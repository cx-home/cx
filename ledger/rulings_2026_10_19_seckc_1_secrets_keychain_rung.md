# Ruling 2026-10-19: cx-platform-secrets#2's scope is the keychain rung plus the consumer interface working end to end

**Status: RULED (the owner, via the integrator on STREAMS/state/claims.txt, RULING SEC2 of 2026-10-19T19:48:30Z and SEC2-SCOPE of 2026-10-19T20:06:16Z; recorded by nseat).** The owner's ids `SEC2` and `SEC2-SCOPE` are not id-shaped, so this page records both decisions as **SECKC-1**.

## SECKC-1 — D1 = (a), D2 = (a): the keychain rung and the consumer interface; the later rungs stay §9.1's

> RULING owner 2026-10-19T19:48:30Z SEC2 = nseat takes cx-platform-secrets#2 now (owner: "the one secrets item can be done, should be done before Andrew takes over. He is expanding the secrets capability but we need this one working now")

> RULING owner 2026-10-19T20:06:16Z SEC2-SCOPE: D1 = (a) and D2 = (a) — owner verbatim: "just a minimum keystore for us to use now to complete other items such as reference apps".

What the decision covers:
- **The keychain rung** (secrets.md §7, §9.2 (1)): `kind=keychain` and a sealed provider's `key-from=keychain:<service>/<account>`. The keychain is reached through its own capability row: `keychain` in security.md §2 and §2.1, read by cx-stdlib/env's `keychain-read` (env.md §3.6, `CXER2505 E_ENV_KEYCHAIN_UNAVAILABLE`, registered in governance.md §9.6's env band). It reads the macOS Keychain or the Linux Secret Service. `--allow-common` does not carry the capability.
- **The consumer interface, end to end** (D2): the flow runner's signing key is named by handle and resolved through `with-resolved` at each anchor, and the opts path retires (flow.md §4.23). A secret-held key is consumed at the journal's signing point (journal.md §4.8). `cx flow serve` and the XAP host both read the `[runtime [secrets …] [authz …]]` block and the `[snapshots every= key=]` row. composition.md S-44 records the flow → secrets seam. Connector credentials already took the seam (connector.md §4.2 step 3).
- **Out of scope:** kms, vault, tenant scoping and Secret-of-T stay secrets.md §9.1's. They are a follow-up issue for the repository's developer.

Where it lands: cx-core-code 79e251ad and 9aa59ec7; cx-platform-store 81ae2b9; cx-platform-secrets b64cf9c; cx-platform-flow 44f9a45; cx-platform-xap b1c017f; and the cx-private pin that cites this page.

Cites: cx-platform-secrets#2, cx-platform-xap#9, cx-private#1945.
