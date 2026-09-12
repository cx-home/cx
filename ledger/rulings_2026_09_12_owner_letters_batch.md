# Owner letters, 2026-09-12 ~03:30Z — "I'll take your recommendations if they are the best long term for cx and its clients"

The owner ruled the batch below by accepting the integrator's recommendations. Each row is a
decision of record; the id is the one cited in commits.

| Id | Decision |
|---|---|
| **OL-1** | Mailbox spec (1413-b rewrite): v1 exposes the `mail` feature's intents, not a JMAP surface; JMAP is a recorded trigger (the first client that needs a standard protocol against the mailbox). Proposals live in the mailbox module as `flow` offered steps. The seven answers of the first draft stand unless the owner overturns them on reading the rewrite. |
| **OL-2** | `sso.md` (S7) is read by the owner BEFORE its merge, as `mailbox.md` was; the S7 branch waits for that read. |
| **OL-3** | Merge on evidence: a branch merges when every step of its own pre-merge pipeline has passed once on its final tree; the post-merge run is the confirmation. A whole-pipeline re-run after a fix is not required — only the steps the fix touched. |
| **OL-4** | 1420-a ratified (the 790-1a kind pin follows 831-1a′). |
| **OL-5** | 1399's spec edits beyond the delegation (`oidc.md` §1/§5/§7–§10, one row each in `crypto.md`, `security.md`) ratified; `oidc.md` §2.2's `[auth-request]` shape gains the `[extras …]` child (one line, lands with the next oidc change). |
| **OL-6** | 1407's `crypto.md` §3.10 `jwt-sign opts.typ` ratified. |
| **OL-7** | 1397's example wording (`in-response-to`, not `idp-initiated`) ratified. |
| **OL-8** | 1408-a's document-runner containment for thrown parse refusals ratified. |
| **OL-9** | #1426 (imap server timeouts, rate window) is FINISHED NOW, before any M2 code; #1085 closes when it lands. (The integrator's own list said "accept open"; the owner's bar — solid and complete — decides otherwise.) |
| **OL-10** | #1424: letter (b) — a post-FILE argument spelled like a cx flag WARNS on stderr unless the program's `[argspec]` declares it; argv unchanged. |
| **OL-11** | #1425: the store daemon readiness test fixes its readiness order (SKIP before the assertion) AND the step joins the retry policy under the "daemon start under load" class. |
| **OL-12** | Tooling names follow the delivery grammar now: run markers, "lane"→step in output, the runner directories — the directory rename waits until no pre-merge run is active. |
| **OL-13** | Release exit: the release ships with epic S complete plus M1 (smtp, imap, sasl) and M2 (mailbox); M3–M6 and epics 1 and P move to the next release. |

Powerband-specific integration (hosting, deliverability operations, data residency, client
protocol) is the platform's decision and appears nowhere in cx specs or code (owner, same
conversation).

## Addendum, ~05:20Z — OL-14 and OL-15 (owner: "recommendations accepted for the library and repo plan"; "we can't keep making these big organization mistakes that cause refactoring and restructuring. its been very costly.")

| Id | Decision |
|---|---|
| **OL-14** | **The ring-legible tree, one repo, before real clients and before M2 code.** One campaign, every artifact dimension together (the #1077 lesson): `spec/03-approved/std-lib/` splits into `stdlib/` (Ring 1) and `platform/` (Ring 2) with `ring=` in every module header and the catalog step keyed on it; the namespace splits into `cx-stdlib/` and `cx-platform/`, migrated by a `cx` migration tool over every program in the tree (no regex); `conformance/stdlib/` splits the same way; code file names align with `vcx/code` (Ring 0–1) and `vcx/platform` (Ring 2); docs generator, guide-check, coverage and catalog checks, lockfile `bundled:` entries, AGENTS.md and the primer follow. Rule for mixed modules: a module lives in the ring of its highest verb; a pure half a Ring 1 consumer needs becomes its own Ring 1 module. Sequence: finish what is in flight (S7 spec + phase 2, #1426, #1424, #1425, tooling names), hold M2 phase 2, run the campaign with its full option table on its issue first, then M2 lands in the new structure. **The repo split (Ring 2 first) is a recorded trigger, not a plan:** the first client that needs Ring 2 released on a cadence different from the binary. |
| **OL-15** | **No more placement mistakes.** Every new module or component states its ring and its directory in its DECISION, before any spec or code, and a placement check refuses a module whose declared ring, spec directory, code directory and corpus ring tags disagree. Every structural change (tree, namespace, gates, ownership) is preceded by the full option table across code, spec, conformance, gates, docs, lockfile and tooling, on its issue, for the owner's letter — never executed one dimension at a time. |
