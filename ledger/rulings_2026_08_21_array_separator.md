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
