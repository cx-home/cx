# Ruling CXP-1 (2026-08-20) — the [?cx] pragma key set closes (#879, owner "4a")

Grammar [34] carried "Unknown attributes are accepted and round-trip
verbatim — the attribute set is open by design." That clause is RETIRED:
an unaccepted key riding along verbatim is the silent-acceptance class
the language refuses everywhere else — demonstrated by
`[?cx output-target=html]` passing inert while documentation taught it
as context-aware escaping (an XSS footgun for anyone who trusted it).

RULED: the registry is CLOSED — include | schema | version |
lint-disable | lint-enable. `version` earns its slot as reader-facing
declared metadata (grammar-sanctioned; its consumer is the reader, not
the engine). The retired schema pragmas (schema-of/schema-name/
schema-mode/frag) stay parse-tolerated solely to reach the S009
schema-load diagnostic. `output-target` is RESERVED with a named refusal
("not implemented — output is not escaped by it") until context-aware
escaping ships as a real feature. An unknown key is a parse-time typed
refusal naming the registry. Timing: pre-cut, deliberately — CX has no
external users yet, so this is the cheapest the closure will ever be.
Cutover-first: the pass-through-pinning fixtures (inc-003,
program-cx-pi-003, eval_semantics bogus test) flip to pin the refusal;
the diagram test's decorative `scope=` key swaps to a registry key.

## ENT-1 rider — attribute-position entity references (#878, corrected)

The 4a letter proposed refusing entity syntax in attribute values. That
recommendation was WRONG and is corrected here rather than implemented:
quoted strings are verbatim by design EVERYWHERE, and attribute values
legitimately contain entity-shaped substrings (`href="?a=1&amp;b=2"`);
refusing them would reject real data. RATIFIED instead: the shipped
model is already coherent — entity references are recognized in BARE
body runs only; quoted strings (body or attribute) are verbatim; the
XML emitter's `&`-escaping of literal attribute text is CORRECT escaping
(it round-trips byte-exactly), not corruption. #878 re-scopes to its one
real defect: the XML emitter drops the inter-item separator between
adjacent bare body items around an EntityRef ('Cheese &amp; Pepper' →
'Cheese&amp;Pepper' in XML text), a fidelity bug independent of this
ruling.
