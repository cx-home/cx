# I5 stream 22 — clean-room implementability (implementation ledger)

**Branch** `impl/I5-stream22-cleanroom` off `design/651-516-partition`
(opened 2026-08-13 @ a3b5e97e, the stream-16 exit merge). **Governing
spec** `clean_room_implementability.md` (letters 70–76 ruled (a)
2026-08-05; EV-WORKER-EXIT ruled AGAINST shipped behavior under the
proviso). **Issues:** #694 (the stream), #707 (held open for exactly
one residual: the lazy `CX_WORKER_THREADS=0` substrate vs
EV-ASYNC-SPAWN — lands here). **Downstream:** stream 17's EV-PULL
engine rewrite (#710 item 6) consumes this stream's rule + probe
infrastructure.

## Shipped-state map (evidence sweep 2026-08-13, at a3b5e97e)

SHIPPED (I2 via #707 + stream 6): EV-RESULT-IMAGE spec'd (code.md
§11.1a R1–R6); grant= promoted (fixtures.cxs + runner three-way);
README rewritten (V = reference impl; retired formats named);
consistency checker repaired + green in TEST_TARGETS; bounded-freedom
register row BF-1; sentinel de-anchoring clean; EV-ASYNC-SPAWN
NORMATIVE text (code.md:4733 eager spawn; cli.md CX_WORKER_THREADS
sizing-only) — but the non-conforming =0 branch STILL SHIPS w/ two
tests asserting the lazy behavior (the #707 residual); EV-EFFECT-SET
fully executed by stream 6 (security.md §2.1 closed table + the
both-direction mirror test + check-effect-alignment); out-effects
DECLARED (fixtures.cxs) but zero runner implementation; EV-BUDGET
floor already 1_000_000 (eval.v:439); [?test-counter] shipped (the §9
probe substrate); mock-clock parking IMPLEMENTED (async.v:25) but not
normative; IteratorNode lazy-shaped; concurrent workers default.
MISSING (this stream): code.md §Evaluation (environment object,
numbered EV register, ordering) + desugar-to-core (L70); A/B/C/D
grades table (L71); witnesses kind=eval/trace + relocation question;
rule= traceability attr (§8) — ZERO discriminator pairs exist for any
EV-* rule; out-effects runner implementation (stream 6's
propose-predicts-commit pair is BOOKED on it); result image has TWO
implementations (harness render_value + production render_canonical),
neither §11.1a-citing, no parity gate; EV-ASYNC-SPAWN residual;
EV-WORKER-EXIT (cancel-and-drain — unimplemented AND the one
ruled-against-shipped row); EV-SELECT-FAIR downgrade text; EV-ARG-ORDER
text; EV-LET-SEQ/EV-CLOSURE-CAP/EV-CLOCK-PARK correct in impl, spec
silent; L75 gate partition; L74 governance §10.1 clause; EV-PULL
(engine eager at 16 mk_eager_iterator sites — the ENGINE rewrite is
stream 17's named landing, #710 item 6).

## Wave plan

- **W1 — witness instrumentation + front-door completion (L73/§8):**
  the out-effects channel IMPLEMENTED in the runner (trace assertion:
  ordered effect-point sequence; unblocks every ordering witness + the
  booked stream-6 pair — authored here as the receiving side); the
  `rule=` traceability attr (fixtures.cxs + runner carry-through — the
  EV map becomes a corpus query); witnesses.txt gains kind=eval/trace;
  the result image UNIFIED on one production-owned §11.1a-citing
  renderer w/ the harness pointed at it + a parity assertion (M22
  output re-bless rides here IF outputs move — deliberate review).
- **W2 — the normative core (L70/L71/L74/L75 + the spec-only EV
  rows):** code.md NEW §Evaluation — the environment object (lexical
  frame, closure snapshot, dynamic-context stack, current-task slot),
  the numbered EV register w/ stable ids, desugar-to-core (the core
  form set + the directive desugaring map), effect-point vs
  cancellation vs capability ordering; EV-LET-SEQ (let* IS the rule),
  EV-CLOSURE-CAP (snapshot discipline), EV-CLOCK-PARK (the parking/
  barrier-advance algorithm from async.v made normative), EV-BUDGET
  (floor spelling), EV-ARG-ORDER (one interleaved source-order pass),
  EV-SELECT-FAIR (the ruled downgrade: MUST NOT be deterministically
  source-order biased; distribution = reference-lane) — EACH w/ its
  discriminator pair (rule= tagged); the A/B/C/D grades table; the
  L75 gate partition (reference-lane-only vs conformance-bar marks on
  §11.4 gates); governance §10.1 clean-room clause (rule-in-register,
  witness-that-fails-under-the-opposite-choice, floors-never-bare-
  numbers).
- **W3 — EV-ASYNC-SPAWN (the #707 residual):** retire the
  CX_WORKER_THREADS=0 lazy branch (eval.v/async.v/matcher.v); re-bless
  the two tests ASSERTING the non-conforming behavior; the
  fire-and-forget discriminator pair (effect with no await, via
  out-effects); #707 CLOSES here.
- **W4 — EV-WORKER-EXIT (the ruled-against-shipped row):**
  cancel-and-drain at top-level return — fixture FIRST (the
  worker-at-exit probe pair), then the engine change; visible drain
  accounting.
- **W5 — EV-PULL rule + probe infrastructure:** the normative pull
  protocol text (code.md §6.7 cross-ref; combinators pull exactly what
  they yield; documented lookahead only); pull-count probes pinned
  over the ALREADY-LAZY substrate (the open-range Iterator lane);
  the per-combinator pull-count pair FAMILY authored to land WITH
  stream 17's engine rewrite (named landing: #710 item 6 — fixtures
  ride the engine change, never red).
- **W6 — hygiene + exit:** the §10 edit-map sweep residue
  (fp/jsonschema de-anchoring VERIFY; security.md §2/§4 VERIFY —
  stream 6; checker/Makefile deltas); #694 closure evidence per
  letter; #707 closure (W3); exit audit + exit gate → merge.

Named landings (ruled, not deferrals): the EV-PULL ENGINE rewrite +
its passing pair family = stream 17 (#710 item 6); the M5 witness
corpus families = stream 14 (§9); the stream-6 propose-predicts-commit
pair = authored here W1 against the new channel (the stream-6 ledger
books it).

## Wave record

