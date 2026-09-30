# The customization model: what one tenant may change — v0.18.0-pre.1

> **GENERATED.** Source: `docs-src/llm/model-customization.md.tmpl` + the
> conformance corpus. Every code block is a fixture and every output was
> re-recorded from the `cx` v0.18.0-pre.1 binary at generation time. Where a
> claim rests on a file in the repository rather than on a fixture, the file
> and line are cited and **the citation is the evidence**. Where a mechanism
> does not exist yet, this document says so in the same voice — §6 is a list
> of gaps, not a list of features.

Read `primer.md` first for the language and `playbook-xap.md` for how a
deployment is assembled. This document answers a different question, and it is
the one an adopter asks first:

> **What may be changed for one tenant, what must change for everyone, and
> why?**

## 0. The answer in one sentence

**A tenant customizes its surface and its contract; it never customizes
behaviour — so one release reaches every tenant, and the toolchain can say in
advance which tenants it breaks.**

Every refusal you will meet is that sentence being enforced. This matters
because the refusals are the product. Met one at a time — `CXER4877`,
`CXER4878`, `CXER4879`, `:unservable-verb` — they read as friction, and the
natural response is to route around them. Read as one model, they are the
reason a fleet upgrade is a replay instead of a merge.

The comparison an adopter will reach for is the metadata-driven platform that
held this same line **by policy** and eventually opened a side door under
customer pressure. CX holds it in the toolchain, which is stronger — but only
if you know it is the line before your first client asks for a custom verb.

Two planes, and they behave differently. Keep them apart:

| | **Surface plane** | **Grammar plane** |
|---|---|---|
| What a tenant edits | arrangement, presentation, look and feel | a **contract**: renames, additions, narrowings, withdrawals |
| The unit | journaled commands over a base document | an `[instance …]` binding document |
| How a vendor change arrives | adopt a new base, **replay** the tenant's commands | move the `of=` pin, **re-instantiate** |
| Granularity of failure | per command: clean / drifted / refused | **all-or-nothing** per instance |
| Authority | `ux.md` §18–§19 | `xap_grammar_composition.md` §4.3 |

## 1. What you build once, and what a tenant may change

### 1.1 The surface plane — exactly four planes, each a document

`ux.md:1861` is normative and worth quoting exactly:

> **[P0-114] Everything a studio edits is one of exactly four planes, and
> each plane is a document — never code, never markup.**

| Plane | The document | The commands a tenant issues |
|---|---|---|
| **Arrangement** | a `[ux:layout]` base document + its journaled command stream | `ux:move` · `ux:wrap` · `ux:place` · `ux:remove` |
| **Presentation & content** | the same layout document (hint and param children) | `ux:set-hint` · `ux:set-param` |
| **Look and feel** | the theme token document | the theme write (`ux.md:521`, `[P0-112]`) |
| **Automations** | the tenant's automation stream — a skeleton, its answers and the filled flow document by address | `ux:automate` · `ux:retire-automation` (`ux.md` §18.8, `[P0-130]`) |

What is deliberately **not** a plane: *"markup, CSS, and component internals"*
(`ux.md:1870`). And nothing is stored flattened — `ux.md:1878` — *"The
rendered arrangement is `fold(base, commands)` — recomputed, never a saved
copy."* That is not an implementation detail; it is the entire reason an
upgrade can exist. A forked document cannot be replayed onto a new base. A
command stream can.

A move touches what it addresses and nothing else, and a command addressing an
element that is not there refuses rather than guessing:

`prog.cx`
```cx
[?lib 'cx-platform/ux' :as ux]
[?let
  [= $comps ([component name=hero], [component name=departments], [component name=promo], [component name=group container=true])]
  [= $l0 [ux:layout [placed id=hero component=hero] [placed id=promo component=promo] [placed id=depts component=departments]]]
  [= $l1 [$ux:layout-apply $l0 [ux:move id=depts parent="" before=hero] $comps]]
  [list [$cx:canonical $l1] [$ux:layout-hint $l1 promo tone]]]
```

```console
$ cx prog.cx
[list '[ux:layout\n  [placed id=depts component=departments]\n  [placed id=hero component=hero]\n  [placed id=promo component=promo]\n]\n' '']
```

`prog.cx`
```cx
[?lib 'cx-platform/ux' :as ux]
[?let
  [; R-A1 migration: envelope → spliced children (2026-08-25) ]
  [= $comps ([component name=hero])]
  [= $l0 [ux:layout [placed id=hero component=hero]]]
  [= $r [$ux:layout-apply $l0 [ux:move id=ghost parent="" before=""] $comps]]
  [$cx:canonical ($r)]]
```

```console
$ cx prog.cx
'([err code=ux-refused\n  [ux-refusal code=ux-layout-address-miss id=ghost]\n]\n)\n'
```

Every command has an inverse, and the round trip is byte-identical — which is
what makes an edit stream auditable and reversible rather than a diff:

`prog.cx`
```cx
[?lib 'cx-platform/ux' :as ux]
[?let
  [= $comps ([component name=hero], [component name=featured], [component name=promo], [component name=group container=true])]
  [= $l0 [ux:layout [placed id=hero component=hero] [placed id=featured component=featured]]]
  [= $rt [?fn ($cmd)
           [?let [= $inv [$ux:layout-inverse $l0 $cmd]]
             [= [$cx:canonical [$ux:layout-apply-batch [$ux:layout-apply $l0 $cmd $comps] $inv $comps]]
                [$cx:canonical $l0]]]]]
  [list [$rt [ux:move id=featured parent="" before=hero]]
        [$rt [ux:set-hint id=hero hint=tone value=info]]
        [$rt [ux:place id=promo component=promo parent="" before=""]]
        [$rt [ux:wrap id=hero wrapper=g1 component=group]]
        [$rt [ux:remove id=hero]]]]
```

```console
$ cx prog.cx
[list true true true true true]
```

A batch is atomic, so a tenant never lands half an edit:

`prog.cx`
```cx
[?lib 'cx-platform/ux' :as ux]
[?let
  [= $comps ([component name=hero])]
  [= $l0 [ux:layout [placed id=hero component=hero]]]
  [; R-A1 migration: envelope → spliced children (2026-08-25) ]
  [= $r [$ux:layout-apply-batch $l0 ([ux:set-hint id=hero hint=tone value=info], [ux:remove id=ghost]) $comps]]
  [$cx:canonical ($r)]]
```

```console
$ cx prog.cx
'([err code=ux-refused\n  [ux-refusal code=ux-layout-address-miss id=ghost]\n]\n)\n'
```

Content and presentation are the same closed discipline — an undeclared param
name refuses:

`prog.cx`
```cx
[?lib 'cx-platform/ux' :as ux]
[?let
  [; R-A1 migration: envelope → spliced children (2026-08-25) ]
  [= $comps ([component name=hero [param name=heading default="Everyday things." carrier=ux-heading]],
             [component name=promo [param name=text default="A note." carrier=ux-text]])]
  [= $l0 [ux:layout [placed id=hero component=hero] [placed id=promo component=promo]]]
  [= $c1 [ux:set-param id=hero param=heading value="Made properly."]]
  [= $l1 [$ux:layout-apply $l0 $c1 $comps]]
  [= $r1 [$ux:layout-apply $l0 [ux:set-param id=hero param=nonesuch value=x] $comps]]
  [= $inv [$ux:layout-inverse $l0 $c1]]
  [= $l2 [$ux:layout-apply-batch $l1 $inv $comps]]
  [list [$cx:canonical $l1]
        [$ux:layout-param $l1 hero heading]
        [$cx:canonical ($r1)]
        [= [$cx:canonical $l2] [$cx:canonical $l0]]
        [$cx:canonical [x [?splice [$ux:layout-inverse $l1 [ux:remove id=hero]]]]]]]
```

```console
$ cx prog.cx
[list "[ux:layout\n  [placed id=hero component=hero\n    [param name=heading value='Made properly.']\n  ]\n  [placed id=promo component=promo]\n]\n" 'Made properly.' '([err code=ux-refused\n  [ux-refusal code=ux-layout-unknown-param id=hero param=nonesuch]\n]\n)\n' true "[x\n  [ux:place id=hero component=hero parent='' before=promo]\n  [ux:set-param id=hero param=heading value='Made properly.']\n]\n"]
```

And look-and-feel is a token document compiled to a stylesheet, where an
unsafe value refuses **the whole sheet** rather than emitting a partial one:

`prog.cx`
```cx
[?lib 'cx-platform/ux' :as ux]
[?lib 'cx-platform/ux-web' :as web]
[?let
  [; R-A1 migration: envelope → spliced children (2026-08-25) ]
  [= $ok  [ux:theme [token name=bg value="#111"] [token name=fg value="white"]]]
  [= $bad [ux:theme [token name=bg value="red;} body{display:none"]]]
  ([$web:token-value-safe "#111"], [$web:token-value-safe "red;}"],
   [$web:theme-refusals $bad], [$web:theme-css $bad])]
```

```console
$ cx prog.cx
(true, false, [ux-refusal code=ux-bad-token-value token=bg], [err code=ux-refused [ux-refusal code=ux-bad-token-value token=bg]])
```

The closed command set is doing load-bearing work here. `ux.md:2154` states
why: *"A closed set is analyzable, which is what makes [P0-120]'s fleet
preflight possible at all… Free CSS is not analyzable, which is why theme-fork
platforms make upgrades the client's problem."*

### 1.2 The grammar plane — four refinements, and removal cannot be spelled

A tenant's variant of someone else's feature is an `[instance …]` binding
document. `xap_grammar_composition.md:330` calls it *"The refinement contract
— four verbs admitted, everything else structurally impossible"*:

| Refinement | What it may do |
|---|---|
| `[rename]` | `label` / `doc` / `summary` of a named noun, field or verb. **Names of record are not renameable** — the vocabulary has no slot for it |
| `[add]` | new fields on existing nouns, new verbs, new rules. Adding is always a narrowing in this rule model; an added name **must not collide** with an inherited one |
| `[tighten]` | move **up** the rank lattice only — scope may narrow, consequence may rise, effect may strengthen |
| `[select]` | the subsetting vocabulary (`offer` / `not-offered`-with-`why`). Selection is a narrowing and **binds every consumption point** |

The schema is the same list, and it is deliberately the whole vocabulary
(`spec/03-approved/xap/xap_schemas/instance.cxs:18-26`). Note what is absent:
*"Removal is not refused because it cannot be spelled: the binding vocabulary
has no remove"* (`xap_grammar_composition.md:359`).

All four at once, with the pin computed in-case — which is also the
demonstration that `of=` is derivable rather than magic:

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?lib 'cx-stdlib/hash' :as hash]
[?lib 'cx-stdlib/bytes' :as bytes]
[?let [= $arch
  [feature name=stamp version="1"
   [nouns [noun name=mark [field name=id type=text] [field name=note type=text label='Note']]]
   [verbs [verb name=press effect=act scope=shared consequence=reversible [intent [do :press [id]]] [writes mark]]
          [verb name=see effect=observe [intent [do :see]] [reads mark]]]
   [rules [rule name=see-after-press kind=ordering verb='stamp/see' after='stamp/press'
           [statement 'You can only see a mark that was pressed.']]]
   [requirements [requirement kind=functional as=user traces=press [want 'to press'] [so 'pressed']]]]]
 [= $pin [$concat "sha2-256:" [$bytes:to-hex [$hash:sha256-string [$cx:canonical $arch]]]]]
 [= $eff [$xap:instantiate $arch
   [instance name=wax-seal of=$pin
    [rename field='mark/note' label='Inscription']
    [add on=mark [field name=colour type=text]]
    [tighten verb=press consequence=irreversible]
    [select [offer verb=press] [not-offered verb=see why='Seals are inspected by the registrar.']]]]]
 [= $r [$xap:compose-report $eff]]
 [probe [name [$string $eff@name]]
        [cq [?for [in $v $eff//verb] [where [= [$string $v@name] "press"]] [yield [$string $v@consequence]]]]
        [rule [?for [in $ru $eff//rule] [yield [$string $ru@verb]]]]
        [fields [$count $eff//field]]
        [sel [$count $eff//selection]]
        [prov [$count $eff//instantiated-from]]
        [composes [$string $r@ok]]]]
```

```console
$ cx prog.cx
[probe [name wax-seal] [cq irreversible] [rule wax-seal/see] [fields 3] [sel 1] [prov 1] [composes 'true']]
```

An instance may also add views onto a noun it inherited:

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?lib 'cx-stdlib/hash' :as hash]
[?lib 'cx-stdlib/bytes' :as bytes]
[?let [= $arch
  [feature name=stamp version="1"
   [nouns [noun name=mark [field name=id type=text] [field name=note type=text]]]
   [verbs [verb name=see effect=observe [intent [do :see]] [reads mark]]]
   [requirements [requirement kind=functional as=user traces=see [want 'to see'] [so 'seen']]]]]
 [= $pin [$concat "sha2-256:" [$bytes:to-hex [$hash:sha256-string [$cx:canonical $arch]]]]]
 [= $eff [$xap:instantiate $arch
   [instance name=wax-seal of=$pin
    [add on=mark [views [sort field=id] [hidden field=note]]]]]]
 [= $r [$xap:compose-report $eff]]
 ([$string $eff//views/sort/@field], [$string $eff//views/hidden/@field], [$string $r@ok])]
```

```console
$ cx prog.cx
(id, note, 'true')
```

### 1.3 What is refused, and the one-sentence reason for each

| Refusal | Raised when | The reason, in one sentence |
|---|---|---|
| `CXER4877` `E_XAP_ARCHETYPE_REPURPOSE` | an `[add]` collides with an inherited name, or a refinement names a member the archetype does not declare | a tenant may extend the vocabulary, never redefine a word already in it |
| `CXER4878` `E_XAP_ARCHETYPE_LOOSEN` | a `[tighten]` widens any axis | substitutability — an instance must be usable everywhere its archetype is |
| `CXER4879` `E_XAP_INSTANCE_INVALID` | `of=` does not match the archetype document presented | an instance derives from an **exact** base, never from "whatever the vendor ships today" |
| `CXER4864` `E_XAP_VERB_NOT_OFFERED` | a withdrawn verb is uttered | a withdrawal is a real narrowing, not a hidden verb — and it is deliberately distinct from "no such verb" |

Repurposing an inherited name:

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?lib 'cx-stdlib/hash' :as hash]
[?lib 'cx-stdlib/bytes' :as bytes]
[?let [= $arch
  [feature name=stamp version="1"
   [nouns [noun name=mark [field name=id type=text]]]
   [verbs [verb name=press effect=act [intent [do :press [id]]] [writes mark]]]
   [requirements [requirement kind=functional as=user traces=press [want 'to press'] [so 'pressed']]]]]
 [= $pin [$concat "sha2-256:" [$bytes:to-hex [$hash:sha256-string [$cx:canonical $arch]]]]]
 [$xap:instantiate $arch
   [instance name=x of=$pin
    [add [verb name=press effect=observe [intent [do :press]]]]]]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4877 message='E_XAP_ARCHETYPE_REPURPOSE: verb "press" is inherited — an [add] may not repurpose it (§4.3)' at='10:2']
```

Widening what was inherited. `xap_grammar_composition.md:358` is blunt about
the absence of an escape hatch: *"There is no escape hatch; the honest release
valve is authoring your own feature."*

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?lib 'cx-stdlib/hash' :as hash]
[?lib 'cx-stdlib/bytes' :as bytes]
[?let [= $arch
  [feature name=stamp version="1"
   [nouns [noun name=mark [field name=id type=text]]]
   [verbs [verb name=press effect=act scope=shared consequence=irreversible [intent [do :press [id]]] [writes mark]]]
   [requirements [requirement kind=functional as=user traces=press [want 'to press'] [so 'pressed']]]]]
 [= $pin [$concat "sha2-256:" [$bytes:to-hex [$hash:sha256-string [$cx:canonical $arch]]]]]
 [$xap:instantiate $arch
   [instance name=x of=$pin
    [tighten verb=press consequence=reversible]]]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4878 message='E_XAP_ARCHETYPE_LOOSEN: verb "press" consequence irreversible → reversible widens (§4.3)' at='10:2']
```

A refinement naming a field the archetype does not declare — the typo class,
caught at instantiation rather than at first render:

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?lib 'cx-stdlib/hash' :as hash]
[?lib 'cx-stdlib/bytes' :as bytes]
[?let [= $arch
  [feature name=stamp version="1"
   [nouns [noun name=mark [field name=id type=text]]]
   [verbs [verb name=see effect=observe [intent [do :see]] [reads mark]]]
   [requirements [requirement kind=functional as=user traces=see [want 'to see'] [so 'seen']]]]]
 [= $pin [$concat "sha2-256:" [$bytes:to-hex [$hash:sha256-string [$cx:canonical $arch]]]]]
 [$xap:instantiate $arch
   [instance name=wax-seal of=$pin
    [add on=mark [views [sort field=colour]]]]]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4877 message='E_XAP_ARCHETYPE_REPURPOSE: [add [views [sort field=colour]]] on "mark" names a field the archetype does not declare (§4.3/§4.5)' at='10:2']
```

A withdrawn verb refuses at resolution, **before** the policy check, and with
its own code:

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?lib 'cx-stdlib/hash' :as hash]
[?lib 'cx-stdlib/bytes' :as bytes]
[?let [= $arch
  [feature name=stamp version="1"
   [nouns [noun name=mark [field name=id type=text]]]
   [verbs [verb name=press effect=act scope=shared consequence=reversible [intent [do :press [id]]] [writes mark]]
          [verb name=purge effect=act scope=shared consequence=irreversible [intent [do :purge [id]]] [writes mark]]]
   [requirements [requirement kind=functional as=user traces=press [want 'to press'] [so 'pressed']]]]]
 [= $pin [$concat "sha2-256:" [$bytes:to-hex [$hash:sha256-string [$cx:canonical $arch]]]]]
 [= $eff [$xap:instantiate $arch
   [instance name=stamp of=$pin
    [select [not-offered verb=purge why='This deployment does not permit purging.']]]]]
 [= $g [$xap:compose $eff]]
 [= $q [$xap:resolve $g "stamp/purge"]]
 [= $b [$xap:resolve $g "purge"]]
 [= $ok [$xap:resolve $g "press"]]
 [probe [qualified [code $q@code] [verb $q@verb] [why $q@why]]
        [bare [code $b@code] [verb $b@verb]]
        [offered-verb $ok]]]
```

```console
$ cx prog.cx
[probe [qualified [code cx-err:CXER4864] [verb stamp/purge] [why This deployment does not permit purging.]] [bare [code cx-err:CXER4864] [verb stamp/purge]] [offered-verb stamp/press]]
```

A withdrawal removes a *verb*, not a *word* — a bare term still resolves
through another feature that offers one:

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?lib 'cx-stdlib/hash' :as hash]
[?lib 'cx-stdlib/bytes' :as bytes]
[?let [= $arch
  [feature name=stamp version="1"
   [nouns [noun name=mark [field name=id type=text]]]
   [verbs [verb name=press effect=act scope=shared consequence=reversible [intent [do :press [id]]] [writes mark]]
          [verb name=purge effect=act scope=shared consequence=irreversible [intent [do :purge [id]]] [writes mark]]]
   [requirements [requirement kind=functional as=user traces=press [want 'to press'] [so 'pressed']]]]]
 [= $vault
  [feature name=vault version="1"
   [nouns [noun name=slot [field name=id type=text]]]
   [verbs [verb name=purge effect=act scope=shared consequence=irreversible [intent [do :purge [id]]] [writes slot]]]
   [requirements [requirement kind=functional as=ops traces=purge [want 'to purge'] [so 'purged']]]]]
 [= $pin [$concat "sha2-256:" [$bytes:to-hex [$hash:sha256-string [$cx:canonical $arch]]]]]
 [= $eff [$xap:instantiate $arch
   [instance name=stamp of=$pin
    [select [not-offered verb=purge why='This deployment does not permit purging.']]]]]
 [= $g [$xap:compose $eff $vault]]
 [probe [purge [$xap:resolve $g "purge"]]
        [bare [?for [in $t $g//term] [yield [$string $t@name]]]]]]
```

```console
$ cx prog.cx
[probe [purge vault/purge] [bare 'press' 'purge']]
```

## 2. Why behaviour is not tenant-customizable

State this as the promise, not the limitation. `xap_grammar_composition.md`
§4.3 now says it normatively (**RULED: AD-10**, #1162): *instantiation is
contract-level by design.* A binding refines a contract — it selects, narrows
and renames what the archetype **already implements**. It does not carry code,
and the vocabulary has no slot for code: `[rename]`, `[add]`, `[tighten]` and
`[select]` are declarations about a grammar, not implementations of one.

Behaviour travels with a feature as its `<feature>.cx` module, and dispatch is
by feature name, so an instance is served by the **archetype's** module — the
one its `of=` pin resolves to.

The consequence you will actually meet: **an `[add]`ed verb that no
implementation can serve is admitted at instantiation and refused at the
surface.** `[add]` is one of the four refinements, so the instance may still
*declare* the verb. What may not happen is a surface **offering** it, because
that is where a declaration becomes a route a caller can reach.
`cx xap check-surface` reports it as `:unservable-verb` — *"a route offers a
verb no `<feature>.cx` module can serve"* (`vcx/cmd/xap_check_surface.v:49`;
exit 0 clean, 1 any problem). The rationale is carried in the generated
checker program itself, `vcx/cmd/xap_check_surface.v:213-216`:

> At the SURFACE, not at instantiate: §4.3 admits ADD of new verbs as one of
> its four refinement operations, so an instance may still DECLARE one. What
> may not happen is a surface OFFERING it, because that is where the promise
> becomes a route a caller can reach.

What this buys, stated as the value and not the mechanism: **one code path per
feature, one release for every tenant, and conflicts known before shipping.**
The ruling record is explicit that this was chosen as a *refusal* rather than
as a new capability — `ledger/rulings_2026_09_01_adoption_campaign.md:446`:
*"a DECLARATION THAT BINDS NOTHING becomes a refusal, not a new capability."*

So when a tenant genuinely needs new behaviour, the answer is §4 below: author
your own feature and compose it beside the shared one. That is a supported
path with a checked seam — not a workaround.

## 3. How change reaches a fleet — the grammar plane

Nothing propagates. A vendor publishing v2 does not move any instance.

The vendor ships v2 of a feature; a tenant's binding still pins v1; presenting
it the new archetype **refuses**, naming both addresses:

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?lib 'cx-stdlib/hash' :as hash]
[?lib 'cx-stdlib/bytes' :as bytes]
[?let [= $v1
  [feature name=thing version="1"
   [nouns [noun name=thing [field name=id type=text] [field name=label type=text]]]
   [verbs [verb name=create effect=act scope=shared consequence=reversible
           [intent [do :create]] [writes thing]]]
   [requirements [requirement kind=functional as=operator traces=create
                  [want 'to create a thing'] [so 'it exists in the record']]]]]
 [= $v2
  [feature name=thing version="2"
   [nouns [noun name=thing [field name=id type=text] [field name=label type=text]
                           [field name=retired-at type=instant]]]
   [verbs [verb name=create effect=act scope=shared consequence=irreversible
           [intent [do :create]] [writes thing]]]
   [requirements [requirement kind=functional as=operator traces=create
                  [want 'to create a thing'] [so 'it exists in the record']]]]]
 [= $pin1 [$concat "sha2-256:" [$bytes:to-hex [$hash:sha256-string [$cx:canonical $v1]]]]]
 [$xap:instantiate $v2 [instance name=asset of=$pin1 [rename noun=thing label='Asset']]]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4879 message='E_XAP_INSTANCE_INVALID: of= pins sha2-256:999a55929a571983e0909d5fa312c401857b3319c35f83918b6fd5ad817473bf but the archetype presented is sha2-256:0416a467110492c86d98f8597bfc2d51e0376ce75394fc0af33ad9aef93caf21 — an instance derives from an EXACT base (§4.3); re-bless by moving the pin deliberately' at='20:2']
```

The upgrade is one deliberate act — *"Re-bless, never silent propagation"*
(`xap_grammar_composition.md:372`): the binding's `of=` moves to the new
address and the instance re-instantiates, **with the whole contract re-checked
against the new base.** The tenant keeps its refinements and inherits the
vendor's additions:

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?lib 'cx-stdlib/hash' :as hash]
[?lib 'cx-stdlib/bytes' :as bytes]
[?let [= $v2
  [feature name=thing version="2"
   [nouns [noun name=thing [field name=id type=text] [field name=label type=text]
                           [field name=retired-at type=instant]]]
   [verbs [verb name=create effect=act scope=shared consequence=irreversible
           [intent [do :create]] [writes thing]]]
   [requirements [requirement kind=functional as=operator traces=create
                  [want 'to create a thing'] [so 'it exists in the record']]]]]
 [= $pin2 [$concat "sha2-256:" [$bytes:to-hex [$hash:sha256-string [$cx:canonical $v2]]]]]
 [= $reblessed [$xap:instantiate $v2
   [instance name=asset of=$pin2
    [rename noun=thing label='Asset']
    [add on=thing [field name=serial type=text]]
    [tighten verb=create consequence=irreversible]]]]
 [probe [name [$string $reblessed@name]]
        [fields [$count $reblessed//field]]
        [cq [?for [in $v $reblessed//verb] [where [= [$string $v@name] "create"]] [yield [$string $v@consequence]]]]
        [rebased [= [$string $reblessed//instantiated-from@archetype] $pin2]]]]
```

```console
$ cx prog.cx
[probe [name asset] [fields 4] [cq irreversible] [rebased true]]
```

And *"the gate holds at every generation"* is not decoration. A refinement
that was legal against v1 can become a widening against v2, and re-bless
refuses rather than lowering the vendor's new floor for one tenant:

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?lib 'cx-stdlib/hash' :as hash]
[?lib 'cx-stdlib/bytes' :as bytes]
[?let [= $v2
  [feature name=thing version="2"
   [nouns [noun name=thing [field name=id type=text] [field name=label type=text]]]
   [verbs [verb name=create effect=act scope=shared consequence=irreversible
           [intent [do :create]] [writes thing]]]
   [requirements [requirement kind=functional as=operator traces=create
                  [want 'to create a thing'] [so 'it exists in the record']]]]]
 [= $pin2 [$concat "sha2-256:" [$bytes:to-hex [$hash:sha256-string [$cx:canonical $v2]]]]]
 [$xap:instantiate $v2 [instance name=asset of=$pin2 [tighten verb=create consequence=reversible]]]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4878 message='E_XAP_ARCHETYPE_LOOSEN: verb "create" consequence irreversible → reversible widens (§4.3)' at='12:2']
```

The control proves the refusal is about the *base*, not the binding — the same
refinement against v1 is fine:

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?lib 'cx-stdlib/hash' :as hash]
[?lib 'cx-stdlib/bytes' :as bytes]
[?let [= $v1
  [feature name=thing version="1"
   [nouns [noun name=thing [field name=id type=text] [field name=label type=text]]]
   [verbs [verb name=create effect=act scope=shared consequence=reversible
           [intent [do :create]] [writes thing]]]
   [requirements [requirement kind=functional as=operator traces=create
                  [want 'to create a thing'] [so 'it exists in the record']]]]]
 [= $pin1 [$concat "sha2-256:" [$bytes:to-hex [$hash:sha256-string [$cx:canonical $v1]]]]]
 [= $ok [$xap:instantiate $v1 [instance name=asset of=$pin1 [tighten verb=create consequence=reversible]]]]
 [probe [legal-on-v1 [$string $ok@name]]
        [cq [?for [in $v $ok//verb] [where [= [$string $v@name] "create"]] [yield [$string $v@consequence]]]]]]
```

```console
$ cx prog.cx
[probe [legal-on-v1 asset] [cq reversible]]
```

Two rejected alternatives are on the record (`xap_grammar_composition.md:381`):
*"copy-with-provenance (a fork with a birth certificate); mutable `extends=`
(silent propagation)."* Both would have made the fleet story easier and the
guarantee empty.

Underneath, distribution supplies the immutability the pin relies on.
`xap_feature_distribution_market.md:480` — *"Released aliases are immutable
(re-pointing is a market-rule violation; consumers pin hashes anyway)"*. So a
new artifact is a new version, and a pin rollback is hash identity: "go back"
is exact rather than approximate. (Both are pinned by
`conformance/xap/xap-dist.cxd` cases `xap-dist-014-publish-released-alias-immutable`
and `xap-dist-020-pin-rollback-hash-identity`; they are cited by id rather than
inlined here because they mint an ed25519 keypair, and this document's code
blocks are replayed with no capability grants.)

Publishing itself also diffs the new version against the previous release —
`:482`, *"Schema lineage rides the publish (RULED: SEA-1)"*: publish compares
the two content trees' schema entries and classifies each change, so a
**derivable** change derives its lineage claim and its upcaster mechanically
while a **reinterpreting** one (an `int` that becomes a `string`) **refuses the
publish** with `CXER4890` (`:488`). That is the nearest thing the grammar plane
has to a preflight — but note what it is not: it runs **at publish, against
schema history**, not per tenant against tenant bindings. See §6.2.

## 4. How change reaches a fleet — the surface plane

Here the mechanism is a replay, and `ux.md:1934` gives the reason it can be
one: *"improvements and customizations live at different cascade levels and in
different documents, so 'upgrade' is a replay, never an overwrite."*

`[P0-119]` (`ux.md:1938-1947`) names **three deliberately separate deploy
channels**:

1. **Code** — *"Improves every client on deploy with no per-tenant state,
   because no client owns markup."*
2. **Vendor documents** — content-addressed; *"each tenant is pinned to a
   version and moves only by an explicit act."*
3. **The tenant's own streams** — *"Never rewritten by an upgrade."*

Adopting a new base is itself a journaled act with a preflight, and
`[P0-120]` (`ux.md:1954`) classifies every replayed command:

| Class | Meaning |
|---|---|
| **clean** | applies |
| **drifted** | applies, but its neighborhood changed — reported |
| **refused** | its target is gone |

A dry run produces that classification without committing. Two sentences carry
the value: *"the same replay runs across the whole fleet before release — the
vendor learns which tenants break, and on which command, before shipping"*
(`ux.md:1962`), and *"A refused customization is presented to its owner as a
decision (re-place it, or drop it); no upgrade path may silently discard one"*
(`ux.md:1965`).

Breaking vendor changes ship **migration commands in the same act**; unmigrated,
they refuse rather than degrading (`ux.md:1968`).

The layering an adopter is operating in is §19.3's: platform (CX) → **vendor
(you)** → tenant (your client) → surface (one deployment). *"An adopter's
release is therefore a versioned vendor bundle, each client pinned to a
version"* (`ux.md:2245`). The ceiling is itself a document: *"The allow
document at the vendor level is how the adopter chooses their client's ceiling:
which elements may move, which axes may be set, which params may be written"*
(`ux.md:2247`).

**Read §6 before building against this section.** The surface-plane fleet
story is spec prose plus one demo, with no conformance fixture, and the spec's
own status ladder scopes it.

## 5. When to compose beside, instead of refining

Refine when you are narrowing a contract someone else implements. **Compose a
new feature beside the shared one** when you need behaviour — that is the
supported answer to §2's refusal, and the seam is checked.

The compose gate reports **every** violation, not the first
(`xap_grammar_composition.md:145`). The gates that guard a seam between two
independently authored features:

| Gate | What it guarantees |
|---|---|
| **W1** | feature names distinct, each a single segment |
| **W2** | **key compatibility** — every registration onto one key name carries the same value type/shape |
| **W3** | frame registration: `via` names a real field, typed to the family's coordinate type |
| **W4** | rule consistency — no mandate/exclusion contradiction, no ordering cycle, dependency targets exist |
| **W5** | every `uses` entry, every qualified reference in a derived noun's `[from …]`, and every derived verb's constituent resolves |
| **W6** | resolution is total and deterministic — every bare term yields one qualified verb or a well-formed ambiguity, never zero-or-crash |
| **W7** | a derived noun is **deriver-reserved** — no verb writes onto it |

W2 is the one an adopter meets first, because the shared key is the join:

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?let [= $ais
  [feature name=ais
   [types [type 'mmsi::text' [pattern '^[0-9]{9}$']]]
   [keys [key name=mmsi via=mmsi]]
   [nouns [noun name=vessel [field name=mmsi type=mmsi] [field name=pos type=geo-point]]]
   [verbs [verb name=track effect=observe [intent [do :track]] [reads vessel]]]
   [requirements [requirement kind=functional as=user traces=track [want 'to track vessels'] [so 'I know traffic']]]]]
 [= $harbor
 [feature name=harbor
  [keys [key name=mmsi via=id]]
  [nouns [noun name=berth [field name=id type=int]]]
  [verbs [verb name=list-berths effect=observe [intent [do :list-berths]] [reads berth]]]
  [requirements [requirement kind=functional as=user traces=list-berths [want 'to list berths'] [so 'I can dock']]]]]
 [$xap:compose $ais $harbor]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4870 message='E_XAP_COMPOSE_CONFLICT: composition rejected with 1 conflict(s)' [conflict code=':w2' at=mmsi detail='key "mmsi" registered with conflicting value types: int vs mmsi']]
```

Compose is commutative and idempotent, and the same feature *set* yields a
byte-identical canonical form — which is what makes a grammar hash an equality
oracle rather than a checksum:

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?let [= $chart
  [feature name=chart
   [nouns [noun name=viewport singular=true [field name=center type=geo-point]]]
   [verbs [verb name=highlight effect=arrange [intent [do :highlight]] [reads viewport]]]
   [requirements [requirement kind=functional as=user traces=highlight [want 'to mark a spot'] [so 'I can find it']]]]]
 [= $strikes
 [feature name=strikes
  [nouns [noun name=strike [field name=pos type=geo-point] [field name=at type=instant]]]
  [verbs [verb name=list-strikes effect=observe [intent [do :list-strikes]] [reads strike]]]
  [requirements [requirement kind=functional as=user traces=list-strikes [want 'to see strikes'] [so 'I avoid them']]]]]
 [= [$xap:grammar-hash [$xap:compose $chart $strikes]]
    [$xap:grammar-hash [$xap:compose $strikes $chart]]]]
```

```console
$ cx prog.cx
true
```

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?let [= $chart
  [feature name=chart
   [nouns [noun name=viewport singular=true [field name=center type=geo-point]]]
   [verbs [verb name=highlight effect=arrange [intent [do :highlight]] [reads viewport]]]
   [requirements [requirement kind=functional as=user traces=highlight [want 'to mark a spot'] [so 'I can find it']]]]]
 [= [$xap:grammar-hash [$xap:compose $chart $chart]]
    [$xap:grammar-hash [$xap:compose $chart]]]]
```

```console
$ cx prog.cx
true
```

### 5.1 The trap: a shared key that moves does NOT refuse

This is the most important paragraph in this section, because the intuition is
wrong. **W2 checks type agreement only, never spelling**
(`xap_grammar_composition.md:1104`): *"W2 checks exactly one property of them:
that every registration onto one name agrees in value type. Nothing checks
that the NAME is the one the author meant."*

So if one feature says `order-id` and the other says `order_id`, there is **no
W2 conflict**. Both become solitary, composition passes, `ok=true`, and the
first evidence is an empty readout at runtime. What catches it is a **note**,
and `ok=` is untouched:

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?let
 [= $alpha [feature name=alpha version='1' [summary 'A.']
   [keys [key name=order-id via=oid]]
   [nouns [noun name=a [field name=oid type=text]]]
   [verbs [verb name=see effect=observe [intent [do :see]] [reads a]]]
   [requirements [requirement kind=functional as=user traces=see [want 'x'] [so 'y']]]]]
 [= $beta [feature name=beta version='1' [summary 'B.']
   [keys [key name=order_id via=oid]]
   [nouns [noun name=b [field name=oid type=text]]]
   [verbs [verb name=look effect=observe [intent [do :look]] [reads b]]]
   [requirements [requirement kind=functional as=user traces=look [want 'x'] [so 'y']]]]]
 [$xap:compose-report $alpha $beta]]
```

```console
$ cx prog.cx
[compose-report ok=true [note code=':solitary-key' at='alpha/a#oid' key=order-id detail='one registration — a key name meant to JOIN needs at least two, so this is either a misspelling of another key or a private field wearing a global name'] [note code=':solitary-key' at='beta/b#oid' key=order_id detail='one registration — a key name meant to JOIN needs at least two, so this is either a misspelling of another key or a private field wearing a global name']]
```

Spelled correctly, the same pair joins and the report is silent — so the note
carries information rather than noise:

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?let
 [= $alpha [feature name=alpha version='1' [summary 'A.']
   [keys [key name=order-id via=oid]]
   [nouns [noun name=a [field name=oid type=text]]]
   [verbs [verb name=see effect=observe [intent [do :see]] [reads a]]]
   [requirements [requirement kind=functional as=user traces=see [want 'x'] [so 'y']]]]]
 [= $beta [feature name=beta version='1' [summary 'B.']
   [keys [key name=order-id via=oid]]
   [nouns [noun name=b [field name=oid type=text]]]
   [verbs [verb name=look effect=observe [intent [do :look]] [reads b]]]
   [requirements [requirement kind=functional as=user traces=look [want 'x'] [so 'y']]]]]
 [$xap:compose-report $alpha $beta]]
```

```console
$ cx prog.cx
[compose-report ok=true]
```

Know its limit, stated at `xap_grammar_composition.md:1123`: it catches the
**typo** class exactly, and says nothing about two features meaning different
things by one correctly-spelled name.

### 5.2 Archetype status is earned, not declared

Before you publish a feature as an archetype for others to instantiate,
`xap_grammar_composition.md:383`:

> **Graduation (R8.10).** Archetype status is EARNED: the cohesion gate passing,
> plus TWO genuinely different instantiations named and recorded as evidence —
> different composing surface/tenant, non-overlapping `uses` neighborhoods,
> **not two skins of one deployment**.

The same bar governs whether a feature is ready for a marketplace at all
(`:497`): *"Designed-for-one-XAP bias cannot be seen by inspection, only by a
second composition failing to fit."* The cohesion instrument ships
report-first — a healthy feature is one component:

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?let [= $f
  [feature name=till version="1"
   [nouns [noun name=sale [field name=id type=text]]
          [noun name=receipt [field name=sale-id type=text]]]
   [verbs [verb name=ring-up effect=act [intent [do :ring-up [id]]] [writes sale]]
          [verb name=print effect=act [intent [do :print [id]]] [writes receipt]]]
   [rules [rule name=receipt-cites-sale kind=validity nouns='receipt sale'
           [statement 'A receipt MUST cite the sale it records.']]]
   [requirements [requirement kind=functional as=clerk traces=ring-up [want 'to ring up'] [so 'rung']]]]]
 [= $r [$xap:cohesion $f]]
 [probe [n [$string $r@components]] [members [$count $r//member]] [edges [$count $r//edge]]]]
```

```console
$ cx prog.cx
[probe [n '1'] [members 4] [edges 3]]
```

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?let [= $f
  [feature name=till-and-piano version="1"
   [nouns [noun name=sale [field name=id type=text]]
          [noun name=piano [field name=pitch type=text]]]
   [verbs [verb name=ring-up effect=act [intent [do :ring-up [id]]] [writes sale]]
          [verb name=tune effect=act [intent [do :tune]] [writes piano]]]
   [requirements [requirement kind=functional as=clerk traces=ring-up [want 'to ring up'] [so 'rung']]]]]
 [= $r [$xap:cohesion $f]]
 [probe [n [$string $r@components]]
        [split [?for [in $c $r//component]
                 [yield [part [?splice [?for [in $m $c/*] [yield [x [$string $m@name]]]]]]]]]]]
```

```console
$ cx prog.cx
[probe [n '2'] [split [part [x piano] [x tune]] [part [x sale] [x ring-up]]]]
```

## 6. The worked arc, and what is missing

### 6.1 Two tenants, one archetype — runnable

This is the whole model in one fixture, on the feature `cx xap init` actually
generates (`vcx/cmd/xap_init_templates.v:100-131`, copied verbatim). Two
tenants derive **different** variants of **one** base: `acme` renames, adds a
field and tightens `create` to irreversible; `borough` renames and withdraws
`list` from its offer. Neither carries code. Both name the same base pin.

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?lib 'cx-stdlib/hash' :as hash]
[?lib 'cx-stdlib/bytes' :as bytes]
[?let [= $thing
  [feature name=thing version="1"
   [summary 'The things this XAP is about. Rename it to your own noun.']
   [frames [use frame=time via=created-at]]
   [keys   [key name=owner-id via=owner]]
   [nouns
    [noun name=thing
     [field name=id type=text]
     [field name=owner type=text doc='the shared key — same name and type in owner.feature.cxd']
     [field name=created-at type=instant doc='the time-frame coordinate']
     [field name=label type=text]]]
   [verbs
    [verb name=create effect=act scope=shared consequence=reversible
     [intent [do :create]] [writes thing]]
    [verb name=list effect=observe
     [intent [do :list]] [reads thing]]]
   [rules
    [rule name=label-required kind=validity
     [statement 'A thing MUST carry a label.']]]
   [governance [grant verb=create to=operator]]
   [requirements
    [requirement kind=functional as=operator traces=create
     [want 'to create a thing'] [so 'it exists in the record']
     [acceptance 'a created thing appears under the /thing state route']]]]]
 [= $pin [$concat "sha2-256:" [$bytes:to-hex [$hash:sha256-string [$cx:canonical $thing]]]]]
 [= $acme [$xap:instantiate $thing
   [instance name=asset of=$pin
    [rename noun=thing label='Asset']
    [add on=thing [field name=serial type=text]]
    [tighten verb=create consequence=irreversible]]]]
 [= $borough [$xap:instantiate $thing
   [instance name=permit of=$pin
    [rename noun=thing label='Permit']
    [select [offer verb=create] [not-offered verb=list why='Permits are listed by the registry, not the tenant.']]]]]
 [probe [acme-name [$string $acme@name]]
        [acme-cq [?for [in $v $acme//verb] [where [= [$string $v@name] "create"]] [yield [$string $v@consequence]]]]
        [acme-fields [$count $acme//field]]
        [borough-name [$string $borough@name]]
        [borough-cq [?for [in $v $borough//verb] [where [= [$string $v@name] "create"]] [yield [$string $v@consequence]]]]
        [borough-fields [$count $borough//field]]
        [acme-base-is-pin [= [$string $acme//instantiated-from@archetype] $pin]]
        [borough-base-is-pin [= [$string $borough//instantiated-from@archetype] $pin]]]]
```

```console
$ cx prog.cx
[probe [acme-name asset] [acme-cq irreversible] [acme-fields 5] [borough-name permit] [borough-cq reversible] [borough-fields 4] [acme-base-is-pin true] [borough-base-is-pin true]]
```

Read the output: two contracts, one implementation. That is §0's sentence,
executed.

### 6.2 The grammar-plane preflight, and what still does not exist

**The grammar plane has a per-refinement preflight** (RULED: 1255-a).
`[$xap:instantiate-preflight ARCHETYPE BINDING]` is the same gate
`[$xap:instantiate]` enforces, read rather than applied: it answers
`[instantiate-preflight ok=<bool> …]` with one `[refinement status=… at=…
detail=…]` per refinement of the binding, in binding order, where `status=` is
`clean`, `refused` — carrying that refinement's own code, `CXER4877`/`4878`/
`4879` — or `redundant`, meaning the archetype already holds that floor, so a
re-bless may drop the line. It never refuses what the gate decides, and
**`ok=false` exactly when `instantiate` would raise**: both faces run the one
validation pass, so the agreement law holds by construction rather than by two
edits kept in step — the same law `compose-report` and `compose` hold on the
composition side.

A stale `of=` pin is itself reported as a refusal, and the refinements are
classified **anyway**. That combination is the point: a candidate v2 presents a
stale pin to *every* tenant binding, so a preflight that refused there would
lose the fleet at the first tenant. Instead a vendor asks which of a fleet's
bindings the candidate would break, and on which refinement, and gets an answer
per tenant:

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?lib 'cx-stdlib/hash' :as hash]
[?lib 'cx-stdlib/bytes' :as bytes]
[?let [= $v1
  [feature name=thing version="1"
   [nouns [noun name=thing [field name=id type=text] [field name=label type=text]]]
   [verbs [verb name=create effect=act scope=shared consequence=reversible
           [intent [do :create]] [writes thing]]]
   [requirements [requirement kind=functional as=operator traces=create
                  [want 'to create a thing'] [so 'it exists in the record']]]]]
 [= $v2
  [feature name=thing version="2"
   [nouns [noun name=thing [field name=id type=text] [field name=label type=text]]]
   [verbs [verb name=create effect=act scope=shared consequence=irreversible
           [intent [do :create]] [writes thing]]]
   [requirements [requirement kind=functional as=operator traces=create
                  [want 'to create a thing'] [so 'it exists in the record']]]]]
 [= $pin1 [$concat "sha2-256:" [$bytes:to-hex [$hash:sha256-string [$cx:canonical $v1]]]]]
 [= $r [$xap:instantiate-preflight $v2 [instance name=asset of=$pin1 [tighten verb=create consequence=reversible]]]]
 [probe [ok [$string $r@ok]]
        [codes [?for [in $x $r//refinement] [yield [$string $x@code]]]]]]
```

```console
$ cx prog.cx
[probe [ok 'false'] [codes 'cx-err:CXER4879' 'cx-err:CXER4878']]
```

Two refusals from one binding is also what totality means here: `instantiate`
raises the first refusal's code and sentence — unchanged, which is why no
existing fixture moved — and now names the rest instead of dropping them
(`xap-compose-137`). The three statuses against the same v1/v2 pair are
`xap-compose-133` (refused, with its code), `134` (redundant — the tighten the
vendor made the floor) and `135` (clean, both faces agreeing):

`prog.cx`
```cx
[?lib 'cx-platform/xap' :as xap]
[?lib 'cx-stdlib/hash' :as hash]
[?lib 'cx-stdlib/bytes' :as bytes]
[?let [= $v1
  [feature name=thing version="1"
   [nouns [noun name=thing [field name=id type=text] [field name=label type=text]]]
   [verbs [verb name=create effect=act scope=shared consequence=reversible
           [intent [do :create]] [writes thing]]]
   [requirements [requirement kind=functional as=operator traces=create
                  [want 'to create a thing'] [so 'it exists in the record']]]]]
 [= $pin1 [$concat "sha2-256:" [$bytes:to-hex [$hash:sha256-string [$cx:canonical $v1]]]]]
 [= $r [$xap:instantiate-preflight $v1 [instance name=asset of=$pin1 [tighten verb=create consequence=reversible]]]]
 [probe [ok [$string $r@ok]]
        [st [?for [in $x $r//refinement] [yield [$string $x@status]]]]]]
```

```console
$ cx prog.cx
[probe [ok 'true'] [st redundant]]
```

The fleet-level command that walks a tenant list and calls this per tenant
(`cx xap preflight --to <addr>`) is its consumer and is **not built yet**;
this verb is what it will be built on.

**The order in which an adopter then moves their tenants is deliberately
unprescribed** (RULED: 1255-b, `ux.md` §19.3). CX supplies the facts — this
per-tenant classification, and pins that move independently — and the adopter
supplies the policy. A canary-first fleet, a smallest-blast-radius-first fleet
and an all-at-once fleet are all expressible with the same facts; prescribing
one would make a release-management opinion normative for everyone.

What still does not exist, stated plainly, because a document that implies a
mechanism is worse than one that admits a gap:

- **The surface-plane fleet mechanics have no conformance fixture.**
  `adopt-base`, the `fold(base, commands)` replay, tenant pins and the allow
  document are spec prose plus the ORIEL demo
  (`spec/03-approved/xap/demos/oriel/serve.cx:5165-5263`, routes at
  `surface.cx:66-67`, gate-enforced assertions at `drive.cx:1016-1025` and
  `:1362-1381` — which is a real-socket step, `make test-oriel-lane`). The spec's own
  status ladder scopes the claim (`ux.md:2114`): built *"for a candidate bundle
  and per-tenant adoption"*, with migration commands for breaking changes
  **unbuilt**.
- **Two spellings in §18.5 are not what the implementation does.** `ux.md:1960`
  describes adoption committing a `[base-adopted from=… to=…]` entry; the
  implementation journals `[pinned tenant= version= clean= refused=]`
  (`serve.cx:5253-5258`). And of `[P0-120]`'s three classes, the layout replay
  emits only `clean` and `refused` (`serve.cx:3523-3531`); `drifted` comes from
  the catalog comparison arm (`serve.cx:3647`), i.e. tenant-owned content, not
  a replayed vendor-document command. Trust the code over the prose here until
  one of them moves.

## 7. Where to go next

| File | Load it when |
|---|---|
| `playbook-xap.md` | you are authoring the features and the deployment this model applies to |
| `reference-platform.md` | you are persisting, serving or distributing |

Normative sources for everything above: `spec/03-approved/xap/ux.md` §18–§19
(the surface plane), `spec/03-approved/xap/xap_grammar_composition.md` §4.3–§4.4
and §4.13 (the grammar plane),
`spec/03-approved/xap/xap_feature_distribution_market.md` §1 (packages and
pins), and `spec/03-approved/xap/xap_schemas/instance.cxs` (the binding
vocabulary). The rulings behind the refusals: AD-10 (#1162) and 1161-Q1a in
`ledger/`; the preflight and the unprescribed rollout order are 1255-a and
1255-b (`ledger/rulings_2026_09_08_grammar_plane_preflight_1255.md`).
