# Rulings 2026-08-21 — whitespace is an item separator in array literals (#903)

## ASP-1 — one rule for array-literal items, with no exceptions

**Status:** RULED (owner "b", 2026-08-21), on the option set posed after
#894 was disproved and #903 filed in its place.

**The rule.** Inside an ARRAY literal, **whitespace separates items**. A bare
scalar ends at whitespace; a following `(`, `[` or `{` begins a new item. This
was already true of all-bare runs — `[1 2 3]` is three ints, byte-identical to
`[1, 2, 3]` (measured) — and ASP-1 makes it true universally.

**What was broken.** The slot reader treated a whitespace-separated
heterogeneous run as ONE item, so an array item followed by a parenthesized
group collapsed the array to a single element and mangled the leading value
differently per type:

| written | before ASP-1 |
|---|---|
| `[1 (2, 3)]` | one item: the STRING `'1 '` (trailing space) plus a sequence |
| `[true (2, 3)]` | an element named `true` (the element/array branch, correct but confusing) |
| `[$g (2, 3)]` | one item; the binding projects to `null` |
| `[1 (2)]` | REFUSED — `expected , or ] in array literal` |

Three wrong shapes and a refusal from one construction, all silent, and the
corrupted form round-trips stably — so canonicalization could not reveal it and
the wrong value would take a legitimate content address.

**Why (b) and not the surgical (a).** (a) — fix only the paren case — removes
the corruption but keeps "whitespace separates, except after a comma", which is
the inconsistency that made the bug possible. The owner's standing directive is
that surface rules get settled inside this window rather than becoming
per-engagement migration cost, and (b) is the version that states in one
sentence and leaves nothing to re-litigate.

**Cost accepted with the ruling.** A multiword bare scalar inside an array
literal must be quoted: `['hello world']`, not `[hello world]`. Corpus reach was
to be MEASURED before landing, and the measurement reported — not silently
re-blessed.

**Not in scope.** Element parsing (`[name …]` stays an element — `[true (2,3)]`
is an element named `true`, which is correct), the comma-makes-a-sequence rule
for `(…)`, sequence and map slots.

## ASP-1a — the same fault at the TOP LEVEL (#906)

Found while verifying the playground with the engine actually running: the
page showed a sequence example as a quoted string, and the page was right.
The DATA reader returned the STRING `"(1, 2, 3)"` for a whole-document
`(…)`, while the SAME bytes read as a sequence nested in an element body and
evaluated as a sequence by the PROGRAM reader — three readings of one
literal, the odd one silent and stable under canonicalization, so it would
have taken a legitimate content address.

Cause: the top-level dispatch had a branch for a `{…}` map literal
(`peek_is_map_literal_at_brace`) and none for `(…)`, so a parenthesised run
fell to the bare-text path. Fixed by giving sequences the branch maps
already had, guarded the same way — a comma-less `(x)` still falls through
to text, per the rule ASP-1 recorded.

Corpus: the #906 change moved NO counts (no corpus document opens with a
top-level `(…)`). The single baseline movement in this landing (+1 total,
+1 cx_only, 827→828) is ASP-1's own new conformance case, which the data
reader accepts and the program reader declines — recorded in the baseline
comment with that reason rather than re-blessed.

## ASP-1 REVERTED (2026-08-21, same day) — the uniform rule collides with mixed-content slots

The implementation of ASP-1 shipped and then failed the full suite in four
lanes. Root cause: a comma-delimited array slot is ALSO how CX code
directives carry mixed content —
`[?if [@stock > 0, In stock: [?=@stock], out of stock]]` is a three-slot
array whose middle slot is a SequenceNode of text + interpolation. ASP-1's
"whitespace separates items" made that slot's parts separate array items,
so the directive read four slots instead of three.

Both behaviors are wanted and they are not distinguishable by the rule as
ruled: `[1 (2, 3)]` should be two items, while `In stock: [?=@stock]` must
stay one. The parser changes are therefore REVERTED in full (the slot
reader's flag, the comma-optional array loop, and the paren-at-slot-head
branch), along with the conformance case and the corpus baseline movement
that pinned them.

**#903 is therefore REOPENED**, and the ruling needs re-posing with this
evidence: option (b) as stated is not implementable without also deciding
what happens to mixed-content slots, which the option set did not consider.
The surgical option (a) — leave the comma rule alone and only stop a
whitespace-preceded `(` from being absorbed into the preceding scalar — was
not affected by this collision and remains available.

**ASP-1a (#906) is UNAFFECTED and stays landed:** the top-level sequence
branch is in the document dispatch, not the slot reader, and all four lanes
are green with it in place.

## ASP-2 — RULED (owner "b", 2026-08-21): the discrete-token array, plus the slot-fill rule

**Status:** RULED, on the measured decision packet posted to #903
(issue comment, prototypes measured at a8152a52: corpus buckets identical,
0/827 per-input render hashes moved on either reader, cli_umbrella /
code_units_umbrella / xap_umbrella / code_eval_fixtures green, oriel lane
green — under BOTH candidates). Supersedes ASP-1, which is dead: its
carve-outs (bare text coalesces; text + `[…]` coalesce; glued runs stay one
item) reduce exactly to this rule.

**The rule, in one breath.** No comma: whitespace separates discrete values.
Comma: commas separate slots. Inside a slot, whitespace never separates —
structure whitespace-adjacent to anything refuses; glued runs are one item.

**Precisely:**

1. **Discrete-token array (the (b) half).** A comma-less bracket whose 2+
   whitespace-separated tokens are ALL discrete values — typed scalars,
   quoted strings, `$name` holes, `[…]` nodes, and now `(…)` sequence
   literals and map-shaped `{…}` — is an array of those values.
   `[1 (2, 3)]` is two items: the int and the sequence. A structure span
   counts as a token only when whitespace-delimited on both sides (the
   glued-span refinement: `[(1, 2)[0]]` keeps its historical one-item
   mixed reading). A bare-Name first token keeps the element reading —
   `[true (2, 3)]` stays the element `true` (the ASP-1 scope note stands).
   A bareword anywhere else keeps the whole bracket prose/comma-path —
   `[(1, 2) three]` is NOT an array of two.
2. **Slot-fill (the (a) half).** Within one collection slot (array item,
   sequence item, map value — the comma-delimited positions), a sequence or
   map literal may not be WHITESPACE-adjacent to any other content: loud
   CXER0100 naming the fix (add the comma, or quote the prose). GLUED runs
   remain one mixed-content item — CXPath kind tests (`$c/node()`, fmt-013)
   and call shapes live glued mid-slot and keep parsing byte-identically.
3. **Untouched:** text + `[…]` mixed content in slots (directive rendering);
   body/args position (already separates structures — `[?zip]`,
   `[$cx:propose]`, the oriel `[$opt]` carrier); the element-vs-array
   dispatch; ASP-1a.

**Costs accepted with the ruling (measured, named):**
- `(1, (2, 3) (4, 5))` — right-by-accident glue (wrapper flatten) — now
  refuses; the author writes the comma. Zero corpus reach.
- Prose slots carrying a comma-bearing parenthetical (`[1, weight (kg, lbs)]`,
  `[?if [@x, use (a, b) now, else]]`) now refuse loudly; the author quotes.
  Zero corpus reach; glued parentheticals unaffected.

**Riders landing under this ruling:** grammar.ebnf [56b] drops the stale
ASP-1 paragraph (the 3f3e02f6 revert missed the spec hunk — the approved
spec asserted a rule the parser did not implement) and its `position.`
splice artifact, replaced by the ASP-2 statement; lexicon [L83] states the
headless typed-list array (implemented since @CHOICE-1, never written down)
and the discrete-token extension; conformance cases pin the packet's syntax
table; the corpus-diff baseline movement those NEW CASES cause is recorded
with its cause (fixture additions, not parser drift); the element-body
`[k 1 (2, 3)]` int→string mangle is filed as #909 (body prose lane — same
corruption signature, different position, needs its own reading; options
posed there).
