# `$xap:pkg-*` — feature distribution & market (catalog entry)

```cx
[module-meta name=xap_dist tier=D status=current]
```

**Status:** Current (owner G3 2026-07-12, #363 item 6(a))

Catalog entry for the `xap_dist_stdlib_builtin` dispatch family — the
stage-1 packaging surface `$xap:pkg-tree` / `pkg-seal` / `pkg-sign` /
`pkg-publish` / `pkg-install` / `pkg-verify` and the market/lifecycle
operations built on it. The normative reference is
[`xap/xap_feature_distribution_market.md`](../xap/xap_feature_distribution_market.md)
(graduated from `02-working` by the same ruling). This file exists because the
stdlib-catalog-gate reads module-meta blocks from
`spec/03-approved/std-lib/*.md` only — the same thin-pointer pattern as
[`sql.md`](sql.md) / [`redis.md`](redis.md) (#294). Spec content lives in the
normative reference, not here.
