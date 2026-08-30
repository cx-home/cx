# Audit — the text-format surface (2026-08-30)

**Scope.** Adversarial audit of the eight text formats: the dedicated,
file-backed stdlib modules (`json`, `csv`, `url`, `html`) and the synthesized
codec modules (`xml`, `yaml`, `toml`, `md`; plus `cx` as the pivot). Judged
against the enterprise/iPaaS bar: third-party round-trip fidelity,
canonicalization for signatures, streaming, hostile input, interop with
systems that will not change.

**Instrument.** `vcx/target/cx` rebuilt at HEAD (`2550c768a`,
`make build-vcx` clean) — every measurement below re-run or spot-confirmed on
that binary. Probes are direct CLI/program invocations with output quoted
inline; no fixture lane is trusted anywhere in this document without its
content having been read (the `v test` stdout-suppression trap does not
apply to direct invocation). No code, spec, or fixture was modified.
Working-tree files from the parallel SAML session (`ledger/rulings_2026_08_29_…`,
`spec/03-approved/process/governance.md`, `spec/03-approved/std-lib/saml.md`,
`devbox.lock`) were left untouched.

Umbrella: #1097. Prior context: #1091 (the SAML consumer that exposed the
question), #1104 (duplicate XML attributes, confirmed still open and still
reproducible).

---

## 1. The standard

A grading standard vague enough to always pass is useless; this is the bar
each format is measured against, chosen from what the enterprise consumer
actually does with it.

| Format | Best-in-class means |
|---|---|
| **xml** | XML 1.0 + Namespaces conformance on parse (well-formedness enforced, attribute-value normalization, entity handling per spec), infoset-faithful round-trip, C14N 1.1 available for signature interop, a streaming path for large documents, clean refusals (never a crash) on hostile input. Reference points: libxml2/Xerces. The consumer that sets the bar is SAML/XML-DSig (#1091) and any integration that re-emits third-party XML. |
| **json** | RFC 8259 strict, explicit big-number policy, I-JSON-grade interop, NDJSON streaming, depth/size guards with named refusals. Reference: serde_json/Jackson strict mode. |
| **yaml** | A *stated* version (1.2 core schema being the defensible choice) implemented fully, or a *normatively specified subset* that refuses what it does not implement. Silent acceptance-with-corruption is the one unacceptable posture. Reference: go-yaml, ruamel. |
| **toml** | TOML 1.0 conformance including native datetime round-trip; strict refusals. Reference: toml-rs. |
| **md** | A stated dialect, deterministic emit, lossy-by-ruling (D-B) is fine. |
| **csv** | RFC 4180 + dialects, schema-driven typing with a no-guessing default, row streaming, refusals that name the row. Reference: Python csv + frictionless. |
| **url** | RFC 3986 and WHATWG both available and labeled; normalization sound enough to build security decisions on. Reference: whatwg-url. |
| **html** | WHATWG-robust lenient parse, policy sanitizer, deterministic serialize. Reference: html5ever/bleach. |

Uniformly, per CX's own core specs: the codec contract (`codec.md` §3/§6),
the loss table (`conversions.md`), the guard posture (`limits.md` §1: the
parse surface is "the ring whose whole pitch is parsing untrusted input"),
and the encoding policy (`conversions.md` §0.4).

---

## 2. Capability matrix

Legend: ✅ meets the §1 bar · ◐ partial · ✗ fails · — not applicable.
"Spec accurate" = the normative text describes shipped behavior.

| | spec exists | spec accurate | parse fidelity | emit fidelity | canonical form | streaming | hostile input | error taxonomy | verbs beyond parse/emit |
|---|---|---|---|---|---|---|---|---|---|
| **cx** | ✅ canonical.md, cxdm.md | ✅ | ✅ | ✅ | ✅ (`cx canonical`/`hash`) | ◐ (streaming.md not in-program) | ✅ depth 64 named refusal | ✅ CXER01xx | ✅ (hash/diff/patch/select…) |
| **json** | ✅ json.md + core | ◐ (F9 +inf) | ✅ strict | ✅ | ✗ §5 CXC-JSON not implemented | ◐ NDJSON only (spec-accurate) | ✅ depth 100 named | ✅ CXER31xx (CLI strips, F13) | ✅ pretty/opts/stream/is-valid |
| **csv** | ✅ csv.md + conv §8 | ✅ | ✅ no-guess default | ✅ RFC 4180 | ✗ §9 not implemented | ◐ sequence-of-rows | ✅ | ✅ CXER15xx names the row — best in repo | ✅ dialects/schema |
| **url** | ✅ url.md | ✅ | ✅ | ✅ | ◐ normalize lacks dot-segments (F15) | — | ✅ | ✅ CXER14xx | ✅ query/join/encode/idn |
| **html** | ✅ html.md | ✅ | ✅ lenient per spec | ✅ | — | ✗ | ✅ sanitizer passed XSS battery | ✅ | ✅ sanitize/extract-text |
| **xml** | ◐ conv §2.1/§3.1 only — no module spec | ✗ (F1–F8) | ✗ | ✗ | ✗ §8 C14N pure fiction (F2) | ✗ none | ✗ segfault ~10k deep (F3), garbage accepted (F1) | ✗ bare strings, CXER0100 | ✗ 4 synthesized verbs, no opts |
| **yaml** | ◐ conv §5.1 + canonical §6 | ✗ (F10) | ✗ anchors/block scalars corrupt | ◐ own-emissions round-trip | ✗ §6 not implemented | ✗ | ✗ segfault ~100k deep; never refuses | ✗ never errors | ✗ 4 verbs |
| **toml** | ◐ conv §6.1 + canonical §7 | ◐ (F11 datetime) | ✅ strict | ✗ datetimes emit as strings | ✗ §7 not implemented | ✗ | ✗ segfault ~100k deep | ◐ CXER0100 w/ named classes | ✗ 4 verbs |
| **md** | ◐ conv §7 + canonical §10 | ✅ | ✅ for the pinned subset | ✅ deterministic | ✗ §10 flag not implemented | — (prose) | ◐ not probed deeply | ◐ | ✗ 4 verbs (fine per D-B) |

---

## 3. Findings

Each: claim → measured (command) → severity → who gets hurt. Probes live in
the session scratchpad; every one is a one-liner reproducible from the quoted
input.

### 3.0 Prior-session claims re-derived (the "starting facts")

| Claim (SAML session) | Verdict |
|---|---|
| `[?lib 'cx-stdlib/xml']` + `[$xml:parse …]` works | **Confirmed.** |
| `parse_xml` autotypes lone text runs via `try_autotype` | **Wrong.** For well-formed XML, text is flushed as a plain `TextNode` at the closing-tag boundary ([xml_parser.v:826-851]); the autotype branch (line 964) is reachable **only for truncated input** — see F1, which is worse than the original claim. `<c>42</c>` → string `'42'` on every lane (`--to=json` gives `"42"`). |
| Strips whitespace-only text when element has children | **Imprecise.** Whitespace-only runs strip *everywhere* — and this is **owner-ruled** (W-6 companion, 2026-08-05, `ledger/partition_I1_rebless.md` items 7/10: "XML LAYOUT whitespace strips at IMPORT"). Not a defect; the mixed-content edge is F6. |
| Accepts duplicate attribute names | **Confirmed** (`<r a="1" a="2"/>` → `[r a=1 a=2]`, RC=0). #1104, open. |
| Preserves attr order, comments-as-nodes, entity refs, namespaces | **Confirmed at parse** — but emit-side fidelity fails in mixed content (F5, F6, F7). |
| `--to-xml --canonical` does not exist; no canonical emit; attrs not sorted | **Confirmed, and wider** — F2. |

### F1 — the XML parser accepts garbage, truncation, and trailing junk silently — prio:high

- **Measured:** `cx --from=xml --to=cx` over `complete garbage, no angle brackets` → empty output, RC=0. `[$xml:parse 'this is definitely not XML …']` → empty. `<c>42` (no end tag) → `[c 42]` RC=0 — and note the **int**: truncated input is the only path that autotypes, so a document cut mid-transfer parses *successfully with different types* than its complete form (`<c>42</c>` → string). `<r/>trailing garbage` → `[r]` RC=0.
- **Mechanism:** [xml_parser.v:128-131] — the document-level loop `p.advance()`s over any non-`<` byte (comment says "whitespace-only"); [xml_parser.v:822] breaks content parse at EOF without requiring the end tag.
- **Contrast:** JSON (`E_JSON_MALFORMED`), TOML (`CXER0100` with class), and even the XML end-tag-mismatch path all refuse — the parser *can* error; it just doesn't for these classes.
- **Hurts:** every ingest pipeline. A truncated SAML response, a proxy error page fed to `--from=xml`, a log line — all become silent empty/partial documents. This is the exact class conversions.md §6.1 forbids: "A data-ingestion surface never guesses at input it cannot read."

### F2 — canonical.md §§5–11 describe an unimplemented surface; XML C14N does not exist — prio:high, owner-ruled territory

- **Claim (spec):** canonical.md §5–§10 document `cx --to-json|yaml|toml|xml|csv|md --canonical`; §8 "Base: C14N 1.1", sorted attributes, "required by C14N for cryptographic interop"; §11.1 "Each emitter accepts a `canonical` flag (`canonical: bool`)".
- **Measured:** `cx --from=xml --to=xml --canonical t1.xml` → `cx: unknown flag --canonical`, RC=2. `grep -rn '\-\-canonical' vcx/cli vcx/cmd` → zero hits. No emitter signature takes a canonical flag (`emit_xml`/`emit_xml_lossless` etc. only). Round-trip of `<r ID="A1" b="2" a="1">` preserves source attr order — no C14N sort.
- **Hurts:** anyone told by the spec they can produce C14N XML — which is the *signature* path (#1091 SAML verify needs a canonical image of the signed subtree). Today the spec promises cryptographic-interop canonicalization that cannot be produced.
- **Owner flag:** canonical identity is owner-ruled territory. The fix direction (implement §5–§10, or descope them to "reserved, unimplemented") changes either the surface or the spec — both need a ruling. Note `cx canonical`/`cx hash` (CX text canonical, §2–§3) are implemented and correct; the drift is the per-format emission canonicals.

### F3 — XML/YAML/TOML parsers segfault on deep nesting; the depth-guard exists per-format, not as a mechanism — prio:high

- **Measured:** nested `<a>` elements: depth 1,000 parses; depth 10,000 → **RC=139 (SIGSEGV)**. YAML flow `[[[…]]]` and TOML nested arrays: 10,000 ok, 100,000 → **RC=139**. JSON: `E_JSON_DEPTH_EXCEEDED: max-depth 100`, RC=1 at any depth ≥100. CX text: `error: 1:194: element nesting exceeds limit (64)` — clean.
- **Spec violated:** limits.md §1/§2 — the parse surface is "the ring whose whole pitch is parsing untrusted input" and documents "Element nesting (text parser) 64 → parse error". The guard covers only the CX text parser; the codec parsers on the same `--from=` surface have none. Depth policy across one surface: 64 (clean) / 100 (clean) / crash / crash / crash.
- **Hurts:** any service parsing attacker-supplied XML/YAML/TOML — a ~10KB payload kills the process. For the iPaaS posture this is a day-one DoS.

### F4 — XML attribute values never get character/entity-reference decoding — round-trip corrupts — prio:high

- **Measured:** `<r a="q&quot;x&#10;y&lt;z"/>` → CX `[r a=q&quot;x&#10;y&lt;z]` (raw, undecoded) → re-emit `<r a="q&amp;quot;x&amp;#10;y&amp;lt;z"/>`. The value has changed from `q"x⏎y<z` to the literal text `q&quot;x&#10;y&lt;z`.
- **Standard violated:** XML 1.0 §3.3.3 (attribute-value normalization is mandatory).
- **Hurts:** week one, any document whose attributes carry quotes/newlines/angles — SAML `AttributeValue`s, HTML-ish payloads, i18n text. Comparisons (`@a = 'q"x…'`) are wrong even without re-emit.

### F5 — XML text content: char-refs decode, named entities become nodes, and re-emit injects spaces — round-trip corrupts — prio:high

- **Measured:** `<r>q&quot;x&#10;y&lt;z&amp;w</r>` → CX `[r q &quot; 'x\ny' &lt; z &amp; w]` → re-emit `<r>q &quot; x⏎y &lt; z &amp; w</r>`. Rendered text was `q"x⏎y<z&w`; it is now `q " x⏎y < z & w` — spaces injected at every entity boundary.
- **Mechanism:** the #878/ENT-1 space-insertion rider in [emitter_xml.v:332-364] exists to keep the *CX-authored* idiom (`[note Cheese &amp; Pepper]`) readable, and fires precisely on the adjacency the *XML-import* lane produces. Two lanes share one emitter with contradictory whitespace conventions. Predefined named entities (`&quot;` `&lt;` `&amp;`) are also not decoded to characters at parse while numeric refs are — inconsistent within one text run.
- **Hurts:** anyone round-tripping third-party XML whose text carries entities — i.e., most real-world XML. Content changes silently; signatures over re-emitted content can never verify.

### F6 — XML mixed-content whitespace between inline elements is dropped — prio:medium, needs ruling refinement

- **Measured:** `<p><b>x</b> <i>y</i></p>` → `<p>⏎ <b>x</b>⏎ <i>y</i>⏎</p>` — the significant space between `</b>` and `<i>` is gone (`x y` renders `xy` under a whitespace-normalizing consumer).
- **Status:** the strip itself is owner-ruled (W-6 companion 2026-08-05: layout whitespace strips at import). The ruling's model — whitespace-only runs are pretty-printing — is right for data documents and wrong for document-oriented mixed content, where XML has no "ignorable whitespace" without a DTD/schema saying so. The ruling predates the SAML/enterprise consumer. Needs an owner ruling *refinement* (e.g. preserve whitespace-only text when the element has mixed content), not a unilateral fix.

### F7 — comments and PIs are dropped in mixed content (emit) and PIs in text runs (parse) — prio:medium

- **Measured:** `<r><!-- keep --><?php echo 1 ?><![CDATA[a<b]]>&custom;</r>` → `--to=xml` gives `<r><![CDATA[a<b]]>&custom;</r>` — comment and PI gone. In element-only content both survive (`<r><!-- keep --><a>1</a></r>` round-trips). `<r>a<?pi data?>b</r>` → `[r a b]` — PI gone at the CX image already.
- **Mechanism:** `emit_xml_inline_node`'s `else {}` ([emitter_xml.v:556]) silently discards CommentNode/PINode on the inline path.
- **Spec violated:** conversions.md §2.1 "Comments, PIs, XMLDecl: … These are all preserved."
- **Hurts:** round-trip pipelines; license headers and editor PIs vanish depending on *sibling content* — the worst kind of conditional loss.

### F8 — `mark_ref_attrs` rewrites any attribute matching any `xml:id` into a reference — prio:medium

- **Measured:** `<r><a xml:id="x7">t</a><b color="x7"/></r>` → `[r [a #x7 t] [b color=@x7]]` — `color`'s plain string became a typed reference because an unrelated element's id collides.
- **Status:** the code comment ([xml_parser.v:137-144]) admits the over-promotion. conversions.md §3.1 does not specify this promotion at all (it specs `cx:attr-types`-driven and lexical auto-typing only).
- **Hurts:** documents with id-shaped codes (SKUs, hex tokens): value semantics silently change kind; a downstream `[?match]` on string attrs stops matching.

### F9 — JSON float overflow silently produces `+inf.0` in a finite-only value model — prio:medium

- **Measured:** `[$json:parse '{"y": 1e400}']` → `{y: +inf.0}`, RC=0 (CLI lane identical).
- **Spec violated:** json.md §4.4 "CX floats are finite-only"; §4.1's no-silent-loss posture; conversions.md §4.1 "out-of-range numbers raise CXER3100–3106". Big *integers* correctly refuse (`CXER3105`) with documented opt-ins (`number-mode all-decimal` measured working) — the float side of the same policy is unimplemented.
- **Hurts:** numeric pipelines: an upstream serializer's overflow artifact becomes an infinity that CX arithmetic itself claims cannot exist.

### F10 — the YAML parser is a private dialect: anchors/aliases/merge corrupt structure, block scalars lose data, multi-doc merges, nothing ever refuses — prio:high

- **Measured (structure corruption):** `base: &b\n  x: 1\nderived:\n  <<: *b\n  y: 2\nalias: *b` → `{base: '&b', x: 1, derived: {'<<': '*b', y: 2}, alias: '*b'}` — the anchor token becomes a *string value*, the anchored map's content is hoisted to the top level, aliases and merge keys become literal strings.
- **Measured (silent data loss):** `msg: |\n  line1\n  line2` → `{msg: '|'}` — block-scalar content dropped entirely, the indicator kept as the value.
- **Measured (multi-doc):** `a: 1\n---\nb: 2` → `{a: 1, b: 2}` — two documents merged into one map. Spec: "YAML multi-document (`---`) → CX multi-document stream."
- **Measured (never refuses):** `a: [1, 2` (unterminated flow) → `{a: '[1, 2'}` RC=0 — and this fallback is *pinned* by fixture `yaml-022-flow-malformed-fallback`, while conversions.md §6.1 claims the YAML lane follows the strict-refusal rule. Spec and fixture contradict; the fixture is the executable truth.
- **Measured (dialect):** `on` → `true` but `NO` → string — lowercase-only YAML 1.1 booleans, which is neither 1.1 (case variants required) nor 1.2 (yes/no/on/off removed). `country: no` is `false`: the Norway problem, shipped. No spec states which YAML the parser implements.
- **Not broken:** plain nested maps/lists, flow style, quoting, `!!cx:T`/`!!binary` tags (lossless lane), and the parser round-trips *CX's own emissions* — canonical.md §6 emit style avoids everything above, and the fixture corpus (24 cases in `conformance/yaml.cxd`) covers exactly that self-consistent subset: zero cases for anchors, block scalars, tags-on-foreign-input, or multi-doc.
- **Hurts:** week one. Kubernetes manifests, docker-compose, CI configs, OpenAPI — anchors and block scalars are pervasive. Today they parse *successfully into wrong data*, the one posture §1 rules out.

### F11 — TOML native datetimes emit as quoted strings — prio:medium

- **Measured:** parse `dt = 2024-01-15T10:00:00Z` → CX datetime scalar (typed, correct); `--to=toml` re-emit → `dt = "2024-01-15T10:00:00Z"` — a TOML *string*, no longer a datetime to any TOML consumer.
- **Spec violated:** conversions.md §0.2 (TOML default for date/datetime: native "TOML date/datetime"); canonical.md §7 assumes datetime emission.
- **Also noted:** TOML local time (`07:32:00`) parses as string — CX has no time-of-day kind and conversions.md has no local-time row; that half is a spec gap, not a defect.
- **Hurts:** config round-trips: a `[tool]` file laundered through CX downgrades every timestamp's type; schema-validating consumers reject.

### F12 — `__cx_map__` internal representation leaks through `json:emit` — prio:high

- **Measured:** `[$json:emit [?for [in $i [$range 0 2]] [yield {id: $i}]]]` → `'{"":{"__cx_map__":[{"id":0},{"id":1},{"id":2}]}}'`. A directly-written sequence emits correctly (`[$json:emit ({a: 1}, {b: 2})]` → `'[{"a":1},{"b":2}]'`) — the leak is specific to comprehension results. The same internal name also surfaces in error messages ("first member [__cx_map__ …]").
- **Hurts:** the single most common ETL shape — *transform rows in a comprehension, emit JSON* — produces garbage wrapped in an empty-string key. Week one, every consumer.

### F13 — error taxonomy: five formats, four shapes, one lane — prio:medium

- **Measured, same convert surface:** JSON `error: E_JSON_DEPTH_EXCEEDED: max-depth 100` (CLI shows no CXER code, no position; in-program the code `cx-err:CXER3100` *is* present — the CLI strips it). TOML `error: cx-err:CXER0100 PARSE_ERROR: TOML — unterminated inline array…` (code, named class, no position). XML `error: 1:11: end tag mismatch…` (position, no code). YAML: never errors (F10). CSV `CXER1503 E_CSV_FIELD_COUNT_MISMATCH: row 2…` — code + named class + location, the model the others should follow.
- **Hurts:** programmatic error handling: a caller multiplexing formats cannot dispatch on error class without per-format string parsing.

### F14 — whole-document memory: ~112× (JSON) and ~50× (XML) input size; no streaming parse for any single large document — prio:medium, needs owner direction

- **Measured:** 18.1MB JSON array (300k records) → `--from=json --to=json`: **2.02GB peak RSS**, 3.3s. 15.4MB XML → 765MB peak, 1.6s. (`/usr/bin/time -l`.)
- **Streaming state:** `json:parse-stream` is NDJSON record streaming and matches its spec exactly (one complete value per element — measured). `streaming.md`'s 32-event API is not reachable from the in-program codec surface, and no XML/YAML/TOML streaming path exists at all.
- **Hurts:** the "documents larger than memory" requirement is simply unmet; at 112×, even documents much *smaller* than memory are a problem (200MB payload → ~22GB).

### F15 — `url:normalize` / `url:parse-whatwg` do not remove dot segments — prio:medium

- **Measured:** `[$url:normalize 'HTTPS://X.IO:443/../a/./b']` → `https://x.io/../a/./b` (scheme/host lowercased, default port stripped — but `/../` retained). `parse-whatwg` same.
- **Status:** url.md §4.3's canonicalization list indeed omits dot-segment removal — so `normalize` matches its own spec — but `parse-whatwg` is spec'd as "browser-exact behavior" and the WHATWG path parser removes dot segments; RFC 3986 §6.2.2 includes it in syntax-based normalization. `url:join` does resolve dot segments correctly (measured).
- **Hurts:** security decisions built on normalize (allowlists, cache keys, SSRF filters): `https://x.io/../admin` and `https://x.io/admin` do not compare equal after normalization. That is the classic path-traversal-filter bypass shape.

### F16 — the codec contract (codec.md §3/§4/§6) is not met by either side of the module split — prio:medium

- **§4 coverage table vs registry:** `html` and `url` are listed as codecs (mandatory ✅) but are absent from the codec registry: `cx --from=html` → `unknown source format: html` (RC=1); `[$convert '<div>hi</div>' :from html :to cx]` → same error. `md` *is* registered.
- **§3 mandatory verbs:** `url` and `html` lack `emit` (alias mandated: "`html:serialize`, `url:build` alias `html:emit`, `url:emit`"), `parse-bytes`, `emit-bytes`. Measured: `no callable "url:emit"`, `"html:emit"`, `"html:emit-bytes"`, `"html-parse-bytes"`. The std-lib specs (url.md/html.md/csv.md) omit these verbs — the std-lib specs and core codec.md contradict each other.
- **§4 optional row for xml:** "emit-with-opts (lossless `<cx:T>` typing)" — `[$xml:emit-with-opts …]` → `no callable`. Consequence: **the lossless XML image is unreachable in-program** — only the CLI `--lossless` flag can produce it; a CX program (the thing the platform runs) cannot. Same for JSON/YAML lossless emit.
- **Hurts:** the "one contract, every codec" pitch — the exact reason a uniform surface exists — fails on discovery: `[$<fmt>:emit …]` works for five formats and errors on two, per accident of module history.

### F17 — two CSV implementations are cross-wired under one module prefix — prio:high

- **Background (deliberate, spec'd):** the conversion lane (`--from=csv`) auto-types with column narrowing; the csv *module* never auto-types (conversions.md §8.2 "stream 16, L67 — deliberate"). Both normative. Fine.
- **Measured defect:** the module namespace is not closed — `[$csv:parse-bytes …]` (a verb csv.md does not define) silently resolves through flat-dispatch fallback to the *conversion-lane* native and returns `[table [table[zip]] 02134]` where `[$csv:parse]` returns `({zip: '02134'})` — different shape **and** different typing policy under one prefix. `[$csv:emit-bytes …]` likewise reaches `emit_delimited`.
- **Spec violated:** codec.md §6 "No format may have a second, parallel conversion implementation" is honored in the registry but defeated at the dispatch layer; conversions.md §8.2's "neither may silently adopt the other's default" is violated by exactly this fallback.
- **Hurts:** a caller who reads csv.md, uses the module, and reaches for the obvious `-bytes` variant gets leading-zero-mangling auto-typed tables with no signal anything changed.

### F18 — encoding policy: one spec rule, three behaviors — prio:medium

- **Spec:** conversions.md §0.4 — "Invalid UTF-8 in **any** input is a parse error (CXER0100)". UTF-16 rejected; UTF-8 BOM tolerated.
- **Measured:** XML with `encoding="ISO-8859-1"` and real latin-1 bytes → declaration ignored, raw 0xE9 flows through, output is invalid UTF-8, RC=0. Invalid UTF-8 in XML text → passes through byte-verbatim, RC=0. Invalid UTF-8 in JSON string → silently **replaced with U+FFFD**, RC=0. (UTF-16 BOM: rejected, though with the unhelpful `expected XML name`; UTF-8 BOM: tolerated — both per spec.)
- **Hurts:** mixed-encoding enterprise feeds (the norm, not the exception): mojibake or replacement characters propagate silently into stores and signatures instead of refusing at the boundary.

### Things that are fine — measured, and worth saying so

- **JSON strictness** (malformed/dup-key/depth/big-int refusals with real CXER codes and working opt-in modes) is at the §1 bar minus F9/F12.
- **CSV module** is the best surface in the audit: RFC 4180 edge cases (embedded newlines, quote doubling), the no-guessing default, dialect support, and errors that name the offending row.
- **The `--lossless` fail-loud rule** (toml/md rejected with the supported list, RC=2) works exactly as conversions.md §0.2 requires.
- **Billion-laughs and XXE are structurally absent** (limits.md §3 is honest): entities parse to nodes, nothing expands, nothing fetches. 10-level bomb: 30MB RSS, 0.02s. `SYSTEM` entity: preserved as declaration, never resolved.
- **XML namespace round-trip** (prefixed elements, `xmlns:*` preservation, CDATA) held in every probe; `resolve_namespaces` exists and fills expanded names as claimed.
- **HTML sanitizer** stripped every classic vector thrown at it (event handlers, `javascript:` in case/entity-obfuscated forms, `<svg><script>`, style URLs); the lenient parser handled misnesting and raw-text elements correctly.
- **MD codec** round-trips its pinned constructs (headings, emphasis, links, lists, fences) and emits `[table[…]]` blocks as GFM pipe tables per conversions.md §7.
- **url module** otherwise: RFC 3986 `join` resolution correct including protocol-relative; query-parse handles repeats/`+`/UTF-8.
- **The `cx` codec core** (`cx:hash`, `cx:canonical`, parse∘emit fixed point) behaved in every probe.
- **JSON/YAML `$tag` lossless envelope** round-trips its own emissions (measured through yaml), matching the conformance pinning.

---

## 4. The dedicated-vs-synthesized verdict

**The split is historical, not principled.** The comment at
[stdlib_bundle.v:453-455] states the actual rule: synthesized modules exist
for "text codecs that **lack** a dedicated stdlib module" — i.e., the split
records which formats had received engineering attention by mid-2026, nothing
more.

**The rule the codebase should follow.** Two orthogonal layers, both already
designed and both half-applied:

1. **The codec layer is core and uniform** — every format, dedicated or not,
   satisfies codec.md §3 (parse/parse-bytes/emit/emit-bytes + aliases) through
   the one registry. This layer is where `--from/--to`, `[$convert]`, and the
   4-verb module surface come from.
2. **A format earns a dedicated module** exactly when it has *format-intrinsic
   verbs beyond the codec contract* — policy (html sanitize), dialects (csv),
   query semantics (url), options/streaming (json). Verb richness is the
   criterion; "has a source file" is not.

**Measured against that rule:**

- `json`, `csv`, `url`, `html` are correctly dedicated (they all carry real
  extra verbs) — but each currently *breaks layer 1* (F16: registry absence,
  missing mandatory verbs/aliases).
- `yaml`, `toml`, `md` are correctly synthesized — parse/emit is the right
  surface — but lack the per-format normative page that would state dialect
  and loss (yaml's absence is how F10 stayed invisible: no spec says which
  YAML this is).
- **`xml` is on the wrong side.** For an XML-native language whose flagship
  enterprise consumers (SAML #1091, any signed-XML interop) need
  canonicalization, parse/emit options (entity policy, whitespace policy,
  lossless typing), and eventually streaming, four synthesized verbs with no
  opts surface is not a defensible resting point — today the lossless XML
  image is literally unreachable from a CX program (F16). XML needs either a
  dedicated module (spec + source + verbs) or, minimally, the
  `parse-with-opts`/`emit-with-opts` pair codec.md §3 already names.

**Migration cost.** Promoting `xml`: the name `cx-stdlib/xml` already
resolves (synthesized), so promotion is *not* a new frozen-surface name — but
codecs are deliberately core-not-stdlib (the comment at
[stdlib_bundle.v:443-455]), so giving xml a dedicated std-lib module crosses
the codec/stdlib boundary the current design drew on purpose. **That boundary
move is an owner ruling**, not an engineering call. The cheap alternative
(add `-with-opts` verbs to the synthesized surface for all five) stays inside
codec.md §3's existing optional list and needs no surface ruling — only specs
for the opts maps. Demoting any of the dedicated four is breaking at a major
boundary and nothing here motivates it.

---

## 5. Orthogonality findings

Both directions, per the mission:

**Capabilities duplicated per-format that should be one mechanism:**

1. **Parse guards** — depth limiting exists three times with three answers
   (cx 64, json 100, cxcol 64) and not at all in xml/yaml/toml (F3). limits.md
   already frames guards as a Ring-0 *surface* property; the mechanism should
   be one guard the registry applies to every codec parse.
2. **Error taxonomy** — per-format code families with per-format *shapes*
   (F13). CSV's `code + named-class + location` is the right shape; it should
   be the codec-contract shape, not a csv feature.
3. **Encoding validation** — conversions.md §0.4 states one rule; each parser
   hand-rolls its own (F18). One boundary validator in front of every text
   codec parse.
4. **Canonical emission** — canonical.md §11.1 already designs the single
   mechanism (a `canonical` flag on every emitter through the registry);
   implementation instead has per-format ad-hoc-ness: CX has real canonical,
   JSON has an insertion-order emitter that isn't the spec'd CXC-JSON, XML has
   nothing (F2).
5. **CSV typing policy** — two implementations by design, but the *dispatch*
   layer lets one leak into the other's namespace (F17). The shared mechanism
   should be: module namespaces are closed; natives not re-exported by a
   module are not reachable under its prefix.

**General capabilities buried inside one consumer:**

6. **Lossless emit is welded to the CLI.** The `lossless` flag exists in the
   registry signature (`emit fn (ParseResult, bool)`) but only `--lossless`
   can set it; no in-program verb passes it (F16). A registry capability is
   trapped inside one consumer — the exact inversion of codec.md §6's intent.
7. **The streaming event model is welded to the ABI/bindings.** streaming.md
   specifies 32 events; nothing on the codec or module surface can produce or
   consume them for any format (F14).
8. **`try_autotype` (the one shared typing mechanism) is bypassed** by the
   XML text path's early flush (F1's type-flip is the visible symptom) — the
   shared mechanism exists and the format hand-rolls around it.

---

## 6. Prioritized recommendations

**(i) Spec drift to close** (make the spec say what ships, or file the gap as
implementation debt — never silently "true" the spec to the shortfall):

1. canonical.md §§5–11 vs reality (F2) — **owner ruling required** (canonical
   identity). Either commit to implementing per-format canonical emission
   (C14N being the one with a named external consumer) or descope the
   sections to reserved status.
2. conversions.md §5.1/§6.1 vs the YAML parser and the yaml-022 fixture
   (F10): the spec claims resolution and strictness the fixtures pin the
   opposite of. The spec must state the actual (or intended) dialect.
3. conversions.md §2.1 "comments/PIs preserved" vs F7; §0.2 TOML datetime row
   vs F11; §0.4 encoding rule vs F18; json.md §4.4 vs F9.
4. codec.md §4 coverage table vs registry (F16) — html/url rows claim a
   surface that does not exist.

**(ii) Defects to fix** (fixture-first, no spec movement needed):

- F1 (garbage/truncation acceptance), F3 (segfaults — one shared guard), F4
  (attr normalization), F5 (entity decode + ENT-1 collision), F7 (inline
  comment/PI drop), F9 (float overflow), F11 (TOML datetime emit), F12
  (`__cx_map__` leak — likely the cheapest high-value fix in this audit), F17
  (close module namespaces), F18 (encoding boundary), F15 (dot-segments in
  whatwg lane at minimum).

**(iii) Capability gaps needing an owner ruling before work:**

- XML's side of the module split — promote to dedicated module vs extend the
  synthesized surface with opts (Section 4). Frozen-surface / codec-boundary
  implications.
- C14N / per-format canonical emission (same ruling as (i).1).
- The streaming story: is the 32-event model meant to reach the codec surface
  (XML/JSON streaming parse for >memory documents), or is NDJSON the ceiling?
  F14's numbers (112×) make this a product question, not a tuning question.
- F6 — whitespace ruling refinement for mixed content (W-6 is owner-ruled;
  only the owner can carve the mixed-content exception).
- YAML ambition: implement YAML 1.2 core (large) vs normatively subset it and
  *refuse* what is outside the subset (small, honest, my recommendation as
  the interim state — silent wrong data is the only unacceptable option).

**(iv) Fine as they are — explicitly:**

- The codec registry architecture itself (one table, overlay, CLI/ABI/module
  routed through it) — the design is right; the findings are gaps in
  honoring it, not in it.
- CSV module semantics and the deliberate module-vs-conversion-lane typing
  split (both specified; keep both).
- JSON strict-parse posture including big-int refusal + opt-in modes.
- Entity non-expansion (billion-laughs immunity) — a *better* posture than
  standard XML processors; keep, and document as the entity policy.
- `--lossless` fail-loud rejection; html sanitizer; md codec scope (ruling
  D-B); url module apart from F15; `cx` pivot codec.
- The frozen-surface discipline itself — nothing here argues for removing
  any module.

---

## 7. Issues filed

| # | Finding | Labels |
|---|---|---|
| #1105 | F1 XML garbage/truncation acceptance | bug, area:cx-lang, prio:high |
| #1106 | F3 codec parser segfaults / shared depth guard | bug, area:cx-lang, prio:high |
| #1107 | F4+F5 XML entity/char-ref fidelity (attrs + text + ENT-1 collision) | bug, area:cx-lang, prio:high |
| #1108 | F7 inline comment/PI drop | bug, area:cx-lang, prio:medium |
| #1109 | F8 mark_ref_attrs over-promotion | bug, area:cx-lang, prio:medium |
| #1110 | F2 canonical emission spec drift / C14N (owner ruling) | design, area:cx-lang, prio:high |
| #1111 | F10 YAML dialect (owner ruling on ambition; spec-vs-fixture conflict) | bug, area:cx-lang, prio:high |
| #1112 | F11 TOML datetime emit | bug, area:cx-lang, prio:medium |
| #1113 | F9 JSON float overflow → +inf.0 | bug, area:cx-lang, prio:medium |
| #1114 | F12 `__cx_map__` leak | bug, area:cx-lang, prio:high |
| #1115 | F16 codec contract conformance (registry + verbs + in-program lossless) | design, area:cx-stdlib, prio:medium |
| #1116 | F17 module namespace closure (csv cross-wiring) | bug, area:cx-lang, prio:high |
| #1117 | F18 encoding boundary policy | bug, area:cx-lang, prio:medium |
| #1118 | F15 url dot-segment normalization | bug, area:cx-stdlib, prio:medium |
| #1119 | F14 streaming/memory posture (owner direction) | design, area:cx-lang, prio:medium |
| #1120 | F13 error taxonomy unification | design, area:cx-lang, prio:medium |
| #1121 | §4 xml module promotion vs opts extension (owner ruling) | design, area:cx-stdlib, prio:medium |
| #1122 | F6 whitespace ruling refinement for mixed content (owner ruling) | design, area:cx-lang, prio:medium |

(All filed 2026-08-30 with full repro bodies; numbers verified against the
tracker. #1104 pre-existed and is cross-referenced from #1107.)
