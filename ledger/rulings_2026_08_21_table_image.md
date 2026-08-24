# Ruling 2026-08-21 — the table image (#914)

**Status:** AUTHORIZED by the owner ("fix 914 in opus 5", 2026-08-21) — the
fix proceeds pre-cut, implementation in a dedicated Opus 5 session. Recorded
BEFORE the work per R6.1. The design calls below are mine under that
authorization (the standing letter-recommendation rule), each with its
reasoning stated so a later reader can overturn one without re-deriving all
of them.

## TI-1 — the image carries the table, because the seam already parsed it

**The finding.** A `[table[…]]`-carrying element is invisible to every
diagram lane: empty `erDiagram`, the `<lit>` envelope in mermaid, an empty
canvas in svg/png (`examples/comparisons/table_block.cx` in full;
`examples/books.cx`'s catalog partially — its `shelf` sibling renders).

**The mechanism, measured — and it is a DISCARD, not a gap.** The program
reader has no production for the table header grammar, so it re-parses the
element's full span with the DATA reader and carries the result as a
`node_lit` literal whose `.node` field is the **fully-parsed `cx.Element`,
TableData attached** (`vcx/cx/program_parser.v` — `reparse_table_element_as_node`,
the same DATA↔PROGRAM seam `[#…#]` / `&…;` / `[!…]` use). The diagram lift
then throws that node away: `dgi_literal`'s `.node_lit` arm is
`dgi_text('cx:data', n.str_val)` — the SOURCE TEXT, structure dropped
(`vcx/code/diagram_cx_seam.v:161`). The data lift `dgi_data_node` never
consults `Element.table` either, so the D910-1 route carries nothing.

**The rule.**
1. `dgi_literal`'s `.node_lit` arm lifts through `dgi_data_node(node)` when
   the literal carries a node, falling back to the `cx:data` text hatch only
   when it does not. The image gains structure for EVERY embedded data
   construct at that seam, not tables alone — the program reading of these
   constructs IS the data reading (the seam's own words), so the image must
   say the same thing.
2. `dgi_data_node` lifts `Element.table` as a `cx:table` CHILD of the
   element — `<cx:table rows="N"><cx:col name= type=/>…</cx:table>` —
   mirroring how an element's attributes become `cx:attr` children. Columns
   carry their declared type (empty `type_name` means the `::string` default,
   spelled explicitly in the image).
3. Rows are **SHAPE, not content**: the row COUNT rides the image; row
   VALUES never do. This matches the pinned ERD design (attr values appear
   only at `--level=full`; child-element values never appear) and keeps the
   golden surface from ballooning with fixture data. A table's cells are
   reachable through the data verbs; a diagram is a shape drawing.
4. Render rules, one per lane:
   * **ERD** — a table-carrying element is an entity whose FIELDS are its
     columns, typed by the declared column type. This is the mapping an
     erDiagram wants and the reason the lane looked empty is precisely that
     it never saw them. The row count rides the `full` rung only, in the
     Mermaid comment slot the DGX-2 stat rows already use.
   * **tree / DOT (D913-1 walks)** — the `cx:table` child renders as ONE
     node labeled `table(<n> cols × <n> rows)`; the columns do not each
     become a node (a 20-column table would drown the drawing, and the
     column detail is the ERD's job). The parent element keeps its normal
     label, whose ` …` body marker is now true.
   * **flowchart (program envelope path)** — unchanged: a table element
     reached under a directive stays a leaf; it is not program structure.
5. The EDL-1a carve-out in `vcx/tests/examples_diagram_gate_test.v` is
   DELETED in the same landing, and the exclusion-count assertion drops with
   it. That gate going green over the full corpus with no exclusions is the
   completion criterion.

**Blast radius, predicted before the work (the implementer MUST measure).**
The `.node_lit` arm is reached by table elements and by the `[#…#]` / `&…;` /
`[!…]` seam constructs, so raw-text and entity-carrying pinned sources are
the movement risk: any golden whose source carries one of those will change
from a `cx:data` text label to a lifted structure. Predict per-golden, then
measure — all four diagram golden lanes, the completeness gates,
code_eval_fixtures, and the corpus differential with the landed
`PROTO_CANON_OUT` per-input hash dump against a baseline at the base commit.
DR-8 stands: goldens that legitimately move are re-captured ONLY with the
movement stated and its cause named in the commit; new pins are additive.
