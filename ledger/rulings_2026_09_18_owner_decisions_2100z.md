# Owner decisions 2026-09-18 ~18:30Z–21:00Z — the design backlog leaves the release label (BACKLOG-1); the store's wire field is `wire-version` (1544-c); the sched restore cases carry their ring

Owner, 2026-09-18 18:2xZ–20:5xZ, on three questions the integrator put in front of them; measured before the rows (head `b3df7ef96`,
20:5xZ): 177 issues open, 140 of them under the `v0.18` label; the owner's bar for the day is 100 or fewer open on the release by midnight
New York; the CSRP clean-up branch (issue 1544) had removed the retired protocol's name from 342 live sentences and found one live WIRE
FIELD still carrying it — `csrp-version`, emitted by the daemon, read by the client, a normative MUST in `store_management_console.md`;
the profile gate's cli composition answered `CXER0136 no callable "journal-open"` for `sched-024` and `sched-038` at the head AND at the
last passed head `87258f3ef` (Agent B2's two-line probe on both binaries) — the cli profile has no Ring 2 by definition (`vcx/Makefile`
line ~259, the runner's own `ring2_probe`), and the two cases had passed only through a discarded refusal that 1537-a now surfaces.

| Id | Decision |
|---|---|
| **BACKLOG-1** | **(owner, 18:2xZ–18:4xZ: "you can't close those simply because they have no commitment windows. we may review some for backlog" — then letter (b))** Design proposals with no commitment window are NOT closed for want of one; they leave the `v0.18` label and stay OPEN, unchanged, for the owner's review at a release's planning. Applied to 26 issues, each with a one-line note: 696 697 699 728 729 731 732 733 734 735 746 747 748 750 784 800 801 954 987 1286 1315 (design proposals), 1439 1442 1443 1444 (V-language limitation records), 521. The board's count row carries two numbers from here: **open** and **open on the release**; the release's bar is measured on the second. Rejected: closing the groups as "not this release" (the integrator's recommendation of 18:1xZ — withdrawn). |
| **1544-c** | **(owner, letter (a), 20:5xZ; issue 1544, completing 1544-a/1544-b)** The live wire field `csrp-version` is renamed **`wire-version`** in the same merge as the clean-up: the daemon's emission, the client's read, the MUST sentence in `store_management_console.md` edited to the new name only (the only spec change; the owner reads it), every fixture pinning the field re-blessed BY NAME; the retired-term guard's scope then reaches zero with no allowlist entry. No external users exist, so no compatibility window. Rejected: (b) emitting both names for a release; (c) keeping the name behind an allowlist. |

## Applications recorded (no new id)

- **The sched restore cases carry their ring (1427-c applied, integrator 20:5xZ, claimed and released on issue 1515):** `sched-024` and
  `sched-038` gain `ring=2` like their ten journal-using siblings (022 023 025 026 027 033 040–043); the profile gate skips them at the
  cli composition and grades them where the journal exists. Not a regression: the cases had passed at `87258f3ef` only because the
  `journal-open` refusal was discarded into a dead binding and the timer armed non-durably — the false-pass class 1537-a ended. Rejected:
  compiling Ring 2 into the cli profile (deletes the profile's definition); a by-name exclusion list (a tagging oversight made precedent).
- **The dogfood gate's flow commands carry the caller's read grant (1061-a applied):** `flows/repo-gate.flow.cx` is read by the CLI on the
  caller's authority, `--allow-read=.` after the `flow` subcommand — the same class as the platform example scenarios (the examples-grants
  merge) and everyday example 290.
- **The data-fallback lanes after 1559-a (the "which refusal" rule of 1536-a applied, issue 1568's shape):** where the program reading of a
  data-idiom document is now the correct reading (prose), the csv emit and the diagram preconditions ask the data reader where the program
  reading is not the document's reading, rather than relying on a refusal that no longer occurs.

## Sequencing

The sched tag merges alone and the union goes; the 1544 branch completes with 1544-c and merges on its own steps; the masking defect Agent
B2 found (a Ring-2 `[?lib]` resolving in a Ring-2-free artifact, only the first verb refusing with `no callable` instead of `CXER0213`) is
filed as its own Ring 0 issue.
