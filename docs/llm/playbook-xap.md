# Playbook: building a production XAP — v0.17.0

> **GENERATED.** Source: `docs-src/llm/playbook-xap.md.tmpl` + the conformance
> corpus. Every code block is a fixture and every output was re-recorded from
> the `cx` v0.17.0 binary at generation time. Where a claim is backed by a
> file in the repository rather than a fixture, the file and line are cited and
> **the citation is the evidence** — nothing here is invented. Read `primer.md`
> first; this document assumes the language.

A **XAP** is CX's unit of packaged functionality. It is a *feature*, never an
"app". A production deployment is several features composed into one runtime,
with an authority model, a durable plane, and a projected surface — and the
striking thing about it is how little of that is code. Most of it is data you
declare, gated by rules that refuse rather than guess.

This playbook walks the whole arc. Each chapter names what is ruled, what it
forbids, and where the evidence lives.

## 0. The map

Six artefacts, in the order you author them.

| # | Artefact | What it is | Chapter |
|---|---|---|---|
| 1 | `<name>.feature.cxd` | one feature's grammar: nouns, verbs, requirements | §1 |
| 2 | *(a composite feature)* | a feature that `[uses]` others and declares derived nouns | §3 |
| 3 | `<deployment>.xap.cxd` | the **wiring layer**: which features, who has authority, what the durable plane is | §5 |
| 4 | a deriver module | the one producer of a derived noun | §3 |
| 5 | `<surface>.surface.cxd` | the route table and media binding | §7 |
| 6 | a client | a separate project; the deployment does not own it | §7 |

The dividing line to hold onto: **a feature document declares grammar; the
deployment document declares nothing about grammar.** It enables features,
names principals, and binds the runtime. Per-verb grants live in the feature,
because that is where the verb lives.

Worked instances to read alongside this document:

* `reference/shop/` — the composition, authority, and distribution reference.
  Eleven files; `README.md` is the guided tour.
* `spec/03-approved/xap/demos/oriel/` — the projection flagship: the full ux
  vocabulary, both renderers, and the headless drive-step harness.

## 1. Author a feature grammar

A feature is a document. Its head is `[feature name=…]`, and it carries
`[nouns]`, `[verbs]`, and `[requirements]` — all three, always. A verb states
its `effect` class, the `[intent]` that reaches it, and what it `[reads]` or
`[writes]`:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $chart
  [feature name=chart
   [frames [use frame=geo via=center]]
   [nouns [noun name=viewport singular=true [field name=center type=geo-point]]]
   [verbs
    [verb name=highlight effect=arrange [intent [do :highlight]] [reads viewport]]
    [verb name=set-waypoint effect=act scope=shared consequence=reversible [intent [do :set-waypoint]] [writes viewport]]]
   [requirements [requirement kind=functional as=user traces=highlight [want 'to mark a spot'] [so 'I can find it']]]]]
 [?let [= $g [$xap:compose $chart]]
  $g//verb[= $_@name 'chart/highlight']/@effect]]
```

```console
$ cx prog.cx
[effect 'arrange']
```

Read the output: after composition the verb is `chart/highlight`, not
`highlight`. **Names qualify on the way in.** That is what lets two features
each own a `highlight` without either of them knowing about the other.

Requirements are not decoration. They carry `kind`, an RFC-2119 `level`, and
`[acceptance]` rows — see `reference/shop/shop.xap.cxd:43-54` for three MUSTs
with their acceptance criteria written as checkable sentences.

Per-verb grants live here too, in the feature's own `[governance]`:
`reference/shop/orders.feature.cxd:56-58` grants `place-order` and
`cancel-order` to the `customer` role. The deployment document's
`[governance]` block is the layer *above* this one, not a replacement for it.

## 2. Compose them

`[$xap:compose]` takes n feature grammars and returns one grammar — or a
conflict value naming every violation. It is an **algebra with laws**, not a
merge convention.

**Commutative** — order of arguments cannot change the result, and the
composed grammar's Tier-1 hash is the equality oracle that proves it:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
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

**Associative / order-independent at any arity:**

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $a
  [feature name=a
   [nouns [noun name=an [field name=x type=int]]]
   [verbs [verb name=va effect=observe [intent [do :va]] [reads an]]]
   [requirements [requirement kind=functional as=user traces=va [want 'a'] [so 'a']]]]]
 [= $b
 [feature name=b
  [nouns [noun name=bn [field name=x type=int]]]
  [verbs [verb name=vb effect=observe [intent [do :vb]] [reads bn]]]
  [requirements [requirement kind=functional as=user traces=vb [want 'b'] [so 'b']]]]]
 [= $c
 [feature name=c
  [nouns [noun name=cn [field name=x type=int]]]
  [verbs [verb name=vc effect=observe [intent [do :vc]] [reads cn]]]
  [requirements [requirement kind=functional as=user traces=vc [want 'c'] [so 'c']]]]]
 [= [$xap:grammar-hash [$xap:compose $a $b $c]]
    [$xap:grammar-hash [$xap:compose $c $a $b]]]]
```

```console
$ cx prog.cx
true
```

**Idempotent** — composing a feature twice is composing it once:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
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

**Closed under name collision** — two features may each own a verb of the same
name, because qualification already separated them:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $chart
  [feature name=chart
   [nouns [noun name=viewport singular=true [field name=center type=geo-point]]]
   [verbs
    [verb name=highlight effect=arrange [intent [do :highlight]] [reads viewport]]
    [verb name=set-waypoint effect=act scope=shared consequence=reversible [intent [do :set-waypoint]] [writes viewport]]]
   [requirements [requirement kind=functional as=user traces=highlight [want 'to mark a spot'] [so 'I can find it']]]]]
 [= $strikes
 [feature name=strikes
  [nouns [noun name=strike [field name=pos type=geo-point] [field name=at type=instant]]]
  [verbs
   [verb name=highlight effect=arrange [intent [do :highlight]] [reads strike]]
   [verb name=list-strikes effect=observe [intent [do :list-strikes]] [reads strike]]]
  [requirements [requirement kind=functional as=user traces=highlight [want 'to see strikes'] [so 'I avoid them']]]]]
 [= $g [$xap:compose $chart $strikes]]
 [$count $g//verb]]
```

```console
$ cx prog.cx
4
```

### The W-gates

Composition runs a well-formedness gate. Each violation has its own code, and
the gate reports **all** of them rather than stopping at the first:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $chart
  [feature name=chart
   [nouns [noun name=viewport singular=true [field name=center type=geo-point]]]
   [verbs [verb name=highlight effect=arrange [intent [do :highlight]] [reads viewport]]]
   [requirements [requirement kind=functional as=user traces=highlight [want 'to mark a spot'] [so 'I can find it']]]]]
 [= $chart-b
 [feature name=chart
  [nouns [noun name=marks [field name=n type=int]]]
  [verbs [verb name=mark effect=act [intent [do :mark]] [writes marks]]]
  [requirements [requirement kind=functional as=user traces=mark [want 'to mark'] [so 'marked']]]]]
 [$xap:compose $chart $chart-b]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4870 message='E_XAP_COMPOSE_CONFLICT: composition rejected with 1 conflict(s)' [conflict code=':w1' at=chart detail='2 distinct features named "chart" — feature names must be unique in a XAP']]
```

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $chart
  [feature name=chart
   [nouns [noun name=viewport singular=true [field name=center type=geo-point]]]
   [verbs [verb name=highlight effect=arrange [intent [do :highlight]] [reads viewport]]]
   [requirements [requirement kind=functional as=user traces=highlight [want 'to mark a spot'] [so 'I can find it']]]]]
 [= $ghost-user
 [feature name=ghost-user kind=composite
  [uses features='chart ghost']
  [nouns [noun name=shadow derived=true [field name=n type=int] [from 'chart/viewport']]]
  [verbs [verb name=peek effect=observe [intent [do :peek]] [reads shadow]]]
  [requirements [requirement kind=functional as=user traces=peek [want 'to peek'] [so 'peeked']]]]]
 [$xap:compose $chart $ghost-user]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4870 message='E_XAP_COMPOSE_CONFLICT: composition rejected with 1 conflict(s)' [conflict code=':w5' at=ghost-user detail='composite "ghost-user" uses "ghost", which is not in the composed feature set']]
```

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $chart
  [feature name=chart
   [nouns [noun name=viewport singular=true [field name=center type=geo-point]]]
   [verbs [verb name=highlight effect=arrange [intent [do :highlight]] [reads viewport]]]
   [requirements [requirement kind=functional as=user traces=highlight [want 'to mark a spot'] [so 'I can find it']]]]]
 [= $chart-b
 [feature name=chart
  [nouns [noun name=marks [field name=n type=int]]]
  [verbs [verb name=mark effect=act [intent [do :mark]] [writes marks]]]
  [requirements [requirement kind=functional as=user traces=mark [want 'to mark'] [so 'marked']]]]]
 [= $labels
 [feature name=labels
  [frames [use frame=geo via=title]]
  [nouns [noun name=tag [field name=title type=string]]]
  [verbs [verb name=label effect=arrange [intent [do :label]] [reads tag]]]
  [requirements [requirement kind=functional as=user traces=label [want 'to label'] [so 'labeled']]]]]
 [= $r [$xap:compose-report $chart $chart-b $labels]]
 [$count $r//conflict]]
```

```console
$ cx prog.cx
2
```

Two faces, one predicate. `[$xap:compose]` raises; `[$xap:compose-report]` is
the never-raising tooling face, and the law is that **compose raises if and
only if compose-report says `ok=false`**:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
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
 [?let [= $r [$xap:compose-report $chart $strikes]]
  $r/@ok]]
```

```console
$ cx prog.cx
true
```

### Composing nothing is a refusal

This is worth its own heading because it is the failure mode that makes a gate
worse than no gate. A gate over the empty set has verified the empty set, and
reports green:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[$xap:compose]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4874 message='E_XAP_COMPOSE_EMPTY: composition has no features — a gate over the empty set verifies nothing (§3.1 identity)']
```

The tooling face agrees, at the same vacuous input, so the two can never
diverge into "the check passes but the build fails":

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[$xap:compose-report]
```

```console
$ cx prog.cx
[compose-report ok=false [conflict code=':empty' at='(no features)' detail='composition has no features — a gate over the empty set verifies nothing (§3.1 identity)']]
```

**If your feature files were renamed, moved, or not yet written, your
composition refuses.** It does not congratulate you.

### Bare terms resolve, or say they cannot

A bare `[do highlight]` is resolved by ρ against the composed grammar. With
one owner it resolves:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $chart
  [feature name=chart
   [nouns [noun name=viewport singular=true [field name=center type=geo-point]]]
   [verbs [verb name=highlight effect=arrange [intent [do :highlight]] [reads viewport]]]
   [requirements [requirement kind=functional as=user traces=highlight [want 'to mark a spot'] [so 'I can find it']]]]]
 [= $ais
 [feature name=ais
  [keys [key name=mmsi via=mmsi]]
  [nouns [noun name=vessel [field name=mmsi type=mmsi] [field name=pos type=geo-point]]]
  [verbs [verb name=track effect=observe [intent [do :track]] [reads vessel]]]
  [requirements [requirement kind=functional as=user traces=track [want 'to track vessels'] [so 'I know traffic']]]]]
 [= $g [$xap:compose $chart $ais]]
 [$xap:resolve $g "track"]]
```

```console
$ cx prog.cx
'ais/track'
```

A qualified term bypasses resolution entirely:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $chart
  [feature name=chart
   [nouns [noun name=viewport singular=true [field name=center type=geo-point]]]
   [verbs [verb name=highlight effect=arrange [intent [do :highlight]] [reads viewport]]]
   [requirements [requirement kind=functional as=user traces=highlight [want 'to mark a spot'] [so 'I can find it']]]]]
 [= $strikes
 [feature name=strikes
  [nouns [noun name=strike [field name=pos type=geo-point] [field name=at type=instant]]]
  [verbs [verb name=highlight effect=arrange [intent [do :highlight]] [reads strike]]]
  [requirements [requirement kind=functional as=user traces=highlight [want 'to see strikes'] [so 'I avoid them']]]]]
 [= $g [$xap:compose $chart $strikes]]
 [$xap:resolve $g "chart/highlight"]]
```

```console
$ cx prog.cx
'chart/highlight'
```

And ambiguity is **a value listing the candidates — never a guess**:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $chart
  [feature name=chart
   [nouns [noun name=viewport singular=true [field name=center type=geo-point]]]
   [verbs [verb name=highlight effect=arrange [intent [do :highlight]] [reads viewport]]]
   [requirements [requirement kind=functional as=user traces=highlight [want 'to mark a spot'] [so 'I can find it']]]]]
 [= $strikes
 [feature name=strikes
  [nouns [noun name=strike [field name=pos type=geo-point] [field name=at type=instant]]]
  [verbs [verb name=highlight effect=arrange [intent [do :highlight]] [reads strike]]]
  [requirements [requirement kind=functional as=user traces=highlight [want 'to see strikes'] [so 'I avoid them']]]]]
 [= $g [$xap:compose $chart $strikes]]
 [$xap:resolve $g "highlight"]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4871 message='E_XAP_VERB_AMBIGUOUS: "highlight" has 2 candidates — disambiguate, never auto-pick' term=highlight candidates='chart/highlight strikes/highlight']
```

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $chart
  [feature name=chart
   [nouns [noun name=viewport singular=true [field name=center type=geo-point]]]
   [verbs [verb name=highlight effect=arrange [intent [do :highlight]] [reads viewport]]]
   [requirements [requirement kind=functional as=user traces=highlight [want 'to mark a spot'] [so 'I can find it']]]]]
 [= $g [$xap:compose $chart]]
 [$xap:resolve $g "warp"]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4872 message='E_XAP_VERB_UNKNOWN: no feature of the composed grammar defines "warp"' term=warp]
```

That property has a name (N-COMPOSE-1) and it is the reason enabling one more
feature cannot silently change what an existing utterance means. See
`reference/shop/shop.xap.cxd:51-54`, where a requirement pins exactly this.

## 3. Derived nouns and deriver principals

A **composite** feature `[uses]` other features and declares nouns that are
`derived=true`, each naming the nouns it is derived `[from …]`:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $own-ship
  [feature name=own-ship
   [frames [use frame=geo via=position] [use frame=time via=observed-at]]
   [nouns [noun name=own-ship singular=true [field name=position type=geo-point] [field name=cog type=deg] [field name=sog type=knots] [field name=observed-at type=instant]]]
   [verbs [verb name=read-instruments effect=observe [intent [do :read-instruments]] [reads own-ship]]]
   [requirements [requirement kind=functional as=skipper traces=read-instruments [want 'to read my instruments'] [so 'I know my state']]]]]
 [= $traffic
 [feature name=traffic
  [frames [use frame=geo via=position] [use frame=time via=observed-at]]
  [keys [key name=mmsi via=mmsi]]
  [nouns [noun name=vessel [field name=mmsi type=mmsi] [field name=position type=geo-point] [field name=cog type=deg] [field name=sog type=knots] [field name=observed-at type=instant]]]
  [verbs [verb name=list-targets effect=observe [intent [do :list-targets]] [reads vessel]]]
  [requirements [requirement kind=functional as=skipper traces=list-targets [want 'to see nearby traffic'] [so 'I avoid it']]]]]
 [= $collision-cpa
 [feature name=collision-cpa kind=composite
  [uses features='own-ship traffic']
  [frames [use frame=geo] [use frame=time]]
  [nouns [noun name=cpa derived=true [field name=vessel type=mmsi] [field name=cpa-dist type=nm] [field name=tcpa type=minutes] [from 'own-ship/own-ship' 'traffic/vessel']]]
  [verbs [verb name=cpa-threats effect=observe [intent [do :cpa-threats]] [reads cpa]]]
  [requirements [requirement kind=functional as=skipper traces=cpa-threats [want 'closing vessels flagged'] [so 'I can avoid collision']]]]]
 [?let [= $g [$xap:compose $own-ship $traffic $collision-cpa]]
  $g//noun[= $_@name 'collision-cpa/cpa']/@derived]]
```

```console
$ cx prog.cx
[derived true]
```

Four rules govern derived nouns, and each of them is a gate.

**A derived noun must declare `[from …]`.** Without it the composition
refuses:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $chart
  [feature name=chart
   [nouns [noun name=viewport singular=true [field name=center type=geo-point]]]
   [verbs [verb name=highlight effect=arrange [intent [do :highlight]] [reads viewport]]]
   [requirements [requirement kind=functional as=user traces=highlight [want 'to mark a spot'] [so 'I can find it']]]]]
 [= $sourceless
 [feature name=sourceless kind=composite
  [uses features='chart']
  [nouns [noun name=shadow derived=true [field name=n type=int]]]
  [verbs [verb name=peek effect=observe [intent [do :peek]] [reads shadow]]]
  [requirements [requirement kind=functional as=user traces=peek [want 'to peek'] [so 'peeked']]]]]
 [= $r [$xap:compose-report $chart $sourceless]]
 [$first [?for [in $c $r//conflict] [yield $c@detail]]]]
```

```console
$ cx prog.cx
'derived noun "sourceless/shadow" declares no [from …] source list'
```

**Every reference inside `[from …]` must resolve.** W5 covers each one:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $chart
  [feature name=chart
   [nouns [noun name=viewport singular=true [field name=center type=geo-point]]]
   [verbs [verb name=highlight effect=arrange [intent [do :highlight]] [reads viewport]]]
   [requirements [requirement kind=functional as=user traces=highlight [want 'to mark a spot'] [so 'I can find it']]]]]
 [= $dangling
 [feature name=dangling kind=composite
  [uses features='chart']
  [nouns [noun name=shadow derived=true [field name=n type=int]
          [from 'chart/viewport' 'nosuchfeature/nothing']]]
  [verbs [verb name=peek effect=observe [intent [do :peek]] [reads shadow]]]
  [requirements [requirement kind=functional as=user traces=peek [want 'to peek'] [so 'peeked']]]]]
 [= $r [$xap:compose-report $chart $dangling]]
 [$first [?for [in $c $r//conflict] [yield $c@detail]]]]
```

```console
$ cx prog.cx
'[from …] reference "nosuchfeature/nothing" is not a noun of the composed grammar'
```

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $chart
  [feature name=chart
   [nouns [noun name=viewport singular=true [field name=center type=geo-point]]]
   [verbs [verb name=highlight effect=arrange [intent [do :highlight]] [reads viewport]]]
   [requirements [requirement kind=functional as=user traces=highlight [want 'to mark a spot'] [so 'I can find it']]]]]
 [= $shade
 [feature name=shade kind=composite
  [uses features='chart']
  [nouns [noun name=shadow derived=true [field name=n type=int]
          [from 'chart/viewport']]]
  [verbs [verb name=peek effect=observe [intent [do :peek]] [reads shadow]]]
  [requirements [requirement kind=functional as=user traces=peek [want 'to peek'] [so 'peeked']]]]]
 [= $r [$xap:compose-report $chart $shade]]
 $r@ok]
```

```console
$ cx prog.cx
true
```

**Derived nouns are deriver-reserved.** No grammar verb may `[writes]` one —
the only producer is the declared deriver:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $chart
  [feature name=chart
   [nouns [noun name=viewport singular=true [field name=center type=geo-point]]]
   [verbs [verb name=highlight effect=arrange [intent [do :highlight]] [reads viewport]]]
   [requirements [requirement kind=functional as=user traces=highlight [want 'to mark a spot'] [so 'I can find it']]]]]
 [= $shade
 [feature name=shade kind=composite
  [uses features='chart']
  [nouns [noun name=shadow derived=true [field name=n type=int]
          [from 'chart/viewport']]]
  [verbs [verb name=assert-shadow effect=act [intent [do :assert-shadow [n]]] [writes shadow]]
         [verb name=peek effect=observe [intent [do :peek]] [reads shadow]]]
  [requirements [requirement kind=functional as=user traces=peek [want 'to peek'] [so 'peeked']]]]]
 [= $r [$xap:compose-report $chart $shade]]
 [probe [ok $r@ok]
        [w7 [$count [?for [in $c $r//conflict] [where [= $c@code ':w7']] [yield $c]]]]]]
```

```console
$ cx prog.cx
[probe [ok false] [w7 1]]
```

**A derived verb's signature is the floor of its constituents.** It cannot be
weaker than what it composes:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $chart
  [feature name=chart
   [nouns [noun name=viewport singular=true [field name=center type=geo-point]]]
   [verbs [verb name=set-waypoint effect=act scope=shared consequence=reversible [intent [do :set-waypoint]] [writes viewport]]]
   [requirements [requirement kind=functional as=user traces=set-waypoint [want 'to set a waypoint'] [so 'I can navigate']]]]]
 [= $strikes
 [feature name=strikes
  [nouns [noun name=strike [field name=pos type=geo-point] [field name=at type=instant]]]
  [verbs [verb name=highlight effect=arrange [intent [do :highlight]] [reads strike]]]
  [requirements [requirement kind=functional as=user traces=highlight [want 'to see strikes'] [so 'I avoid them']]]]]
 [= $cpa-guard
 [feature name=cpa-guard kind=composite
  [uses features='chart strikes']
  [nouns [noun name=threat derived=true [field name=level type=int] [from 'chart/viewport' 'strikes/strike']]]
  [verbs
   [verb name=mark-threat effect=act scope=shared consequence=reversible
    [intent [do :mark-threat]]
    [constituents 'chart/set-waypoint strikes/highlight']
    [reads threat]]]
  [requirements [requirement kind=functional as=user traces=mark-threat [want 'to mark a threat'] [so 'the crew sees it']]]]]
 [?let [= $g [$xap:compose $chart $strikes $cpa-guard]]
  $g//verb[= $_@name 'cpa-guard/mark-threat']/@derived]]
```

```console
$ cx prog.cx
[derived true]
```

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $chart
  [feature name=chart
   [nouns [noun name=viewport singular=true [field name=center type=geo-point]]]
   [verbs [verb name=set-waypoint effect=act scope=shared consequence=reversible [intent [do :set-waypoint]] [writes viewport]]]
   [requirements [requirement kind=functional as=user traces=set-waypoint [want 'to set a waypoint'] [so 'I can navigate']]]]]
 [= $weak-guard
 [feature name=weak-guard kind=composite
  [uses features=chart]
  [nouns [noun name=threat derived=true [field name=level type=int] [from 'chart/viewport']]]
  [verbs
   [verb name=mark-threat effect=observe
    [intent [do :mark-threat]]
    [constituents 'chart/set-waypoint']
    [reads threat]]]
  [requirements [requirement kind=functional as=user traces=mark-threat [want 'to mark a threat'] [so 'the crew sees it']]]]]
 [$xap:compose $chart $weak-guard]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4870 message='E_XAP_COMPOSE_CONFLICT: composition rejected with 1 conflict(s)' [conflict code=':w5' at='weak-guard/mark-threat' detail='declared effect="observe" weakens the derived floor "act"']]
```

### The deriver is a principal

This is the design move that makes the rest cohere. A deriver is not a
callback or a job; it is an **actor**, declared beside the roles and the
agents, so run assembly reads *one* block to know every actor in the system:

```cx
[principals
  [role name=customer authority=own-orders features='orders shipments']
  [role name=fulfilment authority=operations features='*']
  [agent name=expediter]
  [deriver name=detect produces='delayed-shipment/delay-alert'
           package='./detect.cx'
           reads='orders/order shipments/shipment']]
```

`reference/shop/shop.xap.cxd:18-27`. Note `reads=`: it is the deriver's read
**authority envelope**, and it must resolve inside the `[from …]` envelope of
the noun it produces. Run assembly checks that.

The deriver module records its production explicitly —
`reference/shop/detect.cx:21-25` calls `[$xap:derive $rt {deriver: "detect",
noun: "delayed-shipment/delay-alert", record: …}]`, and the entry commits as
`actor: deriver:detect`. The join itself is ordinary CX
(`reference/shop/detect.cx:32-46`) — there is **no join algebra**. The
specification declares production, not semantics.

**Precedence you must know:** when the deployment document carries `[deriver]`
rows, they *supersede* an OPTS `derivers:` key **entirely — they are not
merged**, and the superseded key is announced at boot. With no `[deriver]`
rows the OPTS key forwards unchanged. See
`spec/03-approved/xap/xap_feature_distribution_market.md:634-643`.

## 4. Authority: the PEP, and what a grant does not convey

The policy enforcement point sits between an intent and its effect. Two
properties carry most of the model.

**Authority is rooted in a principal, delegated, and attenuating.** A permit
names the chain it travelled:

`prog.cx`
```cx
[?lib 'cx-stdlib/authz']
[?let [= $az [$authz:store {tenant: 'acme'}]]
  [= $d [$authz:delegate $az
    [delegation d-1 [tenant acme] [from [principal dana]] [to [agent ops-1]]
      [capabilities [refund-duplicate]] [over '/orders'] [assurance :t1] [signature sig-dana]]]]
  [$authz:check $az [authz-request [actor [agent ops-1]] [capability refund-duplicate] [slice '/orders/9'] [tenant acme]]]]
```

```console
$ cx prog.cx
[permit rooted-principal=dana [delegation 'd-1'] [via 'd-1'] [tier :t1] [capability 'refund-duplicate']]
```

**A denial is a value carrying its reason.** There is no implicit grant, and
the reasons stay distinguishable rather than collapsing into one "forbidden" —
no grant at all, a grant that does not reach this slice, a grant that has
expired:

`prog.cx`
```cx
[?lib 'cx-stdlib/authz']
[?let [= $az [$authz:store {tenant: 'acme'}]]
  [$authz:check $az [authz-request [actor [agent ghost]] [capability refund-duplicate] [slice '/orders/9'] [tenant acme]]]]
```

```console
$ cx prog.cx
[deny actor=ghost [code 'cx-err:CXER4700'] [reason :no-grant] [capability 'refund-duplicate'] [slice '/orders/9'] [tenant id=acme]]
```

`prog.cx`
```cx
[?lib 'cx-stdlib/authz']
[?let [= $az [$authz:store {tenant: 'acme'}]]
  [= $d [$authz:delegate $az
    [delegation d-1 [tenant acme] [from [principal dana]] [to [agent ops-1]]
      [capabilities [refund-duplicate]] [over '/orders'] [assurance :t1] [signature s]]]]
  [$authz:check $az [authz-request [actor [agent ops-1]] [capability refund-duplicate] [slice '/payments/9'] [tenant acme]]]]
```

```console
$ cx prog.cx
[deny actor=ops-1 [code 'cx-err:CXER4700'] [reason :out-of-slice] [capability 'refund-duplicate'] [slice '/payments/9'] [tenant id=acme]]
```

`prog.cx`
```cx
[?lib 'cx-stdlib/authz']
[?let [= $az [$authz:store {tenant: 'acme'}]]
  [= $d [$authz:delegate $az
    [delegation d-1 [tenant acme] [from [principal dana]] [to [agent ops-1]]
      [capabilities [refund]] [over '/orders'] [until 1700000000] [assurance :t1] [signature s]]]]
  [$authz:check $az [authz-request [actor [agent ops-1]] [capability refund] [slice '/orders/9'] [tenant acme] [as-of 1800000000]]]]
```

```console
$ cx prog.cx
[deny actor=ops-1 [code 'cx-err:CXER4700'] [reason :expired] [capability 'refund'] [slice '/orders/9'] [tenant id=acme]]
```

The distinction matters operationally: "you were never granted this" and "your
grant does not cover this resource" send an operator to two different places.

### A composite verb evaluates its transitive leaves

This is the rule that stops a composite from laundering authority. Emitting a
derived verb requires the grants of every **leaf constituent**, transitively:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $door
  [feature name=door
   [nouns [noun name=door singular=true [field name=locked type=int]]]
   [verbs
    [verb name=unlock effect=act scope=shared consequence=irreversible [intent [do :unlock]] [writes door]]
    [verb name=chime effect=observe [intent [do :chime]] [reads door]]]
   [requirements
    [requirement kind=functional as=resident traces=unlock [want 'to unlock the door'] [so 'guests can enter']]
    [requirement kind=functional as=resident traces=chime [want 'to sound the chime'] [so 'arrival is announced']]]]]
 [= $porch
 [feature name=porch kind=composite
  [uses features=door]
  [nouns [noun name=visit derived=true [field name=count type=int] [from 'door/door']]]
  [verbs
   [verb name=welcome effect=act scope=shared consequence=irreversible
    [intent [do :welcome]]
    [constituents 'door/unlock door/chime']
    [reads visit]]]
  [requirements [requirement kind=functional as=resident traces=welcome [want 'to welcome a guest'] [so 'arrival is one gesture']]]]]
 [= $g [$xap:compose $door $porch]]
 [= $rt [$xap:run {tenant: "demo" grammar: $g derivers: ({name: "counter" produces: "porch/visit"})}]]
 [= $d [$xap:dial $rt [from id="principal:dana"] [to id="agent:porter-1"] [scope 'door/chime']]]
 [$xap:emit $rt [do :welcome] {actor: "agent:porter-1"}]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4850 message='E_XAP_UNAUTHORIZED: actor "agent:porter-1" is not granted "door/unlock" over ""']
```

A grant on the wrapper's own name conveys **nothing** — the wrapper name is
never consulted:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $door
  [feature name=door
   [nouns [noun name=door singular=true [field name=locked type=int]]]
   [verbs
    [verb name=unlock effect=act scope=shared consequence=irreversible [intent [do :unlock]] [writes door]]
    [verb name=chime effect=observe [intent [do :chime]] [reads door]]]
   [requirements
    [requirement kind=functional as=resident traces=unlock [want 'to unlock the door'] [so 'guests can enter']]
    [requirement kind=functional as=resident traces=chime [want 'to sound the chime'] [so 'arrival is announced']]]]]
 [= $porch
 [feature name=porch kind=composite
  [uses features=door]
  [nouns [noun name=visit derived=true [field name=count type=int] [from 'door/door']]]
  [verbs
   [verb name=welcome effect=act scope=shared consequence=irreversible
    [intent [do :welcome]]
    [constituents 'door/unlock door/chime']
    [reads visit]]]
  [requirements [requirement kind=functional as=resident traces=welcome [want 'to welcome a guest'] [so 'arrival is one gesture']]]]]
 [= $g [$xap:compose $door $porch]]
 [= $rt [$xap:run {tenant: "demo" grammar: $g derivers: ({name: "counter" produces: "porch/visit"})}]]
 [= $d [$xap:dial $rt [from id="principal:dana"] [to id="agent:porter-1"] [scope 'porch/welcome']]]
 [$xap:emit $rt [do :welcome] {actor: "agent:porter-1"}]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4850 message='E_XAP_UNAUTHORIZED: actor "agent:porter-1" is not granted "door/chime" over ""']
```

Dial every leaf and the same emit is admitted:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $door
  [feature name=door
   [nouns [noun name=door singular=true [field name=locked type=int]]]
   [verbs
    [verb name=unlock effect=act scope=shared consequence=irreversible [intent [do :unlock]] [writes door]]
    [verb name=chime effect=observe [intent [do :chime]] [reads door]]]
   [requirements
    [requirement kind=functional as=resident traces=unlock [want 'to unlock the door'] [so 'guests can enter']]
    [requirement kind=functional as=resident traces=chime [want 'to sound the chime'] [so 'arrival is announced']]]]]
 [= $porch
 [feature name=porch kind=composite
  [uses features=door]
  [nouns [noun name=visit derived=true [field name=count type=int] [from 'door/door']]]
  [verbs
   [verb name=welcome effect=act scope=shared consequence=irreversible
    [intent [do :welcome]]
    [constituents 'door/unlock door/chime']
    [reads visit]]]
  [requirements [requirement kind=functional as=resident traces=welcome [want 'to welcome a guest'] [so 'arrival is one gesture']]]]]
 [= $g [$xap:compose $door $porch]]
 [= $rt [$xap:run {tenant: "demo" grammar: $g derivers: ({name: "counter" produces: "porch/visit"})}]]
 [= $d1 [$xap:dial $rt [from id="principal:dana"] [to id="agent:porter-1"] [scope 'door/unlock']]]
 [= $d2 [$xap:dial $rt [from id="principal:dana"] [to id="agent:porter-1"] [scope 'door/chime']]]
 [$xap:emit $rt [do :welcome] {actor: "agent:porter-1"}]]
```

```console
$ cx prog.cx
[event actor=agent:porter-1 [do 'porch/welcome']]
```

Nesting does not dilute it — an *intermediate* grant is still insufficient:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $door
  [feature name=door
   [nouns [noun name=door singular=true [field name=locked type=int]]]
   [verbs
    [verb name=unlock effect=act scope=shared consequence=irreversible [intent [do :unlock]] [writes door]]
    [verb name=chime effect=observe [intent [do :chime]] [reads door]]]
   [requirements
    [requirement kind=functional as=resident traces=unlock [want 'to unlock the door'] [so 'guests can enter']]
    [requirement kind=functional as=resident traces=chime [want 'to sound the chime'] [so 'arrival is announced']]]]]
 [= $porch
 [feature name=porch kind=composite
  [uses features=door]
  [nouns [noun name=visit derived=true [field name=count type=int] [from 'door/door']]]
  [verbs
   [verb name=welcome effect=act scope=shared consequence=irreversible
    [intent [do :welcome]]
    [constituents 'door/unlock door/chime']
    [reads visit]]]
  [requirements [requirement kind=functional as=resident traces=welcome [want 'to welcome a guest'] [so 'arrival is one gesture']]]]]
 [= $estate
 [feature name=estate kind=composite
  [uses features=porch]
  [nouns [noun name=open-day derived=true [field name=visits type=int] [from 'porch/visit']]]
  [verbs
   [verb name=open-house effect=act scope=shared consequence=irreversible
    [intent [do :open-house]]
    [constituents 'porch/welcome']
    [reads open-day]]]
  [requirements [requirement kind=functional as=resident traces=open-house [want 'to run an open house'] [so 'visitors flow in']]]]]
 [= $g [$xap:compose $door $porch $estate]]
 [= $rt [$xap:run {tenant: "demo" grammar: $g derivers: ({name: "counter" produces: "porch/visit"}, {name: "planner" produces: "estate/open-day"})}]]
 [= $d [$xap:dial $rt [from id="principal:dana"] [to id="agent:porter-1"] [scope 'porch/welcome']]]
 [$xap:emit $rt [do :open-house] {actor: "agent:porter-1"}]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4850 message='E_XAP_UNAUTHORIZED: actor "agent:porter-1" is not granted "door/chime" over ""']
```

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $door
  [feature name=door
   [nouns [noun name=door singular=true [field name=locked type=int]]]
   [verbs
    [verb name=unlock effect=act scope=shared consequence=irreversible [intent [do :unlock]] [writes door]]
    [verb name=chime effect=observe [intent [do :chime]] [reads door]]]
   [requirements
    [requirement kind=functional as=resident traces=unlock [want 'to unlock the door'] [so 'guests can enter']]
    [requirement kind=functional as=resident traces=chime [want 'to sound the chime'] [so 'arrival is announced']]]]]
 [= $porch
 [feature name=porch kind=composite
  [uses features=door]
  [nouns [noun name=visit derived=true [field name=count type=int] [from 'door/door']]]
  [verbs
   [verb name=welcome effect=act scope=shared consequence=irreversible
    [intent [do :welcome]]
    [constituents 'door/unlock door/chime']
    [reads visit]]]
  [requirements [requirement kind=functional as=resident traces=welcome [want 'to welcome a guest'] [so 'arrival is one gesture']]]]]
 [= $estate
 [feature name=estate kind=composite
  [uses features=porch]
  [nouns [noun name=open-day derived=true [field name=visits type=int] [from 'porch/visit']]]
  [verbs
   [verb name=open-house effect=act scope=shared consequence=irreversible
    [intent [do :open-house]]
    [constituents 'porch/welcome']
    [reads open-day]]]
  [requirements [requirement kind=functional as=resident traces=open-house [want 'to run an open house'] [so 'visitors flow in']]]]]
 [= $g [$xap:compose $door $porch $estate]]
 [= $rt [$xap:run {tenant: "demo" grammar: $g derivers: ({name: "counter" produces: "porch/visit"}, {name: "planner" produces: "estate/open-day"})}]]
 [= $d1 [$xap:dial $rt [from id="principal:dana"] [to id="agent:porter-1"] [scope 'door/unlock']]]
 [= $d2 [$xap:dial $rt [from id="principal:dana"] [to id="agent:porter-1"] [scope 'door/chime']]]
 [$xap:emit $rt [do :open-house] {actor: "agent:porter-1"}]]
```

```console
$ cx prog.cx
[event actor=agent:porter-1 [do 'estate/open-house']]
```

### The decision explains itself

`[$xap:why-allowed]` answers over exactly the same constituent set the PEP
used, so the explanation cannot drift from the decision:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $door
  [feature name=door
   [nouns [noun name=door singular=true [field name=locked type=int]]]
   [verbs
    [verb name=unlock effect=act scope=shared consequence=irreversible [intent [do :unlock]] [writes door]]
    [verb name=chime effect=observe [intent [do :chime]] [reads door]]]
   [requirements
    [requirement kind=functional as=resident traces=unlock [want 'to unlock the door'] [so 'guests can enter']]
    [requirement kind=functional as=resident traces=chime [want 'to sound the chime'] [so 'arrival is announced']]]]]
 [= $porch
 [feature name=porch kind=composite
  [uses features=door]
  [nouns [noun name=visit derived=true [field name=count type=int] [from 'door/door']]]
  [verbs
   [verb name=welcome effect=act scope=shared consequence=irreversible
    [intent [do :welcome]]
    [constituents 'door/unlock door/chime']
    [reads visit]]]
  [requirements [requirement kind=functional as=resident traces=welcome [want 'to welcome a guest'] [so 'arrival is one gesture']]]]]
 [= $g [$xap:compose $door $porch]]
 [= $rt [$xap:run {tenant: "demo" grammar: $g derivers: ({name: "counter" produces: "porch/visit"})}]]
 [= $d [$xap:dial $rt [from id="principal:dana"] [to id="agent:porter-1"] [scope 'porch/welcome']]]
 [?let [= $w [$xap:why-allowed $rt [do :welcome] {actor: "agent:porter-1"}]]
  $w/@allowed]]
```

```console
$ cx prog.cx
'false'
```

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?let [= $door
  [feature name=door
   [nouns [noun name=door singular=true [field name=locked type=int]]]
   [verbs
    [verb name=unlock effect=act scope=shared consequence=irreversible [intent [do :unlock]] [writes door]]
    [verb name=chime effect=observe [intent [do :chime]] [reads door]]]
   [requirements
    [requirement kind=functional as=resident traces=unlock [want 'to unlock the door'] [so 'guests can enter']]
    [requirement kind=functional as=resident traces=chime [want 'to sound the chime'] [so 'arrival is announced']]]]]
 [= $porch
 [feature name=porch kind=composite
  [uses features=door]
  [nouns [noun name=visit derived=true [field name=count type=int] [from 'door/door']]]
  [verbs
   [verb name=welcome effect=act scope=shared consequence=irreversible
    [intent [do :welcome]]
    [constituents 'door/unlock door/chime']
    [reads visit]]]
  [requirements [requirement kind=functional as=resident traces=welcome [want 'to welcome a guest'] [so 'arrival is one gesture']]]]]
 [= $g [$xap:compose $door $porch]]
 [= $rt [$xap:run {tenant: "demo" grammar: $g derivers: ({name: "counter" produces: "porch/visit"})}]]
 [= $d1 [$xap:dial $rt [from id="principal:dana"] [to id="agent:porter-1"] [scope 'door/unlock']]]
 [= $d2 [$xap:dial $rt [from id="principal:dana"] [to id="agent:porter-1"] [scope 'door/chime']]]
 [?let [= $w [$xap:why-allowed $rt [do :welcome] {actor: "agent:porter-1"}]]
  $w/@allowed]]
```

```console
$ cx prog.cx
'true'
```

The authz layer does the same for delegated authority — naming the **first
failing link** rather than reporting a bare denial:

`prog.cx`
```cx
[?lib 'cx-stdlib/authz']
[?let [= $az [$authz:store {tenant: 'acme'}]]
  [= $d [$authz:delegate $az
    [delegation d-1 [tenant acme] [from [principal dana]] [to [agent ops-1]]
      [capabilities [refund]] [over '/orders'] [assurance :t1] [signature s]]]]
  [= $dec [$authz:check $az [authz-request [actor [agent ops-1]] [capability refund] [slice '/orders/9'] [tenant acme]]]]
  [$authz:explain $dec]]
```

```console
$ cx prog.cx
[explanation outcome=permit [accountable 'dana'] [authority-chain [step 'd-1']]]
```

`prog.cx`
```cx
[?lib 'cx-stdlib/authz']
[?let [= $az [$authz:store {tenant: 'acme'}]]
  [= $dec [$authz:check $az [authz-request [actor [agent x]] [capability y] [tenant acme]]]]
  [$authz:explain $dec]]
```

```console
$ cx prog.cx
[explanation outcome=deny [first-failing-link :no-grant] [code 'cx-err:CXER4700']]
```

An enterprise deployment needs this more than it needs the enforcement: an
authority chain nobody can read is one nobody can review.

### The dial moves *who drives*, never *what is permitted*

An agent's autonomy is a dial, and at its floor an agent may observe and
propose but never act. `reference/shop/shop.xap.cxd:40-41` sets
`[agent-default name=expediter dial=floor]` and says why: an irreversible verb
is "out of its reach **by construction, not by convention**". Raising the dial
is the single explicit act that widens what the agent may do.

## 5. The deployment document (`*.xap.cxd`)

The wiring layer. Its complete child set is fixed by
`spec/03-approved/xap/xap_schemas/xap.cxs:14-24`:

```
[xap name= version=
  [summary …]        [features …]     [principals …]    [runtime …]
  [deployment …]     [surfacing …]    [governance …]    [requirements …]]
```

`name=` is required and `[features]` is required exactly once
(`xap.cxs:15`, `:18`). Everything else is `0..1`. That cardinality is the
schema saying the same thing the vacuity refusal of §2 says: a deployment that
enables nothing is not a deployment.

**There is no `[transport]` block, and you must not invent one.** The
transport is the store —
`spec/03-approved/xap/xap_feature_distribution_market.md:225`, and "no new
transport" at `:710`. Remote endpoints are declared as
`[deployment [remote name= uri= priority=]]`
(`spec/03-approved/xap/xap_schemas/xap.cxs:125-133`).

The reference instance is `reference/shop/shop.xap.cxd` in full — features
`:13-16`, principals `:18-27`, deployment `:29-31`, surfacing `:33-35`,
governance `:37-41`, requirements `:43-54`. Read it; it is 55 lines and it is
the whole shape.

### `[features]` — pinned, and the hash is the truth

```cx
[features
  [feature name=orders package='./orders.feature.cxd']
  [feature name=shipments package='./shipments.feature.cxd']
  [feature name=delayed-shipment package='./delayed-shipment.feature.cxd']]
```

`version=` on a row is **informative; the hash is the truth**
(`spec/03-approved/xap/xap_schemas/xap.cxs:56`). A pin/content mismatch
refuses to boot.

### `[runtime]` — the durable plane, as data

Four run options — `journal`, `sources`, `resolver`, `log-reduce` — ride a
`[runtime]` block, **one child per option, each named for its option key
verbatim**, so the document and the opts map share one vocabulary. The host
compiles the document's data into exactly the values `[$xap:run]` accepts:
there is **one validator, never two**.

```cx
[runtime
  [journal url='file:///var/acme/acts' stream=acts
           checkpoint='file:///var/acme/ckpt' checkpoint-every=512]
  [sources [source fabric='xsp://127.0.0.1:8447' stream=evidence
            verb=record group=acme-xap actor='role:operator']]
  [resolver [affinity component='orders/order-list' when='context[deadline]'
             class=:orders.urgent rank=1]]
  [log-reduce window=500 fn='orders:compact']]
```

`spec/03-approved/xap/xap_feature_distribution_market.md:600-609`. Per child:

* **`[journal url= …]`** — `url=` is required. Without a journal block a
  hosted XAP is in-process demo mode; with one, the bound stream **is** the
  runtime's journal and restart is a re-fold.
* **`[sources [source …]]`** — one `[source]` row each. **A `[sources]` block
  with no row is a refusal, never a silent no-op.**
* **`[resolver …]`** — only the kinds that *are* data: `kind=scripted` and
  `[affinity …]` rule rows. A **closure** resolver is code, not deployment
  data, and stays on the direct `[$xap:run]` lane.
* **`[log-reduce window= fn=]`** — `fn=` names a public def of a *pinned
  feature's* contract module as `<feature>:<def>`. Because a binding may name
  a contract def, the host's load step runs **before** its attach step.

The four `[runtime]` options have **no OPTS spelling on a hosted XAP**: naming
one in `[$xap:host]` opts refuses at boot with
`E_XAP_HOST_BINDING_MISPLACED` — rather than being accepted twice or dropped
once. Every refusal here is named and loud at boot: an unknown `[runtime]`
child, a `[journal]` without `url=`, an empty `[sources]`, an `fn=` naming no
loaded contract def. `spec/…market.md:640-649`.

**Boot ordering.** A `[sources]` subscription **opens** during run assembly —
so a bad binding refuses at boot rather than at first delivery — but
**consumes** nothing until the dials and the host-auth map are wired. Opening
and consuming are two moments, with the deployment's authority between them. A
boot that refuses after run assembly consumed nothing, therefore acked
nothing, so every entry stays redeliverable to the next boot.
`spec/…market.md:651-667`.

> **Honest gap.** No `[runtime]` block is instantiated anywhere in this
> repository today — the schema (`xap.cxs:90-118`) and the spec example above
> are the only spellings, and `reference/shop/shop.xap.cxd` carries none.
> Yours will be the first. Treat the schema as normative and the example as
> the shape.

## 6. Bootstrap identity

A production deployment is deny-by-default at every layer, which means a fresh
one has nobody who may talk to it. Bootstrapping is deliberate.

### Mint the principals offline

```console
cx store-mint-principal --id fleet-ops \
    --seed-file ./secrets/fleet-ops.seed --caps "read write"
cx store-mint-principal --id shop-host \
    --seed-file ./secrets/shop-host.seed --for identity
```

Nothing transits a wire and no store is opened. The verb generates an Ed25519
seed, derives its `did:key`, writes the seed at mode 0600 (never to stdout),
and prints the config rows: `--for grant` (the default) prints the
`[xsp [grants [grant …]]]` row authorizing that principal; `--for identity`
prints the daemon's own `[xsp [identity did= seed-env=]]` responder row.

`--caps` is **required** for a grant row — the authority a grant carries is an
explicit choice at mint time, with no default. The seed environment variable
is *derived* from `--id` (`CX_XSP_SEED_<NAME>`), so two ids that would derive
the same variable are refused by name rather than silently sharing one seed.

**The minted principal is inert until an operator splices the grant into the
config. Config remains the sole authority.** There is no
trust-on-first-use step and no bearer token anywhere in this path.

The arc: **mint → splice the grant into the config → start the deny-by-default
daemon → the client presents its DID.**

### Bind the host's channel policy

`[$xap:host]` reads one block of deployment data for its channel
authentication:

```cx
[host-auth
  [identity did="did:key:z6Mk…" seed-env="CX_XAP_HOST_SEED"]
  [policy mode="mutual"]
  [principals [principal did="did:key:z6Mk…" role="operator"]]
  [public [route "/"] [route "/static/"]]]
```

`spec/03-approved/xap/xap_identity_model.md:635-641`. Four things to know:

* **Absent means today's behavior, byte-for-byte** — the localhost dev floor.
  Going from floor to production is *adding this block* and nothing else.
  `:652-657`.
* **The block is `[host-auth]`, not `[auth]`** — a deployment may already
  carry an `[auth]` element for its own login configuration, a distinct
  concern. Squatting on `[auth]` silently broke that invariant once already.
  `:644-650`.
* **Boot is fail-closed on `[identity]`** — a missing seed variable, a
  malformed seed, or a seed whose public key does not re-derive `did=` refuses
  to boot. Never a latent runtime denial. `:658-663`.
* **An authenticated DID with no `[principal]` row attaches but holds no
  dials** — the session is real and every intent is PEP-denied. That is
  default-deny working, not a bug. `:670-674`.

`[policy mode="floor"]` attaches an anonymous peer as the fixed principal
`floor:<floor>`; the `floor:` prefix is **constructed by the host** so a floor
principal can never collide with an inherent-authority `principal:` id.
`POST /attach` is always open — it *is* the handshake.

### Sessions bind a principal, immutably

Below the host, `cx-stdlib/session` binds a `(principal, tenant)` pair for the
session's whole life. An anonymous floor is a real principal:

`prog.cx`
```cx
[?lib 'cx-stdlib/session']
[?let [= $pair [$session:attach-guest [request scheme="https"] {anonymous-floor: "web-public" tenant: "shop"}]] [= $s [$first $pair]] [?let [= $p [$session:principal $s]] $p@id]]
```

```console
$ cx prog.cx
'web-public'
```

…and a deployment that declares no floor refuses cleanly, naming the policy:

`prog.cx`
```cx
[?lib 'cx-stdlib/session']
[$session:attach-guest [request scheme="https"] {tenant: "shop"}]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4812 message='E_SESSION_ANONYMOUS_REFUSED: the deployment attach policy does not admit an anonymous floor — no `anonymous-floor` principal in cfg (xap_identity_model §4.7; refusing is the production default)']
```

The mutual-authentication path is the same story with a handshake in front of
it. `[$session:attach-xsp]` binds the **proven** DID — the principal the peer
demonstrated possession of, never a claimed one — and an anonymous peer with
no declared floor is refused with `CXER4803`. A presented verifiable
credential compiles into an ordinary authz delegation, so the *unchanged* PEP
decides: there is one evaluator, not a credential path running beside the
authority path, and a credential past its time of use denies at check.

Those four cases carry full RFC key vectors and are long, so they are cited
rather than printed. Read them in `conformance/stdlib/session.cxd`:
`session-045-attach-xsp-binds-proven-principal`,
`session-047-attach-xsp-anonymous-no-floor-rejected`,
`session-050-present-vc-compiles-to-permit`,
`session-052-present-vc-time-of-use-expiry`. The shape they pin is the whole
lesson: **proof, then principal, then delegation, then the same check
everything else goes through.**

Session ids are opaque and are **never** the raw token:

`prog.cx`
```cx
[?lib 'cx-stdlib/session']
[?lib 'cx-stdlib/crypto']
[?lib 'cx-stdlib/time']
[?lib 'cx-stdlib/strings']
[?let [= $pair [$session:attach-cookie [request scheme="https" [headers [header name="Authorization" value="Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6InJzYS0xIiwidHlwIjoiSldUIn0.eyJpc3MiOiJodHRwczovL2lkcC5leGFtcGxlIiwic3ViIjoidXNlci0xIiwiYXVkIjoibXktYXBpIiwiZXhwIjoxNzAwMDAzNjAwLCJuYmYiOjE2OTk5OTk5OTAsImlhdCI6MTY5OTk5OTk5MH0.e4bn1A_a5Q0_4IZxKWipmmrUCCdmNkiTUs071mBMtMVXb68RGPtV2FTR1nRWvM3Zw2XTMuBsk_Y1HPinat_2JQkm3s90lltrErpYOky6Nwm6ha57BxQ0Sg5kWxuQF5KhWUqHzePIVDTfkr0WeN591nDTDn6VuajLaHn2pjXBsaJ0reT6mh6v40UQcBW-yy-XOfrsMeGVj_qZd1UmlE81XN957rjPENcPpH2E1SHfVhu3fQP3QZapxtdMADgWmryw_z5O2lDIIWb7miT0siXRCDjVEhDzKH6Hsf1aUPcYx9x44o1B5OBpX6z1uM1SP0qaOZu6x26H0AbHj84nIISE1A"]]] {jwks: [$crypto:jwks-parse "{\"keys\":[{\"kid\":\"rsa-1\",\"kty\":\"RSA\",\"alg\":\"RS256\",\"n\":\"jdwwBcaMZQLoSNYGNEm3l03HIQqpRIv0eqLUNUCkyv7ysVw4i6vZgdYxcdU0D3kSvUCIjH-icqk4PCDx5AwkeNp55Nqt6wKXDv9TH5pr-Wc3BWmZ1sEOEwyN8QlI8_5EpY3i1w5tysDdeFuiR7BOjpkD49RZzF0YajmocsB4_jXoZcldVNCOChXAbEfOw-BtjFJRN0N3EksymF4azkey8Q3rX07sXkRHavRfAOnowH119RL1V-Xmk_DUX8wSR-2zdlp8FxitJWPgbMmnszsTgEQrThTwsuMrndqzJ_nQ7HTnuK2LXEFmFwXw9NADspq2ZnQmZiN7CXnEYG8WCApzxw\",\"e\":\"AQAB\"}]}"] tenant-claim: "aud" now: [$time:datetime 2023 11 14 22 13 20]}]] [= $s [$first $pair]] [$strings:starts-with $s@id "s-"]]
```

```console
$ cx prog.cx
true
```

`prog.cx`
```cx
[?lib 'cx-stdlib/session']
[?lib 'cx-stdlib/crypto']
[?lib 'cx-stdlib/time']
[?let [= $pair [$session:attach-cookie [request scheme="https" [headers [header name="Authorization" value="Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6InJzYS0xIiwidHlwIjoiSldUIn0.eyJpc3MiOiJodHRwczovL2lkcC5leGFtcGxlIiwic3ViIjoidXNlci0xIiwiYXVkIjoibXktYXBpIiwiZXhwIjoxNzAwMDAzNjAwLCJuYmYiOjE2OTk5OTk5OTAsImlhdCI6MTY5OTk5OTk5MH0.e4bn1A_a5Q0_4IZxKWipmmrUCCdmNkiTUs071mBMtMVXb68RGPtV2FTR1nRWvM3Zw2XTMuBsk_Y1HPinat_2JQkm3s90lltrErpYOky6Nwm6ha57BxQ0Sg5kWxuQF5KhWUqHzePIVDTfkr0WeN591nDTDn6VuajLaHn2pjXBsaJ0reT6mh6v40UQcBW-yy-XOfrsMeGVj_qZd1UmlE81XN957rjPENcPpH2E1SHfVhu3fQP3QZapxtdMADgWmryw_z5O2lDIIWb7miT0siXRCDjVEhDzKH6Hsf1aUPcYx9x44o1B5OBpX6z1uM1SP0qaOZu6x26H0AbHj84nIISE1A"]]] {jwks: [$crypto:jwks-parse "{\"keys\":[{\"kid\":\"rsa-1\",\"kty\":\"RSA\",\"alg\":\"RS256\",\"n\":\"jdwwBcaMZQLoSNYGNEm3l03HIQqpRIv0eqLUNUCkyv7ysVw4i6vZgdYxcdU0D3kSvUCIjH-icqk4PCDx5AwkeNp55Nqt6wKXDv9TH5pr-Wc3BWmZ1sEOEwyN8QlI8_5EpY3i1w5tysDdeFuiR7BOjpkD49RZzF0YajmocsB4_jXoZcldVNCOChXAbEfOw-BtjFJRN0N3EksymF4azkey8Q3rX07sXkRHavRfAOnowH119RL1V-Xmk_DUX8wSR-2zdlp8FxitJWPgbMmnszsTgEQrThTwsuMrndqzJ_nQ7HTnuK2LXEFmFwXw9NADspq2ZnQmZiN7CXnEYG8WCApzxw\",\"e\":\"AQAB\"}]}"] tenant-claim: "aud" now: [$time:datetime 2023 11 14 22 13 20]}]] [= $s [$first $pair]] [= $r [$session:rotate $s]] [= $s@id $r@id]]
```

```console
$ cx prog.cx
false
```

Re-minting the session id on a privilege transition is the fixation defense.
`spec/03-approved/xap/demos/oriel/serve.cx:2523-2528` does exactly that on
sign-in, and carries the basket forward by an **explicit journaled adoption** —
"never a silent rewrite, never a silent loss".

> **A discipline worth copying verbatim.** Oriel never writes a session id
> into its journal. It writes a *derived, non-invertible* stream key —
> `sha2-256(secret ‖ session-id)`, truncated
> (`spec/03-approved/xap/demos/oriel/session.cx:70`, rationale at `:72-82`).
> A journal is durable, exportable, and frequently handed to an analyst;
> writing the session id there would put **live bearer material into the
> permanent audit record**, where it survives logout and outlives the session
> it authenticates.

## 7. Host it, and project a surface

### The host is six steps

`[$xap:host XAP-DOC OPTS]` boots a complete XAP from its deployment document
(`spec/03-approved/xap/xap_feature_distribution_market.md:539-577`):

1. **acquire** — open the store, fetch every pinned `[feature]` by pin, verify.
   A pin/content mismatch refuses to boot.
2. **compose** — `[$xap:compose]` over the sealed spec layers; the composed
   grammar is stored and attached via `[$xap:run {grammar: …}]`, together with
   the `[runtime]` bindings of §5.
3. **govern** — roles, `[governance]` grants, and agent envelopes become
   runtime dials. Actor resolution is an OPTS hook with a default of
   `role:<author's role>`.
4. **load** — resolve each feature's `pkg:` reference and register its
   contract surface, keyed by the composed grammar's qualified verbs.
5. **serve** — the standard surface: `GET /grammar`, `GET /features`,
   `GET /surface` + `GET /surface/<f>`, `POST /intent`, `GET /stream`.
6. **extend** — OPTS registers what is genuinely deployment-specific: extra
   routes, ingest workers, sim cadence. **Adapters register onto the host;
   they never fork it.** Adapter routes are consulted *before* the standard
   surface, so a deployment may enrich a standard route without forking.

**Two layers of refusal, both visible in the ack.** The PEP admits the *verb*;
the feature's contract `apply` may still refuse the *values* by returning
`[refused reason=…]`, and the host acks `ok=false` with that reason.
`spec/…market.md:574-577`.

A XAP with no custom transport is therefore **zero server code**: deployment
document + published packages + a client. Deploying one more feature is
publish, add a pinned row, re-pin, restart.

> **Honest gap.** `[$xap:host]` has no live call site in this repository —
> every occurrence is specification or schema. The nearest working programs
> use the direct `compose` + `run` lane and say so:
> `reference/shop-web-client/serve.cx:36`, with `[$xap:compose]` at `:131` and
> `[$xap:run]` at `:136`. `docs/dev/xap-quickstart.md:73-97` is the six-step
> summary and carries the `[$xap:host …]!` postfix rule.

### The surface document

Routes are composition data. A `[surface]` names its XAP, binds media, and
declares which act verbs each route **offers**:

* `spec/03-approved/xap/demos/oriel/surface.cx:11-12` — the surface head.
* `:23-31` — `[offer verb=…]`, the route's declaration of what is reachable
  from it. "A route with no `[offer]` is a reading page and asserts nothing."
* `:32-37` — a route with its feature instance and fragment path.
* `reference/shop/shop.surface.cxd:26-43` — panels, layout regions, and
  `[materialize]` rows; `:61-67` — `[clients]`, where a human client and an
  agent client are declared as peers. The comment there is the design in one
  sentence: the agent "is not a side channel with its own privileges — what it
  may do is decided by the dial", not by giving it another door.

The coverage claim is **mechanical, and it refuses at compose time**. An act
verb no route offers is a refusal, not a lint warning:

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?let
  [= $f [feature name=shop version="1"
          [nouns [noun name=order [field name=id type=text]]]
          [verbs
           [verb name=sell effect=act [intent [do :sell [id]]] [writes order]]
           [verb name=refund effect=act [intent [do :refund [id]]] [writes order]]
           [verb name=audit effect=act [intent [do :audit [id]]] [writes order]]
           [verb name=browse effect=observe [intent [do :browse]] [reads order]]]]]
  [= $ok  [surface a [route path="/o" [feature xap=shop] [offer verb=sell]]
            [not-offered verb=refund why="No payments rail on this surface."]
            [not-offered verb=audit why="The audit trail is the journal itself."]]]
  [= $missing [surface a [route path="/o" [feature xap=shop] [offer verb=sell]]
                [not-offered verb=refund why="No payments rail on this surface."]]]
  [= $bare [surface a [route path="/o" [feature xap=shop] [offer verb=sell]]
             [not-offered verb=refund why="No payments rail on this surface."]
             [not-offered verb=audit]]]
  ([$ux:check-surface $ok ("/o") ($f)],
   [$ux:check-surface $missing ("/o") ($f)],
   [$ux:check-surface $bare ("/o") ($f)])]
```

```console
$ cx prog.cx
(true, [err code=ux-refused [ux-refusal code=ux-verb-unaccounted verb=audit]], [err code=ux-refused [ux-refusal code=ux-verb-unaccounted verb=audit note='declared not-offered without a why']])
```

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?let
  [= $ctx {route: "/orders", feature: "orders", path: "/"}]
  [= $ok  [ux:region feature=orders path="/live"
            [ux:filter name=q affects="/live/open/rows"]
            [ux:table id=open [ux:rows id=rows [ux:row key=r1 [ux:cell "a"]]]]]]
  [= $bad [ux:region feature=orders path="/live"
            [ux:filter name=q affects="/live/typo/rows"]
            [ux:table id=open [ux:rows id=rows [ux:row key=r1 [ux:cell "a"]]]]]]
  [; R-A1 migration: envelope → spliced children (2026-08-25) ]
  [list [?splice [$ux:dangling-affects $ok $ctx]] [?splice [$ux:dangling-affects $bad $ctx]]]]
```

```console
$ cx prog.cx
[list [ux-refusal code=ux-dangling-affects element=ux:filter affects='/live/typo/rows']]
```

Oriel runs that gate at boot (`serve.cx:3940-3948`) and wraps it in a
`[?match]` on purpose — the refusal is an **err value**, and as a bare call
operand it would propagate and the log line would never run, which is a silent
gate. The comment at `serve.cx:3949-3952` says exactly that. This is the
err-boundary rule of `primer.md` §6 met in real code.

> Several fixtures below carry a `[; R-A1 migration: envelope → spliced
> children …]` comment. That is not noise you should imitate — it is the
> corpus marking where a call returning a sequence stopped being wrapped in an
> envelope element and became `[?splice …]` in element content, per the rule
> in `primer.md` §5. Read those lines as worked examples of the migration you
> would have to make in your own code.

### The semantic vocabulary is closed

You do not write HTML. You write a **semantic tree** over a closed vocabulary,
and a renderer lowers it. Three closed sets govern what you may write, and the
module reports all three — the element vocabulary first (regions and grouping,
text and values, collections, navigation, queries, writes, flows, depiction),
then the **renderer-private** attribute names a semantic tree may never carry,
then the notice tones:

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[; R-A1 migration: envelope → spliced children (2026-08-25) ]
[list [?splice [$ux:vocabulary]] [?splice [$ux:renderer-private-attrs]] [?splice [$ux:tones]]]
```

```console
$ cx prog.cx
[list 'ux:region' 'ux:card' 'ux:heading' 'ux:text' 'ux:field' 'ux:badge' 'ux:list' 'ux:item' 'ux:table' 'ux:columns' 'ux:column' 'ux:rows' 'ux:row' 'ux:cell' 'ux:nav' 'ux:nav-item' 'ux:link' 'ux:action' 'ux:form' 'ux:input' 'ux:hidden' 'ux:submit' 'ux:error' 'ux:notice' 'ux:filter' 'ux:select' 'ux:option' 'ux:group' 'ux:media' 'ux:grid' 'ux:param' 'ux:steps' 'ux:step' 'ux:quantity' 'ux:breadcrumb' 'ux:crumb' 'ux:pager' 'ux:page-link' 'ux:facet' 'ux:facet-value' 'ux:sort' 'ux:sort-option' 'ux:aside' 'ux:status' 'ux:panel' 'oob' 'target' 'swap' 'ext' 'subscribe' 'on' 'include' 'ok' 'warn' 'danger' 'info' 'neutral']
```

An element outside the vocabulary is refused, and so is an attribute outside
the grant table of the member it sits on — one mistake, one refusal, naming
both the element and the attribute:

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?let
  [= $bad ([ux:action verb=v label=x disabled=true reason="out"],
           [ux:aside label=Basket name=basket],
           [ux:row id=r1 [ux:cell "x"]],
           [ux:filter name=q affects="/rows" over="id status"])]
  [?for [in $e $bad] [yield [$ux:refusals-of $e]]]]
```

```console
$ cx prog.cx
[ux-refusal code=ux-unknown-attr element=ux:action attr=disabled]
[ux-refusal code=ux-unknown-attr element=ux:aside attr=name]
[ux-refusal code=ux-unknown-attr element=ux:row attr=id]
[ux-refusal code=ux-unknown-attr element=ux:filter attr=over]
```

The second set is the sharper one. `target=`, `swap=`, `oob=`, `ext=`,
`subscribe=`, `on=`, `include=` are **renderer-private**: they are how the web
renderer thinks, and a semantic tree that names one has stopped being
renderer-neutral. That is not a hypothetical — an earlier arrangement of this
module let exactly those concepts climb into the vocabulary, and the
neutrality claim was false while they were there. The refusal has its own
code:

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?let
  [= $r [$ux:refusals-of [ux:action verb=v target="#x"]]]
  [= $f [$first $r]]
  [list [$count $r] [$string $f@code]]]
```

```console
$ cx prog.cx
[list 1 'ux-renderer-private-attr']
```

Retired members refuse **by name, with the replacement stated** — there are no
aliases, per the standing no-dual-accept rule.

### Forms project from definitions

You do not hand-author a form. A command — a `[?def]` carrying an `[effects]`
clause — *projects* onto one:

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?let
  [= $src """
[?def place-order scope=public impure [effects [write]] [returns element]
  ($customer::string $qty::int $note::string="")
  [ordered customer=$customer]]
[fn-doc name=place-order scope=public purity=impure
  [summary '''Place a customer order.''']
  [param-doc name=customer '''Who the order is for.''']]
"""]
  [$ux:form $src "place-order" {affects: "/live/new"}]]
```

```console
$ cx prog.cx
[ux:form verb=place-order affects='/live/new' [ux:heading level=2 'Place a customer order.'] [ux:input name=customer kind=string required='true' help='Who the order is for.'] [ux:input name=qty kind=int required='true'] [ux:input name=note kind=string required='false'] [ux:submit label='Place order']]
```

An act verb of a feature grammar projects the same way, which is the seam
between the XAP layer and the UX layer:

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?let
  [= $f [feature name=commerce
             [nouns
               [noun name=order [field name=id type=text] [field name=package type=text]
                                [field name=buyer type=did doc="who is buying"]]
               [noun name=price [field name=amount type=money]]]
             [verbs
               [verb name=place-order effect=act [summary "Place an order"] [writes order]]
               [verb name=quote effect=observe [reads price]]]]]
  [$ux:feature-form $f "place-order" {affects: "/live/new"}]]
```

```console
$ cx prog.cx
[ux:form verb=place-order affects='/live/new' [ux:heading level=2 'Place an order'] [ux:input name=id label=Id kind=text value=''] [ux:input name=package label=Package kind=text value=''] [ux:input name=buyer label=Buyer kind=did value='' help='who is buying'] [ux:submit label='Place order']]
```

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?let
  [= $f [feature name=commerce
             [nouns
               [noun name=order [field name=id type=text] [field name=package type=text]
                                [field name=buyer type=did doc="who is buying"]]
               [noun name=price [field name=amount type=money]]]
             [verbs
               [verb name=place-order effect=act [summary "Place an order"] [writes order]]
               [verb name=quote effect=observe [reads price]]]]]
  [; R-A1 migration: envelope → spliced children (2026-08-25) ]
  [$ux:feature-form $f "cancel-order" {}]]
```

```console
$ cx prog.cx
[err code=ux-refused [ux-refusal code=ux-no-such-verb verb=cancel-order]]
```

The point is that **there is no materialized UI manifest to drift**. The form
is derived at render time from the definition, so a parameter that changed
cannot leave a stale control behind. Richer shapes come from the same
derivation — a reference-typed field projects a chooser, a repeating field
projects a group, and a refusal keeps what the user typed:

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?let
  [= $feature [$cx:parse "[feature name=shop [nouns [noun name=product [field name=sku type=text] [field name=name type=text]] [noun name=line [field name=sku type=product label='Product' doc='chosen, never typed'] [field name=qty type=int label='Qty']] [noun name=order [field name=customer type=text label='Customer'] [field name=lines type=line repeats=true add-label='Add a line']]] [verbs [verb name=place-order [summary 'Place an order.'] [intent [do :place-order [customer] [lines]]] [writes order]]]]"]]
  [= $opts {options: ([options for=product [option value=ESC-18 label="Escapement"] [option value=BAL-9 label="Balance wheel"]]),
            affects: "/f/entry", group-endpoint: true, group-affects: "/f/entry/place-order/lines"}]
  [= $f [$ux:feature-form $feature "place-order" $opts]]
  [$cx:canonical [$first $f//ux:select]]]
```

```console
$ cx prog.cx
"[ux:select name=lines.0.sku label=Product required='true' value=''\n  [ux:option value=ESC-18 Escapement]\n  [ux:option value=BAL-9 Balance wheel]\n]\n"
```

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?let
  [= $feature [$cx:parse "[feature name=shop [nouns [noun name=product [field name=sku type=text] [field name=name type=text]] [noun name=line [field name=sku type=product label='Product' doc='chosen, never typed'] [field name=qty type=int label='Qty']] [noun name=order [field name=customer type=text label='Customer'] [field name=lines type=line repeats=true add-label='Add a line']]] [verbs [verb name=place-order [summary 'Place an order.'] [intent [do :place-order [customer] [lines]]] [writes order]]]]"]]
  [= $opts {options: ([options for=product [option value=ESC-18 label="Escapement"] [option value=BAL-9 label="Balance wheel"]]),
            affects: "/f/entry", group-endpoint: true, group-affects: "/f/entry/place-order/lines"}]
  [= $f [$ux:feature-form $feature "place-order" $opts]]
  [$cx:canonical [$first $f//ux:group]]]
```

```console
$ cx prog.cx
"[ux:group name=lines repeat='true' affects=/f/entry/place-order/lines add-label='Add a line'\n  [ux:card\n    [ux:select name=lines.0.sku label=Product required='true' value=''\n      [ux:option value=ESC-18 Escapement]\n      [ux:option value=BAL-9 Balance wheel]\n    ]\n    [ux:input name=lines.0.qty label=Qty kind=int value='']\n  ]\n]\n"
```

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?let
  [= $feature [$cx:parse "[feature name=shop [nouns [noun name=product [field name=sku type=text] [field name=name type=text]] [noun name=line [field name=sku type=product label='Product' doc='chosen, never typed'] [field name=qty type=int label='Qty']] [noun name=order [field name=customer type=text label='Customer'] [field name=lines type=line repeats=true add-label='Add a line']]] [verbs [verb name=place-order [summary 'Place an order.'] [intent [do :place-order [customer] [lines]]] [writes order]]]]"]]
  [= $opts {options: ([options for=product [option value=ESC-18 label="Escapement"] [option value=BAL-9 label="Balance wheel"]]),
            affects: "/f/entry", group-endpoint: true, group-affects: "/f/entry/place-order/lines"}]
  [= $vals ([val name=customer text=""], [val name="lines.0.sku" text="BAL-9"], [val name="lines.0.qty" text="2"])]
  [= $errs ([field-error name=customer message="who is this order for?"])]
  [= $f [$ux:feature-form $feature "place-order" [$cx:merge $opts {values: $vals, errors: $errs}]]]
  [$cx:canonical [$first $f//ux:input]]]
```

```console
$ cx prog.cx
"[ux:input name=customer label=Customer kind=text value='' error='who is this order for?']\n"
```

### Identity is content-addressed

A fragment's identity is exactly the triple `(route, feature, element path)` —
theme, locale, actor, session and data are *content*, never identity:

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?let [= $f [$ux:frag "/orders/o-1041" "orders" "/open-orders/status"]]
  [list [$ux:frag-address $f] [$ux:frag-id $f]]]
```

```console
$ cx prog.cx
[list 'sha2-256:e1029934ea3a0804f9d5aab65a3933242fb692cbf15eeac4b7bb83c6899025d6' 'cx-e1029934ea3a0804']
```

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?let [= $a [$ux:frag "/orders" "orders" "/open"]]
      [= $b [$ux:frag "/orders" "orders" "/open"]]
      [= $c [$ux:frag "/orders" "orders-b" "/open"]]
  [list [= [$ux:frag-id $a] [$ux:frag-id $b]] [= [$ux:frag-id $a] [$ux:frag-id $c]]]]
```

```console
$ cx prog.cx
[list true false]
```

The DOM id is a *derived rendering* of that address, not a second identity,
and a reused address is a refusal rather than a silent disambiguation:

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?let
  [= $t [ux:region feature=orders path="/live"
          [ux:card id=open [ux:heading level=2 "Open"]]
          [ux:form verb=place-order [ux:submit label="Go"]]]]
  [?for [in $p [$ux:address-pairs $t {route: "/orders", feature: "orders", path: "/"}]]
    [yield [$string $p@id]]]]
```

```console
$ cx prog.cx
'cx-b9aa0e4902fe6a43'
'cx-70c02252bf05598f'
'cx-25ff65bbcc985af2'
```

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?let
  [= $ctx {route: "/o", feature: "f", path: "/"}]
  [= $dup [ux:region feature=f path="/r" [ux:card id=same [ux:text "a"]] [ux:card id=same [ux:text "b"]]]]
  [= $ok  [ux:region feature=f path="/r" [ux:card id=one [ux:text "a"]] [ux:card id=two [ux:text "b"]]]]
  [; R-A1 migration: envelope → spliced children (2026-08-25) ]
  [list [?splice [$ux:address-collisions $dup $ctx]] [?splice [$ux:address-collisions $ok $ctx]]]]
```

```console
$ cx prog.cx
[list [ux-refusal code=ux-address-reused id=cx-bfb773fba6d60c77]]
```

Rows key by their **declared key** or get no address at all. Positional row
identity is never minted:

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?let
  [= $rows ([order id=o-1 customer="Ada"], [order id=o-2 customer="Lin"])]
  [$ux:table $rows {id: "open"}]]
```

```console
$ cx prog.cx
[ux:table id=open [ux:columns [ux:column 'Customer'] [ux:column 'Id']] [ux:rows id=rows [ux:row [ux:cell 'Ada'] [ux:cell 'o-1']] [ux:row [ux:cell 'Lin'] [ux:cell 'o-2']]]]
```

### The web renderer, and what it is forbidden to author

`cx-x/ux-web` lowers the semantic tree to HTML plus a **pinned htmx subset**.
It is the sole author of those attributes, and the list is closed:

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?lib 'cx-x/ux-web' :as web]
[; R-A1 migration: envelope → spliced children (2026-08-25) ]
[list [?splice [$web:htmx-subset]] [$web:htmx-allowed "hx-post"] [$web:htmx-allowed "hx-on"] [$web:htmx-allowed "hx-boost"]]
```

```console
$ cx prog.cx
[list 'hx-get' 'hx-post' 'hx-target' 'hx-swap' 'hx-swap-oob' 'hx-trigger' 'hx-include' 'hx-indicator' 'hx-ext' 'sse-connect' 'sse-swap' true false false]
```

`hx-on` is excluded **permanently** — it is what would force `unsafe-inline`
into `script-src`. Enforcement is two-sided: a name gate at authorship, and a
re-scan of the *serialized bytes* so a path that bypassed the constructor
still goes red:

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?lib 'cx-x/ux-web' :as web]
[; R-A1 migration: envelope → spliced children (2026-08-25) ]
[list [?splice [$web:off-subset-attrs "<div hx-post=\"/x\" hx-target=\"#y\"></div>"]]
      [?splice [$web:off-subset-attrs "<div hx-on=\"click: x\" hx-boost=\"true\"></div>"]]]
```

```console
$ cx prog.cx
[list [ux-refusal code=ux-attr-off-subset attr=hx-on] [ux-refusal code=ux-attr-off-subset attr=hx-boost]]
```

Escaping is **structural**. Fragments compose as trees and serialize once, so
there is no interpolation surface to inject into:

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?lib 'cx-x/ux-web' :as web]
[$web:render
  [ux:card [ux:text "R & D <team> \"quoted\""] [ux:field label="A & B" "<script>alert(1)</script>"]]
  {route: "/o", feature: "f", path: "/"}]
```

```console
$ cx prog.cx
'<section class="ux-card"><p class="ux-text">R &amp; D &lt;team&gt; "quoted"</p><div class="ux-field"><span class="ux-field-label">A &amp; B</span><span class="ux-field-value">&lt;script&gt;alert(1)&lt;/script&gt;</span></div></section>'
```

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?lib 'cx-x/ux-web' :as web]
[; R-A1 migration: envelope → spliced children (2026-08-25) ]
[list [?splice [$web:csp-violations "<div style=\"x\"></div>"]]
      [?splice [$web:csp-violations "<script>alert(1)</script>"]]
      [?splice [$web:csp-violations "<div onclick=\"x\"></div>"]]
      [?splice [$web:csp-violations "<script src=\"/static/htmx.min.js\" integrity=\"sha384-a\"></script>"]]]
```

```console
$ cx prog.cx
[list [ux-refusal code=ux-inline-style] [ux-refusal code=ux-inline-script] [ux-refusal code=ux-inline-script] [ux-refusal code=ux-event-handler]]
```

Here is a complete rendered fragment — a region containing a card, a heading,
and an action. Read the `hx-target`: it is **derived** from the semantic
`affects=` path through the same fragment id that minted the target's own id,
so it cannot drift from what the emitter actually produced. Nothing in the
semantic tree named a selector:

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?lib 'cx-x/ux-web' :as web]
[?let
  [= $ctx {route: "/orders", feature: "orders", path: "/", bind: [ux:render-ctx [swap default=outerHTML]]}]
  [$web:render
    [ux:region feature=orders path="/open-orders"
      [ux:card id=summary
        [ux:heading level=2 "Open orders"]
        [ux:action verb=place-order label="Place order" affects="/open-orders"]]]
    $ctx]]
```

```console
$ cx prog.cx
'<section class="ux-region" id="cx-0c97f153f9ac3076" data-cx-frag="[frag\n  [route /orders]\n  [feature orders]\n  [path /open-orders]\n]\n"><section class="ux-card" id="cx-af0e55ddefd36714" data-cx-frag="[frag\n  [route /orders]\n  [feature orders]\n  [path /open-orders/summary]\n]\n"><h2 class="ux-heading">Open orders</h2><form class="ux-action-form" method="post" action="/intent/place-order" hx-post="/intent/place-order" hx-target="#cx-0c97f153f9ac3076" hx-swap="outerHTML"><button type="submit" class="ux-action">Place order</button></form></section></section>'
```

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?lib 'cx-x/ux-web' :as web]
[$web:render
  [ux:table id=grid
    [ux:rows [ux:row key=r1 [ux:cell "a"]] [ux:row [ux:cell "b"]]]]
  {route: "/o", feature: "orders", path: "/"}]
```

```console
$ cx prog.cx
'<table class="ux-table" id="cx-9488f4b5edb0421b" data-cx-frag="[frag\n  [route /o]\n  [feature orders]\n  [path /grid]\n]\n"><tbody class="ux-rows"><tr class="ux-row" id="cx-0c605a4e78d087b1" data-cx-frag="[frag\n  [route /o]\n  [feature orders]\n  [path \'/grid/row[r1]\']\n]\n"><td class="ux-cell">a</td></tr><tr class="ux-row"><td class="ux-cell">b</td></tr></tbody></table>'
```

Liveness comes from the render context's binding for a logical feed name,
never from the tree:

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?lib 'cx-x/ux-web' :as web]
[?let
  [= $rctx [ux:render-ctx
             [feed name=orders endpoint="/stream" event="orders-changed"]
             [fragment affects="/live/open/rows" endpoint="/orders/rows"]
             [swap default=outerHTML]]]
  [= $ctx {route: "/orders", feature: "orders", path: "/", bind: $rctx}]
  [= $r [$web:render [$ux:feed "orders" "/open" "orders" [ux:text "live"]] $ctx]]
  [list $r [$web:off-subset-attrs $r] [$web:csp-violations $r]]]
```

```console
$ cx prog.cx
[list '<section class="ux-region" id="cx-2905217911f2a7e8" data-cx-frag="[frag\n  [route /orders]\n  [feature orders]\n  [path /open]\n]\n" hx-ext="sse" sse-connect="/stream"><p class="ux-text">live</p></section>']
```

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?lib 'cx-x/ux-web' :as web]
[?let
  [= $rctx [ux:render-ctx
             [feed name=layout endpoint="/stream" event="layout-changed" region-refetch="/home/body"]
             [feed name=basket endpoint="/stream" event="basket-changed"]
             [swap default=outerHTML]]]
  [= $c0 {route: "/", feature: "home", path: "/", bind: $rctx}]
  [= $listener [$web:render [ux:region feature=home path="/home" live=layout [ux:text "x"]] $c0]]
  [= $owner    [$web:render [ux:region feature=shell path="/shell" live=basket [ux:text "x"]] $c0]]
  [list $listener [$contains [$string $owner] "sse-connect"] [$contains [$string $listener] "sse-connect"]]]
```

```console
$ cx prog.cx
[list '<section class="ux-region" id="cx-61b6533d57b9b944" data-cx-frag="[frag\n  [route /]\n  [feature home]\n  [path /home]\n]\n" hx-get="/home/body?return=%2F" hx-trigger="sse:layout-changed" hx-target="this" hx-swap="outerHTML"><p class="ux-text">x</p></section>' true false]
```

### Refusals are part of the surface

A projection failure never reaches a browser as content:

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?lib 'cx-x/ux-web' :as web]
[; R-A1 migration: envelope → spliced children (2026-08-25) ]
([$web:render [ux:action verb=v target="#x"] {route: "/o", feature: "f", path: "/"}],
 [$web:render [ux:region feature=f path="/r" [ux:card id=d] [ux:card id=d]] {route: "/o", feature: "f", path: "/"}])
```

```console
$ cx prog.cx
([err code=ux-refused [ux-refusal code=ux-renderer-private-attr element=ux:action attr=target]], [err code=ux-refused [ux-refusal code=ux-address-reused id=cx-fa5c41a015045bf8]])
```

A field-level refusal lands **on its own control**, with the message beside it
and both reaching a screen reader:

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?lib 'cx-x/ux-web' :as web]
[?let
  [= $t [ux:form verb=place-order
          [ux:input name=customer label="Customer" error="who is this order for?"]
          [ux:submit label="Place order"]]]
  [$web:render $t {route: "/o", feature: "f", path: "/"}]]
```

```console
$ cx prog.cx
'<form class="ux-form ux-busy" method="post" action="/intent/place-order" id="cx-75350d510997b9f4" data-cx-frag="[frag\n  [route /o]\n  [feature f]\n  [path /place-order]\n]\n" hx-post="/intent/place-order" hx-indicator="#cx-75350d510997b9f4"><div class="ux-control-field"><label class="ux-label" for="cx-75350d510997b9f4-customer">Customer</label><input class="ux-control ux-control-bad" id="cx-75350d510997b9f4-customer" name="customer" type="text" aria-invalid="true"><span class="ux-field-error">who is this order for?</span></div><button type="submit" class="ux-action ux-submit">Place order</button></form>'
```

And removing a line is an empty response with a renderer-minted control — no
script involved anywhere:

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?lib 'cx-x/ux-web' :as web]
[?let
  [= $rctx [ux:render-ctx
             [feed name=orders endpoint="/stream" event="orders-changed"]
             [fragment affects="/live/open/rows" endpoint="/orders/rows"]
             [swap default=outerHTML]]]
  [; R-A1 migration: envelope → spliced children (2026-08-25) ]
  [= $t [ux:group name=lines label="Lines" affects="/f/entry/place-order/lines" add-label="Add a line"
          [ux:card [ux:input name="lines.0.qty" label="Qty"]]]]
  [$web:render $t {route: "/o", feature: "f", path: "/entry/place-order", fragment: true, bind: $rctx}]]
```

```console
$ cx prog.cx
[err code=ux-refused [ux-refusal code=ux-dangling-affects element=ux:group affects='/f/entry/place-order/lines']]
```

### One tree, two serializations

This is the property that makes an agent a first-class client rather than a
scraper. The handler builds **one** semantic tree and the request chooses the
serialization:

```cx
[body [?if [$wants-cx $request]
        [then [$cx:canonical [$view $rctx2 $c0 $body]]]
        [else [$web:page-html "ORIEL" $assets $body $c0]]]]
```

`spec/03-approved/xap/demos/oriel/serve.cx:4000-4002`. `$view` wraps the tree
in the `[ux:view [route …] [feature …] [path …] $rctx [ux:tree …]]` envelope
(`serve.cx:52-54`) — that five-child element is the agent-parity wire format.

Equivalence between the two faces is not asserted, it is **computed**. The
content normal form strips presentation, and the renderers are checked against
it:

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?let [= $t [ux:card
                [ux:heading level=2 "Open orders"]
                [ux:field label="Customer" "Ada"]
                [ux:field label="Status" [ux:badge tone=warn "late"]]
                [ux:input name=qty kind=int required=true]
                [ux:action verb=place-order label="Place order"]]]
  [$ux:content-repr $t]]
```

```console
$ cx prog.cx
"[c:card\n  [c:heading level='2' Open orders]\n  [c:field label=Customer Ada]\n  [c:field label=Status\n    [c:badge tone=warn late]\n  ]\n  [c:input name=qty label=Qty required='true' error='' '']\n  [c:action verb=place-order label='Place order']\n]\n"
```

`prog.cx`
```cx
[?lib 'cx-x/ux' :as ux]
[?lib 'cx-x/ux-web' :as web]
[?let
  [= $t [ux:card [ux:heading level=2 "Open"] [ux:field label="Customer" "Ada"]
                 [ux:badge tone=warn "late"] [ux:action verb=place-order label="Go"]]]
  [= $ctx {route: "/o", feature: "f", path: "/"}]
  [list [= [$ux:content-repr $t] [$web:content-repr-html $t $ctx]] [$web:content-repr-html $t $ctx]]]
```

```console
$ cx prog.cx
[list true "[c:card\n  [c:heading level='2' Open]\n  [c:field label=Customer Ada]\n  [c:badge tone=warn late]\n  [c:action verb=place-order label=Go]\n]\n"]
```

### Act from inside a collection

The single most common enterprise-UI mistake CX's vocabulary is designed to
prevent: an `[ux:action]` may sit inside an `[ux:item]` or `[ux:row]` and
carry its parameters from that item. N items produce N addressable actions.

Parameters are **server-derived at projection time and never read back out of
the rendered document**. An item whose price changed between render and click
posts the price it was rendered with, and the command layer refuses it — which
is the correct outcome, and the one a DOM read cannot produce. A *missing*
parameter is a projection refusal, because the alternative produces a command
refusal that blames the user for the projection's bug.
`spec/03-approved/xap/ux.md:1023-1042`.

## 8. Test it: the drive-step pattern

Parity between faces is a ruled requirement, and it has broken more than once
— so it is checked by a program rather than asserted in a note.
`spec/03-approved/xap/demos/oriel/drive.cx` is the reference harness. Four
pieces:

1. **Wire readers.** `get-view` requests `Accept: application/cx` and parses
   the answer (`drive.cx:34-38`); `get-html` fetches the other face
   (`:40-42`); `vtree` / `vctx` unpack the `[ux:view]` envelope (`:54-64`).
2. **A driver that uses the shipped wire.** `post-raw` posts to
   `/intent/<verb>` with `follow-redirects: false` (`:70-72`), and
   `post-headers` toggles `HX-Request: true` for the fragment lane (`:74-83`).
   Nothing supplies a scope — the server derives it from the cookie it set.
3. **Steps are values.** `[?def check]` returns
   `[step name= ok="PASS"|"FAIL" detail=]` (`:132-133`), so the harness output
   is a document you can query rather than a log you must read.
4. **Assertions that catch both directions.** `equivalence` (`:147-162`) takes
   the content-normal-form of a **live route** three ways — semantic, web,
   terminal — "because it catches a renderer that drops content **and** one
   that invents it". `paints` (`:167-182`) renders through the terminal face
   and measures the focus ring, because a face with no pointer cannot hide an
   unreachable control, so the ring's size *is* the keyboard-reachability
   measurement.

It is headless on purpose: "a proof that needs a human at a keyboard is not a
proof anyone can re-run" (`drive.cx:9-10`).

**One trap the header calls out** (`drive.cx:12-15`): a bare `--allow-net`
denies a loopback literal, and every step then silently reports `offline`.
Scope the grant.

## 9. What the rulings forbid

The prohibitions are as teachable as the requirements, because each one names
a failure mode that looks like success.

**No dual-accept.** When a surface changes, the old spelling is *removed*, not
kept alongside the new one. Retired UX members refuse by name with the
replacement stated; retired CLI verbs name their own retirement. There is no
compatibility alias anywhere, deliberately — two spellings for one meaning is
two things to keep true.

**No silent partials.** A gate over the empty set refuses rather than
reporting green (`xap-compose-051`). A `[sources]` block with no rows refuses
rather than binding nothing. A composition reports *every* W-violation rather
than the first (`xap-compose-014`). The pattern: a check that cannot do its
job says so.

**No error-as-silent-data.** An externalizing effect refuses to carry an
`[err]` out of the program unless you wrote `errs=:permit`. This closes the
`written=0 errors=25`, exit 0 class and the render-`[err]`-into-HTML class at
the boundary, which is the only honest place. See `primer.md` §6.

`prog.cx`
```cx
[?lib 'cx-stdlib/store']
[?let [= $s [$store:open "mem://"]]
      [= $rows ([row [v 2.5]], [err code=cx-err:CXER0100 message="a refusal at rest"], [row [v 4.5]])]
  [$store:put-doc $s [report [count [$count $rows]] [?splice $rows]]]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER0275 message='E_ERR_AT_BOUNDARY: refusing the store document write — the document contains cx-err:CXER0100 at /report/err; a refusal must not leave the program as silent data (pass errs=:permit on the effect to externalize it deliberately)' err-path='/report/err' err-code=cx-err:CXER0100]
```

**No guessing at ambiguity.** ρ returns a value listing the candidates. A
composite never resolves to "probably this one".

**No auto-splicing.** A sequence value in element-content position refuses and
names `[?splice]`. Nothing silently rewrites what you wrote.

**No laundering authority through a wrapper.** A grant on a composite verb's
own name conveys nothing; the transitive leaf set is what the PEP evaluates.

**No selectors in a semantic tree.** Every htmx spelling is derived from a
semantic declaration plus render context. A hand-written selector could drift
from what the emitter minted — and once did.

**No interpolation.** Fragments compose as trees and serialize once. If you
find yourself concatenating markup, you have left the supported path.

**No bearer material in a journal.** Write a derived, non-invertible key.

**No enforcement in the browser.** The PEP rechecks at the wire; a refusal is
plain and does not disclose capability structure. Hiding a control is a
courtesy, never a control.

**No inventing a module, a directive, or a block.** If it is not in the
directive registry (`primer.md` §4), the module catalog
(`reference-stdlib.md`), or the `[xap]` child set (§5 above), it does not
exist. This is the most expensive mistake to make with a young language,
because the result is plausible and wrong.

## 10. Before you ship

1. Every feature document has `[nouns]`, `[verbs]`, **and** `[requirements]`.
2. `[$xap:compose-report]` says `ok=true` over the real feature set — and the
   set is non-empty.
3. Every derived noun declares `[from …]`, every reference in it resolves, and
   exactly one declared deriver produces it.
4. No grammar verb `[writes]` a derived noun.
5. The deployment document's children are all in the ruled set. You did not
   invent `[transport]`.
6. `[runtime]` names each option key verbatim; `[sources]` has at least one
   row; `[log-reduce] fn=` names a def of a pinned feature.
7. Deriver rows and an OPTS `derivers:` key are not both present — the
   document wins, and the drop is announced.
8. `[host-auth]` is present for anything not on a localhost dev floor, with
   `[identity]` fail-closed and a `[principal]` row for every DID that needs a
   dial.
9. Principals were minted offline and their grants spliced into config by an
   operator.
10. Every act verb is offered by some route; every `affects=` resolves.
11. The surface tree is semantic — no selector, no htmx attribute, no inline
    style, no concatenated markup.
12. Both faces agree under the content normal form, and you ran the check.
13. Every externalizing effect either carries no `[err]` or says
    `errs=:permit`.
14. You ran it. `cx <file>` is a second, and a plausible-looking XAP that
    does not compose costs a reviewer much more than that.

## Where the evidence lives

| Topic | Normative source |
|---|---|
| Composition algebra, W-gates, derived nouns, derivers | `spec/03-approved/xap/xap_grammar_composition.md` |
| Distribution, the deployment host, `[runtime]` bindings | `spec/03-approved/xap/xap_feature_distribution_market.md` |
| `[xap]` document schema | `spec/03-approved/xap/xap_schemas/xap.cxs` |
| Host channel auth, principals, attach | `spec/03-approved/xap/xap_identity_model.md` |
| The UX projection and the emitter contract | `spec/03-approved/xap/ux.md` |
| The paradigm and its frozen invariants | `spec/03-approved/xap/xap.md` |
| The effect boundary | `spec/03-approved/core/commands_effects.md` |
| Composition + authority + distribution, worked | `reference/shop/` |
| The projection, worked | `spec/03-approved/xap/demos/oriel/` |

Every example above is a case in `conformance/`; the release gate fails if any
of them stops holding.
