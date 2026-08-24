# CX resource limits — the Ring-0 structural guards

**Status:** APPROVED (recorded 2026-08-20, #876 — the ruled spec home for
the limits surface; the guide's "Limits and quotas" section derives from
this document, and the engine constants cite it). This document records
the guards **as shipped**; adding a guard is an owner ruling on #876's
open letters, never a doc claim.

## 1. Scope and posture

The parse surface (Ring 0 — the ring whose whole pitch is parsing
untrusted input) carries a deliberately small set of **structural
guards**. Three properties, each load-bearing:

1. **Built in, not tuned.** No guard is configured by environment
   variable. The include-depth bound is configurable by the embedding
   (the resolver options); everything else is a constant of the engine.
   A limits surface that varies with ambient process state is itself an
   attack surface.
2. **Each refusal names its limit.** A guard that fires says which bound,
   where (line:column or path), and — for the include family — the chain
   that crossed it.
3. **Absent classes are absent structurally, not capped.** Where the
   design removes an attack class outright, no guard exists because
   nothing needs guarding (§3).

## 2. The shipped guards

| Guard | Bound | Refusal | Engine home |
|---|---|---|---|
| Element nesting (text parser) | 64 | parse error naming line, column, and the limit | `vcx/cx/parser.v` `max_recursion_depth` |
| Include depth | 8 (default; embedding-configurable via the resolver options) | `cx-err:E905`, naming the limit and the crossing path | `vcx/cx/include.v` `max_include_depth_default` |
| Include cycle | refused at the repeat visit | `cx-err:E904`, naming the whole chain (`A → B → A`) | `vcx/cx/include.v` |
| Include escape — absolute path / root traversal / URL scheme | refused outright | `cx-err:E901` / `E902` / `E903` | `vcx/cx/include.v` |
| CXCol decode recursion | 64 (`max_depth` u32 in the header; the reader enforces it) | decode refusal naming the limit | `vcx/cx/data_bin.v` `cxcol_default_depth` |
| Input size (opt-in) | `ParseLimits.max_input_bytes` — embedding-supplied via `parse_limited`; 0 = unbounded default | typed refusal naming both numbers and this document | `vcx/cx/parser.v` `ParseLimits` |

Include resolution is **opt-in and root-bounded**: the embedding supplies
an absolute include root; every resolved include must lie under it, and
resolution is relative to the including file. There is no search path
and no environment variable — one root, one resolution rule (the full
error family is `cx-err:E901–E911`).

## 3. Structurally absent classes

- **Entity-expansion bombs** (XML's "billion laughs"): entity references
  parse to nodes — there is **no textual expansion pass** — so recursive
  expansion has nothing to attack.
- **Include fan-out**: includes cannot reach outside the root-bounded
  tree (no URLs, no absolute paths, no traversal), so a document cannot
  make the resolver fetch or walk anything the embedding did not hand it.

## 4. Deliberately not guarded (current ruling)

The engine carries **no** attribute-count cap, body-size cap, parse-time
budget, or canonical-form size cap — RULED (LIM-2, owner 2026-08-20):
every such cap would bound a quantity the caller already holds in hand
before calling parse, while every quantity the caller CANNOT see (stack,
expansion, fan-out, decode recursion) is structurally bounded in §2/§3.
The parse **algorithm is linear in input bytes** (calibrated 2026-08-20:
1.9–2.3× per byte-doubling under `-gc none` on every adversarial shape),
and the claim is a TESTED property, not an intention: the amplification
gate (`vcx/tests/parse_amplification_test.v`) hard-asserts the
node-amplification bound on every full test run and prints the CPU-time
ratio as an advisory diagnostic. (Time is advisory because the shipped
collector's mark cost grows with live heap at multi-MB scale — a
collector property, not a parser one; the perf campaign owns it.)
The untrusted-input posture is **boundary-side**: bound the input size
where it enters (or hand the bound to the engine via
`ParseLimits.max_input_bytes` for refusal-over-OOM), run with the empty
grant set (the parser needs no capability grants at all), and pair with
OS-level process limits.

## 5. Out of scope

Evaluation-side bounds (recursion, time, worker pools) are the code
language's story (`spec/03-approved/core/code.md` — stack exhaustion is
`CXER0272`; tail calls ride the trampoline). Ring 0 cannot execute
anything, so no evaluation bound belongs in this document.
