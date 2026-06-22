# patches — gated fork diagnostic instruments

`git apply`-able instruments for the V fork (`third_party/v`), each behind a `-d` flag so
the default build is unaffected. Apply, build a named diagnostic binary, run the repro,
then **revert before committing real work** (`cd third_party/v && git checkout -- .`).

Build pattern (from repo root):
```
cd third_party/v && git apply ../../tools/vgc-debug/patches/<name>.patch
cd ../vcx && ../third_party/v/v -n -w -cc cc -gc e -d <flag>... -o target/<bin> cmd/
```
Repros live in `../../vcx/tests/soundness/` (`serve57.cx` multi-reactor HTTP;
`workers8.cx` 8 concurrent `[?worker]`). Run multi-reactor:
`CX_HTTP_WORKERS=8 target/<bin> --allow-all vcx/tests/soundness/serve57.cx` + `wrk -t12 -c200 -d4s`.

## `passive_detector.patch` — the sweep-while-live ORACLE  (recommended first tool)
Flags `-d vgc_passive -d vgc_nosweep`. Adds a UAF detector at the crash-path read
(`map_clone_string` / `string.clone`): if the source key buffer was freed-while-live it
emits `0xbf1`=buf `0xbf2`=len `0xbf3`=size-class. `-d vgc_nosweep` disables the swept-log
sweep-hook (the ~14% masker), leaving the non-masking ~6.3% detector. This is the
masking-proof oracle used by the soundness gate. (With the sweep-hook on — drop
`-d vgc_nosweep` — a read matched to a swept-log entry emits `0xc0de`/`0xc0d1` = GOLD
freed-at-gen correlation, but that variant masks; oracle-only is the default.)

## `holder_find.patch` — read-time persistent-root search  (reference; defeated)
Flag `-d vgc_holderfind` (composes with the detector). On a detector-confirmed victim,
searches stacks/arena/anon for the holder, excluding vgc globals + the reading frame.
Kept for reference: the immediate holder (keys-array slot) is **co-freed** with the
victim, so this returns branch-3 ("no persistent holder") — it cannot localize a
co-swept subtree. See the case study in `../README.md`.

## `bstep_*` — B-STEP single-step root-coverage localizer
`bstep_fork.patch` (fork machinery: mach single-step controller in vgc_platform.h +
gated logic) + `bstep_vgc_bstep_d_vgc.c.v` (copy into `third_party/v/vlib/builtin/`,
untracked — NOT included in fork.patch) + `bstep_matcher.patch` (a 2-line gated cx-private
hook at `MatchEnv.clone` exposing the source bindings keys-array). Flag `-d vgc_bstep`.
Single-steps one `MatchEnv.clone` and, at each instruction, checks whether the source
keys-array is reachable from vgc's captured roots (GP+NEON+`[sp,base]`); a window where
it isn't = a real GC suspend there would free it. Result on #63: F1 — within-clone,
own-thread coverage is complete (0 windows over 15k steps), so the miss is cross-thread.
Apply order:
```
cd third_party/v && git apply ../../tools/vgc-debug/patches/bstep_fork.patch
cp ../../tools/vgc-debug/patches/bstep_vgc_bstep_d_vgc.c.v vlib/builtin/
cd .. && git apply tools/vgc-debug/patches/bstep_matcher.patch   # cx-private hook (gated)
```
Harness: a single-line nested `[?let]` chain (multi-line / top-level `[?reduce]` render
as data, don't eval). Run with `VGC_NEXT_GC_MB=100000` (GC off) so vgc's own mach-suspend
can't race the single-step.

## Note
These patch against the fork as of the #63 work (around `b9de83a69e`). Line offsets may
need `git apply --3way` or `--reject` against a drifted fork; the instruments themselves
are gated and self-contained.
