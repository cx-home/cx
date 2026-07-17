# Clients and views — materializing a surface

A XAP **never embeds its renderer** (invariant N-CLIENT-2, the clients section
of the XAP spec). It exposes its surface as **data**; every client is a
separate application, with its own spec, that attaches over the shell and
materializes that data into one medium. The same surface drives a CLI, a TUI,
an agent, and a web client with no change to the XAP — that is the point.

## The surface layer — derived, not redeclared

`surfaces/<s>.surface.cxd` binds already-declared feature verbs/views to media
and layout; it never restates an intent. From the marine helm
(`xap-marine/surfaces/helm.surface.cxd`):

```cx
[surface name=helm xap=marine-helm version=0.1.0
  [media [medium name=screen kind=visual primary=true]
         [medium name=audio kind=speech] [medium name=haptic kind=tactile]]
  [panels
    [panel name=collision-alert feature=collision-cpa kind=alert
      [layout region=main mode=overlaid]
      [materialize on=screen as=highlight trigger=threat emphasis=high]
      [materialize on=audio  as=say  trigger=threat priority=foreground]
      [materialize on=haptic as=tone trigger=threat]
      [shows cpa]]]
  [controls
    [control intent=acknowledge-threat
      [materialize on=screen as=button]
      [materialize on=audio  as=say]]]]   # same intent, different trigger
```

One surface, distributed across whatever media are present — a surface
*distributes*, it does not render (the surface & media section of the feature
composition model spec).

## The client spec — the fourth document kind

A client project carries `client.cxd ⊢ client.cxs`: which XAP it attaches to,
what it consumes, how it projects, its windows/widgets/session model. The live
example is `xap-marine-htmx-web-client/marine.client.cxd` — read it before
writing your own; it is the template.

## What a client consumes (the XAP's data endpoints)

From the marine transport block (`xap-marine/xap.cxd`): observe verbs serve as
`GET /surface/{feature}` returning `application/cx` readouts; act/arrange
verbs arrive as `POST /intent` (an XSP request frame wrapping
`[intent verb=… …]`); `GET /grammar` serves the composed control grammar —
the client's single control-vocabulary source (never hardcode verbs);
`GET /stream` is the SSE push channel (named per-feature events carrying full
readout snapshots — a reconnect just re-converges).

## The HTMX web-client pattern

Default web client architecture (the client-app section of the XAP authoring
process spec): **server-rendered HTML from surface data; the browser is a
generic hypermedia client; JavaScript only by explicit, named exception.**
The client app (not the browser) speaks `application/cx`/XSP upstream.

The whole pattern in one verified function — pull a readout, materialize a
generic card (`readout → card`, `kv → row`):

```cx
[?lib 'cx-stdlib/strings' :as s]
[?def render-doc-html ($doc)
  [?let [= $title [$s:join [?for [in $r $doc//readout] [yield $r/@title]] ""]]
   [= $rows [$s:join [?for [in $kv $doc//kv]
                   [yield [$concat "<div class=\"kv\"><span class=\"k\">" $kv/@k
                            "</span><span class=\"v\">" $kv/@v "</span></div>"]]] ""]]
   [$concat "<div class=\"readout\"><div class=\"rtitle\">" $title "</div>" $rows "</div>"]]]
[?let [= $doc [$cx:parse "[readout title=\"Own ship\" [kv k=\"SOG\" v=\"6.4 kn\"] [kv k=\"depth\" v=\"24 m\"]]"]]
 [render-doc-html $doc]]
```

In the real client (`xap-marine-htmx-web-client/serve.cx`) that function sits
behind `/pane/{feature}`; the browser polls or receives SSE-relayed pushes;
feature-specific widgets (autopilot panel, nav dial, instruments) are JSON
projections of the same surface data. Run the pair:

```sh
cd xap-marine && make dev        # XAP :9001 + client :9002 + browser
# client alone, against a running XAP:
cd xap-marine-htmx-web-client
cx --allow-net=127.0.0.1 --allow-read --allow-env serve.cx
```

(`--allow-net=127.0.0.1` matters: a bare `--allow-net` binds but the SSRF
deny-set in the http module spec blocks the loopback dial to the XAP.)

## Intents upstream — XSP

The XAP↔client link carries XSP frames (the XSP spec,
`spec/03-approved/xap/xsp.md`): a self-delimiting binary frame naming the
principal DID, with a CX `data-bin` or text payload. The v1 web binding is
SSE down + POST up. Codec round-trip (verified):

```cx
[?lib 'cx-stdlib/xsp' :as xsp]
[?let [= $bytes [$xsp:encode [frame type=request stream=7 principal="did:key:z6MkExample"
                               [payload [intent verb="set-units" key="speed" value="m/s"]]]]]
 [= $back [$xsp:decode $bytes]]
 ($back@type, $back@stream, $back//payload/intent/@verb)]
# → ('request', '7', [verb 'set-units'])
```

WebSocket/WebTransport bindings, multiplexing beyond the stream-id, credit
backpressure, and reconnect-resume are scoped in the XSP spec but **deferred —
not yet implemented**.

## Rules of the road

- Derive the verb surface from `GET /grammar`; refuse unknown verbs
  client-side before they leave the browser (the marine client's
  `/vocabulary` projection is the pattern).
- The client **mirrors** authority, never owns it — the dial toggle POSTs
  `set-dial` and re-syncs from the XAP's truth; a non-privileged attempt
  reverts.
- Agent-parity is structural: the agent reads the identical surface data the
  human's client materializes.
