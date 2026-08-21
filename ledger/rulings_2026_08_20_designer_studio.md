# Rulings 2026-08-20 — the designer's studio (W27+), design letter DS

**Owner:** the DS letter's recommendations stand accepted — "ok lets go with
your recommendation" (2026-08-20, on the reference-bar framing) followed by
"too many questions and too many misses. just deliver something impressive
and sufficiently full featured to care about" (2026-08-20, on the posed
letter) — under the standing order that letter recommendations are
auto-accepted when long-term-best (2026-08-07 precedent), each verified as
such below. The letter: design/787/w27/studio-2.md.

- **DS-1a** — arrangement-everywhere including the SHELL: nav, search and
  badge become placed elements (search-beside-Account is a drag; the shell
  arrangement applies store-wide). Route-body conversion beyond home
  proceeds estate-wide as the campaign continues.
- **DS-2a** — the grid is first-class: `span` + `col-start` hints, the grid
  visible during editing, snap on every gesture. Free x/y (row pinning)
  REMAINS UNRULED — it needs a P0-96 carve-out and is not recommended.
- **DS-3a** — components declare VARIANT axes in the registry
  (`orientation: top|side` on nav is the acceptance demo); a variant is an
  ordinary surface-level hint.
- **DS-4a** — the THEME PANEL: token editing (color/type/spacing/radius)
  with live preview; commit = ONE journaled theme write at the surface
  cascade level through a gated intent, values through the existing
  token-value gate. SPEC AUTHORIZED: the theme-write clause (P0-112).
- **DS-5a** — CONTENT PARAMS on placed elements, written by a new
  `[ux:set-param]` command (same partial-document semantics and inverse
  shape as set-hint); components declare params in the registry; the studio
  edits them inline on the canvas and in the inspector. SPEC AUTHORIZED:
  the set-param clause (P0-111) joining the closed command set.
- **DS-6a** — the ruled starter library, parameterized: text, image, button,
  spacer, columns (container), and DATA BLOCKS bound to live domain queries
  (product-grid). Registry schema carries params/variants/container-ness.
  SPEC AUTHORIZED: the registry-schema clause (P0-113).
- **DS-7a** — breakpoint-scoped arrangement rides the pack's two ruled
  breakpoints; the studio gains a viewport switcher. (Per-breakpoint hint
  overrides land as the campaign continues; the switcher lands now.)
- **DS-8a** — the vendor-level ALLOW vocabulary = client self-serve on the
  same studio, PEP-enforced. Accepted; lands after the designer planes.
- **DS-9a** — the studio's own UX: layers panel, hover pre-highlight,
  keyboard (undo/delete), gesture polish; multi-select and visible history
  as the campaign continues.
- **DS-10** — sequencing relative to the v0.16.0 cut: NOT ruled here (a
  release decision the owner holds); the work lands on the branch either
  way.

Spec edits under these rulings carry tokens `RULED: DS-4`, `RULED: DS-5`,
`RULED: DS-6` (P0-111/P0-112/P0-113). The standing owner protocol from this
review: every delivered iteration ends with a concise "try this" list.

## Addendum — DS-11: the studio gets a normative spec section (owner, 2026-08-20)

**Owner directive:** *"we really need a spec for this so we can keep track of
where we're going."* SPEC AUTHORIZED for a consolidating section — `ux.md §18,
"The studio — the editing model"` — which states, normatively and in one
place: the three editable planes and their documents; base-document + journaled
fold semantics; the multi-document render (shell + route arrangements) and its
id-uniqueness obligation; gestures-as-commands (no gesture may bypass the
journaled wire); the FLEET model (cascade levels, per-tenant pins, adopt-base
as a journaled act with fleet preflight, refusal triage, the three deploy
channels) — the durable answer to "how do improvements reach many clients
without wiping their customizations"; and a STATUS LADDER distinguishing what
is built and normative from what is ruled-but-unbuilt, so the roadmap is
tracked in the spec rather than in conversation.

Clauses land as [P0-114]…[P0-120]. The fleet clauses are ruled as the MODEL
(the shape every implementation must take); their implementation is a named
campaign, not a claim of shipped behavior — the ladder says which is which.
Spec commits carry `RULED: DS-11`.

## Addendum — DS-12: design control, and the adopter→client contract (owner, 2026-08-20)

**Owner framing (verbatim intent):** the studio is **CX PLATFORM capability**,
so an **adopter** can build an app for their own use *or redistribute it to
their clients with customizations* — *"customizations without creating a
nightmare upgrade scenario."* Plus the review verdict: a UX designer looking at
today's studio would say *"we have no control, no way to differentiate and make
it beautiful."*

Both are ruled as one section because they are one problem: an adopter can only
differentiate if the studio gives real design control, and can only
redistribute if customization survives upgrade.

- **DS-12a — the container plane.** Layout containers carry real layout
  intent — track count, gap, alignment, padding, ground — as CLOSED,
  TOKEN-VALUED variants, never CSS and never pixels. Admissible under P0-20 /
  P0-53 because every face can honor them natively (a terminal has columns and
  blank lines). Landing now: `columns` (cols/gap/align) and `group`
  (pad/tone/align); the section kit and per-element style variants follow.
- **DS-12b — containment is declared.** A container states what it ACCEPTS;
  an unaccepted place or move refuses (`ux-layout-not-accepted`). Ground: the
  owner placed a search box inside the nav's item list and the system produced
  garbage, because nothing said no. A studio that lets a reasonable gesture
  produce an invalid tree is not a design tool.
- **DS-12c — the adopter's product is the VENDOR level.** An adopter's app is
  a vendor-level bundle (base arrangements + registry + theme + allow
  document), content-addressed and versioned; each client is a tenant with
  their own command streams at tenant/surface level. This is what P0-13
  reserved the vendor level for, and populating it is now the named next
  campaign — it is the redistribution story, not an optimization.
- **DS-12d — upgrade is replay with preflight, fleet-wide.** As P0-119/P0-120
  already rule: three deploy channels, per-tenant pins, `adopt-base` as a
  journaled act whose dry run classifies every customization clean / drifted /
  refused, runnable across every client before release, refusals surfaced as
  decisions, breaking changes shipping migration commands.

Spec: ux.md §19 states DS-12a/b as normative clauses [P0-121]/[P0-122] and
records the adopter→client contract as the framing §18.5's fleet clauses
serve. Spec commits carry `RULED: DS-12`.
