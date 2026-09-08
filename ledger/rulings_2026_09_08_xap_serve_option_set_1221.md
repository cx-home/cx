# RULED: 1221-b-1a, 1221-b-2a — `[$xap:serve]` takes a CLOSED option set of
# five keys, and the `xap.md` sentence that promised it every `[$xap:run]` key
# is DELETED.

Date: 2026-09-08. Issue: cx-home/cx-private#1221 (half **b**). Campaign:
v0.18.0 close-out (#1354), Lane 1. Letters drafted by the campaign worker;
**approved by the owner + a Fable pass at 2026-09-08 02:20 ET** and posted on
the issue. 1221-**a** (the `[ux:nav-item]` nested-link refusal) is a separate
record, `rulings_2026_09_08_nav_item_nested_link_1221.md`, and landed first at
`fc39d7758`.

## The defect, at the line

`spec/03-approved/xap/xap.md:236` introduces the `[$xap:run]` option table with

> `opts` (every key is also accepted by `serve`):

`xap_serve` (`vcx/platform/stdlib_xap_serve_notd_wasm32_emcc.v:796`) reads
exactly five keys out of its `opts` map:

| key | read at | what it does |
|---|---|---|
| `runtime` | `:812` | reuse a pre-seeded `[xap-runtime]` instead of wiring a fresh one |
| `shell` | `:815`, `:826` | the static shell directory |
| `tenant` | `:823` | the tenant of the freshly-wired runtime |
| `auth` | `:831` | the `[host-auth …]` block (#839 R7.2) |
| `block` | `:855` | `false` returns the `[xap-server]` handle instead of parking |

The run table lists eleven. So `journal`, `authz`, `sessions`, `components`,
`surfaces`, `handlers`, `resolver`, `sources` and `log-reduce` — **nine keys** —
were promised by normative spec text and read by nobody. A deployment that
wrote `[$xap:serve url {surfaces: (…)}]` (which is what the spec's own D3
example at `:3094` and the verb's docstring at `:786` both taught) got a
running server with **no surfaces registered** and no diagnostic: the
issue's second silent acceptance.

## Ruled — 1221-b-1a: the closed set, `serve` ≠ `run`

`serve` takes `{runtime, tenant, shell, auth, block}` and **nothing else**.
`xap.md:236`'s "every key is also accepted by `serve`" is **deleted**.

`run` builds runtimes; `serve` binds a socket to one. The one-call case stays
one expression —

```cx
[$xap:serve "https://acme.example:8443" {runtime: [$xap:run {…}]}]
```

— so nothing is lost in convenience. What is removed is a **second option
surface that must mirror `run` forever**, and whose accepted set would depend
on another key (`runtime:` present ⇒ the run keys are meaningless; absent ⇒
they would have to be honoured). That mirror is how this defect happened:
promised in spec, never kept, nine keys silently inert.

The guard is a closed set, checked **first**, before the runtime is resolved
and before any URL is parsed, so an unknown or misplaced key is refused with
the key **named** and the sentence

> run options belong to `[$xap:run]`; pass the runtime via `runtime:`

**DELETES:** the nine-key promise, the mirror obligation it created, and the
silent empty readout a `surfaces:`-on-`serve` deployment used to boot with. It
deletes no working call: no key in the closed set changes meaning, and every
key it now refuses did nothing before.

## Ruled — 1221-b-2a: no landed state shows a call the verb refuses

The docstring at `stdlib_xap_serve_notd_wasm32_emcc.v:786` and the D3 example
at `xap.md:3094` are corrected **in the same commit as the guard**. A spec
example or a docstring that the shipped verb refuses is a second defect of the
same kind as the first, so the two never exist apart even for one commit.

`xap.md` §3 also gains a **serve option table** carrying `shell`, `auth` and
`block` — honored by the implementation today and documented nowhere.

**DELETES:** the two teaching sites that produced the wrong call, and the
undocumented-but-honored status of three of the five keys.

## Construction

- **Error code: the existing `CXER4852`** (`xap_err_arg_invalid`,
  `E_XAP_COMPONENT_INVALID`, "reused for arg shape" at `stdlib_xap.v:42`).
  This is the code `serve` already raises for every other argument-shape
  refusal it owns — `serve auth: expects a [host-auth …] element`,
  `serve URL needs an explicit port` — so the option refusal joins its own
  family. **No new code is allocated:** the `cx-xap` band `4850–4889` is
  registered in `governance.md` §9.6 and shipped codes already reach `4873`
  and `4889`; a new code would be a registry amendment, which the ruling did
  not authorize and the defect does not need.
- **Guard position: first.** Before `runtime:` resolution, before
  `xap_serve_authority`, before `cap_guard('net', …)`. A key-set mistake is a
  mistake about the call, not about the host, so it must not depend on a
  capability grant or on a URL parsing.
- **Both map shapes.** `xap_map_get_node` reads an evaluated map value AND an
  unevaluated `[map …]` literal; the key enumeration the guard walks reads
  both the same way, so the guard cannot be bypassed by the shape the opts
  arrived in.

## Fixtures

`[$xap:serve]` had **zero** conformance cases before this ruling — a shipped
verb with a spec option table and no executable pin, which is the gap the
nine inert keys lived in. So the fixtures land as a new suite,
`conformance/stdlib/xap-serve.cxd`, registered `gate=enforced` in
`conformance/gates.cxd` under `[suite name=stdlib]`
(`gates_manifest_gate.sh` resolves `[module name=xap-serve]` to that path;
`check_conformance_coverage.sh` claims every `conformance/stdlib/*.cxd` for
the eval lane by glob, so no coverage-map edit is owed).

**No case may reach `start_xap_listener`.** The stdlib fixture runner grants
the FULL capability set to any case whose `out-err` does not name `CXER0271`
(`code_eval_fixtures_test.v:783`), so a `serve` case that reached the listener
would bind a real socket and — `block` defaulting to `true` — park the gate
forever. Every case here therefore uses a **portless URL**, which refuses at
`xap_serve_authority` before `cap_guard` and before the bind, independent of
the grant. That is a property of the fixtures, not of the guard, and it is
written here so the next author does not remove it.

Cases:

| id | asserts |
|---|---|
| `xap-serve-001-refuses-run-option` | `{surfaces: …}` — a genuine `run` key — is refused, named, with the "run options belong to `[$xap:run]`" sentence |
| `xap-serve-002-refuses-unknown-option` | a key that is in neither surface (`blocking:`) is refused and named |
| `xap-serve-003-accepts-its-option-set` | all five keys pass the guard: the call proceeds to the `auth:` validator (the first check after the guard), which is only reachable once every entry has been found in the closed set |
| `xap-serve-004-portless-url-refused` | the four non-`auth` keys pass the guard and the call reaches the port check — the pin that a well-formed `serve` binds nothing without an explicit port |

## What this does NOT rule

The nine keys are not being *implemented* on `serve`. That is the whole point
of 1(a): they belong to `run`, and `serve` reaches a runtime through
`runtime:`. Nothing is deferred by this record — half **a** landed at
`fc39d7758`, and with this half #1221 is complete.
