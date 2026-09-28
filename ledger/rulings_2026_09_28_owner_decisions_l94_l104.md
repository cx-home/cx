# Owner decisions 2026-09-28 (evening) — Letters 94 to 104: the partition spec's ruled sentences move, the pin verb, and the CI/CD as five cx flow documents

**Status: RULED (owner, 2026-09-28 ~18:5xZ, in session, "recomendations accepted", on the letters
posted on [#1591](https://github.com/cx-home/cx-private/issues/1591) at 18:4xZ — L94 and L95 with the
integrator's reading of items 5 and 10, L96…L104 with the RELFLOW-1 design). RS-1, RS-3, RS-7, RS-11,
RS-36, K7c, CXF-1, CICD-1, INT-8, INT-10, RUN-4, RUN-5, D83a; item 25 and item 28 of the post-split epic.**

## The owner's word, verbatim

"recomendations accepted"

## PART-1 — the six unmade sentence moves of the repo-split edit map land now, and item 5 ticks on the page that names them (L94 = (a))

The decision page `rulings_2026_09_21_repo_split_1589.md` carries an edit map of twelve sentences
"a later branch changes"; on `564d595a1` six have moved (the partition spec's ring section and import
contract, the primer's build table, AGENTS.md, the module registry's rings, the platform README's
namespace line) and six still read their old text: the partition spec's §5 ("Monorepo,
multi-artifact"), §5.1 ("the monorepo persists indefinitely"), §6 P1a ("all artifacts version in
lockstep"), §12.2 ("bindings ship inside the public `cx` mirror") — the page lives in
cx-home/cx-decisions now; the platform README's §2 ("Platform version follows the CX binary … no
independent pin") in cx-home/cx-platform-xap's spec copy; and the OL-14 pointer in this ledger.
Ruled: item 5 ticks on the page (it names and supersedes each section, which is what the item asks)
and the six moves land now as ONE small branch — exactly the map's "Becomes" sentences, no new word,
two component branches under the component-repository rule plus the ledger pointer here. Rejected:
(b) the moves after the epic — the docs waves would cite a spec that still says "monorepo"; (c)
holding the box — no difference from (a) but a later tick.

## DEPSV-1 — `cx deps sync` becomes a verb of the binary (L95 = (a))

The pin transport was ruled as "a CX-written `cx deps sync`" and the pins spec quotes those words,
but the binary has no `deps` subcommand: the program is `scripts/deps_sync.cx` run by
`make deps-sync`. Ruled: the verb `cx deps sync [--check] [--verbose]` — a front-door `vcx/cmd/deps.v`
in the shape the front door's command split already uses for its own plain verbs, running the
embedded `scripts/deps_sync.cx` with the binary's own evaluator so the script stays the one
implementation and `make deps-sync` becomes its thin caller; one subcommand row in cx-core-code's
`vcx/cmd/main.v` on a component branch; fixture first in the cli umbrella. Rejected: (b) amending the
spec sentence to name the make target — the ledger's words would stay untrue of the binary and the
consumer repositories would keep a make dependency for their one pin operation; (c) a cx-gap issue
alone — it ticks nothing.

## RFLOW-1 — the whole CI/CD as five cx flow documents, the design's nine choices (L96…L104 = (a))

The design (`RELFLOW1-DESIGN.md`, posted whole on the board at 18:4xZ) reads the head and rules
nothing by itself; these are its nine choices as the owner accepted them. The documents are
`merge`, `premerge`, `postmerge`, `refresh` and `release` under `flows/`, built in that order, each
a flow document over acts in an env module, each act a make target or an existing cx script
underneath, `--mode=` an act argument, a gate that validates and simulates :done and each refusal.

1. **Where (L96).** The five documents live in cx-private `flows/` with one acts module and the
   simulation cases; the release document and its acts are allocated to the public front door by
   the path allocation, the other four stay private with the integrator protocol. Rejected: all five
   public (four documents describing a private process); in the flow product beside its own
   repo-gate document (every pipeline edit a pin bump).
2. **Acts (L97).** ONE module `flows/ci-acts.cx` (make-one, tail-of, git, gh, log-line, await-gap);
   the docs flow's acts reuse it. Rejected: one module per document (five copies drift); scripts
   called by subprocess (no resolver rows, so no compensation).
3. **Slot (L98).** The runner slot is an act field whose value comes from a new per-step data row
   marking a step load-sensitive — the shared-slot list that is prose today becomes data a gate
   checks — and a shared step re-reads the last RUN line before each run. Rejected: two acts chosen
   by the author (the classification stays in heads); a vocabulary word (placement is not
   choreography).
4. **Waiting (L99).** A blocking act `ci/await-gap [timeout]` polls the loop's last RUN line in a
   bounded sleep loop, one record row per wait — it works under `cx flow run` today, which has no
   liveness. Rejected: an `until … every=` wait over a durable journal with a re-invoking caller
   (the loop is shell again); that plus an in-process stay mode before it exists — the stay mode is
   filed as a flow issue (the design's G3) for the owner to rule on as a spec change.
5. **The post-merge driver (L100).** launchd runs the flow directly every 120 seconds
   (`cx flow run --ephemeral flows/postmerge.flow.cx`, the environment and rlimits in the plist, no
   shell); launchd never overlaps a running job; the state stays in the loop log. The shell loop
   and its library retire. Rejected: a served flow on a schedule (its start pins an address the
   loop's own fast-forward would strand — chosen later, once a runner document can follow a
   document by path); the shell watcher kept and calling the flow per head.
6. **A killed run's verdict (L101).** The run act holds an exclusive io lock for the run's life; the
   next tick that takes it over a start line with no exit line writes the failed verdict — the
   kernel frees a dead holder's lock, no pid probe — and the shell supervisor retires. The lock's
   blocking semantics are measured first in the build. The late marker is why the signal-handler
   cx-gap (the design's G1) is filed. Rejected: the supervisor kept under the act; the journal as the
   verdict (every grep reader breaks).
7. **Underneath (L102).** The acts call `build-slot.sh` and `test_changed.sh` unchanged, so live
   agents share their lock and selection; each port is its own issue, the slot port waiting on the
   foreign-pid liveness cx-gap (the design's G2). No NEW shell is written. Rejected: porting both in
   this round (the item doubles); porting the slot alone (the lock changes under running agents).
8. **Merge order and the release entry (L103).** Trial merges come BEFORE the component pushes, so
   only the release push can fail after them and compensation covers exactly that — a failed push
   is undone with a lease; `release.sh` is deleted, `make release-flow TAG=… [FROM_BUMP=…]` is the
   entry, `--dry-run` is the flow's dry mode (preflight real, later acts answer "would"), the gate
   simulates. The release flow runs under a COPY of the checkout because its first phase rebuilds
   the binary the flow executes. Rejected: the chain's order kept with a shim entry (compensation
   must also undo pushes a later conflict strands); no compensation (today's mains-ahead-of-pins
   failure).
9. **Gates (L104).** ONE program `scripts/ci_flow_gate.cx` over a case table per document, with the
   docs flow gate's four checks and a fifth for merge and refresh — a REAL run against throwaway
   local bare repositories under a temp root removed on exit, proving an unpush restores the
   component's main; one target per document, each a test-target row with its selection row; the
   docs flow gate folds onto the same engine. Rejected: five copies of the docs gate; one target for
   all (a red hides its document).

The three issues the design named are filed on this ruling: the signal-handler cx-gap, the
foreign-pid liveness cx-gap, and the in-process wait as a flow issue.
