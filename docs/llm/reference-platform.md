# Reference: the platform and ecosystem rings — v0.16.0

> **GENERATED.** Source: `docs-src/llm/reference-platform.md.tmpl` + the
> conformance corpus. Every output was re-recorded from the `cx` v0.16.0
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

### Operating a platform

```console
cx store-serve config.cx      # the store service daemon
cx fabric-serve config.cx     # the fabric eventing daemon
```

Both take a CX configuration document. There is deliberately no supervisor
integration in-repo: lifecycle is the operator's, explicitly.

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
cx xap check-surface          # verify the declared surface
cx lock                       # generate / verify cx.lock from [?lib] imports
```

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
