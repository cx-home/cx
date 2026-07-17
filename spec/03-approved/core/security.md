# CX Security — capability-based, deny-by-default

**Status:** Current. Capability-based security model for CX. The
`[?with-caps]` directive (registered in `code.md` §4.1) and the `E_CAP_DENIED`
error code (`CXER0271`) are admitted here and in `code.md`. The host bindings
are specified in their owning files: the `--allow-*` flags in `cli.md` §3.7, the
capability-set parameter + capability bit (38) in `abi.md`, and the §5 hardening
row in `process/threat-model.md`.

`E_CAP_DENIED` is `cx-err:CXER0271`, the next free slot in the designated
`CXER0270–0279` host-capability band (alongside `CXER0270`, the wasm wall-sleep
code).

## §1 Principle
A CX evaluation runs under an explicit **capability set**. **Deny-by-default:
no ambient authority.** Any operation with external effect requires the matching
capability; absent → `E_CAP_DENIED` (`cx-err:CXER0271`; no silent fallback). The
host (embedding app / CLI) grants the set at invocation; **a program can only
*narrow* its set, never widen it** (same invariant as the `cx:eval` library-set
rule M3). This turns the threat-model's *"capability separation is the caller's
responsibility"* into a runtime-enforced guarantee.

**Effect posture (normative; cross-ref `code.md` §9.0 / §6.5.1).** A computation's
*effect* is the set of capabilities it can exercise — **denied by default and
checked at every effect point** (`CXER0271`, §4). "This performs no external
effect" is therefore a property the runtime *enforces*, not a convention: by the
**effect-totality lemma** (`code.md` §6.5.1), a `pure` function (§6.5.x purity
checker) provably reaches no capability-gated effect point and so raises no
`CXER0271` under **any** capability set, including the empty set. Effect
conformance is enforced; type / `[returns T]` conformance is advisory
(`code.md` §12.2.5). This is the one axis the language guarantees rather than
hopes for.

## §2 Capability categories (the gated surfaces)
| Capability | Gates | Scoping |
|---|---|---|
| `read` | filesystem reads, `[?cx include]` | allowed path roots |
| `write` | filesystem writes | allowed path roots |
| `net` | HTTP client, service bind, network channels, `[?lib]` over https | allowed host:port / host globs |
| `env` | environment-variable reads | allowed names |
| `clock` | wall-clock reads / non-mock `[?sleep]` | — (else mock-only) |
| `random` | CSPRNG / OS entropy (`random/crypto-bytes`) | — |
| `subprocess` | process spawn (`std-lib/process`) | allowed executables |
| `eval` | `cx:eval` (string) + `cx:eval-tree` / `[?eval]` (tree) dynamic evaluation | — |
| `secret-reveal` | declassify a secret value (`cxdm.md` §12) | — |

Pure computation, parsing, canonical emit, in-memory transforms need **no**
capability (consistent with the `pure` classifier — pure code is capability-free
by construction).

## §3 Granting + narrowing
- **CLI (deny-by-default):** `cx FILE --allow-read=./data --allow-net=api.example.com:443 --allow-env=HOME`. No `--allow-*` ⇒ empty set (pure-only). `--allow-all` is an explicit opt-out for trusted local use.
- **Embedding / ABI:** the host passes a capability set to `cx_code_eval`/`cx:eval`; defaults to empty.
- **Manifest declaration:** `cx.pkg` MAY declare the capabilities a module *requests* (`[capabilities [net api.example.com:443] [env …]]`); the host reviews/grants — a module never self-grants.
- **In-program narrowing:** `[?with-caps [deny net] [deny subprocess] BODY]` drops capabilities for `BODY`'s dynamic extent (narrow-only; a `deny` cannot be undone inside `BODY`). Run untrusted sub-computations with a reduced set. Grammar `[167]`: ≥1 `[deny CAP (resource)?]` clause + one body expr; a malformed shape is `CXER0100`, and a denied effect at the effect point raises `CXER0271` (§4).

## §4 Enforcement
A capability-gated directive/builtin checks the active set at the effect point;
denial raises `E_CAP_DENIED` carrying the missing capability + the requested
resource (e.g. `[err code=… capability=net resource='api.example.com:443']`).
Denial is **not** catchable into success by the offending op (it is a normal
err value; `[?match]` / `[?else]` / `[?fallback]` may recover it). Grants/denials
are audit-events (see §5).

**Default-deny is normative everywhere (CLI + embedding).** `cx FILE` with
no grant runs pure-only. To keep deny-by-default *ergonomic* (declare-once, not
flag-every-run), three things are **required**:
1. **Actionable errors** — `E_CAP_DENIED` MUST name the exact grant to add (the
   `--allow-…=resource` flag or the `cx.pkg` capability line), not just "denied".
2. **Manifest grant (the ergonomics linchpin)** — a project's `cx.pkg`
   capability declaration (§3) is reviewed/granted once; trusted projects then
   run with **no per-invocation flags**. The manifest is also the supply-chain
   review surface (you see what a dependency requests).
3. **`--allow-all`** — an explicit, visible opt-out for fully-trusted local use.

## §5 Integration
- **`cx:eval` (M1–M5):** a fragment runs under a **subset** of the caller's set
  (M3 generalized to all capabilities — narrow-only). Adversary-controlled
  `source` with an empty set is pure-only.
- **`cx:eval-tree` / `[?eval]` (tree-eval, `code.md` §6.4.4):** reuses the
  `cx:eval` sandbox wholesale — same `eval` capability gate (denial at an inner
  effect point → `CXER0271`), same context-isolation, same module non-widening
  (`CXER4113`), and the **shared** recursion-depth counter (`CXER4114`).
  Tree-eval removes the *syntactic*-injection class (no parse step), but the
  *authority* of the evaluated tree is still bounded only by the capability set
  — wrap untrusted trees in `[?with-caps [deny …] …]`.
- **`[?cx include]`:** the existing include-root *is* the `read` scope.
- **`[?lib]` https:** module fetch needs `net`; offline/pinned resolution from
  `cx.lock` needs none.
- **Debug (`../misc/debug.md`):** attaching a debugger and `eval`-in-frame are
  themselves capability/grant-gated; capability events appear in the audit/trace.
- **Error pipeline (`code.md` §9.6):** a `report` sink that does network I/O
  (`[sink [http …]]`) needs `net`; a denied sink is a hook fault (out-of-band).
- **Secrets (`cxdm.md` §12):** `secret-reveal` is the capability that gates
  declassification.

## §6 Design decisions
- **(C1) Scoping granularity → coarse (v1):** host:port globs + path roots.
  Finer per-URL / per-file scoping is a future extension.
- **(C2) Error code → `CXER0271`** (next free in the `CXER0270–0279`
  host-capability band, alongside the wasm wall-sleep code `CXER0270`).
- **(C3) CLI default → default-deny** even for the CLI (least authority,
  Deno-proven), made ergonomic by the three §4 requirements (actionable errors +
  `cx.pkg` manifest grant + `--allow-all` opt-out). Embedding default is always
  deny.
- **(C4) Capability set as a CX value → yes:** the active set is exposed as an
  introspectable CX document (dogfood; auditable).
