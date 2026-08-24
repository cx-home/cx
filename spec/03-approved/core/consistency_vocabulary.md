# Consistency vocabulary — declare and verify (stream 7)

**Status:** Approved (G3 graduation, owner ruling exit-1a, 2026-08-14; stream 7, issue #679). Implements L10a:
declarable, checkable attributes for what CX ACTUALLY guarantees —
satisfy-or-reject, fail-loud, never approximate. Serializable cross-stream
is NOT offered here (stream 10 owns coordination; the outcome there may be
a mechanism or a principled rejection). Note: the issue text's "as-of" is
pre-correction — bitemporal L118 assigned stream 7 the `at-seq` spelling
and retired `as-of` from new surfaces. Normative once approved.

**Worked example (M5):** the invoice read is `at-seq-pinned` — it REFUSES
rather than silently repricing when a correction lands (resolving through
the covering snapshot first; refusing only when even that is pruned); the
inventory check is `prefix-consistent` — per-source, and a multi-SKU join
across streams gets NO cut unless it declares `at-head-set`; the order-ref
advance is `linearizable-ref` — a blind LWW alias write or `branch-force`
becomes an error on that handle, and the racing loser gets CXER1114 with
the position encoding; the refund commit is `linearizable-append` +
`at-least-once` + `[idempotent]` — a caller reaching for `exactly-once` is
refused WITH the pointer to stream 6's dedup, not left to assume.

## §1. Findings

1. The substrate's guarantees are real and narrow: per-stream
   committed-prefix reads; per-stream linearizable append; NO cross-stream
   order (a negative guarantee — the one that must be refusable);
   linearizable fast-forward ref advancement (with LWW as the silent
   default on expect-less writes); content-address reads that cannot be
   stale by construction; signed snapshot HEAD-SETS as the only
   tenant-wide TX coordinate; fabric's two honestly-different planes with
   no silent promotion; XSP group-resume protected while observe-mode
   resume can silently gap or rewind.
2. Isolation vocabulary appears NOWHERE in the corpus — greenfield — while
   a docs-only `Transactional`/"single-backend ACID" claim contradicts the
   audit's NOT-FOUND finding (#714, amended now — the stream-17
   false-claim precedent).
3. Eight silent-degradation findings (F1–F8), sharpest: `journal head` is
   a PURE read of a handle-cached head — under any second writer it
   reports a stale position with no signal and no fresh path; and no
   replica reads exist yet, which is the argument for landing this
   vocabulary BEFORE stream 9, not after.
4. The corpus's own sentence is the thesis: "a silent delivery-guarantee
   change is a silent-wrong-answer class" — generalized here from delivery
   to every consistency-bearing read.

## §2. The closed vocabulary (L122)

Atoms, closed set, closure is a MUST — an unknown token is a typed error,
never ignored (XSP's ignore-unknown posture is a wire-version concern,
stated as such; the closed-list rulings govern semantics):

| Token | Meaning | Satisfied by / refused by |
|---|---|---|
| `:prefix-consistent` | per-stream committed prefix, never torn | every single-stream journal read / tenant-wide compositions, replicas or adapters that cannot prove it |
| `:at-seq-pinned` | TX position pin (value carried) | replay/fold/snapshot pins; resolve-through-covering-snapshot below retention / pruned-past-coverage |
| `:at-head-set` | a signed, verifiable multi-stream CUT `{(stream, at-seq, anchor-hash)}` | the snapshot substrate / **a READ coordinate, never a commit primitive** — the one-sentence stream-10 line |
| `:linearizable-ref` | ref advances are CAS-only on this handle | `expect=`/`expect-pos=` writes / makes expect-less LWW writes and `branch-force` errors on the declaring handle |
| `:read-your-writes` | this handle's writes visible to its reads | single handle, one daemon mount / byte-source remotes, ref-caching layers, replicas; writer-scoped only inside the CXER1116 self-heal window (one normative sentence) |
| `:monotonic-reads` | no rewind on resume | checkable server-side against the requested cursor |
| `:gapless` | no skip on resume (distinct from monotonic) | refused when retention pruned past `from=` |
| `:at-least-once` | delivery class | the durable plane |
| `:exactly-once` | **permanently refused** — the refusal NAMES `[idempotent]` (stream 6) as the answer | — |
| `:serializable` | **refused with pointer** — the error names stream 10's coordination design | — |

`snapshot-isolation`, `causal`, `eventual`: OUT of the set entirely —
admitting them as refusals implies roadmap; admitting them as accepted is
a lie. `valid-at` is NOT a consistency token (stream 8's query parameter
over payload data; the two axes must not fuse).

## §3. Attachment and checking (L123)

Two attachment points, and only two:

- **Handle/session floor** — store open-opts, journal open/attach, fabric
  subscribe, XSP session: checked ONCE at declaration time against the
  surface's advertised guarantee set (the CSRP §5.3 pre-flight model),
  refused at open, and the advert **binds the config generation** (a
  cached guarantee advert across `config-reload` is a cached lie — F3).
- **Per-read pins** — `at-seq`, head-set, cursor on the read opts.

**No `[?def]` consistency clause** — stated with its reason, since the
stream-6 clause precedent invites one: a consistency need is a property
of the handle a value arrives through at runtime, not of a definition;
a def clause would be either advisory (the house contradiction) or a
per-call dynamic check, i.e. the opts indirected. Pipeline declarations
ride the **source reference** (stream 2's L97 surface) — `[?for]`'s
just-closed clause list stays closed — and composition is computed by
the ONE traversal contract (L100), never a fourth walker.

## §4. Composition semantics (L124)

The vocabulary is a **lattice of independent conjuncts, not a level
ladder** (stated normatively — incumbent "consistency level" intuitions
pull toward a linear order that does not exist here):
`prefix-consistent` and `read-your-writes` are incomparable. A refusal
names the failing STAGE and the failing TOKEN (the D-C1 error shape).
Multi-stream reads: `prefix-consistent` holds per-source ONLY; a
cross-source cut requires `:at-head-set`; and `at-head-set` reads a cut —
committing across streams is stream 10's, entirely.

## §5. Errors (L125 — band corrected at recording)

One primary code: `E_CONSISTENCY_UNSATISFIABLE`, carrying the declared
token, the surface, and the surface's actual guarantee set; one
companion: `E_CONSISTENCY_PIN_UNCOVERABLE` (a declared pin no longer
resolvable, after the resolve-through-snapshot rule — mirroring the
CXER4606/4615 impossible-vs-diverged split). **Allocated in the free
`CXER4990–4999` band** — the sweep proposed `4850+`, which is already
XAP-occupied (4850/4855/4887/4889); verified and corrected under the
standing ruling. Value-vs-raise follows the settled pattern: inspection
verbs ("what does this surface guarantee?") answer VALUES; declarations
refuse loudly.

## §6. Findings register (L126; #714)

F1 `journal head` (pure, handle-cached): `head` satisfies NEITHER
read-your-writes nor freshness declarations — stated; a declared-fresh
head is a distinct, impure verb (spec'd with this stream). F2
observe-mode resume: `:monotonic-reads`/`:gapless` are checkable
server-side against the cursor and retained tail; retention-pruned
`from=` refuses. F3 guarantee adverts bind the config-reload generation.
F4 the unbuilt `?cache=` layer: ref-caching refusal spec'd NOW
(immutable-objects-forever / refs-revalidate is the rule; a ref-caching
layer under a declared `read-your-writes`/`linearizable-ref` refuses).
F5 declared `linearizable-ref` ⇒ expect-less writes error. F6 the
CXER1116 sentence (§2 table). F7 transient-plane drop counts REPORTED
per subscription (the stream-8 redaction-visibility posture; drop-oldest
stays inherent, its magnitude stops being invisible). F8 tenant-wide
fold annotated at the verb: not a cut; `:at-head-set` is the cut.

## §7. The docs contradiction (L127; #714)

`docs-src` cxstore architecture's `Transactional` trait + "single-backend
ACID" claim is amended NOW: superseded by this vocabulary; single-backend
transactionality re-enters, if ever, as a declarable token when a spec'd
backend actually advertises it (none does today).

## §8. Stream-9 handoff (L128)

The replica declaration profile is ruled here so stream 9 inherits
vocabulary instead of inventing it: a replica CAN declare
`:prefix-consistent` (the hash chain makes "prefix" checkable, not
asserted), `:at-seq-pinned` up to its synced head, `:monotonic-reads`;
it MUST refuse `:read-your-writes` and `:linearizable-ref` (offline ref
advance is where stream 9's conflict-values land); it MUST advertise its
signed head-set and ahead/behind through status. A replica whose TX
position lags while its VT data is complete is expressible (the
bitemporal L119/handoff) — a single staleness scalar is not enough.

## §9. Corpus handoff (stream 14; M5 substrate)

Declared-and-satisfied vs declared-and-refused DISCRIMINATOR PAIRS on
the same read, per token; the stale-`head` pair (F1); the observe-resume
gap negative (F2); the expect-less-write refusal under
`:linearizable-ref` (F5); `:exactly-once` → refusal naming
`[idempotent]`; `:serializable` → refusal naming stream 10; the
multi-stream no-cut vs `:at-head-set` pair (the M5 invoice+inventory
join); pin-below-retention resolve-through-snapshot then refuse.

## §10. Rulings ledger — RULED

Letters 122–128 **ruled (a) 2026-08-05 under the standing acceptance
ruling** (each verified against the long-term-best bar; ONE
strengthening: the error band moved from the sweep's proposed
XAP-occupied 4850+ to the verified-free 4990–4999): the closed atom
vocabulary with exactly-once and serializable as teaching refusals
(122); two attachment points, no def clause, source-reference riding,
ONE-traversal composition (123); the conjunct lattice + per-source
semantics + the read-vs-commit line (124); one primary + one pin code
in 4990+ (125); the F1–F8 register with the fresh-head verb, resume
guards, generation-bound adverts, drop-count reporting (126); the
Transactional docs claim amended now (127); the replica declaration
profile handed to stream 9 (128). Recorded in the campaign decision
log. Spec-edit map: journal.md §4.4 (tokens + fresh-head verb + fold
annotation), store.md §5/§6 (advert + refusals), fabric.md §6/§8 (plane
tokens + drop counts), xsp.md §5.3 (resume guards), governance §9.6
(the 4990 band), docs-src cxstore architecture (amendment), stream-3
surfaces (observe/materialize/changes-since declare through the same
opts — coordinated in-wave).

## Identity-epoch membership (audit C9)

**ADDITIVE — this stream owns no I1 manifest row and joins no epoch.**
Guarantee tokens, declarations, adverts, and refusals are config/wire
data and new error rows; verification reads existing E3 positions and
head-sets. Nothing here defines, moves, or re-spells a Tier-1/Tier-2
address, a canonical byte, or a journal preimage.
