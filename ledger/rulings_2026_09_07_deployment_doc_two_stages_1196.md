# RULED: 1196-a — a deployment document has TWO STAGES, and `xap.cxs` describes
# only the first one

Date: 2026-09-07. Issue: cx-home/cx-private#1196. Campaign: v0.18.0 close-out
(#1354), Lane 1. Ruled by the campaign worker under #1354 rule 7.

## What the issue reports, and why both of its options are wrong

`xap.cxs` marks a deployment's feature-row pins `[opt]`, so a document naming
features by path alone validates clean and then refuses at `[$xap:host]` boot
with CXER4880 ("host requires fully pinned [feature] rows … re-pin the
deployment doc"). `manifest=`, which the host requires, is not in the schema at
all. The issue offers: (1) make the pins `[req]`, (2) have the host accept path
rows, (3) a "lower bound" — say in a comment that it depends.

Measured at `0fd41cee0`, both (1) and (2) are refused for cause:

- **(1) is refused** because it reds our own dogfood. `reference/shop/shop.xap.cxd`
  lines 14-16 are three path-only rows (`[feature name=orders
  package='./orders.feature.cxd']`), it is exercised by
  `vcx/tests/xap_umbrella_test.v`, and it validates green today
  (`--mode=strict`, exit 0). Marking `hash=`/`manifest=` `[req]` would also
  demand an author hand-write a Tier-1 content hash — the one field an author
  must never write.
- **(2) is refused** because the host's row requirement IS the verify chain: it
  fetches BY manifest hash, cross-checks the fetched manifest's name/version/
  hash against the row (CXER4888), and runs the full §3 chain. Accepting a path
  row means an unverified load path into the deployment host, for exactly the
  rows most likely to be hand-edited.

## What is actually true

The two artifacts are not describing one document differently. They are
describing **two stages of one document**, and `pkg-install` is the transition:

> `xap_pkg_install` … "rebuild the xap doc with the pin MERGED into (or appended
> to / creating) its section — one entry per name: **an existing same-name row (a
> stage-0 path ref) is updated in place, its foreign attrs (`package=`,
> `status=`) preserved** and its prior pin attrs + `[requires]` closure replaced"
> — `vcx/platform/stdlib_xap_dist.v`, the enable step

So the stages are **ADDITIVE, not exclusive**: `package=` is authored and
SURVIVES the install; `version=`/`manifest=`/`hash=` and the `[requires]`
closure are written BY `pkg-install`; `[libraries]` and `[clients]` sections are
created by it for those kinds. `[$xap:host]` consumes the second stage only.
(An earlier draft of these letters said a row carries `package=` OR the pins and
that mixing is an error. The enable step above disproves that; the ruling below
is the corrected shape.)

The schema describes stage 0 and nothing else. Measured — an installed-form
document validated against `xap.cxs`:

```
installed.xap.cxd:3:6: warn: S012: unknown attribute 'manifest'
installed.xap.cxd:4:8: warn: S001: unknown element <requires>
installed.xap.cxd:5:4: warn: S001: unknown element <libraries>
```

and the same three as **errors** under `--mode=closed`. The document the host
actually boots is undescribed by its own schema — a strictly larger gap than the
`manifest=` omission the issue names.

## The ruling

**1196-a. `xap.cxs` describes BOTH stages, and says which side writes each
field. The host keeps refusing an unpinned row, and its message names the
missing STEP rather than a manual act.**

1. **Declare what `pkg-install` writes.** `manifest::string [opt]` on
   `[feature]`; `[elem requires [card "0..1"]]` plus the `[requires]`/`[require]`
   declarations; the `[libraries]`/`[library]` and `[clients]`/`[client]`
   sections; and `[elem libraries]` / `[elem clients]` on `[xap]` itself.
2. **State the stage in the comments**, so the optionality is legible as
   conditional rather than free: `package=` is AUTHORED and survives install;
   the pin triple and `[requires]` are INSTALL-WRITTEN and are what
   `[$xap:host]` requires; a row without them is stage-0 and cannot boot.
   `version=`'s "informative; the hash is the truth" is corrected — the host
   cross-checks it and refuses on mismatch (CXER4888).
3. **The host's refusal names the step**: not "re-pin the deployment doc" (a
   manual act nobody can perform correctly) but that the row is in the AUTHORED
   form and the deployment must be installed — `[$xap:pkg-install XAP STORE
   REF]`, whose returned document carries the pins — to produce the form it
   boots.

### Why the pins stay `[opt]` — this is the answer, not a lower bound

The issue calls "state that it depends" its option 3 and a lower bound. That
framing assumes `cx validate` COULD refuse a stage-0 document if only the
schema said so. It cannot, for two independent reasons, and neither is a gap to
be closed later:

- **A stage-0 document is legitimately valid.** It is the authored artifact — the
  thing a human writes and commits, and the input `pkg-install` consumes. A
  schema that refuses it refuses the only form an author can produce.
- **The `.cxs` clause vocabulary is closed** — `req, opt, default, min, max,
  min-length, max-length, pattern, enum, card, ref, len, range, open, closed,
  keys` (`is_v0_8_clause_name`, `vcx/cx/data_bin_schema_driven.v`) — and carries
  no cross-attribute or conditional constraint. Even if a conditional were
  wanted, the document does not carry the stage as data, so there is nothing for
  a constraint to key on.

So the schema's job here is to describe both stages truthfully; the STAGE is a
lifecycle fact, and the artifact that knows it is the host. That is why item 3
is not cosmetic: after this change the schema tells no lies, and the one late
refusal that remains names its own remedy.

### `[deriver] package=` (letter 2)

Same treatment — make the schema truthful — which here means the opposite of
pinning. The host's own code is explicit: "`package=`/`doc=` are documentation
for the human reader and for tooling; run assembly binds name↔noun"
(`xap_host_doc_derivers`). Nothing reads it. The schema comment says "path/
package ref to the implementing component", which reads as a binding. It is
corrected to say it is advisory, so the `[opt]` there is legible as intentional
too.

### What this DELETES

The claim that `version=` is "informative"; the silence about `manifest=`,
`[requires]`, `[libraries]` and `[clients]`; and the host message's "re-pin the
deployment doc". Nothing is removed from the document format, and
`reference/shop/shop.xap.cxd` validates unchanged.
