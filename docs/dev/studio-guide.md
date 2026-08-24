# The studio — editing a running surface, and shipping the result

The studio is CX's **design tool for a live XAP**. A designer opens a page of a
running app, selects a block, drags it, resizes it, rewrites its words, restyles
the whole brand — and every one of those acts is a *journaled command*, not a
file edit. The page they were looking at is the page a visitor gets: same
renderer, same bytes, no editor-only rendering path.

It exists for one commercial reason. An adopter builds an app on CX and then
redistributes it to their own clients, each of whom wants it to look like
theirs. The studio makes those customizations **data** — a stream of commands
against a base document — so shipping an improvement to all of them is a
*replay*, not a merge. That is the whole design: customization without a
nightmare upgrade.

The normative source is `spec/03-approved/xap/ux.md` §18–§19 (clauses `P0-105`
…`P0-128`). Rulings live in `ledger/rulings_2026_08_20_studio.md` and
`ledger/rulings_2026_08_20_designer_studio.md`. Where this guide and the spec
disagree, the spec wins.

---

## 1. Try it in five minutes

The reference storefront (ORIEL) ships the studio wired up. You need a built
`cx` and nothing else.

```bash
devbox run -- make build-vcx-dev
```

Boot the store with an editor key. **Deny-by-default: with no
`CX_UX_EDIT_KEY` in the environment, no key opens anything.** The sign-in form
at `/edit` is shown to everyone on purpose — a login door is not the capability
it grants — but without a configured key nothing you type grants `ux:edit`:
`/history` answers 403 and the page carries no edit stamps at all. (Verified
that way, not assumed.)

```bash
CX_UX_PORT=8792 CX_UX_EDIT_KEY=try-the-studio \
  vcx/target/cx --allow-read --allow-net --allow-clock --allow-random --allow-env \
  spec/03-approved/xap/demos/oriel/serve.cx
```

Open `http://127.0.0.1:8792/edit?return=/`, sign in with `try-the-studio`, and
you are editing the home page. Things worth doing first:

| Do this | And notice |
|---|---|
| Click any block | the inspector names it, with its content, its style axes and its width |
| Drag a block somewhere else | it commits as one `ux:move`; the page repaints through its own wire |
| Pull the **↔** grip | the width snaps to the 12-column grid — and a visitor sees it too |
| Double-click a heading | you are editing a *content param*, closed to the registry |
| **Brand → Kids → Apply palette** | one journaled write moves the whole look; ⌘Z takes it back |
| **Brand → Save the current look as** | names it; the list applies it again later |
| **Map → Open the map** | the whole surface, full screen; click a route to go and edit it |
| **History** | every change with its actor; going back *appends* the inverses |
| Move the menu to the side | `Design → nav → Orientation → side`; the content moves beside it |
| **Release → Run preflight** | replays every client's own edits onto a candidate release |

The journal is in memory (`mem://`) in this demo, so **restarting the server
resets both your edits and your editor session**. That is a demo choice, not a
platform one.

Keyboard: `⌘K` for everything, `?` for the key list, `⌘Z` undo, `[` / `]`
narrower and wider, `⌫` remove, `Esc` deselect.

---

## 2. What the studio can and cannot express

This is the part worth reading before designing around it.

**It can:** reorder, nest, place and remove blocks; set a block's width per
width-tier; set the closed style axes a component declares (tone, padding,
alignment, columns, gap, ratio, radius…); rewrite the content params a
component declares; write theme tokens (colour, type, shape, density) globally;
name and re-apply a whole look; and revert to any point in a page's history.

**It cannot, by construction:** write markup, write CSS, write a query, or
invent a component. Everything placeable comes from a **component registry**,
and every style value comes from a **closed set** the registry declares. That is
not timidity — it is what makes `P0-120`'s fleet preflight possible: because
every customization is a command over a declared vocabulary, an adopter can
replay all their clients' edits against a candidate release and be *told* which
ones break, before shipping. Free-form CSS is not analyzable, which is why
theme-fork platforms make upgrades the customer's problem.

A container also declares **what it accepts**, so a reasonable gesture cannot
build an invalid tree: dropping a search control inside a navigation's item list
refuses with `ux-layout-not-accepted`, naming the parent and the child.

---

## 3. Where it fits in the workflow

The studio is not a separate build step. It edits what you already built.

```
   author the XAP                    (features, surface, view tree — as ever)
        │
        ├─ 1. convert the routes you want editable to ARRANGEMENT DATA
        │      tree-preserving: the base fold must project the tree the route
        │      already rendered (P0-117), so nothing changes on day one
        │
        ├─ 2. declare a COMPONENT REGISTRY
        │      what is placeable, what each thing accepts, its content params,
        │      its closed style axes, what is load-bearing chrome (P0-113)
        │
        ├─ 3. grant `ux:edit` in the claims map
        │      the studio is gated like any other capability (§6.5) — the door
        │      is deny-by-default and every command re-checks at the PEP
        │
        └─ 4. designers now edit the running app
               every act is a command in a journal stream, per page, per tenant
                    │
                    └─ deploy: THREE CHANNELS, deliberately separate (P0-119)
                         code            → your release
                         vendor documents → the base arrangements + registry
                         tenant streams   → each client's own customizations
                              │
                              └─ upgrade = REPLAY WITH PREFLIGHT (P0-120)
                                   dry-run every tenant's commands against the
                                   candidate; each one lands clean, drifted, or
                                   refused; refusals are surfaced as decisions,
                                   never silently dropped
```

Two properties make this workable rather than merely clever. Arrangement is a
**fold**: current state = base document + the journaled commands, so a base you
ship later still composes with customizations made earlier. And going back is
**additive**: reverting appends the inverse commands, so the record of what a
client did to their own deployment is never rewritten.

You do not have to convert everything. A route stays code until you choose
otherwise; in ORIEL, `/`, `/c/:dept/:cat` and `/p/:sku` are arrangements and the
rest are still composed in code. The **Map** panel shows you which is which.

---

## 4. Is it usable for any XAP?

Honestly: **the model and the engine are platform; some of the wiring is still
ORIEL-local.** Concretely —

**Already platform, in the `cx` binary:**

- `x/ux.cx` §13 — the layout engine. The five commands, their refusals, their
  inverse pairs, atomic batches, and the registry readers, all pure and public:
  `layout-apply`, `layout-apply-batch`, `layout-inverse`, `layout-refusals`,
  `layout-find` / `-ids` / `-parent-id` / `-successor` / `-hint` / `-param`,
  `component-known` / `-container` / `-params` / `-variants` / `-accepts` /
  `-fixed`.
- `x/ux-web.cx` — edit-mode selection stamps, the 12-column arranged grid, the
  declared-width rules for both width tiers, variant realization from registry
  axes, and the SRI-pinned asset manifest a studio asset rides on.
- `spec/03-approved/xap/ux.md` §18–§19 — the normative model, including what an
  offered control owes the person using it (`P0-128`).

**Still per-XAP today** (ORIEL writes each of these by hand in `serve.cx`):

- the studio's own asset pair (`static/studio.js` + `studio.css`) — vendored in
  the demo, not yet shipped as a platform asset;
- the intent routes (`/intent/ux-move|wrap|set-hint|set-param|place|remove`,
  `ux-batch`, `ux-set-theme`, `ux-save-theme`, `ux-apply-theme`,
  `ux-revert-to`) and the reader routes (`/edit`, `/history`, `/map`,
  `/map/view`, `/map/diagram.svg`, `/theme/tokens`, `/theme/saved`,
  `/fleet/preflight`, `/fleet/adopt`);
- the render-context glue (`arranged-rctx`, `edit-rctx-full`, `shell-spans`,
  `layout-now`, `batch-log`, `revert-batch`, `map-rows`);
- the **projectors** — `component=` → view tree. These are genuinely yours: they
  are where your components become your app.

So a second XAP can adopt the studio today by copying that wiring from
`spec/03-approved/xap/demos/oriel/serve.cx` and keeping its own projectors and
registry. That works, and it is more copying than it should be. Promoting the
asset pair, the intent wire and the context glue into the `x/` tier — so a XAP
gets the studio by composing a module rather than by transcription — is tracked
separately; until it lands, read the ORIEL wiring as the reference
implementation rather than as a library.

---

## 4a. The faces, and where their reference lives

The studio edits **arrangements**, and an arrangement is projected by a *face*.
CX ships three, all in the `x/` tier and all bundled into the binary:

| Module | What it is | Studio-relevant part |
|---|---|---|
| `cx-x/ux` | the semantic core — the view vocabulary (`ux:region`, `ux:card`, `ux:field`, …), the render context, and §13's layout engine | the engine every studio command goes through |
| `cx-x/ux-web` | the web face — HTML + the one stylesheet, the arranged 12-column grid, the edit-mode selection stamps | what makes a page selectable and a width real |
| `cx-x/ux-tui` | the terminal face — the same tree, drawn in a real shell | proves a hint is *semantic*: the terminal reads panels and ignores pixels |

The same document renders on all three, which is why a studio edit cannot mean
"add some CSS": a value the terminal cannot honour is not admissible
(`P0-20`/`P0-53`).

**Where their reference is:** `docs/guide/ux-capability.html` is the conceptual
page, and each module has its own reference page under the guide's **x/ tier —
experimental** group: `x-ux.html`, `x-ux-web.html`, `x-ux-tui.html`. They are
grouped apart from the frozen packs on purpose — the `x/` tier is exempt from
the frozen-surface stability promise (std-lib README, decision D3), so a
semver-breaking change is allowed there while a surface settles. Pin behaviour
you depend on with your own fixtures.

---

## 5. The four documents a studio-enabled XAP adds

Read alongside §4 of [the ORIEL guide](oriel-guide.md), which covers the domain,
surface, service and theme documents every XAP already has.

### 5.1 An arrangement, per editable route

`spec/03-approved/xap/demos/oriel/data/home-layout.cx`

```
[ux:layout
  [placed id=hero   component=hero]
  [placed id=featured component=featured]
  [placed id=depts  component=departments]]
```

Ids are yours and must be unique per page. A `[hint name= value=]` child is a
surface-level style or width decision shipped as a default; a
`[param name= value=]` child is content. The **shell** is an arrangement too —
`shell-layout.cx` — which is how the chrome became editable, and how the search
sits beside the menu by default (eight columns to four, on the shell's own
grid).

### 5.2 The component registry — the closed editing surface

`data/home-components.cx`

```
[ux:components
  [component name=section container=true
    [variant name=tone options="plain|surface|sunk|accent|ink"]
    [variant name=pad  options="none|tight|normal|loose"]]
  [component name=banner
    [param name=heading default="Free delivery over $75" carrier=ux-heading]
    [param name=cta-href default="/"]
    [variant name=tone options="accent|ink|surface|sunk"]]
  [component name=nav container=true fixed=true accepts="nav-link badge"
    [variant name=orientation options="top|side"]]]
```

`carrier=` names the rendered class that inline editing targets, which is what
makes double-clicking a heading on the page edit *that* param. `fixed=true` is
load-bearing chrome: restylable, never moved or removed. `accepts=` is the
containment contract.

### 5.3 The claims map — who may edit, and how much

`data/claims-map.cx` maps a principal to the `ux:edit` capability like any other
grant, and may attach attributes that reduce what an editor sees or may do.
ORIEL ships three roles: `editor` (the adopter), `editor-reduced` (an editor
under a lens), and `client` (an adopter's customer).

### 5.4 The allow document — a client's ceiling

`data/allow.cx` is the adopter's declared limit on what *their client* may
change: which components they may place, which blocks they may move or remove,
which theme tokens are theirs. Enforced per command at the PEP with a reason a
person can read — "your plan does not include placing a product-grid" rather
than a 403.

---

## 5a. Updating a running storefront — what reaches it, and how

"How do I change the shop?" is four different questions with four different
answers, and only three of them have one today. Worth knowing which is which
before you plan around it.

### The four kinds of change

| You want to change | The mechanism | Status |
|---|---|---|
| **Layout** — what is on a page, in what order, how wide, nested how | studio gestures → the five layout commands, journaled per page per tenant | **live**, no restart |
| **Look** — colour, type, shape, density; a whole named theme | studio Brand → `ux:set-theme` / `ux-save-theme` / `ux-apply-theme`, journaled | **live**, no restart |
| **Block copy** — the words *inside* a placed block | studio inline editing → `ux:set-param`, closed to what the registry declares | **live**, no restart |
| **Domain data** — price, stock, name, description, availability | the merchant's desk → `catalog-set-field` / `catalog-retire` / `catalog-restore`, journaled | **live**, no restart |

The first three are the studio's job and they are all the same shape: a command
appended to a journal stream, folded over a base document, rendered by the
page's own renderer. Nothing is written to a file, nothing needs a deploy, and
every change carries the actor who made it.

### Domain data — the merchant's desk

`/admin/catalog` is a search followed by an edit: name a product, get the fields
the registry declares, save. Journaled exactly like a layout change, so a price
change needs no restart and carries the actor who made it.

**Its authority is its own.** The desk is gated by `catalog:edit` through the
same claims map as everything else — and *no role holds both* `ux:edit` and
`catalog:edit`. Whoever may move a hero must not thereby be able to change what
a thing costs. An editor posting a price gets:

```
Changing the catalogue needs the catalog:edit capability.
Editing the layout does not grant it.
```

and a merchant posting a layout command is refused the other way. Someone who
needs both holds two roles, deliberately.

**The field set is closed and declared** in `data/catalog-fields.cx`, with a
kind per field:

| kind | accepts | refuses |
|---|---|---|
| `money` | `55.00` | `12.5O`, `55`, `-1` |
| `count` | `7` | `seven`, `-1` |
| `text` | prose up to 400 chars | empty, or anything carrying `<` or `>` |
| `flag` | `true` / `false` | anything else |

Absent from that document, deliberately: `sku` (identity, not a fact about the
product), `department`/`category` (a move between them is a navigation change),
`art`/`alt` (an asset concern), and `rating`/`reviews` — those are *derived from
what shoppers wrote*, and a merchant editing their own rating is the one write
that would make the number a lie.

**Retirement reaches the till, not just the shelf.** `catalog-retire` delists a
product, answers 404 on its own page, and refuses the add-to-basket with the
truthful reason — `Brack 16 cm casserole is no longer for sale.` — rather than
"not in the catalogue", which would be false and unhelpful to someone arriving
from a bookmark. Stopping a product being *shown* is the easy half; stopping it
being *bought* is the half with money attached.

**What this does NOT do:** these commands *edit* products; they do not *create*
them. A new product needs art, a category, specifications and a place in the
navigation — an import concern with its own shape, not an admin-console field.
Stated so the boundary is a decision on the record rather than an absence you
discover.

**How it works, if you are copying it.** The catalogue is a base document folded
with journaled commands — the same shape the arrangements use. Two fast paths
keep it honest: with no edits the base document is returned by identity, and
once there are edits only the products actually edited are rebuilt. (The first
version rebuilt all 1,004 products on every request after a single price change,
and the cost surfaced as a live-push step timing out three instruments away. A
feature's cost belongs to its use, not to its existence.)

### Shipping a new release to deployments you do not control

This is the part that is built, and it is the reason the studio stores
customizations as commands rather than as edited files. Three channels, kept
deliberately separate (`P0-119`):

```
code             → your release: features, projectors, service, faces
vendor documents → the base arrangements + the component registry + the theme
tenant streams   → each client's own commands, per page, per tenant
```

Because a client's customizations are *commands over a declared vocabulary*, an
upgrade is a **replay you can rehearse**:

```bash
# dry run: replay every tenant's own edits onto the candidate bundle
curl -s --cookie "$SID" 'http://127.0.0.1:8792/fleet/preflight?to=next'
# → preflight candidate=next
#   tenant=default pinned=shipped commands=0 clean=0 refused=0
#   tenant=acme    pinned=shipped commands=1 clean=0 refused=1
#     needs a decision: ux:move featured
#   tenant=borough pinned=shipped commands=1 clean=1 refused=0
```

Each command lands **clean**, **drifted** (it applies, but its neighbourhood
changed) or **refused** (its target is gone). Refusals are surfaced as decisions
for their owner — re-place it, or drop it — and no upgrade path may silently
discard one (`P0-120`). Adoption is then its own journaled act, per tenant:

```bash
curl -s --cookie "$SID" -X POST -d 'tenant=acme&to=next'   'http://127.0.0.1:8792/fleet/adopt'
# → adopted tenant=acme version=next clean=0 refused=1
```

The studio's **Release** panel is this, with buttons. Breaking vendor changes (a
removed component, a renamed param) ship **migration commands** in the same act;
unmigrated, they refuse under the registry's closure rather than degrading.

### And the CX store itself

Distinct from the *storefront*: the content-addressed store underneath is
covered by its own pages — [store: embedded](store-embedded.md) for the
substrate, [store: management](store-management.md) for `status` / `gc` /
`diff` / `branch` and recovery, and [store: service tier](store-service.md) for
the daemon, auth and deploy artifacts. Journal streams are the write path for
state; documents are content-addressed, which is what lets a commit be stamped
with the address of the document it produced — and what makes "the same
arrangement" a checkable claim rather than a hope.

---

## 6. What the lane proves

The studio is exercised by ORIEL's own instrument, not by inspection:

```bash
ORIEL_LANE_PORT=8794 devbox run -- bash scripts/oriel_lane.sh
```

`drive.cx` steps 39–63 are the studio's acceptance walk — gating and refusal
families, the arranged grid at both width tiers, content params, the shell as
data, the theme wire, three editable routes, the client ceiling, the fleet
preflight and adoption, the derived map and its drawing, history and its
additive return, and the saved-theme round trip. The conformance fixtures
`conformance/stdlib/ux.cxd` and `ux-web.cxd` pin the engine and the emitter.

A row in ux.md §18.7's status ladder only reads **built** when a lane exercises
it. That table is the honest inventory of what the studio does and does not do
yet — read it before designing around a capability.

---

## 7. Two rules that will save you a day

**A control that exists is not a control that works** (`P0-128`). Every
invisible defect this studio has had was of one shape: a command was accepted,
journaled, and read back correctly, while the page did not move. If you add a
control, demonstrate the *rendered result*, never the accepted command.

**Declared geometry governs** (`P0-126`). A face may infer layout from what it
recognizes, but where the arrangement states a width, the inference yields — for
every width tier, not only the widest. A narrow-tier decision that cannot take
effect is not a decision.
