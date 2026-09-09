# RULED: 1347-a — the `cx fmt` fingerprint hashes an integer's canonical §2.5 image, EXCEPT under a text-coercing ascription

**Fable, 2026-09-09 04:20 ET, on worker A's letters (question 2), under the
owner's delegation:** `2(a)` — `shape_src_image` receives the ascription in
scope for the literal; a text-coercing `::T` keeps hashing the raw
`ProgramLiteral.src`, everything else hashes the canonical image. MEDIUM.

Refused: `2(b)` unconditional canonical hashing (silently rewrites a value);
`2(c)` leaving the whole underscore class fail-closed (leaves `canonical.md:210`
operative for the emitter and inoperative for `cx fmt`, which is the bug
report).

## What was wrong

`canonical.md:210` (§2.5, Integer row): *"No underscores in canonical output
(underscores in source are stripped)."* The EMITTER already obeyed it —
`cx_int_image` (`vcx/cx/program_emit.v:1424`) renders from `int_val`, and
`.bigint_lit` carries an already-normalized `str_val` — so `1_000` emitted
`1000` and `0x1_f` emitted `0x1f`, both correct §2.5 images.

What declined the file was `prog_shape_of`, which hashed the RAW token (#1328,
because a `::T` ascription coerces from the source TEXT). Re-parsing the
emitter's own correct output gave `src = "1000"` against the original
`"1_000"`, so the fingerprint reported a meaning change that had not happened
and `faithful_program_fmt` returned the file untouched. The fingerprint was
disagreeing with the rule the emitter was already implementing, and that
disagreement was the whole defect.

This is #1347's **half 1**. Half 2 (the float image: §2.5's exponent-always
`1.5e0` against the shipped `1.5`, via the Ring-0 `cx_format_float`) is a
separate, unruled question and is untouched here — `.float_lit` and
`.decimal_lit` keep hashing the raw token.

## The exception, and it is MEASURED rather than argued

Under a text-coercing ascription the raw token IS the value. On the shipped
binary at `f056246c1`:

```
[note::string 1_000]   ->  '1_000'    five characters
[note::string 1000]    ->  '1000'     four
[rec n::string=1_000]  ->  n='1_000'  the D3 ATTRIBUTE form too ([L50])
[n::decimal 1_000]     ->  1000       identical to [n::decimal 1000]
[xs::[] (1_000, 2)]    ->  (1000, 2)  items keep their own auto-type
[rec n=1_000]          ->  n=1000     an untyped attribute normalizes
```

**And the danger is reachable, not theoretical.** A comment-free file takes the
DATA candidate in `fmt_source_lane`, which copies a number token verbatim and
preserves the value by accident; a comment-bearing file takes
`program_source_with_comments`, whose candidate comes from the PROGRAM emitter.
Measured at `f056246c1`:

| input | verdict |
|---|---|
| `[?let [= $x  [note::string  1_000]]  $x]  # note` | DECLINED |
| `[?let [= $x  [note::string  1000]]   $x]  # note` | FORMATTED |

so the underscore is the *whole* reason for the first decline — i.e. the program
lane is the lane reached there. Built with the ascription test disabled (the
refused `2(b)`) and re-measured:

```
in   [?let [= $x  [note::string  1_000]]  $x]  # note
out  [?let [= $x [note::string 1000]] $x]  # note
     value before:  [note::string '1_000']
     value after:   [note::string '1000']

in   [?let [= $x  [rec n::string=1_000]]  $x]  # note
out  [?let [= $x [rec n::string=1000]] $x]  # note
     value before:  [rec n='1_000']
     value after:   [rec n='1000']
```

`cx fmt` silently changing a value. That is what the exception buys, and
`conformance/fmt.cxd` fmt-031 plus
`program_emit_head_ascription_test.v:test_a_text_coercing_ascription_keeps_the_raw_token`
pin it from both sides. Relying on "the data lane usually wins" would have been
accidental safety.

## The text-coercing set, enumerated from the type table

The ruling requires the set be read off the table rather than guessed. The
PROGRAM reading's table is `coerce_typed_scalar_text`
(`vcx/code/eval.v:1652`) — the one place a `::T` body ascription turns a token
into a value; the DATA reading's twin is `coerce_scalar` / `coerce_scalar_strict`
(`vcx/cx/parser.v:3917` / `:4034`) and its arms agree. Spec basis:
`spec/03-approved/formal/lexicon.ebnf:441` [L25d] — *"`::T` (SCALAR type) → the
body is ONE scalar of T; the entire body text is coerced to T … `string` always
coerces (it is text)"*.

**Normalizing — the token's spelling is discarded, so the canonical image may
be hashed:**

| type names | arm |
|---|---|
| `int` `i8` `i16` `i32` `i64` `u8` `u16` `u32` `u64` | `try_coerce_int_token` — underscores stripped |
| `float` `f16` `f32` `f64` | `try_coerce_float_token` — underscores stripped |
| `decimal` `bigint` | `try_coerce_base10_verbatim_token` (#466 item 4: "underscores stripped, type-tagged") |
| `bool` | `txt == 'true'` — the token is compared, not kept |
| `null` | a `NullValue` constant — the token is discarded |
| *(empty)* | **no ascription in scope**: a bare literal, an untyped attribute, or the inferred-element `::[]`, whose items keep their own auto-type (@CHOICE-1 §9 slice C). Auto-typing strips underscores. |

**Text-coercing — everything else, and the polarity is the point:**

| type names | arm |
|---|---|
| `bytes` `date` `datetime` `duration` `period` `atom` | store `txt` VERBATIM |
| `string`, **and every unrecognised name** | the table's `else` arm *is* the string arm |

`ascription_normalizes_number_spelling` is therefore an explicit allowlist with
a fail-closed default: a type name nobody has classified keeps hashing the raw
token. A new scalar type added to the table without a thought here costs a
decline, never a corrupted value.

## Where the ascription comes from

`shape_node_asc` / `shape_nodes_asc` thread it; only the `ProgramLiteral` arm
reads it.

* A glued head `::T` / `::T[]` governs the **body** ([L25d]), so it reaches
  every body literal. `ascription_scalar_type` takes `T` from both spellings and
  `''` from `::[]`.
* A literal with no annotation of its own passes the governing one through — a
  sequence or array literal under `[xs::i64[] (1_000, 2)]` is not itself
  annotated and its members are what `i64` coerces.
* An **attribute** is governed by its own D3 ascription and never by the
  element's head annotation, which coerces the body. `[note::string b=1_000 "s"]`
  leaves `b` untyped, so `b` normalizes while the body would not.
* Every other node kind DROPS it. An ascription on a call or directive coerces
  that form's RESULT; the argument literals inside keep their own rules —
  `coercion_source_text` (`vcx/code/eval.v:1623`) takes a literal's `src` and a
  computed value's rendered text.

## Declared limits, named rather than left to be discovered

1. **Upper-case hex still fails closed.** `0x1F`: §2.5 wants `0x1f`, the emitter
   writes `0x1f` correctly, and the fingerprint still sees `0x1F` against the
   re-parse. The ruling names this as out of scope — it needs its own §2.5
   letter-case decision. Pinned as `test_upper_case_hex_still_fails_closed`.
2. **A malformed grouping stays fail-closed.** `strip_underscores`
   (`vcx/cx/parser.v:3581`) returns none for `_1` / `1_` / `1__0`, so the raw
   token is hashed. `1__0` in fact refuses at parse (`CXER0100`), which is also
   fail-closed.
3. **`.float_lit` and `.decimal_lit` are untouched.** `1_000.5` still declines
   (half 2). `[a n=1_000d]` still formats and KEEPS the underscore — a wrong
   IMAGE rather than a decline, recorded on #1347 and out of scope here.
4. **`::string[]` / `::i64[]` over a sequence body are separately broken**, found
   while measuring and not touched: `[xs::string[] (1_000, 2)]` answers
   `[xs::string[] '']` and `[xs::i64[] (1_000, 2)]` raises `CXER0290: cannot
   coerce `` to i64`. Both spellings behave identically, so nothing here rides on
   it; it is an array-ascription materialization defect, not a fmt one.

## The two gate-enforced expectations this INVERTS

Both were deliberate tripwires against this change, and both were right to be
there. The ruling's DELETES section named the first; the second was found by a
corpus pre-flight over `vcx/**/*_test.v` and is recorded here as an addendum,
because it states the same superseded limit in a second place.

1. `vcx/cx/program_emit_head_ascription_test.v` —
   `test_a_non_canonical_integer_spelling_still_fails_closed` loses its `1_000`
   and `0x1_f` rows to fmt-028 / fmt-029 and keeps `0x1F`, which is now
   `test_upper_case_hex_still_fails_closed`. Its comment is rewritten, not
   deleted: it was the best account of the constraint in the tree, and the
   rewritten version carries the reachability argument the fixture ids cannot.
2. `vcx/tests/codecs_formats_umbrella_test.v` —
   `test_fmt_still_fails_closed_when_a_numeric_spelling_cannot_be_reproduced`
   was pinned with `[n 1_000]` on the reasoning that `1_000` is "the case the
   emitter cannot reproduce". That was wrong about the emitter, not about the
   property: `cx_int_image` reproduces `1000` correctly and only the fingerprint
   disagreed. The property is kept and re-pinned on upper-case hex (`[n 0x1F]`),
   and `test_fmt_formats_a_bare_underscored_integer` takes the old input from
   the other side.

## Fixtures (`conformance/fmt.cxd`), each measured RED at `f056246c1` where it claims to be

| id | input | claim |
|---|---|---|
| fmt-028 | `[?let [= $x  1_000]  $x]` | formats to `1000` — RED before |
| fmt-029 | `[?let [= $x  0x1_f]  $x]` | formats to `0x1f`; pins BOTH §2.5 integer rules at once, so it cannot be satisfied by getting either one alone right — RED before |
| fmt-030 | `[?let [= $x  999_999_…_999]  $x]` | the `.bigint_lit` arm, a different parser arm from fmt-028 — RED before |
| fmt-031 | `[?let [= $x  [note::string  1_000]]  $x]  # note` | fails closed; GREEN before and after, RED under the refused `2(b)` — a guard, and that is its job |
| fmt-032 | `[?let [= $x  [n::decimal  1_000]]  $x]` | formats; without it the exception could be satisfied by declining every ascribed file — RED before |

Registry pre-flight over 87 refs (every `origin/impl/*`, the tip, every local
branch): `fmt-028/029/030` appear only on the abandoned `impl/cx-A-1347`, whose
fixtures these are; `fmt-031/032` free.

## The corpus effects, measured rather than assumed

* **`examples/vcore.cx` still declines byte-identically.** It carries 13
  ascribed underscored literals (`::i64` `::u32` `::u64` `::f64` `::decimal`) and
  was the highest-value manual check: its `::f64` / `::decimal` rows are
  `.float_lit` / `.decimal_lit`, which this change does not touch, so the file
  keeps declining and none of the 13 is rewritten.
* `conformance/code.cxd` `program-body-ascription-013-decimal-underscores` and
  `conformance/extended.cxd` `016j-attr-decimal-underscores` pin
  strip-under-`::decimal` in the EVALUATOR; consistent with `decimal` being
  classified normalizing, and unmoved.
* `scripts/fmt_corpus_expected_errors.txt`'s `tooling/vscode/test/grammar/basic.cx`
  entry **stays**. Its `CXER0100 invalid temporal literal '0o17'` is an OCTAL
  literal — the same §2.5 family, a different gap — and this change does not
  reach it, so the roster line is not stale.
* `FMT_SWEEP_MAX_DECLINED` is lowered in this landing, per the one-way-ratchet
  convention the Makefile states: whoever lowers it edits the number down in the
  same landing.
