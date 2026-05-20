# Frozen at v0.7.0

This binding is **frozen** as of cx v0.7.0 per
[ADR 0022 §D4](../../spec/decisions/0022-cx-is-one-language-v0_7_0-scope.md).

## Status

- **Not actively built** — no CI runs against this binding at v0.7.0.
- **Not part of conformance** — not in the 5-binding parity matrix
  (V + Python + Go + Rust + TypeScript).
- **Source preserved** — historical implementation kept in this
  directory for provenance and potential re-promotion.

## Why frozen

The v0.7.0 binding cut (ADR 0022 §D4) reduced the active binding
matrix from nine to five, focused on the languages with concrete
downstream consumers and the highest-leverage ecosystems for cx's
data-processing positioning. The five active bindings each carry
~3 sessions of v0.7.0 port work; nine would have been unsustainable.

## Re-promotion criteria

A frozen binding moves back to active status when:

1. A concrete downstream consumer surfaces for this language
   ecosystem.
2. An ADR documents the re-promotion decision with rationale.
3. The binding is rebuilt against the current cx C ABI (which has
   evolved since this code was last maintained — see ADR 0022 §D5
   for the v0.7.0 ABI epoch break).

## Won't load against current libcx

Pre-v0.7.0 code in this directory uses the old `cx_eval_cxl*`
symbol names. v0.7.0 libcx exports `cx_eval*` (without the `cxl`
infix) — symbol lookup will fail when this binding is loaded
against a v0.7.0 libcx, by design. A re-promotion would update the
symbol references along with whatever other surface changed.
