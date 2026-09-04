# Rulings 2026-09-04 — #1265 W1 packet D: the `cx flow` command line (PD)

**Status: PD-1 RULED (a) 2026-09-04 under the owner's standing
letter-acceptance rule and the 2026-09-04 directive. Recorded before the
`cli.md` text it authorizes (packet D applies it with `RULED: 1265-PD-1`).**
Ruling id `1265-PD-1`.

**Inputs read.** `flow.md` §4.1 ("in a program [an act] resolves through the
module tree to a command def"), §4.15 (the local profile: `cx flow run FILE
[--journal URL | --ephemeral] [args…]` — a thin wrapper over `validate` →
`start` → `advance`-until-parked → `status`; exit codes 0 terminal `:done`,
1 parked or a failure state with the record printed, 2 usage; `validate`
and `simulate` need no journal), §12 (`misc/cli.md` gains the subcommand);
`misc/cli.md` §2.6 (the project/service registry) and §3.7 (the run
surface); packet B's `start`/`advance` (the resolver is `opts.env` — rows
`[act name= resolved= compensates=? [fn $cmd]]`); `stdlib/flow.cx`'s header
("the executing environment builds the resolver — from `[$cx:ast]` over its
module sources, from `[$xap:compose]` at the XAP face, or by hand in a
fixture").

## The finding the ruling rests on

A flow document is DATA: it names its acts by qualified name and carries no
`[?lib]`. The command line must therefore be told where the acts live, and
§4.1 already says where: the module tree of a program. What the CLI needs is
the program whose module tree the acts resolve through.

## PD-1 — the `cx flow` subcommands and how acts are found — RULED (a)

- **(a) RULED —**
  ```
  cx flow run      FLOW.cx --env ENV.cx [--journal URL | --ephemeral] [--<arg>=<value>…] [--actor=… --authority=…] [--stream=…]
  cx flow validate FLOW.cx --env ENV.cx
  cx flow simulate FLOW.cx RESULTS.cx [--env ENV.cx] [--<arg>=<value>…]
  cx flow status   --journal URL RUN-ID [--stream=…]
  ```
  `ENV.cx` is an ordinary CX program: its `[?lib … :as alias]` imports and
  its own `[effects]`-bearing `[?def]`s ARE the module tree; the CLI
  evaluates it (under the program's own capability grants, `--allow-*` as
  for any `cx FILE`) and builds the resolver element from every command def
  reachable in it — `alias/def` for an imported member, `def` for its own —
  with `resolved=` the def's Tier-1 text address, `compensates=` its pairing
  and `[fn $cmd]` the callable; nothing else is special. The `--<arg>=<value>`
  flags build the `[args …]` record in child form (CA-3), typed by the flow's
  declaration (a value that fails the declaration refuses CXER4965 as the
  spec says). `--actor`/`--authority` default to `principal:<the OS user>` /
  `cli` for the local profile (§4.15: a checkout's own flows run under the
  runner); the journal default is `file://.cx/flow/` in the working directory
  (gitignored — §12), `--ephemeral` = `mem://`; a run parked on a
  non-`:runner` step is W3 and cannot occur in W1. `run` re-`start`s an
  existing run id only through the dedup/resume path the module already has
  (`[deduped …]` for a terminal run; an interrupted run resumes — §4.15's
  fixture). Output: the record in canonical CX on stdout; refusals on
  stderr as the `[err …]` value; exit codes per §4.15 (`validate`/`simulate`:
  0 valid / 1 refused / 2 usage; `status`: 0 found / 1 unknown). **DELETES:**
  nothing (a new subcommand family under §2.6). **KEEPS:** `validate` /
  `simulate` journal-free; every module semantic — the CLI adds none.
  **Strongest counter:** a flow file could carry its own `[?lib]` lines and
  be a program. **Answer:** WF-1 ruled the flow an ordinary DATA document
  with a content address; a `[?lib]` inside it would make the address depend
  on the environment — the separation is the point.
- **(b) `cx flow run FLOW.cx MODULE.cx…` positional module files, qualified
  by basename.** Rejected: invents a second import convention beside
  `[?lib … :as alias]`.
- **(c) the flow file carries `[?lib]` lines.** Rejected (above).

## Edit map (packet D, `RULED: 1265-PD-1`)

| Where | Edit |
|---|---|
| `misc/cli.md` §2.6 | the `cx flow` row(s); §3 a subsection with the flags, exit codes and the `--env` rule |
| `vcx/cmd/` | the `flow` subcommand (registry entry, help text), evaluating ENV.cx and building the resolver, driving the module's verbs |
| `.gitignore` | `.cx/flow/` |
| `flow.md` §4.15 | the `--env` clause and the `validate`/`simulate`/`status` subcommands, one sentence each |
