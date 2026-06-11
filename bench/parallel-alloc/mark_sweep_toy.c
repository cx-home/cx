// mark_sweep_toy.c — precise mark + sweep over a toy typed heap (spec §5.3 (c)).
// The last unproven mechanic of the minimal collector blueprint:
//   * precise heap interior scan via PER-TYPE pointer maps (the V advantage —
//     no conservative-interior tax; vgc's vgc_scan_precise does exactly this),
//   * cycle-safe marking (a mark bit prevents re-scan -> reachable cycles
//     survive without infinite looping),
//   * sweep that reclaims everything unmarked, INCLUDING unreachable cycles
//     (the advantage over pure reference counting, which leaks cycles).
//
//   cc -O2 -o mark_sweep_toy mark_sweep_toy.c && ./mark_sweep_toy
//
// PASS = reachable objects (incl. a reachable cycle) survive; unreachable
// objects AND an unreachable cycle are all swept.

#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define MAXOBJ 64
#define NSLOTS 4

typedef struct {
    int      type_id;
    int      alive;   // allocated bit
    int      marked;  // mark bit
    intptr_t slot[NSLOTS]; // pointer slots store (index+1); 0 = null. raw ints elsewhere.
} Obj;

static Obj heap[MAXOBJ];
static int nobj = 0;

// Per-type pointer map: bit s set => slot s holds a heap pointer (index+1).
// type 0 = "pair" (slots 0,1 are pointers); type 1 = "leaf" (no pointers).
enum { T_PAIR = 0, T_LEAF = 1 };
static const uint8_t type_ptrmap[2] = { 0x3 /*0b0011*/, 0x0 };

static int alloc_obj(int type) {
    int i = nobj++;
    heap[i].type_id = type;
    heap[i].alive = 1;
    heap[i].marked = 0;
    memset(heap[i].slot, 0, sizeof(heap[i].slot));
    return i;
}
static void set_ptr(int obj, int s, int target) { heap[obj].slot[s] = (intptr_t)(target + 1); }

// --- precise, cycle-safe mark ---
static int work[MAXOBJ], wn = 0;
static void shade(int idx) {
    if (idx < 0 || !heap[idx].alive || heap[idx].marked) return;
    heap[idx].marked = 1;
    work[wn++] = idx;
}
static void mark_from_roots(const int* roots, int nroots) {
    wn = 0;
    for (int r = 0; r < nroots; r++) shade(roots[r]);
    while (wn > 0) {
        int idx = work[--wn];
        uint8_t pm = type_ptrmap[heap[idx].type_id]; // precise: only scan pointer slots
        for (int s = 0; s < NSLOTS; s++) {
            if (pm & (1u << s)) {
                intptr_t v = heap[idx].slot[s];
                if (v != 0) shade((int)v - 1);
            }
        }
    }
}
static int sweep(void) {
    int freed = 0;
    for (int i = 0; i < nobj; i++) {
        if (heap[i].alive && !heap[i].marked) { heap[i].alive = 0; freed++; }
        heap[i].marked = 0; // reset for next cycle
    }
    return freed;
}

int main(void) {
    // Reachable graph: root -> A(pair); A.0->B, A.1->L(leaf); B.0->A (CYCLE A<->B).
    int A = alloc_obj(T_PAIR), B = alloc_obj(T_PAIR), L = alloc_obj(T_LEAF);
    set_ptr(A, 0, B); set_ptr(A, 1, L);
    set_ptr(B, 0, A);                 // reachable cycle A<->B
    heap[L].slot[0] = 42;             // raw value in a leaf (not a pointer slot)

    // Garbage: C<->D unreachable CYCLE; E unreachable leaf.
    int C = alloc_obj(T_PAIR), D = alloc_obj(T_PAIR), E = alloc_obj(T_LEAF);
    set_ptr(C, 0, D); set_ptr(D, 0, C); // unreachable cycle
    (void)E;

    int roots[] = { A };
    mark_from_roots(roots, 1);
    int freed = sweep();

    int reach_ok  = heap[A].alive && heap[B].alive && heap[L].alive;
    int garb_ok   = !heap[C].alive && !heap[D].alive && !heap[E].alive;
    printf("  reachable (A,B,L incl. cycle A<->B): %s\n", reach_ok ? "SURVIVED" : "WRONGLY SWEPT");
    printf("  garbage   (C,D,E incl. cycle C<->D): %s (freed=%d, want 3)\n",
           (garb_ok && freed == 3) ? "COLLECTED" : "LEAKED", freed);

    if (reach_ok && garb_ok && freed == 3) {
        printf("mark_sweep_toy PASS: precise ptrmap mark + cycle-safe + sweep; "
               "reachable cycle kept, unreachable cycle collected (the edge a "
               "pure RC front line cannot reclaim -> this is the backstop's job).\n");
        return 0;
    }
    printf("mark_sweep_toy FAIL\n");
    return 1;
}
