# RULED: 1398-a — session's `leeway` default reaches the SAML path: `attach-saml` injects it into `cfg.saml` when that map names none

**Fable, 2026-09-11 02:0xZ, under the owner's delegation of 2026-09-09 05:50 ET**; the owner
may override on #1354. Letters drafted by worker A (Opus) on #1398 at `304d3433c`; premises
re-verified at `19af3b349`: `session_leeway_node` (`stdlib_session.v:430`) supplies the 60 s
default to the JWT paths only; `session_attach_saml_impl` hands `cfg.saml` to the saml verbs
verbatim (`:1295-1298`), and `saml_validate_verb` reads `opts.leeway` with default `0`
(`stdlib_saml.v:688`). So an SP that names no leeway gets zero skew tolerance on an
enterprise IdP's `Conditions/@NotOnOrAfter` — the failure mode #1398 exists to remove, one
path over.

## 1. Whose knob is clock skew on the SAML path — RULED (a)

- **(a) the top-level `leeway` reaches both paths.** `attach-saml` copies `cfg.leeway`
  (or the 60 s default when that is absent too) into the `saml` opts map **when that map
  names no `leeway`**; an explicit `cfg.saml.leeway` (including `0`) is honoured verbatim.
  One skew knob per login. DELETES two cells of `session.md` §3.1: the `leeway` row's
  *"forwarded to `[$crypto:jwt-verify]`"* becomes *"forwarded to whichever verifier the
  attach path uses — `crypto:jwt-verify` or `saml:validate`"*, and the `saml` row's
  *"session does not interpret it"* becomes *"session does not interpret its SEMANTICS
  (issuer, audience, recipient, `attrs` — RULED: 1360-b); it supplies its own `leeway`
  default when the map names none"*. That is what 1360-b was for — keeping session out of
  SAML semantics — and a skew default is session's product-surface knob on the other path
  already.
- **(b) a separate injected 60 s default in `cfg.saml.leeway`, ignoring the top-level key** —
  refused: half a fix. A deployment that wrote `leeway: 90` at the top level would still get
  a different tolerance on its assertions, the layered surprise this issue's own ask 3 names.
- **(c) leave it; document that `cfg.saml.leeway` defaults to `0`** — refused: for a lane
  whose bar is *"it will need to just work"* in a client's IdP, zero tolerance on
  `NotOnOrAfter` against ADFS/Entra clock drift is the intermittent-login class, not a
  documentation gap.

**Rider, load-bearing (the one argument against (a), taken on board):** the 60 s widens the
window in which a captured assertion is still acceptable. It creates no exposure the module
does not already state (`saml.md` §9: replay is the deployment's; #1405 owns the replay
store), but **#1405's replay-window arithmetic must include the leeway in force** — the
session already records `leeway_secs` at attach (`stdlib_session.v:113`), so the number is
there to read.

## 2. The DID path — no skew knob in v0.18

`attach-did`'s only clock check is `vc_do_verify`'s lexical ISO-8601 comparison, with no
leeway parameter anywhere (`stdlib_vc.v:164`). A proof-of-control has no long-lived assertion
window to drift across; adding a parameter to a ring-2 verb is new API outside this issue.
Recorded; not filed. A measurement showing drift there is a new issue.

## 3. The pure verbs keep `0`

`crypto.md` §3.10 and `saml.md` §4.5 already pin it. A primitive must not invent tolerance
its caller did not ask for; a product surface must. No spec change, no ruling needed.

## Conformance

In `conformance/stdlib/session.cxd`: `session-062`'s document with the clock 30 s past
`Conditions/@NotOnOrAfter` and no `leeway` anywhere → **attaches** (red at HEAD); the same
with `saml: {leeway: 0}` explicit → refused `CXER4801` wrapping `CXER5406` (the explicit
choice is honoured); top-level `leeway: 90` with the `saml` map naming none and the clock 80 s
past → attaches; top-level `leeway: 90` but `saml: {leeway: 10}` and the clock 30 s past →
refused (the inner key wins). The pure-verb `saml-073`/`saml-074` stay as they are.

Spec commits carry `RULED: 1398-a`. Interplay with RULED 1397-a (strict `attach-saml`):
`leeway` is not among the keys strict REQUIRES; the injected default and the documentation of
`leeway`/`destination` in §3.1 are the same edit.
