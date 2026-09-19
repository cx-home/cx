# #1294 — `[$xap:on]` intent handlers

Ruling records for the §3.4 / §4.1 intent-handler surface. **Every letter here
was ruled by the owner or the Fable session on the issue before any of it was
implemented** — the provenance is listed first, because this landing is large
and the one thing a later reader must be able to check quickly is that no part
of it was self-ruled.

## Provenance

| letters | ruled by | on #1294 at |
|---|---|---|
| `1294-a`, `1294-b`, `1294-c`, `1294-d`, `1294-e`, `1294-f` | Fable + owner | 2026-09-08 16:25 ET (comment 20:04:54Z) |
| `1294-a2` | owner + Fable | 2026-09-08 17:50 ET (comment 21:41:41Z) |
| `1294-g`, `1294-h` | owner + Fable | 2026-09-08 18:45 ET (comment 22:19:44Z) |

`1294-a2` amends `1294-a`'s "presence only" sub-ruling: pattern holes BIND.
`1294-g`/`1294-h` answer questions 2 and 3 of a later draft and explicitly
direct that questions 1 and 4 of that draft are already closed by `1294-a`/`a2`
and are to be implemented as those state them, "not as a fourth spelling".

## What was there before

`fn xap_on(args []cx.Node) ?cx.Node` returned a `null` scalar and read none of
its arguments. Its docstring said it "records the handler for completeness";
`struct XapRuntime` had no handlers field and no bus field, so it recorded
nothing. Corpus pre-flight before implementing: **zero** hits for `xap:on` in
`conformance/`, `docs-src/`, `docs/llm/` and `vcx/tests/testdata/`. Nothing was
pinned; no expectation had to be flipped.

## Implementation readings — the decisions the letters did not spell out

These are **not** new rulings. They are the places where the letters left a
mechanism open, recorded here so the next reader does not have to re-derive
them from the code, and so any of them can be redirected without re-opening the
ruling.

1. **A bare verb pattern matches a qualified act's LOCAL name.** `1294-a`
   admits both `:create` and `'thing/create'` as spellings of one pattern, and
   §8.2 makes the committed act's verb QUALIFIED whenever a grammar is
   attached (`xap_emit_prepare` rewrites `items[0]` to the resolved name). An
   exact compare alone would make the bare form dead the moment a grammar is
   attached — and the bare form is the spelling both spec examples use — so a
   bare pattern also matches the local name. A **qualified** pattern stays
   exact: it names one noun's verb, and widening it would silently broaden an
   audit-bearing registration.

2. **The verb slot is read in two spellings.** Measured against the binary:
   `[?quote [do :create [id $x]]]` renders `[do [cx:atom 'create'] [id $x]]` —
   the lift wraps scalars in their codec element. A pattern written directly as
   data carries a bare atom instead. Both resolve to the same text
   (`xap_pattern_verb_slot`), so `1294-a`'s one comparison covers both; reading
   only the bare form would send the quoted verb through the generic matcher as
   a type-strict atom literal, which cannot match a qualified (string) verb at
   all.

3. **A handler REJECTS by returning an `[err]`; a handler that FAULTS does
   not.** `xap.md:965` declares `CXER4851 E_XAP_INTENT_REJECTED` as "a
   subscriber rejected an admitted intent; the rejection event + flowing
   `[err]`", and `1294-e` places that code on step 3's failure path. A returned
   `[err]` is therefore the rejection channel. A fault (bad arity, a raise) is
   the handler being broken rather than the act being rejected, and letting it
   flow would let one bad registration refuse every act on the runtime — so it
   is swallowed and the walk continues.

4. **The first rejection stops the walk.** Later handlers would otherwise run
   against an act the runtime has already recorded as rejected.

5. **The rejection event's SHAPE.** Not specified by the letters or by §8
   beyond "the rejection event". Implemented as the minimum that makes a
   rejection auditable from the stream alone, under the `[event …]` envelope
   §3.1.1 makes the stream's total pattern:
   `[event [rejected code='cx-err:CXER4851' reason=… by=<subscription id>] ACT]`.
   `reason` is `subscriber-rejected` or `handler-cascade-cap`.

6. **Dispatch order is REGISTRATION order, and the list is snapshotted.**
   Nothing here has a priority vocabulary; the bus's `priority:` is the bus's,
   and minting a second one would be the parallel surface `1294-a` refused. The
   snapshot means a handler that registers or cancels another does not change
   who fires for the event being dispatched.

7. **`xap_handler_depth_cap` = 8.** `1294-c` requires a constant named in §4.1
   and does not fix its value. Eight rather than one because a handler that
   emits is the point of the surface; a constant rather than a knob because the
   bound is quoted in the refusal and an operator must be able to read it.
   Counted per RUNTIME so the bound holds however handlers chain.

8. **The matcher reuses `[?match]`'s engine via the data image, and the engine
   gains exactly one arm.** `1294-a2` requires "the SAME engine `[?match]`
   uses (one pattern language, C7)". `[?quote]`'s output is CXDM data, and the
   engine's element-shape vocabulary is `cx.ProgramPattern`, which only the
   parser mints — so the bridge is `data_to_program_node` (the lowering
   `[?eval]` already uses) plus one new arm in `match_value_pattern` for
   `cx.ProgramLiteral{kind: .cx_element}`, in `vcx/code/matcher_data_image.v`.
   **Checked rather than assumed** that this cannot move an authored pattern's
   meaning: `parse_match_pattern` (`vcx/cx/program_parser.v:3670`) is the one
   reader for all three pattern positions, and its `[`-led arm yields
   `.array_lit` or `cx.ProgramPattern` — a `.cx_element` literal is minted only
   by the expression-mode element parse, which no pattern position reaches.
   Before the arm existed, a `.cx_element` in pattern position fell through to
   `scalar_literal_matches` and could only return false.

9. **Element-pattern body items are an ORDERED SUBSEQUENCE.** An act carries
   fields the pattern does not mention, so exact arity would force a pattern
   that names one field to name them all. Order is still honored, so a pattern
   that reads as a shape keeps reading as one.

10. **`handlers:` entries are `[on PATTERN HANDLER]` and go through
    `xap_on`.** One registration path, so a bad pattern refuses at `run`
    exactly as it does at the call. Wired after the journal replay and before
    the source pumps arm: replay rebuilds state rather than re-running the
    cascade, so a handler must not fire for a replayed act, and it must not
    miss the first ingested delivery either.

## A finding the ruling's own fixture sentence does not survive

`1294-h` asks for a fixture where "a two-argument call refuses with the arity
fault naming the runtime". Measured: the arity is enforced by the `[?def]`
declaration BEFORE the builtin runs, so a two-argument call answers
`cx-err:CXER0100 missing required argument handler` — it names the parameter
that ended up missing, not the runtime the author forgot. **Three arguments
are required, which is `1294-h`'s substance, and both offending spec examples
are corrected in this landing.** The WORDING cannot name the runtime without
changing the arity diagnostic for every `[?def]` in the language, which is not
this issue's to change. `xap-on-006` pins what the surface actually does and
says this in the case; the gap is reported on #1294 rather than pinned as if it
were the ruled wording.

## Not in this landing, and named rather than dropped

`1294-f` sanctions landing "in RULED pieces with fixtures per landing (matcher
+ dispatch first; batch-lane fix; closed set; 4851)". This landing is the
first piece plus 4851 (which is step 3's own failure path and not separable
from dispatch). Still owed, in `1294-f`'s order:

- **The batch lane's per-act prep recompute** (`1294-c`, second half): the
  pipelined `xap_emit_batch_into` precomputes every act's prep BEFORE any
  fold, so a later act's prep cannot see an earlier act's fold. The lane now
  dispatches per entry in receipt order, but the precompute shape is
  unchanged and is still the latent defect `1294-c` names.
- **`run`'s CLOSED option set** (`1294-d`, second half), mirroring `serve`
  under `1221-b`. Measured while implementing `handlers:`: `run` reads
  `tenant`, `resolver`, `grammar`, `derivers`, `log-reduce`, `journal`,
  `sources` and now `handlers`; the run-option table ALSO declares `authz`,
  `sessions`, `components` and `surfaces`, which nothing reads, and does NOT
  declare `grammar` or `derivers`, which are read and are live in the
  `xap-compose` family-6 fixtures. So closing the set is not a one-line guard:
  it has to decide what the closed set IS, and the table has to become true in
  both directions. `1294-d` says a red there "is a finding, not a reason to
  reopen" — that finding is the four unread declared keys, and it is recorded
  here so the next piece starts from it rather than rediscovering it.
