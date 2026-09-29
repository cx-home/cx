# Owner direction 2026-09-29 — what earns the documentation a 5 of 5, the playground included

**Status: RULED (owner, 2026-09-29 ~03:0xZ, in session: the owner rated the live site 2 of 5 and the
playground 1 of 5 after a shallow scan — the playground's Query tab holding `[?match]` programs, two
vocabularies on one page, a guide sidebar listing every module beside the sections — asked for the
acceptance criteria, read the nine below and said "looks pretty good. is that the doc spec? does that
include playground? hope so." — and "no fix until the next 5-hour window"). DOCS-41…49, HOSTL-1,
PLAY-1, RS-30, CXF-8.**

## The owner's words, verbatim

"a lot of the query examples in playground are not query but code. and why do we have categories doc,
query, program instead of data, query, code? lack of consistency in terms is a massive failure." —
"looks pretty good. is that is the doc spec? does that include playground? hope so." — "playground
made some attempts at improvement up ultimately took steps back from 4 of 5 to 1 of 5 with glaring
issues." — "Don't fix until we get more credits in the next 5hr window."

## DOCS-51 — the acceptance criteria for a 5 of 5, each held by a step, none ticked on a step table alone

The site is 5 of 5 when a reader finds no issue and a step keeps it that way. Every DOCS-4 wave from
this ruling on is written to these nine and merges only after the integrator has read its pages
against them in a browser and the owner has read them too; a wave that passes its steps and fails a
reader is sent back, not merged.

1. **One vocabulary.** The rings' and the delivery grammar's words everywhere: data, code, a query
   is a program over data, two rings and the groups above them. The same word for the same thing on
   the landing, the guide, the reference, the playground, the primer and the navigation. Held by a
   word-list step over every served source, in the shape of the voice ratchet.
2. **Every page answers one reader in its first screen.** Who it is for, what it gives, one runnable
   example, where to go next. No page that is a generated table with no prose around it.
3. **The navigation is the reader journeys.** Start here, Guide, Reference, Repositories, LLM; at
   most about seven items in a group; the module reference pages under Reference only; every page
   within three clicks of the landing. Held by a step over the nav's shape.
4. **Every example is a fixture**, replayed byte-exact, the floor at all of them. The playground
   classifies an example by WHAT IT IS — a data document, a query over a document, code — never by
   the chapter it sits in or the flags it runs with; every example runs in the browser or says why
   not, by name; the page opens on an answer. Held by the playground gates and the citation ratchet.
5. **Every fact is projected**, never typed: counts, pins, versions, module tables. Every link
   resolves, internal and external. Nothing says Ring 2 or Ring 3 or names the monorepo. Held by the
   generators, the link walks and the vocabulary step.
6. **The live site equals the head.** A refresh follows every documentation merge, and a step
   compares the live site's version stamp with the public main.
7. **The voice.** First person plural for CX; a claim beside its fixture or its count; no host
   language outside the four ruled exceptions; no sentence lifted from a prompt. Held by the voice
   ratchet.
8. **Complete.** A page for every repository, module, directive, CLI verb and flow document;
   `llms.txt` and the primer generated from the binary and equal to it. Held by the manifest checks.
9. **The owner's read.** The owner opens the landing, the guide home, the playground and three
   pages picked at random and finds nothing to iterate on. This is the tick; nothing else is.

## PLAY-2 — the playground's own 5 of 5, inside DOCS-51

The playground regressed from 4 of 5 to 1 of 5 under PLAY-1: its readings were assigned from the
primer's chapter order (§5's neighbours became "Query"), its tabs said Document / Query / Program
while the rest of the site says data and code, and a `[doc]` stub was shown as "the document" for a
program that reads none. Ruled: the playground's three readings are the site's words — **data**
(a document, shown and projected), **query** (a pattern over a document: a `[?for]` over a bound
`$doc`, a CXPath select, a `[?match]` on document shape — an input document is real, never a stub),
**code** (everything else: a program with no input document) — assigned by a rule over the example
itself and checked by a step that refuses an example filed against its shape; every corpus example the
engine can run is offered, every one it cannot is marked with its reason by name; the page opens on an
answer; the picker, the crumbs and the legacy sections use the same three words. A playground wave
ticks on the owner's run of five examples of each reading, not on its gates.
