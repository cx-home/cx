# Ruling 2026-08-22 — the map-syntax settlement (#917)

**Status:** RULED by the owner ("1a 2a 3a 4a-ii 5a 6a. Be sure to update
docs and examples as well", 2026-08-22) against the settlement letter at
`design/917/map_syntax_letter.md` (posed @ eb2ad4bc, examples + Q5 revision
@ 953a8064). Recorded BEFORE the work per R6.1. This ruling carries NAMED
SPEC AUTHORIZATION for: `spec/03-approved/formal/lexicon.ebnf` ([L85],
[L86], the [L83] slot note where it speaks about map slots),
`spec/03-approved/formal/grammar.ebnf` (the [27] re-scope and the [157]
KindName cross-reference), `spec/03-approved/xap/xap.md` (the four fence
sites), and the consequential corrections in approved spec prose, docs,
guide sources, and examples that the settlement makes false — each edit
citing this ruling.

The letter's Part 2 defect list (D1–D8) and Part 3 empirical constraints
are incorporated by reference; every exhibit there was measured against a
clean rebuild at 97847a9c.

## MSS-1 (= letter Q1a) — map values are expression-shaped; prose is quoted

A map VALUE is one discrete expression-shaped item in BOTH readers — the
program reader's existing rule becomes the language's. Unquoted prose in a
map value is a LOUD refusal whose message names the fix (quote the prose).
Single bare tokens remain values (`{status: active}`). This is the only
basis on which "refuse, never invent" is achievable: while free prose is a
legal value, a missing comma IS legal prose. Corpus blast radius accepted:
one fixture line (conformance/yaml.cxd:345 class). Arrays and sequences
KEEP their body-slot prose semantics ([L83] 2a) — this ruling narrows map
values only.

## MSS-2 (= letter Q2a) — entries separate by comma OR whitespace, both readers

[L85] is amended: `MapEntryList ::= MapEntry ((S? ',' S?) | S) MapEntry)*
(S? ',')?` in intent — commas and whitespace/newlines both separate,
matching the array precedent (`[1 2 3]` ≡ `[1, 2, 3]`) and the 715 shipped
usage sites. Unambiguous because MSS-1 makes every value a complete
expression. The data reader adopts the program reader's loop shape (entry,
optional comma, next entry); its former absorb-as-prose behavior dies with
MSS-1.

## MSS-3 (= letter Q3, all seven confirmed) — refuse, never invent

1. ALL ascription coercion arms are CHECKED — bool/string/date/datetime/
   bytes/instant/secret join the numeric arms' loud CXER0290; no arm falls
   through to unchecked coercion. `{x: prose ::bool}` refuses instead of
   inventing false.
2. The postfix split applies to single ws-free tokens only, never to a
   coalesced prose run (applies to array/sequence slots too — the invention
   dies there without disturbing legal prose slots).
3. `{a ::int}` refuses loudly, the message naming all three constructions:
   key type `{a::int: …}`, value type `{a: 5::int}`, atom value `{a: :int}`.
   Byte rule: after a map key, `::` is never the entry separator. `{a : 5}`
   (spaced single colon) stays legal.
4. A bare `::`-carrying token in a collection slot either ascribes (valid
   tag, conforming payload) or refuses (CXER0107 unknown tag / CXER0290
   nonconforming payload) — it NEVER silently becomes text. Consequence,
   ratified: `{a: std::vector}` refuses; write `{a: 'std::vector'}` (zero
   corpus hits).
5. Quoted keys follow the same ascription rules as bare keys — identity is
   (kind, image), so `{'1.10'::decimal: x}` ≡ `{1.10::decimal: x}` and
   `{'k'::int: 5}` is a loud CXER0290, never the shipped mangle. A quoted
   VALUE followed by glued `::` also refuses (no silent two-item sequence).
6. The top-level program→data fallback stops swallowing FAILED program
   parses: in a program entry point, a map that fails the program read
   reports the program error. The data reading remains the data reading for
   data entry points; the deliberate data-seam constructs (program reading
   IS the data reading) are unaffected — this closes the error hatch, not
   the seam.
7. Reader parity: the data reader accepts double-quoted keys; a valid
   ascription on ANY key kind behaves identically in both readers
   (accept + coerce-check + normalize, annotation-iff-retyping — extending
   the data reader's ident-key behavior to the program reader).

## MSS-4 (= letter Q4a + Q4b-ii) — the declaration-only entry

[L86] gains the alternative: a prefix TypeAnnotation as the SOLE value
means DECLARED, VALUE ABSENT — `{name: ::string}`. Three `::` positions,
one meaning each: glue types the key (shipped L47), postfix types the value
(shipped L43), prefix-alone declares (new). `{a: ::int 5}` STAYS a loud
error — the prefix takes NO value; typed values are postfix only, so [27]'s
prefix-scalar alternative is RE-SCOPED in the grammar (it is implemented in
no position and contradicts TA-1 in element bodies; the map-entry
declaration is now the one home of the prefix spelling). Absent is NOT
null, per the standing check-null-absence-conflation gate. Declarations are
legal in any map literal.

The declaration tag vocabulary is [157] KindName (+ optional `[]` suffix)
— the vocabulary bind patterns [140g] already use for exactly this meaning:
scalars plus element/sequence/map/iterator/array/document/text/scalar-node/
comment/pi/directive/function/path/any/number and the [157a] refinements.
A declaration is a kind CONSTRAINT, not a coercion.

## MSS-5 (= letter Q5a, the revised recommendation) — xap's `ref` is spelled honestly

The props kind in xap.md is spelled from core kinds: `{order: ::string}`.
The prop carries an entity id (a string) — the fence's own bind line
compares `$props/order` to `@/id` — and the REFERENCE semantics is already
declared by the `bind:` arm itself. No `ref` enters [L51], [157a], or the
codec table; no atom vocabulary is introduced.

## MSS-6 (= letter Q6a) — the fences

xap.md block #3 gains `# verify-skip` (it fails on a literal `…` ellipsis
placeholder — a deliberately illustrative fragment, unrelated to maps).
Blocks #5 and #10 are respelled per MSS-5 and parse under MSS-1/2/4 once
the implementation lands. Block #6 is REWRITTEN to the ruled spelling
(`[props {order: ::string  compact: ::bool}]`) — its current spaced-glue
form passes the fmt-based gate while silently mangling to `{order: false}`.
The gate-design gap (verify-doc-blocks verifying with the most permissive
of three readers) is a named follow-up, not part of this settlement.

## Owner rider — docs and examples

"Be sure to update docs and examples as well": every doc, guide source, and
example that teaches a spelling this settlement changes (unquoted prose map
values, `::ref`, commas-only claims, any `{a: ::T v}` prefix-value
teaching) is swept and corrected in the same campaign, verified by
verify-doc-blocks + the guide build.

## Implementer decisions recorded under this ruling (findable, not silent)

- **Lossy-target image of a declaration-only entry:** REFUSES (JSON/YAML/
  CSV/TSV have no absent-field image and `null` would conflate) — the
  ANC-1 dangling-on-lossy-lanes precedent. Round-trip CX/XML lanes carry it.
- **Value reads of a declared-absent entry** behave as ABSENT (the #584
  presence-predicate semantics); the declaration itself is visible in the
  canonical image and the AST.
- **Movement protocol:** PROTO_CANON_OUT corpus differential + the golden
  sweep, movement predicted before measuring, legitimate movement stated
  with its cause (DR-8).

---

## MSS-7 — the prefix family completes: `::T VALUE` types the value (RULED "1a", 2026-08-22, same day)

**Supersedes one clause of MSS-4** ("`{a: ::int 5}` STAYS a parse error —
the prefix takes no value"), recorded as a rider, the original left
intact. **The evidence that forced it**: testing the rebuilt playground,
the owner reached for `{age::int: 30}`, then `{age: :int 30}`, then
`{age: ::int 30}` — three consecutive type-BEFORE-value spellings, zero
attempts at the ruled postfix. The surface was fighting its own
designer's instincts.

**The rule.** In a collection VALUE slot (map value; array/sequence item
for uniformity), a prefix `TypeAnnotation` followed by ONE scalar value
token is a TYPED VALUE, coercion-checked through the same strict core as
the postfix form — the historical [27] `TypeAnnotation S ScalarValue`
production revived in exactly the positions where no element name
precedes it (so TA-1 is untouched). The prefix family is now one rule:
**`::T` in a value slot — with a value it types the value, without one
it declares the field (MSS-4)**. Declarations stay map-entry-only; a
value-less prefix in an array slot still refuses.

- The tag for a PREFIXED VALUE draws from the scalar tag set
  (is_valid_type_tag); a kind-only tag (`::element`, `::path`, …)
  followed by a value refuses — kinds declare, they do not coerce.
- Slot-initial `::T` COMMITS the slot: exactly one value token (bare or
  quoted) must follow, then the slot ends — trailing content refuses.
- Canonical form is unchanged: annotation-iff-retyping governs, so
  `::int 30` emits `30` and `::decimal 2` emits `2::decimal`. One
  canonical image; two accepted input spellings (prefix + the shipped
  L43 postfix), which is the same acceptance/emit split every annotation
  position already has.
- Both readers implement it identically (the program reading carries the
  coerced scalar via the node_lit seam — the program reading of a typed
  scalar IS the data reading).
- Zero corpus movement by construction: both spellings refused before
  this ruling.

The letter's Part 5 line "`{a: ::int 5}` stays a loud error" and the
MSS-4 fixture pin flip WITH this rider; the diagnostics that taught
postfix-only now teach both spellings.
