# `cx-fabric` — platform eventing (catalog entry)

```cx
[module-meta name=fabric tier=D status=current]
```

**Status:** Catalog entry Current (P0–P3 shipped: embedded + served tiers,
coord migration, adapters — #518/#531, closed); the normative design spec is
[`spec/03-approved/xap/fabric.md`](../xap/fabric.md) (03-approved, graduated
by owner ruling 2026-07-22).

Catalog entry for the `stdlib/fabric.cx` bundle and the
`fabric_stdlib_builtin` dispatch family — its OWN bundled package
(`[?lib 'cx-fabric' :as fabric]`, the cx-xap shape), NOT a `cx-stdlib`
module. One subscribe/emit surface, two planes: **durable**
(`publish`/`subscribe`/`receive`/`ack` — a fabric stream IS a journal
stream; delivery + consumer groups + store-persisted cumulative offsets,
at-least-once; group subscriptions may carry the §9.1 redelivery policy —
`max-deliveries` + `dlq` — dead-lettering a poison head to an ordinary
stream) and **transient** (`emit`/`read` — latest-wins channels, no
history; plus the §12.1 request-reply call convention —
`respond`/`request`/`serve`). Patterns are `bus.md` §2.2 reused verbatim.
Band CXER4920–4949. No capability of its own — persistence authority is the
underlying journal/store's. Conformance: `conformance/stdlib/fabric.cxd`
(36 enforced offline lanes over a mem:// journal).

This file exists because the stdlib-catalog-gate reads module-meta blocks
from `spec/03-approved/std-lib/*.md` only — the same thin-pointer pattern as
[`xap.md`](xap.md) / [`xsp-auth.md`](xsp-auth.md) / [`sql.md`](sql.md). Spec
content lives in the normative reference, not here.
