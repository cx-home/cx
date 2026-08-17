module main

// The scaffold bodies for `cx xap init`. Kept beside the command rather
// than read from disk so a scaffold never depends on the toolchain's own
// source tree being present.
//
// The shape mirrors the in-family reference application (reference/shop/):
// two INDEPENDENT base features, one COMPOSITE that joins them over a
// shared key, then the wiring and surface layers. It composes as generated.

fn xap_init_files(name string) map[string]string {
	return {
		'thing.feature.cxd':          xap_init_base_a(name)
		'owner.feature.cxd':          xap_init_base_b(name)
		'thing-of-owner.feature.cxd': xap_init_composite(name)
		'${name}.xap.cxd':            xap_init_xap(name)
		'${name}.surface.cxd':        xap_init_surface(name)
		'compose.cx':                 xap_init_compose(name)
		'README.md':                  xap_init_readme(name)
	}
}

fn xap_init_base_a(name string) string {
	return "[; A BASE feature. It knows nothing about any other feature — that
   independence is the point, and the compose gate enforces it (see the
   note in thing-of-owner.feature.cxd).

   It registers the `owner-id` KEY, which the other base registers too,
   with the same type. That agreement is what W2 checks and what makes the
   composite's join legal. ]
[feature name=thing version=\"1\"
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
   [intent [do :create]]
   [writes thing]]
  [verb name=list effect=observe
   [intent [do :list]]
   [reads thing]]]

 [rules
  [rule name=label-required kind=validity
   [statement 'A thing MUST carry a label.']]]

 [governance [grant verb=create to=operator]]

 [requirements
  [requirement kind=functional as=operator traces=create
   [want 'to create a thing'] [so 'it exists in the record']
   [acceptance 'a created thing appears under the /thing state route']]]]
"
}

fn xap_init_base_b(name string) string {
	return "[; The SECOND base feature. It registers onto the SAME `owner-id` key
   as thing.feature.cxd, with the same `text` type — W2's agreement.

   Note that both bases here define a bare `list` verb. That is legal:
   W1 requires FEATURE names to be distinct, and qualified names
   (`thing/list`, `owner/list`) keep the two apart. The consequence is
   worth seeing: with both enabled, a BARE `[do list]` is ambiguous, and
   the resolver returns a VALUE listing both candidates rather than
   guessing. A client must turn that into a prompt, never auto-pick.
   `compose.cx` shows it. ]
[feature name=owner version=\"1\"
 [summary 'Who owns the things. Rename it to your own actor noun.']

 [frames [use frame=time via=registered-at]]
 [keys   [key name=owner-id via=id]]

 [nouns
  [noun name=owner
   [field name=id type=text doc='the shared key']
   [field name=name type=text]
   [field name=registered-at type=instant]]]

 [verbs
  [verb name=register effect=act scope=shared consequence=reversible
   [intent [do :register]]
   [writes owner]]
  [verb name=list effect=observe
   [summary 'Shares its bare term with thing/list — see the header.']
   [intent [do :list]]
   [reads owner]]]

 [governance [grant verb=register to=operator]]

 [requirements
  [requirement kind=functional as=operator traces=register
   [want 'to register an owner'] [so 'things can be attributed to someone']
   [acceptance 'a registered owner appears under the /owner state route']]]]
"
}

fn xap_init_composite(name string) string {
	return "[; The COMPOSITE. This is the reason the other two are separate.

   It joins them over the shared `owner-id` key into a DERIVED noun that
   exists in neither base — a relationship between two features can only
   live above both of them.

   THE RULE PLACEMENT IS THE LESSON. 'A thing can only be created for an
   owner that was registered' is a true statement about this domain, and
   it may NOT be written in thing.feature.cxd: a base feature naming
   another feature's verb reaches outside its own grammar, W4 refuses it,
   and it would mean `thing` could never be enabled alone. It belongs
   here, because `uses` puts both bases inside this feature's reach.

   Try moving it into thing.feature.cxd and running compose.cx — the
   refusal is immediate and names the rule. ]
[feature name=thing-of-owner version=\"1\" kind=composite
 [summary 'Things joined to their owners — the view neither base can produce alone.']

 [uses features='thing owner']

 [frames [use frame=time]]
 [keys   [key name=owner-id via=owner]]

 [nouns
  [noun name=owned-thing derived=true
   [summary 'One thing with its owner resolved — derived, never sourced.']
   [field name=thing-id type=text]
   [field name=owner type=text]
   [field name=owner-name type=text]
   [field name=label type=text]
   [from 'thing/thing JOIN owner/owner ON thing/thing.owner = owner/owner.id']]]

 [verbs
  [verb name=review effect=observe
   [intent [do :review]]
   [reads owned-thing]]
  [verb name=reassign effect=act scope=shared consequence=reversible
   [summary 'DERIVED — its authority is its constituents, never its own name.']
   [intent [do :reassign]]
   [reads owned-thing]
   [writes thing]
   [constituents 'thing/create owner/register']]]

 [rules
  [rule name=create-after-register kind=ordering verb=thing/create after=owner/register
   [statement 'A thing can only be created for an owner that was registered.']]]

 [requirements
  [requirement kind=functional as=operator traces=review
   [want 'to see things with their owners resolved']
   [so 'I do not have to join them by hand']
   [acceptance 'owned-thing is present in the composed grammar as a derived noun']]
  [requirement kind=functional as=operator traces=reassign
   [want 'to reassign a thing to another owner']
   [so 'ownership can be corrected']
   [acceptance 'reassign derives its effect signature from its constituents']
   [acceptance 'a principal granted only thing-of-owner/reassign is REFUSED — the denial names the constituent']]]]
"
}

fn xap_init_xap(name string) string {
	return "[; The WIRING layer. It declares no grammar — the features already did.
   It enables them, names who has authority, declares the agent and its
   dial, and says how the thing is packaged. ]
[xap name=${name} version=\"1\"
 [summary 'Describe what this XAP is for.']

 [features
  [feature name=thing package='./thing.feature.cxd']
  [feature name=owner package='./owner.feature.cxd']
  [feature name=thing-of-owner package='./thing-of-owner.feature.cxd']]

 [principals
  [role name=operator authority=operations features='*'
   doc='The human with final authority.']
  [agent name=assistant
   doc='Proposes; does not dispose. See the dial below.']]

 [deployment model=in-process role=app]

 [surfacing default=peripheral]

 [governance
  [authority role=operator]
  [; THE DIAL at its floor: the agent may observe and propose, never
     commit an act. Raising it is one explicit, revocable delegation. ]
  [agent-default name=assistant dial=floor]]

 [requirements
  [requirement kind=domain level=must
   [statement 'The agent MUST NOT commit an irreversible verb at dial=floor.']
   [acceptance 'the assistant emitting an act verb is refused at the PEP']]]]
"
}

fn xap_init_surface(name string) string {
	return "[; The MATERIALIZATION layer. DERIVED from the xap + features: it BINDS
   already-declared verbs to media and lays them out. It never redeclares
   an intent — if a control here names a verb no feature declares, the
   surface is wrong, not the feature. ]
[surface name=${name}-console xap=${name} version=\"1\"
 [summary 'The operator console.']

 [media
  [medium name=screen kind=visual primary=true]]

 [panels
  [panel name=things feature=thing kind=view
   [layout region=left mode=separate]
   [materialize on=screen as=table trigger=always priority=peripheral]
   [shows 'thing.id thing.label thing.owner']]
  [panel name=owners feature=owner kind=view
   [layout region=right mode=separate]
   [materialize on=screen as=table trigger=always priority=peripheral]
   [shows 'owner.id owner.name']]
  [panel name=owned feature=thing-of-owner kind=view
   [layout region=main mode=stacked]
   [materialize on=screen as=table trigger=always priority=peripheral]
   [shows 'owned-thing.thing-id owned-thing.owner-name owned-thing.label']]]

 [controls
  [control intent=thing/create   [materialize on=screen as=form]]
  [control intent=owner/register [materialize on=screen as=form]]]

 [clients
  [; agent-parity: the agent attaches to the SAME surface a human does. ]
  [client kind=human attach=independent]
  [client kind=agent attach=mirrored]]]
"
}

fn xap_init_compose(name string) string {
	return "[; Compose this XAP's features through the W1-W6 gate and show what it
   produced. Run it before editing anything:

     cx --allow-read compose.cx

   NOTE the `//feature` DESCENDANT step. Each spec file opens with a
   `[; … ]` block comment, so the CHILD step `/feature` selects NOTHING —
   and composing zero features cheerfully reports ok=true, because the
   empty grammar is the identity. A vacuous green is the one failure mode
   of this script worth guarding against. ]
[?lib 'cx-xap' :as xap]
[?lib 'cx-stdlib/io' :as io]
[?lib 'cx-stdlib/cx' :as cx]

[?let
  [= \$ad [\$cx:parse [\$io:read-file 'thing.feature.cxd']]]
  [= \$bd [\$cx:parse [\$io:read-file 'owner.feature.cxd']]]
  [= \$cd [\$cx:parse [\$io:read-file 'thing-of-owner.feature.cxd']]]
  [= \$a  [\$first [?for [in \$n \$ad//feature] [yield \$n]]]]
  [= \$b  [\$first [?for [in \$n \$bd//feature] [yield \$n]]]]
  [= \$c  [\$first [?for [in \$n \$cd//feature] [yield \$n]]]]
  [= \$g  [\$xap:compose \$a \$b \$c]]
  [= \$g1 [\$xap:compose \$a]]

  [${name}
    [gate [\$xap:compose-report \$a \$b \$c]]
    [grammar verbs=[\$count \$g//verb] nouns=[\$count \$g//noun]
             hash=[\$xap:grammar-hash \$g]]
    [resolution
      [unique-owner    [\$xap:resolve \$g 'create']]
      [qualified-wins  [\$xap:resolve \$g 'thing/list']]
      [; both bases define a bare `list`, so this is an ambiguity VALUE
         listing both candidates — a prompt, never a guess ]
      [ambiguous       [\$xap:resolve \$g 'list']]
      [unknown         [\$xap:resolve \$g 'nosuchverb']]]
    [; enabling a feature may only ever turn a resolution into a prompt
       that STILL LISTS the old answer — never into a different verb ]
    [no-silent-rebinding
      [with-thing-alone [\$xap:resolve \$g1 'list']]
      [with-owner-too   [\$xap:resolve \$g 'list']]]]]
"
}

fn xap_init_readme(name string) string {
	return "# ${name}

A XAP scaffolded by `cx xap init`. Three authored layers, and they compose
as generated — nothing to fix before it runs.

| File | Layer |
|---|---|
| `thing.feature.cxd` | base feature |
| `owner.feature.cxd` | base feature — registers the same key |
| `thing-of-owner.feature.cxd` | **composite** — joins them, derives a noun neither has |
| `${name}.xap.cxd` | wiring: features enabled, principals, the agent's dial |
| `${name}.surface.cxd` | materialization: verbs bound to media |

```bash
cx --allow-read compose.cx
```

## Three things the skeleton is trying to show you

**A composite is a feature nobody authored the data for.** `owned-thing`
is in neither base — a relationship between two features can only live
above both.

**Features stay independent, and the gate enforces it.** The rule \"a thing
can only be created for an owner that was registered\" is on the
*composite*, not on `thing`. Move it into `thing.feature.cxd` and compose
again: W4 refuses it, because a base naming another feature's verb would
mean `thing` could never be enabled alone.

**Ambiguity is a value, not a guess.** Both bases define a bare `list`.
With both enabled, `[do list]` returns a value listing both candidates. A
client turns that into a prompt; it may not auto-pick. The same pair shows
that enabling a feature never silently changes what an existing utterance
meant.

## Next

- Rename the nouns and verbs to your domain; the shapes carry over.
- Add a component per feature (`bind`, `emits`, and a view) to run the
  cascade — PEP → journal → ordered bus, with state as the fold.
- A client is a SEPARATE project (`cx xap init ${name} --client` scaffolds
  one): a XAP never embeds its renderer.
"
}

fn xap_init_client_files(name string) map[string]string {
	return {
		'client.cxd':         xap_init_client_spec(name)
		'shell/layout.html':  xap_init_client_shell(name)
		'README.md':          '# ${name}-web-client\n\nA SEPARATE project from the XAP (N-CLIENT-2): a XAP never embeds its\nrenderer. It exposes the surface as data; this materializes it into one\nmedium. The same surface drives a CLI, a TUI, an agent and a browser with\nno change to the XAP.\n\n## This is a SPEC + SHELL ONLY — it does not run yet\n\nWhat is scaffolded here is `client.cxd` (the spec layer) and `shell/` (the\ndocument shell). There is deliberately no server: a serve entrypoint has to\nregister a component per feature WITH A VIEW, and views are the one thing\nonly you can write — they are your medium, not the scaffold\'s.\n\nTo make it run, add a `serve.cx` that:\n\n1. declares `[\$xap:component NAME {bind: …, emits: …, view: …}]` per feature\n2. composes the XAP\'s features and runs a runtime over them\n3. calls `[\$xap:serve URL {runtime: …, shell: \'shell\'}]`\n\n`reference/shop-web-client/serve.cx` in the cx repo is a worked example of\nexactly those three steps.\n'
	}
}

fn xap_init_client_spec(name string) string {
	return "[; The CLIENT SPEC — the fourth document kind, in its OWN project.
   A XAP never embeds its renderer (N-CLIENT-2), so this lives beside the
   XAP rather than inside it. The same surface data drives a CLI, a TUI,
   an agent and this web client with no change to the XAP at all. ]
[client name=${name}-web version=\"1\"
 [summary 'A hypermedia client: server-rendered CX → HTML, no JavaScript.']

 [attaches xap=${name} surface=${name}-console]

 [medium name=screen kind=visual]

 [shell dir='shell']

 [panes
  [pane panel=things refresh='every 5s']
  [pane panel=owners refresh='every 5s']
  [pane panel=owned  refresh='every 5s']]

 [controls
  [control intent=thing/create   as=form]
  [control intent=owner/register as=form]]

 [javascript policy=none
  doc='Minimal-JS-by-exception; this client takes no exception.']]
"
}

fn xap_init_client_shell(name string) string {
	// The surface mount placeholder is assembled rather than written
	// literally: the shell splicer scans the whole file, so a placeholder
	// appearing anywhere — including in a comment — is resolved as a
	// component name and refuses when there is no such component.
	o := '{{surface:'
	c := '}}'
	return '<!doctype html>\n' +
		'<html lang="en">\n<head>\n  <meta charset="utf-8">\n' +
		'  <title>${name} console</title>\n' +
		'  <script src="https://unpkg.com/htmx.org@1.9.10"></script>\n' +
		'</head>\n<body>\n  <h1>${name}</h1>\n\n' +
		'  <section hx-get="/thing" hx-trigger="every 5s" hx-swap="outerHTML">\n' +
		'    <div id="things-mount">${o}thing${c}</div>\n  </section>\n\n' +
		'  <section hx-get="/owner" hx-trigger="every 5s" hx-swap="outerHTML">\n' +
		'    <div id="owners-mount">${o}owner${c}</div>\n  </section>\n' +
		'</body>\n</html>\n'
}
