# CX v0.18.0-pre.1 — Release Notes

**Date:** 2026-09-12
**Tag:** `v0.18.0-pre.1`

This is a **pre-release checkpoint**, not the final v0.18.0. It is cut the moment epic S
(enterprise SSO production readiness) reaches completion and before the ring-legible tree
reshape (#1427) touches the spec/code layout (RULED: INT-3) — so the SSO surface can be
evaluated on a stable tree while M2 (the mailbox model) and the tree reshape continue in
parallel. **195 merges** landed on `release/0.18` since the `v0.17.0` tag, closing on the order
of **375 issues**. The final v0.18.0 follows once M2 and #1427 land (RULED: OL-13).

Three bodies of work dominate this checkpoint: **epic S** — SAML, OIDC, session, SCIM and the
transport layer under them, hardened to a gated, real-socket interop step against Entra, Okta,
Ping and ADFS; **M1** — CX ships its own SMTP and IMAP, client and server, built agent-ready from
the start; and the **delivery grammar** — the release process itself now has one vocabulary,
spec-approved, with the tooling renamed to match. Underneath those, the path/value model's node
access API rollout continues, `cx flow` gained a standalone runner and closed an intermittent
ingress race, and the format/playground/diagram tooling had another hardening pass.

## Headlines

- **Enterprise SSO is production-ready (epic S).** The SSO deployment surface (#1394) went
  from "undershot like the mailbox" (the owner's words, 1394-b) to complete: an XML-DSig signer
  entered `crypto` (`crypto:xml-sign`, RSA-SHA256 and ECDSA-SHA256, CXER3700–3721), SAML gained
  SP-initiated login and Single Logout, XML Encryption (`EncryptedAssertion`/`EncryptedID`/
  `EncryptedAttribute`, CXER5413), the full binding layer (ACS decode, HTTP-Redirect, RelayState,
  CXER5415/5416), a SHA-1 opt-in for legacy IdPs (CXER5414), and Core-conformance hardening
  (unrecognized `<Condition>` invalidates, `OneTimeUse`/`ProxyRestriction`/`@Version` read,
  CXER5406). OIDC was hardened (narrowable alg allow-list, PKCE fail-closed by default, the
  device grant RFC 8628, `client_secret_jwt`, back-channel logout, RFC 9207 `iss`). Session
  became store-backed and durable across restarts (#1395), gained replay defense (SAML assertion
  ID as `jti`, CXER4814/4816), identity linking, service/agent principals, and a documented 60s
  clock-skew leeway actually applied (#1398). SCIM added RFC 7644 §3.9 attribute projection
  (#1103), pagination on the wire-spelled keys, and a strong ETag (#1406). None of it is graded
  offline any more: an in-tree identity provider mints live, correctly-dated signed assertions
  per profile (Entra/Okta/Ping/ADFS), and a gated real-socket interop step
  (`test-sso-interop-lane`) runs 29/29 SAML rows live and a growing set of OIDC rows, with a
  published compatibility matrix that fails the release gate on any PARTIAL/PENDING cell (#1403).
- **CX ships its own mail transport, agent-ready from the ground up (M1, #1085).** SMTP and IMAP
  landed as protocol modules with both client and server halves — SMTP submission, pipelining,
  DSN, STARTTLS, per-RCPT verdicts (123-case corpus, real-socket tests); IMAP4rev2 with 38 verbs
  (list/select/fetch/search/store/idle/…, 144-case corpus, real-socket step 15/15); SASL as a
  shared mechanism registry (PLAIN/LOGIN/OAUTHBEARER/XOAUTH2, 71-case corpus). Server hardening
  followed immediately: read/idle/pre-auth timeouts and the §5.4 rate window on served sockets
  (#1426), and IMAP's `DONE`/IDLE handshake corrected so a client can actually end an IDLE
  against CX's own server (#1428). Every mailbox operation is designed as an intent from the
  start (compose/send/reply/triage/…) so an agent and a human call the same verbs once the
  mailbox feature (M2) lands on top — the design principle is ruled (1085-a), the transport
  underneath it is what this checkpoint ships.
- **The delivery grammar is now spec, and the tooling speaks it (DG-1).** One vocabulary for
  the whole release process — release/epic/issue/decision/spec, branch/worktree/integration
  branch/merge, owner/integrator/agent/session, step/pipeline/run/runner/flaky test/artifacts —
  replaces three prior, never-ratified drafts (`spec/03-approved/process/delivery-grammar.md`,
  status New). Tooling was renamed to match: RUN-START/RUN-EXIT markers, "step" instead of
  "lane" in output, the serial-retry banner says "passed" (RULED: OL-12). A pre-merge run is now
  explicitly exempt from `check-gate-lock` — the lock protects the integration checkout during a
  post-merge run, not a worktree's own build (RULED: INT-1) — and a branch merges once every
  step of its own pipeline has passed on its final tree, with only the touched steps re-run
  after a fix (RULED: OL-3); when `test-changed` escalates to the full union, the branch instead
  merges on its other steps and the post-merge run grades the union (RULED: INT-5).
- **`cx flow` gained a standalone runner and closed an intermittent 400.** `cx flow serve` runs
  a flow outside any host with its own fixed-delay courier (#1265, WF-28), `cx flow watch`
  streams the run overlay live over the capability-free fd-1 answer channel (#1369), and pending
  timers re-arm at boot under their own recorded basis (#1313). The flow runner's HTTP ingress
  is now serial with its courier — a handler runs only while holding the process evaluator's
  turn — closing a race where one of three identical webhook deliveries was intermittently
  answered 400 (reproduced 1/40 → 3/80 → 0/80 under load, #1411). Every flow step is now admitted
  at the PEP against the run's own recorded basis, one routine serving both the cascade and the
  flow act path (#1265, WF-40b), and the diagram module gained the run picture as its third
  subject — a run overlay keyed by node id (#1316).
- **The node access API rollout continues.** `vcx/cx`, `vcx/code`, platform, tests, `cmd`, `cli`
  and `lang/v` moved their `ScalarValue` dispatch onto the access API (#1201–#1206, W2–W4); the
  `__cx_map__` envelope retires in favor of one map carrier (RP-3); a bare string in
  collection-item position now re-reads as the same string on both the parser and evaluator
  side, closing a persisted-groups coalescing bug (#1420, RULED: 831-1a′) with every content
  address unchanged.
- **Format, playground and diagram tooling hardened again.** The playground corpus sweep found
  and fixed 14 silently-stopped examples and added 20 more (#1170, a multi-week hardening effort: the
  bare-builtin lint, the `[?let]`-cascade lint, per-example `[expect]` grading, the mermaid gate
  joining the matrix). `cx fmt` gained a corpus-sweep gate with a named error roster (#1348), the
  fmt fingerprint now hashes a decimal's and float's canonical image correctly (#1347), and the
  diagram module unified its VIEW axis (`auto | erd | cfg | seq | effects`, #1377) with the
  mermaid golden corpus now recording what it was rendered from (41 `.source` sidecars, #1350).
- **V fork bumped to `115487c7a4` (four new patches).** A pooled span keeps its oldest trim
  clock through a coalesce or split and files in age order (#1295, closing a `vgc` age-ordering
  defect); a dynamic-Huffman `deflate` emitter picks the smaller of fixed/dynamic from one LZ77
  pass (#1095, two patches: emitter + pinned test); the checker type-checks a match-expression
  arm against a `.result` return type (#1213).

## Changed (behavioral)

- `[auth …]` on a `[?http-service]` is enforced on the real socket — a guard that returns `err`
  now refuses 401 there too, and a guarded `[$serve-file]` route stops serving the file (#1393).
  A deployment relying on the previous silent pass-through is now refused; audit any guard that
  was never actually exercised.
- Session persists across restarts and replicas through a store seam (`cfg.store`, `mem://`
  default) instead of living only in one process (#1395); the documented 60s clock-skew leeway
  default is now actually applied, on both the OIDC and SAML paths (#1398).
- `session:attach-saml` is strict with no opt-out: an under-configured `cfg.saml` refuses
  (CXER4813 naming every missing key) instead of silently disabling checks (#1397).
- SAML: an unrecognized `<Condition>` invalidates the assertion (CXER5406) instead of being
  ignored; `OneTimeUse`, `ProxyRestriction`, `@Version` are read; SHA-1 refuses unless opted in;
  certificate expiry is checked at metadata import (#1404, #1410).
- OIDC: the caller can narrow the algorithm allow-list; `code_challenge_methods_supported`
  omitted now means no PKCE, fail-closed; a `:none` client is refused at `begin`; the
  back-channel logout token must carry the client id in `aud` (#1407).
- SCIM: pagination reads the wire-spelled keys (`startIndex`/`count`/`totalResults`) instead of
  ignoring them; `meta.version` is a strong ETag with `If-Match`/`If-None-Match` honored; `DELETE`
  answers a 501 refusal naming `active:false` instead of silently doing nothing (#1406).
- The flow HTTP ingress with `{serial: true}` holds the process evaluator's turn for the
  duration of a handler; the store's single-owner refusal no longer fires spuriously on its own
  fold worker (#1411).
- A post-`FILE` argument spelled like a `cx` flag draws one stderr warning naming the argument
  and the binding order, unless the program's `[argspec]` declares it — argv, stdout and exit
  status are unchanged (#1424, RULED: OL-10).
- The out-err grader now pins the TOP-LEVEL error code everywhere it is used (fixture, profile
  and fmt runners); OIDC's panic-string error converter is gone in favor of a proper `[cause]`
  (#1408).
- A bare string in collection-item position re-reads as the same string on the parser and
  evaluator side (#1420, RULED: 831-1a′); a decimal negative zero keeps its sign in the
  canonical image (#1353).

## Known gaps / still to come

- **M2 — the mailbox model.** The spec was rewritten to platform grade on a branch
  (`mailbox.md`: enterprise model — shared mailboxes, ACL, SORT, retention/legal hold,
  export/import, quotas, rules as flows; agent model — scoped grants, attributed keywords,
  annotations, proposals; RULED: 1413-a, 1413-b) but is **not yet merged** into `release/0.18`.
  The mailbox model/code (#1413), the delivery queue and relay (#1414), deliverability —
  DKIM/SPF/DMARC/ARC (#1415), the `mail` XAP agent feature (#1416), and the interop step against
  Gmail/M365/Fastmail (#1417) all remain for the final v0.18.0.
- **#1427 — the ring-legible tree.** Decided in full (1427-a…j, RULED: OL-14/OL-15: `stdlib/` +
  `platform/`, `cx-stdlib/` + `cx-platform/`, a parser-based migration, no dimension executed in
  isolation) but not yet executed. It runs after what is in flight today and before M2 code
  lands, so M2 lands directly in the new structure rather than being moved twice.
- **INT-2's four issues** — pulled into the v0.18 scope by the owner but not yet landed as of
  this checkpoint: #1421 (no server-role TLS upgrade on an accepted connection — SMTP/IMAP
  servers cannot offer STARTTLS to a real client), #1422 (`security.md` §2 names an audit
  channel that does not exist), #1384 (`cx fmt` silently changes data around a bare text run
  beside a char-ref), #1391 (`cx fmt` fails closed and silently on a bracketed/collection value
  in argument or attribute position — 36% of the tracked corpus does not format). #1418, #1419,
  #1423 and #1392 were considered and deliberately moved to the next release instead.
- **The connector kit** (#1430, `#728` component 2 — pagination vocabulary, engine loops, the
  `cx-connector` library, a real connector end to end, OpenAPI ingestion) remains open. A GraphQL
  client codec module was decided (Ring 1, `cx-stdlib/graphql`, RULED: GQL-1) for the connector
  kit's first consumer, next release; the server half is a recorded trigger, not planned work.
- **The SSO interop matrix** is real but not yet exhaustive: OIDC rows pass over a real
  socket for the flows exercised so far and SAML rows are 29/29 live against the in-tree IdP; the
  published compatibility matrix continues to carry PARTIAL/PENDING cells per named provider
  until each is driven live (release-verify fails while any remain, by design, #1403).
- **#1394**, the SSO deployment-surface issue this checkpoint is named for, reflects the state at
  the moment of this cut; its formal close is a separate step from the code landing it here.

## Toolchain

- V fork bumped from `cf25c48308` (`v0.17.0`) to `115487c7a4` (`third_party/v`), four new
  patches: a `vgc` fix so a coalesced or split pooled span keeps its oldest trim clock and files
  in age order (#1295); a `compress.deflate` dynamic-Huffman block emitter that picks the
  smaller of the fixed/dynamic encoding from one LZ77 tokenize pass, plus its pinning test
  (#1095, two patches); and a checker fix so a match-expression arm is type-checked against a
  `.result` return type (#1213). All four are registered in `scripts/v_fork_register.cxd` and
  are V-only, upstreamable.
