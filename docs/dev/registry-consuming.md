# Consuming a registry — verify, install, pin, vendor

The consumer pipeline is `discover → acquire → verify → compose-gate →
consent → enable`, fail-closed at every stage. Governing spec: the feature
distribution & market spec — the lifecycle and function-surface sections.

## Verify and discover

Every check is offline-verifiable (hash, signature, VC chain) — a vendored
mirror is as good as the origin. Against the live marine registry (verified):

```cx
[?lib 'cx-xap' :as xap]
[?lib 'cx-stdlib/store' :as store]
[?let [= $reg [$store:open-opts "file:///…/xap-marine/registry/store"
                                [map read-only="true"]]]
 [= $v [$xap:pkg-verify $reg "own-ship@0.1.1"]]
 [= $cat [$xap:pkg-catalog $reg {term: "nmea"}]]
 ($v@status, $v@kind, [$count $cat//package])]
# → ('ok', 'feature', 1)
```

- Open registries **read-only** (`[map read-only="true"]`) — then plain
  `--allow-read` suffices; a default open asks for `write` too.
- `pkg-fetch` resolves `name@version` (or a manifest hash directly) to the
  manifest; aliases are consulted only to *discover* hashes — trust never
  rests on one.
- `pkg-catalog` is discovery over any store — alias-table-driven locally,
  CXPath pushdown on a served `cx-store://` handle; the same call works in
  both, so graduating the registry changes no consumer code. Discovery is
  never trust: install re-runs the full chain on whatever discovery surfaced.

Failure lanes: absent alias/object `CXER4886`; content re-hash mismatch
`CXER4881`; bad signature `CXER4882`; failed VC `CXER4883`; gate rejection
`CXER4884` carrying the exact conflict values.

## Install — fetch → verify → per-kind gate → consent → enable

`[$xap:pkg-install XAP STORE REF OPTS?]` takes the `[xap …]` deployment doc
(or a previous install's report — it chains) and returns the doc with the
package **pinned by hash** and its `requires` closure resolved beneath it.
Verified:

```cx
[?lib 'cx-xap' :as xap]
[?lib 'cx-stdlib/store' :as store]
[?let [= $reg [$store:open-opts "file:///…/xap-marine/registry/store" [map read-only="true"]]]
 [= $xap0 [xap name=my-helm version=0.0.1 [features]]]
 [= $done [$xap:pkg-install $xap0 $reg "own-ship@0.1.1"]]
 [$count $done//features/feature]]
# → 1 — own-ship pinned under [features], requires closure resolved beneath it
```

Per-kind gates: a **feature** meets the compose gate (W-gate over the enabled
set ∪ candidate) plus the exports-surface check; a **library** meets the
module-surface check (every declared def present, Tier-2 identities match); a
**client** meets client-spec validation. A library never meets the compose
gate; a feature never skips it.

**Consent = grants.** With `OPTS.runtime` + `OPTS.grantee`, install issues
*exactly* the manifest's `needs` set as delegations — enabling **is**
granting; there is no installed-but-ungoverned state, and a runtime request
beyond `needs` is PEP-denied (default-deny). A library has no `needs` and
receives no grants.

## The pin view, in practice

The marine repo's consumer program is `registry/pin.cx` — it installs every
feature named by `xap.cxd` (plus required libraries) from the registry,
chaining `pkg-install`, and writes the fully pinned deployment doc:

```sh
make registry-pin      # re-pin xap.cxd from the registry (fails loud, writes nothing on error)
```

Prove the lockfile view is live, not decorative — the stage-1 self-test
re-verifies **every pinned feature against its pin** from the committed
store, checks compose determinism, and resolves wire verbs through ρ:

```sh
cd xap-marine && cx --allow-all tools/stage1-test.cx
```

## Rollback and updates

- **Update** = publish a new version (a new hash) and explicitly re-pin. An
  update that would rebind existing utterances surfaces as ambiguity prompts
  (invariant N-COMPOSE-1), never silent change; the composer can diff two
  grammars — they are data — before you move.
- **Rollback** = re-pin the previous hash; the composed-grammar hash returns
  to its previous value. A downgraded feature must tolerate event kinds a
  newer version introduced (open schema mode is the floor).
- **Yank/revocation** are attestations published at the market — never
  remote reach-in (invariant N-DIST-1); a running XAP is untouched, its
  composer surfaces the warning. The end-to-end yank flow awaits the market
  composer surface — **specified, not yet implemented** (see
  [marketplace](marketplace.md)).

## Vendoring / air-gapped installs

`clone` the registry store (or a subset via fetch-by-hash) into a local
store; verification and install proceed identically with no network — the
offline-install lane is conformance-fixtured. `xap-marine/tools/vendor.cx`
materializes required library packages from the registry, verified.
