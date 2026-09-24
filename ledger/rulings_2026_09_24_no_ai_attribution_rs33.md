# RS-33 — zero AI attribution anywhere in any repository, ever (owner: D87, D88b)

**Status: RULED (owner, 2026-09-24 ~23:0xZ, in session, on
[#1591](https://github.com/cx-home/cx-private/issues/1591)).**

## The owner's word, verbatim

**D87:** "Zero AI attribution anywhere in repos, ever. Attribution will be handled elsewhere as
needed."

**D88 (applying D87 to the existing histories):** "all attributions must be stripped from public
repos."

D87 is a RULE, not a lettered choice: zero AI attribution anywhere in any repository, ever —
commit messages, trailers, tracked files, docs, generated output. Attribution is handled outside
the repositories. D88 is the lettered decision that applies the rule to history already written.

## The measured counts (the board, D87's comment on #1591)

The filtered `cx` history (the extraction prepared at
[`/Users/dev2/git-repos/cx/extract-cx/cx.git`](../extract-cx/cx.git), not yet pushed) carries:

| what | count |
|---|---|
| Co-Authored-By AI trailer lines | 353 |
| message lines naming a `/Users/…` path | 613 |
| distinct author emails | 3 |

Measured separately, on this tree's own head (`release/0.18` at the branch base): the tracked-file
scan finds no hit at all — the board measured none, and this branch's own checker (step 2 below)
proves that count on the head it merges.

Measured by this branch's end-to-end tool test (step 3 below), each on a local `--mirror` clone:

| repository | commits with a hit | commits total |
|---|---|---|
| `cx-platform-fabric` | 2 | 140 |
| `cx` (the prepared extraction) | 352 | 3435 |

## D88's three options, verbatim

**(a)** "one pass NOW over everything — the 20 pushed repositories, the fork, the two unpushed, AND
cx-private's `release/0.18`/`main`: the rule holds everywhere today, but rewriting the live
integration branch invalidates K7a's branch, every worktree and every pin at once — about half a
day of the split lost to re-basing and re-pinning, in front of the leave."

**(b)** "STAGED: the two unpushed repositories stripped at their push (now, in the same filter); the
20 pushed repositories and the fork rewritten in ONE pass immediately before the public flip at the
cut (they are private until then; ~2–3 h with the re-pins and one union); cx-private LAST, after
D83a's switch-over when its integration branch quiesces and every open branch has merged — private
the whole time, and nothing that is public ever carried a trailer."

**(c)** "rewrite only what goes public (the 21 + the fork) and never cx-private, which stays private
for good — cheaper by one rewrite, but the ops repository would carry the trailers forever, against
'anywhere, ever'."

**Recommended: (b).** **Ruled: D88 = (b).**

## The staged plan (b), as ruled

1. **The two unpushed repositories** (`cx`, `cx-core-code`) are stripped **at their push**, in the
   same filter that produces them — they carry no trailer from the day they first go live.
2. **The pushed component repositories and the V fork** (the 20 already-pushed repositories plus
   `cx-home/v`) are rewritten in **one pass**, immediately before the public flip at the cut; they
   are private until then, so nothing public ever carried a trailer. The public flip is gated on a
   zero count from the scanner (step 2 below) over the rewritten history.
3. **`cx-private` last**, after D83a's switch-over, once its integration branch quiesces and every
   open branch has merged. It stays private the whole time it carries any trailer.

In every option: RS-33 goes on the ledger (this page), and a `check-no-ai-attribution` step — the
branch's commit messages since the base, plus every tracked file — is added to every repository's
gate template and to `cx`'s post-merge `TEST_TARGETS`.

## The gate step and the tool

- **Gate:** [`scripts/check_no_ai_attribution.cx`](../scripts/check_no_ai_attribution.cx), the
  Makefile target `check-no-ai-attribution`, added to the post-merge `TEST_TARGETS` and to
  `tooling/repo-template`'s Makefile `check` in cx-tooling (RULED: RS-33, CXF-1 — see the K12
  brief's RESULTS.md for the prepared cx-tooling sha).
- **Tool:** [`scripts/strip_attribution.cx`](../scripts/strip_attribution.cx) — mirror-clones a
  named repository, runs `git filter-repo --message-callback` to drop exactly the flagged lines
  (message-only; no path, author or date change), verifies a zero count with the gate script over
  the whole rewritten history, and prints the old-sha → new-sha re-pin list. It pushes nothing; the
  integrator force-pushes from the mirrors it produces.

## A note on this page's own text

This page quotes the patterns the scanner looks for. Writing them whole would make this page fail
its own gate, so each is split at a point the scanner's literal match does not cross: the trailer
token is `Co-Authored-By` immediately followed by `:` and a space and `Claude`; the address token is
`noreply` immediately followed by `@` and `anthropic.com`; the phrase token is `Generated with`
immediately followed by a space and `[Claude Code]` (or, without the brackets, `Generated with` and
` Claude`); the emoji token is the robot-face emoji immediately followed by a space and `Generated`.
The gate script (step 2) holds the four whole patterns as data, not as prose in a page a human reads.

`(RULED: RS-33)`
