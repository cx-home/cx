# Matrix — the format surface, every cell addressable (2026-08-30)

**Why this file exists.** The owner's finding, verbatim in intent: the truth
about the format surface was fragmented because nothing COMMITTED to
unification and orthogonality across formats. This matrix is that
commitment instrument — the same shape as
`ledger/matrix_2026_08_25_path_value_model.md` for path/value semantics.
Rule: **every divergent cell carries a justification (a ruling or a spec
citation) or is flagged UNJUSTIFIED with a filed action.** A future change
that makes two cells differ without adding a justification here is wrong
by definition.

Cell reference: `<row>.<col>` — e.g. `D7.JSON`. Columns: CX, XML, JSON,
YAML, TOML, MD, CSV (covers tsv/psv dialects), HTML, URL, BIN
(cxcol/data-bin/ast). State shown is POST the CR-1..CR-7 wave (in
execution at time of writing); `→` marks what the wave changes, so the
pre-wave state stays readable.

## The matrix

| # | Dimension | CX | XML | JSON | YAML | TOML | MD | CSV | HTML | URL | BIN |
|---|---|---|---|---|---|---|---|---|---|---|---|
| D1 | Registry entry | base | base | emit-only base → full base | base | base | base | base | overlay → base | overlay → base | base |
| D2 | Parse core ring | R0 | R0 | R1 → R0 | R0 | R0 | R0 | R0 | R1 → R0 | R1 → R0 | R0 |
| D3 | Emit core ring | R0 | R0 | R0 | R0 | R0 | R0 | R0 | R1 → R0 | R1 → R0 | R0 |
| D4 | Bytes halves | fallback | fallback | fallback | fallback | fallback | fallback | fallback | fallback | fallback | native |
| D5 | Module (layer 2) | always-on | synthesized | dedicated | synthesized | synthesized | synthesized | dedicated | dedicated | dedicated | synthesized |
| D6 | Format-intrinsic verbs | hash/canonical/diff… | — | pretty, parse-stream, opts | — | — | — | dialects, schema | sanitize, extract-text | query, join, idn | — |
| D7 | Registry parse-opts keys | — | whitespace, entities | — (module-level opts only) | — | — | — | — (module-level dialects) | — | — | — |
| D8 | Registry emit-opts keys | — (inherent) | lossless | lossless | lossless | — | — | — | — | — | — |
| D9 | Lossless image | inherent | `<cx:T>` | `$tag`+sidecar | `!!cx:T` | refused by name | refused by name | refused by name | refused by name | refused by name | n/a |
| D10 | Canonical emission | REAL (`cx canonical/hash`) | reserved | reserved | reserved | reserved | reserved | reserved | unspecified | unspecified | n/a |
| D11 | Streaming read | events model (CX source) | none | NDJSON records | none | none | none | none | none | none | chunked tables |
| D12 | Streaming write (events writer) | yes | yes | yes | yes | value lanes only | value lanes only | no | no | no | writer ABI |
| D13 | ABI conversion family | yes (`cx_to_*`) | yes | yes | yes | yes | **none** | yes (+delimited) | **none** | **none** | yes |
| D14 | Error band | CXER01xx | CXER0100+`XML —` | CXER31xx | CXER0100+`YAML —` | CXER0100+`TOML —` | CXER0100 | CXER15xx | CXER39xx | CXER14xx | decode refusals |
| D15 | Refusal location | line:col | line:col | none → line:col | line:col | none → line:col | ◐ | row | ✅ | ✅ | n/a |
| D16 | Nesting guard | 64 | 64 (shared) | **100** | 64 (shared) | 64 (shared) | n/a (flat) | n/a (rows) | unverified → 64 (shared) | n/a | 64 |
| D17 | §0.4 encoding boundary | yes | yes | yes | yes | yes | yes | yes | verify at move → yes | verify at move → yes | n/a |
| D18 | Typing policy | native | lexical + `cx:attr-types` | strict, never synthesizes | 1.2-core subset | native | n/a | lane autotypes / module never | verbatim text | components as strings | schema-driven |
| D19 | Dialect pinned where | grammar | conversions §2.1 (XML 1.0+NS) | json.md (RFC 8259 strict) | TF-2 stmt (1.2 core, CX subset) | conversions §6.1 (TOML 1.0) | conversions §7 (subset, D-B) | csv.md (RFC 4180+dialects) | html.md (WHATWG-lenient) | url.md (3986 + WHATWG) | data-bin.md/ast-bin.md |
| D20 | Data profile / libcx-core | full | full | emit-only → full | full | full | full | full | absent → full | absent → full | full |
| D21 | Corpus `in-*` cases | 1916 | 47 → **50** | **0 → 4** | 49 | 18 | 5 | 5+1+1 | **0 → 2** | **0 → 2** | binary lanes |
| D22 | Open defects | — | — | — | — | — | — | — | — | — | — |

(D22 note: #1119, the 112×/50× in-memory representation cost, is
cross-format — it is the top-priority open item by TF-10 and applies to
every column's parse lane, so it is not a per-cell divergence.)

## Divergence register — every non-uniform row, justified or flagged

- **D1/D2/D3/D20 (the wave's subject):** divergence existed pre-wave for
  JSON/HTML/URL, RULED unjustified (CR-1), being removed. Post-wave these
  rows are uniform; #1130's gate record makes new divergence loud.
- **D4:** uniform BY MECHANISM — one registry fallback (text half +
  BOM strip) serves every text codec; BIN's native bytes halves are the
  codec.md §4 binary row. Justified.
- **D5/D6:** the TF-3 criterion — a format gets a dedicated module exactly
  when it has format-intrinsic verbs. The column IS the justification;
  an empty D6 with a dedicated module, or a rich D6 without one, would be
  the violation. Justified, ruled.
- **D7:** xml-only registry opts is TF-3's sequencing ("xml first"; yaml/
  json lossless emit rode it). JSON's parse options (number-mode, max-*)
  live at module level only — justified as sequencing, NOT as end state:
  when a second format needs registry-level parse opts, json's fold in.
  csv dialects are module-level BY RULING (§8.2 two-surface split).
- **D8/D9:** lossless keys exist exactly where a lossless image exists
  (conversions.md §0.2); everything else refuses BY NAME — the ruled
  no-silent-no-op posture. cx is inherently lossless so the flag is not
  offered. Justified, uniform in rule.
- **D10:** reserved everywhere per TF-1(a2), real only for CX text
  (TF-1(a1) removed the C14N claim permanently). **HTML/URL have no row in
  canonical.md at all** — recorded here as an open spec cell: decide when
  TF-1's revisit trigger fires (first consumer of deterministic non-CX
  emission). No issue filed — the trigger owns it.
- **D11:** TF-5 — the 32-event model is the ONE committed streaming-read
  direction (json+xml first), demand-triggered; NDJSON is a lane, not the
  ceiling; per-format streaming hacks forbidden meanwhile. Justified,
  ruled.
- **D12:** the events writer's six formats are abi.md §2.15's spec'd set;
  toml/md take value lanes only (element events refuse — those formats
  cannot carry them). csv/html/url absent from the writer: csv's row
  streaming lives in the chunked-table ABI; html/url have no
  document-stream shape. Justified by spec; extend only via abi.md.
- **D13: was UNJUSTIFIED — now RULED (CR-8 = a BY OWNER 2026-08-30,
  #1133) and LANDED (W8):** one registry-generic ABI conversion entry;
  the bespoke families are frozen legacy sugar, documented as such, never
  extended. **Read the row this way now:** the cells below describe the
  frozen FAMILIES, which are permanently as shown; ABI REACH is uniform —
  `cx_convert(src, from, to)` resolves any registry name in the loaded
  artifact, so md/html/url (and any future or overlay-registered codec)
  are reachable from every binding with no new symbols. The row stays as a
  record of what the families cover, and it may never grow a cell.
  Original register entry kept below for the record.
  codec.md §6 says "the ABI / language
  bindings expose the registry, not bespoke `cx_X_to_Y` functions"; the
  shipped ABI is the inverse: bespoke N×M families for cx/xml/json/yaml/
  toml/csv, and NOTHING for md/html/url. abi.md documents the families as
  frozen carry-over, so the resolution is a registry-generic entry point
  (from-name + to-name) with the families as documented legacy sugar —
  or an explicit codec.md §6 amendment. Filed: #1133. #1130's inventory
  entry is the first registry-shaped ABI step either way.
- **D14/D15:** per-format CODE BANDS are registered allocation
  (cxer-registry-gate); the SHAPE is one ruled contract (TF-9:
  code + named class + location in the format's natural unit). Post
  W1/W4 the location column holds everywhere a natural unit exists;
  MD's ◐ is the recorded residual (rare, low-stakes errors; upgrade
  opportunistically).
- **D16:** 64 is the shared ruled bound (#1106) — JSON's 100 predates it,
  is spec'd (json.md §4) and caller-configurable, with a named refusal.
  Divergent-but-documented; RECORDED as a harmonization candidate, not
  unjustified. **HTML: RESOLVED at the W2 move — the cell now reads 64
  (shared).** Probed on the pre-move binary, verbatim: a 50 000-deep
  `<div>` document through `cx --from=html --to=cx` was `RC=139`
  (SIGSEGV); so was depth 20 000 to `cx`, `html` AND `json`; depth 5 000
  to `html` was `RC=0`. The verdict is NOT "the parser recurses" — the
  tokenizer is a byte loop and the tree builder keeps an EXPLICIT frame
  stack, which is why depth 5 000 serialized fine. It is the #1106 hole
  one step removed: a reader that accepts unbounded nesting from
  untrusted input hands every recursive CONSUMER of the tree (the cx /
  json / html emitters) a stack-overflow vector, and `--from=html` is the
  untrusted-input surface. So the guard sits in the reader, at the frame
  push, on the shared bound. Refusal, in html's own band per D14:
  `cx-err:CXER3900 E_HTML_PARSE_FAILED: element nesting exceeds limit
  (64)` — the same band-local shape JSON's depth refusal takes
  (CXER3101), not the `CXER0100 PARSE_ERROR: <FMT>` form xml/yaml/toml
  use. **Open sync: `limits.md` §2's codec-parser row names only
  XML/YAML/TOML and states the CXER0100 shape; it needs html added and
  the band-local shape noted (json's row has the same unstated
  divergence). Spec edit — NOT taken in this wave; it needs the owner's
  authorization and a `RULED:` token.**
- **D17:** RESOLVED at the W2 move. Both cores already routed their input
  through the ONE §0.4 boundary (`cx.codec_text_boundary`) before reading
  a byte — html and url were marked "verify at move" because nothing
  PINNED it, not because it was suspected absent. Verified and pinned:
  `test_text_codecs_refuse_a_utf16_bom` now covers the whole text-codec
  row (xml, yaml, toml, json, md, html, url), asserting both that the
  refusal names the ENCODING and that it names the policy it enforces.
  Row uniform.
- **D18/D19:** typing and dialect are per-format BY NATURE — the
  uniformity requirement is that each be PINNED normatively somewhere,
  and post-campaign every column is. Justified.
- **D21:** the corpus floor was never stated per codec, which is how
  D21.JSON=0 stayed invisible (#1126/#1127). New rule, this file: **every
  codec with a text parse half carries at least one `in-<fmt>` corpus
  case**; the registry-driven runner (CR-4) refuses unknown sections,
  closing both directions. **SATISFIED for every column as of W5/W6:**
  json = conv-052..055 (W5), html = conv-056/057, url = conv-058/059
  (W6). The html/url pair WERE intentional exclusions from the extraction
  gate's C-ABI probe (no `cx_html_*`/`cx_url_*` family exists, as with md);
  the probe derives that from its own battery table now instead of a
  hardcoded `in_md` literal, and their cross-artifact assertion rested on
  the `cx_codec_inventory` record (#1130) rather than on a fixture. **W8
  (CR-8, #1133) closed the exclusion the registry-shaped way:** the generic
  `cx_convert` entry gave md/html/url an ABI path with zero new bespoke
  symbols, the probe drives all three through it, and the gate's
  ABI-excluded count is **9 → 0** — the intentional-exclusion set is empty.
- **D22:** EMPTY. #1104 (xml duplicate attribute names accepted) was the
  last format-local open defect; it is closed — the reader refuses a
  repeated attribute name as MALFORMED (#1100) with its one refusal shape,
  and the D21 xml count moves 47 → 50 with the three `in-xml` cases that
  pin it (conv-060 position, conv-061 reserved names, conv-062 the
  Namespaces-spec boundary that still parses). Every other audit defect
  (#1105–#1118, #1120) was already closed.

## Maintenance rule

A PR that changes any cell updates this file in the same commit; a PR
that makes two columns differ on a row NOT already justified here needs a
ruling first. The extraction gate's registry record (#1130) enforces
D1/D2/D20 mechanically; the rest is reviewed at this file.
