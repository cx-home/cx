# Ruling ANC-1 (2026-08-20) — the Resolved AST is the semantic reading (#877, owner "3a")

The conflict: ast.md's two-AST model says XML emission works from the
Resolved AST (aliases expanded, merges applied); the shipped engine and
conversions.md carry anchors/merges through every lane instead — and the
lanes disagree with each other (XML carries `cx:merge=`, JSON silently
drops the alias, CXPath sees nothing). Meanwhile STRICT CANONICAL already
expands anchors — the document's ADDRESS is computed over the resolved
form — so identity said "the alias IS the copy" while query said "the
alias is nothing". Hash and query disagreed about meaning.

RULED (owner, 3a): **resolution is the semantic reading.** The evaluator,
CXPath, validation, and the LOSSY projections (JSON/YAML/TOML/MD/CSV)
operate on the Resolved AST; the LOSSLESS lanes (`cx fmt`, `--lossless`,
CX round-trip) preserve authored anchors/merges as presentation, and
conversions.md's `cx:merge=` carry is re-scoped to those lanes. ast.md
stands as written and gains the evaluator/lossy-projection rows plus an
implementation-status note. The engine gap (resolve pass before eval and
lossy projection) is #877's re-scoped implementation — post-cut, with
fixtures, real golden movement expected. Docs continue stating shipped
behavior (carried-not-resolved, per the audit landing) until it lands.
