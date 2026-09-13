# RULED: CFG-1 — the agent-context layers get ONE stated precedence, the load-bearing agent rules become tracked repo content, and the stale config is removed

**Owner, 2026-09-13**, on issue #1438 — "audit of every file that steers Claude on this repo —
global (`~/.claude`) and local — accepted in full; **priority, and break nothing**." All nine
parts accepted as letter **(a)**.

Two notes on how this record came to exist:

- **(a) `CFG-1` is taken under the standing letter-acceptance rule.** The issue's "Open for the
  owner" section proposed `CFG-1` as a new decision series and the owner accepted the issue in
  full; the standing rule that an unanswered letter is accepted as written therefore names the
  id. No separate owner message assigns it.
- **(b) Posting the six V drafts upstream stays with the owner.** This decision files them as
  issues in *this* tracker only. Each filed body's last line says so, so a later reader cannot
  mistake "filed here" for "filed at vlang/v".

## The findings this decision rests on (quoted from #1438)

| Finding | Evidence |
|---|---|
| Four rule layers, no stated precedence | `~/.claude/CLAUDE.md` (auto) · `MEMORY.md` (auto) · `CLAUDE.md` → `AGENTS.md` (pointer only — **not auto-loaded**) · `AGENT-STANDING-RULES.md` (reached only via a #1354 comment) |
| The load-bearing agent rules are **unversioned, outside any repo** | `AGENT-STANDING-RULES.md` sat one directory above the checkout, not in a git repo; edited 09-13; every agent brief reads it by absolute path |
| Three live conflicts between layers | pushing (AGENTS.md rule 8 vs memory vs the standing rules' step 4); `nohup … > /dev/null &` (AGENTS.md recommended the idiom two memories forbid); plan mode / AskUserQuestion (memory forbids both; the harness requires one inside the other) |
| `AGENTS.md` contradicts its own charter | claims "stable and minimal"; its operational half churned 4× in 3 weeks; carried `release/0.17` |
| Memory over the load limit | `MEMORY.md` 24.6 KB > 24.4 KB — truncated at every session start |
| Memory rot | 435 files / 3.1 MB; 172 orphans never indexed; 2 duplicate index links; 3 "READ FIRST" handoffs |
| Inert settings | `.claude/settings.local.json`: 333 allow entries, unread under `bypassPermissions` |
| Stale generators | two global skills (2026-05-19) that regenerate `scripts/gen_docs/` (moved 09-01) and `tooling/install/` (08-23) — running either clobbers newer in-tree code |
| Clutter | `.claude/next-session-prompt.md` (ADR era), `.claude/v_upstream_drafts.md` (tracked content in a config dir), 3 `.bak`, 1 stale plan, ~368 MB of transcripts for 7 directories that no longer exist |
| Mechanism to preserve | agent memory is keyed by working directory → a **worktree agent has an empty memory directory**; rules that must reach agents live in a repo file read by absolute path, never in memory |

## The decision, as nine rows

| # | Row | Where it lands |
|---|---|---|
| 1 | `AGENT-STANDING-RULES.md` becomes tracked repo content at the **repo root**, and the loose path one directory above the checkout becomes a **symlink** at it, so every live agent brief that reads the absolute path keeps resolving. `CLAUDE.md` names both `AGENTS.md` and it. | `AGENT-STANDING-RULES.md`, `CLAUDE.md` |
| 2 | `AGENTS.md` returns to its charter: what CX is, the ten rules, and a **"which file wins — this repo"** block naming the standing-rules file, `delivery-grammar.md` and `ledger/`, resolving the three conflicts. The operational half moves to `CONTRIBUTING.md` §Testing. The stale `release/0.17` string is corrected. | `AGENTS.md`, `CONTRIBUTING.md` |
| 3 | `.claude/` hygiene: `next-session-prompt.md`, `settings.local.json` and its `.bak` are dropped; `v_upstream_drafts.md` is removed from version control once row 4 has filed its content. | `.claude/` |
| 4 | The six unfiled V drafts (#1a #2 #5 #6 #7 #9) become issues in this tracker, labelled `area:v-runtime` + a kind label + a `prio:*` label, sanitized, cross-linking the three already upstream (vlang/v#27165, #27178, #27179). | the tracker |
| 5 | `scripts/ledger_index.cx` generates `ledger/README.md` (`RULED: <id>` → file → heading); `make ledger-index` writes it and `make ledger-index-check` fails on drift; a `scripts/test_changed.sh` manifest row selects the step. **Last and separate** — a `scripts/*` change escalates `test-changed` to the full union, so INT-5 applies: the pre-merge pipeline is this branch's own steps only. | `scripts/`, `Makefile`, `ledger/README.md` |
| 6 | `~/.claude/CLAUDE.md` gains the generic precedence block: owner's live word → that file → the project's `AGENTS.md` + standing rules → its spec/process docs → memory (recall, never authority) → harness templates. | outside the repo |
| 7 | A new reusable audit skill prints the tables above for any project path, and **reads only** — it never deletes. | outside the repo |
| 8 | The two stale regenerator skills, the stale plan, the `.bak` files and the 7 dead transcript directories are deleted, each verified absent by its decoded path first. | outside the repo |
| 9 | This repo's memory store: closed `project_*` archived, orphaned `feedback_*` indexed or merged, the question-format copies deleted once row 6 carries the rule, the three handoffs collapsed to one line, `reference_worktree_agents_have_empty_memory` added. **Row 9 is the integrator session's own work, not an agent's** — a worktree agent's memory directory is empty by construction, so it cannot see the store it would be editing. | outside the repo |

**Order:** 9 → 6 → 1 → 2 → 3/4 → 7 → 8 → 5. Row 6 runs before row 9 deletes the memory copies of
the question-format rule, so the rule is never unowned for a moment.

## Two corrections made while executing, recorded rather than assumed

1. **The moved standing-rules file is sanitized on one word.** Its git section carried a
   downstream consumer's name in the sentence forbidding that name in specs and code. That
   sentence was correct advice and illegal as tracked content: `check-no-consumer-terms` scans
   every tracked file, so the file could not be committed verbatim. The sentence now states the
   rule without naming the consumer, and the gate that enforces it is named instead. Everything
   else is the 2026-09-13 text byte-for-byte.
2. **The symlink is swapped only when the target resolves.** The symlink points into the *main*
   checkout, which does not carry this branch until the integrator merges it. Creating it before
   the merge would leave every live agent's `cat` of the absolute path reading a dangling link —
   the one outcome "break nothing" rules out. The loose file therefore stays a real file, with
   the identical committed content, and the swap is a one-line integrator step recorded in
   `RESULTS.md`.

## Verification the decision names

- `git ls-files AGENT-STANDING-RULES.md` lists it; `cat` of the absolute loose path prints the rules.
- `grep -c nohup AGENTS.md` = 0; no `0.17` in `AGENTS.md` or `CONTRIBUTING.md`; every rule that
  leaves `AGENTS.md` lands somewhere tracked, and the before/after rule set is listed in `RESULTS.md`.
- Six issues, three labels each; `v_upstream_drafts.md` gone from `git ls-files`.
- `cx lint scripts/ledger_index.cx` clean; `make ledger-index && git diff --exit-code ledger/README.md`;
  `RULED: 1085-a` resolves to `rulings_2026_09_11_email_world_class_agentic_1085.md`.
- The audit skill reports the project's load path, orphans, duplicate and dangling index links,
  age and bytes by memory type, inert allow-lists, `.bak` files, stale plans and dead transcript
  directories — and deletes nothing.
