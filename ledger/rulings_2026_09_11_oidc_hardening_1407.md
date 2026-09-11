# RULED: 1407-a — the four OIDC hardening gaps and the four smaller ones: every row implemented in one lane except the logout-token `jti` replay, which is #1405's replay store

Fable, 2026-09-11 ~14:20Z, under the owner's delegation of 2026-09-09 05:50 ET. The owner may
override on #1354. Issue: #1407 (zero comments before this; measured at `3ca1d0b39`, re-checked
against `5152f3f0e` before ruling — the S11 landing already made `sub` required and enforced
`at_hash` on a plural `aud` as fallout of 1399-a, but neither is GRADED, and `expected-alg`
forwarding and the logout token's `aud`/`typ`/`jti` are absent from the code).

## Rulings, row by row (all (a) unless stated)

1. **`sub` REQUIRED** on every ID token the module validates (`complete`, `refresh`,
   `validate-id-token`): a token without `sub` is `CXER5304`-class token-invalid, and `oidc.md`
   §5 says `sub` is the only stable subject identifier (a deployment keys users on it, never on
   `email`). Graded: a negative arm. **(b) warn-only — refused**: a warning nobody reads is the
   `email`-keyed deployment this issue describes.
2. **`at_hash` REQUIRED when `aud` is multi-valued** (the §5 rule already in the spec): an
   ID token with plural `aud`, a correct `azp` and no `at_hash` is refused. Graded: the negative
   arm plus one positive arm with a correct `at_hash` (the machinery has zero cases today).
3. **The algorithm allow-list can be NARROWED by the caller, never widened**: `opts.alg` — one
   `alg` or a list — on `complete`, `refresh`, `validate-id-token` and `userinfo`, forwarded as
   crypto's `expected-alg`; a token whose `alg` is outside the narrowed set is `CXER5304`-class
   token-invalid naming both. `HS*` and `none` stay permanently refused whatever the caller
   lists (a caller cannot list its way past J-4 — the 1409-a exception is client assertions
   only). `kid` pinning is NOT added: JWKS rotation makes a pinned `kid` a self-inflicted outage;
   the allow-list is the honest knob. **(b) a config-level `alg` — refused as the only form**:
   the config already carries the provider's advertised `id_token_signing_alg_values_supported`,
   and a deployment's policy is the caller's, per call, like every other `opts` key.
4. **Back-channel logout token**: `aud` MUST contain the client id (`CXER5304`-class); `typ`,
   when present, MUST be `logout+jwt` (RFC 8725 §3.11 / OIDC Back-Channel Logout §2.4 — absent
   is accepted, a wrong value is refused); the `events` claim rule and the nonce-absent rule
   stay as graded. **`jti` replay tracking is SCHEDULED onto #1405** (S16, the replay store
   RULED under 1404-a's `jti←@ID` line): a replay table needs the store seam, and building a
   second one here is the "two dedup machineries" this repo refuses. `sid`→session binding is
   S7's (#1394 mounts the logout route and knows the session).
5. **`complete` refuses an `[auth-request]` with no `code-verifier`** (`CXER5310` argument
   invalid) — a hand-built request never POSTs an empty verifier.
6. **`config` REQUIRES `issuer`** (`CXER5302`, "malformed provider element" — the row the spec
   already assigns at `config`).
7. **`code_challenge_methods_supported` is recorded** on the built provider, and a `:none`
   (public) client against a provider that does not advertise `S256` is `CXER5307` at `begin`
   (the §6 guard the spec already states and the code could not enforce). A provider that omits
   the field entirely is treated as NOT advertising (fail closed; the spec sentence says so).
8. **Trailing-slash tolerance is the RULE, stated and graded**: issuer comparison is equality
   after trimming trailing `/` on both sides — `oidc.md` §3 "exactly" and §5 "never a prefix"
   are rewritten to say exactly that (a prefix is still refused; `https://idp.example/` vs
   `https://idp.example` is equal). Graded: one positive arm with the slash and one negative
   prefix arm.

## Spec text, delegated G3 (flagged for the owner)
`oidc.md` §3 (`config` requires `issuer`; `code_challenge_methods_supported` recorded), §5
(`sub` required; plural-`aud` `at_hash`; `opts.alg`; the trailing-slash rule), §6 (the `:none`
guard as enforced), the logout-token section (`aud`, `typ`), §8 (the rows that change — reuse
the allocated `CXER5301–5310` band; no new code unless a row is genuinely missing, and then
`governance.md` gets the registration). Nothing else in the spec moves.

## Graders
One corpus arm per refusal above plus the positive arms named; the interop lane
(`scripts/sso_interop`) gains a `login-alg-narrowed` row if the driver can express it, else the
corpus alone. `oidc.md` §8's rows and the census delta prove the cases graded.
