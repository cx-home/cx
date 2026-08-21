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
