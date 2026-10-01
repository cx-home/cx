# Owner decisions 2026-10-01 ~04:2xZ — Letters 153 to 156, "all a": the last four reader-parity exceptions are resolved by one reading for one text

**Status: RULED (owner, 2026-10-01 ~04:2xZ, in session, "all a", after asking "are you sure about
each of these and the recommendations? I'm not seeing any examples" and reading the measured
examples below). Bug batch B (`3361c8a87`), BARE-1, 1559-a, 1559-d, L25c, 1521-a, 1548-c, FMT-2,
CXF-8; #1576, #1578, #1579, #1436, #1745.**

## The owner's words, verbatim

"153-156 I can't believe we're still talking about this at this late stage. are you sure about each of
these and the recommendations? I'm not seeing any examples to help the evalutation" — "all a"

## What was measured on `3361c8a87` (release cx `cx v0.18.0-pre.1-dev+3361c8a87`)

- `[lock full cx.lock — https + file resolvers, other item]`: the data reader answers
  `[lock ['full cx.lock — https + file resolvers', 'other item']]`; the program reader refuses
  `CXER0100: expected ']' (closing element), got cx.lock at 1:27`.
- `[a href=https://github.com/ardec Erik Paulson]`: the data reader keeps the string; the program
  reader refuses "a bare `href=https://github.com/ardec` is read as an expression, where `//` starts a
  CXPath step"; `[a href=//x/y text]` evaluates as a document-rooted query. No file in the tree or the
  pinned corpora writes a bare `attr=//path` as a query (count 0).
- `examples/article.cx` line 28 (`… is shorthand for [code tls=true].`): the data reader reads the
  body as prose with its inline elements; the program reader refuses `expected name after ., got ]`
  (the trailing `.` read as a field step) — a refusal, not a different tree.
- `cx fmt` declines `bench_report.cx` (a comment between the entries of the `{…}` map inside
  `[?const BENCH-CMDS {…}]`, line 91) and `examples/vcore.cx` (a trailing comment on a
  declaration-only map entry, line 41), each named by CXER0301.

## SLOT-1 — a sigil-free multi-token comma slot is prose in both readers (L153 = (a); #1576)

In a whitespace-separated or comma-separated sequence, a slot whose tokens carry no `$`, `?` or `[`
is prose — the data reading — in the program reader too; a slot with a sigil stays an expression.
Why: since BARE-1 a sigil-free run has no call reading, so prose is the only reading that is not a
refusal; `lockfile.cxd` and `yaml.cxd` leave the accepted-by-one table. Rejected: the expression
reading with the files quoted by hand (a permanent exception row); a loud refusal in both readers (a
text the data reader always read becomes an error).

## ATTRU-1 — a bare URL in an attribute value is the data ring's string; a CXPath needs `$` (L154 = (a); #1578)

An attribute value that carries no sigil reads as the data ring reads it, a string typed on read; a
query in an attribute is written with `$` (`href=$doc//x`), as "`$` marks a value or a call" says.
1559-d's expression position stands for sigil-bearing values. Rejected: the CXPath step reading kept
(an attribute reading differently from a body for the same text); refusing the ambiguous value.
`chapter.cx` also refuses on its namespaced attribute name (`xmlns:dc=`), a separate program-reader
defect, #1745, fixed in the same round.

## PROSE-1 — the data reader is the oracle for a prose body (L155 = (a); #1579)

A body is prose when the data reader reads it as text — a sigil-free run that is not one scalar —
and the program reader takes that reading, inline elements included; the parse-refusal trigger of
1559-a is replaced by this rule. Why: the reason for deferring to a refusal (a bareword head might
be a call, decided at eval) is gone since BARE-1; one oracle gives reader parity by construction.
Rejected: a token-shape list (a leading `-`, a trailing `.`) that grows with every case; refusing the
ambiguous bodies.

## FMT-3 — FMT-2 gains the two break sites it lacks; a formatter places every comment it reads (L156 = (a); #1436)

A break site between the entries of a map value inside a directive's value, and one after a
declaration-only map entry's trailing comment; TREE-REFUSED falls from 3 to 0 of 206 and the three
files format. Rejected: the named refusal kept for these shapes (a formatter that declines tracked
files is a partial under AGENTS.md rule 3); moving the comments by hand (the class recurs).

One opus round on cx-core-data (the program reader and the formatter), fixture first, each file
leaving reader-parity's accepted-by-one table with the fix that closes it.
