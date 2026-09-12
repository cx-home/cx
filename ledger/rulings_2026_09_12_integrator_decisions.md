# Integrator decisions, 2026-09-12

Decisions the integrator took inside the delivery grammar's existing rules — no owner letter
needed, because each one reads a rule already ruled rather than adding one. Each row is a
decision of record; the id is the one cited in commits.

| Id | Decision |
|---|---|
| **INT-1** | **A step held by the PRE-MERGE runner is exempt from `check-gate-lock`.** `check-gate-lock` passes when `CX_BUILD_SLOT` is set to any runner directory other than `.build-slot` itself; `scripts/build-slot.sh` exports the directory it resolved so the step can see it. The refusal message now names the pre-merge runner as the way through instead of only the override variable. |
| **INT-2** | **(owner, 2026-09-12 13:40Z)** #1421, #1422, #1384, #1391 are pulled into v0.18; #1418, #1419, #1423, #1392 move to the next release. Why: server-role STARTTLS is an M1 gap; a spec sentence naming a non-existent audit channel cannot stand; a formatter that changes data or declines silently fights every new file. |
| **INT-3** | **(owner, 13:40Z)** `v0.18.0-pre.1` is cut when #1394 closes (epic S complete), before the #1427 merge; the final tag follows M2 (#1325/#1326). |
| **GQL-1** | **(owner, 13:30Z, option (a))** GraphQL as a Ring 1 CLIENT codec module `graphql` (`cx-stdlib/graphql`, spec in the Ring 1 directory, code `vcx/code/stdlib_graphql.v`, corpus `conformance/stdlib/graphql.cxd`, pure), first consumer the GitHub connector under #1334, next release; the server half is a recorded trigger (#1429). |
| **1405-a addendum** | **(integrator, 09:58Z)** `validate-id-token` stays pure and OUTSIDE the JWKS re-fetch list — a pure wrapper over an impure builtin is CXER0233 (oidc.md §5.1, case oidc-073). |

## INT-1 — why

`check-gate-lock` refused every `make` invocation in every worktree for as long as the
post-merge run held `/tmp/cx-gate.lock`. Four pre-merge runs on 2026-09-12 ended in an EXIT=2
whose message spoke only of "a FULL GATE", named neither the caller's branch nor a way forward
that a pre-merge run could take, and cost those runs their turn. The escape hatch that did
exist — `CX_GATE_LOCK_OVERRIDE=1` — is indiscriminate: it exempts an unserialized `make` in the
main checkout exactly as readily as a queued pre-merge step, so a branch that adopts it has
disabled the protection rather than satisfied it.

## INT-1 — the §6 reading

The grammar's §6 says:

- *One post-merge run at a time, started only when the head changes.*
- *The post-merge runner never executes a pre-merge run.*
- *A merge never touches the main checkout while a post-merge run holds it.*

What §6 protects is the **main checkout**, against a **merge**, for the duration of a run. It
does not ask a worktree to stop building, and it states the two runners are separate by design:
the post-merge run holds `~/git-repos/cx/.build-slot`, a pre-merge run holds
`~/git-repos/cx/.build-slot-impl`. A step that already holds the pre-merge runner has therefore
serialized against every other pre-merge step, and the box-load hazard `check-gate-lock` was
written for (the http/pty steps failing under concurrent load, a `-j` storm deadlocking) is the
runner's job, not the lock's. Refusing that step protects nothing the runner had not already
protected, and blocks work §6 permits.

The exemption is deliberately keyed on the runner DIRECTORY rather than on a boolean: a caller
who spells no runner at all still meets the lock, and the post-merge run's own steps — which
resolve `CX_BUILD_SLOT` to `.build-slot` — stay inside it, so the gate's `CX_GATE_OWNER`
inheritance keeps doing the work it always did.
