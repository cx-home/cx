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

### §2.1 The closed effect-point table (normative; EV-EFFECT-SET)

Every capability-gated primitive, mapped to the capability it charges.
This table is the **normative closed set** (the stream-22 EV-EFFECT-SET
relocation: the table previously lived only as implementation data —
a clause checkable only against an implementation file violates the
clean-room bar). The implementation's alignment map
(`effect_alignment.v`) is a conformance **mirror** of this table; the
`check-effect-alignment` gate asserts spec ↔ implementation equality in
both directions, so neither can drift. Adding an effect point is a spec
change: a row lands here first.

Scoping enforcement note (C1, coarse v1): the capability listed is the
boolean gate charged at the effect point; resource scoping is carried
per §2 and enforced per-domain as each lands. Three prims derive the
charged capability per call — `io-open` (from the requested mode:
read|write), `store-open` / `store-open-opts` (from the URL scheme +
mode: file:// ⇒ read|write, remote ⇒ net); they are listed under their
nominal capability. `io-edit-file` is a fourth shape: it is the one
primitive that requires BOTH `read` and `write` (it reads, replaces
exactly once, and writes back), and it self-guards on both at its
dispatch site rather than riding the read/write prim lists; it is listed
under `read` as its nominal capability.

| Effect-point primitive | Capability |
|---|---|
| `env-has-var` | `env` |
| `env-hostname` | `env` |
| `env-username` | `env` |
| `env-var` | `env` |
| `env-var-bool` | `env` |
| `env-var-float` | `env` |
| `env-var-int` | `env` |
| `env-var-or-default` | `env` |
| `env-var-required` | `env` |
| `env-vars` | `env` |
| `locale-default-locale` | `env` |
| `env-cwd` | `read` |
| `env-executable-path` | `read` |
| `io-read-file` | `read` |
| `io-read-file-bytes` | `read` |
| `io-read-file-lines` | `read` |
| `io-read-all` | `read` |
| `io-read-all-bytes` | `read` |
| `io-read-bytes` | `read` |
| `io-read-line` | `read` |
| `io-line-iter` | `read` |
| `io-stat` | `read` |
| `io-exists` | `read` |
| `io-is-file` | `read` |
| `io-is-directory` | `read` |
| `io-is-symlink` | `read` |
| `io-is-eof` | `read` |
| `io-list-dir` | `read` |
| `io-glob` | `read` |
| `io-glob-iter` | `read` |
| `io-walk` | `read` |
| `io-readlink` | `read` |
| `io-size` | `read` |
| `io-created-time` | `read` |
| `io-modified-time` | `read` |
| `io-tell` | `read` |
| `io-seek` | `read` |
| `io-system-temp-dir` | `read` |
| `io-temp-dir` | `read` |
| `io-watch` | `read` |
| `io-watch-next` | `read` |
| `io-open` | `read` (mode-derived: read\|write) |
| `io-open-with-opts` | `write` |
| `io-write-bytes` | `write` |
| `io-write-file` | `write` |
| `io-write-file-bytes` | `write` |
| `io-write-file-lines` | `write` |
| `io-write-line` | `write` |
| `io-write-string` | `write` |
| `io-append-file` | `write` |
| `io-append-file-bytes` | `write` |
| `io-make-dir` | `write` |
| `io-make-dirs` | `write` |
| `io-remove` | `write` |
| `io-remove-dir` | `write` |
| `io-remove-tree` | `write` |
| `io-rename` | `write` |
| `io-copy` | `write` |
| `io-copy-tree` | `write` |
| `io-symlink` | `write` |
| `io-lock` | `write` |
| `io-unlock` | `write` |
| `io-flush` | `write` |
| `io-temp-file` | `write` |
| `path-absolute` | `read` |
| `path-canonical` | `read` |
| `i18n-load-catalog` | `read` |
| `test-fixture-load` | `read` |
| `store-open` | `read` (url+mode-derived) |
| `store-open-opts` | `read` (url+mode-derived) |
| `time-now` | `clock` |
| `time-today` | `clock` |
| `time-instant-now` | `clock` |
| `time-monotonic-now` | `clock` |
| `time-utc-now` | `clock` |
| `time-system-timezone` | `clock` |
| `prof-now-ns` | `clock` |
| `prof-now-cpu-ns` | `clock` |
| `prof-trace` | `clock` |
| `prof-time-fn` | `clock` |
| `prof-time-and-trace` | `clock` |
| `mime-multipart-boundary` | `random` |
| `random-crypto-bytes` | `random` |
| `random-crypto-int` | `random` |
| `random-crypto-hex` | `random` |
| `random-crypto-base64-url` | `random` |
| `random-crypto-token-urlsafe` | `random` |
| `uuid-v4` | `random` |
| `uuid-v4-bytes` | `random` |
| `uuid-v7` | `random` |
| `uuid-v7-bytes` | `random` |
| `crypto-aead-encrypt` | `random` |
| `crypto-ed25519-keypair` | `random` |
| `crypto-x25519-keypair` | `random` |
| `crypto-password-hash` | `random` |
| `crypto-jwks-fetch` | `net` |
| `http-get` | `net` |
| `http-post` | `net` |
| `http-put` | `net` |
| `http-del` | `net` |
| `http-patch` | `net` |
| `http-head` | `net` |
| `http-options` | `net` |
| `http-request` | `net` |
| `http-send` | `net` |
| `http-sse-connect` | `net` |
| `http-sse-events` | `net` |
| `http-serve` | `net` |
| `http-listen` | `net` |
| `http-accept-iter` | `net` |
| `http-exchange-request` | `net` |
| `http-respond` | `net` |
| `http-stop` | `net` |
| `net-resolve` | `net` |
| `net-dial` | `net` |
| `net-dial-tcp` | `net` |
| `net-dial-tls` | `net` |
| `net-dial-udp` | `net` |
| `net-dial-dtls` | `net` |
| `net-dial-unix` | `net` |
| `net-listen` | `net` |
| `net-listen-tcp` | `net` |
| `net-listen-tls` | `net` |
| `net-listen-udp` | `net` |
| `net-listen-dtls` | `net` |
| `net-listen-unix` | `net` |
| `net-accept` | `net` |
| `net-accept-iter` | `net` |
| `net-read-bytes` | `net` |
| `net-read-exact` | `net` |
| `net-read-line` | `net` |
| `net-read-all` | `net` |
| `net-read-all-bytes` | `net` |
| `net-write-bytes` | `net` |
| `net-write-string` | `net` |
| `net-write-line` | `net` |
| `net-flush` | `net` |
| `net-is-eof` | `net` |
| `net-line-iter` | `net` |
| `net-chunk-iter` | `net` |
| `net-send-to` | `net` |
| `net-recv-from` | `net` |
| `net-send` | `net` |
| `net-recv` | `net` |
| `net-tls-wrap` | `net` |
| `net-tls-accept` | `net` |
| `net-peer-cert` | `net` |
| `net-tls-info` | `net` |
| `net-shutdown` | `net` |
| `net-set-deadline` | `net` |
| `net-set-opt` | `net` |
| `io-edit-file` | `read` |
| `process-close` | `subprocess` |
| `process-kill` | `subprocess` |
| `process-kill-group` | `subprocess` |
| `process-pid` | `subprocess` |
| `process-pipeline` | `subprocess` |
| `process-poll` | `subprocess` |
| `process-pty` | `subprocess` |
| `process-run` | `subprocess` |
| `process-send-signal` | `subprocess` |
| `process-set-window-size` | `subprocess` |
| `process-spawn` | `subprocess` |
| `process-spawn-pty` | `subprocess` |
| `process-stderr` | `subprocess` |
| `process-stdin` | `subprocess` |
| `process-stdout` | `subprocess` |
| `process-terminate` | `subprocess` |
| `process-wait` | `subprocess` |
| `process-wait-timeout` | `subprocess` |
| `process-window-size` | `subprocess` |
| `live-changes-since` | `eval` |
| `live-observe` | `eval` |
| `live-materialize` | `eval` |
| `live-advance` | `eval` |
| `live-adapt-watch` | `write` |

The impure-WITHOUT-capability exception table (state-bearing PRNG, mock
clock, ambient process basics, capability introspection, impl-pending
bare names) is the other half of the §6.5.1 alignment invariant and
lives in `code.md` §6.5.1 — an entry there is deliberately absent here.

**`[effects]` declarations check against this table's capability column
(commands and effects, stream 6 — L110).** A `[?def]` carrying an
`[effects …]` clause is a **command**; its declared capability names
MUST come from the closed §2 nine-name list (an unknown name is the
fail-closed `E_CAP_UNKNOWN`, `cx-err:CXER0274` — the same refusal the
grant surface gives a typo'd grant, and for the same reason). At
runtime the declaration acts as a `[?with-caps]`-like NARROWING: for
the command body's dynamic extent the active set is the intersection of
the caller's grant with the declared set, so an effect point outside
the declaration raises `E_CAP_DENIED` (`cx-err:CXER0271`) at the effect
point — **checked and enforced, never advisory**. `pure` plus a
non-empty `[effects]` is the static contradiction
`E_COMMAND_CONTRACT` (`cx-err:CXER0239`) by the §6.5.1 effect-totality
theorem. The full clause grammar and static rules live in `code.md`
§12.2.7.

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
  The GRANT surface is equally fail-closed (#713): an unknown capability
  name in a host grant spec/list — or the retired `cap:resource` scope
  spelling (`cap=resource` is THE scope spelling; `cap:` is the reserved
  capability-value address prefix, L114) — is the typed refusal
  `E_CAP_UNKNOWN` (`cx-err:CXER0274`) naming the bad token and the accepted
  set, and NO set is installed. The same code with the same posture covers
  an unknown capability name declared in a `[?def]`'s `[effects …]` clause
  (§2.1, `code.md` §12.2.7) — one refusal wherever a capability name is
  spelled. A typo'd grant must never become a silent
  no-grant: it flips denial fixtures false-green and makes the grant
  surface lie.
- **(C3) CLI default → default-deny** even for the CLI (least authority,
  Deno-proven), made ergonomic by the three §4 requirements (actionable errors +
  `cx.pkg` manifest grant + `--allow-all` opt-out). Embedding default is always
  deny.
- **(C4) Capability set as a CX value → yes (implemented, stream-5 L104):** the
  active set is exposed as an introspectable CX value via the zero-arg builtin
  **`[$caps]`** (classified `impure` in `code.md` §6.5.x — a `pure` body reading
  the grant set would break the §6.5.1 cap-set-invariance; capability-FREE by
  the §3 narrow-only invariant: a program can only observe its own authority,
  never exceed it). **Canonical form** — a map over the closed §2 nine-name
  list, self-canonicalizing by key sort: granted-unscoped capability → `true`;
  granted-scoped capability → a sorted sequence of canonicalized scope strings
  (host globs lower-cased; path roots trailing-slash-normalized); ungranted
  capability → **absent**. **The `--allow-all` opt-out NORMALIZES to the
  explicit full grant set plus one policy field** (`private-range-allowed:
  true` — the §4.5 private-range-deny bypass, the single behavior the opt-out
  adds): one canonical form, not two (#713 item 3). A `[?with-caps]`-narrowed
  set is visible to `[$caps]` (the ACTIVE view) and never carries the policy
  field. This value is the `caps` component of the stream-5 `[computation]`
  record (`computation_identity.md` — where the ENTRY set is the hash basis).
  Example: `{net: ('api.example.com:443'), read: true}`.
