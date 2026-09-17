# Audit record — the diagnostics corpus census over every registered CXER code (2026-09-17)

Decision: **RULED: CXF-3** (`ledger/rulings_2026_09_17_cx_first_1522.md`) — the decision
itself is declared there; this page is its audit record. Issue:
cx-home/cx-private, the "cx first" epic (1522). Branch:
`impl/cx-F-diagnostics-audit`, base `d4d62ad9a`.

Tool: `scripts/diagnostics_census.cx`, a CX program — the audit of the
diagnostics corpus is itself written in the language it audits (the epic's
first row). Step: `make diagnostics-census`, NOT in `TEST_TARGETS` on this
branch: the census reports, and the mutation-tested gate belongs to the fix
batches this page proposes. Document: `_gate_evidence/diagnostics_census.cxd`
(784 `[code]` rows, one `[band]` row per §9.6 range, five `[silent]` rows).

The census line, which `_gate_evidence/pipeline_cxf3/RESULTS.md` quotes:

> `diagnostics census: 784 codes registered; 688 emitted; 8 covered; 599 weak; 176 no-case; 5 silent`

**Eight codes of seven hundred and eighty-four have a graded case that tells a
writer what was refused, where, and what to do next. That is one per cent.**

## What was measured, and how

The universe is every code observed in the tree — emitted in `vcx/**/*.v`
(minus `vcx/target/`) with `//`-comment text stripped, or in `stdlib/*.cx`
with `#`-comment text stripped, or ASSERTED by a `conformance/**/*.cxd` case
— plus every code a `governance.md` §9.6 row names singly in its code column.
The three definitions are the bash predecessor's (`scripts/cxer_registry_report.sh`)
and were reused rather than re-derived, sparse-list parentheticals included: a
`(sparse: …)` list REPLACES a row's body, an `(… excluded/reserved …)` one
subtracts from it.

An ASSERTION is a case section that pins a refusal — `out-err`, `out-text`,
`out-multiset`, `expected-refusal`, `expect-diff`. A code named in a `meta`,
`doc`, `tags` or `in-code` section is a mention, not an assertion.

Each assertion is judged on the LINE of its expectation body that carries the
code — not the whole body, so a code buried in program output is judged on
what the reader actually sees beside it:

| column | yes when the expectation … |
|---|---|
| FORM | names the construct that was refused — a bracketed directive or verb spelling, a backticked spelling, or a symbolic `E_*` name beside the code |
| POSITION | carries `line:col`, or an `opened at L:C` site |
| FIX | says what the writer does next (one of twenty-five guidance phrases: `expected `, `use `, `instead`, `did you mean`, `grant via`, `must be`, `to keep`, `filter by`, …) |

A code's row answers yes on a column when ANY of its cases does. The class is
`silent` when the run answers a value or an absence where a refusal is due
(the five ruled classes below), else `no-case` when no case asserts the code,
else `weak` when no single case answers all three columns, else `covered`.

`position-carrier` records how a code's diagnostic delivers position TODAY,
read from its emission sites (the site is read together with the line above
it, so a constructor call split over two lines is classified).

## The one finding behind every number

**The err-value lane carries no position at all.** `vcx/cx/error.v` is sixteen
lines: `CxError{message, line, col}` and `msg()` = `'${line}:${col}: ${message}'`
— so the READER lane (the data parser, the program lexer/parser) carries
position, in the MESSAGE TEXT, and `vcx/cx/parser.v:221` appends the
`(unterminated <head> opened at L:C)` chain to it. Everything else raises
through `mk_err` / `mk_err_attrs` (`vcx/code/eval.v:9800`), and that builds
`[result status=err code=… message=…]`: two attributes, no `line`, no `col`,
no `where`. There is no position for a case to assert, which is why the
POSITION column is `no` on 762 of 784 rows.

| position-carrier | codes | what it means |
|---|---|---|
| `message-text` | 39 | the reader lane — `L:C: ` prefix, `opened at L:C` chain |
| `attribute` | 2 | `CXER0108`, `CXER4952` — a site writing a `line=`/`col=` attribute |
| `none` | 282 | an err VALUE (`mk_err`), or a code nothing emits |
| `unknown` | 461 | a site the rule cannot read — a code named inside a table, a help string or a test assertion |

The other two columns are barely better: 159 rows answer FORM yes (20%), 38
answer FIX yes (5%), 22 carry a position on any case (3%).

## Reconciliation with the bash predecessor

`sh scripts/cxer_registry_report.sh` at the same tree: **791 distinct codes
emitted/asserted, 84 registered ranges, every emitted code registered.** The
census's universe is **784**. The difference is seven codes and is fully
accounted for, not a disagreement to settle later:

`CXER4552`, `CXER4560`, `CXER4561`, `CXER4949`, `CXER6599`, `CXER6699`,
`CXER6809` appear in corpus text ONLY inside a non-assertion section (a `meta`
note, a `doc` block, a `tags` line); the predecessor greps raw bytes and
counts them, the census does not call a mention an assertion. `CXER9999` is
excluded by both. No code is in the census and not in the predecessor's set —
the registry singles added nothing new. The census's own `[band]` rows count
84 registry rows' ranges the same way.

## The silent classes — first, because a silent wrong answer is the one outcome the posture forbids

| id | code | issue | state | what the run does |
|---|---|---|---|---|
| SILENT-1 | none | 1531 | pinned (`program-err-017…019`) | `[?if]` whose condition is an err value takes NEITHER branch |
| SILENT-2 | none | 1529 | fixed | `cx lint` arbitration reported the DATA-lane diagnostic and hid the program-lane failure |
| SILENT-3 | `CXER0301` | 1436 | open | `cx fmt` names the FIRST comment rather than the one it could not place |
| SILENT-4 | none | 1521 | merged at `d4d62ad9a`, closes on that run | the data parser swallowed the cases after a `[title]` holding an apostrophe |
| SILENT-5 | none | 1537 | open, owner letters pending | an err bound by `[?let]` to a name nobody reads is swallowed |

Four of the five have **no refusal code at all**, which is the defect rather
than an omission in the table: there is nothing for a case to assert, so the
fix is a code and its case together. `CXER0301` is the exception and it has
class `silent` and `cases=0` — the formatter's own declined-refusal code is
asserted by nothing.

SILENT-5 was met twice while this tool was written. Both times an err bound to
a name the program never reads made a whole section of the census come back
empty with exit 0 and no diagnostic, and both times the way to see it was to
make the value the program's ANSWER. That is the shape of the defect, from the
inside.

## No case at all — 176 codes, by band

`CXER1700–CXER1712` heads the list on purpose: its ten uncovered codes are
emitted by live shipped code while §9.6 declares the band retired. Filed as
its own issue (see below).

| band | owner | no-case | codes |
|---|---|---|---|
| `CXER1700–CXER1712` | CXStore Remote Protocol (retired in §9.6, live in the tree) | 10 | 1701, 1702, 1703, 1705, 1706, 1707, 1708, 1710, 1711, 1712 |
| `CXER3400–CXER3412` | `cx-stdlib/io` | 13 | 3400…3412, the whole band |
| `CXER4500–CXER4524` | `cx-platform/net` | 19 | 4502…4524 less 4501, 4510, 4519 |
| `CXER4525–CXER4589` | `cx-platform/http` | 16 | 4526, 4527, 4528, 4529, 4530, 4534, 4536, 4542, … |
| `CXER5000–CXER5049` | XSP generic layer + store profile | 16 | 5010…5017, 5018, 5020, … |
| `CXER4000–CXER4013` | `cx-stdlib/process` | 12 | 4000, 4002…4007, 4009, … |
| `CXER4920–CXER4949` | `cx-stdlib/fabric` | 10 | 4924…4930, 4934, … |
| `CXER1100–CXER1149` | `cx-platform/store` | 9 | 1113, 1115, 1116, 1131, 1132, 1140, 1142, 1143, … |
| `CXER4850–CXER4889` | `cx-xap` subsystem | 8 | 4855, 4859, 4860, 4863, 4876, 4881, 4888, 4889 |
| `CXER4600–CXER4649` | `cx-platform/journal` | 6 | 4600, 4602, 4604, 4605, 4608, 4617 |
| `CXER5700–CXER5799` | `cx-platform/smtp` | 5 | 5700, 5704, 5705, 5707, 5714 |
| `CXER6000–CXER6099` | `cx-platform/sso` | 5 | 6008, 6009, 6010, 6011, 6012 |
| `CXER0100–CXER0299` | CX language core | 4 | 0132, 0135, 0244, 0273 |
| `CXER4700–CXER4799` | `cx-platform/authz` | 4 | 4707, 4708, 4709, 4716 |
| `CXER5800–CXER5899` | `cx-platform/imap` | 4 | 5800, 5805, 5807, 5814 |
| `CXER6300–CXER6399` | `cx-platform/connector` | 3 | 6309, 6314, 6320 |
| `CXER3700–CXER3721` | `cx-stdlib/crypto` | 2 | 3704, 3716 |
| `CXER4650–CXER4699` | `cx-platform/bus` | 2 | 4650, 4661 |
| `CXER4800–CXER4849` | `cx-platform/session` | 2 | 4800, 4849 |
| `CXER4950–CXER4969` | cross-stream coordination | 2 | 4958, 4964 |
| `CXER4970–CXER4989` | `cx-stdlib/sched` | 2 | 4970, 4975 |
| `CXER5090–CXER5109` | `cx-stdlib/supervise` | 2 | 5092, 5095 |
| `CXER5500–CXER5599` | `cx-stdlib/tar` | 2 | 5501, 5504 |
| one code each | `CXER0001–0009` 0003 · `cx fmt` 0300 · jsonschema 1610 · CSRP 1720, 1721 · random 1900 · prof 2102 · test 2201 · env 2504 · format 2700 · mime 2802 · time 3325 · term 3451 · module-cx 4104 · xap-dist 4892 · store/journal sync 5051 · zip 5205 · oidc 5300 | 17 | — |

The full list, with each code's emission files, is in the census document.

## The eight covered codes

| code | band | cases |
|---|---|---|
| `CXER0001` | generic-core panic | 25 |
| `CXER0100` | CX language core | 278 |
| `CXER3100` | `cx-stdlib/json` | 2 |
| `CXER4852` | `cx-xap` subsystem | 16 |
| `CXER4920` | `cx-stdlib/fabric` | 5 |
| `CXER4952` | cross-stream coordination | 9 |
| `CXER4990` | `cx-core/consistency` | 10 |
| `CXER6701` | `cx-platform/sftp` | 4 |

`CXER6701` is the interesting one: `sftp` has no implementation yet and emits
nothing, and its corpus — written with the spec, before the module — is the
only band where a code was given form, position and fix from the start. The
shape to copy is there, in `conformance/platform/sftp.cxd`.

## Every band

`codes` is the band's observed codes; `emitted` those with at least one
emission site; `m-text` those whose position-carrier is `message-text`.

| band | owner | codes | emitted | covered | weak | no-case | m-text |
|---|---|---|---|---|---|---|---|
| `CXER0001–CXER0009` | Generic-core panic | 2 | 2 | 1 | 0 | 1 | 2 |
| `CXER0100–CXER0299` | CX language core | 79 | 79 | 1 | 74 | 4 | 25 |
| `CXER0300–CXER0309` | `cx fmt` | 2 | 2 | 0 | 0 | 1 | 0 |
| `CXER1100–CXER1149` | `cx-platform/store` | 21 | 21 | 0 | 12 | 9 | 0 |
| `CXER1200–CXER1205` | `cx-stdlib/ft` | 6 | 6 | 0 | 6 | 0 | 0 |
| `CXER1300–CXER1306` | `cx-stdlib/email` | 7 | 7 | 0 | 7 | 0 | 0 |
| `CXER1400–CXER1403` | `cx-stdlib/url` | 4 | 4 | 0 | 4 | 0 | 0 |
| `CXER1500, 1502–1504` | `cx-stdlib/csv` | 4 | 4 | 0 | 4 | 0 | 0 |
| `CXER1600–CXER1609` | `cx-stdlib/validate` | 7 | 7 | 0 | 7 | 0 | 0 |
| `CXER1610–CXER1619` | `cx-stdlib/jsonschema` | 1 | 1 | 0 | 0 | 1 | 0 |
| `CXER1700–CXER1712` | CXStore Remote Protocol | 11 | 11 | 0 | 1 | 10 | 0 |
| `CXER1720` / `CXER1721` | CSRP integrity / not found | 2 | 2 | 0 | 0 | 2 | 0 |
| `CXER1800–CXER1801` | `cx-stdlib/uuid` | 2 | 2 | 0 | 2 | 0 | 0 |
| `CXER1900–CXER1906` | `cx-stdlib/random` | 7 | 7 | 0 | 6 | 1 | 0 |
| `CXER2000–CXER2005` | `cx-stdlib/hash` | 6 | 6 | 0 | 6 | 0 | 0 |
| `CXER2100–CXER2103` | `cx-stdlib/prof` | 4 | 4 | 0 | 3 | 1 | 0 |
| `CXER2200–CXER2203` | `cx-stdlib/test` | 4 | 4 | 0 | 3 | 1 | 0 |
| `CXER2300–CXER2307` | `cx-stdlib/bytes` | 8 | 8 | 0 | 8 | 0 | 0 |
| `CXER2400–CXER2405` | `cx-stdlib/log` | 5 | 5 | 0 | 5 | 0 | 0 |
| `CXER2500–CXER2504` | `cx-stdlib/env` | 5 | 5 | 0 | 4 | 1 | 0 |
| `CXER2600–CXER2603` | `cx-stdlib/path` | 3 | 3 | 0 | 3 | 0 | 0 |
| `CXER2700–CXER2702` | `cx-stdlib/format` | 3 | 3 | 0 | 2 | 1 | 0 |
| `CXER2800–CXER2804` | `cx-stdlib/mime` | 5 | 5 | 0 | 4 | 1 | 0 |
| `CXER2900–CXER2904` | `cx-stdlib/strings` | 4 | 4 | 0 | 4 | 0 | 0 |
| `CXER3000–CXER3003` | `cx-stdlib/math` | 4 | 4 | 0 | 4 | 0 | 1 |
| `CXER3100–CXER3106` | `cx-stdlib/json` | 7 | 7 | 1 | 6 | 0 | 0 |
| `CXER3200–CXER3203` | `cx-stdlib/re` | 4 | 4 | 0 | 4 | 0 | 2 |
| `CXER3300–CXER3349` | `cx-stdlib/time` | 12 | 12 | 0 | 11 | 1 | 2 |
| `CXER3400–CXER3412` | `cx-stdlib/io` | 13 | 13 | 0 | 0 | 13 | 0 |
| `CXER3450–CXER3459` | `cx-stdlib/term` | 2 | 2 | 0 | 1 | 1 | 0 |
| `CXER3500–CXER3504` | `cx-stdlib/locale` | 5 | 5 | 0 | 5 | 0 | 0 |
| `CXER3600–CXER3605` | `cx-stdlib/geo` | 6 | 6 | 0 | 6 | 0 | 0 |
| `CXER3700–CXER3721` | `cx-stdlib/crypto` | 20 | 20 | 0 | 18 | 2 | 0 |
| `CXER3800–CXER3805` | `cx-stdlib/i18n` | 5 | 5 | 0 | 5 | 0 | 0 |
| `CXER3900–CXER3902` | `cx-stdlib/html` | 3 | 3 | 0 | 3 | 0 | 0 |
| `CXER4000–CXER4013` | `cx-stdlib/process` | 14 | 14 | 0 | 2 | 12 | 0 |
| `CXER4100–CXER4119` | module-cx | 20 | 20 | 0 | 19 | 1 | 1 |
| `CXER4400–CXER4409` | `cx-stdlib/fp` | 1 | 1 | 0 | 1 | 0 | 0 |
| `CXER4500–CXER4524` | `cx-platform/net` | 21 | 21 | 0 | 2 | 19 | 2 |
| `CXER4525–CXER4589` | `cx-platform/http` | 28 | 22 | 0 | 12 | 16 | 0 |
| `CXER4600–CXER4649` | `cx-platform/journal` | 29 | 29 | 0 | 23 | 6 | 0 |
| `CXER4650–CXER4699` | `cx-platform/bus` | 7 | 7 | 0 | 5 | 2 | 0 |
| `CXER4700–CXER4799` | `cx-platform/authz` | 17 | 17 | 0 | 13 | 4 | 0 |
| `CXER4800–CXER4849` | `cx-platform/session` | 18 | 18 | 0 | 16 | 2 | 0 |
| `CXER4850–CXER4889` | `cx-xap` subsystem | 33 | 33 | 1 | 24 | 8 | 4 |
| `CXER4890–CXER4899` | `cx-xap` distribution | 3 | 3 | 0 | 2 | 1 | 0 |
| `CXER4900–CXER4901` | `cx-stdlib/similar` | 2 | 2 | 0 | 2 | 0 | 0 |
| `CXER4902–CXER4919` | `cx-xap` subsystem | 5 | 5 | 0 | 5 | 0 | 0 |
| `CXER4920–CXER4949` | `cx-stdlib/fabric` | 17 | 17 | 1 | 6 | 10 | 0 |
| `CXER4950–CXER4969` | cross-stream coordination | 10 | 10 | 1 | 7 | 2 | 0 |
| `CXER4970–CXER4989` | `cx-stdlib/sched` | 6 | 6 | 0 | 4 | 2 | 0 |
| `CXER4990–CXER4999` | `cx-core/consistency` | 2 | 2 | 1 | 1 | 0 | 0 |
| `CXER5000–CXER5049` | XSP generic + store profile | 22 | 22 | 0 | 6 | 16 | 0 |
| `CXER5050–CXER5069` | store/journal sync | 4 | 4 | 0 | 3 | 1 | 0 |
| `CXER5070–CXER5089` | `cx-platform/live` | 9 | 9 | 0 | 9 | 0 | 0 |
| `CXER5090–CXER5109` | `cx-stdlib/supervise` | 6 | 6 | 0 | 4 | 2 | 0 |
| `CXER5200–CXER5299` | `cx-stdlib/zip` | 6 | 6 | 0 | 5 | 1 | 0 |
| `CXER5300–CXER5399` | `cx-stdlib/oidc` | 11 | 11 | 0 | 10 | 1 | 0 |
| `CXER5400–CXER5499` | `cx-stdlib/saml` | 18 | 18 | 0 | 18 | 0 | 0 |
| `CXER5500–CXER5599` | `cx-stdlib/tar` | 5 | 5 | 0 | 3 | 2 | 0 |
| `CXER5600–CXER5699` | `cx-stdlib/scim` | 9 | 9 | 0 | 9 | 0 | 0 |
| `CXER5700–CXER5799` | `cx-platform/smtp` | 15 | 15 | 0 | 10 | 5 | 0 |
| `CXER5800–CXER5899` | `cx-platform/imap` | 16 | 16 | 0 | 12 | 4 | 0 |
| `CXER5900–CXER5999` | `cx-stdlib/sasl` | 4 | 4 | 0 | 4 | 0 | 0 |
| `CXER6000–CXER6099` | `cx-platform/sso` | 13 | 13 | 0 | 8 | 5 | 0 |
| `CXER6200–CXER6299` | `cx-platform/audit` | 9 | 9 | 0 | 9 | 0 | 0 |
| `CXER6300–CXER6399` | `cx-platform/connector` | 31 | 30 | 0 | 28 | 3 | 0 |
| `CXER6400–CXER6499` | `cx-platform/sync` | 17 | 1 | 0 | 17 | 0 | 0 |
| `CXER6500–CXER6599` | `cx-stdlib/graphql` | 12 | 0 | 0 | 12 | 0 | 0 |
| `CXER6600–CXER6699` | `cx-stdlib/soap` | 16 | 0 | 0 | 16 | 0 | 0 |
| `CXER6700–CXER6799` | `cx-platform/sftp` | 17 | 0 | 1 | 16 | 0 | 0 |
| `CXER6800–CXER6899` | `cx-platform/ftp` | 16 | 0 | 0 | 16 | 0 | 0 |
| `CXER6900–CXER6999` | `cx-stdlib/ws` | 12 | 0 | 0 | 12 | 0 | 0 |

Ninety-six codes are asserted by a case and emitted by nothing — `graphql`,
`soap`, `sftp`, `ftp`, `ws` and most of `sync`, the bands registered WITH their
spec and corpus before their module. Their cases are the audit's cheapest
lesson: a case written beside the spec tends to carry the form and the fix,
because the writer is reading the error table while writing it. Not one code is
emitted, asserted by nobody, AND unregistered — the predecessor's completeness
claim holds.

## Defects filed from this audit

| issue | what | class |
|---|---|---|
| 1543 | a stdlib verb applied to a `[no-match]` refuses with `E_NO_CALLABLE` naming a callable that does not exist (`"re-group"`) — the diagnostic points at the verb, never at the argument, and carries no position; `cx lint` accepts it | a diagnostic that points elsewhere (the epic's trap row) |
| 1544 | the retired `CXER1700–CXER1712` CSRP band is still emitted by live code — 11 codes, 20 sites, 5 files, no graded case; the registry and the binary disagree on a shipped wire | registry vs. tree |

No silent wrong answer was found beyond the five already-ruled classes, so
nothing here is filed `prio:high`.

## Proposed fix batches

**Proposed, not decided** — the integrator turns rows into briefs. Each batch
is at most six codes, fixture first, in the shape a batch branch already has
(a `test(N)` / `fix(N)` commit pair per code, one pipeline, one merge naming
every issue). Ring 0 first; the silent classes are batch 1. The batches that
add a case to a code with no refusal text to assert MUST add the refusal text
in the same batch — a case pinning `cx-err:CXERnnnn` and nothing else is what
this audit measured, and repeating it would move a row from `no-case` to
`weak` and call it progress.

| batch | ring | codes / classes | what the batch does |
|---|---|---|---|
| D1 | 0 | SILENT-1, SILENT-2, SILENT-3 (`CXER0301`), SILENT-4, SILENT-5, `CXER0300` | the silent classes: each gets the refusal it owes, its code where it has none, and a case naming form, position and fix. `CXER0300`/`CXER0301` are the formatter's own and are asserted by nothing today |
| D2 | 0 | `CXER0003`, `CXER0132`, `CXER0135`, `CXER0244`, `CXER0273`, `CXER0136` | the language core's four uncovered codes plus the RE2 shim's, and `CXER0136`'s misleading message (issue 1543) |
| D3 | 0 | `CXER0271`, `CXER0101`, `CXER0290`, `CXER0291`, `CXER0233`, `CXER0104` | the highest-traffic weak codes of the core band — `CXER0271` alone is asserted by 283 cases, none of which names the grant, the effect or the flag |
| D4 | 0 | the `L:C` carrier itself | the change every later batch depends on: an err value carries its position. Today `mk_err` builds `code=` and `message=` and nothing else, so 762 rows CANNOT answer the POSITION column. Spec sentence first, then `mk_err_attrs`, then the batches below can assert a position at all |
| D5 | 1 | `CXER3400`…`CXER3405` | `cx-stdlib/io`, first half — the whole band is uncovered and it is the band a new writer meets first |
| D6 | 1 | `CXER3406`…`CXER3412` (six of seven) | `cx-stdlib/io`, second half |
| D7 | 1 | `CXER4000`, `CXER4002`…`CXER4006` | `cx-stdlib/process`, first six of twelve |
| D8 | 1 | `CXER4007`, `CXER4009`, and the band's remaining uncovered | `cx-stdlib/process`, the rest |
| D9 | 2 | `CXER1700`-band, six of ten | blocked on issue 1544's decision — a retired band gets no cases until the owner says whether the emissions or the registry sentence is the defect |
| D10 | 2 | `CXER4502`…`CXER4507` | `cx-platform/net`, first six of nineteen |
| D11 | 2 | `CXER4508`…`CXER4513` | `cx-platform/net` |
| D12 | 2 | `CXER4526`…`CXER4534` (six) | `cx-platform/http`, first six of sixteen |

Thereafter, one batch per band in the order of the no-case table, at most six
codes each: `net` (7 left), `http` (10 left), XSP `CXER50xx` (16), `fabric`
(10), `store` (9), `xap` (8), `journal` (6), `smtp` (5), `sso` (5), `authz`
(4), `imap` (4), `connector` (3), then the twelve bands with one or two each,
which fold into two mixed batches. That clears the `no-case` class in
twenty-nine batches. The `weak` class — 599 codes — is not batch work at that
rate; it is the mutation-tested gate's, and the gate is what stops a new code
from arriving weak. The gate belongs to the batch that first makes a band
fully covered, so `io` (D5, D6) is where it should land first: change one
diagnostic's text or position, and its case fails.

## What this branch did not do

No spec edit, no code fix, no corpus case: this is the audit. `make
diagnostics-census` is the step the batches pin; it is deliberately outside
`TEST_TARGETS` here, because a census that fails a build before the batches
run would fail it 776 times.
