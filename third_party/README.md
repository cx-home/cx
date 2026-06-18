# `third_party/` — vendored toolchain submodules

## `third_party/v` — the patched V compiler

CX builds against a **fork** of the V compiler (`https://github.com/cx-home/v.git`),
not upstream `vlang/v`. As of the CX-from-V eviction
(`spec/02-working/evict_cx_from_v_PLAN.md`) the fork carries **only CX-agnostic
runtime/mem-mgmt patches** ("Bucket-1") that are being upstreamed to `vlang/v`;
it contains **no CX-specific code**. The goal is for the fork to eventually be
replaceable by stock upstream V.

### What the fork still carries (Bucket-1, CX-agnostic)

1. **`-gc e` / vgc memory management** — architecture-E (Perceus RC front line +
   precise STW vgc backstop), the default GC for ordinary C-backend programs;
   plus the `-gc e` cgen correctness fixes and MP-concurrency hardening.
2. **macOS hardened-runtime `libgc` bypass for `-prod`** — skips the precompiled
   `gc.o` on macOS even under `-prod`, so `-prod` builds don't segfault on the
   broken Boehm GC. (System/`devbox` V bundles the broken GC — always build with
   this fork; never plain `v -prod` on macOS.)
3. **wasm32-emcc `vmemcpy` null-page guard fix** — collapses V's low-address
   pointer guard to the `n == 0` early-return under `-d wasm32_emcc` (the guard
   otherwise drops legitimate copies of low-address stack temporaries).
4. **`net.mbedtls` DTLS-over-UDP** + the `@[thread_local] __global` cgen support
   — general V networking / codegen capabilities (the latter also used by
   `vlib/v2/profiler`).

### What is NO LONGER in the fork (vendored into CX)

CX's event-loop HTTP/SSE/XAP transport is now vendored in **`vcx/transport/`**
(`picoev`, `pico_http_parser`, `picohttpparser` + the CX shared-listener/held-SSE
patch as `vcx/transport/picoev/cx_shared_listener.v`). The scope-aware region
allocator (`-d cx_regions`) was retired entirely. CX no longer imports
`vlib/picoev` and no longer references any `cx_region_*` builtin — see
`vcx/transport/README.md`.

### Canonical pin

| | |
|---|---|
| Remote branch (carries the Bucket-1 patch series) | `cx-home/v-cx-patches` |
| Immutable tag (GC anchor → a `-prod`/dist pin) | `cx-patched-v` |
| Superproject gitlink | the SHA your branch records (a commit on `cx-home/v-cx-patches`) |

Each superproject branch pins a specific commit on `cx-home/v-cx-patches` via the
submodule gitlink (`git ls-tree HEAD third_party/v`). The annotated tag
`cx-patched-v` anchors a commit so it can never be garbage-collected off the
remote if the branch is moved or force-pushed — the failure that once made fresh
clones fall back to the broken system V.

### Recovery — "fatal: remote error: ... not our ref `<sha>…`"

If `git submodule update --init --recursive` fails because the remote no longer
serves the pinned SHA, the commit was dropped from `cx-home/v`. Restore it from
any checkout that still has it locally (push access to `cx-home/v` required);
`<sha>` is the gitlink your branch records:

```sh
cd third_party/v
git cat-file -e <sha>^{commit}                       # confirm you hold it locally
git push origin <sha>:refs/heads/cx-home/v-cx-patches # restore the branch tip (ff)
git tag -f -a cx-patched-v <sha> -m 'cx patched V pin'
git push -f origin refs/tags/cx-patched-v
```

Then verify in a throwaway worktree:

```sh
git worktree add --detach /tmp/cxv-check HEAD
git -C /tmp/cxv-check submodule update --init --recursive third_party/v   # must succeed
git worktree remove --force /tmp/cxv-check
```

If **no** checkout anywhere still has the commit, the Bucket-1 patches must be
re-applied on top of a V revision the remote does have, pushed to
`cx-home/v-cx-patches`, and this pin (gitlink + table above) updated to the new
SHA.
