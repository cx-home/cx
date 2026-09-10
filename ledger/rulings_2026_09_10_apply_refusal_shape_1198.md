# RULED: 1198-a — what `apply` may return, and a refusal the host does not recognise is SAID, never dropped

**Fable, 2026-09-10 05:20Z, under the owner's delegation:** items 1 + 2 of the
issue together. Refused item 3 alone (a schema constraint on the apply result
at authoring time): the result is a VALUE the feature computes at runtime, so
a static schema would constrain the literal shapes an author writes and miss
the computed ones — the host is the one party that sees every result, and it
is where the contract is enforced.

## What was wrong

The host recognised ONE element name: `[refused reason=…]` was acked with its
reason; an `[err …]` was acked `reason=apply-error code=<code>
detail=<message>` — so `[?element "err" [?attr "reason" "party id already
registered"]]` (the issue's shape) became `code='' detail=''`, which reads as
"the module gave nothing"; and any other element was acked `ok=true` as a
success. Nothing in the §1.2 contract said what `apply` may return, so the
shape was discoverable only by copying a working feature (five right,
seventeen wrong in one catalog).

## What changed

- `xap_feature_distribution_market.md` §1.2: a normative paragraph beside the
  entry-point table — success / refusal (`[refused reason= code= detail=]`) /
  failed act (`[err]`, `reason=`/`detail=` stand in for a missing `message=`)
  / unrecognised (a `reason=`-bearing or refusal-named element is acked
  `ok=false reason=apply-error detail='unrecognised apply result [<name> …]:
  <its words> — a refusal is [refused reason=…]'`). §1.2's body fingerprint is
  RE-PINNED at the same revision (an editorial move: every module that answered
  a recognised shape before answers identically; only shapes that were being
  swallowed or emptied now say so).
- Host (`stdlib_xap_host_notd_wasm32_emcc.v`): `[refused]` carries `code=` /
  `detail=` when supplied (absent ones absent, never empty); `[err]` reads
  `reason=`/`detail=` when `message=` is missing; `xap_apply_result_words` +
  `xap_refusal_like_names` decide the unrecognised branch.
- Test (`xap_umbrella_test.v`, the door feature): `[bare 'true']` → `[err
  reason=…]` keeps its words on the ack; `[odd 'true']` → `[nope reason=…]` is
  acked ok=false naming the unrecognised shape; neither mutates state.
