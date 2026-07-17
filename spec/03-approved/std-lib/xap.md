# `cx-xap` — XAP experience layer (catalogue entry)

```cx
[module-meta name=xap tier=D status=current]
```

**Status:** Current (owner ruling 2026-07-12, #363 item 3(a))

Catalogue entry for the `stdlib/xap.cx` bundle and the `xap_stdlib_builtin`
dispatch family. The normative reference is
[`xap/xap.md`](../xap/xap.md) — the XAP paradigm and orchestrator:
component/surface/view-tree constructors, intent registration + the committed
cascade, journal-folded state, the resolver hook, content-negotiated render,
the dial/RACI delegation wrappers, `[$xap:serve]`, and `[$xap:init]`. The
design is frozen there; the empirical resolver-accuracy gate (§20/§26) remains
open and is unaffected by this catalogue linkage.

This file exists because the stdlib-catalogue-gate reads module-meta blocks
from `spec/03-approved/std-lib/*.md` only — the same thin-pointer pattern as
[`sql.md`](sql.md) / [`redis.md`](redis.md) (#294). Spec content lives in the
normative reference, not here.
