# Batch #796 — post-gate defects (#788, #792, #793, #781, #782)

Status: Working ledger (the batch's design + completion record)
Ruling basis: the post-gate defect batch ruling (owner, **RULED: 1a**,
2026-08-13 — recorded on the issues), scheduled with the #695 hygiene
wave; membership extended by **audit ruling Q1a** (2026-08-13, audit
AF-12) to carry #781 and #782, which predated the 1a mapping and had no
landing. #793 was relabeled `prio:medium` under **ruling Q2a** (the
fail-open class floor). The packet §10 arc places the batch after #795
and before the #804 return.

## The unifying defect

Four of the five members are one shape: **the engine accepted something
and then quietly did something other than what it said**. Not a wrong
answer — a *silent* one, where the caller has no way to learn that the
thing they asked for was not what happened.

- #793 — `[?await $f :timeout 2ms]` parsed, dropped the two trailing
  slots, and ran as an UNBOUNDED await. A spelling mistake became a
  behavior change at exactly the point a deadline was being requested.
- #782 — `query "/event/promo[@valid-from]"` cut the predicate off and
  matched the element-name step alone, answering with a SUPERSET of
  what was asked. A deliberate subset is defensible; a silent one is
  not.
- #788 — an unclassified callee defaults to PURE, so a fold reducer
  reaching an unregistered Ring-2 verb slipped the CXER4611 guard and
  deadlocked on the pack's own non-reentrant mutex instead of refusing.
- #781 — `[$io:temp-dir P]` handed back a LEFTOVER directory, stale
  contents included, whenever a recycled pid reproduced an earlier
  run's name. The caller believes it holds a fresh directory.

#792 is the odd one out and the inverse: the engine reported honestly
that it did not know (`FILE:0:0`) because the data AST carried no
positions to report.

## The five fixes

### #781 — temp-dir is collision-proof by construction

`<temp>/<prefix><pid>-<counter>` is unique within ONE process only; pids
recycle and nothing cleans the system temp dir. Direction 1 of the
issue, and what the APPROVED spec already states (std-lib/io.md §3.8:
"temp-dir creates a fresh empty temp directory"): `mkdir` (unlike
`mkdir_all`) fails on a taken name, so the search draws a fresh token
and retries. Collision-proof by construction, no randomness added to the
fixture-visible name shape, real mkdir errors still surfacing
immediately, and the search bounded so a pathological temp dir cannot
spin. `temp-file` is unaffected (os.create truncates) and the asymmetry
is documented in-code so it does not read as an oversight.

Repro verified in BOTH directions: pre-fix the leftover comes back with
its marker file; post-fix the search walks past every taken name.

### #793 — the await family refuses what it does not define

`await_check_args` is the family's one argument authority: per §10.5.2
the whole family takes ONE positional, and only `[?await]` defines a
label (`timeout=`). Anything else is CXER0100. The barrier verbs share
the check through `collect_future_args`, so the refusal is the FAMILY's,
and they refuse `timeout=` rather than promise a deadline they never
apply. The unknown-LABEL door closed with the unknown-positional one —
a misspelled `timeuot=` had the identical unbounded-wait consequence.

Two documentation sources TAUGHT the refused spelling and were corrected
to the approved-spec form: async.v's own header comment and the
canonical docs CXER0241 row (plus the adjacent try-send/try-receive rows
carrying the same error).

### #782 — journal query applies the real predicate

The path now goes through the engine `cx select` and inline `$doc/…`
reads already use (`select_path_on_node` — select_path's parse,
validation and evaluator, with a door for a caller already holding the
materialized tree). ONE evaluator means predicate semantics cannot drift
between the journal surface and the rest of CX.

Rooting is the documented one, made explicit: §3.3's own example is
`/event/do[…]`, where the leading step addresses the ENTRY's `[event]`
child. The engine's bare `/…` is root-NAMED, so the surface path is
anchored to the entry with an explicit `$doc`. **Probed live before
choosing the mapping**, not inferred. An unparseable path is now the
caller's error, reported once (CXER4610), instead of being cut off so
the query could answer anyway.

### #788 — the Ring-2 impure sweep, behind a self-checking gate

The gate came FIRST and DERIVED the gap rather than trusting a
hand-kept list. It states the invariant over the source of truth — each
wrapping `[?def]`'s own declared purity in `stdlib/*.cx`:

> a def declared `impure` must reach at least one callee the engine
> CLASSIFIES impure

If it does not, the engine reads that body as pure: the declaration says
impure, the classifier says pure, and a pure-required context admits it.
That IS the slip. The check runs through the real module loader and the
real classifier — no regex, no second parser — so it cannot drift from
what the engine does.

It found **208** such defs. ~130 are Ring-2 and are registered (bus,
fabric, session, authz, did, vc, xap + dist, live, net, ft-search-store,
the http SERVE half per seam H, io-watch-close). Verb names are the
defs' own dispatched builtins, so a registration typo cannot pass — the
def would simply stay unclassified and fail the gate.

### #792 — the data AST gains an OPT-IN position surface

`ElementMeta` gains `pos ?Position`, recorded at the element's NAME
token. Tracking is opt-in (`parse_cx_positioned`) as a REQUIREMENT, not
a preference: meta is lazily allocated and `new_element` elides it when
empty, so stamping every element would add one allocation per element to
every parse in the system. `cx validate` is the door that prints
FILE:LINE:COL to a human, so it is the one that opts in.

The validator threads positions through ONE stamping frame in
`validate_element` rather than editing ~56 construction sites.
Recursion makes attribution precise: a child's frame completes first, so
a child's diagnostics already carry the CHILD's position when the
parent's frame runs.

**Identity-adjacent care** (the issue's own constraint): positions are
presentation, the standing anchors and comments have. They reach neither
canonical bytes nor Tier-1 identity — the canonical emitters read meta
field-by-field through named accessors, so a field they do not name is
inert by construction. PINNED rather than asserted: the same source is
parsed BOTH ways and required to produce identical `emit_cx` output AND
an identical Tier-1 address.

## No canonical-byte movement

Unlike #795, this batch moves **no** canonical bytes and **no** Tier-1
address. #792 is the only member touching an identity-adjacent surface
and carries the both-ways inertness test as its proof. No corpus
re-bless was required or performed.

## Filed, not silently widened

Three findings were surfaced by this work and belong to their own
landings rather than to a quiet scope extension:

- **#816** — `[?try-send]`/`[?try-receive]` accept the SPEC-DEFINED
  `timeout=` and never read it. The same fail-open class as #793, but a
  spec-defined argument cannot be closed by refusal: the deadline has to
  be implemented (or §10.4.2 reconciled to the zero-wait poll the engine
  actually performs). Needs its own direction.
- **#817** — journal.md §3.3's query example still uses the RETIRED
  infix predicate form (`[@*='refund-duplicate']`), which #782 makes
  load-bearing because the engine now sees it. APPROVED spec, so it
  needs authorization rather than an edit in an implementation pass.
- **#818** — 82 impure-declared defs in RING-1 packs (random, test,
  prof, log, sched, the http client half, mime, io, locale) that the
  Ring-1 purity table does not classify. Same defect as #788 through a
  different seam; registering them through `ring2_impure_register` would
  have been a lie about the ring. Pinned in a CLOSED exception table
  checked in BOTH directions — an unlisted unclassified def fails, and a
  listed def that starts passing also fails ("remove it") — so #818's
  acceptance, the table reaching empty, is observable.

## Batch completion record (2026-08-15)

LANDED: all five members with repros. #781 verified in both directions
on a pre-taken-name repro; #793's four fixtures each verified RED with
the check disarmed (which also proved the runner compares out-err codes
rather than passing on any thrown error); #782's three fixtures with the
pre-existing journal-009 staying green unchanged (it was already a
strict path match); #788's gate red-then-green across the derived gap;
#792's three tests (positions reported, inert to canonical bytes and
identity, and the opt-in property itself — which is also what pins the
old 0:0 contract for every non-validating reader).

Exit: FULL `make test-vcx` GATE-RC=0 twice — once at the #788 seam
(788_union.log) proving ~130 newly-classified verbs broke no
pure-required context in the corpus, once at the #792 seam
(792_union.log, schema_validate.cxd 79/79) proving the parser/AST change
is inert. In both runs the same two lanes (fabric, http umbrellas) died
at C-compile with `ld: duplicate symbol` and cleared on their cache-free
retries — the documented #572 `-usecache` stale-layer class, unrelated
to this batch and identical across both runs.
