# Owner decisions 2026-10-13 evening – 2026-10-14 early: PGO-1, LOOPBIN-1, SCALE-1, RACE-1, LOAD-1, the bridges and the quiet mode, YAML/PyYAML/Jinja2 baselines, MYCDC-1

**Status: RULED (owner, via the integrator on STREAMS/state/claims.txt, 2026-10-13 16:29Z – 2026-10-14 02:42Z; recorded by core 10-14 from those RULING lines, verbatim below each heading).** The 83fa250d4 tick's ledger-index-check found `pgo-1` cited with no page; this page carries every owner decision of the evening that a subject cites or will cite. Issues: cx-home/cx-private#1928, #1923, #1925, #1869, #1917, #1927, cx-home/cx-core-code#136, cx-home/cx-examples#319, #320, cx-home/cx-platform-connector#27.

## CSVROW-1 — the csv-aggregate workload program streams its file (csv:rows over io:open), the way Python's csv.DictReader reads it (#1925/#1869)

> RULING owner 2026-10-13T16:29:38Z (via integrator, CSVROW-1 = (a), core's DECISION-ASK 15:58:59Z on #1925/#1869): the csv-aggregate workload program STREAMS (csv:rows over io:open — Python's own algorithm), so the row compares like with like: 22 MB vs Python 14.1 at 2M rows, the remaining gap the collector's floor (gaps2) — core lands the program change on cx-examples (it is the ledger input: the owner's ep-2 regen records it; cx-examples fix/1869-csv-rows is that branch — reconcile with it) and posts the row; shaped record maps (#1925 slice 1) stay open on their own bar (no parse-row cost: the 1 KB parse -19 % must be gone before they land).

## YAML-1 — cx-examples#319/#320 are v0.18 scope for gaps2: cx's YAML parser widens to the corpus's valid YAML 1.2 documents; the bar is Python's YAML library's acceptance on the corpus

> RULING owner 2026-10-13T18:32:31Z (via integrator, YAML-1 = (a), cx-examples#319): in scope for v0.18 — gaps2 widens cx's YAML parser to accept the valid YAML 1.2 documents the corpus names (#319) and fixes #320; the bar is Python's YAML library's acceptance on the same corpus; closes on the landing with the corpus cases green.

> RULING owner 2026-10-13T19:08:19Z (via integrator, PYYAML-1 = (a), gaps2's ASK 18:48:09Z): download PyYAML==6.0.3 from PyPI (one wheel, the hash pinned in cx-examples baseline/requirements.txt — verify the hash) into a scratch venv on /opt/homebrew/opt/python@3.12/bin/python3.12 3.12.15; YAML-1's Python column runs there; state the version on every row.

The integrator's reading within YAML-1's bar (565N-1, not an id the grammar parses; recorded here as prose, cited by no subject):

> RULING integrator 2026-10-13T19:28:20Z (565N-1 = (a), gaps2's DECISION-ASK 19:14:44Z; within YAML-1's bar as written, no reinterpretation — the owner may overrule): cx-examples#320 closes on the YAML landing with 565N recorded on the issue as the ruled bytes reading (conversions.md §0.2), equal to PyYAML 6.0.3's (both read bytes; the suite's json:emit compare refuses bytes on both sides); json:emit writing bytes is a json.md question for the owner, filed separately only if the owner wants it.

## FABLE-8 — the fable-1910 task runs on account 8 (#1869 slice re-home, #1925 parse cost, #133 store, v#15 lever 3)

> RULING owner 2026-10-13T18:43:31Z (via integrator, FABLE-8 = (a)): the fable-1910 task is launched now on account 8 (Fable weekly 0 % here): it takes #1925's 1 KB parse cost (the lever; core keeps the landing and the rows), cx-core-code#133's chunked key-only set store (core's wip/setstore133-* prototype is its start; core lands the accessor alone first), the re-homing of its #1926 slice 1 (fable/1926-s1 branches, gate GREEN 578a5ae97, LAND-S1-EXIT 4 on the H7 pin move) under the issue the owner's #1926 close names for its rows, then v#15 lever 3 (allocator fast path + vgc_find_span O(1), lands as a bump via gaps2).

## PGO-1 — #1928 / cx-core-code#136 close on the SHIPPED binary: the release scripts build build-vcx-pgo (gcc .gcda form) and one release_linux.sh proof

> RULING owner 2026-10-13T18:54:13Z (via integrator, PGO-1 = (a), core's DECISION-ASK 18:42:18Z): #1928/cx-core-code#136 close on the SHIPPED binary — this landing also moves scripts/tag_release.sh and scripts/release_linux.sh to build-vcx-pgo and teaches build-pgo gcc's .gcda form; the Linux proof is one release_linux.sh build; close both on that proof + the PERF-EVID rows (time + peak RSS vs Python 3.12.15). Core lands the targets + HARDEN-1 now; the release switch rides the same landing or the next.

## MYCDC-1 — cx-platform-connector#27's mysql slice is the binlog client (the decision first posted as MYSQLCDC-1)

> RULING owner 2026-10-13T18:54:13Z (via integrator, MYSQLCDC-1 = (a), plat's DECISION-ASK 18:43:12Z): cx-platform-connector#27's mysql slice = the binlog client (libmysqlclient 8.4 binary-log interface, ROW events decoded as pgoutput is, binlog_format/row_image/row_metadata checked at open, position = file + end position, CXER6413 on a purged file, snapshot + log_status baseline, sync.md §3.4.3); ~2 windows; closes #27 + the db-cdc row. plat: flow#1 first (FLOW1-1 = (a)), then this.

## QUIET-1 — two build-free rows slots per window (superseded the same hour by LOAD-1)

> RULING owner 2026-10-13T18:54:13Z (via integrator, QUIET-1 = (a)): two build-free ROWS-SLOTs per window, called by the integrator here 20 min ahead as 'ROWS-SLOT HH:MMZ-HH:MMZ'. In a slot no stream starts a build, suite, gate or deps-sync and none runs in it (do not start one that would run into it); rows chains run then, in claim order (plat q18/q18b, priv rows-1923, core rows, gaps2, fable-1910). Outside slots rows still need load <= 8 and a BOX claim.

## RACE-1 — after a GREEN landing gate, a head move of other streams' files only is merge + push, no rebuild

> RULING owner 2026-10-13T18:57:40Z (via integrator, RACE-1 = (a)): after a landing_gate GREEN on your merge, if origin/release/0.18 moved and the new merge brings ONLY other streams' files (git diff --stat of the merge touches nothing you changed, no deps.cxd/repos.cxd conflict, no fork-pin change), merge and push WITHOUT a rebuild — the loop's tick on the pushed head is the report. A merge that touches your files, a deps row conflict, or a fork-pin move still gets make deps-sync build-vcx test-vcx-suite (a gate rerun only when your own files changed). Supersedes the 'rerun just build-vcx + test-vcx-suite' line of STREAM-BRIEF.md's Landing step 3.

> RULING integrator 2026-10-14T01:55:15Z (RACE-1 clarified, priv's 01:54:59Z ask; within the owner's intent — no rebuild for other streams' moves): a deps.cxd/repos.cxd conflict that is TEXTUAL ONLY on adjacent rows, resolved as origin's rows + your own row unchanged, counts as 'other streams' files only' — merge, make deps-sync (seconds, so the tree matches the pins), push; NO build-vcx/test-vcx-suite rerun. A conflict on the SAME row, or a fork-pin move, still rebuilds. priv: push 308d25df4 now; stop race-138's build by its pid.

> RULING integrator 2026-10-14T02:42:01Z (gaps2's 02:41:48Z ask = (b), per RACE-1 clarified 01:55:15Z): an ADJACENT-row deps.cxd/repos.cxd conflict resolved as origin's rows + your own row is other streams' files only — merge, make deps-sync (seconds), push now, NO rebuild; the gate's check-v-fork red was your V link, not the content (re-read OK at c44b0e0049; every other step GREEN on the same tree) = GREEN. Close #319 + #320 on the push (565N-1). The loop's tick reports the data x code pairing.

## LOAD-1 — rows at any load, cx and Python interleaved, medians, load stated; builds at nice 10; the BOX claim is the only exclusion (supersedes QUIET-1)

> RULING owner 2026-10-13T19:06:59Z (via integrator, LOAD-1 = (a); supersedes QUIET-1): NO rows slots — ROWS-SLOT 19:40Z-20:00Z is CANCELLED, disarm every slotguard now and let builds run. Rows at any load: (1) every build, suite, gate and deps-sync runs at low priority (nice -n 10) from now; rows run at normal priority; (2) every time row interleaves cx and Python 3.12.15 in the same minute, 3 rounds, medians, the load stated on the row; (3) the load <= 8 gate is gone — the only exclusion is the BOX claim (one rows run at a time). The owner's reading: a known load penalty (10-20 %) is factored in, cx is expected 20 %+ faster anyway; a row that meets the bar under load PASSES; one that misses by less than the load penalty is inconclusive (re-run, not a fail); one that misses by more is a miss. Memory rows read the same at any load.

## PYYAML-1 — PyYAML 6.0.3 from PyPI, hash-pinned, as the YAML comparison's Python library

> RULING owner 2026-10-13T19:08:19Z (via integrator, PYYAML-1 = (a), gaps2's ASK 18:48:09Z): download PyYAML==6.0.3 from PyPI (one wheel, the hash pinned in cx-examples baseline/requirements.txt — verify the hash) into a scratch venv on /opt/homebrew/opt/python@3.12/bin/python3.12 3.12.15; YAML-1's Python column runs there; state the version on every row.

## SCHED-1 — nothing that loads dev2 runs in a usage pause; landable work pushes before the fill

> RULING owner 2026-10-13T19:14:04Z (via integrator, SCHED-1 = (a); BRIDGE-1 = (a)): NO bridge on extra usage this pause. Everything landable pushes BEFORE the fill (~20:20Z). After the last PASSED tick the box stays QUIET for #1917's three remaining union rows (~1.5 h at load <= 8): in this pause NO detached build, gate, deps-sync, suite, V build or rows chain runs on dev2 — watchers and posting scripts only (HOLD-1917 as written). Each stream's WRAP-UP PAUSED block names what it would have armed and arms NOTHING that loads the box; GitHub-side CI runs are fine. Relaunch at the 23:30Z reset.

## BRIDGE-1 — no bridge on extra usage in the 10-13 19:xxZ pause

> RULING owner 2026-10-13T19:14:04Z (via integrator, SCHED-1 = (a); BRIDGE-1 = (a)): NO bridge on extra usage this pause. Everything landable pushes BEFORE the fill (~20:20Z). After the last PASSED tick the box stays QUIET for #1917's three remaining union rows (~1.5 h at load <= 8): in this pause NO detached build, gate, deps-sync, suite, V build or rows chain runs on dev2 — watchers and posting scripts only (HOLD-1917 as written). Each stream's WRAP-UP PAUSED block names what it would have armed and arms NOTHING that loads the box; GitHub-side CI runs are fine. Relaunch at the 23:30Z reset.

## OVER-4 — tens of dollars of extra usage may extend a window past the fill to finish a landing or a close

> RULING owner 2026-10-13T19:15:41Z (via integrator, OVER-4; amends SCHED-1): tens of dollars of extra usage MAY extend this window past the fill IF NEEDED — i.e. to finish a landing or a close that is within ~30 min of done at the fill (a green or nearly green gate/suite, a CI verdict to read, a close comment), never to start new work, new builds or new rows. The WRAP-UP message still comes at ~80 %; a stream that holds such an item says so in one line on claims.txt ('DRAIN <item> <ETA>') and finishes it, then PAUSES. The integrator watches the extra-usage figure and stops the drain at ~$40. The quiet pause for #1917 begins after the last PASSED tick.

## BRIDGE-2 — fable-1910, gaps2 and core (then all five streams) run on extra usage through the 23:30Z reset without a restart

> RULING owner 2026-10-13T21:14:05Z (via integrator, BRIDGE-2 = (a)): fable-1910, gaps2 and core relaunch NOW on extra usage (~$115 budget to the 23:30Z reset; the integrator stops the bridge at that figure) — the H8 fmt peak RSS regression first (fable-1910 + gaps2), then the YAML landing and H9 (gaps2), the PGO Linux proof (core). At the 23:30Z reset they CONTINUE (no relaunch); plat and priv relaunch at the reset. LOAD-1 holds (builds at nice 10); after the fix's tick PASSES the three keep the box as light as their work allows so #1917's union can run in what remains of the pause.

> RULING owner 2026-10-13T21:18:04Z (via integrator, BRIDGE-2 amended): NO dollar cap on the bridge — its point is that fable-1910, gaps2 and core are not restarted; they run through the 23:30Z reset and on. The integrator reports the extra-usage figure hourly and stops nothing for it.

> RULING owner 2026-10-13T21:19:26Z (via integrator, BRIDGE-2 widened): plat and priv relaunch NOW as well (all five run through the 23:30Z reset without a restart). plat: #1910's re-run first (k8/k1 1.34 vs the 1.3 bar — interleaved per LOAD-1, close if met), then connector#27's mysql slice, store#17, net#21. priv: #1923 run5's remaining segments under a BOX claim, the #1840/#1917 watchers, IDLE-1 reds.

## SCALE-1 — #1923's scaling-efficiency bar: CPU per unit at k <= 1.3x k=1 through the P-core count; above it, cx's CPU per unit <= Python's at the same k

> RULING owner 2026-10-13T23:30:07Z (via integrator, SCALE-1 = (b), core's DECISION-ASK 23:04:52Z on #1923's scaling-efficiency row): CPU per unit of work at k <= 1.3x k=1 through k = the box's P-core count (20 on dev2, 8 on ep-2); above it, cx's CPU per unit <= Python's at the same k. Every other #1923 bar unchanged (wall and memory better than Python at every k; sound). Record the P-core count on each row.

## QUIET-1917 — a quiet mode without a restart for #1917's union rows after the in-flight landings and a PASSED tick

> RULING owner 2026-10-13T23:34:47Z (via integrator, QUIET-1917 = (a)): a QUIET MODE without a restart for #1917's three union rows. When the in-flight landings (gaps2 YAML, H9, core PGO, priv #138, fable's #1869 slice) are in and the head's tick has PASSED, the integrator writes 'QUIET-START <HH:MMZ> 90 min' here: every stream finishes ONLY the command in flight, starts NO build, gate, deps-sync, suite, V build, rows or push until 'QUIET-END' (GitHub-side CI, issue writing, code reading, planning, or sleep 900 are fine; load must read <= 8 so the loop's idle union starts after 600 s and runs up to 3 unions of ~15 min); then resumes. Until QUIET-START: land what is ready, but do not START a new gate within 20 min of the integrator's announced start.

## LOOPBIN-1 — the loop's perf-pair measures the shipped binary: the perf-pair target builds and uses build-vcx-pgo

> RULING owner 2026-10-14T01:06:30Z (via integrator, LOOPBIN-1 = (a)): the loop's perf-pair measures the SHIPPED binary — the perf-pair step builds/uses build-vcx-pgo (the Makefile's perf-pair target, not flows/); core lands it with or right after the PGO landing (#1928/#136), with the PGO record of the training run in the step's log; the tick's extra training time is accepted. The -O2 retention (+68 MB live at gc 11) stays core's item at lower priority: PGO hides it, the fix is still owed.

## CLOSE-1927 — cx-private#1927 closes on v#42's fix in H9 (fork c44b0e0049)

> RULING owner 2026-10-14T01:15:04Z (via integrator, CLOSE-1927): cx-private#1927 closes NOW on v#42's fix (fork c44b0e0049 in H9 = release 9ebbc554b; the pacer's CPU reading leaves out the collector's spin-waits; FreeBSD fixture green in all three modes) — gaps2 posts the close comment with the sha + the CI run and closes it.

## BRIDGE-3 — after #1917 closes, every 5-hour gap is bridged on extra usage (revoked by BRIDGE-4)

> RULING owner 2026-10-14T01:15:04Z (via integrator, BRIDGE-3): after #1917 closes, EVERY 5-hour gap is bridged on extra usage — no WRAP-UP at a fill, no restart; the streams run continuously to the weekly wall. The integrator reports the extra-usage figure hourly. QUIET-1917's quiet mode still happens once (for #1917's rows).

> RULING owner 2026-10-14T02:39:53Z (via integrator, BRIDGE-4; revokes BRIDGE-3): THIS bridge (the 02:10Z fill to the 04:30Z reset) is the LAST one, budget a couple hundred dollars (spent $17 so far). From the next fill on: NO bridging — WRAP-UP by message at ~80 % of the 5-hour, hand stop at 93-97 %, PAUSED blocks, relaunch at the reset. The QUIET for #1917 (after the frozen gates push and the tick passes) runs on, across the 04:30Z reset if needed.

## LABELS-1 — cx-private#1836, #1837, #801 and #784 are v0.18 work as labeled and enter the streams' lists

> RULING owner 2026-10-14T01:26:15Z (via integrator, LABELS-1): cx-private#1836 (performance program), #1837 (xap state model), #801 (labeled visibility) and #784 (store placement tier) ARE v0.18 work as labeled — they enter the lists: #1836 -> core + gaps2 (the evaluator/collector halves; the Benchmarks Game is the acceptance; budget page + gate step first, as the issue says), #1837 -> plat (xap), #801 + #784 -> plat (store), each after the stream's current close-first items; DECISION-ASKs for any scope question, never a reinterpretation.

## JINJA-1 — one pip download of Jinja2 into a venv on the PYBASE-1 interpreter for the template comparison

> RULING owner 2026-10-14T02:21:13Z (via integrator, JINJA-1 = (a), fable-1910's DECISION-ASK 02:16:52Z): one pip download of Jinja2 into a venv under fable-1910's scratch on /opt/homebrew/opt/python@3.12/bin/python3.12 (3.12.15); the Jinja2 version recorded in every template-render row's header; nothing system-wide; the venv dies with the scratch. The template-render Python baseline is then measured (PYBASE-1) for #1869 and v#15.

## BRIDGE-4 — the 02:10Z-04:30Z bridge is the last one (revokes BRIDGE-3)

> RULING owner 2026-10-14T02:39:53Z (via integrator, BRIDGE-4; revokes BRIDGE-3): THIS bridge (the 02:10Z fill to the 04:30Z reset) is the LAST one, budget a couple hundred dollars (spent $17 so far). From the next fill on: NO bridging — WRAP-UP by message at ~80 % of the 5-hour, hand stop at 93-97 %, PAUSED blocks, relaunch at the reset. The QUIET for #1917 (after the frozen gates push and the tick passes) runs on, across the 04:30Z reset if needed.

## The token MYSQLCDC-1 — renamed MYCDC-1

`MYSQLCDC-1` (unparsed, IDSH-1) -> `MYCDC-1`. The integrator's RULING line of 2026-10-13 18:54:13Z named the decision `MYSQLCDC-1`. That is eight capitals, outside the id grammar's two to six (CFG-1), so no page can declare it. plat's landing subject `3f720d7bc` (pin(cx-platform-connector): main 8a12488 …) cites it as `(RULED: STREAM-1, MYSQLCDC-1)`. The decision is renamed `MYCDC-1` (the integrator, 10-14 03:1xZ), and the section above records it under that name. This line is the record ledger_index.cx reads: an unparsed token written in this shape, backquoted with `(unparsed, IDSH-1)` after it, is excused from the IDSH-1 refusal. A token not written in this shape is still refused.

