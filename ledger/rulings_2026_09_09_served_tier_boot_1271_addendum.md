# Addendum to 1271-c1 / 1271-c2 — what the first gates carrying `d92c2ceb7` measured (Fable, 2026-09-09 21:15Z)

`test_xap_host_served_journal_present_and_store_mismatch_refuses` red the gate
deterministically at `699dfea4d`, `3ae64d274` and `d7b95bc53`, and the red hid
two defects behind one test-ordering flake:

1. **A deployment declaring no `[features]` could not boot** — again. `4d21eb8a2`
   (1271-c1) made the registry open conditional, but the host still composed
   over the empty feature set at `stdlib_xap_host_notd_wasm32_emcc.v:223`, and
   `compose` refuses `E_XAP_COMPOSE_EMPTY` there by design (a GATE over nothing
   verifies nothing, §3.1 identity). The host is not gating; it boots a runtime
   whose grammar is empty. Composition is now skipped when there is nothing to
   compose and the runtime gets an empty `[grammar]`; the runtime bindings and
   the 1271-c2 check run as before.
2. **The store-mismatch check attached the deployment store under the WRONG
   tenant.** `xap_host_served_journal(store, tenant, rt_id)` used the
   deployment tenant (the `[xap name=…]`, `toy`) while the bound chain lives
   under the journal binding's `tenant=acme`; the store answered a genesis head
   against the fabric's seq=1 and the AGREEING deployment was refused as a
   mismatch. `XapJournalBind.tenant` (the binding's `tenant:` else the runtime's)
   rides onto `XapRuntime.journal_tenant`, and the check attaches for that.
3. **The test started the fabric daemon before awaiting the store**, so on a
   loaded box the fabric's boot-time `open fabric` died with `CXER1101
   E_STORE_BACKEND_UNREACHABLE (status -1)` and the test panicked
   `fabric-serve never came up` — worker C's take-2/take-3 shape. The store's
   `/ready` and XSP port are awaited first; the store's kill is deferred as
   soon as it is spawned.

Measured: the umbrella file passes alone in 80 s with all three (previously
red at arm (b), then at arm (a)). RULED tokens: 1271-c1, 1271-c2 — this lands
what those rulings ordered; nothing new is ruled.
