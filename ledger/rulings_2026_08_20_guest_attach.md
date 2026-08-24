# Ruling GA-1 (2026-08-20) — attach-guest: the anonymous-floor transport (#857, owner "857a")

The gap: `cx-stdlib/session` ships three attach transports (`attach`/
`attach-token` Bearer, `attach-did` DID proof, `attach-xsp` XSP-AUTH) and
every one requires a proof. `xap_identity_model.md` §4.7 already names the
principal you get when you prove nothing — the deployment's **anonymous
floor** — and `attach-xsp` already takes `anonymous-floor` in its cfg, but
the plain-HTTP transport for it is missing. A public web surface therefore
has no session for pre-login state (basket, saved search), and #787's P0-76
forbids the workaround (a parallel visitor-cookie model beside the session
module). The ORIEL demo carries the debt as a named shim
(`spec/03-approved/xap/demos/oriel/session.cx` `guest-attach`, "deleted the
day the primitive arrives").

RULED (owner, 857a — 2026-08-20): **pre-cut bug-class fix; the cross-cutting
debt is not carried into v0.16.0.** `attach-guest` lands in
`cx-stdlib/session` as the fourth attach transport:

```
[?def attach-guest scope=public impure [returns element] ($req::element $cfg::map)]
```

- `$cfg` carries the floor principal (`anonymous-floor`) and the `tenant`.
  The **presence of `anonymous-floor` in cfg IS the deployment's policy
  admission** (mirroring `attach-xsp`'s existing cfg posture and §4.7's
  "policy either refuses or maps to the floor").
- It mints the SAME `[session]` value at the floor through the SAME cookie
  adapter — same `HttpOnly; Secure; SameSite` posture and refusals
  (`CXER4810`/`CXER4811`), same per-session CSRF synchronizer (a guest
  session is cookie-shaped: ambient credential ⇒ CSRF-guarded, never
  exempt), same `attached | detached | expired` states, registered in the
  session registry so `of`/`from-cookie`/`by-id` resolve it.
- Guest sessions are **per-visitor independent**: N visitors share one
  floor `(principal, tenant)` but NEVER one session — a guest attach never
  mirrors by subject and never becomes the floor subject's default session.

Three properties, all normative (from §4.7), amended into
`spec/03-approved/std-lib/session.md`:

1. **Remint on privilege transition.** An anonymous session that logs in
   does not keep its pre-login id: a PROVEN attach (`attach`/`attach-cookie`)
   over a request whose cookie names a live guest session invalidates the
   guest session server-side and establishes the proven session under a
   freshly minted id (the §2.8.4 fixation machinery, applied at the
   anonymous→proven seam). Fail-closed ordering: the guest session is
   invalidated only AFTER the new proof verifies — a failed login leaves
   the guest session (and its state) intact.
2. **The floor is a real `(principal, tenant)` and the PEP gates it like
   any other** — no anonymous COMMIT by default; the floor principal's
   grants define the entire anonymous attack surface (identity model §10
   item 12).
3. **Refusal is the common case.** When the deployment's policy does not
   admit an anonymous floor (the production default per §4.7), attach-guest
   refuses CLEANLY with a typed error naming the policy:
   `cx-err:CXER4812 E_SESSION_ANONYMOUS_REFUSED` — newly allocated from the
   session band's unallocated tail (`CXER4813–CXER4849` remain reserved).
   This is the session-band analogue of the identity model's
   `CXER-XSP-AUTH-ANONYMOUS-REFUSED`.

Riders:

- **GA-1a (no downgrade).** `attach-guest` over a request already carrying a
  live PROVEN session cookie refuses (`CXER4805` semantics — the binding is
  immutable and never downgrades to anonymous). Over a live guest cookie for
  the same `(floor, tenant)` it is idempotent (returns the live session +
  its Set-Cookie directives — a visitor re-attaching does not lose their
  basket).
- **GA-1b (via marker).** The guest client records `via=guest`; for the
  ambient-credential classification (CSRF gating N-SESSION-7, rotate) the
  engine treats `guest` as cookie-shaped. The materialized `[session]`
  carries `guest="true"` so surfaces and audit read the pre-login state
  directly.
- The ORIEL shim deletion (the consumer swap the shim's own header promises)
  is a consumer landing, sequenced separately with the 787 lanes; this
  ruling covers the stdlib/session + spec + conformance surface.

Scope of the mixed spec+impl commit under this ruling (`RULED: GA-1`):
`stdlib/session.cx`, `vcx/platform/stdlib_session.v`,
`vcx/platform/ring2_register.v`, `spec/03-approved/std-lib/session.md`,
`conformance/stdlib/session.cxd`, `vcx/tests/stdlib_session_guest_test.v`.
