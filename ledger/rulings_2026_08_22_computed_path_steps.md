# Ruling 2026-08-22 — computed path steps (PYE-1a, PYE-1b)

**Status:** RULED by the owner ("1a 2b", 2026-08-22) against the two
questions posed in the bug-campaign successor session. Recorded BEFORE the
work per R6.1. Rider to `rulings_2026_08_22_python_eradication.md` PYE-1;
that ruling's text is left intact.

## PYE-1a (1a) — the grammar edit for a computed member step is INSIDE PYE-1's authorization

PYE-1's named-authorization list is `spec/03-approved/misc/cli.md` §3,
`spec/03-approved/std-lib/env.md`, `spec/03-approved/std-lib/re.md` §5, and
the new normative `map:` / `array:` spec. It does not name
`spec/03-approved/formal/grammar.ebnf` or `lexicon.ebnf`. But PYE-1's own
text names the spelling — "Computed-key access on maps is included; `$m.$k`
is presently a parse error" — and #925's acceptance requires it to work. A
ruling that names the exact syntax authorizes the file that defines it.

The grammar / lexicon edits for computed steps therefore proceed under
PYE-1, citing this rider, and go to the owner for G3 in the campaign's
close-out package together with the map/array spec. The rider exists so the
reasoning is findable rather than silent; it does not pre-approve the text.

The two rejected alternatives, recorded so the choice is not re-litigated:
shipping computed access as `map:get` only would have contradicted PYE-1's
text and left `$m.beta` as sugar with no computed twin — a permanent
asymmetry; holding the computed-key half for a separate authorization would
have stalled Phase 1, which the #922 rewrites depend on, for a question
PYE-1 had already answered.

## PYE-1b (2b) — ALL FOUR compact steps take a computed name, not just `.`

`$m.$k`, `$m/$k`, `$m//$k`, `$m@$k` all resolve their step name from a
binding. PYE-1's scope was `.$k` alone; the owner widened it to the whole
compact family.

**Why the wider rule is the cheaper one.** The four steps are ONE loop —
`parse_postfix_path_steps` (`vcx/cx/program_parser.v`), which emits all five
of the `expected name after //` / `/@` / `/` / `@` / `.` refusals and is
shared by binding paths (BP-1) and by every bracketed value form's result
path (PS-1, #886). Adding the computed alternative once covers `$x.$k`,
`$x/$k`, `$x//$k`, `$x@$k` and `[$f $y]/$k` alike. Orthogonality is a stated
fundamental CX objective, and `.` having a computed form while its three
siblings do not is exactly the wart that is cheap now and permanent after a
tagged release carries it.

**Zero corpus movement by construction.** All four forms are parse errors
on the pre-ruling tree, measured at 89528502:

    $m.$k    parse: expected name after ., got $
    $m/$k    parse: expected name after /, got $
    $m//$k   parse: expected name after //, got $
    $m@$k    parse: expected name after @, got $

Nothing in the corpus can be reading them today, so no golden and no
canonical image moves. The PROTO_CANON_OUT differential is still run — the
claim is checked, not asserted.

### Implementer decisions recorded under this rider (findable, not silent)

- **The computed name is a BARE `$name` binding — no inner path, no QName
  fold.** `$m.$k/foo` is therefore a computed member step followed by a
  child step `foo`, not a member step named by `$k/foo`. The greedy reading
  would make the inner binding swallow the outer path's steps, which is both
  surprising and unwritable-around. A parenthesized general-expression form
  is left unclaimed for a future ruling; it is not needed by #925.
- **BP-1's axis refusal still fires.** `$m.$k::name` and the `/`, `//`
  siblings refuse with the same `[135a]` message a literal name gets — the
  computed alternative changes what supplies the NAME, never which axes are
  binding-path surface.
- **The kind tests and `*` wildcard are untouched.** `node()` / `text()` /
  `*` are not names and take no computed form.
- **CXPath proper is untouched.** `vcx/cx/path_parser.v` implements the
  twelve-axis CXPath surface and has its own variable model; this rider is
  the `[135a]` compact-step surface only.
- **A computed name that resolves to a non-string, or to the empty
  sequence, refuses loudly** rather than coercing to an image or silently
  selecting nothing — the refuse-never-invent rule (MSS-3) applied to the
  step position.
