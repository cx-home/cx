# RS-1…RS-12 — the multi-repo split of cx-private (owner, 2026-09-21; shape approved in session)

**Status: DRAFT for the owner's read.** This page lands on the owner's word and not before
(#1591 item 5). Until it lands, nothing below is binding, no commit subject cites an `RS-` id,
and `registry/repos.cxd` states a plan the gate keeps total rather than a decision.

**Where the decisions were taken.** In the owner's session with the integrator on 2026-09-19
through 2026-09-21, recorded on
[#1589](https://github.com/cx-home/cx-private/issues/1589) (the shape, rewritten to the
approved state on 2026-09-21) and
[#1591](https://github.com/cx-home/cx-private/issues/1591) (the board; its last comment is
the resume point on every machine). The owner's words that this page rests on, verbatim:
"recommendations accepted" (the stdlib-membership round), "1a" (the break policy), "that
looks right. shape approved" (the final table), "a" on every item of the dev1 retirement
list, and, on sequencing, "why doesn't the split begin now, before v0.18 cut?" followed by
the go-ahead to start. Nothing on this page is the integrator's inference presented as the
owner's; where the integrator recommended and the owner accepted, the row says so.

## The decisions

| Id | Decision |
|---|---|
| **RS-1** | **Two rings, then groups.** Ring 0 is the data format; Ring 1 is the language. They are the only rings: frozen, changed by decision, each an import contract that buys a product property (Ring 0 cannot execute; Ring 1 cannot reach a socket, a store or a protocol). "Ring 2" and "Ring 3" leave the vocabulary. Everything else is a GROUP — platform, binding, ecosystem, dist — whose import graph is declared per module and must be acyclic; a module may import the rings and whatever its manifest declares. |
| **RS-2** | **Split by product, not by dependency graph.** A repository exists where a person could own it, release it and explain it in one line. Per-library repositories (session, journal, the store wire, xsp as a repo) are REJECTED; the store owns its engine, its streams (journal, live, audit) and its server in one repository, as Postgres does. Fifteen repositories under `cx-platform-*` were considered and refused for this reason. |
| **RS-3** | **The shape:** `cx` (front door and distribution), `cx-core-data` (Ring 0), `cx-core-code` (Ring 1, the stdlib inside it), `cx-platform-{net, mail, identity, store, db, fabric, xap}` (V, compiled into the full `cx`, release with it), `cx-platform-{flow, connector, sso, ux, agent}` (pure CX, registry packages, their own cadence), `cx-binding-{python, go, rust, v}` (active) and `cx-binding-{typescript, java, kotlin, csharp, swift, ruby}` (archived repositories at the ABI they were frozen with), `cx-registry`, `cx-decisions`, `cx-tooling`. Twenty-nine repositories, twenty-three live. The table with group, ring, stability, composition, artifact, pins and analog is #1589's; `registry/repos.cxd` is the allocation of every tracked path to one of them. |
| **RS-4** | **Naming:** `cx-<group>-<product>`; the bare `cx` is where a visitor starts. `cx-xap` and `cx-fabric` give up their own namespaces and import as `cx-platform/xap` and `cx-platform/fabric` (one run of the 1427-i migration tool). |
| **RS-5** | **Stdlib membership moves, by the membership test (cx_partition.md §10) and by consumer.** INTO Ring 1: `did`, `vc`, `authz`, `bus`, the xsp frame and session-layer codec, `iowatch` (it is `cx-stdlib/io`'s `[io:watch]`), `term` (from `x/`). OUT of the frozen stdlib to the product that consumes them: `ft` → store, `sasl` → mail, `diagram` → tooling. KEPT as shared codecs in the language: saml, scim, oidc, soap, graphql, ws, email, http-client, similar (the `~` operator's backing). `did:web` resolution and vc's revocation-journal touch stay above the rings, in identity and store respectively. |
| **RS-6** | **The store server authenticates through the Ring-1 trust primitives** (did/vc verify, the authz decision) and its own `[grants]`, not through session tables. This is the design item that removes the store↔session cycle; it precedes the store's extraction. The four `xap_*` node accessors (`xap_elem`, `xap_attr`, `xap_elem_attr`, `xap_map_get_node`; 184 call sites below xap) move to `code` first — they are the entire "xap dependency" of every lower module. Connector's native half (secret handle, token store, spend ledger, cap guard) moves down into identity/store builtins so the kit is pure CX. |
| **RS-7** | **Consumers pull, producers never push.** Each repository pins the releases it builds on (`deps.cxd`: repository, SHA or tag, module; the V-fork SHA for V repositories) and bumps them in its own PR. `cx` is a migration lane, never a gate: when any repository releases, it tries the newest mutually green set; green advances the pins, red leaves them and lands a finding on the repository that moved. No merge anywhere waits on `cx`. A release cut ships whatever is pinned. Pin transport is a CX lock document plus a CX-written `cx deps sync` (shallow fetch at SHA into an ignored `deps/`, read by the V build via `-path`); not submodules, not vpm. |
| **RS-8** | **Break policy (owner, "1a"):** within a release train a lower repository keeps its specified surface compatible; the repository that moved fixes what it breaks or ships the compatibility; an intentional break is a decision naming its consumers. |
| **RS-9** | **Docs follow the module.** `stdlib_colocated_docs.md` extends to every module in every repository: a repository generates its own reference fragment from its own corpus at release; a `cx` build embeds the docs of exactly the module versions it compiles in; the site in `cx` indexes what was published. The closed `[output]` list of `docs-src/llm/manifest.cxd` becomes the union of per-repository doc manifests. Nothing waits on the site. |
| **RS-10** | **Daemons stay subcommands of one `cx`** (`store-serve`, `fabric-serve`, `flow serve`, the XAP host). A separate executable per daemon is DEFERRED to the trigger the platform README already records: a deployment that needs a platform fix without a `cx` upgrade. Once the repositories exist that step is a `main` and a release lane in the daemon's repository. The four `cx` builds of cx_partition.md §4 (data, embed, cli, platform) are unchanged. |
| **RS-11** | **Public or private is a setting per repository.** The allowlist mirror (`scripts/publish.sh`, `.publishignore*`, the guard) retires with the split; `cx-private` becomes `cx` when it is no longer private. Issues live in the component repository; cross-cutting decisions in `cx-decisions`; release epics in `cx`. |
| **RS-12** | **Sequencing: the split starts now, during the suspension, and v0.18.0 ships from `cx` pinning the new repositories.** Extraction is TOP-DOWN and QUIETEST FIRST so the parked v0.18 branches move last among the tops: sso → agent + ux → mail, db → fabric → flow → connector → net → store → identity → core-data → the residue (xap, core-code; `cx-private` → `cx`) → bindings, registry, decisions, tooling. Each step ends on a green union. The repository template (gate, release lane, bump-PR job, `cx deps sync`) exists BEFORE the first extraction, or the repository count is the new choke point. #1591 is the checklist. |

## What this supersedes — the edit map

Each row is a sentence a later branch changes, carrying `RULED: RS-<n>` in its subject. The
owner reads every one. Nothing else in those pages moves.

| Page | Today | Becomes | Id |
|---|---|---|---|
| `spec/03-approved/core/cx_partition.md` §2 "Ring 2 — platform", "Ring 3 — ecosystem" | two ring definitions with import rows | the platform GROUP: a declared acyclic graph over the rings; bindings and tooling are groups on the C ABI and the released binary | RS-1 |
| same, §3 import contract | `Ring 2 MAY import Rings 0–1. Ring 3 MAY import Rings 0–2.` | `Everything else imports the rings and what its manifest declares, acyclic.` | RS-1 |
| same, §5 | "Monorepo, multi-artifact (ruled)." | "One repository per product (RS-2, RS-3); the conformance corpus stays the shared contract, carried per repository." | RS-2, RS-3 |
| same, §5.1 | "Private: the monorepo persists indefinitely. The split trigger is organizational…"; "Public: repos multiply on exactly two triggers…" | the split is done (RS-3); public/private is per repository (RS-11) | RS-3, RS-11 |
| same, §6 P1a | "all artifacts version in lockstep from the repo-root VERSION" | lockstep for the nine V repositories through `cx`'s pins; packages and bindings version on their own (RS-7) | RS-7 |
| same, §12.2 | "Public: bindings ship inside the public cx mirror … per-binding public repos are generated ONLY when…" | one repository per binding, the source not a mirror (RS-3) | RS-3 |
| `spec/03-approved/platform/README.md` §2 | "Platform version follows the CX binary … no independent pin … the recorded trigger for releasing Ring 2 on a cadence of its own is a client that needs one — D11" | true of the seven V products; the five CX products are packages pinned by hash (RS-3, RS-7); the D11 sentence moves to RS-10's deferral of per-daemon executables | RS-3, RS-7, RS-10 |
| same, §3.1 | `cx-fabric` and `cx-xap` "carry a namespace of their own" | both under `cx-platform/` | RS-4 |
| `docs-src/llm/primer.md.tmpl` §3 "The four rings — take the smallest one that answers your question" | a four-row ring table | a "which `cx` build do I install" table over the four builds, then the two rings | RS-1, RS-10 |
| `AGENTS.md` | "built in four rings — data, code, platform, ecosystem" | "two rings, data and code, and the platform, bindings and ecosystem groups above them" | RS-1 |
| `registry/modules.cxd` `ring=` | 0, 1, 2 | 0 and 1; platform rows carry `group=platform` | RS-1 |
| `ledger/rulings_2026_09_12_owner_letters_batch.md` OL-14 | "The repo split (Ring 2 first) is a recorded trigger, not a plan" | superseded by RS-3 and RS-12; the sentence stays as history with a pointer here | RS-12 |
| #1077 | NO-GO, the in-repo component layout | superseded: this is its repository-level answer with the measured basis it asked for | RS-2 |

## Not decided here

The agent cap stays the owner's: the machines lift the CPU constraint, not the oversight one.
Which daemon, if any, becomes its own executable first is RS-10's trigger, not a plan. The
per-machine runner model (self-hosted GitHub runners per box, one label per role) is #1591's
runner item and is operational, not a decision of this page.

## Measured basis (dev1, tree at `22175ebaf`, 2026-09-19 – 21)

A one-line change to `vcx/platform/stdlib_store.v` selects 58 of 89 post-merge steps because
every V step compiles one tree; a one-line change to `stdlib/flow.cx` selects 38, including
the language suite (~35 min), the extraction gate (~13 min) and the profile gate (~11 min).
Selected pre-merge run 154 min, full union 175 min on an idle 12-core box. Compilation is 9%
of the largest lane (`audit_2026_08_25_gate_cost_attribution.md`). Cross-area co-change over
4,046 commits in three months: Ring 0 + Ring 1 in one commit 3.2%; Ring 1 + platform 2.2%;
platform commits touching two components 11%. The top-of-stack components have zero or near-zero
V callers (connector 0, sso 0, audit 0, flow 1, fabric 15 — 11 of them by name). Every `xap_*`
call from below xap is one of four node accessors. did, vc, authz and bus import nothing.
