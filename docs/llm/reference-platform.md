# Reference: the platform and ecosystem rings — v0.17.0

> **GENERATED.** Source: `docs-src/llm/reference-platform.md.tmpl` + the
> conformance corpus. Every output was re-recorded from the `cx` v0.17.0
> binary. Read `primer.md` first.

## Ring 2 — the platform

Ring 2 is where data outlives a process and where more than one party is
involved: the store and its journal, the session layer, the HTTP surface, the
XAP host, the fabric, database drivers.

**Ring 2 is reached over a network, not embedded.** The store engine imports
Ring 0 only and contains no evaluator, so running a platform does not drag a
server into every program that merely reads data. That is the property that
keeps Rings 0 and 1 auditable, and it is enforced by the build, not by
convention.

### The store — content-addressed documents

`open` takes a URL. `mem://` is the in-process substrate and needs no
capability at all, which makes the whole functional matrix runnable in a
plain `cx` invocation:

`prog.cx`
```cx
[?lib 'cx-stdlib/store']
[?let [= $s [$store:open "mem://"]] [= $h [$store:put-doc $s [doc [item "hello"]]]] [$store:get-doc $s $h]]
```

```console
$ cx prog.cx
[doc [item 'hello']]
```

A handle is derived from the document's canonical bytes, so putting the same
document twice yields the same handle — identity is a property of content,
not of insertion order:

`prog.cx`
```cx
[?lib 'cx-stdlib/store']
[?let [= $s [$store:open "mem://"]] [= $h1 [$store:put-doc $s [doc [item "hello"]]]] [= $h2 [$store:put-doc $s [doc [item "hello"]]]] [= $h1 $h2]]
```

```console
$ cx prog.cx
true
```

Two different documents cannot collide into one handle:

`prog.cx`
```cx
[?lib 'cx-stdlib/store']
[?let [= $s [$store:open "mem://"]] [= $h1 [$store:put-doc $s [doc [item "a"]]]] [= $h2 [$store:put-doc $s [doc [item "b"]]]] [= $h1 $h2]]
```

```console
$ cx prog.cx
false
```

Absence and refusal are values, not exceptions. A missing handle, a
malformed handle, and a handle naming an unknown hash algorithm are three
distinct answers:

`prog.cx`
```cx
[?lib 'cx-stdlib/store']
[?let [= $s [$store:open "mem://"]] [$store:get-doc $s "sha2-256:0000000000000000000000000000000000000000000000000000000000000000"]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER1121 message='E_STORE_NOT_FOUND: sha2-256:0000000000000000000000000000000000000000000000000000000000000000']
```

`prog.cx`
```cx
[?lib 'cx-stdlib/store']
[?let [= $s [$store:open "mem://"]] [$store:get-doc $s "deadbeef"]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER0130 message='E_STORE_ADDRESS_INVALID: bare hex is not an address — tagged form `<algo>:<hex>` required since I1 (e.g. `sha2-256:…`) (cx-err:CXER0130)']
```

Aliases give a mutable name over immutable content:

`prog.cx`
```cx
[?lib 'cx-stdlib/store']
[?let [= $s [$store:open "mem://"]] [= $h [$store:put-doc $s [doc [item "hello"]]]] [= $a [$store:set-alias $s "latest" $h]] [$store:get-alias $s "latest"]]
```

```console
$ cx prog.cx
'sha2-256:6d8460dd10c5fb09c542c81d617efef1eba054a71755f4e1c96a6af7830ddeeb'
```

A read-only store refuses writes rather than accepting and dropping them:

`prog.cx`
```cx
[?lib 'cx-stdlib/store']
[?let [= $s [$store:open-opts "mem://" [map read-only="true"]]] [$store:put-doc $s [doc [item "x"]]]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER1110 message='E_STORE_READ_ONLY: mem://']
```

### Writes are an effect boundary — errors do not leave silently

A store *document* write externalizes. It refuses to carry a document
containing an `[err]` at any depth out of the program:

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

The guarded verbs are `put-doc`, `put-doc-stream`, `put-doc-text` (it stores a
*parsed* document) and `modify-doc` (its action payload is the injection
vehicle). Blob and byte writes are exempt by construction — bytes carry no
`[err]` to find. Storing a refusal *deliberately* is legal and explicit:

`prog.cx`
```cx
[?lib 'cx-stdlib/store']
[?let [= $s [$store:open "mem://"]]
      [= $h [$store:put-doc $s [report [err code=cx-err:CXER0100 message="stored deliberately"]] {errs: :permit}]]
  [$store:get-doc $s $h]]
```

```console
$ cx prog.cx
[report [err code=cx-err:CXER0100 message='stored deliberately']]
```

`prog.cx`
```cx
[?lib 'cx-stdlib/store']
[?let [= $s [$store:open "mem://"]]
      [= $h [$store:put-doc $s [doc [item "x"]]]]
  [$store:modify-doc $s $h [append [err code=cx-err:CXER0100 message="injected"]]]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER0275 message='E_ERR_AT_BOUNDARY: refusing the store document write — the document contains cx-err:CXER0100 at /append/err; a refusal must not leave the program as silent data (pass errs=:permit on the effect to externalize it deliberately)' err-path='/append/err' err-code=cx-err:CXER0100]
```

The same rule governs HTTP response emission, with the refusal as a loud 500.
`$journal:append` and `$fabric:emit` are deliberately **not** guarded: a
journal is exactly where error events belong, and fabric emit is channel-shaped
fan-out.

### The journal — history you can replay

The journal is an append-only chain: each entry links the previous one, so
the history is verifiable rather than merely stored.

`prog.cx`
```cx
[?lib 'cx-stdlib/journal']
[?let [= $j [$journal:open "mem://acme" "acme"]]
  [$journal:append $j [do :refund] {actor: "ops" authority: "d-77"}]]
```

```console
$ cx prog.cx
[entry seq=1 tenant=acme actor=ops authority=d-77 ts='1970-01-01T00:00:01Z' prev-hash='genesis:' payload='sha2-256:1c28ab1fd422c356d61afc4be98fe2ff836d21b306487a4d67a62b40fc762ec5' hash='sha2-256:902dfe8cf83616e030e70ec30429c632601d4bd29308b757049706a3afb218a4' [event [do :refund]]]
```

`prog.cx`
```cx
[?lib 'cx-stdlib/journal']
[?let [= $j [$journal:open "mem://t" "acme"]]
[= $e1 [$journal:append $j [a 1] {actor: "u" authority: "g"}]]
[= $e2 [$journal:append $j [b 2] {actor: "u" authority: "g"}]]
  [$journal:read $j 2]]
```

```console
$ cx prog.cx
[entry seq=2 tenant=acme actor=u authority=g ts='1970-01-01T00:00:02Z' prev-hash='sha2-256:69c69761d531660401aa7275810f13828b1db1430511243efbaddc053637311d' payload=sha2-256:e74783796d0d83dfce07552c3773cc9ab4f270fbeb19ada5438a363d79b08e18 hash='sha2-256:1d4f5830f65cd9c6b37aa82309376cb3933b6ff91b7d0c7ef877d4403c9dabb0' [event [b 2]]]
```

Reading past the end is absence, not an error:

`prog.cx`
```cx
[?lib 'cx-stdlib/journal']
[?let [= $j [$journal:open "mem://t" "acme"]]
  [$journal:read $j 5]]
```

```console
$ cx prog.cx
()
```

### HTTP

Status codes are values you can ask questions about, which is what makes an
HTTP result composable with the rest of the language instead of needing a
separate error channel:

`prog.cx`
```cx
[?lib 'cx-stdlib/http']
[$http:status [response status=404]]
```

```console
$ cx prog.cx
404
```

`prog.cx`
```cx
[?lib 'cx-stdlib/http']
[$http:ok [response status=404]]
```

```console
$ cx prog.cx
false
```

Serving is `[?http-service]` with `[block true]`; the guide's own static
server (`scripts/gen_guide/guide_serve.cx`) is the worked example in-repo.
Anything that dials or listens needs `--allow-net`, optionally scoped:
`--allow-net=example.com:443`.

### Identity and authority

Two layers sit between a request and an effect, and they answer different
questions. **Session** answers *who is this*. **Authz** answers *may they*.

A session binds a `(principal, tenant)` pair for its whole life — the binding
is immutable, and rebinding is a refusal, not an update. A deployment that
admits an anonymous floor says so in its attach policy, and the floor is a
*real* principal, not the absence of one:

`prog.cx`
```cx
[?lib 'cx-stdlib/session']
[?let [= $pair [$session:attach-guest [request scheme="https"] {anonymous-floor: "web-public" tenant: "shop"}]] [= $s [$first $pair]] [?let [= $p [$session:principal $s]] $p@id]]
```

```console
$ cx prog.cx
'web-public'
```

Refusal is the common case. Without a declared floor, a guest attach is a
clean typed refusal naming the policy — deny-by-default all the way down:

`prog.cx`
```cx
[?lib 'cx-stdlib/session']
[$session:attach-guest [request scheme="https"] {tenant: "shop"}]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4812 message='E_SESSION_ANONYMOUS_REFUSED: the deployment attach policy does not admit an anonymous floor — no `anonymous-floor` principal in cfg (xap_identity_model §4.7; refusing is the production default)']
```

Authority is **delegated, attenuating, and rooted in a principal**. A permit
names the chain it came through:

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

A denial is a *value* carrying its reason, not an exception. There is no
implicit grant anywhere:

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

And the decision explains itself — the first failing link, by name, which is
what makes an authority chain auditable rather than merely enforced:

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

### Operating a platform

```console
cx store-serve config.cx      # the store service daemon
cx fabric-serve config.cx     # the fabric eventing daemon
cx store-health URL           # readiness probe (exit 0 iff accepting)
cx store-rotate-kek …         # rotate a key-encryption key
cx store-mint-principal …     # mint an XSP-AUTH principal, offline
```

All take a CX configuration document or an explicit target. There is
deliberately no supervisor integration in-repo: lifecycle is the operator's,
explicitly.

#### The clean-state bootstrap

A daemon is deny-by-default, so a fresh deployment has nobody who may talk to
it. The bootstrap is an **offline identity mint** — nothing transits a wire,
no store is opened, and there is no trust-on-first-use step:

```console
cx store-mint-principal --id fleet-ops \
    --seed-file ./secrets/fleet-ops.seed --caps "read write"
```

That generates an Ed25519 seed, derives its `did:key`, writes the seed at mode
0600 (never to stdout), and prints two things: the `[grant …]` row for the
daemon config's `[xsp [grants …]]` table, and the client's `xsp-did` /
`xsp-seed-env` open-opts. The minted principal is **inert** until an operator
splices that grant into the config — **config remains the sole authority**.

`--for identity` prints the daemon's *own* `[xsp [identity did= seed-env=]]`
responder row instead. `--caps` is required: the authority a grant carries is
an explicit choice at mint time, with no default. The seed environment
variable is *derived* from `--id` (`CX_XSP_SEED_<NAME>`, upper-cased with `-`
folded to `_`), so an `--id` whose derivation would collide with another is
refused by name rather than silently sharing one seed.

The full arc is: **mint → splice the grant into the config → start the
deny-by-default daemon → the client presents its DID.**

#### Retired verbs answer for themselves

`cx store-token` was retired at v0.16.0 — the bearer/RBAC plane is gone. It
does not answer "unknown subcommand"; it names its own retirement and points
at the replacement. If you recall a store verb that is not in `cx --help`,
run it: the tool will tell you what replaced it.

## Ring 3 — the ecosystem

Ring 3 is everything *around* CX: feature distribution, the registry, the
language bindings, and agent interop. It is the ring most under construction;
what follows is what ships.

### Agent interop — MCP and A2A

CX command definitions (an `[?def]` carrying an `[effects …]` clause) project
to tool descriptors, and the protocol shapes are ordinary CX values emitted
to their wire form. Nothing here is a bespoke serializer:

`prog.cx`
```cx
[?lib 'cx-x/mcp' :as mcp]
[?lib 'cx-stdlib/json' :as json]
[$json:emit [$mcp:list-tools-request 2]]
```

```console
$ cx prog.cx
'{"id":2,"jsonrpc":"2.0","method":"tools/list"}'
```

`prog.cx`
```cx
[?lib 'cx-x/mcp' :as mcp]
[?lib 'cx-stdlib/json' :as json]
[$mcp:validate-args
  [$json:parse "{\"name\":\"w\",\"inputSchema\":{\"type\":\"object\",\"required\":[\"location\"],\"properties\":{\"location\":{\"type\":\"string\"}}}}"]
  [$json:parse "{\"location\":\"NYC\"}"]]
```

```console
$ cx prog.cx
[ok]
```

Argument validation refuses rather than defaulting, so a malformed tool call
fails at the boundary:

`prog.cx`
```cx
[?lib 'cx-x/mcp' :as mcp]
[?lib 'cx-stdlib/jsonschema' :as js]
[?lib 'cx-stdlib/json' :as json]
[$js:violation-paths
  [$mcp:validate-args
    [$json:parse "{\"name\":\"w\",\"inputSchema\":{\"type\":\"object\",\"required\":[\"location\"]}}"]
    [$json:parse "{}"]]]
```

```console
$ cx prog.cx
('/location')
```

The A2A shapes are the same story on the agent-to-agent side:

`prog.cx`
```cx
[?lib 'cx-x/a2a' :as a2a]
[?lib 'cx-stdlib/json' :as json]
[$json:emit [$a2a:agent-card "greeter" "says hi" "http://x/" "0.1" ()]]
```

```console
$ cx prog.cx
'{"capabilities":{"streaming":false},"description":"says hi","name":"greeter","skills":[],"url":"http://x/","version":"0.1"}'
```

The projection itself is offline and inspectable:

```console
cx tools export MODULE.cx     # command defs -> tool descriptors
```

Enforcement stays at the CX effect point (`cx-err:CXER0271`) regardless of
what any client claims — descriptor annotations are hints, and hints are
lossy downward.

### Features (XAPs) and distribution

A XAP is the unit of packaged CX functionality — a *feature*, never an
"app". Scaffolding and surface checking are CLI verbs:

```console
cx xap init NAME              # scaffold a feature
cx xap check-surface DIR      # the surface derivation check
cx lock                       # generate / verify cx.lock from [?lib] imports
```

Feature grammars **compose**, and composition is an algebra with laws rather
than a merge convention. Composing is commutative, associative, and
idempotent, and the composed grammar has a Tier-1 hash that is the equality
oracle:

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

Names qualify on the way in, so two features may each own a `highlight`
without collision:

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

Composing *nothing* is a refusal, not a vacuous pass — a gate over the empty
set has verified the empty set, which is the one failure mode that makes a
gate worse than no gate:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[$xap:compose]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4874 message='E_XAP_COMPOSE_EMPTY: composition has no features — a gate over the empty set verifies nothing (§3.1 identity)']
```

Distribution is seal → sign → publish → install, and **the transport is the
store**. There is no separate package wire and no new protocol. A package
tree is content-addressed, so entry order cannot change its identity:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[?lib 'cx-stdlib/store' :as store]
[?let [= $s [$store:open "mem://"]]
 [= $t1 [$xap:pkg-tree ([entry path='b.cx' 'bee'], [entry path='a.cx' 'ay'])]]
 [= $t2 [$xap:pkg-tree ([entry path='a.cx' 'ay'], [entry path='b.cx' 'bee'])]]
 [= [$store:put-doc $s $t1] [$store:put-doc $s $t2]]]
```

```console
$ cx prog.cx
true
```

…and every gate fails closed rather than sanitising:

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[$xap:pkg-tree ([entry path='../evil.cx' 'x'])]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4880 message='E_XAP_PKG_INVALID: entry path "../evil.cx" must be relative and traversal-free' path='../evil.cx']
```

`prog.cx`
```cx
[?lib 'cx-xap' :as xap]
[$xap:pkg-tree ([entry path='a.cx' 'one'], [entry path='a.cx' 'two'])]
```

```console
$ cx prog.cx
[err code=cx-err:CXER4880 message='E_XAP_PKG_INVALID: duplicate entry path "a.cx"' path='a.cx']
```

**Building a production XAP end to end — composing features, authoring the
deployment document, bootstrapping identity, hosting, and projecting a
ux-web surface — is `playbook-xap.md`.** Read it before you write one.

### Language bindings

CX is reachable from Go, Python, Rust, and V through the C ABI
(`include/cx.h`). The binding surfaces are parity-tested against a shared
conformance family (`conformance/binding_api.cxd`), so "it works in Python"
and "it works in Go" mean the same bytes came back.

## Choosing a ring, in one line each

* **Ring 0** if the answer is already in the document.
* **Ring 1** if the answer has to be computed.
* **Ring 2** if the answer has to outlive the process or be shared.
* **Ring 3** if the answer has to cross a language or a protocol boundary.

Take the smallest one. Moving outward later costs nothing, because a lower
ring is never changed by a higher one.
