# Owner decisions 2026-09-28 (midday) — Letters 71 to 79: the world-class documentation design, nine choices

**Status: RULED (owner, 2026-09-28 ~11:5xZ, in session, on the design pass posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 11:4xZ — `DOCS4-DESIGN.md`, the Fable
design pass of the docs redo the owner directed at 08:3xZ). The nine letters were the design's every
unforced choice; the owner took the recommended (a) on each. RS-30, RS-28, RS-1, K11, CXF-1, D83a,
SITE-1; the CICD-1 flow document carries the steps these add.**

## The owner's word, verbatim

"All recommendations accepted"

## DOCS-41 — one prose file per repository, every fact projected from the registries (L71 = (a))

Each served repository page (`repo-<name>.html`, one per `registry/repos.cxd` row with
`status=extracted` or `name=cx`) takes its prose from one hand file `docs-src/repos/<name>.cxd` and
every fact — what it ships, its status, its pins, its `at=` sha — from `repos.cxd`, `modules.cxd` and
`deps.cxd`; a missing file is named by `site-check`. Rejected: (b) fully generated pages from `about=`
and the pinned README — tables, not a narrative; (c) prose kept in each component's README — a voice
pass across seventeen repositories, and the front door losing the narrative RS-28 gave it.

## DOCS-42 — the ring SVG is rendered from the registry at build time, untracked (L72 = (a))

A CX script under `scripts/` reads `registry/modules.cxd` and `registry/repos.cxd` and emits the
ring figure — Ring 0 at the centre, Ring 1's modules on the ring, the platform group clustered by
repository, the bindings and ecosystem groups at the edge — at `make guide` time, inlined in the pages
and written untracked, with a self-test that its module count equals the registry's; the existing
colour tokens, never a hard-coded colour again. Rejected: (b) a tracked SVG with a drift gate — one
more generated-and-committed artifact; (c) the hand geometry kept — drifts the day a module moves.

## DOCS-43 — Python confined to the bridge pages and held by a step (L73 = (a))

Python is named only on the migration page, one comparison row and the quickstart's host-language
step; a `docs-voice-check` step counts the word outside those pages and fails above zero. Rejected:
(b) the same confinement with no step — a rule that erodes; (c) no Python anywhere — the one bridge
RS-30 allows, lost.

## DOCS-44 — the internal link step extends the site assembler's check (L74 = (a))

`site_assemble.cx --check` walks every `href` and `src` of every assembled page and every relative
link of every served Markdown file, fragments included, against the assembled tree. Rejected: (b) a
separate script — a new row for the same walk; (c) the landing's and the guide's partial checks alone.

## DOCS-45 — external links are checked by a CX script in the site workflow, not pre-merge (L75 = (a))

A CX script over the http client fetches every external URL once per run, with an allowlist file for
known-flaky hosts; it runs in `site.yml` and in the CICD-1 flow's check step, never in
`TEST_TARGETS`. Rejected: (b) in `TEST_TARGETS` too — a network step in every union; (c) none.

## DOCS-46 — the LLM door is rendered and `docs/dev/` retires into the guide (L76 = (a))

`llm/index.html` is rendered from the LLM manifest; the `docs/dev/` pages, which predate RS-1 and
still say "Ring 2/3", fold into the guide's platform sections and a new operations page. Rejected:
(b) both doors rendered and `dev/` re-voiced in place — a second parallel guide kept; (c) doors only.

## DOCS-47 — every example on a touched page is a fixture citation, with a ratchet (L77 = (a))

Every example on a new or re-voiced page is a `[fixture id=]` citation replayed byte-exact; the
snippet step carries a floor on the citation count that a wave may not lower. Rejected: (b) new pages
only — two standards on one site; (c) all 466 first — a fixture wave before any voice work.

## DOCS-48 — the value map becomes the enterprise page, each item re-backed (L78 = (a))

`docs-src/positioning/ring_value_map.md` is served as `enterprise.html`, each item's backing turned
into a fixture id or a step name and its archived spec paths fixed. Rejected: (b) left unserved; (c)
dropped.

## DOCS-49 — the generators and the front pages first, the repository pages next, the voice pass last (L79 = (a))

Wave 1: the generators (the ring SVG, the plug-in diagram, the before/after panels on the site, the
two link steps, the one TL;DR source), the landing, the why page, the rings page, the LLM door; waves
2 to 4: the repository pages, eight per wave; waves 5 to 7: the voice pass with the fixture ratchet,
the enterprise page, the `dev/` fold. Rejected: (b) the voice pass first — pages changing under the
reader before the structure does.
