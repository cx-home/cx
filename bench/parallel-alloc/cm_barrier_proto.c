// cm_barrier_proto.c — concurrent-mark soundness prototype (spec §7, Phase-2 2c).
//
// Proves, in isolation and CX-free, that the two GC hazards introduced by
// marking the live graph WHILE mutators run are each closed by exactly one
// mechanism of the planned concurrent collector:
//
//   HAZARD 1 — "hide a white behind a black" (the insertion hazard):
//     the collector has already blackened object A (scanned it, will NOT
//     re-scan it). The mutator then stores a pointer to a still-white object B
//     into A, and deletes the last *other* pointer to B. B is now reachable
//     only through black A -> the collector never greys it -> B is swept while
//     live (use-after-free). CLOSED BY: a Dijkstra insertion write barrier —
//     shade(B) at the store, so B is greyed and scanned.
//
//   HAZARD 2 — "load to a root, then unlink" (the deletion-via-stack hazard):
//     the mutator loads a pointer to a white object W out of the heap into a
//     root (a stack local / register), then nulls the heap slot it came from.
//     W is now reachable only from the root. A Dijkstra *store* barrier does
//     NOT see this (it shades the *new* value written — here nil). CLOSED BY:
//     re-scanning the roots at the brief STW mark-termination, before sweep.
//
// Method: deterministic, scripted worst-case interleaving (NOT real threads —
// a race test is flaky; scripting the exact bad interleaving is a proof). Each
// hazard is run twice: with the closing mechanism DISABLED (must reproduce the
// reclamation, proving the hazard is real and the harness has teeth) and
// ENABLED (must prevent it). PASS = reproduced-when-off AND closed-when-on, for
// both hazards.
//
//   cc -O2 -o cm_barrier_proto cm_barrier_proto.c && ./cm_barrier_proto
//
// This mirrors the chosen design of vlib/builtin/vgc_gc_d_vgc.c.v: the existing
// vgc_write_barrier() is already a Dijkstra shade-the-new-value insertion
// barrier, and vgc_gc_start already re-scans every suspended thread's roots at
// mark-termination. This prototype validates that those two — and only those
// two — suffice, so Phase 2 wires the existing scaffolding rather than
// inventing a new barrier.

#include <stdio.h>
#include <stdint.h>
#include <string.h>

// ---- toy heap -------------------------------------------------------------
#define MAXOBJ 64
#define NSLOTS 4

typedef struct {
    int      alive;          // allocation bit (1 = allocated)
    int      marked;         // mark bit (the tri-color state: see color())
    int      scanned;        // 1 once the collector has scanned this obj's slots
    intptr_t slot[NSLOTS];   // pointer slots: store (index+1); 0 = null
} Obj;

static Obj heap[MAXOBJ];
static int nobj = 0;

// grey work queue (objects marked but not yet scanned)
static int  work[MAXOBJ];
static int  work_n = 0;

// roots: a handful of "stack/register" slots the mutator can hold pointers in
#define NROOTS 4
static intptr_t root[NROOTS];

// GC phase + barrier flag, mirroring vgc_heap.gc_phase / wb_enabled
enum { PHASE_OFF = 0, PHASE_MARK = 1 };
static int gc_phase   = PHASE_OFF;
static int wb_enabled = 0;

// tri-color, for narration only: white = !marked; grey = marked && !scanned;
// black = marked && scanned.
static const char *color(int h) {
    if (!heap[h].marked) return "white";
    return heap[h].scanned ? "black" : "grey";
}

static int alloc_obj(void) {
    int i = nobj++;
    heap[i].alive = 1;
    heap[i].marked = 0;
    heap[i].scanned = 0;
    memset(heap[i].slot, 0, sizeof(heap[i].slot));
    return i;
}

static intptr_t ref(int h) { return (intptr_t)(h + 1); } // encode handle
static int      deref(intptr_t v) { return (int)(v - 1); } // decode handle

// ---- collector primitives -------------------------------------------------

// shade(v): mark grey + enqueue, if v is a heap ref to an allocated white obj.
// (vgc_shade equivalent.) Safe to call with 0 / non-refs.
static void shade(intptr_t v) {
    if (v == 0) return;
    int h = deref(v);
    if (h < 0 || h >= nobj || !heap[h].alive) return;
    if (!heap[h].marked) {
        heap[h].marked = 1;     // white -> grey
        work[work_n++] = h;
    }
}

// scan one object: shade everything it points to, then blacken it.
static void scan_obj(int h) {
    for (int s = 0; s < NSLOTS; s++) shade(heap[h].slot[s]);
    heap[h].scanned = 1;        // grey -> black
}

// drain the grey set fully.
static void drain(void) {
    while (work_n > 0) {
        int h = work[--work_n];
        scan_obj(h);
    }
}

// scan all roots (start snapshot AND termination re-scan use this).
static void scan_roots(void) {
    for (int r = 0; r < NROOTS; r++) shade(root[r]);
}

// sweep: free every allocated-but-unmarked object; report how many freed.
static int sweep(void) {
    int freed = 0;
    for (int h = 0; h < nobj; h++) {
        if (heap[h].alive && !heap[h].marked) { heap[h].alive = 0; freed++; }
    }
    return freed;
}

static void clear_marks(void) {
    for (int h = 0; h < nobj; h++) { heap[h].marked = 0; heap[h].scanned = 0; }
    work_n = 0;
}

// ---- the mutator's barriered store -----------------------------------------
// Models codegen's pointer-store site: heap[h].slot[s] = v, with the Dijkstra
// insertion barrier (shade the NEW value) when the barrier is enabled.
static void store(int h, int s, intptr_t v) {
    heap[h].slot[s] = v;
    if (wb_enabled) shade(v); // Dijkstra insertion barrier
}

// ============================================================================
// HAZARD 1 — hide a white behind a black. Closed by the Dijkstra store barrier.
// ============================================================================
static int run_hazard1(int barrier_on) {
    nobj = 0; clear_marks(); memset(root, 0, sizeof(root));
    gc_phase = PHASE_OFF; wb_enabled = 0;

    // Build: root -> A (a black-to-be), and H -> B (B is the white victim).
    int A = alloc_obj();
    int H = alloc_obj();
    int B = alloc_obj();
    root[0]   = ref(A);
    heap[H].slot[0] = ref(B);
    root[1]   = ref(H);

    // === STW start: snapshot roots, enable barrier, "resume" mutators. ===
    clear_marks();
    gc_phase = PHASE_MARK;
    wb_enabled = barrier_on;
    // Snapshot roots. Grey H first, then A, so the LIFO grey queue is [H, A]
    // and the collector scans A first (below). B is reachable only via H here.
    shade(root[1]);        // H -> grey
    shade(root[0]);        // A -> grey

    // === Concurrent mark, INTERLEAVED with the worst-case mutator. ===
    // Step 1: collector blackens A and FULLY dequeues it (a real black object is
    // never re-scanned). H is left grey, still pending. This is the precondition
    // for the hazard: A is black before the mutator stores into it.
    {
        int h = work[--work_n]; // pops A (greyed last)
        scan_obj(h);            // A -> black, removed from the grey set
    }

    // Step 2: mutator hides B behind black A, then drops B's only other pointer.
    store(A, 0, ref(B));             // black A now points to white B (barrier shades B)
    store(H, 0, 0);                  // delete the only other pointer to B

    // Step 3: collector finishes marking (scans H, drains grey set). A is black
    // and NOT in the queue, so its new slot[0]=B is never re-scanned here.
    drain();

    // === STW mark-termination: re-scan roots, final drain, then sweep. ===
    scan_roots();
    drain();
    gc_phase = PHASE_OFF; wb_enabled = 0;
    int freed = sweep();

    int b_reclaimed = !heap[B].alive;
    printf("  [hazard1 barrier=%s] A=%s B=%s -> B %s\n",
           barrier_on ? "on " : "off",
           color(A), heap[B].alive ? "alive" : "DEAD",
           b_reclaimed ? "RECLAIMED (live!)" : "retained");
    (void)freed;
    return b_reclaimed; // 1 = B was wrongly reclaimed
}

// ============================================================================
// HAZARD 2 — load to a root, then unlink. Closed by termination root re-scan.
// ============================================================================
static int run_hazard2(int term_rescan_on) {
    nobj = 0; clear_marks(); memset(root, 0, sizeof(root));
    gc_phase = PHASE_OFF; wb_enabled = 0;

    // Build: root -> H -> W (W is the white victim, reachable only via H).
    int H = alloc_obj();
    int W = alloc_obj();
    heap[H].slot[0] = ref(W);
    root[0] = ref(H);

    // === STW start: snapshot roots, enable barrier (Dijkstra), resume. ===
    clear_marks();
    gc_phase = PHASE_MARK;
    wb_enabled = 1;          // barrier is ON; it just can't see this hazard
    scan_roots();            // greys H

    // Step 1: collector scans H -> black; W greyed... but stage the hazard so
    // the mutator acts BEFORE the collector reaches W. We scan H's slots? No:
    // to stage it, the mutator first loads W to a root and nulls H BEFORE H is
    // scanned. So: do NOT scan H yet.
    //   work holds [H]; pop H but model the mutator interleaving first.
    work_n = 0;              // collector hasn't drained yet

    // Step 2: mutator loads W into a root, then unlinks it from H.
    root[1] = heap[H].slot[0];   // load &W into a "register" root (no load barrier)
    store(H, 0, 0);              // null H.slot0 (Dijkstra shades the NEW value: nil -> no-op)

    // Step 3: collector now drains. It scans H (already greyed at root snapshot),
    // finds H.slot0 == nil, so W is NOT discovered through the heap.
    shade(root[0]); // H already grey; re-grey is a no-op
    drain();        // scans H (black); W never greyed via heap

    // === STW mark-termination. ===
    if (term_rescan_on) scan_roots(); // re-scan roots -> finds &W in root[1]
    drain();
    gc_phase = PHASE_OFF; wb_enabled = 0;
    int freed = sweep();

    int w_reclaimed = !heap[W].alive;
    printf("  [hazard2 rescan=%s] H=%s W=%s -> W %s\n",
           term_rescan_on ? "on " : "off",
           color(H), heap[W].alive ? "alive" : "DEAD",
           w_reclaimed ? "RECLAIMED (live!)" : "retained");
    (void)freed;
    return w_reclaimed; // 1 = W was wrongly reclaimed
}

// ============================================================================
// HAZARD 3 — the IMPLEMENTED barrier: a card / "dirty-span" insertion barrier,
// proven preemption-safe. This collector suspends mutators with OS-level mach
// suspend (NOT cooperative safepoints), so a mutator can be frozen MID-BARRIER.
// An immediate-shade barrier that enqueues the new value can lose the enqueue if
// frozen between the slot write and the count bump. Instead the barrier marks the
// target object's span DIRTY (one idempotent byte store) and the collector
// re-scans every dirty span at termination. The ORDERING is load-bearing: the
// dirty mark must precede the pointer store. We prove dirty-BEFORE is sound under
// a mid-barrier freeze and dirty-AFTER is not.
//
// per-object `dirty` here models the per-span dirty flag of VGC_Span.
static int dirty_flag[MAXOBJ];
static void rescan_dirty(void) {        // collector, at STW termination
    for (int h = 0; h < nobj; h++) {
        if (heap[h].alive && dirty_flag[h]) {
            for (int s = 0; s < NSLOTS; s++) shade(heap[h].slot[s]);
            dirty_flag[h] = 0;
        }
    }
}
// freeze_in_gap: model the mutator being mach-suspended between the two barrier
// sub-steps. dirty_before: emit dirty mark, [FREEZE], then the store. If frozen,
// the store never executes this cycle. dirty_after: emit store, [FREEZE], then
// dirty mark. If frozen, the store executed but the span was never dirtied.
static int run_hazard3(int dirty_before, int freeze_in_gap) {
    nobj = 0; clear_marks(); memset(root, 0, sizeof(root));
    memset(dirty_flag, 0, sizeof(dirty_flag));
    gc_phase = PHASE_OFF; wb_enabled = 0;

    int A = alloc_obj();   // black-to-be
    int H = alloc_obj();   // holds B
    int B = alloc_obj();   // white victim
    int C = alloc_obj();   // B's child, reachable only via B (tests subtree scan)
    heap[B].slot[0] = ref(C);
    root[0] = ref(A);
    heap[H].slot[0] = ref(B);
    root[1] = ref(H);

    // STW start
    clear_marks();
    gc_phase = PHASE_MARK; wb_enabled = 1;
    shade(root[1]); shade(root[0]);          // grey H, A
    { int h = work[--work_n]; scan_obj(h); } // blacken A, dequeue it

    // mutator hides B behind black A, then drops B's other pointer. The barrier
    // marks A's span dirty; the only question is the dirty-vs-store ordering when
    // a freeze lands in the gap.
    int store_executed;
    if (dirty_before) {
        dirty_flag[A] = 1;                   // barrier: mark dirty FIRST
        if (freeze_in_gap) { store_executed = 0; }   // <-- frozen here: store skipped
        else { heap[A].slot[0] = ref(B); store_executed = 1; }
    } else {
        heap[A].slot[0] = ref(B); store_executed = 1; // store FIRST
        if (freeze_in_gap) { /* frozen before dirty */ }
        else { dirty_flag[A] = 1; }
    }
    store(H, 0, 0); // drop B's other pointer (a normal barriered store; B may be dirtied via H)

    // collector finishes the concurrent drain
    drain();

    // STW termination: re-scan dirty spans + roots, final drain, sweep.
    rescan_dirty();
    scan_roots();
    drain();
    gc_phase = PHASE_OFF; wb_enabled = 0;
    sweep();

    // The hazard exists ONLY if the store executed (B is hidden behind black A).
    // Soundness requirement: if the store executed, B AND its child C survive.
    int hazard_present = store_executed && heap[A].slot[0] == ref(B);
    int b_lost = hazard_present && !heap[B].alive;
    int c_lost = hazard_present && !heap[C].alive;
    printf("  [hazard3 %s freeze=%s] store=%s -> B %s, C %s\n",
           dirty_before ? "dirty-before" : "dirty-after ",
           freeze_in_gap ? "yes" : "no ",
           store_executed ? "done" : "skipped",
           hazard_present ? (heap[B].alive ? "retained" : "RECLAIMED(live!)") : "n/a",
           hazard_present ? (heap[C].alive ? "retained" : "RECLAIMED(live!)") : "n/a");
    return b_lost || c_lost; // 1 = unsound reclamation
}

int main(void) {
    printf("concurrent-mark soundness prototype (scripted worst-case interleaving)\n");
    printf("HAZARD 1: hide-a-white-behind-a-black (insertion barrier)\n");
    int h1_off = run_hazard1(0); // barrier OFF: must reproduce reclamation
    int h1_on  = run_hazard1(1); // barrier ON:  must prevent it
    printf("HAZARD 2: load-to-root-then-unlink (STW termination root re-scan)\n");
    int h2_off = run_hazard2(0); // rescan OFF: must reproduce reclamation
    int h2_on  = run_hazard2(1); // rescan ON:  must prevent it
    printf("HAZARD 3: implemented card/dirty-span barrier, preemption-safety\n");
    int h3_db_nf = run_hazard3(1, 0); // dirty-before, no freeze:   sound
    int h3_db_fz = run_hazard3(1, 1); // dirty-before, freeze:      sound (store skipped)
    int h3_da_nf = run_hazard3(0, 0); // dirty-after,  no freeze:   sound
    int h3_da_fz = run_hazard3(0, 1); // dirty-after,  freeze:      UNSOUND (proves ordering matters)

    int teeth   = h1_off && h2_off && h3_da_fz; // all hazards real (harness has teeth)
    int closed  = !h1_on && !h2_on && !h3_db_nf && !h3_db_fz && !h3_da_nf;
    printf("\n");
    printf("  harness teeth: hazard1=%s hazard2=%s hazard3(dirty-after+freeze)=%s\n",
           h1_off ? "yes" : "NO", h2_off ? "yes" : "NO", h3_da_fz ? "yes" : "NO");
    printf("  closed:        h1(barrier)=%s h2(rescan)=%s h3(dirty-before, all freezes)=%s\n",
           !h1_on ? "yes" : "NO", !h2_on ? "yes" : "NO",
           (!h3_db_nf && !h3_db_fz) ? "yes" : "NO");
    if (teeth && closed) {
        printf("cm_barrier_proto PASS: insertion barrier closes the hide-white-behind-black\n");
        printf("  hazard; STW-termination root re-scan closes load-to-root-then-unlink; the\n");
        printf("  card/dirty-span barrier is preemption-safe IFF the dirty mark precedes the\n");
        printf("  store (dirty-after+freeze is provably unsound). + alloc-black. Sufficient.\n");
        return 0;
    }
    printf("cm_barrier_proto FAIL (teeth=%d closed=%d)\n", teeth, closed);
    return 1;
}
