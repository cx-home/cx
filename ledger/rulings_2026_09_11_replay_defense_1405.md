# RULED: 1405-a — replay defense lives in session's store seam and is ON by default; the assertion ID travels as `jti`; JWKS rotation re-fetches once

Fable, 2026-09-11 ~18:55Z, under the owner's delegation of 2026-09-09 05:50 ET. The owner may
override on #1354. Premises re-checked at `ac6a58527`: `session_attach_saml_impl` returns only
the minted `[session]`; `saml:claims` emits no `jti`; no `replay` anywhere in saml/session code or
corpus; `crypto_jwt_select_key` refuses an unknown `kid` with `CXER3714` and nothing re-fetches;
`session.md:1053` attributes JWKS fetch to crypto, which has none. #1407 (merged `7127d4514`)
already checks the logout token's `aud`.

1. **The assertion ID is a claim.** `saml:claims` emits `jti` = the assertion `@ID` and `exp` =
   `Conditions/@NotOnOrAfter` (already emitted as `exp` where present), so every path that reaches
   the claim set — `attach-saml` included — carries the identifier and its window. The OIDC ID
   token's `jti` (when present) and the back-channel logout token's `jti` (REQUIRED by the
   Back-Channel Logout spec) are the same claim on their paths.
2. **One replay table, in session's store seam** (S6, #1395): `session:replay-claim $jti $exp $cfg`
   records `jti` until `exp` (plus `cfg.leeway`) and refuses a second presentation inside the
   window with a new session code **`CXER4814 E_SESSION_REPLAY`** (the 4800–4849 band is
   registered to session as a whole; add the row to `session.md` §8). `attach-saml`, `attach-oidc`
   (S7's N-SESSION-1 path) and the logout handling call it; `session:reap` drops expired rows.
   **ON by default**: `cfg.replay` defaults to `true`; `false` is allowed only with a store that is
   not the per-process `mem://` default — a deployment that opts out says so in its config, in the
   open. The in-tree consumer is S7's deployment; the interop step replays a captured `Response`
   and a captured logout token and expects the refusal.
3. **JWKS rotation re-fetches ONCE, bounded.** When key selection fails with `CXER3714` (unknown
   `kid`) and the provider carries `jwks-uri`, `oidc:complete` / `refresh` / `validate-id-token`
   re-fetch the JWKS one time (under the `net` grant they already hold) and retry selection; a
   second miss is the `CXER3714` refusal, unchanged. The refreshed set is returned on the result
   (`[provider …]` or `[jwks …]`) so the caller can persist it; the module holds no cache (O-3
   stands). `session.md:1053`'s sentence moves the responsibility to oidc; `crypto.md:282`'s
   promised granted-fetch case is deleted (oidc.md:227 ruled it out) — spec text, delegated G3
   (flagged).
4. Refused: (b) surfacing the assertion element itself from `attach-saml` — a login path that
   hands back the raw assertion invites the caller to re-read it; the claim set is the contract.
   (c) a replay table in `saml`/`oidc` — both modules hold no state by design (S-6, O-3). (d) a
   cached JWKS with TTL inside oidc — a cache is state; one bounded re-fetch fixes the rotation
   break without one.

Order: after S7 (#1394) merges — its deployment is the consumer and its interop rows are the
graders. Spec text delegated (flagged): `saml.md` §3 (`claims` gains `jti`), `session.md` §3.1
(`replay`, `leeway`), §3.x (`replay-claim`), §8 (4814), the :1053 sentence; `oidc.md` §5 (the
one-time re-fetch), `crypto.md` §3.10/:282.
