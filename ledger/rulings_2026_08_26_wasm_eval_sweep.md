# Rulings — 2026-08-26 · the playground wasm evaluation blind spot (#1033)

Recorded per #832 (`ledger/` is the ruling store). Honesty note on
sequence: unlike the SEQ ruling filed beside this one, WE-1..WE-4 were
settled DURING the work rather than before it, because each decision
turned on a measurement that did not exist until the harness ran. The
measurements are reproduced here so the reasoning can be checked rather
than taken on trust.

## The blind spot

`make verify-playground-examples` replays all 182 examples through
NATIVE cx. `make test-playground-mermaid` checks that the DIAGRAMS
parse. Nothing evaluated the corpus in the engine a reader gets.

The mermaid gate came closest and is worth naming precisely, because it
is where the hole hid: it calls `evalCode` to obtain its `output`
subject, then swallows the result —

```js
try { output = String(cxlib.evalCode(source, 'cx') || ''); }
catch (_) { output = ''; }
```

— which converts "this example refuses to run in the browser" into
"this example has no output subject", counted as a SKIP. A refusing
example therefore made the gate MORE green, not less.

**Measured on this head: 10 of 182 examples refuse outright in the
shipped engine**, and one more evaluates to a value native cx does not
produce. All of it shipped through two release cuts.

## WE-1 — the harness must be a real browser; the cheap one is dishonest

The issue offers a choice: the #1007 gate drives the bundle from node,
the #992/#1007 CDP run drove real Chrome, "pick the cheaper honest
harness". Node is cheaper. Measured, it is not honest for this corpus.

`libcx-async` / `libcx-pthreads` are JSPI builds (`-sASYNCIFY=2`, #930).
They call `new WebAssembly.Suspending(...)` at instantiation and abort
under node, so a node harness must fall back to `libcx-sync`. Node 22
exposes no JSPI at all: `WebAssembly.Suspending` is `undefined` under
`--experimental-wasm-jspi` AND `--experimental-wasm-stack-switching`
(measured, v22.22.2).

And the two bundles DISAGREE about this corpus:

| example | libcx-sync (node) | libcx-async (Chrome) |
| --- | --- | --- |
| 42-for-yield-par | REFUSED | evaluates |
| 44-for-yield-stream | REFUSED | evaluates |
| 50-map-par-wall | REFUSED | evaluates |
| 82-sleep-wall | REFUSED | evaluates |
| 89-worker-basic | REFUSED | REFUSED |
| 172-seq-…-backpressure | REFUSED | REFUSED |

A node/sync harness reports **18** refusals; the reader's engine has
**10**. It would have demanded a wasm-unsupported marker on 8 examples
that work perfectly on the page, and the page would then have told
readers a banner's worth of lies about working code.

**Adjudication:** the sweep drives a Chromium-family browser over the
staged `dist/playground-preview`, through the page's own `cxlib`. A
cheaper harness that manufactures false markers is not the cheaper
honest harness. The gate ASSERTS the bundle it got is a JSPI build and
fails setup (exit 2) otherwise, so it can never quietly degrade to the
engine whose verdicts are known to be wrong.

**Scope stated, not hidden:** `cxlib` loads `libcx-pthreads` when
crossOriginIsolated + SharedArrayBuffer are available (COOP/COEP, i.e.
`make guide-http`) and `libcx-async` otherwise — file://, GitHub Pages,
generic HTTP. This lane measures the ASYNC path, which is what the
published playground and a local file:// reader actually get. The
pthreads configuration is a second subject this lane does not speak for.

## WE-2 — the mechanism, and why the marker set is what it is

The refusal is not a mystery to be labelled vaguely. Captured from the
page console:

```
V panic: `go code__run_worker_thread()`: Not supported
V panic: `go code__run_future_thread()`: Not supported
```

The default single-threaded JSPI build has no thread spawning at all, so
V's `go` is a hard "Not supported" and the program exits(1). That splits
the corpus cleanly:

- `[?worker]` → `run_worker_thread` — examples 89, 161, 171, 172
- `[?async]` / `[?await*]` / `[?cancel]` → `run_future_thread` —
  examples 83, 84, 85, 86, 87, 90

`[par]` comprehensions and `[?sleep]` are NOT in the class: they need no
thread and evaluate fine. This is why the marker reasons name the
mechanism rather than saying "concurrency is unsupported" — the latter
would be false for the seven `[par]` examples that work.

**Adjudication:** `[wasm-unsupported [# reason #]]` in `examples.cxd`,
riding through `gen_examples.cx` to a `wasmUnsupported` field, on
exactly those 10. The reason states the FACT about the example; the
page's single `WASM_UNSUPPORTED_REMEDY` constant states what to do about
it, so the remedy is not copy-pasted ten times.

## WE-3 — a marker must be JUSTIFIED, in both directions

A gate whose green condition is "marked OR passes" is defeated by
marking everything.

**Adjudication:** a marker on an example that in fact evaluates AND
matches native is a FAILURE ("STALE MARKER"), not a pass. This is not
theoretical — it fired for real during this work (example 57, below) and
is what forced WE-4.

## WE-4 — the third state: an example with NO stable value

`57-map-par-bulkhead` (a 2-slot `[?bulkhead]` over 8 `[par]` items) first
appeared as a wasm/native divergence:

```
wasm:   (1, 4, 9, 16, 25, 36, 49, 64)
native: ([err … 'bulkhead saturated' max=2], 4, 9, 16, 25, 36, 49, 64)
```

Marked wasm-unsupported, it then failed the NEXT run as a stale marker.
Measured directly — 12 consecutive native runs of that source produced
**10 distinct results**, from zero saturation errs to six, one of which
equalled the wasm result exactly. Which items saturate is a race.

So `wasm ≡ native` is not a test for this example; it is a coin flip,
and either verdict would have been a flaky gate — the kind that teaches
people to ignore a red.

**Adjudication:** a third, explicitly weaker state —
`[no-stable-value [# reason #]]` → `noStableValue`. For these the sweep
asserts the property that IS true: the example must still EVALUATE in
the wasm engine, and its value is not compared. A refusal is a different
defect and does NOT get to hide behind this marker (a `noStableValue`
example that throws still fails as an unmarked refusal). These are
listed in the gate's summary so the set cannot grow unnoticed. Exactly
one example needs it.

The example's own note now says so to the reader, which is a better
outcome than the note it replaced: that note promised a specific
`CXER0152` err the program produces only sometimes natively and never in
the browser.

## WE-5 — placement

**Adjudication:** `make test-playground-wasm-eval`, beside
`test-playground-mermaid` (the #992 placement) and deliberately NOT in
`TEST_TARGETS` — that lane must not require emcc or a browser. Both
preconditions (staged `dist/playground-preview`, a Chromium-family
browser) fail LOUD with exit 2 rather than skipping, so the lane cannot
report a vacuous pass. Every wait is bounded per #988
(`WASM_EVAL_DEADLINE`, default 900s); the static server and the browser
are reaped on every exit path.

**Red-proof, measured.** A deliberately-refusing temporary example
(a bare `[?worker]`) added to `examples.cxd`:

- unmarked → the sweep exits 1 and names it: "REFUSED in the shipped
  wasm engine and NOT marked wasm-unsupported."
- marked → the sweep exits 0 with 11 justified markers.

The temp example was removed and the corpus regenerated back to 182.

## Result

182 examples: **171** evaluate and match native, **10** justifiably
marked wasm-unsupported, **1** marked no-stable-value, **0** failures.
