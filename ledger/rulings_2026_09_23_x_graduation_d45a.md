# The x/ graduation — the eleven experimental-tier rows join the platform namespace (owner, 2026-09-23, D45a)

**Status: RULED (owner, 2026-09-23 ~09:5xZ, in session on dev2; recorded on
[#1591](https://github.com/cx-home/cx-private/issues/1591), comment of 2026-09-23 11:14Z).**
This page records the owner's answer to LETTER D45 and nothing else. It applies RS-4 and RS-1 of
[the repo-split page](rulings_2026_09_21_repo_split_1589.md) to eleven rows neither decision named;
it is not a new design, and a commit that carries it cites `RULED: RS-4, RS-1`.

## The letter

RS-4 moved `cx-xap` and `cx-fabric` under `cx-platform/` with one run of the 1427-i migration tool.
The merge of that branch (`b8ebd615b`) found eleven more rows with no ruled target: every
`ns=cx-x` row of `registry/modules.cxd` — the eight modules `registry/repos.cxd` allocates to
`cx-platform-agent` (`a2a`, `a2a-xap`, `adjudicate`, `llm`, `mcp`, `mcp-server`, `run`, `tools`)
and the three it allocates to `cx-platform-ux` (`ux`, `ux-tui`, `ux-web`). The letter offered:
(a) all eleven move to `cx-platform/` in the agent/ux extraction branch, together with RS-1's
`group=platform`, by one more run of the tool; (b) ux's three now, agent's eight later; (c) keep
`cx-x/` until each module gets a decision of its own. The owner's answer, verbatim on the board:
**D45a**.

## What D45a authorizes

- **The rows.** Each of the eleven reads `ns=cx-platform group=platform`; its `ring=` stays what
  RS-1's rows read (the ring of its highest verb, 1 for all eleven). Every other column is the
  extraction's, not this page's.
- **The retirement.** `cx-x/<name>` is a RETIRED resolver name for each of the eleven, mapped to
  `cx-platform/<name>` in the one table the loader's refusal and the sweep both read
  (`retired_bundled_names()` in `vcx/code/stdlib_bundle.v`, RS-4's). A program that still imports
  the old spelling fails at load with CXER0213 naming the new one; no alias is kept.
- **One run.** `cx --migrate-namespace --retired -w` runs ONCE over the tree after the table grows;
  a second run changes nothing. Its per-file counts are recorded in the branch's RESULTS.md.
- **Refusal cases.** Each module's corpus pins its retired spelling refusing, so the retirement is
  graded wherever the corpus is.

## What it does not decide

- **The experimental tier itself.** With these eleven gone no row carries `ns=cx-x`. Whether the
  tier is retired as a concept — its sentence in `AGENTS.md`, `spec/03-approved/x/README.md`, the
  placement check's `cx-x` allowance — is not in the letter; the branch flags it.
- **The directories.** RS-1 and RS-4 say nothing about where a graduated module's spec and corpus
  sit. The files stay under `spec/03-approved/x/`, `conformance/x/` and (ux) `xap/` as allocated,
  and the rows point where they are; the branch flags the directory question.
