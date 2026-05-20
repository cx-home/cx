# Fuzzing

Per `spec/v0_7_0_status.md` CC, cx ships a continuous fuzz harness
that exercises the parser + C ABI surfaces with random byte
sequences, mutated CX text, and hand-picked tricky inputs.

## Running locally

```sh
DYLD_LIBRARY_PATH=vcx/target scripts/fuzz_cx.py --duration 60
```

Flags:

| Flag | Default | Meaning |
|---|---|---|
| `--duration SECONDS` | 60 | Wall-clock budget. CI runs at 3600 (1 hour). |
| `--seed N` | 0 | PRNG seed for reproducibility. |

The harness drives three target surfaces per iteration:

- `cxlib.to_ast_bin` — parser path (`cx_to_ast_bin` C ABI)
- `cxlib.eval_cxl` — buffered evaluator (`cx_eval`)
- `cxlib.eval_cxl_streaming` — pull-based evaluator (`cx_eval_streaming`)

Each iteration picks a seed input from the corpus (see below), applies
a single-step byte mutation (flip / insert / delete / duplicate), and
hands the mutated bytes to a randomly-chosen target. The acceptable
outcomes are clean execution or a `RuntimeError` from the C ABI;
anything else (process abort, native exception, unexpected Python
exception) counts as a crash and gets archived.

## Crash archival

Crashes land under `vcx/fuzz/crashes/`:

```
20260518-142129-parse-4fd195ae.bin   # the input bytes that triggered
20260518-142129-parse-4fd195ae.txt   # target name + traceback + len
```

The `.bin` is the exact mutated input; `.txt` carries the traceback
and the input length. To reproduce a crash locally:

```python
import cxlib
data = open('vcx/fuzz/crashes/20260518-142129-parse-4fd195ae.bin', 'rb').read()
cxlib.to_ast_bin(data.decode('utf-8', errors='replace'))
```

CI archives crashes as build artifacts on the failing run, so any
regression that resurfaces a previously-found crash is replayable.

## Seed corpus

The harness seeds itself from:

1. `fixtures/bench/*.cx` — the bench fixtures (small / medium /
   large / 1MB / 10MB synthesized inputs). These cover realistic
   CX shapes (services, configs, tables).
2. Hand-picked tricky seeds in `scripts/fuzz_cx.py::load_seed_corpus`:
   - Empty input, single `[`, lone `[]`
   - Nested element depth, raw-text blocks `[#...#]`, block content `[|...|]`
   - Long attribute lists (1000-attr element)
   - Repeated empty-element bursts
   - CXL directives `[?for]`, `[?if]`
   - Syntactic ID `#name`, anchor `~~~`

Adding a new seed: append to `load_seed_corpus()` and commit. The
runner picks uniformly across the corpus, so additional seeds widen
the explored search space without slowing per-iteration time.

## CI integration

The CC5 CI gate runs `scripts/fuzz_cx.py --duration 3600` nightly
on the `v0.7.0-dev` branch. Findings are uploaded as build
artifacts; the build fails if any new crash appears (i.e., the
fuzzer found bytes that crash the binary).

Existing crash files in `vcx/fuzz/crashes/` are NOT replayed on
every PR — that's a CI cost the CC corpus-replay job runs weekly.
Each PR run starts with an empty crash directory (per the
fixture-corpus seed only).

## Limitations

- Python-based fuzzing has higher per-iteration overhead than
  libFuzzer-style harness. The CC1 / CC2 followup will land V-side
  `LLVMFuzzerTestOneInput` exports once V's toolchain support
  stabilizes (currently the `-cflags "-fsanitize=fuzzer,address"`
  path conflicts with V's libgc trampoline allocation under macOS
  hardened runtime — same root cause as the `-prod` segfault noted
  in `vcx/Makefile`).
- The harness does NOT exercise the binding wrappers' own surface
  (e.g., Go / Rust struct constructors). Each binding has its own
  type-system gates that catch most native-side fuzz cases at
  compile time; the C ABI is the genuinely-exposed surface across
  all bindings.

## Status

| Item | Status |
|---|---|
| CC1 Parser fuzz target | ✅ — via `cxlib.to_ast_bin` |
| CC2 Eval fuzz target | ✅ — via `cxlib.eval_cxl` and `eval_cxl_streaming` |
| CC3 C ABI fuzz target | ✅ — every C ABI symbol is reachable through the cxlib wrappers |
| CC4 Corpus management | ✅ — seed = bench fixtures + hand-picked; crashes archived under `vcx/fuzz/crashes/` |
| CC5 CI integration | 📋 — nightly job wires into V row |
| CC6 Documentation | ✅ — this document |
