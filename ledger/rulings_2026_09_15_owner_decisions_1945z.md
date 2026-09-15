# Owner decisions 2026-09-15 ~19:45Z — "5a 6a if those are the best cx long term" (RULED: 1197-a, 1220-a)

Both were recommended as the long-term choice and are taken as ruled (the standing acceptance pattern).

| Id | Decision |
|---|---|
| **1197-a** | **(owner, letter 5(a))** `ux.md` §3's gating sentence is trued to what ships: the `ux` pack is Ring 2 and bundled in EVERY profile — default, cli and embed — under its registry name `cx-x/ux`, behind no gate; the sentence naming "the same `-d` gating pattern as the rest of the platform ring" is replaced (`-d` is a build-time define; no run flag of that shape exists). Measured by #1197's branch on all three profile binaries. Written with this page. |
| **1220-a** | **(owner, letter 6(a))** `[$xap:component]`'s `emits:` accepts ANY sequence-like value and materializes an Iterator (a comprehension) into the Sequence it reads — the primer's "a comprehension yields a sequence" kept at the call boundary, the orthogonality the #1192/#1218 fixes restored (collections are values everywhere). No refusal, no wrapper remedy. One enforced case (the issue's repro: `a=0 b=1`). Lands on `impl/cx-F-1220-emits-iterator-err` with items 2–3 (INT-13). |
