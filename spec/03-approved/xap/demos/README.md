# `cx-xap` demos — the client ladder (D1 → D4)

Complete, self-contained, **spec-conformant** XAP examples. Each is a working
program that targets the `cx-xap` runtime (the orchestrator surface specified in
[`../xap.md`](../xap.md) §3) and is structured to run **as-is** — source + the
exact run command + the expected output.

> **Run status.** All four demos **run today** on the bundled `cx-xap` runtime
> (the package resolves as `[?lib 'cx-xap' :as xap]` — no install). D1/D2/D4 are
> one-shot `cx <file>` and reproduce their `expected-output.txt` byte-for-byte;
> D3 is a long-running server — `cx --allow-net …/serve.cx` — whose
> `expected-output.txt` is a captured live GET/POST transcript. The runtime is the
> incremental slice these demos exercise (the pure constructors, the cascade, the
> dial, and the web `serve` leg); the one deferred piece is D3's live SSE feed
> (bridge-supplied until the http streaming amendment, [`../xap.md`](../xap.md)
> §24). The `cx-stdlib` primitives they compose (`bus`, `journal`, `authz`,
> `session`, `sched`, `http`, `html`) are implemented.

## The ladder

One capability, surfaced through progressively more clients. Each rung adds **one
client** and turns on **one** new subsystem; nothing from a prior rung is
rewritten (the [`../xap.md`](../xap.md) Appendix D ladder, realized as runnable
dirs).

| Demo | Adds | Capability | `cx-xap` slice exercised | Deferred deps |
|---|---|---|---|---|
| [`d1-greeting-cli`](d1-greeting-cli/) | one-shot **CLI** | `greeting` (pure) | `component` / `surface` / `panel` / `render` — the **pure constructors** | none |
| [`d2-guestbook-cli-tui`](d2-guestbook-cli-tui/) | stateful capability | `guestbook` (stateful) | the **cascade** (`run`/`emit`/`state`) — two signs, one fold, rendered once | none |
| [`d3-guestbook-web`](d3-guestbook-web/) | + **web** & **terminal** clients | `guestbook` | `serve` (GET shell / POST cascade) + a real in-place TUI (`tui.cx`) over the same in-process fold | live SSE *push* (§24) |
| [`d4-guestbook-agent`](d4-guestbook-agent/) | + **agent** peer | `guestbook` | the resolver/agent hook + the **dial** (`authz` delegation) | — |

**The ladder is the build order.** D1 is the smallest real `cx-xap` slice (pure,
no journal/bus/socket); each later demo turns on exactly one more subsystem.
The runtime was built in this order and each demo is its acceptance test —
`cx <file>` (D1/D2/D4) / `cx --allow-net …/serve.cx` (D3) reproduces every
`expected-output.txt`.

## Conventions (shared by every demo)

- Each dir is a scaffoldable project: `cx xap init <dir> [from <demo>]` lands
  these files (the demo *is* its files; the modules just run them —
  [`../xap.md`](../xap.md) §25.2 / N-IMPL-1).
- `[?lib 'cx-xap' :as xap]` imports the gated runtime (the `:as xap` alias binds
  the `[$xap:…]` call prefix); `cx-stdlib/*` imports the primitives. The
  `cx xap …` subcommands are core to the binary (no import).
- The dial sits **at the floor** (agent silent) through D1–D3; D4 raises it.
- Single tenant `"demo"`, one fixed dev principal, **no login** (the `--role
  tooling` localhost-trust posture, [`../xap.md`](../xap.md) §22.1) — the auth
  seam is one place, flipped to SSO without touching the rest.
