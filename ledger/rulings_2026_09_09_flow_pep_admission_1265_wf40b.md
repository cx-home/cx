# RULED: 1265-WF-40b — the PEP admission mechanism on the flow act path

**Owner, 2026-09-08 21:35Z** (the requirement, amending `1265-WF-40`);
**Fable under the owner's delegation, 2026-09-09 20:21Z** (the mechanism, on
letters drafted by worker A at 20:18Z). Implemented by worker A, 2026-09-09.
This record AMENDS `rulings_2026_09_08_flow_serve_wf28.md` §`1265-WF-40`: that
ruling kept the admission sentence normative and DATED it to the W3 performer
axis. The owner refused the dating — "every step is admitted at the PEP against
the run's recorded authority basis" is the trust property of an orchestrator
and it ships in v0.18.0. The `1265-WF-40` record stands as written for what it
decided (the re-cast sentences); its "lands with the W3 performer axis" clause
is superseded here and removed from `flow.md` §4.5, `flow.md`'s runner
paragraph and `misc/cli.md`'s serve bullet.

## What was decided

1. **(a) `[authz-request]` gains an optional `[basis 'cap:…']` child**, and
   `authz_decide` additionally requires the permitting chain to pass THROUGH
   that delegation. A request without the child decides exactly as before, so
   the cascade PEP and the store-query PEP are byte-unchanged. Refused: an
   actor-only `check` per requirement (it deletes the owner's own fixture
   sentence — the basis would not be what is checked, and 1265-PB-1 would be
   unenforceable); flow resolving the chain itself (it deletes `authz.cx:7-8`
   by making flow a second decider).
2. **(a) `opts.authz`** (the `store.md` §6.2 handle shape), consulted exactly
   where the act's command declares `[requires]`, FAIL-CLOSED there: a
   `[requires]` act with no handle is refused; an act with no `[requires]`
   needs no authority and runs. Measured cost on the corpus: zero — no flow
   fixture declared `[requires]`. Refused: a mandatory `opts.authz` (a
   whole-corpus edit for no additional safety); skip-when-absent (a courier
   that omits one opts key would bypass the PEP).
3. **(a) `CXER4700`** carrying the denial, delivered as the act's own answer:
   the step is `:failed` with the refusal recorded on it and §4.8's path
   applies (the `flow-044` shape). Refused: minting `CXER4969`, the flow
   band's last code, to re-code a decision flow does not own.
4. **The seam, as Fable corrected it.** `coord_flow_perform`, immediately
   before `command_invoke_labeled`, bracketed as the `[requires-at]` pin is —
   but the decision call is NOT a second `check` written in coordination. The
   request-building + decide is factored out of `xap_pep_admits` into ONE
   store-level PEP routine and called from both: the intent path keeps its
   runtime-store wrapper, the flow act path passes `opts.authz`. One decider
   (`authz_decide`), one PEP routine, two callers.

## What landed

- `vcx/platform/stdlib_authz.v` — `AuthzReq.basis`; `authz_read_request` reads
  the `[basis]` child; `authz_basis_delegation_id` resolves it against LIVE
  (un-revoked) delegation values; `authz_decide` denies `:basis-unresolved`
  before the grant scan and `:basis-not-in-chain` inside it, right after the
  principal-root walk, so the conjunct restricts and never enables;
  `authz_pep_decide` / `authz_pep_permits` are the shared PEP routine and
  `authz_decision_reason` names a denial's failing conjunct (D-C1).
- `vcx/platform/stdlib_xap.v` — `xap_pep_admits` is now a call to
  `authz_pep_permits` with no basis. Its request is byte-unchanged.
- `vcx/code/eval.v` — `command_requires_of`, the first reader of
  `CommandMeta.requires` on any invoke path.
- `vcx/platform/coordination.v` — `coord_flow_admit`, called from
  `coord_flow_perform` before the `[requires-at]` bracket.
- `stdlib/flow.cx` — `f--perform-act` takes `$opts` and `$rec` and threads the
  RUN'S RECORDED `actor`/`authority`/`stream` (off `$rec`, never off `$opts`)
  plus `opts.authz` and `opts.tenant` into the seam's opts map.
- Spec: `std-lib/flow.md` §4.5 (the mechanism, and the `:runner`-only scope
  statement) and its runner paragraph; `misc/cli.md`'s serve bullet;
  `std-lib/authz.md` §3.4's permit sentence and request grammar.
- Fixtures: `flow-067` … `flow-071`, `authz-091` … `authz-093`.

## Two things the implementation chose, inside the ruling's latitude

1. **The capability asked for is the requirement token with its `cap:` domain
   separator stripped** — `[requires cap:orders/pick]` asks the PEP for
   `orders/pick`. ONE rule with no branch, rather than one meaning for a
   `cap:sha2-256:` artifact address and another for a bareword. The ruling
   said "`cap:` address or bareword, resolved as `commands_effects.md`
   resolves it", and §6's rule is that `cap:` is the domain separator for
   trust inputs; what follows it names the thing. `authz_commit_impl`'s extra
   LIVE re-resolution of a `cap:` clause is the COMMIT point's own rule and is
   left exactly where it was — this is a second enforcement point for the same
   declaration, not a second reading of it.
2. **Tenant.** The request's tenant is `opts.tenant` when the caller names one
   and `''` otherwise, in which case `authz_decide`'s hard partition check is
   skipped and the store's OWN tenant governs. The ruling asked the worker to
   verify the partition rule and report if it must differ: it need not. The
   handle is passed explicitly by the caller, so the tenant was already chosen
   when the store was opened, and an empty request tenant cannot cross a
   partition — it can only decline to re-assert one (`authz.md` §4.6).

## The compensator fork — RULED 2026-09-09 21:30Z, and closed here

The fork below was put to Fable as a letter and **ruled 1(a)**: the FORWARD act
is admitted at the PEP; a compensator is not — the letter's reasoning stands,
and (b) is refused on it. **But the asymmetry does not wait for W3.** The
letter's own honest cost — "a deployment could put authority on the forward act
and have the reversal escape it" — is an authority hole, and the ruling closes
it in this landing with one predicate at a check that already exists:
**`validate` refuses a pre-pivot act whose `[compensates]` target declares
`[requires]`**, with the shipped `CXER4954`. A compensator that needs authority
the runner cannot re-present is not a compensator the runner can run — the same
fault class as "declares no `[compensates]`", reused and never re-coded.

**How a PURE check sees a def's `[requires]`.** Through the resolver row, which
`stdlib/flow.cx`'s own header ("WHY A DATA RESOLVER AND NOT LIVE
INTROSPECTION") already names as the only seam: no pure-CX surface reaches a
live def's clauses. §4.1's row therefore gains an optional `requires=`, the
def's own items space-separated, beside `compensates=` and `idempotent=` and
for the same stated reason — a STATIC check needs to see it. `cx flow --env`
emits it only when the def declares the clause, so an ABSENT `requires=`
declares no authority requirement, which is `commands_effects.md`'s
deny-by-default posture read the right way round.

**The compensator has a row of its own to read** because a resolver holds one
row per COMMAND, not one per act a document names: `flow_cli_module_acts`
walks every public `[effects]`-bearing def of every imported module. That is a
property of the shipped emitter, verified by running it, not an assumption —
`flow_umbrella_test.v`'s new case asserts the `wh/unpick` row exists before it
asserts the refusal.

**Where the environment carries NO row for the pairing the check STANDS DOWN.**
This is decided, not overlooked. A resolver may legitimately hold rows for the
acts a document names and not for their compensators — every hand-built
resolver in `conformance/stdlib/flow.cxd` does, including `flow-006`'s own
`compensates='c/undo'` with no `c/undo` row — and `f--open-resolver`'s dry-run
rows name `compensates='unresolved:'`, which has no row by construction.
Refusing on a missing row would therefore refuse `simulate` over the open
resolver and a corpus of valid documents, inventing a refusal from an absence.
The check is exact where the environment is complete and silent where it is
partial; `flow-072`'s `comp-row-absent` pins the stand-down so it can never
become an accident.

**Two things deliberately NOT touched.** (1) `validate`'s ANSWER rows still
project `name`/`resolved`/`idempotent` only (`f--act-answer`) — `requires=` is
an INPUT the check reads, not an output, so no `out-text` in the corpus moves.
(2) The two `CXER4965` argument-refusal messages that spell the row as
`[act name= resolved= compensates=? idempotent=?]` are unchanged: they are
fixture-pinned strings whose job is to correct a MALFORMED resolver argument,
not to enumerate the grammar (one of the three already omits the `[fn …]`
child). §4.1 is where the grammar is normative, and that is where `requires=?`
landed.

**Red proof, measured with no build and no slot.** The module source run as a
program against the same driver, edited vs `origin/release/0.18`: the edited
module answers `CXER4954` for `comp-requires-pre`, `no-pivot-comp-requires` and
`map-body-comp-requires` and carries the message; the tip's module answers
`VALID` for all three with an empty message. Seven probes are identical in both
columns — `forward-requires` among them, which is the case a naive reading of
the rule breaks: an act that itself declares `[requires]` validates, because
THAT one is admitted at the PEP against the run's basis.

## The fork as it was put (superseded by the ruling above)

`coord_flow_admit` is called AFTER `coord_flow_perform`'s compensate branch
returns, so a **compensator is not admitted at the PEP** — only the forward
act is. The ruling said "every step"; a compensation is §4.8's reversal of a
step rather than a step of its own, so the placement decides something the
ruling did not say. It is recorded rather than assumed: a compensator the PEP
refused would strand the run `[conflict kind=:uncompensatable]` for an
authority reason instead of an effect one, and §4.8's reverse path is the
runner's obligation to finish once the forward act has run — against which
`[compensates]` does name an ordinary command that may declare its own
`[requires]`. Put to Fable as a letter on #1265. Reversing it moves ONE call
above the compensate branch and changes nothing else.

## The id range moved by one

The ruling pre-announced `flow-066` … `flow-070`. `flow-066` was taken by
`a98584025` (#1316, `activated=`) between the ruling and the landing, so the
set is **`flow-067` … `flow-071`**. Registry pre-flight over all 118
`impl/*` + `release/*` refs at landing time: flow high-water 66, authz
high-water 90.

## What is NOT in scope, and why that is not a deferral

Only the `:runner` arm is reachable in v0.18.0 — `stdlib/flow.cx:553-556`
refuses `by=:principal`, `:agent`, `:peer`, `to=`, `[escalate]` and `[bounds]`
to W3, so `opts.authority`-at-start is the whole of the shippable mechanism.
The `[bounds]` attenuation and the performer's-own-authority arms of
`flow.md` §4.5 remain stated law with no reachable case, and `flow.md`'s
scope paragraph says so in as many words. That is the vocabulary's own
staging, not a reduction of this ruling.
