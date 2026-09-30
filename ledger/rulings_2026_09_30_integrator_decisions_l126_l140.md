# Integrator decisions 2026-09-30 — Letters 126 to 140, taken under DELEG-3: the eleven design issues and the three bugs that needed a decision, and the sftp module's SSH transport, each at the long-term-best option

**Status: RULED BY DELEGATION (the owner, 2026-09-30 ~04:0xZ, in session: "no decisions for at least
8hrs … make best long term decisions for cx. no deferring. no partial work" — DELEG-3; the fourteen
letters were drafted by an opus agent from the issues and measurements on `a2100a8b3`, read by the
integrator, and posted on [#1591](https://github.com/cx-home/cx-private/issues/1591) at 04:1xZ with
their options, consequences and the taking; the owner may reverse any of them on reading). SHIP-1,
FIX-1, RS-38, CXF-5, CXF-8, 1099-a, RS-26, 1173-b, 1174-a/b, 1545-a, 1329-a, 1190-a, RP-5, RP-6,
TRIAGE-1, SEC-1.**

## The owner's words, verbatim

"no decisions for at least 8hrs. pause if limits are hit and resume when lifted. make best long term
decisions for cx. no deferring. no partial work. only complete, sound, performant implementation that
follows the expectations"

## TREEP-1 — `cx_code_tree` projects the parsed tree (L126 = (a); #1041)

Measured: `cx code-tree` projects `[doc a, b]` as three scalars with `,` among them, an entity ref as
text plus a scalar `&`, a `[?def]` body with `(` and `)` as scalars; abi.md §2.16.3 names six D2 kinds
and none of these. Taken: the projection owes the parsed tree — a comma body one node of N items, an
entity ref decoded, a directive body as the program reader reads it, a comment its own node; the D2
kind list gains array and comment, §2.16.3 says so with the oracle table's cases (RS-38). Rejected:
six kinds with the rest mapped to text (structure the parser holds hidden); a token view by design
(one source, two readings). One opus round, Ring 0 cx-core-data.

## ERRSF-1 — #1062 closes on 1099-a; CO-19's `--errs=refuse` is withdrawn (L127 = (a))

Measured: a computed `[err]` at any depth already exits 1 with one stderr line naming its path
(1099-a); `--errs=refuse` is an unknown flag. Taken: the flag would be a second spelling of the
default; #1062 closes on the measurement. Rejected: a stricter mode withholding stdout; the inverse
flag (reopens the silent-data shape).

## MEXA-1 — `sign`, `round`, `truncate`, `clamp` and `gcd` answer exactly on decimal and bigint (L128 = (a); #1070)

Measured: `[$math:round 2.5]` refuses CXER3002 while `[$math:floor 2.5]` answers `2` and the core
`[$round 2.5]` answers `3`; math.md §4.4 calls the delegation "an open design item". Taken: the five
answer exactly as their core twins do, §4.4's list names ten verbs, `div-decimal` joins §3's table,
fixtures first in `math.cxd` (RS-38). Rejected: pinning the split (two spellings, two answers);
refusing all ten (breaks shipped `[$math:abs 2.50]`). One small opus round, Ring 1 cx-core-code, with
SETB-1's branch.

## REPRM-1 — W8's measurement runs in v0.18 and its finding is fixed in v0.18 (L129 = (b), amended by SHIP-1; #1119)

Measured: `bench/repr` pins json 7.569× and xml 7.941× against RP-5's bounds; a rough peak-RSS run on
the integrator's own 300k-record corpora, once each under load, read about 34× (JSON) and 41× (XML)
against the ≤ 8× bar. Taken: one measurement round on the audit's own corpora (`/usr/bin/time -l`,
Stage-0, RP-5's attribution of pacer share against representation share); #1119 closes on that number
when the bar is met, and when it is not, RP-6's trigger has fired and its representation round (shared
record maps, columnar arrays) lands in v0.18 under SHIP-1 — nothing moves to v0.19 (TRIAGE-1's
relabel of #1207 is superseded for this item). Rejected: closing on W1–W7 with the bar unmeasured;
holding #1119 with no measurement first.

## RLOAD-1 — the R2.2 release step loads each staged library (L130 = (a); #1131)

Measured: `r22_profile_payload` checks presence by glob; nothing loads the library; the prerequisites
(`cx_codec_inventory`, #1129's mask fix) exist. Taken: R2.2 loads each staged library through the
extraction step's probe and compares `cx_codec_inventory` and `cx_features` with the build's own, a
dry run against the current staged artifacts first. Rejected: a round trip through the staged `cx`
(the library never loaded); the presence check kept. One opus round, cx-private + the cx-core-code
probe, before the cut relies on it.

## WASMC-1 — the wasm wall-sleep and asyncify controls stay in Ring 1; abi.md names all four controls with their ring (L131 = (a); #1132)

Measured: the arena pair is in cx-core-data's `cabi.v`, the sleep pair in cx-core-code's; the sleep
flag's only reader is the evaluator's `new_env()`. Taken: split by meaning, abi.md lists the four with
their ring and says a Ring-0 wasm build carries the two memory controls. Rejected: moving the pair to
Ring 0 (a seam with no consumer in its ring); no change. One small sonnet round, cx-core-data, abi.md.

## KEYV-1 — the declarable key vocabulary stays bound to 1190-a's trigger; #1199 is the one item put to the owner at the cut (L132 = (b); #1199)

Measured: `xap_grammar_composition.md` §4 says the vocabulary "is deliberately not specified here";
no composition in the tree meets the trigger (a two-party composition proving what one key means —
inferred). Taken: 1190-a stands; the format depends on a second publisher that does not exist; the
issue is presented to the owner at the cut as the one v0.18 item needing their word to leave (SHIP-1:
one by one, never a page). Rejected: designing the artifact now (a format frozen before its second
party); `from=pkg:` as an unverified citation.

## EDMAP-1 — 1329-a's edit-map step reads each path's owning repository (L133 = (a); #1329)

Measured: no `scripts/ledger_edit_map_check.cx`, no target, no `release-process.md` row; the edit
maps' targets live under `deps/<repo>` since the split. Taken: the step reads a path's pinned history
under `deps/` for its `landed` rows and refuses `pending` at the cut; the checklist row as 1329-a words
it. Rejected: the front door only; withdrawing 1329-a. One opus round, cx-private, fixtures first,
mutation-tested.

## ERRAT-1 — 1545-a's paused branch is ported onto cx-core-code (L134 = (a); #1545)

Measured: err values carry no `at=`; `origin/impl/cx-F-batch-a5` (paused 09-19, `458e27a88`) holds
1545-a's §9.1 sentence, five fixtures and four closed gaps, unmerged. Taken: port those commits with
the paths rewritten, finish its pre-merge steps and the 139 re-blessed ids, merge. Rejected: a fresh
re-implementation (the four gaps rediscovered); v0.19 (762 of 784 codes cannot say where). One opus
round, Ring 1 cx-core-code.

## SETB-1 — `cx-stdlib/set` takes the ten-block `CXER7100–7109` (L135 = (a); #1173)

Measured: `CXER7000–7099` is `cx-platform/secrets`' band (SEC-1); nothing is registered from
`CXER7100` to the sentinel; map's non-scalar key refusal is the core CXER0100. Taken: a ten-block, a
non-scalar member refusing CXER0100 exactly as `map:entry` does, the governance band row in the
`set.md` 1173-b decided. Rejected: a hundred-block; borrowing map's band. One opus round, Ring 1
cx-core-code, the module and its manifest touchpoints, with SETM-1 and MEXA-1.

## SETM-1 — one refusal code for "the closure reached a bound in force", naming the bound (L136 = (a); #1174)

Taken: `max-rounds` and `max-size` breaches answer one typed refusal whose message names which bound
and its value — 1174-b's own reason applied to both. Rejected: a code per bound; dropping `max-size`.
Rides SETB-1's round.

## FABT-1 — the standby-delivery panic is the test's defect, not the fabric's (L137 = (a); #1506)

Measured: the test waits 1 s for B's quiet check against a 1500 ms liveness window; the sweeper (every
250 ms) deposes a holder silent past the window when a sibling waits, as fabric.md §13 requires;
under load more than 1.5 s passed (inferred, not reproduced). Taken: the test asserts §13 — A pings
through the quiet check, or the check runs under the boot window — with a delayed-ping case showing
the spec's failover first; no product change. Rejected: a second liveness check at delivery; a
serial-retry roster row. One small opus round, cx-platform-fabric, in the platform bug batch.

## INCL-1 — program-time includes are judged by the granted roots (L138 = (a); #1556)

Measured: `cx:resolve-includes` charges `read` but the granted roots do not judge the path — with
`--allow-read=/tmp`, root `/etc` still read `hosts`; security.md §2 puts `[?cx include]` in `read`'s
row judged by allowed roots. Taken: the CLI's `--include-root` pass stays on the caller's authority
(1061-a (5)); the program-time forms go through #1539's single admission function, the refusal naming
the grant to add; §5's include line gains one clause with the case ids (RS-38). Rejected: charging the
program for the caller's argument; the yes/no check kept (the fail-open class of #1539). One small
opus round, cx-core-data `include.v` + cx-core-code cases, in the Ring-0 bug batch.

## SSHL-1 — the sftp module's SSH transport is libssh2 behind the V fork, mbedtls its crypto backend (L140 = (a); #1457)

#1457 (1430-c) says the choice is taken before code: (a) a vetted C library behind the fork — the
mbedtls precedent, a `v_fork_register.cxd` row, the wasm stub rule — or (b) an SSH transport written
in V over `net` and `crypto`. Taken: (a) libssh2 with the mbedtls backend the fork already carries —
one crypto stack, a vetted key exchange, cipher and MAC implementation, the version pinned and its
licence named in the round's SCAN.md. Rejected: (b) a fresh SSH implementation — a security-critical
protocol whose every primitive would be ours to get right, for no gain the library does not give;
(c) an external `ssh` binary through `process` — an effect the capability table cannot scope to a
host and a path. The module stays out of the data and embed wasm builds (platform group), so the
stubs cover only the symbols the linker sees.

## SOAPV-1 — #1595 closes on RS-26 (L139 = (a))

Measured: connector.md and `connector.cxd` spell `version='1.1'` (25 cases, no `:1.x`); the atom
grammar still refuses `:1.1`, unchanged by RS-26. Taken: closed as fixed; atoms stay identifiers.
Rejected: admitting `:1.1` as an atom (a Ring-0 identity change for a spelling no spec uses); holding
the issue as a reminder.
