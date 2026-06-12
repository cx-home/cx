# A7 — fork forward-port to latest V (cx onto June-11 upstream)

The dominant integration risk: get cx's V off its stale base and onto the latest
upstream, carrying ALL cx patches + the architecture-E work. User directives
2026-06-12: base on **a83aabb** (upstream Jun-11, the tip E was developed on),
retire the misleading **"v0.7.0"** V-fork branch name (the V version is actually
**0.5.1** on both sides — "0.7.0" was a stale cx-side label; the fork's upstream
base was only ~May-20, ~3 weeks behind, not ancient).

## What was done (in the third_party/v submodule checkout = cx-home/v fork)
1. Fetched `a83aabb` from the local clone (`vlang-v-latest`); the clone is shallow,
   so its deeper ancestry is absent, but a83aabb's tree is complete and usable.
2. New branch **`cx-home/v-cx-patches`** (the rename off `cx-home/v0.7.0-cx-patches`)
   reset to a83aabb, then **cherry-picked the 8 cx patches** onto it (cherry-pick,
   not rebase — rebase walks a83aabb's missing shallow ancestry; cherry-pick only
   needs each cx commit's own parent). 2 conflicts from 3 weeks of upstream drift,
   both resolved:
   - `consts_and_globals.v` (`@[thread_local]` codegen): upstream replaced the old
     volatile-only `modifier` with a `qualifiers` builder + relocated the setup →
     grafted `if node.attrs.contains('thread_local') { qualifiers += '__thread ' }`
     onto `qualifiers`.
   - `ssl_connection.c.v` (DTLS): upstream added an `alpn_protocols` struct field
     where the cx patch added `dtls_handshake_min/max_ms` → kept both.
3. **Applied the full E work** (`vgc-collector-linux.patch`, generated against
   a83aabb) with `git apply --3way`: **all 10 files clean**, including `cmain.v`
   (no overlap with the cx P0 marker-pin). Added the untracked `perceus.v` cgen pass
   (deep-drop analysis present). Committed as one E commit.
4. Branch tip **`677770ddc`** = a83aabb + 8 cx patches + E.

## Build + validation (forward-ported V)
- Bootstrap: stale fork `v` binary CANNOT compile the Jun-11 source (compiler drift)
  → used `make` (self-hosts from vc). **"V has been successfully built", V 0.5.1.**
- `-gc e` on the forward-ported V: **g_churn 100 1 30 = 10/10**; corpus G-DIFF
  `none == e` = 3/3. E composes + is correct on the latest-V base.
- All cx patches compile (make built V with cx_region/DTLS/picoev/thread_local/P0).

## Safety
The branch lives only in the local submodule checkout (not yet pushed). Captured as
a range bundle `bench/parallel-alloc/A7-forward-port.bundle` (the 9 forward-port
commits; prerequisite = a83aabb). Restore: `git bundle unbundle` onto an a83aabb
checkout. **cx-private's gitlink is NOT bumped yet** (still 0807dd15f) — correct: the
bump waits on the full cx gate.

## Remaining A7 sub-steps (next)
1. **Publish the branch to cx-home/v.** Needs a83aabb's FULL history (the branch is
   rooted at the shallow a83aabb locally). Either GitHub-sync cx-home/v with vlang/v
   upstream first, or fetch vlang/v full history locally, then push
   `cx-home/v-cx-patches`. Then delete/retire `cx-home/v0.7.0-cx-patches`.
2. **Bump cx's third_party/v gitlink** to the new tip + update `.gitmodules` branch
   ref away from v0.7.0.
3. **Full cx gate under the new V (B14):** build cx against the forward-ported V,
   `make test` + conformance, `-prod` and non-prod. This is the real payoff — the #14
   `[par]` workload measured under E in cx (B13).
