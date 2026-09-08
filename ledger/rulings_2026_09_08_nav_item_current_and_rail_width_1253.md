# RULED: 1253-a / 1253-b — `current=` joins `ux:nav-item`; the side rail's width
# becomes a `rail-width` token WITH a 220px fallback, and does NOT reuse
# `aside-width`.

Date: 2026-09-08. Issue: cx-home/cx-private#1253. Campaign: v0.18.0 close-out
(#1354), Lane 1. Ruled by the campaign worker under #1354 rule 7. Every fact
below was read at `fc39d7758`, not recalled.

## 1253-a — `current=` is granted to `ux:nav-item`

### The asymmetry, measured

`allowed-attrs` in `x/ux.cx` at `fc39d7758`:

| member | granted attributes |
|---|---|
| `ux:nav-item` | `("href", "label", "id", "live")` |
| `ux:crumb` | `("label", "href", "current", "id")` |
| `ux:page-link` | `("n", "href", "current", "id")` |

So `current=` is already in the vocabulary, on two members, and both lower it
the same way — `x/ux-web.cx:373` (`lower-crumb`, `[?attr "aria-current" "page"]`)
and `:405` (`lower-page-link`). The refusal the issue reports,
`[ux-refusal code=ux-unknown-attr element=ux:nav-item attr=current]`, is
P0-98 working correctly over a grant table that is missing a row.

### Ruled: grant it

The [P0-53] asymmetry test decides this on its own. A nav that is a list of
places is the PRIMARY thing "you are here" is about; a breadcrumb trail and a
pager are secondary carriers of the same fact, and both already have it.
Granting the attribute to the two members that need it less while refusing the
one that needs it most is precisely the asymmetry the test forbids. No new
concept enters the vocabulary: `current=` is spelled, lowered and fixtured
already, on a boolean whose web lowering is one existing `[?attr]`.

**DELETES:** the two workarounds the issue names, both of which are wrong for
reasons the spec already states — decorating the label (`"acme-party *"`), a
presentation decision smuggled into content that a screen reader reads aloud as
a star; and leaning on a `[ux:breadcrumb]` beside the content, which says where
you are while leaving the list itself unmarked.

### What the implementation owes, including the part most easily missed

1. `allowed-attrs` — add `"current"` to the `ux:nav-item` row.
2. `lower-nav-item` (`x/ux-web.cx:441`) — `aria-current="page"` on the anchor
   when `current=true`, the same `[?attr [?if $cur …]]` shape `lower-crumb`
   uses. Note it must go on the ANCHOR, not the `li`: the anchor is what
   `$box` wraps, and it is what `lower-crumb` marks.
3. The terminal face (`x/ux-tui.cx:183`, the `t:navitem` arm) — the marked
   item. A face that ignores it fails the two-renderer equivalence rule that
   `refusals-of` exists to enforce.
4. `content-of` (`x/ux.cx:1327`) — project it. Content normal form is what the
   equivalence fixtures compare; an attribute the projection drops is invisible
   to them.
5. **The reverse projection at `x/ux-web.cx:3496`** — html→content already
   reads `aria-current="page"` back into `current=` for the anchor family
   (`[?attr "current" [?if [= [$ux:str-or $a@aria-current ""] "page"] …]]`).
   The `ux-nav-item` arm at `:3289` builds `[c:nav-item …]` and does NOT read
   it. Round-trip parity breaks here first, and it breaks silently, because
   nothing in the corpus exercised `c:nav-item` at all before `ux-121`
   (2026-09-08, #1221). This is the step to write the fixture for.

## 1253-b — a `rail-width` token WITH a fallback; NOT `aside-width`

### The fork, and the record it departs from

The issue offers both spellings: "a `rail-width` (or reuse of `aside-width`)
token". And there is an existing record —
`ledger/rulings_2026_09_04_view_grammar.md:71`, in the consequences for #1282 —
which says "the rail width reads the theme's `aside-width` token". That record
is a **recommendation for #1282's own ruling**, not a ruled outcome; #1282 is
still OPEN and unruled. This ruling declines the recommendation, and records why,
because two facts read today were not in evidence when it was written.

**Fact 1 — reuse is a 172px visible change, not a refactor.** The only theme in
the tree that declares the token,
`spec/03-approved/xap/demos/oriel/data/oriel-theme.cx:187`, sets
`[token name=aside-width value="392px"]`, against the rail's `220px` literal.
Reusing it silently widens the rail by 172px in the one surface that would
notice.

**Fact 2 — `aside-width` has no default anywhere, and copying that would
REGRESS the rail.** `var(--cx-aside-width)` is referenced twice in
`x/ux-web.cx` (`:2386`, `:2707`) with no fallback, and a repo-wide search finds
`token name=aside-width` declared in exactly one file — the oriel demo theme.
So a surface with no theme has no aside width at all today. The rail's `220px`
literal is, right now, the only rail geometry that works with no theme.
Replacing it with a bare `var(--cx-rail-width)` — or with a bare
`var(--cx-aside-width)` — would take the rail from "always 220px" to "nothing
unless a theme says so". That is a regression dressed as a cleanup.

### Ruled

Two rules in `component-rules` (`x/ux-web.cx:2766` and `:2862`) change from

```
[decl prop=grid-template-columns value="220px minmax(0, 1fr)"]
```

to a `rail-width` token **carrying the current literal as its CSS fallback**:

```
[decl prop=grid-template-columns value="var(--cx-rail-width, 220px) minmax(0, 1fr)"]
```

- A **separate token**, not `aside-width`, because a rail and an aside are
  different things: the aside is a secondary region beside the content, the rail
  is navigation chrome. Coupling them means a theme that widens its aside
  silently widens its nav, which is a surprise of the same family as the two
  #1221 was about.
- **With the fallback**, because that is what makes this byte-equivalent in
  behaviour for every existing surface: no theme declares `rail-width`, so every
  rail stays exactly 220px, and a theme that wants a wider rail for longer
  member names now has the knob [P0-33] says a theme is for. It also fixes the
  no-theme hole rather than propagating it.

**DELETES:** the literal, in both rules, and the situation where the one measure
a members-list nav needs to change is the one measure a theme cannot reach.
It deletes no current rendering — that is the point of the fallback.

### Scope boundary against #1282

#1282 (OPEN, unruled) owns the rail's **narrow tier** — that the 220px column
survives onto a phone and squeezes the content, and the side→top collapse at the
880px tier. This ruling tokenizes the WIDTH only and touches no breakpoint. The
two are separable: a tier that collapses the rail away and a token that sizes it
while it is there. Nothing here pre-empts #1282's ruling, and #1253's item 2 is
satisfied without it.

## Registry pre-flight — one finding, and it is not a fixture

- No conformance fixture asserts the `220px` rail literal. The repo-wide hits
  are `design/787/audit2/AUDIT.md` (prose), `scripts/gen_guide/playground/playground.css`
  (the guide's own stylesheet, not emitted by `ux-web`), and the oriel theme's
  `page-width value="1220px"`, which merely contains the substring.
- **`themeGroupOf` in `spec/03-approved/xap/demos/oriel/static/studio.js:1197`
  is an unregistered enumeration and will MISCATEGORIZE the new token.** Its
  regex lists `space|radius|border-width|label-width|control-width|page-width|aside-width|grid|line-gap|media`
  as "Spacing & shape" and falls through to `return 'Light palette'`, so a
  `rail-width` token appears in the studio's Brand tab as a COLOR. It does not
  refuse and nothing reds — the studio just shows a length among the swatches.
  `rail-width` must be added to that regex in the same landing.
- There is no theme-token registry in `x/*.cx` and none in `spec/03-approved/xap/`:
  no `known_token`/`valid-token` validation exists, so a theme may declare any
  token name. That is why the CSS-level fallback, not a validation rule, is what
  makes the new token safe.
