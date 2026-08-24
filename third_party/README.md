# `third_party/` — vendored toolchain submodules

## `third_party/v` — the patched V compiler

CX builds against a **fork** of the V compiler (`https://github.com/cx-home/v.git`),
not upstream `vlang/v`. As of the CX-from-V eviction
(`spec/02-working/evict_cx_from_v_PLAN.md`) the fork carries **only CX-agnostic
runtime/mem-mgmt patches** ("Bucket-1"); it contains **no CX-specific code**.

### Maintenance posture: the fork is PERMANENT

**Do not treat this fork as a staging area for patches on their way upstream.**
It was framed that way until 2026-08-24 — "the goal is for the fork to
eventually be replaceable by stock upstream V" — and the framing cost real
maintenance attention. Two tracked upstream issues (`vlang/v#27178`,
`vlang/v#27179`) closed without merging, and the gate that watched them went
red demanding a decision; the audit that followed found upstream 0.5.2 already
carried both changes by another route, so neither had been fork divergence for
some time. Nothing was pending. The expectation was the defect.

The posture that replaced it: **CX owns this fork indefinitely.** The largest
divergence — architecture-E memory management — is not something upstream V has
or plans, and the fork-safety patches (pinned bootstrap, no phone-home, `v up`
refusing to rebase) exist *because* the fork is a fork and can never be
upstreamed at all. Upstreaming an individual CX-agnostic patch is welcome when
someone wants to do the work, but it is opportunistic, not a roadmap, and no
gate waits on it.

What replaces the watching: **[`scripts/v_fork_register.cxd`](../scripts/v_fork_register.cxd)**
is the register of the fork's deliberate divergence — the upstream commit the
series sits on, one row per fork commit, and the reason each patch *family*
exists. `make check-v-fork` compares it against the actual commit set in
`third_party/v` and fails when the two disagree in either direction: a fork
commit with no row is **undocumented divergence**, a row with no commit is a
**stale entry**. It is offline and deterministic, and it sits in `TEST_TARGETS`,
so an undocumented fork patch cannot reach a release.

**When you land a patch on the fork**, move the submodule pin and add its row to
the register in the same change. If no family fits, write a new one — the
`reason=` is the documentation, and an empty one fails the gate. Rebasing the
series onto a newer upstream V changes every SHA and reds the whole register at
once; that is deliberate, because a rebase is exactly when the inventory has to
be re-confirmed rather than silently carried.

### What the fork carries (Bucket-1, CX-agnostic)

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

## `third_party/re2` — vendored RE2 (regex engine)

Pinned to **2023-03-01**, the last pre-abseil release (later releases drag
the full abseil dylib closure — ~60 libraries — which made the shipped
darwin binary non-self-contained; #520 field evidence, fixed by #573). The
`vcx/Makefile` `re2-static` target builds `obj/libre2.a` in-tree with re2's
own plain Makefile, and `vcx/cx/regex_re2.v` links the archive statically —
no system re2 package on any platform, full source determinism. The shim
(`vcx/deps/re2_shim/`) uses only the stable compile/match/replace RE2 API,
which is identical across this pin and later releases; moving the pin is a
build-system change, not an API change. BSD-3 license — `LICENSE-re2.txt`
ships in every release tarball.
