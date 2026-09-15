# Owner decisions 2026-09-15 ~18:30Z — "1a 2a 3a 4a" (RULED: INT-20, 1503-b, 1502-b, 1457-a)

The four questions posted on #1354 at 16:10Z, each answered by letter.

| Id | Decision |
|---|---|
| **INT-20** | **(owner, letter 1(a))** The agent cap stays at TWO — one code, one spec — under INT-17's scope (139 open issues in v0.18 at the time). The integrator does evidence-only work itself; landings are batched so one post-merge run closes several issues. |
| **1503-b** | **(owner, letter 2(a))** `db_access.md` §9 gains one sentence stating the truth per backend: a single multi-row statement's partial effect is the backend's — sqlite applies rows until the first refusal (row 1 in, `changes=0` on the refusal), pg and mysql roll the statement back — and a caller wanting all-or-nothing wraps the statement in §9's transaction. One case per backend (sqlite enforced, pg/mysql advisory). No implicit savepoint. |
| **1502-b** | **(owner, letter 3(a))** `crypto` gains `xml-verify` — enveloped and detached, `xml-sign`'s exclusive c14n, digest roster and two algorithms, KeyInfo by reference — as its own branch (spec section + `crypto.cxd` cases + code) BEFORE the `soap` code phase, whose inbound side consumes it (#1507). The SAML verifier keeps refusing a detached `Reference` (S-3) and is not widened. |
| **1457-a** | **(owner, letter 4(a))** SFTP's SSH transport is **libssh2 over the fork's own mbedTLS** — a V-fork pin with a `v_fork_register.cxd` row and the wasm stubs (the mbedtls precedent, INT-4) — as `sftp.md` §1.3 recommends; option (b), an SSH transport written in V, is not taken. |
