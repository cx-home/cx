# Security Policy

## Supported versions

CX is **pre-1.0**. Only the latest released minor series — currently
**0.16.x**, per the repo-root [`VERSION`](VERSION) file, which is the
single source of truth for the release version — receives security
fixes. Integration for the next minor happens on its `release/X.Y.0`
branch (derived from `VERSION` — never named here, so this file cannot
go stale against a cut); pre-release branches receive
fixes as part of normal development, not as security backports.

There has been no external security audit yet — see the
[Status section in `README.md`](README.md#status) for the full caveat.

## Reporting a vulnerability

For non-sensitive bug reports, file a public issue at
[github.com/cx-home/cx/issues](https://github.com/cx-home/cx/issues).

For potential security vulnerabilities — anything that could allow
denial of service against a parser, memory corruption, an injection
that escapes the format, or unauthorized data exposure — **please use
GitHub's private vulnerability reporting** instead of a public issue:

1. Go to <https://github.com/cx-home/cx/security/advisories/new>.
2. Fill in the advisory.
3. We acknowledge within 7 days. Triage and fix timeline depend on
 severity; high-severity fixes ship in a patch release within 30
 days, lower-severity in the next minor release.

## Disclosure

We follow coordinated disclosure: the fix lands in a patch release,
and the advisory is published 7 days afterward so consumers have time
to upgrade. If a vulnerability is already public when reported, we
publish the advisory immediately.

## Scope

In scope:

- The V core (`vcx/`) parser, emitters, and conversion logic.
- The C ABI surface in `libcx`.
- The Tier-1 language bindings under `lang/` (V / Python / Go / Rust
  as of v0.8.0). Archived bindings under `lang/_archived/` are not in
  scope for the current security-fix window.
- The `cx` CLI.

Out of scope:

- Bugs in the V toolchain itself — report upstream at
 [vlang/v](https://github.com/vlang/v).
- Vulnerabilities in third-party libraries our bindings link against
 — report to the upstream library.

## Fuzz testing

The repo carries an in-tree fuzz harness, itself written in CX:
`scripts/fuzz_cx.cx` drives the parser, the buffered evaluator, the
streaming emitter and the strict-canonical serializer with random byte
sequences, malformed CX text, oversized inputs, and known parser edge
cases, asserting on crashes (SIGSEGV / SIGBUS / SIGABRT), a memory-leak
proxy, and catastrophic-time regressions. Crash findings land in
`vcx/fuzz/crashes/` (a gitignored runtime-artifact directory) and are
fixed with accompanying regression fixtures.

A GitHub Actions fuzz job wraps the same harness with a 1-hour budget,
but it is currently manual-dispatch only — there is no scheduled or
OSS-Fuzz-style *continuous* fuzzing campaign running.

## Known gaps

- No *continuous* fuzzing (the harness above is run manually /
  on-demand).
- No security audit by an external party.

The project threat model — trust boundaries, hardening claims, and
the assumed deployment model — is
[`spec/03-approved/process/threat-model.md`](spec/03-approved/process/threat-model.md).
Remaining gaps are tracked in the release process
([`spec/03-approved/process/release-process.md`](spec/03-approved/process/release-process.md)).
Treat CX as appropriate for prototypes and internal tools — not for
parsing adversarial input on a public-facing endpoint.
