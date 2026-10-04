# Integrator decisions 2026-10-04 ~05:3xZ — Letters 182 to 185 (CORE1's and H1's adversarial-reader findings), each taken at the recommended (a) under the owner's standing delegation as the rounds that implement them launch

**Status: RULED BY DELEGATION (DELEG-3; the owner confirmed the shape the same night: "sounds reasonable, if each is what's best for cx long term"). The letters are numbered on the board (#1591, 05:3xZ) with this page's ids; the owner reverses any by reading. TDUR-1, TMPD-1, QUAL-1, REFUTE-1, NEWB-1, RS-38, AGENTS.md rule 1 (the spec is the only truth).**

## The owner's words, verbatim

"make best long term decisions for cx. no deferring. no partial work." (DELEG-3, 2026-09-30); "2 sounds reasonable, if each is what's best for cx long term" (2026-10-04 ~04:4xZ, on the eight takings before these).

## DEQ-1 — a duration is equal to another by value, and `[cast d :int]` answers its nanosecond count (Letter 182 = (a); cx-core-code#46)

A duration scalar carried its literal text and `=` compared it structurally, so `[= 1s 1000ms]` and `[= 90m 1h30m]` were false, and since TDUR-1 `[= [$time:parse-duration '90m'] 90m]` too; `[cast 1s :int]` refused although time.md §1 says duration refines int. Taken: equality and the ordered comparisons read the value; the cast answers the nanosecond count; the canonical form and the hash keep the literal's text as written (identity is the data ring's — the round measures and flags whether two spellings hash apart). Rejected: (b) normalizing literals at read (the written text is the document's); (c) leaving both, documented.

## DIVZ-1 — `duration-div` by zero answers CXER3305 E_TIME_DURATION_DIV_ZERO, as time.md §5's table says; time-053 moves with it (Letter 184 = (a); cx-core-code#45)

The code answered CXER3304 (overflow) and the enforced case time-053 was blessed to it, so the case and the spec disagreed; a gate-enforced case flips only under a ruling — this is it. Rejected: (b) the table row moved to 3304 (the spec follows the code).

## TMPW-1 — `temp-file` and `temp-dir` judge the path they create against the granted write roots; `system-temp-dir` stays under the read grant (Letter 183 = (a); cx-core-code#47)

The three temp primitives had no path argument for `--allow-write=PATH` scoping to judge, so `temp-dir` created a directory under `--allow-read` alone, and since TMPD-1 the directory is TMPDIR's choice. Taken: the created path is judged against the write roots (CXER0271 naming the path and the flag); `system-temp-dir`'s answer is a path, not a secret, and stays under `read`. Rejected: (b) an env grant required when the answer came from TMPDIR (a grant for reading a path the program may then write to); (c) nothing.

## IDSH-1 — the ledger indexer refuses an id-shaped token it cannot parse, and the historical owner-letter shape becomes a parsed shape (Letter 185 = (a); #1767)

`scripts/ledger_index.cx --check` skipped a `RULED:` token outside its id regex silently ("0 subject ids, all resolve", exit 0) — `CAPADDR-1`, `zzqx-9`, `D99z9`. Taken: an id-shaped token the regex does not parse is refused by name (exit 1, the token and the subject quoted); the owner-letter shape `D<digits><letter>[<digit>]` (D70a1, D59a — hundreds of historical subjects) joins the parsed shapes and resolves against the pages that declare it. Rejected: (b) widening to any token (every word a candidate id); (c) leaving the skip (a typo in a RULED id passes forever).
