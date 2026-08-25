# AUDIT — V module-cache key completeness (#700 wave 2 part i, under VC-23)

**Status:** audit record, produced by the Fable 5 cache-soundness session
2026-08-24 per VC-23 §3(i). This file states findings and their evidence
class; it rules nothing. Authority for the work: VC-21/VC-22/VC-23 in
`rulings_2026_08_24_0170_campaign.md`.

**Charter sentence** (Makefile, #572 note): *"a stale cache layer can inject
a duplicate V-runtime symbol … the cache-key root fix is the V-fork
follow-up."*

Every row is labeled **measured** (reproduced this session, probe scripts in
the session scratchpad; the shipped gate re-runs them), **code-cited** (file:
line), or **inferred**. Probes ran in devbox against the fork `v` at
`3a6097574` (also a `-d trace_usecache` build of the same tree for phase
attribution).

## The key, as it exists

A cached module object's identity is `hash(vopts + module_path)` where
`vopts` = `original_vopts` (+ `#` + cc-stage temporary salt once
`set_temporary_options` has run):

- `original_vopts` (pref/default.v:317-328 → vcache.v:49-96): `@VHASH` |
  `backend | os | ccompiler-NAME | is_prod | sanitize` | sorted define
  NAMES | cflags | third_party_option | lookup_path | `vexe:size:mtime`
  (the cx #151 compiler-identity salt).
- temporary salt (cc.v:1077 ← thirdparty_object_args cc.v:1251-1283):
  `-std`, env `CFLAGS`, `ccoptions.args` (cflags, `-arch`, `-fwrapv`,
  warnings), `guessed_compiler` (= the ccompiler NAME string, cc.v:781).
- Source freshness is a SEPARATE mechanism: a global `.hashes` record diffed
  per build (rebuilding.v:77-223), keyed by `new_cache_manager(all_files)` =
  file PATHS + vexe salt — no config. Serve time
  (`rebuild_cached_module`, rebuilding.v:296-321) checks only existence +
  the `.embeds.txt` manifest.

## Key-completeness table

| # | input that can change cached-object bytes | where it enters the key | verdict | evidence |
|---|---|---|---|---|
| 1 | V release (`@VHASH`) | default.v:319-321 | keyed | code-cited |
| 2 | V binary build — fork patch level, `v self`, uncommitted edits | vexe size+mtime salt, vcache.v:77-89 (#151) | keyed | measured (VOPTS in every `.output.description.txt`) |
| 3 | backend, target OS, `-prod`, sanitize | default.v:323 | keyed | measured |
| 4 | cc NAME (`-cc`) | default.v:323 | keyed | measured |
| 5 | **cc BINARY identity** — resolved path, version, content behind the name | **nowhere**: `guessed_compiler = v.pref.ccompiler` (cc.v:781), no version/path/mtime anywhere | **HOLE H1** | **measured RED**: swapped the compiler binary behind an unchanged name → HIT. Locally live: devbox nix clang 21.1.8 and host Apple clang 21.0.0 are both `cc` (VC-21 measured them 4x apart) and share one bucket |
| 6 | `-d NAME` defines (incl. gc-mode defines `vgc,perceus,gcboehm*` — `-gc` enters as defines + build_options pref.v:759) | defines_map_unique_keys, default.v:159-170,324 | keyed | measured (`macos,perceus,vgc` in VOPTS; `-d cfgb` produced a distinct namespace) |
| 7 | **`-d NAME=VALUE` values** (`$d()`) | **nowhere**: pref.v:1592-1601 puts only the NAME in compile_defines; values live in compile_values, absent from the key | **HOLE H2** | **measured RED**: module returns `$d('lvl','zero')`; `-d lvl=one` then `-d lvl=two` → second binary prints `one` |
| 8 | `-cflags` | default.v:325 + cc salt (cc.v:732→1077) | keyed | code-cited |
| 9 | third_party_option | default.v:326 | keyed | measured (`-fPIC`) |
| 10 | lookup path (`VMODULES`, vroot) | default.v:327 | keyed | measured |
| 11 | env `CFLAGS` | cc salt (cc.v:1073,1269) | keyed at cc stage | code-cited |
| 12 | env `LDFLAGS` | deliberately excluded (link-only; final binaries are never cached) cc.v:1272-1275 | sound | code-cited |
| 13 | arch (`-arch`) | cc salt (cc.v:792-798) + build_options | keyed | measured (`-arch\|arm64` in salt) |
| 14 | **module `.v` source content, cross-config** | `.hashes` diff — but its key (rebuilding.v:72,83) is file paths + vexe salt, NO config: config A's save convinces config B nothing changed while B's namespace still holds old objects | **HOLE H3** | **measured RED**: A and B built at S1; edit to S2; A rebuilds; B then silently links S1 objects and prints deleted source |
| 15 | **served `.o` ↔ the sources it was built from** | **nothing binds them**: serve time checks existence + embeds only (rebuilding.v:296-321) | **HOLE H-POISON** | **measured RED**: a valid-but-wrong `.o` planted at the cache path links silently; binary prints the planted variant's output |
| 16 | `$embed_file` assets | `.embeds.txt` manifest (cc.v:1307-1311, rebuilding.v:245-294) — this fork's earlier fix | keyed | code-cited |
| 17 | **`$tmpl` templates** | **nowhere** for the module cache (ast.File.template_paths is consumed only by crun, rebuilding.v:657-666) | **HOLE H5** | **measured RED**: template edit → stale output |
| 18 | **`$env` comptime values** | **nowhere** (resolved at checker/comptime.v:421; never recorded) | **HOLE H6** | **measured RED**: env change → stale output |
| 19 | **`#include`/`#insert` local C headers** compiled into a layer (for vcx: include/cx.h et al.) | **nowhere** for the module cache (crun hashes them via crun_hash_stmt_dependency_path rebuilding.v:610-633; the module path does not) | **HOLE H7** | **measured RED**: header edit `return 1`→`return 2` → binary still prints 1 |
| 20 | fail-closed on failed module rebuild | guard rebuilding.v:34-74 — but it computes `stale_o` BEFORE the cc salt exists (`rebuild_modules` runs at parse end, builder.v:393; the salt first appears at validate/cc time) | **DEFECT H4: the #151 guard is vacuous** | **measured** (traced): on a failed rebuild the parent computed bucket `ac/acfc60…` and declared "no cached object under this key — harmless" while the object sat in `87/875299…`; the source hashes were then saved anyway. Net behavior stayed fail-closed (loud panic) only because `validate_usecache_type_tables` → `rebuild_cached_module` re-attempts on demand — a backstop that is load-bearing by accident |
| 21 | concurrent writers/readers of one cache entry | none: build-module cc writes the `.o` DIRECTLY to its final cache path (cc.v:1297-1327); metadata via plain write_file (vcache.v:172-184); no locks, no tmp+rename | **HOLE H8** | code-cited; matches the -j-storm environment #572 was seen in |
| 22 | duplicate-symbol resolution | linux + use_cache adds `-Xlinker -z muldefs` (cc.v:1092-1099): first-definition-wins, silently; macOS errors loudly | **HOLE H9** (masking, linux-only) | code-cited; not measurable on this host |
| 23 | module cache-key canonicalization | key = module path AS SPELLED (vcache.v:107-150): `vlib/builtin` and its absolute path are two entries | **DEFECT H10**: every cold cache builds builtin (and closure) TWICE; the class already produced a ~9000-duplicate-symbol incident (guard comment rebuilding.v:330-337) | measured (two builtin buckets after one cold build) |
| 24 | VCACHE location | basepath only, never the key | sound | code-cited |
| 25 | VFLAGS/CLI | parsed into prefs → covered exactly as far as rows above are | derivative | code-cited |
| 26 | crun timestamp cache | separate mechanism (rebuilding.v:465-529); not used by gates | noted, out of scope | code-cited |

## #572 attribution (duplicate `___v_thread_wait` class)

**Measured:** the class reproduces deterministically. A stale layer that
still exports a symbol (`@[export]` fixture) plus an on-demand fresh rebuild
of a sibling layer that now also exports it → `ld: 1 duplicate symbol` —
the #572 signature. Mixed-generation layers are exactly what H3, H-POISON,
H8 and H10 produce; on linux, H9 would turn the same state into a silently
wrong binary instead of a loud failure. The original `___v_thread_wait`
instance itself is no longer resurrectable: the #151 vexe salt namespaces
old-cgen objects away, which is consistent with #572 never re-firing after
that fix while remaining un-root-caused. The surviving mechanism is the one
reproduced.

## Soundness invariants (what the gate proves)

- **I1 completeness** — every input that can change the bytes of a cached
  module object is a component of the key it is saved AND looked up under.
- **I2 agreement** — the build-module subprocess and the consuming parent
  compute identical keys for the same module (build_options must reconstruct
  every key-relevant pref).
- **I3 provenance** — a cached object is served only with evidence it was
  built from the CURRENT inputs under THIS configuration (per-object source
  manifest bound to the object bytes, verified at serve time).
- **I4 fail-closed** — a failed rebuild never advances cache state that
  could cause a stale object to be served later.
- **I5 atomic publication** — a reader can never mistake a partially
  written or mid-replacement entry for a valid one.
- **I6 loud duplicates** — duplicate symbol definitions across linked cache
  layers are never silently resolved.

## Fix series (this session, fork-local, cx-agnostic, upstream-offerable)

1. **V1 — cc identity salt**: resolved compiler path + size + mtime joins
   original_vopts (same design as the #151 vexe salt). Closes H1.
2. **V2 — define values in the key**: sorted `name=value` pairs of
   compile_values join original_vopts. Closes H2.
3. **V3 — per-object provenance manifest** (`.srcs.txt`, written by the
   build-module subprocess only on SUCCESS, binding: object-bytes hash +
   content hashes of every parsed `.v` file, `$tmpl` template, local
   `#include`/`#insert` header, and `$env` name=value reads): verified in
   `rebuild_cached_module` before an object is served; mismatch or absence →
   rebuild once, then loud failure. Closes H3, H5, H6, H7, H-POISON; makes
   the global `.hashes` an optimization instead of a soundness mechanism.
4. **V4 — real fail-closed guard**: `rebuild_modules` computes the stale
   path under the salted key (setup_ccompiler_options is re-entrant, the
   #864 precedent) and the `.hashes` record is config-keyed. Closes H4,
   belt for H3.
5. **V5 — atomic publication**: build-module compiles to `<final>.tmp.<pid>`
   and renames after the manifest is written. Closes H8 for readers and
   writers (the manifest binding already detects torn objects; the rename
   removes the TOCTOU window).
6. **V6 — canonical module keys**: module paths normalize (real_path,
   vroot-relative) before keying, collapsing spelling twins. Closes H10 and
   its duplicate-link class; saves one full builtin build per cold cache.
7. **H9 (muldefs)** cannot be validated on this host — FILED as a linux
   follow-up rather than changed blind (removing it may break upstream's
   inherent generated-helper duplication; needs a linux measurement).

Gate: `scripts/vcache_soundness_gate.sh` (devbox, log + GATE-RC, no pipes)
runs every probe above as an EXPECTED/OBSERVED assertion — green requires
all sound, and the gate's red side is proven by running the probe set
against the pre-fix compiler (recorded) plus a permanent `--inject` mode
that forges a provenance manifest and must stay RED.
