# RULED: 1058-T1.6-b, 1058-T1.7-a, 1058-T1.7-c

Date: 2026-09-08. Issue: #1058 (T1.6, T1.7). Ruled by the **owner + Fable** on
the issue, 2026-09-08 18:10 ET (comment `2026-09-08T21:50:36Z`), as 1(b), 2(a),
3(a).

Recorded here late: the three implementing commits (`2c2093e49`, `8329dd45d`,
`de7c1b44d`) carried their `RULED:` tokens but no ledger record existed, and
`spec-freeze-gate` refused them —

```
SPEC-FREEZE VIOLATION: commit 2c2093e4991a58ffb3aa6d7addebac4b786ab8c5 carries
a RULED: token that names NO recorded ruling in ledger/ (register R4.1 —
rulings are recorded BEFORE the work they authorize, R4.2).
```

The ruling itself predates the work by ~1h20m; only this record was missing.
Recording it does not create authority — the ruling is the owner's and Fable's,
quoted below.

## T1.6 — 1(b): `no callable` gets a real code, and `user-undefined` is removed

`no callable "f"` was the ONE member of the refusal surface carrying no
`cx-err:` code — it answered the bare string `user-undefined`. That makes "did
this fail with a CX diagnostic?" unwritable as a single predicate over `code`:
a consumer testing for the `cx-err:` prefix got the right answer everywhere
except the most common refusal there is.

**Ruled:** `no callable` gets a real `cx-err:CXERnnnn` code (`E_NO_CALLABLE`);
`user-undefined` is **REMOVED** from the surface — no alias. A dual-accept is
refused: it would keep the predicate a lie for as long as both spellings
answered.

**Code allocation, as ruled:** the §9.4 application band `0100–0105` is full;
take the first free code from §9.4's reserved tail `CXER0136–0139` (confirm
free by grep across `spec/`, `vcx/`, `conformance/`) and amend §9.4's table row
in the same commit. Implemented as **`CXER0136`**; `governance.md` §9.6 already
registers `CXER0100–0299` to the CX language core, so the registry gate is
satisfied without a new row.

**Re-cast, as ruled** — each an expectation that moves under this ruling:

- `conformance/.../code.cxd:18633` (`default=enforced`),
- `db_access.md:61`'s `[verified]` line,
- the profile gate's probe at `profile_gate.v:753` — this one is what grades
  absent-module refusals, so its move is **fixture-first**: red on the old
  string, green on the new.

Refused alternative, with what it deletes: **1(a)** alias `user-undefined` to
the new code — refused, it deletes the single-predicate property that is the
whole reason for the change.

## T1.7 — 2(a): a built-in response takes the service's declared Content-Type

**Ruled:** the built-in 404 — **and every built-in response `mk_wire` emits** —
takes its `Content-Type` from the service's existing
`[default-headers Content-Type=…]`; `text/plain` only when none is declared.
**Zero new surface**: the declaration this reads has always been there.

**3(a):** the duplicate `Content-Type` header is fixed in the **same commit**
(the same three lines). Before the fix `mk_wire` appended
`text/plain; charset=utf-8` unconditionally *after* copying the service's
default headers, so a service that declared one carried the header twice and
`serialize_wire` wrote both to the wire.

**Fixtures, as ruled:** a JSON service's unrouted path answers a JSON 404 with
exactly one `Content-Type`; a service with no default header keeps
`text/plain`. Commits carry `RULED: 1058-T1.6-b, 1058-T1.7-a, 1058-T1.7-c`;
`docs-check` runs in the lane because the error text moves. **HIGH tier** — a
fixture expectation moves.

### Scope note (measured 2026-09-09, worker A)

The ruling's scope is the responses **`mk_wire`** emits — the listener's
unrouted 404/500/503 at
`vcx/platform/services_listener_notd_wasm32_emcc.v:1262,1267` and the
stop/vanished 503s. It is **not** the built-in refusals the static-file
builtin produces: `serve_file_outcome`'s 403/404/500 flow through
`mk_serve_response` (`vcx/platform/serve_file.v:250`), which stamps its own
`Content-Type` header — defaulting to `text/plain; charset=utf-8` when the
outcome carries none — and `cx_response_to_wire` lets a response's own header
override the service default. So a `[$serve-file]` service that declares
`application/json` still answers `text/plain` on a missing file.

The two fixtures first authored for this ruling both routed through
`[resource [GET "/*"] [$serve-file]]`, so they exercised that OTHER path: the
JSON one failed for a reason outside the ruling, and the `text/plain` one
passed only because `mk_serve_response` stamps `text/plain` anyway. Both are
re-cast onto an **unrouted** path, which is the shape the ruling names and the
shape the ruled fixture sentence describes.

Whether the same rule should extend to the static-file builtin's refusals is a
**separate question** — it is not a three-line change there, because the
fallback would have to move into `cx_response_to_wire`, which serves every
handler response, not just built-ins. Drafted as a letter on #1058; not
self-ruled and not implemented here.
