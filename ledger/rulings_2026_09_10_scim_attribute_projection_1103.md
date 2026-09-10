# RULED: 1103-a — SCIM attribute projection ships in v0.18, and `returned: never` is not narrowable in either direction

**Fable, 2026-09-10 18:03Z, on the owner's Lane P direction ("1103 and 1383
delivered in v0.18. Get enterprise SSO completely done"):** scope is the
issue's own list — RFC 7644 §3.9 projection driven by each attribute's RFC
7643 `returned` characteristic, `attributes` / `excludedAttributes` on GET,
list and PATCH responses, and the security half: a `returned: never`
attribute never leaves a response whatever the request says. Fixtures first,
a spec section carrying this token, and an `examples/platform/sso/` example
that exercises it (1383-a).

This record closes **C-2a** (`rulings_2026_08_29_scim_1092.md`), which ruled
§3.9 out of v1 by name rather than silently narrowing C-2's in-list, and
which said out loud that the deferral had a security edge.

## The principle

**`returned` outranks the request, in both directions.** A client's
`attributes` list says what it wants; the schema says what may be given. The
four values are read before the request is read at all:

| `returned` | in the default set | under `attributes=…` | under `excludedAttributes=…` |
|---|---|---|---|
| `always` | yes | yes, unrequested | yes — not removable |
| `never` | **no** | **no, even when named** | no |
| `default` | yes | only when named | unless named |
| `request` | no | only when named | no |

`never` is the security half and it is the reason this is not cosmetic: core
`password` is `mutability: writeOnly, returned: never`, so `apply-patch`
returns a map holding the credential the patch just set — it has to, the
patch set it — and a feature that echoes that map back to the IdP leaks it.
`project` with no options at all is the whole fix, because the default set is
`default` and `never` is not in it.

## What changed

- **`stdlib/scim.cx`** gains one public verb, `project(resource, opts)`,
  reading `attributes:` / `excluded-attributes:` from `opts`. No shipped
  verb's signature moves.
- **`list-response` projects every member**, with or without narrowing
  options. A ListResponse is a response, and this is the surface a deployment
  is most likely to forget; leaving it to the caller would have re-created
  §9's hazard one layer out. Pinned by `scim-082` and `scim-085`.
- **`spec/03-approved/std-lib/scim.md`**: a new §8 for projection, the §3
  surface row, and **§9's security note rewritten** — it said "v1 does not
  project attributes for you (RULED: C-2a)", which this ruling makes false.
- **19 fixtures**, `scim-071`…`scim-089`.

## The calls inside the scope, and what each one refuses

1. **A requested name that addresses nothing is REFUSED** (`CXER5602`), not
   narrowed away. Refused the lenient reading: returning only the `always`
   attributes for a misspelled `usrName` looks like data loss to the client
   and like success to the deployment. This follows `validate`'s posture
   (§6, spec line 208) and the issue's own error list. `scim-080`.
2. **A key no supplied schema describes is KEPT in the default set** and
   dropped under an explicit request. Refused making the projector a second
   validator: `validate` already owns that refusal (C-6's escape hatch is to
   supply the schema), and duplicating it here would make a response harder
   to widen than to narrow. `scim-084`.
3. **`request` is honoured at whatever level the schema declares it** — an
   attribute or sub-attribute marked `request` needs its own name, and
   naming a complex parent does not request it. One uniform rule; refused
   special-casing sub-attributes under an explicitly named parent, which
   would have made the level a thing to remember. `scim-081`, `scim-086`.
4. **A resource that declares no `schemas` is still projected**, resolving
   against every schema in play. Refused refusing it the way `validate` does
   (`scim-059`): a store that never wrote `schemas` onto its rows is exactly
   the deployment whose response still goes out, so refusing would leave the
   credential in the only place it mattered. `scim-085`.
5. **A value-filter path in an attribute list is REFUSED** (`CXER5600`).
   §3.9 takes attribute names in §3.10 notation; a value filter is §3.5.2
   PATCH syntax and selects members, not attributes. `scim-087`.
6. **The two options are mutually exclusive** (`CXER5600`), as §3.9 says.
   Refused picking one: that answers a question nobody asked. `scim-079`.
7. **The list is read as a sequence OR as one comma-separated string.** A
   query parameter arrives as the latter and a CX caller holds the former;
   the module's standing rule is that nothing is translated between the wire
   and these verbs. A non-string list is the CX caller's fault (`CXER5607`)
   under the #1100 split, while a malformed NAME is the IdP's (`5600`/`5602`).
   `scim-088`, `scim-089`.

## Error codes

No new codes and no new band: `CXER5600` (malformed list — the IdP wrote
it), `CXER5602` (a name addressing nothing), `CXER5607` (a CX caller passing
something that is not a name list). All three already registered in
`governance.md` §9.6.
