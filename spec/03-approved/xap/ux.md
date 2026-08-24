# CX UX — the projection capability: semantic vocabulary + emitter contract

**Status:** APPROVED (graduated 2026-08-20, ruling UX-1,
`ledger/rulings_2026_08_20_ux_spec_precut.md`) — the verbatim promotion of
`design/787/787-phase0-spec.md`, whose clauses were owner-ruled 2026-08-17
(Parts I–II sign-off, all eight §9 letters Q-A…Q-H) with the later ruled
amendments recorded inline ([P0-97]…[P0-104], 2026-08-18/19; [P0-105]…[P0-110],
2026-08-20 — the W26 studio rulings ST-1a…ST-8a,
`ledger/rulings_2026_08_20_studio.md`; [P0-111]…[P0-113], 2026-08-20 — the
designer-studio rulings DS-4a/DS-5a/DS-6a,
`ledger/rulings_2026_08_20_designer_studio.md`; §18, the studio's editing
model — [P0-114]…[P0-120] — under DS-11 of the same ledger; §19, design
control and the adopter's product — [P0-121]/[P0-122] — under DS-12; §18.6, the
projection rule, the derived map and history — [P0-123]…[P0-125], [P0-127] —
and §19.2a, declared geometry — [P0-126] — under DS-13…DS-17, and [P0-128] with
§19.2a's orientation rule under DS-18, and the place-keeping and
legible-without-its-stylesheet rules under DS-19, all in the same ledger). The
historical
draft note said this document "lives under design/787/ until #832's naming
ruling places it"; #832 closed 2026-08-18 and this is that placement. The
clause text is unamended by the promotion; §17 (Implementation and
conformance) is the one graduation addition. This spec is the normative home
of the ux capability; `design/787/787-phase0-spec.md` is the historical
draft record.

**Inputs:** issue #787 rulings 1–9; the 2026-08-14 owner addendum (C1–C5, R1–R8, scope
tiers, DP1–DP3); the 2026-08-15 identity/authz sketch and its six Phase 0 questions; the
2026-08-13 field-evidence comment (21-feature estate, four spec inputs); the vision document
(`design/787/787-vision.md`, branch `design/787-ux-vision`).

**Terminology:** per C4 — the composed deliverable is a **surface**, never an "app". Ruling
8's `[app …]` head renames to `[surface …]` throughout.

**Ruling convention:** clauses marked **[P0-n]** were drafted by the Phase 0 session and are
owner-ruled as written (2026-08-17). §9 records the eight letters and their answers.

---

## 1. Scope

This document drafts the two artifacts the addendum's Phase 0 requires before W1 opens:

1. the **projection vocabulary** — the claim, component, surface-document, and layout-command
   heads, and above all their **keying** (§2), which is identity-bearing and expensive to
   unwind if minted wrong;
2. the **emitter contract** — the normative obligations of the web renderer (§5): sole
   attribute author, pinned htmx subset, escaping/CSP, per-session projection, redaction, and
   the fragment-swap invariants taken from field evidence.

It also rules the six identity/authz questions (§6) and folds the four field-evidence
findings into normative clauses (§2.3, §4, §5.3, §5.4, §6.7).

Everything here is additive, Ring 2. Nothing touches identity, format, or wire semantics of
existing surfaces.

**Shipped-anatomy alignment.** The vision doc's L1 sketches (`in=`, `rule=`,
`flow= propose/commit`, `[?feed]`) were expressly shapes-level. This draft binds to the
shipped spellings: a command is a `[?def]` with an `[effects]` clause (presence is the
discriminator); its input is the param list; rules are `[preconditions]`; propose vs commit
is decided by the boundary and the actor's authority basis, never declared on the command;
and feeds are stream-3 live-modes subscriptions. Where the sketches and the shipped surface
diverge, the shipped surface wins throughout.

---

## 2. Identity and keying

This is the section that must be right the first time. Canonical forms are identity-bearing
(canonical.md §1.2/§1.4): every key ruled below is defined by strict canonical bytes, and
every derived rendering (DOM ids, catalog keys) is a stated function of those bytes — never a
second identity.

**[P0-1] Four keying regimes, none conflated.** The design uses exactly four kinds of key,
each answering a different question:

| Regime | Keys | Answers |
|---|---|---|
| **Claim keys** (§2.1) | (schema content-address, field-path) | *what shape* a claim is about — presentation intent, labels, field capabilities, component overrides |
| **Fragment addresses** (§2.2) | (route, feature instance, element path) | *where on a rendered page* — swap targets, OOB updates, dedup memos, anchors, studio selection |
| **Document addresses + cascade** (§2.3) | Tier-1 content address; name→address bindings per cascade level | *which theme/template/pack/mapping* was in force |
| **Surface-doc element ids** (§2.4) | author-assigned ids inside one surface document | *which placed element* a layout command addresses |

The studio's selection protocol is a defined projection **from** regime 2 **to** regimes 1
and 4: a click resolves a fragment address; the edit it emits lands either as a claim (keyed
by regime 1) or as a layout command (addressing regime 4). Fragment addresses are never
stored in claims and never appear in journals as subjects — they are runtime addresses.

### 2.1 Claim keys: (schema content-address, field-path)

**[P0-2] The subject side is an existing Tier-1 address, unchanged — three subject kinds,
because commands are not schemas.** No new address form, no bare hex, no version strings —
exactly the discipline `[schema-lineage]` and journal `schema=` already use:

- **Data shapes:** the E2 schema content address — `sha2-256:<lowercase hex>` over the
  schema's strict CANONICAL TEXT bytes (schema.md §13.1, hash_registry). The portable,
  "wherever this schema is used" key. This is the workhorse.
- **Command forms:** the command's **input-schema identity** — the same `input-schema-id`
  the agent-tools descriptor already carries (tools.md §2). Commands take a param list, not
  an `in=` record; the tools projection already derives a param schema via
  `type-schema-of` and gives it an identity. Keying form-level claims (param grouping,
  ordering) by that identity is stable under def *body* edits (the def-text Tier-1 changes
  on every body edit and would orphan claims) and shared with the tool face for free.
- **Command-level presentation** (the command's own label/summary override): keyed by
  **qualified verb** within the composed grammar — `[verb :place-order]`. Two commands with
  byte-identical param lists share an input-schema identity, so shape-keyed claims cannot
  name one of them; the verb is the composition's command address (it is what
  `POST /intent/<verb>` dispatches on) and is stable under body edits. Verb-keyed claims
  are composition-scoped, deliberately — a command's name is not a portable shape.

(Ruled as written — §9 Q-G.)

**[P0-3] The field side is a CXPath**, the slash-separated step path already canonical in the
suite (validate.md §2.2 `path="/address/zip"`, canonical.md §2.12 emit rules with round-trip
identity). Whole-value claims carry path `/`. Two constraints specific to claim paths:

- **No positional predicates.** Claims address *schema nodes*, not document nodes; `[n]`
  steps are refused in a claim key (a hint applies to every instance of a shape).
- **Paths are local to the keyed schema's root** — they never start anywhere else.

**[P0-4] The composite string form** — needed wherever the pair must be one string (i18n
catalog message keys, component-registry keys) — is the tagged address immediately followed
by the CXPath:

```
sha2-256:<hex>/items/qty      ; field
sha2-256:<hex>/               ; whole value
```

Unambiguous by construction: the address grammar admits no `/`, and every CXPath starts with
one. This composite is a *derived spelling* of the pair, not a third identity.

**[P0-5] Claims are Lane-2 detached documents**, following the `[type-binding]` /
`[schema-lineage]` suite shape: subject keys as child elements, payload as attributes/body.
Stored as ordinary content-addressed store documents — never store metadata, never schema
edits (an edit would mint a new schema identity — ruling 6).

```cx
# verify-skip — schematic block (deliberate ellipses / placeholders)
[ux:hint  [schema sha2-256:…] [path /items] view=cards]
[ux:hint  [schema sha2-256:…] [path /price] format=currency]
[ux:label [schema sha2-256:…] [path /customer] lang=de "Kunde"]
[ux:cap   [schema sha2-256:…] [path /cost-basis] read=cap:… mode=mask]
[ux:component [schema sha2-256:…] [path /stock]
  [?def render [v] [ux:badge tone=[?if [< $v 10] warn ok] $v]]]
```

(The `for=@…` sugar in the vision doc's sketch resolves to this canonical form; sugar is a
reader affordance, the claim's identity is the canonical form above.)

**[P0-6] Innermost-schema keying with context override.** When a field's enclosing type is
itself an addressable schema (one-type-per-schema-document is normative,
semantic_value_model.md §3), the *portable* claim keys on the innermost schema
(`line-item` + `/qty`) — that is what makes it sharable "wherever that schema is used".
A *context-specific* claim keyed on an outer schema with a path crossing into the referenced
type (`place-order` + `/items/qty`) is also legal. Resolution per rendered node, per hint
type: **outermost context wins, then longest path, then the claim from the nearest cascade
level (§2.3)**. This is a bounded, two-level specificity rule — not CSS.

**[P0-7] Lineage carriage is asymmetric by safety class.** Claims survive schema evolution
via the existing `[schema-lineage]` unique-path graph (`[$journal:lineage-path]`, CXER4643/4
fail-closed on ambiguity) — no new linkage vocabulary. Carriage rules:

- **Presentational claims** (`ux:hint`, `ux:label`, `ux:component`): carried automatically
  across `:additive` and `:narrowing` relations when the path still resolves in the target
  schema; **fail open** — a claim that no longer resolves is ignored and the default
  projection applies (silent loss of a hint degrades to a safe default). `:split`/`:merge`
  do not carry; claims are re-blessed against the new address.
- **Field-capability claims** (`ux:cap`, §6.1): restrictions carried across `:additive` and
  `:narrowing` automatically (a restriction must not evaporate); across `:split`/`:merge`
  the projection **fails closed** — a schema revision reached by a `:split`/`:merge` edge
  from a schema that carried `ux:cap` claims refuses to serve until its capability claims
  are re-blessed (CXER TBD, W-phase). Cosmetics fail open; safety fails closed.

### 2.2 Fragment addresses: (route, feature instance, element path)

**[P0-8] Identity inputs are exactly the triple — everything else is content.** Theme,
template, locale, actor, session, and data values are inputs to a fragment's *content*,
never to its *identity*. Consequences, each load-bearing:

- a rebrand (theme/template change) does not change fragment addresses — anchors, memos,
  and studio selections survive;
- two sessions in the same visibility class (§5.6) render **the same fragment address** with
  identical bytes — render-once-broadcast is possible at all only because identity excludes
  the actor;
- per-user redaction changes content, not address — a lens never forks identity.

**[P0-9] The canonical form is a CX value**; its strict canonical bytes are the identity:

```cx
[frag [route /orders] [feature orders] [path /open-orders/row[o-1041]/status]]
```

- **route** — the *instantiated* route path as served (pattern params bound:
  `/orders/o-1041`, not `/orders/:id`). Fragments are addresses on rendered pages; the
  pattern-level "this label everywhere" intent belongs to regime 1 (a claim), which is what
  the studio emits after resolving a selection.
- **feature** — the feature *instance* name on the route. It defaults to the feature name;
  composing the same feature twice on one route **without explicit distinct instance names
  is a compose-time refusal** (no silent ordinals, no first-wins).
- **path** — element path inside the instance's projection: schema-derived step names for
  projected elements, template slot names for template regions, the author-assigned id
  (§2.4) for placed elements.

**[P0-10] Collection rows key by declared key, or identity degrades honestly.** A row
element's path step is `row[<key-value>]` where the key is the projected query's declared
row key. If a collection declares no key, rows get **no per-row addresses**: the enclosing
fragment is the smallest addressable unit, per-row OOB updates are unavailable, and updates
repaint the region. Positional row identity is **never** minted — an insertion must not
re-address every following row.

**[P0-11] DOM id is a derived rendering, not a second identity.** The `id` attribute is
`cx-` + the first 16 lowercase hex chars of the sha2-256 of the fragment address's strict
canonical bytes; the full readable canonical form rides in `data-cx-frag`. Rendered-fragment
goldens therefore stay human-diffable, ids stay CSS-selector-safe for htmx targeting, and
truncation is defined once: an intra-page truncated-id collision is an **emitter error**
(refusal, never silent disambiguation). Deep links use `#cx-<hash16>` anchors.

### 2.3 Documents and the cascade

**[P0-12] Theme, template, component-library, hint-set, and claims-mapping documents are
ordinary Tier-1 store documents** — immutable, content-addressed (`sha2-256:` tagged, strict
canonical bytes), no latest pointers; names live in the alias layer, exactly per store.md
§11. A rebrand is a doc put plus a binding change. Nothing new is minted here — that is the
point.

**[P0-104] `[palette scheme=…]` — named token sets inside one theme document.**
*(RULED — owner, 2026-08-19, audit2 letter (p).)* A theme document MAY group
tokens into `[palette scheme=light|dark …]` groups, of which exactly one
carries `default=true`; tokens outside any palette are shared by every
scheme. The web emitter writes the shared tokens and the default palette's
tokens as the `:root` block, and each non-default palette as the same custom
properties under `@media (prefers-color-scheme: <scheme>)` — the tree, the
classes and every component rule stay scheme-blind, which is the token
system's own claim (one decision, resolved everywhere) made conditional. The
refusals are fail-loud like every token's: a palette whose `scheme=` is
missing, outside the ruled set, or already claimed by another palette is
`ux-bad-palette-scheme`; palettes present without exactly one `default=true`
is `ux-bad-palette-default`. A theme with no palettes emits byte-identically
to before this clause. The terminal theme may later map schemes the same
way; nothing here obliges it yet. Rejected: a second whole theme document
plus a binding switch — the cascade binds one theme per level, and a scheme
is a *condition inside* a brand, not a different brand.

**[P0-13] The cascade order is ruled now, four levels, vendor reserved:**
`platform → vendor → tenant → surface`. v1 (MUST tier) populates platform, tenant, surface;
the **vendor level is reserved in the resolution order from day one** and simply empty until
R3 (SHOULD) lands — introducing it later is then a data change, not a keying migration.

**[P0-14] Resolution is per-key, nearest-wins.** Each level contributes *binding documents*
mapping names/claim-keys to addresses (theme slots, template names, component names, hint
sets, claims-mappings). Resolution for a given key walks surface → tenant → vendor →
platform and takes the first binding — "override the piece, inherit the rest, at every
level" (R3). Merged bundles are never stored; the resolution is a pure function of the level
binding-document addresses.

**[P0-15] The render-input manifest closes the audit loop.** Every render is a pure function
of a manifest of addresses: (surface doc, level binding docs ×4, resolved claim docs, schema
addresses, locale, visibility class). The emitter can emit this manifest as a value; "which
UI did tenant X see on date D" = the manifest reconstructed from history — projection inputs
are all content-addressed, so the answer is exact, not archaeological.

### 2.4 Surface-document element ids

**[P0-16] Placed elements carry author-assigned stable ids** in the surface document
(dashboard-style estates: the arrangement is data). Layout commands (§4) address elements by
these ids, never by position. Ids are unique per surface document (compose-time check); the
id becomes the element-path step for the fragment address (§2.2).

---

## 3. Projection vocabulary

Call convention follows the stdlib (`[$html:serialize]`, `[$store:put-doc]`): the projection
entry points are `[$ux:…]`. The pack is Ring 2, platform profile, same `-d` gating pattern
as the rest of the platform ring (ruling 1).

### 3.1 Projection entry points

```cx
# verify-skip — schematic block (deliberate ellipses / placeholders)
[$ux:form  $command]          ; command param schema → complete form
[$ux:table $query]            ; query row schema → complete table
[$ux:feed  $sub]              ; live-modes subscription → live region (§5.5/§5.6)
```

**[P0-17] The third projection derives from the same source as the first two, the same
way.** A command is a `[?def]` whose `[effects]` clause is present — clause presence, not
item count, exactly the agent-tools discriminator (tools.md). Like the tools face, the UX
projection **derives at render time from definitions; there is no materialized UI manifest**
to drift. The mapping reuses the tools machinery: fields from the param list via
`type-schema-of` (stream-16 carrier conventions), required = the non-defaulted positionals,
default labels and help text from `[fn-doc]`/`[param-doc]` — the same documentation sources
the tool descriptors consume. One divergence, deliberate: where the tools projection
fails loud on a missing `[summary]` (agent-facing descriptions are load-bearing semantics),
the UX projection **degrades to name-derived labels** — human-facing defaults are
presentational, and the R6 gates measure their quality. `[preconditions]` and schema
constraints are enforced once, at the command layer; a refusal renders as a form error from
the `[err]` channel — the UX layer never restates a rule. Reference-typed fields project
typeahead wired against the referenced query (spelling per the shipped schema vocabulary).

**[P0-18] Writes ride the shipped intent wire.** A projected form submits as
`POST /intent/<verb>` (the existing web bridge: ρ-resolution, PEP, contract apply,
`[ack …]`/refusal), with the session CSRF token attached (§6.3). The web UX face is a client
of the shipped XAP web binding — it adds **no new wire**.

**[P0-19] The approval widget is mode-driven by the boundary, not declared on the command.**
There is no `flow=` clause; the boundary decides the mode (commands_effects.md §5). The
emitter, being actor-aware (§5.3), projects accordingly:

- an actor whose authority basis for the verb carries `[propose-only]` gets a **Propose**
  submit; the created `[proposal …]` (its Tier-1 address is what an approval binds) appears
  in the widget as pending;
- an actor holding commit authority gets direct commit;
- the widget's pending / who-approved / history views render from the `[approval [subject
  hash=…]] …` Lane-2 claims and the journaled `[command-committed proposal=…]` transitions —
  shipped stream-6 machinery, projected, not reimplemented. It shows what *you* can approve
  (§5.3).

**[P0-20] Vocabulary surface-neutrality (R5).** The semantic element set emitted by
projection (`ux:card`, `ux:field`, `ux:table`, `ux:badge`, …) assumes no hover, pointer, or
CSS-shaped layout; the web emitter's lowering to HTML/htmx is renderer-private (§5). The
semantic element list itself is a W1 deliverable enumerated as fixtures; this draft rules
the *discipline*, not the final list.

### 3.2 Hint claims — the initial ruled set

**[P0-21]** v1 hint types (deliberately small; the hint vocabulary gets language-surface
governance — vision §9.8):

| Hint | Payload | Meaning |
|---|---|---|
| `group` | `name=`, member order | group fields (address block) |
| `order` | explicit field order | reorder within a form/table |
| `view` | `table \| cards` | collection presentation |
| `format` | `currency \| …` (locale-aware via locale.md) | scalar formatting |
| `show` | `disabled` (+ optional `reason=`) | opt an uninvokable command into visible-disabled (§6.2) |

`ux:label` is the i18n carrier: **[P0-22] label claims compile into i18n catalogs** —
message key = the composite string form (§P0-4) plus `lang`; ICU MessageFormat
(i18n.md) is available for parameterized labels. No parallel label machinery.

### 3.3 Component overrides

**[P0-23]** `[ux:component]` registers a **pure def** (value → semantic element) for a claim
key; purity-checked, fixture-testable, lowered by the emitter like every built-in component
(ruling 2 — no second template language). Registration participates in the cascade (§2.3):
a tenant-level override beats a platform default for the same key.

### 3.4 The surface document

```cx
[surface storefront-admin
  theme= @cx:base
  [nav Products Orders]
  [route /products [feature xap=catalog]]
  [route /orders template=two-pane [feature xap=orders]]]
```

**[P0-24]** `[surface …]` (renamed from ruling 8's `[app …]` per C4) is a document: diffable,
reviewable, deployed by store put. Route-level picks (template, feature composition) live
here and are deliberately unshared (vision §6). Hand-authoring a surface doc plus projection
defaults is a complete, working path with no studio (R1 — the bootstrap guarantee; W5 proves
it). Note: the CXDM head `[surface …]` for the composed-deliverable document coexists with
the XAP readout element of the same name (`GET /surface/<f>`, `[surface-delta …]`) — same
word, different planes (a document head vs a readout element); ruled to coexist — §9 Q-H.

**[P0-25] Routing lowers onto shipped machinery.** `[route …]` entries lower to the
directive-owned routing the platform already ships (`[?http-service]` `[resource]` routes,
`:name` path params) over the hosted web binding (`POST /intent`, `GET /stream`,
`GET /surface/<f>`). The surface document is composition data; it introduces no second
router.

---

## 4. Layout command vocabulary — partial-document semantics

The studio and drag/drop both emit these; they are ordinary typed commands (journaled,
actor-stamped, propose/commit-capable). Field evidence finding 1 becomes normative here:

**[P0-26] An element a command does not address is untouched — never removed.** All layout
commands (`[ux:move]`, `[ux:set-hint]`, `[ux:wrap]`, and any future member) address elements
by surface-doc id (§2.4) and mutate only what they address. This is load-bearing because
**editors operate under lenses**: a principal that received a 7-of-12 projection can only
serialize what it was sent; replace semantics would make its first edit silently delete
everything its lens withheld — no error anywhere.

**[P0-27] Whole-document replacement does not exist in the vocabulary.** Not "requires the
widest visibility" — absent. Bulk edits are sets of element-addressed commands (batchable in
one journal entry). This also buys per-element attribution in the journal for free (the
field evidence's observation).

**[P0-28] An address miss is a refusal, not a no-op.** A layout command addressing an id
that no longer exists (concurrently deleted) refuses with a conflict error; silence would
hide a lost update.

**[P0-29] Layout validity rules are evaluated against the full document, server-side** —
never against a lens projection (a client cannot avoid collisions with elements it was never
told about; §5.3's placeholders exist so it doesn't have to).

### 4.1 The five members and their shapes (W26 — the studio)

**[P0-105] `[ux:place]` and `[ux:remove]` complete the vocabulary.**
*(RULED — owner, 2026-08-20, studio letter ST-3a.)* `move`/`wrap`/`set-hint`
rearrange and restyle what exists; an editor that cannot add or remove a
placed element is half an editor. The closed member set is these five, each
with the P0-26..29 semantics, journaled, actor-stamped,
propose/commit-capable; the shapes are normative (the inverse-pair table
below is spelled in them):

```cx
# verify-skip — schematic block (deliberate placeholders)
[ux:move     id=<id> parent=<id|""> before=<id|"">]   ; ""-parent = the layout root; ""-before = end
[ux:wrap     id=<id> wrapper=<new-id> component=<container-name>]
[ux:set-hint id=<id> hint=<name> value=<text|"">]     ; ""-value clears the surface-level hint
[ux:place    id=<new-id> component=<name> parent=<id|""> before=<id|"">]
[ux:remove   id=<id>]
```

- `[ux:place]` inserts a placed element under an **author-assigned id**;
  uniqueness is checked at apply and a collision refuses (P0-16). Addressing
  an absent `parent=`/`before=` refuses (P0-28).
- **Placeable is a component name resolvable via the §2.3 cascade — never raw
  markup.** A `component=` that no cascade level binds refuses; the studio's
  palette is the resolvable set, not an HTML editor.
- `[ux:wrap]` mints a new **container** placed element (`wrapper=`, same
  uniqueness rule) standing exactly where the addressed element stood; the
  addressed element becomes its only child. Wrapping in a non-container
  component refuses (a P0-29 validity rule).
- A `[ux:move]` whose `parent=` lies inside the addressed element's own
  subtree refuses (a cycle is a P0-29 validity rule, judged against the full
  document).

**[P0-106] `[ux:remove]` takes the addressed element's own subtree with it.**
*(RULED — owner, 2026-08-20, studio letter ST-3a.)* Children of a removed
element are removed with it — they are its content. **P0-26 protects
unaddressed SIBLINGS, never the addressed subtree.** Removing an id that a
concurrent command has bound as its `parent=`/`before=` target refuses at
that command as the standard address-miss conflict (P0-28); nothing here
introduces a second conflict channel.

**[P0-107] `set-hint` writes land at the SURFACE level only at v1.**
*(RULED — owner, 2026-08-20, studio letter ST-4a.)* A hint edit is a claim
write into the cascade (P0-13/P0-14); the surface level is deliberately
unshared (P0-24), so a studio edit can never silently restyle another surface
or tenant. A hint inherited from a wider level displays with its provenance
(P0-109's stamped cascade level), and **override here** — a surface-level
write of the same hint — is the one offered action. Clearing the surface
value (`value=""`) returns the element to the inherited resolution. A level
picker is a post-v1 ruling once §6.5 has field evidence at tenant scope.

**[P0-108] Undo is inverse-command emission — the inverse-pair table.**
*(RULED — owner, 2026-08-20, studio letter ST-7a.)* An editor's undo stack
holds INVERSE commands, client-held, emitted through the same journaled path:
the journal stays the single honest history (an undo IS an edit — attributed,
replayable). There are no server-side revert verbs. The pairs, each computed
against the pre-state the client was rendered with:

| Command | Inverse |
|---|---|
| `[ux:move id P B]` | `[ux:move id parent=<prior parent> before=<prior successor\|"">]` |
| `[ux:set-hint id h v]` | `[ux:set-hint id hint=h value=<prior value\|"">]` |
| `[ux:place id …]` | `[ux:remove id]` |
| `[ux:remove id]` | the `[ux:place]` (or P0-27 batch of places + set-hints) that reconstructs the removed subtree in place |
| `[ux:wrap id wrapper=w …]` | **one P0-27 batch**: `[ux:move id]` back to where the wrapper stands, **then** `[ux:remove w]` — in that order, because remove takes its subtree (P0-106) |

A batch is atomic: one journal entry, all-or-nothing — a refusal of any
member refuses the batch whole (P0-27's "sets of element-addressed commands,
batchable in one journal entry", with the refusal semantics stated).

**[P0-111] `[ux:set-param]` — content parameters on placed elements.**
*(RULED — owner, 2026-08-20, designer-studio letter DS-5a.)* A placed element
MAY carry **content parameters** — the words and references a component
renders (a headline, a blurb, an image path, a link target) — declared by the
component's registry entry and written by the sixth member of the closed
command set:

```cx
# verify-skip — schematic block (deliberate placeholders)
[ux:set-param id=<id> param=<name> value=<text|"">]   ; ""-value returns to the registry default
```

Same P0-26..29 semantics, journaled, actor-stamped, propose/commit-capable;
its inverse row is `[ux:set-param id param value=<prior|"">]`, computed like
set-hint's. Two constraints, both load-bearing: a param **value is text
flowing through the emitter's escaping (P0-32) — never markup** (inline
content editing cannot become an HTML injection surface); and a param whose
name the component's registry entry does not declare refuses (the P0-98
closure discipline reaching arrangement data). Params are content where
hints are presentation: a lens or face that drops a param has dropped
content, and the content normal form carries them through the projected
output.

**[P0-112] The theme-write wire — look and feel is editable, journaled, and
gated.** *(RULED — owner, 2026-08-20, designer-studio letter DS-4a.)* P0-12
already rules a rebrand as "a theme-document put plus a binding change"; this
clause gives it a wire. Token edits (color, type, spacing, radius — including
P0-104 palette groups) commit as **one journaled theme write at the surface
cascade level** through a gated intent, P0-27 batch semantics (a set of token
changes is one entry, all-or-nothing), every value through the emitter's
token-value gate (an unsafe value refuses the write exactly as it refuses a
sheet). Gating is the same §6.5 claims mapping as the layout commands — one
`ux:edit` claim at v1, splittable into a distinct theme claim when an estate
needs the separation. A committed theme write re-renders attached clients
through the same liveness path as a layout commit. The studio's live PREVIEW
is client-side and ephemeral by design — the journal records only commits,
and P0-82 governs committed state, not a designer's in-flight gesture.

**[P0-113] The component registry declares the editable surface.**
*(RULED — owner, 2026-08-20, designer-studio letter DS-6a.)* A registry entry
names, beyond the component and its container-ness (P0-105): its **params**
(name, default, and the carrier the studio's inline editing targets), its
**variant axes** (name + closed option set — `orientation: top|side`; a
variant is an ordinary surface-level hint per P0-107), and the hint axes it
honors. What the registry does not declare, the studio does not offer and the
commands refuse — the registry IS the closed editing surface, which is what
makes a client-facing palette safe by construction. Data-bound components
(collection blocks parameterized by a declared domain query) are registry
entries like any other; their params select the query, never write it.

---

## 5. Emitter contract

### 5.1 Sole attribute author; the pinned subset

**[P0-30]** All managed HTML flows through the emitter; the emitter is the **sole author** of
htmx attributes (R4 — replaceability is an invariant). htmx and idiomorph are vendored and
pinned together (idiomorph is the morph engine §5.4 requires; it is htmx-ecosystem
standard).

**[P0-31] The initial normative attribute set** (fixture-enforced from W1; additions are
individual rulings; `hx-on` is excluded permanently per R4):

```
hx-get  hx-post  hx-target  hx-swap  hx-swap-oob  hx-trigger
hx-include  hx-indicator  hx-ext  sse-connect  sse-swap
```

Excluded until individually ruled in: `hx-boost`, `hx-push-url`, `hx-vals`, `hx-confirm`,
`hx-select`, `hx-sync`, non-POST write verbs (commands post). Rationale: every attribute in
the set must be replicable by a ~2 kB substitute kernel with no surface-visible change.

### 5.2 Escaping and CSP

**[P0-32] Escaping is an emitter invariant, stated once.** Semantic-element lowering emits
through the existing html pack serialization (`[$html:serialize]`, WHATWG rules,
double-quoted attributes) — text content and attribute values are escaped by construction
(strings.md `escape-html` discipline at the character level). Fragment composition happens
at the CXDM tree level, never by string concatenation; there is no interpolation surface to
inject into.

**[P0-33] Strict CSP is a requirement**, enabled by the `hx-on` exclusion and by:

- the emitter never emits inline `style=` (theming is token CSS — a generated stylesheet;
  this also keeps every visual decision in the token/claim system);
- the emitter never emits inline scripts or event-handler attributes;
- the vendored kernel (htmx + idiomorph + the island loader) and island assets are served
  as static files and hash-pinned in `script-src`.

**[P0-34] Rung-4 raw routes carry their own stated escaping obligation** (they bypass the
emitter; R7) — the html pack's `sanitize` / `sanitize-with-policy` is the sanctioned tool.

### 5.3 Per-session projection, redaction, placeholders

**[P0-35] One evaluator.** The emitter consults the same authorization evaluator as the wire
and the agent-tools face, per session, at render time. What is shown and what is allowed are
the same computation (the identity/authz sketch §5): commands the actor cannot invoke are
not emitted (§6.2), unreadable fields are omitted/masked (§6.1), out-of-scope rows never
leave the query.

**[P0-36] Withheld layout-bearing elements keep their geometry** (field evidence finding 2).
A lens that withholds a placed element emits a **redacted placeholder** carrying layout
metadata only — position and size, with the content fields **never computed into the
output** (nothing exists client-side to un-hide). Placeholders make server-side validity
rules honorable by every client and make invisible-collision deletion structurally
impossible. A placeholder has the element's normal fragment address (identity excludes
content — §P0-8).

### 5.4 Fragment-swap invariants (field evidence finding 3 — pack-owned, fixture-testable)

Each of these passed every server-side gate in the originating estate before failing in the
field; they are stated as pack invariants precisely because the defect class is invisible to
server-side testing by construction.

- **[P0-37] One painter per managed region.** The kernel is the only writer into managed
  fragments; islands write only by posting commands (ruling 4).
- **[P0-38] Dedup memos live ON the element.** Any repaint-skip memo is stored on the DOM
  element it guards — a destroyed node carries no memo, so a rebuilt fragment always paints;
  the fetched-but-unpainted desync becomes structurally impossible rather than patched per
  call site.
- **[P0-39] Morph, don't replace** — idiomorph with `ignoreActiveValue`: the field under the
  cursor is protected at element granularity; a live update never wipes in-progress input.
- **[P0-40] Hide, don't wipe** on intra-page region switches (tab/pane toggles within one
  page; v1 is MPA, route changes are real navigations) — hidden regions keep their DOM and
  their memos.
- **[P0-41] A fetch cache never gates a DOM write.** Any response-dedup state advances only
  after the paint commits (equivalently: skip decisions read only element-resident memos,
  §P0-38). The cache-advanced-before-skip-guard failure mode — the focused fragment that
  stops updating forever — is thereby excluded.
- **[P0-42] An empty or non-200 fragment response is a failed swap**, surfaced in a visible
  error state — never a success. (Field case: 200-with-empty-body from a broken deploy read
  as success.) Managed fetches treat empty bodies as protocol errors.

**[P0-43]** These are fixture obligations of the pack itself: rendered-fragment goldens
cover the emitter side; the swap behaviors get a thin browser-harness lane (the vision doc's
honest challenge 3 — accepted, scoped to exactly these invariants). Harness choice is a
W-phase decision; the obligation is ruled now.

### 5.5 Liveness

**[P0-44] A UX feed is a live-modes subscription; ∂ frames lower to fragment operations.**
There is no `[?feed]` directive to invent: the shipped machinery is stream-3 live modes —
`[$ux:feed $sub]` consumes a `[live-sub …]` (`[$live:observe]` over a quoted planar
comprehension, live.md) and the emitter lowers its ∂ frames onto fragment addresses (§2.2):

| ∂ frame | Fragment operation |
|---|---|
| `[insert pos=N ROW]` | OOB insert of the keyed row fragment (§P0-10) |
| `[retract pos=N]` | remove the keyed row fragment |
| `[regroup pos=N ROW]` | move/re-render the keyed row fragment |
| `[recompute reason=…]` | repaint the enclosing region |

Unkeyed collections (§P0-10) collapse every frame to region repaint — honestly, per the
keying ruling. Transport is the shipped SSE surface (http.md §3.6 `sse-subscribe` topics /
`sse-publish`; hosted `GET /stream`) through `hx-ext` + `sse-connect`/`sse-swap`, one SSE
connection per page. Resume follows the shipped pattern: the reconnecting client presents
`Last-Event-ID` and the server replays from the cursor (`[head-set …]` — never a scalar),
the journal-fold-from-cursor discipline http.md already states. Pages never poll.

### 5.6 Feed visibility classes

Ruled with the update semantics per the sketch's §6; see §6.4.

### 5.7 Edit mode — the studio is the emitter with `edit` engaged (W26)

**[P0-109] Edit mode is the same face, capability-gated, with selection
stamped at render.** *(RULED — owner, 2026-08-20, studio letter
ST-1a/ST-2a/ST-6a.)* The studio is NOT a second app: it is the web face
itself with edit engaged — the same projection, the same emitter output,
plus a selection overlay and an inspector. Consequences, each normative:

- **Gating is the `ux:edit` claim through the §6.5 claims mapping** — no new
  mechanism. The face renders the edit toggle only when the session carries
  the claim (§6.2's hide-vs-refuse covers the toggle), and **every layout
  command is re-checked server-side at the PEP** like any command; the
  browser is never an enforcement point.
- **In edit mode ONLY, the emitter stamps selection resolution beside
  `data-cx-frag`**: `data-cx-sel` carries the resolved edit target — either
  `[placed <surface-doc-id>]` (regime 4) or `[claim <schema-address>
  <field-path>]` (regime 1) — and `data-cx-sel-prov` carries the element's
  current hint provenance (which cascade level bound each honored hint).
  Selection is then a pure client-side read: one resolver (the emitter, which
  knows both answers while rendering), no round-trip per click, no second
  resolution algorithm to drift. Resolution data rides the render context,
  derived at projection time — never a second identity, never a client guess.
- **Normal-mode output is byte-identical to a build without this section** —
  edit-mode HTML is a strict superset, and edit-mode goldens pin the stamped
  bytes while the normal-mode goldens pin their absence.
- **Edit mode suspends normal app pointer interaction** (selection-first): a
  click selects; the app's own controls act again when edit is disengaged.

**[P0-110] The studio chrome is ONE vendored, pinned, CSP-clean asset.**
*(RULED — owner, 2026-08-20, studio letter ST-5a.)* The studio client
(`studio.js` + `studio.css`) is vendored and pinned exactly like htmx and
idiomorph (P0-30's vendoring discipline) and served ONLY in edit mode; it
complies with the emitter's CSP (§5.2 — no inline script, no eval, SRI-pinned
like every kernel asset). Its DOM additions live under one reserved root
(`#cx-studio`); the attributes it owns are `data-cx-studio-*`; it **never**
writes `hx-*` or any P0-31 attribute — the emitter stays sole author. The
selection overlay draws boxes positioned FROM the page and never mutates a
selected element's styles or bytes: a selection must not change the thing
being edited.

---

## 6. Session, identity, authorization — the six rulings

v1 MUST scope is as ruled (ruling 3 + sketch §8): local login, httpOnly SameSite session
cookie, CSRF token on every command post, actor stamping, `cap:` deny-by-default, query
scoping, emitter omit-by-default, journal audit. The six questions rule as follows.

### 6.1 Redaction semantics — Q1

**[P0-45] Three modes; OMIT is the default; disclosure is a command, not a mode.**

- **omit** (default): the field is never computed into the output — absent from wire
  payloads, projections, and exports alike. Nothing exists client-side to un-hide.
- **mask** (opt-in per field via `ux:cap … mode=mask`): a type-shaped masked token is
  emitted (presence disclosed, value not); the mask is derived server-side and is **never a
  transformation of the value in client space**. For discoverability cases ("a value exists
  here; request access").
- **disclose-on-request is not a redaction mode** — it is the composition of omit/mask with
  a separate command carrying its own `cap:` (and, where declared, step-up §6.6) that
  returns the value and **journals the disclosure**. Reading-past-a-lens is an audited act,
  not a rendering variant.

One ruling, all surfaces: the same evaluator answer drives the wire, agent tools, and the
emitter — a field masked on the web is masked in a tool result.

**[P0-46]** Field-capability claims key by (schema-address, CXPath) exactly like hints
(§2.1) and cascade the same way; their lineage carriage fails closed (§P0-7).

### 6.2 Uninvokable commands — Q2

**[P0-47] Default omit — not emitted, not CSS-hidden.** The `show=disabled` hint (§3.2) opts
a control into visible-but-disabled where discoverability is wanted; the rendered reason is
the hint's `reason=` text — **never** derived from the failed capability itself (capability
structure is not disclosed to principals who lack it). show-disabled is presentational only;
the wire refuses identically either way (the browser is never an enforcement point).

### 6.3 Session document shape — Q3

**[P0-48] The web session IS the shipped session module's session — extended, not
paralleled.** session.md already ships the load-bearing shape: the server-held `[session
id=… state=…]` value whose id doubles as the opaque cookie value (§2.8, N-SESSION-5 — the
cookie never carries a token), `HttpOnly; Secure; SameSite` defaults, the per-session
synchronizer `[csrf-token …]` (§2.9), states `attached | detached | expired` with
`CXER4804` on dead-session ops, the tenant-rooted session store (§9), and mirrored attach
(browser cookie + agent Bearer + DID peer on one session, each client's `via=` keying the
CSRF exemption). `[$session:principal]` is the actor the PEP reads. Phase 0 adds the pieces
the web login path needs, as extensions to that model:

- **Local login** (ruling 3's v1 scope) is a session-establishing kernel command below the
  feature layer — it mints the same `[session]` value through the cookie adapter; shipped
  expiry semantics key off the verified token `exp`, so local login defines the equivalent
  validity window at establishment.
- **TTL policy overlay:** sliding idle expiry under an absolute cap, evaluated alongside the
  shipped `expired` state. Proposed defaults: idle 24 h, absolute 30 d — policy values,
  tenant-overridable via the cascade (§2.3); the numbers are an owner letter (§9 Q-D).
- **Revocation:** `detach` = logged out everywhere, effective at next request; sessions are
  enumerable per actor over the session store ("show active sessions for X" is a query);
  revoke-all-for-actor is a command.
- **Concurrent sessions:** allowed and unbounded in v1 (mirrored attach already assumes
  multi-client); per-tenant limits are a policy hook, COULD tier.
- **No capability snapshot in the session.** Capabilities are evaluated live per command and
  stamped per journal record as capabilities-at-time; freezing them at login would make
  grant revocation ineffective for open sessions.
- **Fixation defense (new normative clause):** the session id — being the cookie value — is
  reminted on every privilege transition (login, step-up §6.6); the CSRF token is bound to
  the session id and rotates with it.
- **Auth-level field (new):** the session records `[auth method=local|oidc level=base|stepped-up
  stepped-at=<ts> …]` for §6.6; absent means `base`.

### 6.4 Feed visibility classes — Q4

**[P0-49] A visibility class is the equivalence class of sessions whose rendered fragment
bytes are provably identical**, and it is derived, not hand-declared per event:

- A feed's row policy and the field-capability claims over its row schema declare (and are
  purity-checked against) an **attribute footprint** — the set of actor attributes they may
  read.
- **Class key = (feed id, footprint attribute values for the session)**, assigned at
  subscribe time. Empty footprint → one class → true render-once-broadcast. Footprint
  = {region} → one render per region. Footprint containing the actor id → degenerates to
  per-session rendering, correctly and visibly.
- Events are rendered once per class with a live subscriber and broadcast to that class's
  sessions. Fragment addresses are class-invariant (§P0-8), so a class render targets the
  same DOM ids in every receiving session.
- A policy reading an attribute outside its declared footprint is a compile/registration
  refusal — the class model's soundness is the purity checker's theorem, not a convention.

This generalizes shipped precedent rather than inventing one: the hosted XAP stream's #647
privacy rule (lensed readouts broadcast the anonymous-actor **public subset** only; a lensed
client treats the event as a change signal and re-fetches under its own proof) is exactly
the two-class degenerate case — an empty-footprint public class broadcast, plus per-session
re-fetch for lensed content. The footprint model keeps that behavior as its floor and adds
the middle ground (per-region, per-rank classes) where render-once is still sound.

### 6.5 Claims-mapping vocabulary — Q5

**[P0-50]** The OIDC claims → capabilities mapping is a content-addressed document, cascade
position **tenant** (each tenant brings its own IdP and mapping; platform/vendor may ship
defaults). Shape:

```cx
# verify-skip — schematic block (deliberate ellipses / placeholders)
[claims-map issuer=<url>
  [rule [when [group "engineering"]]        ; equality/membership predicates ONLY
        [grant cap=<cap:…> scope=…]
        [attr  region= [claim /realm/region]]]
  …]
```

- Predicates are equality and membership over ID-token claim paths — deliberately
  non-Turing, pure, total, fixture-testable.
- Outputs are **grants** (capability, scope) and **actor attributes** (which feed row
  policies and visibility footprints, §6.4).
- **Monotone: rules only add.** No negative rules; revocation and exceptions live in the
  grant-document layer, keeping the mapping auditable by union. Deny-by-default does the
  rest.
- JIT provisioning: (issuer, subject) → actor identity document, minted on first login from
  the same mapping doc.
- Mapping changes are commands → can require propose/approve (separation of duties on authz
  changes). "Why did X have Y on date D" = mapping-doc address at D + IdP claims presented
  at D — both journaled.

### 6.6 Step-up × propose/commit — Q6

**[P0-51] Step-up attaches to acts, not to command lifecycles.** A command may declare an
auth level (machinery COULD-tier; the interaction is ruled now so nothing shipped precludes
it). The lifecycle's acts are the shipped ones — `cx:propose` mints the proposal,
`[$authz:approve]` mints the address-bound `[approval]` claim, `[$authz:commit]` re-verifies
fail-closed and executes. **Each act is evaluated against the declaring command's auth level
at its own time, on its own session**:

- the proposer's step-up does not carry to the approver, nor vice versa;
- **approving a step-up command itself requires fresh authentication by the approver** —
  approval is exercising authority over the sensitive command, not clerical assent;
- the auth-level check joins `commit`'s existing fail-closed re-verification chain (re-hash,
  tier signature, no `[propose-only]` in the basis, `cap:` re-resolution, precondition
  re-evaluation — the CXER4714–4716 family) as one more gate;
- every stamp records auth-level-at-time alongside actor/session/caps-at-time.

Step-up bumps the session's `auth` level with its own freshness TTL and remints the session
id (§6.3); it never mints a second session.

### 6.7 Actor-at-command-record (field evidence finding 4)

**[P0-52]** The journal design assumes **actor-at-command-record, never
actor-recovered-later** — and the mechanisms are shipped, so this ruling binds the web face
to them rather than inventing anything: journal appends take the `(actor, authority)`
attribution map and refuse anonymous appends (`CXER4609`); the actor rides the entry's hash
preimage; and the XAP host-auth stamping rule already states that on an admitted
`POST /intent` the committing actor is the channel's **session principal** — an absent
`author=` inherits it, a non-empty one must match byte-for-byte or the intent refuses.
**The web session boundary adopts that rule verbatim**, with `[$session:principal]` as the
principal source. Claimed author attributes in payloads are not attribution. (Confirms
ruling 3; the field estate is deliberately waiting on platform stamping rather than working
around it with claimed attributes — the remaining gap it names is the *feature layer* seeing
the proven principal, which arrives with actor stamping as ruled.)

---

## 7. Fixture and gate mapping

| Clause family | Fixture lane | Wave |
|---|---|---|
| Claim keying, composite form, precedence (§2.1) | pure-def fixtures + goldens | W1–W2 |
| Fragment addresses, DOM id derivation, keyed rows (§2.2) | rendered-fragment goldens | W1 |
| Emitter attribute subset (§5.1) | subset-list fixture (any attr off-list = red) | W1 |
| Escaping/CSP invariants (§5.2) | goldens + header fixtures | W1 |
| Partial-document command semantics (§4) | command fixtures incl. lensed-editor case | W2 |
| Redaction modes + placeholders (§6.1, §5.3) | lensed-projection goldens | W2–W3 |
| Swap invariants (§5.4) | browser-harness lane (scoped) | W3–W4 |
| Visibility classes (§6.4) | class-assignment fixtures + SSE fan-out test | W4 |
| Nested-schema gauntlet, override-cliff, Django-admin benchmark (R6) | acceptance suite | DP1/DP2 |
| Layout-command apply/refusals + inverse pairs (§4.1); edit-mode stamps (§5.7) | command fixtures + edit-mode goldens + reference-estate drive steps | W26 |

The lensed-editor fixture (a 7-of-12 projection edits; the 5 withheld elements survive) and
the project-and-diff fixture against a hand-written UI (offered by the field estate; see
§8) are the two highest-value early fixtures.

---

## 8. The #726 boundary

#726 (in-family reference XAP, M5 commerce) requires a "served-web HTMX client pattern
(server-rendered CX → hypermedia) as a separate client"; #787 W5 is a 2–3 route commerce
mini-surface. Same demo, two ways. **RULED (owner, 2026-08-17; Q-A): shared domain, both
clients, the diff is the fixture.** #726's commerce features (L1 definitions) are authored
once on shipped machinery with its web leg hand-authored (the rung-4/5 pattern demonstration
it was filed to be; its DoD's `cx xap init` template never depends on the PoC pack); W5 then
projects *the same features* as its demo surface, and the hand-written-vs-projected diff is
a DP1 review input — the reference comparison between the old and new approaches, and
exactly the "project this grammar and diff against its hand-written UI" fixture the
field-evidence estate offered, in-family. #726 is underway in a parallel session; W5 takes
its features as input when they land — the PoC does not block on it before W5.

---

## 9. Owner question register — ALL RULED (owner, 2026-08-17)

- **Q-A** — the #726 boundary → **shared domain, both clients, diff-as-fixture** (§8);
  #726 proceeds in its own session and doubles as the old-vs-new reference comparison.
- **Q-B** — DOM id derivation → **hash16 + `data-cx-frag`, collision = refusal** (§P0-11 as
  written).
- **Q-C** — initial hint set → **the five as listed** (§P0-21 as written).
- **Q-D** — session TTLs → **idle 24 h / absolute 30 d, tenant-overridable** (§6.3 as
  written).
- **Q-E** — un-carried `ux:cap` claims across `:split`/`:merge` → **whole-schema refusal
  until re-blessed** (§P0-7 as written).
- **Q-F** — `show=disabled` reason text → **never capability-derived, on any surface**
  (§6.2 as written).
- **Q-G** — claim-subject kinds → **E2 schema address / input-schema identity / qualified
  verb** (§P0-2 as written).
- **Q-H** — `[surface …]` head coexistence with the XAP readout element → **keep both;
  different planes** (§P0-24 as written).

---

# Part II — the storefront waves (W8 additions, 2026-08-18)

**Status of Part II:** drafted by the W8 session; the clauses are numbered
**[P0-53]** onward and follow Part I's convention — a clause marked `[P0-n]` is
normative once ruled. The open letters are in §16 and in `design/787/w8/DP2.md`.

**Why Part II exists.** W6 and W7 built a projected order-entry desk over a
three-noun commerce domain and the owner's verdict on the result was that it is
not a store: *"a lame experience — not a typical cart experience."* The
diagnosis recorded in `design/787/w8/README.md` is ~70% domain and ~30% UX, and
the useful residue is a list of things the vocabulary **cannot say**. Part II
says them. Nothing in Part I is withdrawn; §15 records the one cutover.

---

## 10. The storefront vocabulary

### 10.1 The admission rule, restated as a clause

**[P0-53] A member is admitted only when it passes the asymmetry test.** W5 stated
the test in prose and it has held twice: drill-down needed no member because
drill-down is navigation and the vocabulary already had navigation; filtering
needed one because a filter is a query and `[ux:form]` posts intents. As a
clause:

A candidate concept is admitted to the semantic vocabulary **only if both** hold:

1. **It carries semantics no existing member carries.** "The same thing with a
   different appearance" is a hint or a token, never a member.
2. **Both renderers can honor it natively** — neither has to simulate the other,
   and neither has to parse a concept private to the other. A member one
   renderer can only render as the literal word "[image]" is a member that
   renderer cannot honor.

A candidate that fails (1) becomes a hint value; a candidate that fails (2) is
refused outright and the design that wanted it is wrong. Every member below
carries the argument for its own admission; §16 letter (c) is the one candidate
that is being admitted over an objection and says so.

**[P0-98] The vocabulary is closed over attributes, not only over members.**
*(RULED — owner, 2026-08-18, audit letter 3a.)* The shared refusal gate
refuses an attribute no clause grants to the member carrying it
(`ux-unknown-attr`), exactly as it refuses an unknown member. The
renderer-private attributes already enumerated (`ux:region` `oob= ext=
subscribe= on=`; `ux:row` `oob=`; `ux:action` `target= swap= include=`;
`ux:form` `target= swap=`) remain the ruled exceptions. Ground, demonstrated
by the 2026-08-18 audit: `[ux:action disabled=true reason="…"]` passed the
gate and both renderers ignored it — an author who invents an attribute gets
no error and no rendering, which is the same silent-acceptance family as the
campaign's three language traps. Member closure without attribute closure is
half a rule.

### 10.2 Depiction

**[P0-54] `[ux:media]` — a depiction of the subject.**

```cx
[ux:media src="/static/art/fk-0119.svg" alt="Farrow 24 cm sauté pan, in graphite"
          kind=illustration tone=neutral]
```

- `alt=` is **required**; an undescribed depiction is a projection refusal, not a
  rendering with an empty attribute. A store without alt text is a store a
  blind customer cannot shop, and P0-95 makes that a spec property rather than a
  review comment.
- `kind=` ∈ `illustration | photo | glyph` — what *sort* of depiction, which is a
  semantic fact (a glyph is a symbol, a photo is evidence); size is not a member
  attribute and never was, because size is a token decision (P0-33).
- `src=` is a **served path**, never a data URI and never an external origin —
  the CSP posture (P0-33) is a property of the emitter, and a depiction is not
  an exception to it.

**What each renderer owes.**

| Renderer | Owes |
|---|---|
| web | an image element carrying `alt` verbatim; dimensions and object-fit from tokens, never inline `style=` |
| terminal | a framed block filled from the `tone` token's SGR, with `alt` as its caption inside the frame — **the depiction's meaning, rendered**, never the literal string `[image]` and never blank |

Admission: fails neither test. There is no member that means "a picture of this"
(`ux:field` means "a labelled value"), and the terminal honors it natively —
a framed, toned, captioned block is what a terminal has instead of an image,
which is why k9s is a legitimate quality bar and a screenshot is not.

Content normal form: `alt` and `src` are **content**; `kind` and `tone` are not
(they are the renderer's control-choice inputs, exactly like `kind=` on a field —
see W5's rule that asserting on `kind` would assert that two renderers make the
same widget choice).

### 10.3 Two-dimensional collections

**[P0-55] `[ux:grid]` — a collection of peers scanned in two dimensions.**

```cx
[ux:grid density=comfortable [ux:item …] [ux:item …] …]
```

A table's members are **rows of one shape compared field by field**; a grid's
members are **whole things compared as wholes**. That is a difference in what the
reader is doing, not in appearance, so it passes test (1). `density=` ∈
`comfortable | compact` is semantic; a **column count is never a member
attribute**, because a column count is a fact about a viewport and the
vocabulary has no viewport.

| Renderer | Owes |
|---|---|
| web | a grid container whose track sizing comes from tokens; item order is document order |
| terminal | measured multi-column card flow, columns derived from the live window width, collapsing to one column when the window is narrow — the same measurement discipline the table columns already use |

`view=grid` (a §3.2 hint value) and `[ux:grid]` are the same member reached two
ways: the hint chooses the projection, the element is what comes out. `view=` is
now `table | cards | grid`.

### 10.4 Acting from inside a collection

**[P0-56] An `[ux:action]` may sit inside an `[ux:item]` or `[ux:row]`, and carries
its parameters from that item.**

```cx
[ux:row key=FK-0119
  …
  [ux:action verb=add-to-cart label="Add to cart" affects="/cart/badge"
    [ux:param name=sku value="FK-0119"]
    [ux:param name=qty value="1"]]]
```

This is the gap W6 and W7 could not see past: **no intent was emittable from a
collection item.** Every intent in W1–W7 came from a form the surface placed
beside the collection, which is precisely why the result read as an order-entry
desk — a desk is what you get when the only way to act on a thing is to type its
name into a form somewhere else.

Four properties, each load-bearing:

- **Per-item identity.** The action's fragment address is the item's element path
  plus the action step, so N items produce N addressable actions. One shared
  control that "means" whichever row you clicked is not addressable and is
  therefore not emittable (P0-10's honesty rule reaching the write side).
- **Parameters are server-derived at projection time.** `[ux:param]` values are
  computed from the item being projected. They are **never read back out of the
  rendered document** — what the item was rendered with is what posts. This is
  P0-82 (no client-side state) at its sharpest: an item whose price changed
  between render and click posts the price it was rendered with, and the command
  layer refuses it, which is the correct outcome and the one a DOM read cannot
  produce.
- **A missing parameter is a projection refusal.** A `[ux:param]` whose value is
  absent on the item refuses the render. The alternative — posting an empty
  string — produces a command refusal that blames the customer for the
  projection's bug.
- **`affects=` may name a region outside the item.** Adding to a cart from a
  product card changes the cart badge, which is elsewhere on the page. That is
  what the patch algebra (P0-44) and P0-83 are for.

| Renderer | Owes |
|---|---|
| web | one real submit per item, posting to `/intent/<verb>` with the params as body fields and the CSRF token; `hx-target` derived from `affects=` |
| terminal | the action is a focus stop **within the focused item**; activating it posts the same body over the same wire |

### 10.5 Multi-step flows

**[P0-57] `[ux:steps]` / `[ux:step]` — an ordered flow whose position is a URL.**

```cx
[ux:steps name=checkout current=review
  [ux:step name=address  label="Address"  state=done    href="/checkout/address"]
  [ux:step name=shipping label="Shipping" state=done    href="/checkout/shipping"]
  [ux:step name=review   label="Review"   state=current href="/checkout/review"]
  [ux:step name=confirm  label="Confirm"  state=ahead]]
```

- `state=` ∈ `done | current | ahead`.
- **A `done` step MUST carry `href=`.** An earlier step you cannot go back to is
  refused at projection. This is the one place in Part II where a UX pattern
  (§13's editable earlier steps) is enforced by the *vocabulary* rather than by
  review, because it is the pattern most often lost and the loss is silent.
- An `ahead` step carries no `href=` — a flow position whose preconditions are
  unmet is not a place, and P0-84 says what happens if you type its URL anyway.
- `ux:steps` is a **projection of flow position, not a controller**. It does not
  advance anything; advancing is an intent, and the intent's answer is a new
  location.

| Renderer | Owes |
|---|---|
| web | an ordered list with the current step marked `aria-current="step"`; done steps are links, ahead steps are plain text |
| terminal | a single header line — `Address ✓ › Shipping ✓ › **Review** › Confirm` — with done steps as focus stops |

**[P0-58] `[ux:quantity]` — a bounded numeric control.** *(Named
`ux:stepper` at drafting; renamed by the W20 cutover — see §15.)*

```cx
[ux:quantity name=qty value=2 min=0 max=12 step=1 verb=set-quantity
             label="Quantity" affects="/cart/lines"
  [ux:param name=sku value="FK-0119"]]
```

- Three affordances over one value: decrement, the value, increment. Each
  activation is a **real intent** (`verb=`), not a client-side counter — P0-82.
- **At a bound, the affordance is disabled, never absent.** A control that
  disappears at `min` moves everything beside it, and a geometry that changes
  under the cursor is a defect the terminal face makes obvious.
- `min=0` is how "remove" is spelled when removal is a quantity change; an
  explicit remove action is a separate `[ux:action]` with `confirm=` per P0-67.

| Renderer | Owes |
|---|---|
| web | a group of three real submits sharing one accessible name (`label`), the value in a live-updating text node, `aria-label` on each affordance naming *what* it steps |
| terminal | the value is a focus stop; `-`/`+` (and `←`/`→`) step it; the bound is announced in the status line rather than by a silent no-op |

`ux:steps` and the member above are **unrelated members** whose drafted names
collided by one letter. §16 letter (d) offered the rename and W20 executed it
(§15): `quantity` states what the member is *for*; `stepper` stated how it
*looks*, which P0-53 says is the wrong axis for a member name.

### 10.6 Location, paging, narrowing, ordering

**[P0-59] `[ux:breadcrumb]` / `[ux:crumb]` — the location trail.**

```cx
[ux:breadcrumb
  [ux:crumb label="All departments" href="/c"]
  [ux:crumb label="Kitchen"         href="/c/kitchen"]
  [ux:crumb label="Cookware"        href="/c/kitchen/cookware"]
  [ux:crumb label="Sauté pans"      current=true]]
```

The final crumb is the current location and carries **no `href=`** — a link to
where you already are is a lie about what activating it does. Web: an ordered
list in a landmark with `aria-current="page"` on the last crumb. Terminal: one
line above the panel, earlier crumbs as focus stops.

**[P0-60] `[ux:pager]` — a window over an *ordered* collection.**

```cx
[ux:pager page=3 pages=42 total=1004
          prev-href="/c/kitchen?p=2" next-href="/c/kitchen?p=4"
  [ux:page-link n=1 href="/c/kitchen?p=1"]
  [ux:page-link n=2 href="/c/kitchen?p=2"]
  [ux:page-link n=3 href="/c/kitchen?p=3" current=true]
  …]
```

- **Every page is a URL** (P0-78), including page 1, which is the canonical URL of
  the unpaged state and must be the same document.
- **A pager over a collection with no declared order is a refusal.** Paging an
  unordered set is not a window, it is a lottery: the same request twice may
  return overlapping pages and omit rows entirely, and no client can detect it.
  This is P0-10's keying honesty applied to sequence rather than identity.
- `total=` is the honest count of the whole collection, not of the page. A pager
  that cannot state the total says `total=` absent rather than guessing; the
  renderers then omit the count instead of printing a number nobody computed.

**[P0-61] `[ux:facet]` / `[ux:facet-value]` — a constrained narrowing, with counts.**

```cx
[ux:facet name=brand label="Brand"
  [ux:facet-value value="farrow"  label="Farrow Kitchen" count=128 href="/c/kitchen?brand=farrow"]
  [ux:facet-value value="coldpeak" label="Coldpeak"      count=41  href="/c/kitchen?brand=coldpeak" selected=true]]
```

A facet is not a filter with a menu. **The counts are the difference**: a filter
tells you nothing until you use it; a facet tells you what narrowing is
available *and how much of the collection each one leaves* before you commit to
it. That is a distinct semantic — it is the collection describing itself — so it
passes test (1), and both renderers can render a labelled count natively, so it
passes test (2).

- Selecting and deselecting are **both** navigations (GET, safe, idempotent).
  `selected=true` values carry the href that *removes* them.
- **A facet value with `count=0` is emitted only when it is selected.** Otherwise
  it is omitted: a narrowing that leads nowhere is not an affordance, it is a
  trap with a label on it. A selected zero-count value must stay, because it is
  the only way back out of the empty state you are looking at.
- Facet state is entirely in the URL, so a faceted result is deep-linkable and
  shareable, which is P0-78 and is also the whole reason facets exist in a store.

**[P0-62] `[ux:sort]` / `[ux:sort-option]` — an ordering choice.** (W7's deferred
member, landing in both faces at once per the parity ruling.)

```cx
[ux:sort name=sort label="Sort by"
  [ux:sort-option value=relevance  label="Relevance"      href="/c/kitchen"            selected=true]
  [ux:sort-option value=price-asc  label="Price, low → high" href="/c/kitchen?sort=price-asc"]]
```

Ordering, like filtering and faceting, is a **query**: no effect, nothing
committed, nothing journaled. It cannot ride `[ux:form]` for the same reason
`[ux:filter]` could not. It pairs with P0-60: a sorted collection is an ordered
one, so choosing a sort is what makes paging honest.

### 10.7 Secondary regions and announcements

**[P0-63] `[ux:aside]` — a secondary, dismissible region whose open state is a URL.**

```cx
[ux:aside name=cart label="Your basket" open=true dismiss-href="/c/kitchen"
  …]
```

- `label=` required (it names a landmark); `dismiss-href=` **required when
  `open=true`** — a region you can open and cannot close is a trap.
- **It is not a modal.** The primary region stays reachable and interactive. The
  vocabulary has no member that traps focus, deliberately: a modal is the
  affordance that most often breaks the keyboard face, and the store patterns
  in §13 need none.
- Open state is in the URL, so a shared link to an open basket opens the basket,
  and the no-kernel path (P0-81) is a plain page.

| Renderer | Owes |
|---|---|
| web | a complementary landmark labelled by `label`; on open, focus moves to its first focusable; on dismiss, focus returns to the control that opened it (P0-92) |
| terminal | a side pane sized from the live window; `esc` activates `dismiss-href` |

**[P0-64] `[ux:status]` — an announcement of what just changed.**

```cx
[ux:status tone=ok "Added — Farrow 24 cm sauté pan. Basket: 3 items, $184.00."]
```

Its content is **a sentence about what happened**, never a code and never a
count on its own. `tone=danger` raises the urgency (assertive) — nothing else
does.

| Renderer | Owes |
|---|---|
| web | `role="status"` + `aria-live="polite"` (at `tone=danger`: `role="alert"` + `aria-live="assertive"`), present in the document from first paint so the first announcement is heard |
| terminal | the status line, which the shell already owns |

P0-93 makes there be exactly one per page and makes every state change write to
it.

### 10.8 Formatting

**[P0-65] `format=money` — money never becomes a float.** The rendered form takes
its currency and minor-unit precision from the value's declared money type and
its grouping and symbol placement from `locale.md`. Two obligations:

- **Aggregation rides the decimal carrier.** `[$sum]` over decimals routes through
  a double and returns `4.6e1` where `[+]` returns `46.00`; W6 hit this and
  patched it at one call site. It is a clause because a money total in
  scientific notation is not a formatting bug, it is a **carrier** bug, and the
  same discipline already governs controls (a `decimal` field projects a text
  input, not a number input, for exactly this reason).
- **Money is never a bare number in the semantic tree.** The tree carries the
  decimal carrier plus the currency; the renderers format. A tree that carries
  `"$46.00"` has done the renderer's job in the wrong place and cannot be
  re-localized.

**[P0-66] `format=rating` — the asymmetry test, applied and passed the other way.**
A rating is a scalar with a conventional depiction, so it is a **hint value, not
a member**. Web: a token-styled meter *with the numeric value in text beside it*
— a run of star glyphs alone is a picture of a number, and a picture of a number
is not a value. Terminal: a filled/unfilled block run plus the number. The
review count, when present, rides the same field as a secondary value.

**[P0-99] An unavailable act says so, and says why — when the why is data.**
*(RULED — owner, 2026-08-18, audit letter 2a.)* `[ux:action]` admits
`available=false`, which **requires** `reason=` — a sentence about what makes
the act unavailable *right now* (`reason="Two review tasks are still open"`,
`reason="Out of stock"`). Both renderers keep the control's place and its
label, render it inert, and carry the reason (web: a disabled real control
with the reason text programmatically associated; terminal: a focus stop that
does not activate and announces the reason in the status line — the P0-58
bound behavior, generalized). The reason-class split, which preserves P0-47
unchanged:

- **data/precondition-derived** unavailability (state of the world: an empty
  branch, an open task, an exhausted stock) is *disclosed* — this clause;
- **capability-derived** unavailability (the actor lacks authority) stays
  P0-47: default omit, `show=disabled` hint with static `reason=` text only,
  never derived from the failed capability.

An `available=false` without `reason=` is a projection refusal. Admission:
passes (1) — no member could say "this act exists and is currently blocked,
because X"; the 2026-08-18 audit found both Rules-Driven and Approval flows
unwritable without it — and passes (2) natively in both faces per P0-58's
precedent. The store's out-of-stock buy control (P0-91) is the live consumer.

**[P0-103] `prominence=` on `[ux:action]` — a semantic emphasis level.**
*(RULED — owner, 2026-08-18, DP4 letter (a).)* `prominence=` ∈
`normal | primary`, default `normal`: which act is the subject's principal
act, a fact about the content. Tokens decide what emphasis looks like; a
face may not drop it (the projection emits it for its primary control, and a
droppable hint on the projection's own output is the silent family P0-98
closed).

**[P0-67] Destructive actions confirm by URL, never by dialog.** `hx-confirm` stays
off the pinned subset (P0-31) and is not re-litigated. An `[ux:action]`
declaring `confirm='…'` carries `confirm-href=`; activating it **navigates** to
a confirmation view (GET, safe) that restates what is about to happen and
carries the real POST. Consequences, all of them wanted: the confirmation is a
place with a URL; the two renderers behave identically without either
simulating a dialog; and the flow degrades unchanged with no kernel.

### 10.9 Grouping peers

**[P0-101] `[ux:panel]` — a named group of peer blocks.**
*(RULED — owner, 2026-08-18, DP4 letter (g), admitting the W19 R1 draft.)*

```cx
[ux:panel name=narrow label="Narrow"
  [ux:facet …] [ux:facet …]]
```

- `name=` is **required** and is the panel's identity within its region (the
  address step, exactly as `ux:group` steps by name). `label=` is the
  reader-facing title and defaults from the name.
- A panel carries **no appearance**: not an order, not a width, not a side.
  Where a panel *goes* is each renderer's own geometry — what the member
  states is only that its children are one coherent group of peers and the
  name of that group.
- Content normal form: `c:panel name= label=` with the children as content —
  a face that dropped the grouping would flatten a case file's "parties" and
  "timeline" into one undifferentiated run, which is content loss, not a
  style choice.
- The gate: `ux-input-no-name` when unnamed (the existing rule); a panel
  inside a panel is **refused** (`ux-panel-nested`) — peers of peers is a
  hierarchy, and a hierarchy is what regions and cards already are.

| Renderer | Owes |
|---|---|
| web | a `section` landmark carrying the label as its accessible name; rail/track assignment by token, never a selector guess over the panel's children |
| terminal | a framed box per panel, titled by `label=`, in document order — classification tables gone |
| serial/voice | the label announced once, before the group's members |

Admission: passes (1) — "these blocks are peers, and the group has a name"
is a statement about the content's structure, the same argument that
admitted `ux:group` for writes; a region is scope (one feature instance), a
card is one thing, and neither says "these three blocks are the narrowing
controls". Before this member, both renderers materialized that statement by
guessing — the terminal with a hard-coded classification table, the web with
a child-selector — two places the truth lived, and the case-file shape (two
tables that mean different things) breaks classification-by-element-name
outright. Passes (2) — every face renders it natively (a box, a landmark, an
announcement); none simulates another.

---

## 11. Session-scoped state — the architectural ruling

The gap, stated exactly: **the journal fold is service-wide and a cart belongs
to one visitor. The projection has no notion of whose state a fold is.** Nothing
in Part I answers this, because everything in Part I is either service-wide
(the order book) or per-actor-by-authorization (redaction), and a cart is
neither — it is per-*visitor*, and a visitor has not authenticated.

### 11.1 Whose

**[P0-68] A visitor is a session; state follows authority, and authority is per
session.** An unauthenticated shopper attaches at the deployment's **anonymous
floor principal** (`xap_identity_model.md` §4.7 — the principal you get when you
prove nothing, already ruled and already shipped as a policy knob). No second
identity concept is minted for shoppers.

The load-bearing precedent is **N-IDENT-4**: *authority compiles per session*,
and two concurrent sessions of one principal MAY hold different authority bases.
Authority is already per session, not per principal. **State follows authority**
— that is the whole ruling in one line, and it is why the alternative in
P0-77(iv) is not merely inconvenient but incoherent.

**[P0-76] Guest attach is a session-establishing act, the same shape as local
login (P0-48).** It mints the same `[session]` value at the anonymous floor
through the same cookie adapter, with the same `HttpOnly; Secure; SameSite`
posture and the same per-session CSRF synchronizer. It is **not** a parallel
session model, and a surface that mints its own visitor cookie beside the
session module is in violation of this clause.

*Known gap, stated rather than worked around:* the shipped `session` module's
three attach transports (`attach` / `attach-did` / `attach-xsp`) each require a
proof, and a guest attach has none to require — which is the point, since the
anonymous floor is exactly what the identity model calls the principal you get
when you prove nothing. W11 raises the gap against `session` and consumes
whatever lands; it does not mint a second cookie to route around it.

`SameSite` is **`Lax`, not `Strict`**: a customer following an emailed or shared
product link must arrive holding the basket they left. Strict discards it, and
the discard is silent.

### 11.2 Where

**[P0-69] Session-scoped state is a journal STREAM — not a filter, not a second
store, and not a mutable bag.** `journal.md` §2.1.1 already defines exactly the
thing needed: *"a **stream** is an aggregate: a `string` routing key naming a unit
of contention and ordering (typically one principal, entity, or workspace)."* A
basket is an aggregate. Nothing is invented here; a shipped mechanism is being
named as the answer.

- The basket of visitor *V* is the stream **`cart:<visitor-key>`**.
- Per-stream dense `seq`, per-stream hash chain, per-stream tamper-evidence.
- Appends to different baskets **never contend** — two shoppers are two streams
  and commit in parallel, which is also why this scales past the demo.
- The read is `[$journal:fold … stream]` — O(one basket), not a scan of every
  event the service has ever recorded filtered down to yours.
- Service-wide state stays what §2.1.1 says it is: the order-independent
  composition of per-stream folds.

**[P0-70] The visitor key is DERIVED and non-reversible; the session id never
lands in a durable record.**

```
visitor-key = first 32 lowercase hex of sha2-256( deployment-secret ‖ session-id )
```

The session id **is the cookie value** (N-SESSION-5 — the cookie never carries a
token, it carries the id). A journal is durable, exportable, and frequently
shipped to an analyst; a stream key is part of every entry's hashed preimage.
Writing the session id into a stream key therefore writes **live bearer
material into the permanent audit record**, where it survives logout and
outlives the session it authenticates. The salt makes the derivation
non-invertible even against an attacker holding the journal and a candidate id
list.

This is the same discipline as P0-11 (the DOM id is a derived rendering of the
fragment address, never a second identity): a derived, one-way spelling of a
key, defined once, with the readable original deliberately not carried.

**[P0-71] Cross-stream effects are choreographed, in the recoverable order.** The
journal gives per-stream atomicity only and spans no commit across streams
(§2.1.1, explicitly). Checkout touches two aggregates, so its order is ruled:

1. append the order into the `orders` stream;
2. append `[cart-emptied …]` into `cart:<visitor-key>`.

A crash between them leaves **a placed order and a stale basket** — visible to
the customer, idempotently repairable (the basket's next fold reconciles against
the order it names), and never the reverse. The reverse ordering loses the
order and keeps nothing to reconstruct it from.

### 11.3 What the projection learns

**[P0-72] The projection learns nothing.** `[$ux:…]` takes rows and definitions; it
has never taken a journal and does not start now. What gains the concept is the
**render-input manifest** (P0-15), which grows one entry:

```cx
[render-inputs … [scope stream="cart:9f2c…"] …]
```

so *"which UI did visitor V see at time T"* stays exactly answerable rather than
archaeological — the manifest was always the audit loop's closure and a
per-visitor surface would have opened a hole in it.

**[P0-73] Fragment addresses stay scope-free, and a basket is a visibility class of
one.** P0-8 holds unchanged: identity excludes the actor, so two visitors with
identical baskets render **identical bytes at identical addresses**. It follows
from P0-49 without amendment that a basket feed's footprint contains the visitor
key and therefore degenerates to per-session rendering — *"correctly and
visibly"*, as §6.4 already puts it. The model needed no new case; it needed to
be pointed at this one.

**[P0-74] Adoption on login is a journaled act, never a silent rewrite.** The
session id remints on every privilege transition (P0-48's fixation defense), so
the visitor key changes with it. The basket is carried forward by an explicit
append into the **new** stream:

```cx
[cart-adopted from="cart:9f2c…" to="cart:be07…" lines=3]
```

The old stream is left intact and auditable. *"Why does this basket belong to
this account"* has an answer, and the answer is an entry with an actor on it
(P0-52), not an inference.

**[P0-75] The scope is never client-supplied.** The visitor key is derived
server-side from `[$session:of $request]`. A `scope=` or `visitor=` in a request
payload is not attribution — P0-52 verbatim, and the same failure mode: a
claimed key in a payload is a request to read someone else's basket.

### 11.4 What was rejected, and why

### 11.5 The general rule this section is a case of

**[P0-100] State lives in the journal stream of its owning aggregate.**
*(RULED — owner, 2026-08-18, audit letter 4a.)* journal.md §2.1.1 keys a
stream by "one principal, entity, or workspace"; §11 is the **session** case
of that rule (`cart:<visitor-key>` — the aggregate is the visitor's session),
not a special mechanism. A long-running flow whose state outlives a session
and admits more than one actor — a process instance, a case file, an approval
subject — keys its stream by the **entity** (`claim:C-4411`,
`application:<id>`), with the same per-stream ordering, hash chain, and
choreography discipline (P0-71) unchanged, and P0-72 unchanged: the projection
learns nothing; the render-input manifest names the stream. Service-wide state
remains the composition of per-stream folds. Nothing in §11.1–§11.4 is
amended; this clause names the rule they instantiate so the next flow type
does not have to rediscover it.

**[P0-77]** Five alternatives were considered and rejected. They are recorded
because the next person will propose at least two of them.

**(i) The basket is client-side state (a cookie payload, or web storage).**
Rejected: it violates P0-82 outright, it makes the basket invisible to the
terminal face and to every non-browser client, and it puts prices and quantities
somewhere the server cannot validate without re-deriving everything the client
sent. The failure mode is not theoretical — it is the classic tampered-cart
bug, and the architecture that permits it is the one that stores the cart where
the customer can edit it.

**(ii) A journal per session (`mem://cart/<visitor-key>`).** Rejected: N journals
means N hash chains with no composition rule, no cross-basket query (*"how many
open baskets"* becomes a directory walk), and — decisively — checkout would span
two **journals** rather than two streams, so P0-71's choreography would have no
shared tenant, no shared retention policy, and no snapshot that anchors both.
Streams give the partition without giving up the tenant.

**(iii) A mutable server-side session bag (`session.state`).** Rejected: this is
precisely the un-journaled mutable state the whole design refuses. It has no
attribution, no history, and no answer to *"what was in the basket at 14:02"* —
which is not a hypothetical question, it is the first question asked about any
disputed order. It would also be the only place in the system where state
changes without an entry, which is the kind of exception that quietly becomes
the rule.

**(iv) Scope by principal rather than by session.** Rejected as **incoherent**,
not merely inferior: every unauthenticated visitor shares the anonymous floor
principal, so all baskets would be one basket. This is the exact bug that makes
the ruling necessary, and N-IDENT-4 already points the other way.

**(v) The basket is a proposal (`cx:propose`), committed at checkout.** The
strongest rejected alternative, and worth recording in full because it is
genuinely attractive: propose/commit is shipped machinery, a basket *is* a
proposed order, and checkout *is* a commit. It is rejected for v1 on two
grounds. First, a proposal is **address-bound and immutable** — its Tier-1
address is what an approval binds (P0-19) — so every quantity change mints a new
proposal and the basket's identity churns once per keystroke, which breaks the
one property a basket must have. Second, the approval machinery answers *"who
may approve this"*, and that is the wrong question for *"did you change your
mind about the socks"*; borrowing it would put a separation-of-duties concept in
the path of a shopper. **Revisit if propose gains a revise verb** that preserves
proposal identity across amendment — at which point (v) is probably right and
this clause should be reopened.

---

## 12. Hypermedia design patterns

Normative for the projection and for every surface built on it. These are
stated as obligations rather than as advice because each one has already been
violated at least once in this campaign or in the field estate that seeded it.

**[P0-78] Every meaningful state has a URL, and it is deep-linkable.** Enumerated
for the store, so the obligation is checkable rather than aspirational: a
department, a category, a facet selection, a sort, a page, a search, a product,
a chosen variant, an open basket, each checkout step, a placed order, an order
in history, a return. A state reachable only by performing a sequence of actions
is a defect; W13's drive harness enters each of these **cold**, by URL, which is
what makes this clause a fixture rather than a paragraph.

**[P0-79] GET is safe and idempotent; every state change is a POST.** No GET
mutates — not "add to cart" as a link, not "remove" as a link, not a logout
link. The pinned subset already bars non-POST write verbs (P0-31); this clause
bars the other direction, a mutation hiding behind a safe method.

**[P0-80] A state change answers with the affected fragments — or with a location.**
Two shapes, and which applies is determined by the request, not by the handler's
preference:

- **Fragment carriage declared** (the kernel is driving): the response is the
  target fragment plus out-of-band updates for every other fragment whose
  content the change altered — and *nothing else*. Not a whole page; not a
  redirect that discards what was just computed.
- **No fragment carriage** (the no-kernel path, P0-81): the response is
  `303 See Other` to the affected state's URL, so the browser lands on a real
  place and a reload does not re-post.

Stating both is deliberate. A design that only rules the first breaks
degradation; one that only rules the second throws away the fragment the server
already rendered. P0-42 is unchanged and applies to the first shape: an empty
or non-200 fragment response is a **failed swap**, surfaced visibly.

**[P0-81] The MPA shape degrades rather than dies.** With the kernel absent, every
control still works: forms carry real `action=` and `method="post"`, links carry
real `href=`, and the same URLs serve the same states. What is lost is
smoothness — full page loads instead of fragment swaps — and nothing else. The
fixture is a **no-kernel lane**: render every route with the asset manifest
empty and assert that every control's target resolves to a served route and
every form carries a method and an action.

**[P0-82] No client-side state the server cannot see.** W6 discovered this the
hard way and solved it in one place; it is a clause so that the next place is
not a new decision. A count, a next index, an open/closed flag, a selected
facet, a chosen sort, a page number, a quantity: each is either **in the URL**
or **derived server-side from what was posted**. The client holds nothing the
server cannot reconstruct from the request, which is what makes a stale tab
harmless and a shared link honest.

**[P0-83] Out-of-band updates ride the existing patch algebra.** The basket badge
is a `update` operation over the badge's **element path** (P0-44), lowered by
each renderer for itself — not a bespoke swap, not a second mechanism, and not a
renderer-private selector in the semantic tree (that is the mistake W5 spent a
wave undoing). P0-37's one-painter-per-region is unchanged.

**[P0-84] Deep links are cold-start correct, and unmet preconditions redirect
honestly.** Entering any URL directly renders the same state that navigating to
it produces — facets, page, sort, open basket, checkout step, all of it. A
location whose precondition is unmet (a checkout step with an empty basket, a
confirmation for an order that does not exist) answers `303` to the nearest
satisfiable location **with a `ux:status` that says why**. Never a blank page,
never a 200 rendering an impossible state, and never a silent bounce to the
home page.

---

## 13. Store UX patterns

Normative for the surface. Part I ruled how a projection behaves; these rule
what a *store* must be, because W6/W7 proved that a correct projection of an
underspecified surface is an underspecified surface, faithfully rendered.

**[P0-85] Departments, categories, and facets are the way in.** A persistent
department nav; a category page that states what it holds and how many;
facets over the attributes that actually vary within that category (a facet
that is constant across the whole result set is noise and is not emitted).

**[P0-86] The product grid sells.** Every card carries: a depiction, the product
name, its brand, its price as money, its rating, and **a working add-to-cart**.
A card you cannot buy from is a catalogue entry, not a product card — and a
catalogue is what W6 built. Out-of-stock cards keep their place and swap the buy
control for the honest state (P0-91), rather than vanishing.

**[P0-87] Product detail carries variants, and a variant is a URL.** A variant
choice changes which SKU you are looking at, so it changes the location — not a
hidden field, not a client-side swap of a price label. Detail also carries the
full attribute set, the depiction at a larger size, the delivery promise, and
reviews.

**[P0-88] The basket is present, persistent, and honest.** A badge in the header
that is correct on every page; an `[ux:aside]` basket with a line per item,
a `[ux:quantity]` per line, a running subtotal that changes when a quantity
changes, and a remove that confirms (P0-67). It survives navigation because it
is server state (§11), not because a script kept it. Its empty state offers a
way out — a department, not an apology.

**[P0-89] Checkout is visible steps, and earlier steps are editable.** Address →
shipping → review → confirm, as `[ux:steps]`, each a URL, each earlier step
reachable and editable (P0-57 enforces the href). Review restates **everything**
— items, quantities, prices, address, shipping method, total — before the commit,
because the commit is the point of no return and the customer is entitled to see
what they are committing.

**[P0-90] The order lifecycle is visible after the sale.** A confirmation naming
the order id, what was bought, what it cost, and where it is going; an order
history; per-order detail; cancel and return as commands with their own
confirmation views (P0-67) and their own refusals when they are not permitted.

**[P0-91] Honest states, all of them specified.** Empty search, empty category,
empty basket, out of stock, back-ordered with a date, a refused command, a
failed swap. Each says **what happened** and **what to do next**. None invents
optimism, and none is a blank region. Out-of-stock is a state of the *buy
control*, never a hidden product: hiding it means a customer who searched for it
by name concludes the store does not sell it.

---

## 14. Accessibility

Spec, not polish. Each clause names the renderer obligation, and the terminal
face is repeatedly the cheapest fixture for it.

**[P0-92] Focus is managed across every swap.** After a swap, focus lands
deterministically:

| The swap was | Focus goes to |
|---|---|
| caused by a control that survives | that control |
| a refusal | the first field carrying an error |
| a newly-opened region (`[ux:aside]`) | the region's first focusable |
| a region dismissed | the control that opened it |
| a new region replacing the caller | the region's first focusable |

Never the document body. P0-39 (morph, don't replace, with `ignoreActiveValue`)
is what makes "that control" survivable; this clause is what happens when it
does not.

**[P0-93] Exactly one `[ux:status]` per page, present from first paint, and every
state change writes to it.** A basket change, a refusal, a step transition, a
facet narrowing that changed the result count: each writes a sentence. Present
from first paint matters — a live region inserted at the same moment as its
first message is not announced by most assistive technology, which is a defect
that testing with a screen reader finds and testing without one never does.

**[P0-94] Full keyboard reachability, and the terminal face is the proof.** Every
action, facet value, page link, crumb, variant, quantity affordance, and dismiss
is reachable and activatable from the keyboard alone. The focus ring is a token
and is never suppressed. **The terminal renderer is the fixture**: a face with
no pointer cannot hide an unreachable control, so `ux-tui`'s focus ring
enumerating N stops on a route where the web face offers N affordances is a
mechanical, re-runnable keyboard-reachability test — one the web face cannot
fake and no human has to perform.

**[P0-95] Depictions are described.** P0-54's required `alt=`, plus: decorative art
carries `alt=""` **explicitly**, so that "described as decorative" and "nobody
wrote the alt text" are distinguishable states rather than the same missing
attribute.

**[P0-96] Reading order is document order.** No member reorders visually without
reordering semantically, and the emitter never emits a CSS ordering that
diverges from tree order. This is cheap to hold now and impossible to retrofit;
it is also what keeps the two renderers' content normal forms comparable, since
the terminal renderer has only document order.

---

## 15. The cutovers

**[P0-97] `format=currency` is renamed `format=money`; there is no alias.** P0-21's
initial hint set listed `currency`. Per the standing no-dual-accept rule, the
value cuts over rather than gaining a synonym: `currency` names a *field* (which
currency is this?), `money` names a *quantity* (this is an amount of money), and
the hint is about the quantity. `format=currency` is refused after the cutover
with a message naming the replacement. The affected artifacts are `hints.cx` and
the W1 goldens, both of which this campaign rewrites anyway.

**[P0-102] `[ux:stepper]` is renamed `[ux:quantity]`; there is no alias.**
DP2 letter (d)'s recommendation, executed in W20 under the standing
no-dual-accept rule. The name collided with `ux:steps` by one letter — both
appear on the same checkout page — and named the control's look rather than
its meaning. The normal form follows (`c:quantity`), both renderers follow
(`t:quantity`, `ux-quantity`), and `ux:stepper` refuses after the cutover as
any unknown member does (`ux-unknown-element`, P0-20/P0-98).

Everything else in Part I stands unamended.

---

## 16. DP2 — the open letters

Recorded here and expanded with trade-offs in `design/787/w8/DP2.md`. Each is
lettered; each carries the W8 session's recommendation, and each recommendation
is what the implementation waves proceed under until ruled otherwise.

- **(a)** the domain instantiation — RECOMMEND: as built (§DP2.1)
- **(b)** the session-state ruling — RECOMMEND: streams (P0-69), (v) recorded
- **(c)** `[ux:aside]` admission over the "it is presentation" objection — RECOMMEND: admit
- **(d)** `ux:steps` / `ux:stepper` name collision — RECOMMEND: rename the numeric one
- **(e)** facets: server-computed counts vs. omitted counts at scale — RECOMMEND: computed
- **(f)** `[ux:param]` value trust window — RECOMMEND: refuse on drift
- **(g)** guest-attach gap in the shipped `session` module — RECOMMEND: file and consume
- **(h)** where Part II lands when #832 rules the spec directory — RECOMMEND: with Part I

---

# §17 Implementation and conformance (graduation addition, 2026-08-20)

The one section added at promotion; everything above is the ruled draft text
unamended.

## 17.1 Where the capability lives

| Piece | Home | Tier |
|---|---|---|
| Semantic core — vocabulary, addressing, validation, projections, patch algebra | `x/ux.cx` | x-tier (bundled + gated in-tree; exempt from the frozen-`std` byte-compatible-reimpl promise until DP1 passes — the module header states this) |
| Web face — HTML/htmx lowering per §5 | `x/ux-web.cx` | x-tier |
| Terminal face — TUI lowering | `x/ux-tui.cx` | x-tier |
| Conformance lane | `conformance/stdlib/ux.cxd` | fixture corpus |
| Reference surface (all 14 act verbs, both faces, six instruments) | `spec/03-approved/xap/demos/oriel/` | promoted reference estate (#869); private to this repo per ruling RW-CUT.2 |

The semantic core imports no markup library of any kind; a renderer-private
concept cannot enter the vocabulary without crossing a module boundary
(the x/ux.cx module header records why this split is the only enforcement
that holds).

## 17.2 The pinned member vocabulary

The closed member set enforced by the shared refusal gate (`ux-unknown-element`,
[P0-20]/[P0-53]; attribute closure `ux-unknown-attr`, [P0-98]). Additions are
individual owner rulings under the [P0-53] asymmetry test — this table is the
registry the gate implements (`vocabulary` in `x/ux.cx`), reproduced so the
spec and the gate can be diffed:

| Family | Members |
|---|---|
| Regions and grouping | `ux:region` · `ux:card` · `ux:panel` · `ux:aside` · `ux:group` |
| Text and values | `ux:heading` · `ux:text` · `ux:field` · `ux:badge` · `ux:error` · `ux:notice` · `ux:status` |
| Collections | `ux:list` · `ux:item` · `ux:table` · `ux:columns` · `ux:column` · `ux:rows` · `ux:row` · `ux:cell` · `ux:grid` |
| Navigation | `ux:nav` · `ux:nav-item` · `ux:link` · `ux:breadcrumb` · `ux:crumb` · `ux:pager` · `ux:page-link` |
| Queries (safe, idempotent) | `ux:filter` · `ux:facet` · `ux:facet-value` · `ux:sort` · `ux:sort-option` |
| Writes (intents) | `ux:form` · `ux:input` · `ux:hidden` · `ux:select` · `ux:option` · `ux:submit` · `ux:action` · `ux:param` · `ux:quantity` |
| Flows | `ux:steps` · `ux:step` |
| Depiction | `ux:media` |

Retired members refuse by name with the replacement stated: `ux:stepper` →
`ux:quantity` ([P0-102]); the hint value `format=currency` → `format=money`
([P0-97]). No aliases, per the standing no-dual-accept rule.

## 17.3 Conformance obligations

The clause-family → fixture-lane mapping of §7 is implemented by
`conformance/stdlib/ux.cxd` (projection, addressing, refusal-gate, patch
algebra, redaction and no-kernel lanes) plus the reference surface's six
instruments (drive, keys, voice, nokernel, bench, diff) as its CI lane. The
keyboard-reachability theorem of [P0-94] — the terminal face as the proof —
is instrumented there, not sampled by review.

---

# §18 The studio — the editing model (2026-08-20, RULED: DS-11)

The clauses above rule the studio's *vocabulary* ([P0-105]…[P0-108]), its
*emission surface* ([P0-109]/[P0-110]) and its *editable surface*
([P0-111]…[P0-113]). This section states the model those clauses compose into
— what a studio edit IS, where it lives, how it reaches many clients, and
which parts are built versus ruled-and-pending. It exists because the model
was being carried in design letters and conversation, which is not where a
contract belongs.

## 18.1 Three planes, three documents

**[P0-114] Everything a studio edits is one of exactly three planes, and each
plane is a document — never code, never markup.**

| Plane | What it decides | Document | Commands |
|---|---|---|---|
| **Arrangement** | which components are placed, in what order, nesting, width | an `[ux:layout]` base document + its journaled command stream | `ux:move` · `ux:wrap` · `ux:place` · `ux:remove` |
| **Presentation & content** | a placed element's variants, hints, and words | the same layout document (hint and param children) | `ux:set-hint` · `ux:set-param` |
| **Look and feel** | brand: color, type, spacing, radius | the theme token document | the theme write ([P0-112]) |

What is deliberately NOT a plane: markup, CSS, and component internals. A
component's rendering is *code* — which is precisely why it can be improved
for every client at once ([P0-118]). An editor who could write markup would
take that property away from the product, along with the escaping, CSP and
addressing invariants the emitter guarantees.

## 18.2 The arrangement is a base document plus a journaled fold

**[P0-115] The current arrangement is the base document folded with its
command stream; nothing is stored flattened.** A vendor (or author) ships a
base `[ux:layout]`; every accepted command is one journal entry in that
arrangement's stream, actor-stamped, carrying the content address of the
resulting document. The rendered arrangement is `fold(base, commands)` —
recomputed, never a saved copy. Consequences, each load-bearing:

- **"What did this client's page look like on date D"** is exact, not
  archaeological: replay to that entry (the [P0-15] manifest closes the loop).
- **A new base is adoptable**: the client's commands replay onto it
  ([P0-119]) — the upgrade story exists *because* customizations are commands
  rather than a forked document.
- **Undo is not a feature**, it is the inverse-command emission of [P0-108];
  the stream stays the single honest history.
- A command whose target no longer exists **refuses** ([P0-28]); a fold never
  silently drops an entry.

## 18.3 A page renders the union of its arrangements

**[P0-116] One page is the union of the arrangements in force for it — the
shared chrome plus the route's own — and placed-element ids are unique across
that union.** The shell (navigation, search, announcement, badge) is one
arrangement; each route body is another. Both fold independently, into
separate streams, and render into the same page. Therefore:

- **ids are unique per rendered page, not merely per document**, because
  selection stamps ([P0-109]) and fragment addresses key on them;
- a **batch addresses exactly one document** — atomicity is per stream
  ([P0-27]/[P0-71]) — and a batch spanning two refuses;
- a command whose target is in neither document, and which names no parent,
  lands in the arrangement of the page the editor is on; the editor states
  which that is, and the server never guesses from referer.

**[P0-117] Conversion of a route to arrangement data is tree-preserving.**
When a coded route body becomes an arrangement, the base fold MUST project the
tree the route already produced — same members, same order, same names — so
every equivalence and terminal-face assertion holds before an editor moves
anything. What conversion adds is only that membership and order became data a
command can address. (A conversion that changes the tree is a redesign
wearing a refactor's clothes, and the faces will say so.)

## 18.4 Gestures are commands

**[P0-118] Every studio act, including every direct-manipulation gesture,
resolves to one of the ruled commands on the shipped intent wire.** A drag
ends as `ux:move`; a resize ends as `ux:set-hint span=`; an inline text edit
ends as `ux:set-param`; a theme control ends as the theme write. No gesture
has a private path, which is what makes undo, propose/commit batching,
capability gating, attribution, refusal and liveness apply to gestures for
free rather than per-feature. A client-side preview MAY precede the commit
(the theme panel's live preview is the ruled case) but is ephemeral by
construction: the journal records commits, and a preview that outlived its
commit would be state the server cannot see ([P0-82]).

## 18.5 The fleet: improvements reach clients without erasing them

The model, ruled now because it is expensive to retrofit: **improvements and
customizations live at different cascade levels and in different documents, so
"upgrade" is a replay, never an overwrite.**

**[P0-119] Three deploy channels, deliberately separate.**

1. **Code** — projections and renderers. Improves every client on deploy with
   no per-tenant state, because no client owns markup. Most improvements ride
   here and cost nothing per client.
2. **Vendor documents** — the base arrangements, the component registry, the
   base theme. Content-addressed; **each tenant is pinned to a version** and
   moves only by an explicit act.
3. **The tenant's own streams** — their commands, their params, their tokens.
   Never rewritten by an upgrade.

Resolution across levels is [P0-14]'s per-key nearest-wins with merged bundles
never stored: a vendor change to a key a tenant never overrode reaches them
automatically; a key they did override keeps their intent, and the divergence
is *reportable* rather than silent.

**[P0-120] Adopting a new base is a journaled act with a preflight, and its
refusals are surfaced, never resolved by guessing.** `adopt-base` replays the
tenant's command stream against the candidate base and classifies every
command: **clean** (applies), **drifted** (applies, but its neighborhood
changed — reported), **refused** (its target is gone — [P0-28]). A dry run
produces that classification without committing; adoption then commits the
new pin plus a `[base-adopted from=… to=…]` entry, exactly the shape of
[P0-74]'s adoption (an explicit journaled act, never a silent rewrite).
Because the fold is pure and every tenant's customizations are data, **the
same replay runs across the whole fleet before release** — the vendor learns
which tenants break, and on which command, before shipping. A refused
customization is presented to its owner as a decision (re-place it, or drop
it); no upgrade path may silently discard one.

Breaking vendor changes (a removed component, a renamed param) ship with
**migration commands** in the same act; unmigrated, they refuse under
[P0-113]'s closure rather than degrading. The [P0-7] asymmetry governs the
rest: cosmetics fail open, safety fails closed.

## 18.6 The projection rule, the map, and history

**[P0-123] A component has ONE projection, wherever it is placed.** A page's
own projector owns only the blocks that belong to that page — a home page's
opening block, a category page's facet rail — and delegates every other
component to one shared projector. A component the registry offers is therefore
placeable on any arranged page and renders the same way on all of them.

This is not a convenience. The alternative — each page knowing only its own
components and silently dropping the rest — produces a command that **journals
cleanly and renders nothing**, which is strictly worse than a refusal: a
refusal teaches the editor the rule, and a silent no-op teaches them the tool
cannot be trusted. A projector that cannot render a placed component MUST say
so ([P0-28]'s named refusal, or a visible unknown-component marker), never
answer empty.

A projector answers **one shape on every arm**, including the empty one. A
function that returns a bare element in one arm and a sequence in another has
no single answer shape, and the reader that unwraps it means two different
things depending on which arm ran. That is not a style preference: it emitted a
card's *heading* in place of the card, and so without the id the emitter stamps
selection onto — a block that rendered but could not be selected or addressed.

**[P0-124] The surface is a DERIVED map, and the map is exportable as a
diagram.** An editing authority may read the whole surface as data: every route
the composition declares, which of those are arrangement-driven, and the blocks
of each arrangement in order. It is computed from the composition document plus
the live folds, so it cannot drift from what is served — a map that is
maintained separately is a map that is wrong.

A route pattern carries a **walkable example** derived from the data actually
loaded, so "open this route and edit it" resolves to a page that exists; a
pattern whose parameters cannot be filled honestly reports no example rather
than offering a link that 404s.

**An exported drawing must be legible without its stylesheet.** A receiving
context may refuse the carriage: inlined into a page, an SVG's own `<style>` is
an inline stylesheet and a strict `style-src` policy declines it — at which
point every `var()` reference collapses to its initial value and the drawing can
render as a solid rectangle with invisible labels. Colour and geometry therefore
ride as presentation attributes, and a stylesheet may only carry what is
genuinely optional (an alternate colour scheme for standalone viewing).

The same map answers in **diagram text** (Mermaid), which is what the
platform's own diagram surface speaks. Direction matters: a diagram is an
**export of the derived model**, never an input. Nothing reads a diagram back,
because a hand-edited diagram would be a second, unverifiable source of truth
for a structure the composition already states.

**[P0-125] A page's history is readable, and returning to a point is
additive.** An editing authority may read the change log of an arrangement —
each entry with its sequence, its actor and what it did, oldest first — and may
return the arrangement to any point in it. Returning **appends** the inverse
commands for the range ([P0-108]'s pairs, committed as one [P0-27] batch); it
never rewrites, reorders or removes an entry.

An undo that mutates the record is inadmissible here for the same reason
[P0-74] forbids silent rewrites: this journal is the evidence an adopter shows
a client about their own deployment. Going back must itself be a thing that
happened.

**[P0-127] An editor's own view repaints through the page's own wire.** After a
commit the editor's window re-renders by triggering the refetch the *page*
declares — the same request, the same renderer, no editor-only rendering path.
Where a page declares none, the editor reloads it.

The broadcast ([P0-44]) remains what repaints every *other* viewer. An editor
that waited on a broadcast it had just caused would be slower for no gain and
would show stale bytes whenever the feed dropped; an editor that painted the
result *itself* would be the second renderer this whole design exists to avoid.
The client-ephemeral theme preview ([P0-112]) is the single ruled exception, and
it is reverted unless committed.

**[P0-128] A control the studio offers must be reachable, and acting on it must
take effect.** This is one clause because the failures are one failure wearing
three coats:

- **Unreachable.** An empty container renders as a zero-height box — invisible,
  therefore unclickable, therefore unselectable. Every command needed to fill it
  worked; there was no way to ask. A face MUST give an editor a target for any
  block it will accept a gesture on, and an empty container MUST state that it is
  empty and offer its own space in edit mode. (This costs a visitor nothing: the
  element being decorated has no content to disturb.)
- **Offered but impossible.** A gesture may only be offered where it can
  succeed — an element the arrangement does not hold is not a drag target
  ([P0-123]), and a control whose write cannot take effect is worse than an
  absent one, because it teaches that the tool lies.
- **Written but inert.** The declared value must actually govern
  ([P0-126]/[P0-127]): a hint that is written, journaled, read back and then
  overridden by the face is indistinguishable, to the person doing the work,
  from a bug in their own understanding.

A studio may therefore not ship a control whose only evidence of working is that
its command was accepted. The demonstration is the rendered result.

**And acting must not cost the designer their place.** Where a commit forces a
full reload — a stylesheet or a chrome change that no region refetch can
repaint — the editor returns to the panel and the selection it was working in.
Losing them reads as the tool undoing the navigation the designer just did, and
it is indistinguishable from a bug. Where the position lives matters too: it is
a view position, not a document, so it belongs to the session and never to the
journal.

**And a panel states what it is for.** An instrument whose surfaces are correct
but unexplained is not usable: a reader who cannot tell what a panel does will
not use it, and a panel that only repeats what the canvas already shows has not
earned its place. Each one names its purpose in the reader's terms, and justifies
itself by doing something the canvas cannot.

## 18.7 Status ladder — built vs. ruled

Normative status is per clause; this table records *implementation* state so
the roadmap is tracked here rather than in conversation. It is updated with
the waves it names.

| Capability | Clauses | State (2026-08-20) |
|---|---|---|
| Five layout commands, refusals, inverse pairs, batches | P0-105…P0-108 | **built** (engine + fixtures) |
| Edit mode, selection stamps, capability gating, PEP recheck | P0-109, §6.5 | **built** |
| One vendored CSP-clean studio asset | P0-110 | **built** |
| Direct manipulation (drag, resize, grid guides) | P0-118 | **built** (drag to move, grip to resize, column guides) |
| The declared width actually governs the grid | P0-126 | **built** (wide and narrow tiers; both chains were dead before this wave) |
| Content params + inline editing | P0-111, P0-113 | **built** |
| Theme write + live preview + multi-token palettes | P0-112 | **built** |
| Component registry as the closed surface (params, variants, container, fixed) | P0-113 | **built** |
| One projection per component, on every arranged page | P0-123 | **built** (shared kit projector) |
| Arrangement coverage: shell + home + category + product routes | P0-116, P0-117 | **partial** — search, basket, checkout, orders, account pending |
| Component library breadth (sections, kit, leaves, data block) | P0-113 | **partial** — a working set, deliberately closed |
| Derived surface map + Mermaid export + open-a-route | P0-124 | **built** — as data, as diagram text, as a drawn SVG, and as a page in the surface's own theme |
| The chrome's own geometry (shell widths) | P0-126 | **built** |
| Readable history + additive return-to-a-point | P0-125 | **built** |
| Editor repaint through the page's own wire | P0-127 | **built** — home declares a refetch; category and product reload instead (their own refetch routes pending) |
| Grid: column position, row control, more breakpoints | P0-114 | **partial** — two width tiers; explicit column start and row control pending |
| Page/route creation from the studio | P0-116 | **unbuilt** |
| Draft → preview → publish (beyond propose/commit batching) | P0-27, §6.6 | **unbuilt** |
| Client self-serve tier under the vendor allow-document | P0-113, §6.5, §19.3 | **built** (ceiling enforced per command at the PEP) |
| Container layout controls (tracks, gap, alignment, padding, ground) | P0-121 | **partial** — `columns`, `group`, `section` and the kit carry them; more leaf axes pending |
| Declared containment (`accepts=`) with named refusal | P0-122 | **built** |
| Saved themes: name the current look, apply it later | P0-112 | **built** — one journal entry per save; applying writes the same token path a hand edit takes |
| Empty containers are reachable drop zones | P0-128 | **built** |
| Panels state their purpose | P0-128 | **built** |
| Fleet: tenant streams, pins, adopt-base + preflight, refusal triage | P0-119, P0-120, §19.3 | **built** for a candidate bundle and per-tenant adoption; migration commands for breaking changes **unbuilt** |

A row moving to **built** requires its own fixtures and reference-estate
instrumentation, per §17.3; nothing in this table is a claim about behavior
that a lane does not exercise.

---

# §19 Design control and the adopter's product (2026-08-20, RULED: DS-12)

§18 states what a studio edit *is*. This section states what a designer can
*control* — and why that question is inseparable from redistribution.

**The frame.** The studio is platform capability: an **adopter** builds a
surface for their own use *or to redistribute to their clients*, and those
clients customize it. Two obligations follow, and they pull against each
other unless the vocabulary does the work. The adopter must be able to make
something **differentiated and beautiful** (otherwise every CX app looks the
same and the platform is a liability), and a client's customizations must
**survive the adopter's upgrades** (otherwise redistribution is a support
nightmare and nobody ships twice). Free-form styling would satisfy the first
and destroy the second. The resolution is the container plane: real control,
expressed in closed semantic terms the platform can reason about.

## 19.1 The container plane

**[P0-121] Layout containers carry layout intent as closed, token-valued
variants — never CSS, never pixels.** A container declares axes such as track
count, gap, alignment, padding and ground; each axis has a closed option set
resolved through the theme's own scale ([P0-33]). This is what gives a
designer compositional control — rhythm, alignment, emphasis, density —
without giving them a stylesheet:

- **Admissible under [P0-20]/[P0-53]** precisely because the values are
  semantic: a terminal has columns, blank lines and framed boxes, so every
  face can honor `cols`, `gap`, `pad` and `tone` natively rather than
  simulating a browser.
- **Realized from the emitter's variant stamps** ([P0-113]) against theme
  tokens, so a rebrand moves every container with it and a container cannot
  hard-code a colour or a measure.
- **A closed set is analyzable**, which is what makes [P0-120]'s fleet
  preflight possible at all: the adopter can enumerate every legal
  customization of their product, and therefore compute what an upgrade does
  to each one. Free CSS is not analyzable, which is why theme-fork platforms
  make upgrades the client's problem.

Per-element style variants (heading scale, text emphasis, card elevation) are
the same mechanism at leaf scale, and a **section kit** — ready-made,
parameterized compositions the adopter ships in their registry — is how a
designer reaches a good result quickly rather than assembling primitives.
Beauty is composed from a kit, not built from a blank canvas in a browser.

## 19.2 Containment is declared

**[P0-122] A container declares what it accepts; an unaccepted place or move
refuses.** `accepts=` on a registry entry names the component names a
container may hold; absence means anything, and a violation refuses with
`ux-layout-not-accepted` naming the parent and the child. Ground, from the
field: an editor placed a search control inside a navigation's item list and
the projection produced an invalid, ugly tree — because nothing said no. A
studio that lets a reasonable gesture produce an invalid document is not a
design tool, and a refusal that names the parent and the child is how the
tool teaches its own grammar.

Containment is also what lets the palette be honest: an editor sees the
components a *selected container* can take, rather than a flat list that
sometimes works.

## 19.2a Declared geometry governs

**[P0-126] Inside an arranged region the ARRANGEMENT decides geometry, and a
face's own layout heuristics stand down on any element the designer has
placed a width on.** A face may infer layout from what it recognizes — a facet
rail goes beside results, a pager goes under them — but those inferences are
guesses about an *unarranged* document. Where the arrangement states a width,
the guess yields; where it says nothing, the guess still serves.

This is stated as a clause because the failure mode is invisible and total. A
face's heuristics naturally name more structure than a width does, so a width
declared as data can lose on precedence alone: the gesture writes its hint, the
inspector reads the hint back and agrees, the journal records it — and the page
does not move. Every layer reports success and nothing happens. A face MUST
therefore give declared geometry precedence over its own heuristics, and MUST
do so for **every** width tier it offers, not only the widest: a narrow-tier
decision that cannot take effect is not a decision.

**Orientation outranks width.** Where a face offers a container-level
orientation (a menu beside the content rather than above it), that decision is
about the whole region's shape and MUST outrank any width declared for a single
child within it. Stated because the inverse failed in exactly the invisible way
[P0-126] describes: the rail rules were correct and the arranged grid outranked
them, so a menu moved to the side pushed every other block below itself instead
of standing beside them.

Two consequences follow.

**The chrome is arrangeable in the same two dimensions as a page.** An
arrangement that governs order but not width cannot express "put this beside
that", and a container's declared containment ([P0-122]) rightly refuses the
alternative of nesting an unrelated control inside a list that does not accept
it. Where the shell is edited as data, its own geometry is editable too.

**In edit mode a region is arrangeable before its first width exists.** A
visitor's render may mark a region as gridded only once the arrangement says
something — that is what keeps an unarranged surface byte-identical to one with
no studio at all — but applying the same rule to the editor is a deadlock: no
width means no grid, no grid means no resize affordance, and the first width can
never be set. An editor sees the grid it is about to arrange.

## 19.3 The adopter's product, and its clients

The clauses of §18.5 are the redistribution contract; this is what they mean
in the adopter's terms:

| Layer | Who owns it | What it holds |
|---|---|---|
| Platform | CX | projections, renderers, the vocabulary, the studio |
| **Vendor** | **the adopter** | their base arrangements, their component registry and kit, their base theme, their **allow document** |
| Tenant | the adopter's client | that client's commands, params, tokens |
| Surface | one deployment | route-level picks |

An adopter's release is therefore a **versioned vendor bundle**, each client
**pinned** to a version, and an upgrade is [P0-120]'s replay-with-preflight —
never an overwrite. The **allow document** at the vendor level is how the
adopter chooses their client's ceiling: which elements may move, which axes
may be set, which params may be written. A client editing inside that ceiling
cannot break the adopter's brand, accessibility guarantees, or another
client's deployment — because those are properties of the platform and the
vendor bundle, not of the client's command stream.

**What this obliges of the platform, stated so it is trackable** (§18.6's
ladder carries the state): the vendor level must be populated rather than
reserved; bundles and pins must be first-class; `adopt-base` and its fleet
preflight must exist as commands with fixtures; and the allow document must
gate the studio's offers and the PEP's answers from one declaration.
