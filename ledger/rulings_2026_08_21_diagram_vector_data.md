# Rulings 2026-08-21 — the vector lanes read data, and the examples get a gate (#913, the #910 lane suggestion)

Owner ruled "1a and 2a, rule and fix pre-cut" on the measured finding in #913.
Recorded BEFORE the work, per R6.1. Both land pre-cut by the owner's word —
neither was on the R9 cut path until now.

## D913-1 — the DOT walk and the flowchart arm render the data tree (#913)

**Status:** RULED (owner "1a", 2026-08-21).

**The finding (measured).** The DOT emission walk (stdlib/diagram.cx,
`dot-kind`) emits nodes ONLY for `cx-node`-MARKED images — directives and
for-comp; a plain value/element image is "skip". The quirks are preserved
bit-for-bit from the pre-cutover V walk (the DR-8 note above `render-dot`).
Consequence: `cx diagram examples/config.cx --format=svg --allow-subprocess`
exits 0 and writes an 8pt-square EMPTY canvas (a digraph with zero nodes; the
base64 `cx:source` metadata makes the file look non-trivial) — every shipped
example, all data docs or element-literal docs, draws BLANK in svg/png. A
directive program (`[?let …]`) renders correctly. The mermaid FLOWCHART arm
has the sibling gap: a data doc renders the `start → … → result` envelope
with one ellipsis node. The D910-1 data lift reaches the ERD lane
(`cx code-diagram`, populated and pinned) and the embed-source metadata, but
neither vector lane nor the flowchart renders the lifted DATA tree's content.
Exit 0 + blank picture is the #910 silent-degradation class, one lane over.

**The rule.** The D910-1 data vocabulary extends to the DOT walk and to the
flowchart arm: a document with NO program structure to draw renders its
ELEMENT TREE — elements as nodes (name-labeled, detail rungs adding attrs on
the same `min|compact|full` ladder the ERD lane already implements),
containment as edges — in `mermaid` (flowchart), `svg`, and `png` alike, so
all three formats of `cx diagram` show a data document's actual content, the
way `cx code-diagram` already does. Directive renders stay BYTE-IDENTICAL:
the DR-8-pinned DOT goldens and the 264+ diagram-family goldens constrain the
change to zero movement on every existing pin; data-tree renders are NEW
golden surface, captured additively (hand-written sidecars + goldens, entries
added to the regen tools' lists; DR-8 forbids regeneration, not addition).

**Why (a) and not the loud refusal (b) or the warning (c).** The ERD lane
proves the lift already carries the content — refusing (b) would leave two
lanes disagreeing about whether a data doc is diagrammable, and (c) keeps the
silent-loss shape with a beep. (a) makes the three formats say one thing.

## EDL-1 — the examples-diagram gate (the #910 suggestion, homed)

**Status:** RULED (owner "2a", 2026-08-21).

**The rule.** A gate of its OWN (not folded into an existing CLI lane) that
diagrams every shipped `examples/*.cx` (and `examples/comparisons/*.cx`) and
asserts CONTENT, not exit codes: the mermaid render is not the placeholder /
envelope shape, the DOT text carries at least one declared node, and — for
data docs — the ERD is populated. Hermetic: it asserts on `render_diagram`
(mermaid) and the pure DOT text (`render_dot_cx`), never on the graphviz
subprocess, so it runs without `dot` installed. Exit-code sweeps measurably
lie here: the #913 blanks all exit 0 — this gate exists because BOTH #910 and
#913 would have been caught at a release by content assertions over the
shipped examples.

**Sequencing.** EDL-1 lands AFTER D913-1 (its content assertions on the
vector/flowchart lanes only hold once the data tree renders); one landing
each, both pre-cut.
