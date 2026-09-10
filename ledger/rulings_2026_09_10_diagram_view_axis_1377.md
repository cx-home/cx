# RULED: 1377-a — one diagram VIEW axis, everywhere: `auto` | `erd` | `cfg` | `seq` | `effects`

**Fable, 2026-09-10 08:10Z, under the owner's delegation (scope owner-ruled on
#1354: "Graph-kind axis: yes in v0.18 scope").** The spelling and the refusal:

- ONE set, `code.code_diagram_views`, read by the module's `code-diagram`
  (third argument `$view`, default `auto`), the CLI's `--view=`, the wasm
  export `cx_code_diagram_with_view_level` (view index 0..4) behind
  `cxlib.diagram(src, 'mermaid:LEVEL', VIEW)`, and the playground's graph
  selector (Auto · Data · Flow · Sequence · Effects · Instance — `instance`
  stays the page's own tree-derived view and never reaches the engine).
- `auto` is the shipped §10.1 classification BYTE FOR BYTE (the two-argument
  call is unchanged; `code_diagram_with_level` calls the same path with
  `'auto'`; both golden corpora prove it).
- A forced view over a source that cannot carry it refuses **`CXER0282
  E_VIEW_NOT_CARRIED`** naming the view and why: `seq` needs at least one
  async / worker / channel step (the same `cd-program-is-sequence` predicate
  Auto uses); `cfg` needs code (`cd-program-is-code`) — a pure data document's
  reading is `erd`; an empty source carries only `erd`. Never an empty
  diagram (refused: an "empty-body header" answer is the silent class the
  playground's Auto label was added to end). An unknown view refuses
  `CXER0100` naming the set. `CXER0282` is allocated from Visualization's
  reserved tail (code.md §9.6: 0280 and 0283..0289 stay free).
- `erd` over a code source draws the element shapes the source carries
  (`cd-erd-top` over its statements); a program whose statements carry no
  element shape refuses CXER0282 rather than answering the header-only
  `erDiagram` the emitter would otherwise produce (measured: `[?let [= $x 1]
  [box v=$x]]` → header only). Extracting entities from elements a program
  CONSTRUCTS inside directive bodies is not attempted here — it would be a
  new emitter walk, and the honest answer today is the refusal that names
  the reading the source does have.
- The mermaid gate grades the forced renders too: a diagram the engine draws
  for a forced view must parse and be structurally sound; the engine's own
  CXER0282 refusal is a recorded SKIP, never a pass and never a failure.
- Fixtures `diagram.cxd` 035–038: forced `cfg` over a sequence-auto source is
  a flowchart; forced `seq` over `[pizza size=large]` refuses CXER0282; forced
  `erd` over a code source is an erDiagram; an unknown view refuses CXER0100.
