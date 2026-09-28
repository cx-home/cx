# Owner decisions 2026-09-28 (afternoon) — Letters 80 to 84: feature dispatch, the host's fabric, breaker state, comprehensions in literals, bare namespaced heads

**Status: RULED (owner, 2026-09-28 ~14:5xZ, in session, on the letters posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 13:4xZ and 14:4xZ; the owner asked
whether the recommendations were the best for cx long-term, the integrator revised L80 and L83 on the
board, and the owner answered on the revised set). OPXAP-1, KIT4-2, HC-1, 1509-a, YIELD-1, RS-38,
CXF-8; cx-private #1693, #1694, #1700, #1664; cx-core-code#3.**

## The owner's word, verbatim

"L80d, L81a, L82a, L83b, L84a"

## FDISP-1 — the host dispatches a verb through a feature→package map built at boot (L80 = (d))

Measured under the host (OPXAP-1): the host registers a package's module under the package's name
and dispatches an act by its verb's feature name (`<feature>:apply`), so a package whose name is not
its feature's is never dispatched, and order-pipeline's scenario had to publish its tree as
`order-events`. Ruled: the host builds, at boot, a map from each feature a deployment's packages
declare to the package that carries it, and dispatches through that map; a package's name stays free
of its features' names, and a package may carry several features (KIT4-2). One sentence in the
distribution spec where dispatch is defined, with the order-pipeline scenario — published under its
real package name again — as its case (RS-38). Rejected: (a) the published name is the feature's,
one connector per feature — a convention that forbids a multi-feature package; (b) dispatch by
package name — the features of one package not addressable apart; (c) an explicit published-name
attribute — a second name to keep aligned.

## FABR-1 — the host context carries the fabric the host built on the deployment's journal (L81 = (a))

OPXAP-1's xap fix hands the connector kit the embedded fabric the host built on the deployment's own
journal; the distribution spec's §1.2 (the `$host` shape HC-1 defines) did not name it. Ruled: one
sentence in §1.2 carrying the xap test's id
(`test_connectors_context_hands_the_kit_the_embedded_fabric`), in the FDISP-1 round. Rejected: (b)
leaving it unspoken; (c) a fabric section of its own.

## CBKEY-1 — a computed `name=` keys resilience state by its evaluated value (L82 = (a))

cx-core-code#3: `[?circuit-breaker … name=$x]` and `[?rate-limit name=$x …]` key ONE shared state
per call site whatever `$x` evaluates to, while a literal name is isolated (program-cb-002…004); the
connector's `c--send` wraps every call in both with a computed name, so four failed acts of one
gateway made every later request of every other gateway refuse CXER0150 unsent. Ruled: the state is
keyed by the evaluated name value, exactly as a literal is — fixture first (`name=$x` cases beside
the literal ones), a small evaluator fix, prio:high. Rejected: (b) a distinct call site per gateway
in the connector — a library workaround for an evaluator defect; (c) refusing a non-literal name —
no per-tenant breakers at all.

## LITER-1 — a `[?for]` contributes one item per `[yield]` in a `(…)` or array literal, as 1509-a says (L83 = (b))

cx-private #1693: the engine nests the whole comprehension as one item inside a `(…)` or `[…]`
literal (`(0, [?for … [yield $x]])` → `(0, (1, 2, 3))`), while 1509-a's sentence in code.md §7
names both literals, beside the element body, as multi-sibling slots. Ruled: the engine follows the
ruled text — one item per yield in both literals, nesting spelled explicitly, `(0, ([?for …]))` —
so one contributor rule holds in every multi-item slot; fixture first (the two measured cases as
red-then-green); the readers that relied on the nesting are SCANNED first across the corpora, the
bundled modules and the reference programs, the count reported on the board before the rewrite
starts, and every site rewritten in the same round (the YIELD-1 shape). Rejected: (a) narrowing the
sentence to the element body — a second rule for one directive, the kind of surprise cx exists to
remove; (c) refusing an unspliced comprehension in a literal — loud but needless.

## BARE-1 — a bare head is data, namespaced or not; `$` is the only call sigil (L84 = (a))

cx-private #1694: a bare `[alias:name …]` head is evaluated as a call of the imported module's def
when `alias` is an imported module (`[capabilities [strings:upper 'a']]` → `[capabilities 'A']`
under the import, data without it); the primer says a bare head is data and `$` marks the call; an
inline authz grant naming `sync:reseed` called it (SYNC 2a). #1700 (code.md contradicting itself on
bare-name calls) and #1664 (a bare-head call with a `[cast]` argument evaluating to data silently)
are the same cluster. Ruled: the evaluator follows the primer — a bare head builds data, namespaced
or not, and `[$alias:name …]` is the one call spelling; fixture first (the two reproductions); the
corpora and the bundled modules scanned for bare namespaced heads that relied on the call, the count
reported, every site rewritten with `$` in the same round; #1700's contradiction and #1664's silent
case resolved under the same sentence. Rejected: (b) documenting the namespaced bare head as a call
form — a second spelling, and data becoming a call the day an import is added; (c) refusing the
ambiguity — a namespaced data element unable to coexist with an import of that alias.
