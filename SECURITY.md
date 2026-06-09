# Security Policy

## Supported versions

CX is **pre-1.0**. Only the latest released minor version (0.7.x at
time of writing; v0.8.0 in development on `v0.8.0-dev`) receives
security fixes. There has been no formal security review or
fuzz-testing infrastructure yet — see the
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

## Known gaps

- No fuzz-testing infrastructure yet.
- No formal threat model.
- No security audit by an external party.

These are tracked in the release process §6.
Treat CX as appropriate for prototypes and internal tools — not for
parsing adversarial input on a public-facing endpoint.
