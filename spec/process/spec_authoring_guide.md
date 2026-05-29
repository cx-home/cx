# CX Spec Authoring Guide

**Status:** Current for v0.8.0

Authoring conventions for normative CX specification documents. Reviewers use this guide when checking whether a spec is admission-ready. The corpus governance rules themselves (G1 mutual compatibility, G2 terseness, G3 user-only approval) live in [`governance.md`](governance.md) §13; this file is the practical author-facing companion.

## 1 — The destruction test

A complete CX specification passes this test: if all code and implementation history were destroyed and only the specs remained, a competent engineer could recreate CX — parser, AST, format conversions, document API, CXPath, streaming, ABI, and language bindings — with no divergence from the original design.

Ambiguity is a first-class defect. Wherever a reasonable implementor could make two correct-seeming choices and produce different observable behaviour, the spec has failed.

## 2 — Quality criteria

A spec section passes if a competent engineer who has never seen the CX codebase could read it and produce an implementation that passes the conformance suite.

A spec section fails if:

- It describes what a method does without specifying what it returns for every possible input, including missing, empty, and error cases.
- It uses "appropriate", "reasonable", "typical", or "usually" without a normative default.
- It specifies the happy path but leaves error paths implicit.
- Two reasonable engineers reading it could make different implementation choices that produce different observable behaviour.
- It references a concept defined elsewhere without citing where.

Every method signature in API-bearing specs ([`../misc/api.md`](../misc/api.md), [`../core/code.md`](../core/code.md), [`../misc/bindings.md`](../misc/bindings.md)) must specify:

1. What it returns on success.
2. What it returns when the target is absent (not an error).
3. What constitutes a programming error (panic/throw) vs a soft return.

Every binary-format spec ([`../core/data_bin.md`](../core/data_bin.md), [`../core/ast_bin.md`](../core/ast_bin.md), [`../core/streaming.md`](../core/streaming.md)) must include a hex-annotated test vector.

## 3 — Companion documents

- [`governance.md`](governance.md) — release process, audit framework, and the load-bearing G1/G2/G3 rules.
- [`readiness_rubric.md`](readiness_rubric.md) — release-readiness gates; quality criteria here are a precondition for any spec row to pass.
- [`threat_model.md`](threat_model.md) — security threat model that hardening-bearing specs cross-reference.
