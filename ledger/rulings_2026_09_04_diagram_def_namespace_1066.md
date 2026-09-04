# Ruling record — #1066 code-diagram per-def id namespace (DR-8 mini-ruling, 2026-09-04)

Issue: #1066 (bug, area:cx-stdlib, prio:high). Renderer: `stdlib/diagram.cx` `cd-def-subgraph`.
Instrument: `vcx/tests/testdata/code_diagram_golden/` (DR-8, RULED DRW3-1) — golden bytes move ONLY under a
mini-ruling recorded here first. This is that record.

## The defect

`cd-def-subgraph` minted the whole per-def node-id namespace from the def name's FIRST LETTER
(`[$str-slice $nm 1 1]`). Mermaid ids are global across subgraphs, so two defs sharing an initial
shared `<p>s` / `<p>e` / `<p>b` / `<p>lt1` …: last-writer-wins on labels, nodes stayed in the first
subgraph, and every later def's body silently disappeared. Measured with `sum-a` / `sum-b` / `scale`:
two of three bodies gone. The #1036 class one namespace up; inherited from the V emitter (#889 port).
No golden and no conformance case had two defs sharing an initial, so the gate was blind to it.

## Question 1066-Q1 — what image mints the def namespace?

- **(a) RULED — the def ORDINAL plus the sanitized full name: `d<i>_<slug>`** (`d1_sum_a`, `d2_sum_b`,
  `d3_scale`), `$i` being the statement index `cd-cfg-defs` already walks. The ordinal GUARANTEES
  uniqueness (two names that sanitize alike — `sum-a` / `sum_a` — still differ); the slug keeps the id
  readable in the diagram source. DELETES: the first-letter image and the `"x"` fallback for an empty
  name. Every def-bearing golden moves (named movement, #976 discipline); the regen tool gains the pin
  `pin-cfg-shared-initial-defs` (three defs, two sharing an initial) so the class stays closed.
- (b) the sanitized full name alone — readable, but `sum-a` / `sum_a` still collide; a residual of the
  same silent class.
- (c) the ordinal alone — unique, unreadable (`d3s`, `d3e`); goldens lose the def they belong to.

Ruled (a) under the standing letter-acceptance order (prio:high, campaign authority 2026-09-04).
Id: **1066-Q1a**.

## Execution record

- `stdlib/diagram.cx`: ONE derivation, `cd-def-pfx nm i`; `cd-def-subgraph` takes `$i` from `cd-cfg-defs`; the
  cross-def call edges (`cd-def-entry-id`, `cd-call-edge-lines`) and the `resolves` anchor (`cd-resolve-target`)
  look the callee's ordinal up by name over the statement list (`cd-def-ordinal`), so a caller and its
  callee's subgraph name the same node — the first gate run caught the call edge still on the old letter.
- `conformance/code_diagram.cxd`: the five def-bearing cases' expected node/edge sets renamed.
- `vcx/tools/regen_code_diagram_golden/main.v`: pin `pin-cfg-shared-initial-defs` added; goldens
  regenerated ONCE under this record; the diff is the namespace rename plus the three new pin files.
- Gate: `vcx/tests/diagram_umbrella_test.v` byte-for-byte; conformance `code_diagram.cxd` node/edge sets.
