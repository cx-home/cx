# Deployment process model — one process per port, fail-fast, no bespoke supervision

**Status:** APPROVED — graduated 2026-08-20 (ruling SPR-5,
ledger/rulings_2026_08_20_spec_tree_reshape.md) from the xap_architecture
working notes §10, where it was design-accepted 2026-07-08 after a field
failure with three stacked fragilities: a deployment whose bind failed kept
running its ingest workers (a half-alive instance silently fighting the bound
one for an upstream gateway's single TCP client slot); a dev launcher that
could not tell its own server from someone else's (any process answering the
port passed its health check); and a respawning keepalive script that
pkill-by-name'd its way into collisions with every other launcher. The model
is deployment-side; it requires no runtime change.

## §1. The port is the only mutex

A deployment process's identity IS its bound port. The kernel already
arbitrates binds; nothing else (scripts, pidfiles, name matching) may
arbitrate instance ownership.

- **Bind failure is fatal to the whole process.** A deployment entry MUST make
  a failed host/serve bind terminate the program — per the core error model
  (errors are values; propagation is explicit), that is the postfix `!` on the
  host call: `[$xap:host …]!`. A deployment that cannot serve MUST NOT run its
  adapters/workers: the half-alive state (ingesting, not serving) is the worst
  operational state because nothing observes it.
- Corollary: at most one instance per port, enforced by the OS, with a loud
  nonzero exit for every loser of the race — no arbitration policy to encode,
  test, or get wrong.

## §2. Collisions fail fast; replacement is explicit

A launcher that finds the port taken MUST fail with a clear message naming the
stop/restart verb — never kill the incumbent implicitly (newest-wins takeover
is how surprise outages happen), and never "reuse" silently (the operator
should know which launch owns the process). `restart` = explicit stop of the
incumbent + start; `stop` kills only PIDs the launcher itself started
(kill-by-port / kill-by-name sweeps are forbidden — they are blind to
ownership).

One escape hatch, learned in the field: an instance of the deployment's OWN
entry started outside the launcher (no pidfile) must still be stoppable, or
the operator dead-ends (`stop` no-ops, launch refuses the owned port). `stop`
MAY terminate an untracked process only under VERIFIED IDENTITY — it both owns
the deployment's port AND its command line is this deployment's entry —
reported loudly as such. A foreign port owner is reported, never touched.
This is targeted removal of a verified own-instance, not a sweep.

## §3. Supervision: none by default; the OS supervisor when unattended

- **Default (dev and crewed operation): no supervisor.** The runtime's serve
  plane is expected to be sound (the SIGPIPE silent-death and GC collect-storm
  wedge classes were fixed at the root); a crash is a runtime bug that must be
  seen and root-caused, not respawned over. Bespoke keepalive loops are
  retired: their health-check kill cycles masked exactly the defects that
  needed fixing, and their respawn loops are a standing collision source.
- **Unattended operation (e.g. a long-running field deployment): the OS
  supervisor** — a launchd job on macOS (label-keyed single instance, start at
  boot, restart on crash), the systemd unit on Linux — supervision without a
  second launcher fighting the first.
- Processes terminate cleanly on SIGTERM (verified: the serve plane exits 143
  promptly); tooling MUST use plain TERM, reserving KILL for a TERM that went
  unanswered.

## §4. Single-client upstreams

Adapters that dial single-client upstreams get their exclusivity FROM §1 —
one process per port means one dialer per upstream. No adapter-level locking
is added; if an upstream must be shared across deployments, that is a
gateway/fan-out component, not a client-side protocol.
