# RS-13…RS-17 — the repo split's first follow-up decisions (owner, 2026-09-22, in session on dev2)

**Status: RULED.** The owner answered each as a letter on the integrator's lettered options, in
session on 2026-09-22 (recorded on [#1591](https://github.com/cx-home/cx-private/issues/1591)
the same hour). They extend [`rulings_2026_09_21_repo_split_1589.md`](rulings_2026_09_21_repo_split_1589.md)
(RS-1…RS-12) and take the calls that page did not make.

## RS-13 — `authz` splits along the RS-6 line (owner: D14a)

`authz` is not Ring 1 whole: measured on `5bcf2afa9`, `stdlib_authz.v` reaches the journal at 20
sites (the trust store binds and replays a journal handle) and names `SxConn` / `XapRuntime`. The
pure DECISION half — `check`, `authorize`, `decide`, `resolve-cap`, `verify-tier`, delegation parsing
and attenuation, the predicate library — becomes **`cx-stdlib/authz`** (Ring 1: spec
`spec/03-approved/stdlib/authz.md`, corpus `conformance/stdlib/authz.cxd`, code under `vcx/code/`).
The journaled TRUST STORE — `store` and every verb that appends (allocate / debit / delegate /
revoke / commit / grant-guardian / expire) — stays above the rings as **`cx-platform/authz-store`**
(spec `spec/03-approved/platform/authz-store.md`, corpus `conformance/platform/authz-store.cxd`,
code under `vcx/platform/`). `AuthzStore` is cut along that line and authz.md §3.1/§5 say so. A
consumer that decides and mutates imports both; the store server (RS-6) imports the decision half
only.

## RS-14 — did/vc's impure remainder gets modules named for what leaves (owner: D15b)

The pure verbs move to Ring 1 as RS-5 says (`cx-stdlib/did`: `key-create peer-create parse method
document key-of verify-control`; `cx-stdlib/vc`: `issue verify valid present`). The impure remainder
becomes two new modules above the rings, the `http-client` shape with the direction reversed:
**`cx-platform/did-web`** (`resolve` for `did:web` over HTTPS; spec `spec/03-approved/platform/did-web.md`,
corpus `conformance/platform/did-web.cxd`, code `vcx/platform/`) and **`cx-platform/vc-revocation`**
(`revoke`, `revoked-set` over a journal; spec `spec/03-approved/platform/vc-revocation.md`, corpus
`conformance/platform/vc-revocation.cxd`, code `vcx/platform/`). `[$did:resolve]` on a `did:web` from
Ring 1 refuses with a named code and sentence pointing at `did-web`; the refusal is a case in
`conformance/stdlib/did.cxd`.

## RS-15 — the xsp `auth-*` defs become `cx-platform/xsp-auth` (owner: D16a)

The 13 `auth-*` defs of `stdlib/xsp.cx`, whose natives are identity's `stdlib_xsp_auth.v`, move to a
new module **`cx-platform/xsp-auth`** (spec: the existing `spec/03-approved/xap/xsp-auth.md` becomes its
page, corpus the existing `conformance/xap/xsp-auth.cxd`, source `stdlib/xsp-auth.cx`, code
`vcx/platform/stdlib_xsp_auth.v`); `[$xsp:auth-*]` becomes `[$xsp-auth:*]` at every call site (about
75, in `xsp-auth.cxd`, `session.cx`, `store_xsp_*`). `cx-stdlib/xsp` is then the three frame defs and
moves whole to Ring 1 with its V half.

## RS-16 — the `cx` binary grades a corpus file (owner: D13a)

A pure-CX package repo's gate is `cx` on PATH plus its own `.cxd`. The binary gains a verb that grades
module corpus files with the SAME grading core the fixtures shards use (moved out of `vcx/tests/`
into a linked module; the shards' census unchanged), prints the graders' `PASS`/`FAIL` lines and
summary, exits by the CLI's exit-code rule, honours `--manual-clock`, and refuses a document suite it
cannot grade by name. The verb is specified on the CLI page; it exists in the cli and platform
profiles.

## RS-17 — the `-gc e` per-case growth is fixed at the root (owner: D3b)

A long-lived evaluator's per-case cost must be flat: what a finished env leaves reachable under
`-gc e` is found and freed in the runtime/env teardown (measured on `f9706fe84`: the connector shard
3,893 s with per-case cost growing 0.8 → 12–25 s under `-gc e`, 46 s at a flat ~80 ms under a tracing
collector). No grader recycling, no per-kind corpus split, no collector swap for the graders.

## Also ruled in the same session, operational (no id; recorded)

D1a the RS page landed as drafted; D2a the XSP codec's home as drafted; D4a #1592 re-rated
prio:medium; D5a #1594 closed, #1601 filed; D6a the runner derives `VJOBS` from the box (#1600);
D10a agents run in parallel without a count cap on dev2, opus by default; D11a merges batch per
union; D12a Fable only for the integrator session and for a runtime problem the owner names.
