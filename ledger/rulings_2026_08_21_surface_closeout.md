# Rulings 2026-08-21 — the surface close-out (#909, #911, #912)

Owner ruled "1a 2a 3a" on the measured ruling sheet for the three issues left
open by the ASP-2 (#903) and D910-1 (#910) landings. Recorded BEFORE the work,
per R6.1.

## ASP-3 — the element body reads discrete values, like every position beside it (#909)

**Status:** RULED (owner "1a", 2026-08-21).

**The rule.** The ASP-2 discrete-token rule extends to ELEMENT BODIES: a
comma-less body whose whitespace-separated tokens are all discrete values —
typed scalars, quoted strings, `$name` holes, `[…]` nodes, `(…)` sequences,
map-shaped `{…}` — yields those values as discrete children. `[k 1 (2, 3)]` is
the element `k` with two children (the int and the sequence), where it produced
`[k '1' (2, 3)]` — the int silently restringified. A BAREWORD anywhere in the
body still makes the whole body PROSE (`[p weight (kg, lbs) shown]` is
untouched), and the ws-delimited-span rule carries over from ASP-2, so glued
runs stay one item.

**Why (a) and not the loud refusal (b).** The decisive evidence is that the
mangled shape is *engine output*: conformance `ux-016`'s rendered result is
`[list false (verb, label, …) (label, open, …)]`, and re-reading that line turns
the bool `false` into the string `'false'` — output that fails its own re-parse
(the #704 class), stable under canonicalization, and invisible to every gate
because no gate re-reads rendered output. Refusing would leave the renderer
emitting a form nothing may read back; (a) makes the output re-readable and
gives the shape the meaning every adjacent position already gives it.

**Measured before the ruling:** corpus reach ZERO — no `in-cx` input in
conformance, oriel, stdlib or examples carries the shape (the two grep hits are
an `in-code` section, which the PROGRAM reader owns and this does not touch, and
the `ux-016` `out-text`, which no gate re-parses). Full protocol still applies at
landing: predict, then measure bucket counts AND per-input canonical hashes of
both readers against a baseline run at the base commit.

## TA-1 — the type annotation is GLUED, and the reader enforces it (#911)

**Status:** RULED (owner "2a", 2026-08-21).

**The rule.** lexicon [L50] means what it says — a TypeAnnotation binds GLUED to
the token on its left. The DATA reader stops accepting the spaced form and
refuses it loudly, naming the one-character fix ("type annotation must be glued:
write `port::u16`"). The leniency was never a decision: whitespace skipped
before the `::` check in the element-meta loop, so `[port ::u16 8080]` was
accepted and silently normalized to the glued spelling while the PROGRAM reader
refused it outright — two readers disagreeing about a spelling the spec does not
define (the #793 silent-acceptance class, and the reader asymmetry that produced
#910's headline error).

**Why (a) and not specing the leniency (b).** The glued form is already the
canonical emit, so every document that has been through `cx fmt` is glued
already: enforcement makes the spec, both readers, and the emitter say one
thing, and the churn falls entirely on files we own. (b) would spend spec
surface — and new PROGRAM-reader work, for convergence — to keep a spelling that
exists only because of a whitespace skip. Precedent: #484's glued-only
`[table[` cutover.

**Migration measured before the ruling** (~60 sites, all ours): examples/ 50
occurrences across 8 files (config, env, article, post, chapter, cx-tour, vcore,
comparisons/typed_int); docs/guide/ two files teaching the spaced form
(tour-data.html, data-language.html); conformance 1 (`[r ::int[3,1,2]]`);
vcx/tests 7 across 4 files. stdlib and the oriel estate: ZERO. Corpus-diff reach
is NOT yet measured and MUST be, per the ASP-2 protocol, before landing.
Examples and docs move to the glued spelling in the same landing — a shipped
example teaching an undefined form is part of the defect.

## DGF-1 — the CLI accepts the diagram detail rungs it already implements (#912)

**Status:** RULED (owner "3a", 2026-08-21).

**The rule.** `eval_code`'s diagram-target checks match on the BASE format (split
on `:`) and pass the full target string through to `render_diagram`, which
already owns the suffix parsing (`parse_diagram_format`). The D910-1 fallback arm
takes the same base-format match. So `cx diagram F --format=mermaid:full` renders
the full rung instead of being refused by an exact-match target list, matching
`of-source`, the wasm export and the gates, all of which take the rung today.
`run_diagram` already splits `base_fmt` on `:` for the graphviz capability check,
so the suffixed spelling was intended at the CLI. One pinned test per rung
through the CLI path.

## Not ruled here — the examples-diagram lane

The #910 suggestion (a lane that diagrams every shipped `examples/*.cx`, which
would have caught #910 at the release) still needs a HOME decision: a gate of its
own, or an addition to an existing CLI lane. Not slipped into any of the above.
