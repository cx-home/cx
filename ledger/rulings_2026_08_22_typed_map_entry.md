# Ruling 2026-08-22 — the typed map entry (#917 + the xap fences)

**Status:** AUTHORIZED by the owner ("That looks good. approved.",
2026-08-22) against the proposal below, which was put with its grammar
diff, its examples, and its three disambiguation rules. Recorded BEFORE
the work per R6.1. This ruling carries NAMED SPEC AUTHORIZATION: it
changes `spec/03-approved/formal/lexicon.ebnf` [L86] and the fences in
`spec/03-approved/xap/xap.md`, both of which the standing rule otherwise
forbids touching.

## TME-1 — a map key is a declaration site, so it takes the glued annotation

**The finding.** There is no way to type a map entry, and every attempt
degrades SILENTLY: `{a: ::int 5}` yields the string `'::int 5'`,
`{a ::int}` yields the atom `{a: :int}`, and `[p {a ::int c: 3}]` collapses
the whole map into one string value at exit 0 (#917). Meanwhile
`spec/03-approved/xap/xap.md` DOCUMENTS typed component props
(`{props: {order: ::ref  compact: ::bool}}`) in a form the language never
admitted and now rejects outright — which is why `verify-doc-blocks`, a
`release-verify` row, is red.

**The rule.** `[L86]` gains the annotation, exactly as `[55] Attribute`
already has it — same glue token, same position, only the map's `:`
separator where an attribute writes `=`:

    [L86] MapEntry ::= MapKey TypeAnnotation? S? ':' S? BodyItem
                     | MapKey TypeAnnotation
                     | ComputedEntry

`TypeAnnotation` is the existing `[L50]`, unchanged.

    {a: 5}                      untyped field with a value      (unchanged)
    {a::int: 5}                 field a, declared int, value 5
    {a::int}                    field a, declared int, value ABSENT
    {a::string[]: ["x", "y"]}   array-typed field
    {"my key"::int: 5}          quoted key, typed
    {a::int, b::bool}           two declared fields, no values

**Why the key and not the value.** Every other site in CX that declares a
name with a type glues it: element head `[p::int 3]` ([51]), attribute
`[p x::int=5]` ([55]), table column `[table[id::int]]` ([29b]), function
parameter `$x::int` ([153b]), bind pattern `_::int` ([140g]). A map key is
the one such site that did not follow the spine. Orthogonality is a stated
CX objective, and this adds NO new concept — it moves an existing token
into the one position that lacked it. The syntax space is free: `{a::int}`
and `{a::int: 5}` are clean parse errors today, so nothing is reinterpreted.

**The three disambiguation rules.**
1. `::` is GLUED to the key. `{a ::int}` is REFUSED, not read as a
   declaration — and specifically not silently degraded to the atom
   `{a: :int}`, which is today's behaviour.
2. The `:` stays required whenever there IS a value. `{a::int 5}` refuses:
   whitespace is not a separator here, matching `[L85]`, which admits
   commas only.
3. A declaration-only entry means the value is **ABSENT, not null**. CX
   already polices that distinction with its own gate
   (`check-null-absence-conflation`), so `{a::int}` declares the field and
   asserts nothing about a value — precisely what a props/schema map means.
   Declaration-only entries are legal in ANY map literal: restricting them
   to "schema position" would need a notion of schema position the grammar
   does not have, and consumers can decide what an absent value means.

**Rejected alternatives, with reasons.**
- *Type the VALUE via `[27] Scalar` (`{a: ::int 5}`)* — leaves the
  props/schema case with no home, and does not match the glued spine. Worth
  noting `[27]`'s space-separated form attaches a type in NO collection
  position today (array item, sequence item and map value all stringify it;
  element body errors), so implementing it is a separate question.
- *Both forms* — two ways to say overlapping things, against orthogonality.
- *No types in map literals; a separate schema surface* — larger design, and
  it strands the approved xap spec's own example.

**Out of scope, fixed independently:** #917's silent mangling. Whatever the
syntax, a parse that cannot represent its input must REFUSE it rather than
invent a different document. That is not contingent on this ruling.

**Also disclosed:** the parser today accepts whitespace-separated map
entries (`{a: 1 b: 2}` → `{a: 1, b: 2}`) which `[L85]` never admitted —
commas only. That divergence is noted here so the implementer decides it
deliberately rather than preserving it by accident.
