# RULED: 1352-a … 1352-f — the agent-tool projection projects feature VERBS beside `[?def]` commands (implementation record)

**Rulings:** owner + Fable, 2026-09-09 03:35–04:00 ET, on worker B's and worker
A's letters (#1352); the six `## RULED:` comments on the issue are the record
of the decisions. This file records the IMPLEMENTATION (Fable session,
2026-09-09 afternoon) and the two decisions it had to take where the rulings
were silent.

## What was wrong

`x/tools.cx:164` `descriptors-of` filtered the compiler's def table; a XAP
feature's act verbs live in a parsed `[feature]`/`[grammar]` element tree, so a
feature whose whole surface is verbs projected as an agent tool set of size
zero — for MCP `tools/list`, the A2A agent card and `cx tools export` alike.
A non-string source leaked `CXER0100 cx:ast: SOURCE must be a string`.

## What changed

- `x/tools.cx` — `descriptors-of ($source::any)` dispatches on kind: a
  string answers the UNION of the `[?def]` command lane and every
  `[feature]`/`[grammar]` element the text carries, interleaved in SOURCE
  ORDER (each docs-lane span located by `strings:find`, each def by its
  `loc.start`, merged by a fold); an element answers the verb lane alone;
  anything else answers `[err code=source-unreadable [source-unreadable …]]`.
  The verb lane asks `[$xap:emits-of]` for `{effects: (:act)}` and
  `{effects: (:observe)}`, resolves each slot's type through the feature's
  `[types]` alias chain, and builds the SAME `[tool …]` shape: `required: ()`,
  `additionalProperties: false`, read-only = observe, destructive = not
  read-only, idempotent/open-world false, `[meta]` with the verb
  declaration's `cx:hash` as the Tier-1 key, the schema ids, `[feature]`, and
  one `[domain-type slot= type=]` row per aliased slot. The missing-summary
  refusal names `def=` and `verb=` rows in ONE element; an `emits-of` refusal
  is wrapped as `unreadable-feature` with the cause verbatim.
  `type-schema-of` gains the grammar's `text` and `instant` spellings.
- `stdlib/xap.cx` / `vcx/platform/stdlib_xap.v` — `emits-of ($doc $opts::map
  {})`: `opts.effects` selects effect FAMILIES; default `(:act)`.
- `spec/03-approved/x/tools.md` §1–§3 — the two-lane sentence, the shape,
  and a second Source column.

## Two decisions taken here (Fable, under the owner's delegation; the owner may override on #1354)

1. **`:act` is a FAMILY, and `arrange` verbs ARE projected.** `1352-b` was
   ruled at 03:40 ET; `1259-i` (ruled later the same morning, landed
   `ccbfb6443`) made membership "not observe", so the pre-1352 vocabulary
   already contained `arrange` verbs and the undeclared effect. A default of
   `(:act)` that stayed byte-identical for every existing call therefore has
   to mean the invocable family — `act`, `arrange`, undeclared — and it does.
   `1352-b`'s "arrange verbs are not projected (no letter asked)" is
   superseded by `1259-i`'s own reasoning: an arrange verb is something a
   principal invokes (`ux:form` projects a submit form for it), so an agent
   tool for it is the same answer one face over. An `{effects: (:arrange)}`
   request selects the same family; `(:observe)` is the read family.
2. **An observe verb's slots are typed from the noun it READS.** The
   fallback that types slots from the written noun answers nothing for a verb
   that writes nothing; the read noun is the one it touches. The `[writes]`
   noun still wins where present, so no act/arrange verb's atom moves
   (xap-compose-138..161 byte-identical).

## Fixtures

`conformance/stdlib/tools.cxd` `tools-009..015`: the union (def + act verb,
source order); the element path (feature lane alone); an observe verb as a
read-only tool; alias resolution with the `[domain-type]` row; the
`source-unreadable` refusal on a map; the missing-summary union (`def=` and
`verb=` rows); a composed `[grammar]` element. `conformance/stdlib/xap-compose.cxd`
`xap-compose-162` (`{effects: (:observe)}` — read verbs, typed from the read
noun) and `xap-compose-163` (the default and `(:act)` and `(:arrange)` agree
with each other and with the pre-1352 answer). `conformance/stdlib/mcp-server.cxd`
`mcp-server-013` and `conformance/stdlib/a2a.cxd` `a2a-010` pin the two
adapters on the SAME union document (separate call sites, each could drop the
new descriptors).

Not fixtured: the `unreadable-feature` wrap. Under `1259-g1` `emits-of`'s one
refusal is the kind check, which `descriptors-of`'s own dispatch prevents from
ever being reached; the wrap is implemented and unreachable today, as the
ruling itself says ("this is the residual").

## DELETES

- the def-table-only enumeration; the `CXER0100 cx:ast` leak on a non-string
  source; the `($source::string)` signature (`$source::any`, no dual-accept).
- `1352-b`'s parenthetical that arrange verbs are not projected (see 1).
