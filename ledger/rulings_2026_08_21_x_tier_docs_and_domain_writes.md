# Rulings — the x/ tier reaches its readers, and domain data gets a write path
2026-08-21 · owner: "fix 904 and 905"

Two gaps found while documenting the studio, both authorized for fix by the
owner in one instruction.

---

## XD-1 — the x/ tier is DOCUMENTED, and marked for what it is (#904)

**The finding.** The guide generates one reference page per module from
`[$io:glob 'stdlib/*.cx']`. The `x/` tier lives in a sibling directory, so its
12 bundled modules get no page at all — including `ux` (109 `fn-doc` blocks),
`ux-tui` (27) and `ux-web` (24). Roughly 160 documented functions, in the
source, reaching no reader. The terminal face is undocumented everywhere.

**The complication that decides the shape of the fix.** Every `x/` module
carries a banner disclaiming the frozen-surface promise, and
`spec/03-approved/std-lib/README.md` §3 (decision D3) states the tier is
"explicitly exempt from the frozen-stability promise… the frozen-surface canary
never counts it". So globbing `x/*.cx` into the same list as the 48 frozen packs
is the WRONG fix: it would publish an experimental surface as though it were
stable, which is a worse lie than silence.

**RULED (XD-1a).** The `x/` tier is published in the module reference as its
OWN group, named as experimental, with the exemption stated on every page. A
reader gets the functions; nobody is told they are frozen. Page slugs carry an
`x-` prefix so the URL says which tier it is.

**RULED (XD-1b).** The tier's enumeration in the spec is TRUED to what is
actually bundled. `bundled_x_names()` in the implementation lists 12 modules;
the spec's table lists 6. The six missing are `ux`, `ux-web`, `ux-tui`, `term`,
`tools` and `adjudicate` — all bundled, all gated, none in the table. A spec
table that is a strict subset of what ships is the same defect class as the
studio's dead controls: correct at one layer, wrong where it is read.

---

## XD-2 — domain data is journaled, and its authority is its own (#905)

**The finding.** Layout, look and block copy are all editable at runtime and
journaled. DOMAIN DATA is not: ORIEL reads its catalogue with
`[$io:read-file …/catalog.cxd]` at boot, and there is no `product-added` or
`price-set` command anywhere. Changing a price means editing a document and
restarting the service. Every *transactional* fact in ORIEL is already
journaled — baskets, orders, returns, reviews, subscriptions, editor sessions,
theme, layout, tenant pins — so the pattern was established and simply never
applied to the catalogue.

**RULED (XD-2a) — the catalogue is a base document plus a journaled fold.**
Exactly the shape arrangements already use: current state = the shipped
document + the commands appended since. This is what makes a runtime price
change possible without making the catalogue mutable-in-place, and it is what
lets a new vendor bundle still compose with a tenant's own edits.

**RULED (XD-2b) — a closed field set, declared as data.** A catalogue command
may write only fields a registry document declares, with a declared kind
(money, text, flag). An unknown field refuses by name; a value that is not of
its kind refuses by kind. Same reasoning as the component registry: a closed
vocabulary is what makes the fleet replay analyzable, and free-form domain
writes would put that back where theme-fork platforms leave it.

**RULED (XD-2c) — DESIGN AUTHORITY IS NOT PRICE AUTHORITY.** The write path is
gated by its own capability, `catalog:edit`, mapped through the same §6.5 claims
map. An editor who may move a hero MUST NOT thereby be able to change a price.
This is the point of capability-per-act rather than role-per-person, and getting
it wrong here would be the most expensive possible demonstration of the
principle.

**RULED (XD-2d) — retirement is a fact, and it must reach the buy path.** A
retired product stops being buyable, not merely stops being shown. A domain
write that changes what a shopper sees but not what a shopper may DO is the
dead-control class again ([P0-128]) with money attached.

**RULED (XD-2e) — the admin surface is a surface, not a special case.** It is
composed from the same vocabulary as every other page, gated like every other
capability, and its writes are journaled like every other act. What it is NOT
is the studio: a price is not a layout decision and does not become one by being
edited in a browser. The two tools share a substrate and nothing else.

**Named limit, deliberately.** These commands EDIT the catalogue; they do not
CREATE products. A new product needs art, a category, specifications and a
place in the navigation — that is an import concern with its own shape, not an
admin-console field. Stated here so the boundary is a decision on the record
rather than an absence someone discovers.

Spec: `spec/03-approved/std-lib/README.md` §3 is trued under XD-1b. Commits
carry `RULED: XD-1` / `RULED: XD-2`.
