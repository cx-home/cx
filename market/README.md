# The market — a XAP, dogfooded

The market is **not a platform**; it is a XAP whose features are ordinary
feature specs in this directory (distribution spec §5):

| Feature | Verbs |
|---|---|
| `catalog` | `publish` (act) · `yank` (act, attestation-issuing — §8, never reach-in) · `search` (observe) |
| `entitlement` | `issue-license` (act) · `revoke-license` (act) · `verify` (observe) |
| `commerce` | `quote` (observe) · `place-order` (act) · `record-settlement` (act, gateway-fed) · `fulfil` (act, **derived**: `[constituents entitlement/issue-license]`) |

The three specs **compose through the one W1–W6 gate** into the market's
single grammar (`[$xap:compose]`, M0), and the market runtime is an ordinary
`[$xap:run {grammar: G}]` — which makes every consequence of "market = XAP"
load-bearing and *tested*:

- **Auditability for free** — publishes, orders, settlements, license
  issuances are committed intents in the journal.
- **`commerce/fulfil` cannot launder authority** — it is a derived verb over
  `entitlement/issue-license`, so the PEP admits it only for holders of the
  *constituent* grant (N-COMPOSE-2 at the emit cascade, §8.2). A settlement
  gateway that can `record-settlement` cannot mint licenses.
- **Payment rails sit below the seam** — providers are gateway adapters
  feeding the `settlement` noun; the grammar above never changes, and the
  consuming runtime only ever sees the entitlement VC.
- **Bundles are catalog objects** (§5.3) — `[bundle name= version= [member …]]`
  documents published to the registry store, listed by `pkg-catalog`,
  entitled by member-set or bundle-reference VCs. Never composite features.
- **Markets federate** — N market catalogs merge into one discovery surface
  exactly as N XAPs compose into one experience; discovery is data, so the
  blend is a data merge, and every install still verifies against its origin.

Conformance: `conformance/stdlib/xap-dist.cxd` cases 039–043 (the market
worked case, the journaled choreography with the N-COMPOSE-2 denial lane,
bundle catalog objects with the growing bundle-reference entitlement, and
two-market federation).
