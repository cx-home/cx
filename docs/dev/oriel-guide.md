# The ORIEL guide — building a surface the ORIEL way

ORIEL is the reference storefront built by the #787 campaign: 1,004 products,
six departments, facets, a session-scoped basket, a four-step checkout,
subscriptions, returns, reviews — **in a browser, in a terminal, and in a
serial voice-style renderer, from declarations, with zero view code**. This
guide teaches the way it is built, so the next feature, XAP, or surface can be
built the same way.

Every command in this document was executed against the tree before it was
written down, and re-verified against the released **v0.16.0** (the
storefront boots and answers on :8790 with the release binary; the
`test-oriel-lane` gate re-runs the drive/keys/voice/nokernel/diff battery
inside every full `make test`). Paths are relative to the repo root. ORIEL
lives at its reference-XAP home, `spec/03-approved/xap/demos/oriel/` (domain
documents in `spec/03-approved/xap/demos/oriel/data/`) — the promotion #869
planned for the 0.16.0 cut happened, and these are the promoted paths.

The normative source for every rule this guide mentions is the Phase 0 spec,
`design/787/787-phase0-spec.md` — clauses are cited by name (`P0-…`) and never
restated here. When this guide and the spec disagree, the spec wins.

---

## 1. The idea in one paragraph

You declare a **domain** (nouns, verbs, rules, grants) in a feature document.
You declare a **composition** (routes, what each route offers) in a surface
document. The service folds journal streams and hands the projection *data*;
the `cx-x/ux` vocabulary decides what that data *is*; the renderers
(`cx-x/ux-web`, `cx-x/ux-tui`, or anything that consumes the content normal
form) decide what it *looks like*. No file you write for a feature contains a
color, a class name, a pixel size, or a markup decision — `diff.cx` computes
that this stays true. What polices the whole arrangement is not discipline
but **instruments**: six programs that walk the running store and refuse
loudly when a declaration and a rendering disagree.

## 2. What is where

| Document | Path | Role |
| --- | --- | --- |
| Feature (domain) | `spec/03-approved/xap/demos/oriel/data/oriel.feature.cxd` | nouns with fields/labels/docs, verbs with intent grammars, validity/ordering rules, grants |
| Surface (composition) | `spec/03-approved/xap/demos/oriel/surface.cx` | routes, `[offer verb=]` declarations, card specs, nav (P0-24) |
| Theme | `spec/03-approved/xap/demos/oriel/data/oriel-theme.cx` | every appearance decision: tokens, tones, `[palette scheme=]` groups (P0-104) |
| Service | `spec/03-approved/xap/demos/oriel/serve.cx` | folds, the command layer (`apply-intent`), page composition — **no view code** |
| Session seam | `spec/03-approved/xap/demos/oriel/session.cx` | visitor cookie ↔ visitor key (P0-70, N-SESSION-5) |
| Terminal shell | `spec/03-approved/xap/demos/oriel/tui.cx` | a real client of the same server, over the same wire |
| Catalogue | `spec/03-approved/xap/demos/oriel/data/catalog.cxd` | reference data — a document, not a journal |
| Instruments | `spec/03-approved/xap/demos/oriel/{drive,keys,voice,nokernel,diff,bench}.cx` | §5 below |

---

## 3. Quickstart

### 3.1 Build

```bash
devbox run make -C vcx build
```

Produces `./vcx/target/cx` (~2 minutes). Every command below uses that binary —
the `x/*.cx` packs (including `cx-x/ux`) are embedded in it, so after any
`x/` change you must rebuild before the change exists.

### 3.2 Boot the store

```bash
./vcx/target/cx --allow-read --allow-net --allow-clock --allow-random spec/03-approved/xap/demos/oriel/serve.cx
```

A healthy boot logs, in order:

```
info ORIEL: surface and service agree
info ORIEL: catalogue 1004 products, 14 hint claims
```

The first line is `[$ux:check-surface]` — the compose-time gate that refuses a
declared verb no route accounts for (see the micro-example in §6 for what the
refusal looks like). Then browse **http://127.0.0.1:8790/**.

### 3.3 The terminal face

From a second terminal (it needs a real tty):

```bash
./vcx/target/cx --allow-read --allow-net=127.0.0.1:8790 --allow-clock --allow-random --allow-write --allow-env spec/03-approved/xap/demos/oriel/tui.cx
```

This is a separate process and a genuine client: it fetches the semantic tree
over HTTP (`Accept: application/cx`), renders it with `cx-x/ux-tui`, posts to
the same `/intent/<verb>` wire, and rides the same SSE topic. `CX_UX_BASE`
retargets it; `CX_UX_ROUTE` picks the opening route; `q` quits.

### 3.4 The six instruments

All are headless; all but `diff` and `bench` need the store running. **The
grants are exact and failure without them is misleading**: a bare
`--allow-net` denies the loopback literal and every step then fails as
`offline` while the server is demonstrably up — grant `--allow-net=127.0.0.1:8790`.

```bash
# drive — journeys + three-face equivalence, 38 steps
./vcx/target/cx --allow-read --allow-net=127.0.0.1:8790 --allow-write --allow-clock --allow-random spec/03-approved/xap/demos/oriel/drive.cx
```

```bash
# keys — the real shell on a real pty at a stated size, 9 steps
./vcx/target/cx --allow-read --allow-subprocess --allow-net=127.0.0.1:8790 --allow-write --allow-clock --allow-random --allow-env spec/03-approved/xap/demos/oriel/keys.cx
```

```bash
# voice — the third renderer: serial utterances from the content normal form, 5 checks
./vcx/target/cx --allow-read --allow-net=127.0.0.1:8790 --allow-write --allow-clock --allow-random spec/03-approved/xap/demos/oriel/voice.cx
```

```bash
# nokernel — plain GETs and real forms only: the degrade-don't-die walk, 3 checks
./vcx/target/cx --allow-read --allow-net=127.0.0.1:8790 --allow-write --allow-clock --allow-random spec/03-approved/xap/demos/oriel/nokernel.cx
```

```bash
# diff — computes "zero view code" instead of asserting it (no server needed)
./vcx/target/cx --allow-read --allow-write spec/03-approved/xap/demos/oriel/diff.cx
```

```bash
# bench — measures and reports; run on a quiet machine or the numbers are garbage
./vcx/target/cx --allow-read --allow-clock --allow-write spec/03-approved/xap/demos/oriel/bench.cx
```

Expected verdict lines: `DRIVE: all steps passed`, `KEYS: all steps passed`,
`VOICE: all steps passed`, `NOKERNEL: all steps passed`. `diff` reports
per-file appearance-decision counts — the theme is the only file allowed a
nonzero colour/px count — and a card `drift='0'` line. `bench` reports
microsecond timings per stage; treat any run on a loaded machine (or a
non-release build) as noise, and compare only against timings from the same
machine and build flags.

### 3.5 Live demo — two tabs, one basket (pushed, not polled)

State follows the session, and one browser is one visitor (spec §11 / P0-100),
so two tabs in the same browser are the same shopper:

1. Open **http://127.0.0.1:8790/c/coffee/beans** in two tabs of the same browser.
2. In tab one, click **Add to basket** on any card.
3. Watch tab two: the **Basket** badge in the top bar changes — no reload, no
   poll. The server published `basket-changed` on the visitor's own stream and
   the badge anchor took the push (P0-44).

The same proof without a browser, in two terminals — mint a session, hold its
stream open, then write to the basket **as that visitor**:

```bash
SID=$(curl -si http://127.0.0.1:8790/ | grep -i '^set-cookie' | cut -d= -f2 | cut -d';' -f1)
echo $SID   # keep this for the second terminal
curl -N -H "Cookie: __Host-oriel-sid=$SID" http://127.0.0.1:8790/stream
```

```bash
curl -s -o /dev/null -H "Cookie: __Host-oriel-sid=<SID from above>" -d 'sku=CB-0825&qty=1' http://127.0.0.1:8790/intent/add-to-basket
```

The first terminal greets with `data: ready` on connect, then prints the push,
payload = the badge's route-neutral words:

```
event: basket-changed
data: Basket · 1 item · $41.25
```

### 3.6 Live demo — the open drawer refetches itself

1. In tab two, click the **Basket** badge — the drawer opens and the URL gains
   `?basket=open` (the open drawer is a *state with a URL*, P0-78).
2. In tab one, add a product or change a quantity.
3. Tab two's open drawer redraws with the new line — it listened for
   `basket-changed` and refetched `/basket/aside` itself. It refetches rather
   than taking a pushed fragment because route-scoped fragment identity (P0-9)
   forbids pushing another page's targets; the badge *can* take the push
   directly, so it does. Both listeners are declared in the tree (`live=`),
   not wired in script.

### 3.7 Live demo — browser and terminal as the same shopper

Two clients are two visitors *by design*, so sharing a shopper is explicit:
the cookie value **is** the session id (N-SESSION-5), and `CX_UX_SID` hands it
to the shell.

1. In the browser, open DevTools → Application (Firefox: Storage) → Cookies →
   copy the value of `__Host-oriel-sid`.
2. Start the terminal face as that visitor:

```bash
CX_UX_SID=<the cookie value> ./vcx/target/cx --allow-read --allow-net=127.0.0.1:8790 --allow-clock --allow-random --allow-write --allow-env spec/03-approved/xap/demos/oriel/tui.cx
```

3. Add to the basket in the **browser**. The terminal repaints on the push —
   same basket, same badge words, different face. (The shell subscribes to
   `/stream` carrying that same cookie; without it, it would subscribe to its
   own — different — visitor's silence.)

### 3.8 The re-skin — light and dark with zero markup (P0-104)

The theme document declares two `[palette scheme=]` token groups; the emitter
writes the light set on `:root` and the dark set under
`prefers-color-scheme: dark`. Nothing else changes — not one view file, not
one markup decision:

1. With any store page open, switch the OS appearance (macOS: System Settings
   → Appearance; or emulate in DevTools → Rendering → prefers-color-scheme).
2. The page re-skins live: the warm-paper light palette swaps for the warm-ink
   dark one, accents flip polarity, shadows deepen — every one of those words
   is a token in `spec/03-approved/xap/demos/oriel/data/oriel-theme.cx` and nowhere else.

Verify from the wire that both palettes ride one stylesheet:

```bash
curl -s http://127.0.0.1:8790/static/ux.css | grep -c 'prefers-color-scheme'
```

prints `1`.

---

## 4. The ORIEL way — the four documents

### 4.1 Declare the domain: the feature document

`spec/03-approved/xap/demos/oriel/data/oriel.feature.cxd` is the model artifact. Everything on screen
is a projection of it — *"if the store shows something this document does not
declare, that is a bug in the store"* (its own header). It declares:

- **nouns** with typed fields, customer-word `label=`s and `doc=` strings —
  forms, cards, table columns and spoken labels are all derived from these;
- **verbs** with `effect=act|observe`, `scope=`, `consequence=` and an
  **intent grammar** (`[intent [do :add-to-basket [sku] [qty]]]`) — the
  parameters a control must carry (P0-56) come from here;
- **rules** (`kind=validity`, `kind=ordering`) — stated once; the command
  layer enforces them and the projection never restates them (P0-17);
- **grants** — who may invoke which verb (visitor vs customer).

What you do *not* put here: anything about pages, layout, or appearance.

### 4.2 Compose the surface: the surface document

`spec/03-approved/xap/demos/oriel/surface.cx` decides **what is on a page**, never what it
looks like (P0-24). Its parts:

- `[route path=…]` — every meaningful state has a URL (P0-78): the basket,
  each checkout step, a confirmation, even the open drawer (`?basket=open`).
- `[offer verb=…]` — the route's own statement of which invokable verbs a
  customer can reach from it. This is not decoration; it is what the boot
  gate (`[$ux:check-surface]`, a compose-time refusal) and the coverage
  instrument (drive steps 29/30) hold the rendered tree to. A verb nobody
  offers needs a `[not-offered verb=… why=…]` with an honest why.
- `[card noun=… shows=… action=…]` — a route-level presentation *pick*:
  which of the noun's declared fields a card shows and what acting on it
  means. Deliberately per-route, deliberately unshared.

### 4.3 The service: folds, commands, composition

`spec/03-approved/xap/demos/oriel/serve.cx` holds exactly three kinds of code:

- **folds** — journal streams to values: the basket from `cart:<vk>`,
  subscriptions from `subs:<vk>`, reviews from `reviews:<sku>` (state lives in
  the stream of its *owning aggregate*, P0-100; the visitor key derivation is
  P0-70/P0-77);
- **the command layer** — `apply-intent`, one arm per verb: enforce the rules,
  append the event, answer in the customer's words or refuse with an err the
  faces will render (refusal-first — a refusal is content, not a log line);
- **page composition** — assembling `ux:` vocabulary elements per route and
  handing them to the projection. `ux:action`, `ux:form`, `ux:panel`,
  `ux:quantity` — members of the closed vocabulary (P0-98: unknown members
  *and unknown attributes* refuse), never HTML, never a class name.

One wire serves every face: a route answers HTML or the semantic tree by
content negotiation, a POST answers fragments or a 303 **and the request
chooses** (P0-80) — which is why the store works with the kernel scripts
absent (P0-81, proven by `nokernel.cx`).

### 4.4 The theme: where appearance lives

`spec/03-approved/xap/demos/oriel/data/oriel-theme.cx` is the only file allowed an appearance
decision, and `diff.cx` counts them to keep it that way. Tones are *meanings*
(`tone=danger` says "this is bad"); what bad looks like is decided here per
face — a hex token on the web, an SGR parameter in the terminal.

---

## 5. The instruments — what each one proves

| Instrument | Proves | Refuses when |
| --- | --- | --- |
| `drive.cx` (38 steps) | journeys work end to end **and** the three canonical forms agree (semantic == web == terminal) per route; every declared offer is a reachable control (29); every act verb is offered or honestly declined (30); liveness is pushed, not polled (35) | any face disagrees, any offer is uncovered, any refusal goes silent |
| `keys.cx` (9 steps) | what a person at a real 110×36 terminal actually sees — the real shell, a real pty, real keystrokes, frame-by-frame | a frame overflows the window, focus leaves the visible frame, a keystroke's promise isn't in the next frame |
| `voice.cx` (5 checks) | the renderer-agnostic claim: a serial face consuming only the content normal form can speak all thirteen live routes | any vocabulary member is unspeakable (`UNSPOKEN:<name>` — a loud utterance, never a silent drop) |
| `nokernel.cx` (3 checks) | the MPA degrades rather than dies: every href answers, every form posts to a declared intent, counts reported | a dead link, an undeclared form target, a silently thinner walk |
| `diff.cx` | zero view code, computed: appearance-decision counts per file; card derivation drift | a colour/px/class/markup decision appears outside the theme |
| `bench.cx` | measured cost per stage (parse, narrow, project, render, readback, fold), reported not asserted | nothing — it reports, including where the numbers are bad |

Two standing rules. **Goldens move only by generator**: the ux conformance
fixtures are derived by `design/787/tools/gen_ux_fixtures.cx` (run from the
repo root with `--allow-read --allow-write --allow-subprocess --allow-env`);
hand-editing an expected output is how a projection bug gets enshrined, and a
case the generator does not carry is a case the next run deletes. And after any
`x/ux*.cx` change, run `make test-vcx-suite` — that is the lane that catches a
changed golden.

---

## 6. Worked micro-example: `save-for-later`

One new noun and verb, added the ORIEL way. Each stage below was actually run;
the outputs are pasted from those runs. The point of the stages is that **the
system refuses at each gap until the work is whole** — the instruments drag
you forward.

### Stage 1 — declare the domain, and let the boot refuse

Three additions to `oriel.feature.cxd`:

```
[noun name=saved-item
 [summary 'Something set aside to decide on later.']
 [field name=sku  type=text label='Item']
 [field name=name type=text label='Product']
 [field name=at   type=text label='Saved' doc='when it was set aside']]
```

```
[verb name=save-for-later effect=act scope=session consequence=reversible
 [summary 'Set this aside to decide on later.']
 [intent [do :save-for-later [sku]]]
 [writes saved-item]]
```

```
[grant verb=save-for-later to=visitor]
```

Boot the store. The compose-time gate refuses, by name:

```
error ORIEL: surface refused — ([err code=ux-refused '([ux-refusal code=ux-verb-unaccounted verb=save-for-later])']
```

A verb now exists that no route offers and nothing honestly declines. The
domain is ahead of the surface, and the system says so before a customer can.

### Stage 2 — declare the offer, and let the instrument demand the control

One line on the product route in `surface.cx`:

```
[route path="/p/:sku"
  [feature xap=oriel as=product]
  [offer verb=add-to-basket] [offer verb=subscribe] [offer verb=write-review]
  [offer verb=save-for-later]]
```

Boot agrees (`info ORIEL: surface and service agree`). Run `drive.cx`:

```
[step name='29 every declared offer is a control on its route' ok=FAIL detail='11 offering routes walked into their states; 1 uncovered']
[step name='30 every invokable verb is offered somewhere or declares why not' ok=PASS detail='15 act verbs; 15 offered, 0 declared not offered with a why; 0 unaccounted']
DRIVE: 1 FAILED
```

The offer is a promise, and step 29 walked the product page and found no
control keeping it. Note step 30 already counts 15 — the declarations are
consistent; the *rendering* is what lags.

### Stage 3 — wire it: an arm, a control, a fold, a panel

Four additions to `serve.cx`, and this is everything — note what is *not*
among them.

**The command arm** (in `apply-intent` — rules and the event, nothing else):

```
[case "save-for-later"
  [?if [not [$ux:found $prod]]
    [then [err code=cx-err:CXER0160 message="That item code is not in the catalogue."]]
    [else
      [?let [= $_a [$journal:append $j
                     [saved [?attr "sku" $sku]
                            [?attr "name" [$ux:str-or $prod@name ""]]
                            [?attr "at" $now]]
                     {actor: "visitor", authority: "anonymous-floor", stream: [$saved-stream $vk]}]]
        [$concat "Saved for later — " [$string $prod@name] "."]]]]]
```

**The control** (on the product page, after the buy block — vocabulary, not
markup):

```
[ux:action [?attr "verb" "save-for-later"] [?attr "label" "Save for later"]
  [ux:param [?attr "name" "sku"] [?attr "value" $sku]]
  [ux:param [?attr "name" "return"] [?attr "value" $self]]]
```

**The fold** (a stream name and the simplest fold in the file):

```
[?def saved-stream pure [returns string] ($vk::string) [$concat "saved:" $vk]]

[?def saved-of impure [returns any] ($j::element $stream::string)
  [?let
    [= $box [sv [?splice [?for [in $ev [$basket-events $j $stream]]
                           [= $b [$event-body $ev]]
                           [where [= [$name $b] "saved"]]
                           [yield $b]]]]]
    [$reverse [$ux:child-elements $box "saved"]]]]
```

**The reading place** (a declared panel on `/account`, plus an item row and
the two-line callsite change passing `[$saved-of …]` in):

```
[ux:panel [?attr "name" "saved"] [?attr "label" "Saved for later"]
  [?splice [$opt [$ux:absent $saved]
             ([ux:text "Nothing set aside yet. Every product page offers it."])
             ([ux:list [?splice [?for [in $s $saved] [yield [$saved-item-row $s]]]]])]]]
```

Now everything is green — `drive` 38/38 with step 29 back to `0 uncovered` and
step 30 at `15 act verbs; 15 offered`; `keys` 9/9; `voice` 5/5; `nokernel`
now counts **13** distinct form actions (it found the new form and checked the
verb was declared). And the wire works end to end:

```
$ curl -s -o /dev/null -w "%{http_code} -> %{redirect_url}\n" -H "Cookie: __Host-oriel-sid=$SID" \
    -d 'sku=CB-0825&return=/p/CB-0825' http://127.0.0.1:8790/intent/save-for-later
303 -> http://127.0.0.1:8790/p/CB-0825
$ curl -s -H "Cookie: __Host-oriel-sid=$SID" http://127.0.0.1:8790/account | grep -o 'Saved for later\|CB-0825' | sort -u
CB-0825
Saved for later
```

### What was composed, and what was derived

Written by hand (~60 lines across three files):

- the noun, the verb, the grant — *domain declarations*;
- the offer — *one line of composition*;
- the command arm, the fold, the control placement, the panel — *service*.

Derived — none of this was written, all of it appeared:

- the **web form**: a real `<form>` posting to `/intent/save-for-later`,
  styled by the theme, working with scripts disabled;
- the **terminal face**: a focus stop on the product page, invokable from the
  keyboard, and a titled "Saved for later" panel box on the account frame;
- the **voice face**: the control spoken with its label, in reading order;
- **labels everywhere** from the noun's `label=`s;
- the **acknowledgement**: "Saved for later — Ridge 250 g filter roast." rides
  the 303 as a one-shot notice and is announced on all three faces;
- **refusals rendered**: the unknown-sku err comes back as visible content in
  the customer's words, on whichever wire asked;
- the **policing**: the boot gate, drive 29/30 and nokernel N2 now hold this
  verb to its promises forever.

No conformance golden moved — the example composes existing vocabulary
members. (Adding a *vocabulary member* is a different, spec-gated act — see
the Phase 0 spec's vocabulary rules, P0-98.)

The three stages were then reverted; ORIEL ships without `save-for-later`.
The full diff is reproducible from the snippets above.

---

## 7. Where the law lives

- **The Phase 0 spec** — `design/787/787-phase0-spec.md`: the projection
  vocabulary, session state, hypermedia patterns, store patterns,
  accessibility, money (`P0-1 … P0-104`). The clauses this guide leaned on
  most: P0-24 (composition), P0-56 (intents from collection items), P0-78
  (states have URLs), P0-80 (the request chooses fragments or 303), P0-81
  (no-kernel degrade), P0-98/P0-99 (closed vocabulary; availability with
  reasons), P0-100 (state in the owning aggregate's stream), P0-44
  (liveness by declaration), P0-104 (palettes).
- **Wave records** — `design/787/w8/ … w25/README.md`: the decision records,
  including every dead end. Decision records are not teaching documents;
  that is what this guide is for. But when you need *why*, they are the why.
- **Audit records** — `design/787/AUDIT-2026-08-18.md`,
  `design/787/audit2/AUDIT.md`: what an adversarial pass looks like against
  this kind of surface, and the one failure family it kept finding (silent
  acceptance).
- **Rulings** — `ledger/` at the repo root, notably
  `rulings_2026_08_19_787_guide_and_packaging.md` (this guide, and ORIEL's
  promotion) and `rulings_2026_08_19_787_integration.md` (the rebase onto
  `release/0.16.0`, and how fixture collisions were adjudicated).
