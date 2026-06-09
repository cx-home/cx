# D4 — `guestbook`, + agent (resolver/agent + the dial)

Add an **agent** as a fourth peer alongside the three human clients (CLI, TUI,
web). It emits the **same** `[do :sign …]` intents (agent-parity, §15); the
**dial** (an `authz` delegation, §21) governs how much it does on its own.

## Files

| File | Role |
|---|---|
| [`agent.cx`](agent.cx) | the `guestbook` capability (reused) + the runtime + the dial + a human sign + an agent sign + a `why-allowed` audit |
| [`expected-output.txt`](expected-output.txt) | the `why-allowed` result — the deciding delegation chain + the accountable principal |

## Run

```sh
cx agent.cx
```

## Expected output

```
[why-allowed allowed='true' [chain [delegation id=d-dial-guestbook from=principal:dana to=agent:greeter-1 [scope :guestbook] [setting :semi-auto]]] [accountable principal=principal:dana]]
```

The agent's sign was admitted **via the dial's delegation**, and the accountable
party resolves to the human `principal:dana` — authority traces to a principal at
every instant (N-CONTROL-2). The guestbook now holds Ada (human) + Lin (agent),
each attributed to its own `:actor` in the journal.

## What it demonstrates

- **Human + agent are peers on one intent surface** (N-CLIENT-1): both fire the
  identical `[do :sign]`; both commit through the same PEP + cascade.
- **The dial *is* delegation issuance** (§21.3): `[$xap:dial …]` = `[$authz:delegate …]`
  — scoped, attenuating, revocable; raising it off the floor lets the agent act
  within bounds.
- **Per-pool attenuating sub-delegation** (R1): the agent runs under its own
  sub-delegated session, so the journal's `:actor` names the specific agent and
  `revoke` / `why-allowed` work at agent granularity.
- **Accountability invariant** (N-CONTROL-2): `why-allowed` always resolves the
  accountable party to a human principal.

## Implements (the `cx-xap` slice)

The resolver / agent hook (xap.md §20 — scripted for the demo) + `authz`
delegation (the dial, `[$xap:dial]` / `[$xap:why-allowed]`).

## Status

Spec-conformant and **runs today** on the bundled `cx-xap` runtime: `cx
agent.cx` produces `expected-output.txt` exactly. The dial (`[$xap:dial]` =
`authz` delegation issuance) + `[$xap:why-allowed]` query are implemented; the
resolver/agent hook is scripted for the demo (xap.md §20).

> Beyond D4 (no rewrite): raise the dial toward **guardian** (§22.4) within the
> bright line; **federate** a second XAP into one experience (§22.6.1); reach a
> new **medium** (voice, mobile) by changing nothing. That trajectory is Tier 1
> (the boat, xap.md Appendix D §T1).
