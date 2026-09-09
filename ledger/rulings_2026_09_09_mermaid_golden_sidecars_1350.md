# Ruling — the mermaid golden corpus gets `.source` sidecars and a MANIFEST, and its gate asserts BOTH properties (#1350)

**Ruling ids:** 1350-b, 1350-c
**Date:** 2026-09-09
**Ruled by:** Fable, under the owner's delegation of 2026-09-09 05:50 ET
(cx-home/cx-private#1350, comments 2026-09-08T23:09:56Z and
2026-09-09T07:19:20Z). Recorded here BEFORE the work, per rule 7 of #1354.
**Follows:** `99c25169d` (#1350, the membership half for the OTHER corpus —
`code_diagram_golden`; that landing is untouched by this one).

## The class

There are TWO diagram golden corpora, two instruments, two gates:

| corpus | goldens | sidecars | graded at | renderer |
|---|---|---|---|---|
| `code_diagram_golden` | 321 | 107 | `diagram_umbrella_test.v:39` | `code_diagram_with_level` over the authored `.source` |
| `diagram_mermaid_golden` | 123 | **0** | `diagram_umbrella_test.v:1182` | `reverse_parse_diagram` + `render_diagram` over the GOLDEN |

The mermaid gate re-derived its own input by extracting the `%%cx:` marker out
of the golden it was about to compare against. That asserts ONE property — the
fixed point `render(extract(golden)) == golden` — and a hand-patched golden
satisfies it forever, because the extractor reads the patched bytes back out.
Nothing on disk recorded what the golden was rendered FROM, so in this corpus
the silent-rot class was undetectable rather than merely unlikely. 0 of 321
code goldens carry the `%%cx:` marker; 123 of 123 mermaid goldens do, which is
why only this corpus could take the shortcut.

## 1350-b — what does the byte gate assert?

- **(a)** the fixed point alone.
- **(b)** `render(.source) == golden` alone.
- **(c)** BOTH — they are two properties, not one property twice.

### Ruled — (c)

**Deletes:** (a)'s blindness to a hand-patched or stale golden; (b)'s loss of
the extract-mermaid gate, which the fixed point doubles as (a broken extractor
currently fails every file loudly, and that coverage is not bought back
anywhere else).

## 1350-c — how does `diagram_mermaid_golden` acquire the sidecar half?

- **(a)** `regen_diagram_golden` writes one `<id>.source` per golden from the
  inputs it already holds (the in-tool `pin_sources` map + the `program-viz-*`
  fixtures of `conformance/code.cxd`), and declares its corpus by MANIFEST the
  way `99c25169d` made the other tool do.
- **(b)** provenance markers on the 321 `code_diagram_golden` goldens.
- **(c)** read `1350-b` jointly across both corpora.

### Ruled — (a)

**Deletes:** (b), which rewrites every committed code golden to buy a property
their sidecar assertion already covers, and collides head-on with #1349's 18
re-records; (c), which leaves `diagram_mermaid_golden` permanently unable to
detect a hand-patched golden — the exact class this issue exists to remove, in
the one corpus where it is undetectable.

Question 1 of the 22:28Z letter (which renderer the two sides call) is
**WITHDRAWN as moot**: the two sides call the identical renderer with identical
arguments; the real defect was membership, and it landed at `99c25169d`.

## What lands

1. `vcx/tools/regen_diagram_golden/main.v` writes `<id>.source` byte-for-byte
   the source it rendered, for all 41 ids (21 pins + 20 renderable
   `program-viz-*` fixtures), and a sorted `MANIFEST` of those ids.
2. The gate at `diagram_umbrella_test.v` renders the sidecar and requires the
   golden's bytes **before the sidecar is trusted for anything else** — a wrong
   sidecar must RED, not quietly become the new provenance — and keeps the
   fixed point beside it.
3. The `ran >= 120` FLOOR is replaced by `ran == manifest.len * 3` plus an
   orphan check and a missing check, plus refuse-to-vouch on an empty or absent
   manifest. A floor cannot see an extra; that is how
   `pin-cfg-computed-name-element` rotted through #1038 and #1068.
4. **ZERO golden bytes move.** The render calls are untouched; regeneration
   that moves a byte is a red to read, not a diff to accept.
5. `code_diagram_golden` is untouched, so this does not collide with #1349's
   18 re-records.

## Pre-flight, measured

No ref under `refs/heads` or `refs/remotes/origin` carries a `.source` or
`MANIFEST` file in `vcx/tests/testdata/diagram_mermaid_golden`, so the 41-id
sidecar set claims no name anyone else has taken. No id contains a `.`, so the
gate's `<id>.<detail>.golden` split is unambiguous.
