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

---

# TME-1 is SUPERSEDED — its premise was FALSE (recorded 2026-08-22)

**Do not implement TME-1 as written.** It was authorized on a claim I made
that turns out to be wrong, and the correction is recorded here rather than
by editing the ruling above, so the mistake stays visible.

**The false claim.** I told the owner the glued-key syntax space was free —
"`{a::int}` and `{a::int: 5}` are clean parse errors today, so nothing is
reinterpreted." That was tested only through the PROGRAM reader, which
errors. The DATA reader's `read_map_key` (vcx/cx/parser.v) deliberately
absorbs a glued `::` as the **key's own** postfix scalar ascription — landed
2026-08-05 in `a7de7583` (#516/#684/I1 row-1, "postfix value ascription,
strict carriers, decimal/bigint canonical forms"), lexicon L43/L47.
Measured: `{1.10::decimal: x}` → rc=0, decimal key; `{42::bigint: y}` →
rc=0, round-trips with its ascription; `{a::string: 5}` → rc=0, key `a`
ascribed string. TME-1 would have SILENTLY REDEFINED that construct.

**What is actually true, and it is smaller than TME-1 assumed.** CX already
has BOTH type slots in the grammar:

- **Key type** — `[L87] MapKey ::= Ident | QuotedText | Scalar`, plus the
  L43/L47 postfix ascription. IMPLEMENTED and working, single and multiple
  entries.
- **Value type** — `[L86] MapEntry ::= MapKey S? ':' S? BodyItem`, and
  `[53] BodyItem` includes `Scalar`, and `[27] Scalar ::= TypeAnnotation S
  ScalarValue` ("explicit scalar in any context"). So `{a: ::int 5}` is
  ALREADY LEGAL GRAMMAR. It is NOT implemented: the parser returns the
  string `'::int 5'`.

So value typing is an unimplemented spec provision, NOT a missing feature,
and it needs NO grammar change. `{a: ::int 5}` and
`{1.10::decimal: ::string "x"}` are what the spec already admits.

**The only genuinely missing capability** is a field declared with a type
and NO value (`{a: ::ref}`), because `[27]` requires `TypeAnnotation S
ScalarValue`. That is exactly what `spec/03-approved/xap/xap.md`'s props
maps want, and it is the ONE piece that would need a new production. The
owner was asked and has NOT yet answered.

**Therefore the work splits three ways:**
1. Implement `[27] Scalar` in value position (map values, array items,
   sequence items). Pure bug fix against the spec as written — NO spec
   change, NO new ruling needed.
2. Fix #917's silent mangling — a parse that cannot represent its input must
   REFUSE it, never invent a different document. NO spec change.
3. The declaration-only entry `{a: ::ref}` — OPEN, needs the owner's letter.

**The named spec authorization TME-1 claimed is NOT exercised** and does not
carry forward: nothing in `spec/03-approved/` was edited under it.
