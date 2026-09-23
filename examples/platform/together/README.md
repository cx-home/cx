# Together — one component's output is the next one's input

One runnable scenario.

```sh
make deps-sync   # the login half is cx-platform-sso's now (RULED: RS-12)
cd examples/platform/together/sso-flow-xap && CX=cx sh run.sh
```

| Scenario | What it shows |
| -------- | ------------- |
| [`sso-flow-xap/`](sso-flow-xap/) | An SSO login establishes a principal; that principal is the flow run's actor; the XAP wiring layer is what governs the same domain in a deployment |

## Why this is a composition and not three examples in a row

The test of a composed example is whether a value CROSSES the boundary.
Here one does, in the open, in the transcript:

1. `actor.cx` runs the OpenID Connect login in full — the same
   `validate-id-token` call, with the same refusals available — and answers
   the principal it established.
2. The shell unquotes that answer and hands it to
   `cx flow run … --actor=…`.
3. The flow record comes back carrying `actor=principal:user-42`, and its
   run id is the content address over (the document, **that** principal, the
   args). Change who logged in and the run id changes.

**There is no path where an unverified subject reaches the flow.** A wrong
token makes `validate-id-token` answer an `[err …]`; reading a claim off an
error propagates the error; the shell then has an error value where an actor
should be, and the flow run is never reached with a principal nobody
authenticated.

## Nothing is copied

The flow document and the acts module are the ones in
`examples/platform/flow/checkout/` of cx-platform-flow, read out of the checkout
`deps.cxd` pins (`deps/cx-platform-flow/`, since the extraction — RULED: RS-12;
`make deps-sync` first), unchanged — this directory adds only its
own `--env` program, because a relative `[?lib]` path resolves against the
working directory. The XAP instance is the one in
`examples/platform/xap/storefront/`, unchanged. If either moves, this
transcript moves with it, which is the property worth having: a composition
that carried its own copies would keep passing after its parts broke.

## What is not composed here yet

The XAP layer is shown as what it is — the joined grammar and the authority
that admits an act — but the flow run in step 2 is the local `cx flow run`
profile, not a run admitted by that XAP's authority. Wiring the flow run
through the deployment's policy enforcement point is the next rung, and
saying so is better than implying it already happened.
