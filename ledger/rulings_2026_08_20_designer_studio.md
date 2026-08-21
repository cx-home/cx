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

## Addendum — DS-13…DS-17: the finish pass (owner directives, 2026-08-20)

**Owner framing (verbatim intent):** *"keep going until we're 80-100% … get a
full working spec complete, fully implement it"*; *"make studio amazing to work
with. don't cut corners. give designers simplicity across detailed control
surface in a way that is safe. When I demo it people should walk away thinking
wow"*; and *"is cx ability to gen diagrams helpful for studio? at least as a xap
wide map with all the routes and ability to navigate and restructure … sound,
solid, highly efficient, simple to use and just beautiful."*

- **DS-13 — the kit projects on EVERY arranged route.** A component the
  registry offers is placeable wherever an arrangement exists; a page's own
  projector owns only the blocks that belong to that page and delegates the
  rest to one shared kit projector. Ground: the studio offered "add a banner"
  on a category page, the command journaled cleanly, and the page rendered
  nothing. A command that succeeds and shows nothing is worse than a refusal —
  it teaches the designer that the tool lies. Corollary ruled with it: a
  projector answers ONE shape (a sequence) on every arm, because `$first` means
  "first item" of a sequence and "first child" of an element, and that
  difference silently emitted a card's heading without the card — and so
  without the id the emitter stamps selection onto.

- **DS-14 — the surface has a map, and the map is derived.** The studio shows
  every route the composition declares, which of them are arrangement-driven,
  and the blocks in each — computed from `surface.cx` plus the live folds, so
  it cannot drift from what is served. A route pattern carries a WALKABLE
  example derived from the catalogue actually loaded, which is what makes
  "open this route and edit it" a real gesture rather than a link to a 404.
  The same map answers as Mermaid text (`?format=mermaid`), so the platform's
  existing diagram surface — `cx code-diagram` — and any document that speaks
  Mermaid get the XAP's structure for free. Diagram GENERATION is therefore
  useful to the studio as an EXPORT of a derived model, never as a second
  source of truth: nothing in the studio reads a diagram back.

- **DS-15 — history is a place to stand, and going back is additive.** A
  page's journal is readable as a list of changes, newest last, and an editor
  may return to any point. Returning APPENDS the inverse commands for the
  range (P0-108's pairs, P0-27's batch); it never rewrites or erases an entry.
  A studio whose undo is a mutation of the record cannot be trusted with a
  client's deployment.

- **DS-16 — the declared width wins.** Inside an arranged region the
  arrangement decides geometry; the face's classification guesses (facet rail,
  panel placement) stand down on any element the designer gave a width. Ground:
  two whole specificity chains were dead — a wide-tier span and a narrow-tier
  span both lost to rail rules naming more classes, so the resize gesture
  wrote its hint, the inspector read it back, and the page never moved. THAT
  was the "clunky" the owner kept meeting.

- **DS-17 — the studio's own surface is a designed instrument.** Curated
  brand controls (palette, colours, type, shape) over the full token set, not
  instead of it; closed axes shown as segmented controls, never as dropdowns a
  reader must open to learn the options; palettes that write several tokens as
  ONE journaled change so a whole look moves and reverts together; one command
  box (⌘K) over jump / add / switch; the keyboard sheet discoverable at `?`;
  viewport tiers that make the narrow decision its own decision; and an
  editor's own window repainting through the PAGE'S OWN declared refetch —
  never a second rendering path, and never a wait on a broadcast it just
  caused.

Spec: ux.md §18 gains the map, the history/return clauses and the
projection rule as normative clauses; §19 gains the declared-width rule; the
§18.6 status ladder is trued. Spec commits carry `RULED: DS-13` … `RULED:
DS-17`.

## Addendum — DS-18: the second owner walkthrough (2026-08-21)

The owner drove the studio and reported eight things. Six were defects, two were
missing capability. Recorded together because they share one cause: **a control
that exists is not a control that works**, and every one of these passed its own
layer's check while failing the person using it.

- **DS-18a — the default arrangement puts the search beside the menu.** The
  owner's first request of the studio, twice now. It cannot go INSIDE the nav
  ([P0-122] refuses that, correctly), so it goes beside — and beside is a
  WIDTH, which means shipping the widths in the base document rather than
  making a designer discover the grid first. The face aligns the two into one
  bar: same centre, the card's own chrome dropped, the bar's rule continued
  under both.
- **DS-18b — a side menu is BESIDE the content.** The rail rules said so
  already; inside an arranged region the 12-column grid outranked them and
  everything stacked under the menu. Same class as [P0-126]: a decision that
  cannot take effect is not a decision. Ruled: a menu's orientation is a
  decision about the whole region's shape, and therefore outranks any width
  declared for one child within it.
- **DS-18c — an empty container is a drop zone.** A container with nothing in
  it rendered as a zero-height box: invisible, so unclickable, so
  unselectable — "add something to a column" was impossible even though the
  command wire accepted it perfectly. In edit mode an empty container states
  what it is and offers its own space. It changes nothing a visitor sees,
  because the thing it decorates is empty.
- **DS-18d — returning through a multi-command batch.** History refused. The
  range inverse computed EVERY command's inverse against the batch's
  pre-state, so a batch that placed an element and then removed it asked for
  the removal's inverse in a document where the element did not exist yet, and
  the whole revert answered `ux-layout-address-miss`. Ruled: within a batch the
  inverses are built by folding forward and emitted in reverse.
- **DS-18e — the map is DRAWN, not only described.** Words and cards told the
  shape; the owner asked to see it. The same derivation emits an SVG document
  on its own route, embedded as an image — no diagram library, CSP posture
  unchanged, and each arrangement's box brackets the blocks it owns so a group
  reads as a group. Still export-only ([P0-124]): nothing reads a drawing back.
- **DS-18f — a panel must say what it is for.** "Not sure what layers do" is a
  copy defect, not a feature request. Every panel states its purpose in the
  reader's terms, and the block list earns its place by doing what the canvas
  cannot: reaching a block that is off-screen, nested, or too small to click —
  so it also carries the reorder controls.
- **DS-18g — a theme can be SAVED under a name and applied.** Editing was
  already journaled per token; what was missing was a name. A saved theme is
  one journal entry carrying every editable token as it stands, in its own
  stream; applying one writes those tokens through the SAME path a hand edit
  takes, so it is not a second mechanism and cannot express anything a hand
  edit could not.
- **DS-18h — the palette set covers real house styles.** Coastal, Mountain,
  Rock, Tie-dye, High contrast, Executive and Kids join Editorial, Ink and
  Ember. High contrast is not decoration: it is the accessibility floor said as
  a palette, and it carries a heavier border width because contrast is not only
  colour.

Found in passing and fixed with them: the command palette hangs off the studio
ROOT rather than the rail, so it inherited the PAGE's ink and every unselected
row read as blank on the dark panel — the whole ⌘K list was invisible against a
light theme. Colour is now stated on the root.

Spec: ux.md §18.6 gains [P0-128] (an offered control must be reachable and
must take effect) and §19.2a records the orientation-outranks-width rule.
Spec commits carry `RULED: DS-18`.

## Addendum — DS-19: the third owner walkthrough (2026-08-21)

- **DS-19a — a thumbnail is not a map.** A 960×1610 drawing shown 307px wide in
  the rail is a rumour of a diagram. The map opens over the whole viewport with
  the drawing INLINED — so its nodes are elements a click can land on rather
  than a picture of clickable things — with zoom including fit-the-whole-surface,
  and every route and block as a door into editing it. Corollary, learned the
  hard way: **an exported drawing must be legible without its stylesheet.**
  Under the page's CSP (`style-src 'self'`) a transplanted `<style>` is an
  inline stylesheet and is REFUSED, so every `var()` fell back to black and the
  whole map rendered as a black rectangle with 55 invisible labels. Colours are
  presentation attributes now; the style block carries only the dark-mode
  override, which is a standalone-viewing concern.
- **DS-19b — a control must not lose the designer's place.** Applying a colour
  in Brand "bounced back to the inspector": a theme or shell commit reloads the
  page (the stylesheet and the chrome are not region-refetchable) and the studio
  came back on the Design tab. The open panel is part of where the designer IS
  and survives the reload. It is a view position, not a document, so it lives in
  the session and never in the journal.
- **DS-19c — the bar fits.** The owner's "layout gibberish": every box was
  placed correctly and the content of one was 89px wider than its track. A
  search form's intrinsic width is its input plus its button; a flex item that
  wide does not shrink, it overflows — and under right-alignment it overflows
  LEFTWARD, sliding the input in under the menu. `min-width: 0` is what lets a
  flex item honour the track it was given. The default split moves to eight
  columns for the menu and four for the search, because a search is two
  controls and three columns could not hold both. And a menu item's label does
  not wrap mid-phrase — stated only inside the narrow media query, so a
  squeezed bar broke "Basket · 0 items · $0.00" across two lines at full width.
- **DS-19d — a loud palette colours the GROUND.** "Very bland… I was looking
  for bright, almost obnoxiously colorful." A palette that repaints the accent
  and leaves every surface white reads as bland whatever the accent is. The
  vivid ones now set the ground, the cards, the wash, the price, the stars and
  the tone colours: Kids is yellow ground / hot pink / navy ink at pill radius,
  Tie-dye is violet on lilac, Neon is acid green on near-black, Candy and
  Sunset join them. The sober ones — Editorial, Ink, Executive, High contrast —
  stay sober on purpose: a house style and a party are different jobs.

Spec: ux.md §18.6 records the place-keeping rule under [P0-128] and the
legible-without-its-stylesheet rule under [P0-124]. Spec commits carry
`RULED: DS-19`.
