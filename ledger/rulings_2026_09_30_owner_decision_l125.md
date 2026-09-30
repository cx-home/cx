# Owner decision 2026-09-30 — Letter 125: cx-platform-xap#1 closes on its four merged items; the runner's key through the keystore handle is its own issue after the cut

**Status: RULED (owner, 2026-09-30 ~03:4xZ, in session, "a", answering Letter 125 as posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 03:3xZ with its three options and asked
again in chat as "l125a / l125b / l125c"). FW-1, FW-2, WF-28b, WF-29, SEC-1, XAP-1, RS-36.**

## The owner's words, verbatim

"a"

## HKEY-1 — xap#1 closes on items 1–4 as measured; item 5 (the signing key and connector credentials through a `cx-platform/secrets` handle) is filed for after the cut (L125 = (a))

FW-1 ruled every named landing of `flow.md` into v0.18 and FW-2 made the v0.18.0 tag wait for FW-1's
issues. Measured on `6fc01a610` (post-merge run `2026-09-30T03:36:01Z RUN-EXIT=0`): W3 and W7 were
merged on 09-25 (`47e65ed92`) and 09-26 (`341add5ca`) and `flow.md` §3's status rows say their verbs
shipped, so cx-platform-flow#3 and #7 closed on the measurement; cx-platform-xap#1's items 1–4 — the
`[on …]` binding row in the deployment document, the host-side courier and `rearm` loop, ρ over the
composed grammar, the binder as the actor of `start` — merged 09-26 (xap main `6e880f967`,
`f034d07a2`), and item 5 is not built: the runner's signing key still arrives as an opts value
(`stdlib/flow.cx`, `snapshot-key`), SEC-1's keystore ships as `cx-platform-secrets`, and nothing wires
the runner to a handle. Ruled: xap#1 closes on items 1–4; item 5 is filed as its own issue on
cx-platform-xap — the runner's signing key and connector credentials resolved through a
`cx-platform/secrets` handle, the keystore's first live consumer, a small xap+flow round after the
cut with the two-journal byte-identical fixture pair kept; the v0.18.0 release notes say the key
arrives by the runtime's options. Nothing is stubbed: the opts path is the working path and stays.
Rejected: (b) building item 5 before the cut — about one more window on the critical path; (c)
keeping xap#1 open and relabelling it v0.19.0 — FW-2's "the tag waits" amended by the owner's word or
the cut waiting indefinitely.
