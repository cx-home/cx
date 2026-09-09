# RULED: 1316-a — the flow picture's node id IS the construct's sanitized
# document address

Date: 2026-09-08. Issue: cx-home/cx-private#1316 (Part 1, the derived
picture). Campaign: v0.18.0 close-out (#1354), Lane 2 (the #1265 flow
ladder). Letters drafted by worker B on the issue at 07:24Z; **ruled by the
owner + Fable at 2026-09-08 17:55 ET** and posted on the issue. Recorded
here verbatim in substance before any byte of the emitter was written.

## Ruled — 1316-a

For the FLOW subject of the `diagram` module, each picture node's id is
minted from the construct's DOCUMENT ADDRESS, sanitized to the mermaid/dot
id charset by ONE pure total function, pinned by its own fixture:

- **round-trip:** address → id is INJECTIVE over any one document;
- **the sanitizer is the only place the charset rule lives;**
- the address therefore travels inside BOTH forms `flow.md` §4.17 names —
  the text form and SVG — with nothing to keep in sync;
- the existing SVG metadata post-pass MAY additionally write the
  unsanitized address as `data-cx-address`, derived from the same id.

**Refused:** (b) a sidecar `id → address` table, because it makes the
address a property of the MODULE rather than of the ARTIFACT — a picture
pasted into a review loses selectability the moment it travels without its
sidecar, which is the one thing §4.17 says the picture is for ("a shared
review artifact"); (c) SVG-only attachment via `inject-svg-metadata`,
because it fails the text form, which §4.17 names in the same breath as
SVG.

**Note for the implementer, ruled:** this is a DIFFERENT id scheme from the
code-diagram subject's counter ids (#1349 `lh1`/`lb1`/`b1`) — two subjects,
two id disciplines, each pinned. **Do not unify them.**

## What the ruling does NOT say, and how the implementation derived it

1316-a rules WHERE the address lives (in the id) and WHAT PROPERTY the
minting has (injective, one sanitizer). It does not spell the address
itself. The implementation did not choose one: three pieces of already-ruled
normative text settle it, and they are recorded here so a reader can refuse
the reading cheaply if it is wrong.

### 1. The address spelling is the #787 fragment-address `path` component

`flow.md` §4.17 (`spec/03-approved/std-lib/flow.md:1120-1124`) does not say
"a path" — it names a protocol:

> every drawn element carries the document address of the construct it
> draws (the #787 fragment-identity protocol)

That protocol is `ux.md` §2.2. **[P0-9]** gives the canonical form and its
`path` component (`spec/03-approved/xap/ux.md:186-201`):

> `[frag [route /orders] [feature orders] [path /open-orders/row[o-1041]/status]]`
> … **path** — element path inside the instance's projection: schema-derived
> step names for projected elements, template slot names for template
> regions, the author-assigned id (§2.4) for placed elements.

So a path step is `<element name>[<key value>]`, keyed by the DECLARED key,
never by position. **[P0-10]** makes the "never by position" normative and
gives the reason (`ux.md:204-209`):

> Positional row identity is **never** minted — an insertion must not
> re-address every following row.

### 2. A flow construct's declared key is `name=`, and it is total

`flow.md` §2.3 declares `name=` "unique in the document" on `step`, and
`name=` on `flow` / `branch` / `map` / `until`. It is not merely declared —
it is ENFORCED, on every construct, by `f--check-names`
(`stdlib/flow.cx:695-706`), which refuses `CXER4952` both for a duplicate:

> the name `…` is used by more than one construct — `name=` is unique in the
> document (§2.3), because the record, every transition and every guard
> address a construct BY name

and for an absence:

> a construct carries no `name=` — every step, branch, map and lane is
> addressed by name in the record, in transitions and in guards (§2.3)

§4.17's totality obligation is scoped to "every document `validate`
accepts", so over exactly that set a name-keyed address is TOTAL. This is
also the addressing flow already uses everywhere else — the record, the
transitions, the guards (`$steps/<name>`) and `needs=`.

**Therefore** the address of a construct is `/flow[<name>]` at the head and
`…/<word>[<name>]` per nested construct, e.g.
`/flow[checkout]/branch[fanout]/seq[left]/step[compile]`. The `cx:diff` /
`cx:patch` positional path spelling (`/users/user[2]/name`,
`vcx/code/stdlib_cx.v:1488-1513`) is a DIFFERENT regime — a diff address
over arbitrary values, where no key is declared — and using it here would
be precisely the positional identity P0-10 forbids: inserting a step would
re-address every following node in the picture and invalidate every anchor
and studio selection in it.

### 3. Marks, badges, ladders and edges carry their CONSTRUCT's address

§4.17 says "a drawn element with no document address is a defect", and it
draws elements that are not constructs: a clock mark, a performer badge, an
escalation rung ladder, a skip edge, a fork bar, a join bar. None of them
has a `name=`, so under P0-10 none of them may be addressed positionally,
and P0-10's own remedy applies — "the enclosing fragment is the smallest
addressable unit".

That is also what §4.17's construct table already says of them: a
`deadline=` is "a clock mark ON the construct", `[escalate]`'s rungs "a
short ladder BESIDE it", `pivot=` "a marked node", `when=` "a labeled edge
INTO the guarded construct". They are decorations of a construct's node,
not constructs. **So only the five construct words that `validate` accepts
mint addresses — `flow`, `step`, `branch`, `seq`, `map` — and every mark,
badge and edge drawn for a construct carries that construct's address.**

Where one construct needs more than one NODE (a `branch` draws a fork bar
and a join bar; a guarded construct draws a skip edge), the second node's
address is the construct's address with a ROLE TAIL — `#fork`, `#join`,
`#skip` — from a closed role vocabulary in the sealed rule table. The tail
is part of the string the sanitizer is given, so injectivity and "the
sanitizer is the only place the charset rule lives" both still hold, and the
readable address including the tail is what rides in `data-cx-address`.

### 4. Injectivity forces an ESCAPING sanitizer, not the shipped replacing one

The module's existing sanitizer, `cd-sanitize-id`
(`stdlib/diagram.cx:2700-2714`), maps every character outside
`[A-Za-z0-9_]` to `_`. It is total but **NOT injective**: `a/b` and `a-b`
both become `a_b`. It cannot be reused here, which is a second, independent
reason the ruling's "do not unify them" is right.

`fl-id` is therefore an escaping function over the same target charset:
`[A-Za-z0-9]` pass through, `_` doubles to `__`, and every other byte
becomes `_` followed by two lowercase hex digits. The escape alphabet is
prefix-free (`_` is not a hex digit), so decoding is deterministic and the
function is injective over ALL strings, not merely over one document — a
strictly stronger property than the ruling requires, and cheaper than
reasoning about which strings a document can hold. Every address begins
with `/` → `_2f`, so an id can never begin with a digit, which is the
leading-digit hazard `cd-sanitize-id` guards for separately.

## Scope of the picture, and why that is not a partial implementation

§4.17's totality gate is "every document `validate` accepts has a picture".
Five §2.3 words are SPEC'D AND NOT YET IMPLEMENTED, and `validate` refuses
each with `CXER4952` naming its landing — `until`, `quorum=`, `flow=`
(sub-flow), `calendar=` and the `[notify]` rung, registered in
`f--attr-pending` / `f--kid-pending` (`stdlib/flow.cx:298-317`). No document
carrying one of them is accepted, so no such document is inside the
totality obligation.

The rule table therefore carries a row for every §4.17 construct row —
which is what lets the completeness gate diff the table against the spec
table for SET EQUALITY, the DGX-1b discipline — and marks those five
`pending=` with the same reason string shape flow's own registers use. When
the word lands in `validate`, its picture row is already written and the
`pending=` mark comes off in the same landing. That is the register
discipline this module pair already ships, not a stub: nothing claims to
draw a construct it cannot draw, and the drift dies structurally.
