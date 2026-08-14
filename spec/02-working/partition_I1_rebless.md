# I1 identity epoch — deliberate-red ledger + re-bless obligations

**Status: THE EPOCH IS CLOSED** (2026-08-06, commit ef80e409 — THE
RE-BLESS). All 16 manifest rows landed; the spec-edit maps executed; the
one coordinated re-bless regenerated every ledgered red class; the
registry re-sealed; eval gate ZERO enforced, conform FULLY green, full
suite green, differential at its final baseline. The deliberate-red
table below is DISCHARGED — from this commit forward, ANY red is a
plain regression. **OWNER RULINGS 2026-08-06: (1) the re-bless review
is APPROVED (mapping file + corpus diff accepted, ruling 2a
discharged); (2) entry-25 schema-mode ruled (a) — the directive strip
stands at I1; mode-in-identity is resolved BEFORE I5's type-binding
anchoring (either content-bearing-directive preservation under its own
ruling, or schema-of/schema-mode moving into schema-document body
data). The residual stays test-pinned
(test_mode_does_not_survive_canonical_text_named_residual).** This file remains the epoch's
historical record (entries 1-34, plus the post-epoch entries 35-36).

*(Original mid-epoch charter, kept for the record:)* live working
ledger on `impl/I1-identity-epoch`. Every entry is a fixture class that
is RED ON PURPOSE mid-epoch (its pinned bytes moved by a manifest row)
plus the obligations the final coordinated re-bless must discharge.

## Red classes (verified intended, per triage)

| Class | Cause (manifest row) | Re-bless action |
|---|---|---|
| `identity_hash.cxd` singles idh-001…005 | W-14 LF (row 2) — every Tier-1 digest moved | re-bless digests; record old→new in the mapping file |
| ~~`operator_heads.cxd` oph-001…005 digests~~ | ~~W-14 LF now; row 8 will move them AGAIN (stringify → element)~~ | RETIRED at entry 27 — row 8 landed and this class re-blessed with it (10/10 green; the flip-at-row-8 instruction below discharged) |
| `journal.cxd` ×27 + `sched.cxd` sched-022 | chain preimages ride canonical bytes (rows 2/10-12) | re-bless chains after the ts-form (#712) + detached-payload (#720) land, not before |
| `store.cxd` ×6 (address literals) | store keys are Tier-1 canonical addresses | re-bless literals |
| `xap-dist.cxd` ×4 (pinned tree/manifest hashes) | package tree hashes are Tier-1 | **re-seal the committed `registry/`** (gtin@0.1.0 re-publishes under epoch bytes) + re-pin fixtures + `xap_registry_serve_real_test.v` consts |
| `bus.cxd` bus-026 (hardcoded doc address) | store put-doc address moved | re-bless the literal |
| `cx.cxd` ×8 incl. cx-010 | address literals + the serialize-vs-canonical LF seam | re-bless literals; **cx-010 fixture-semantics note:** `cx:serialize` is the FRAGMENT emitter (LF-less), `cx:canonical` is a complete POSIX text file (W-14) — the fixture's equality re-forms as `serialize + "\n" ≡ canonical` |
| `extended.cxd` ext-038 + ext-039 | L15/L17 (row 2): quoted canonical text escapes control bytes; triquote never emitted (body + AttValue pins) | re-bless both to the escaped single-quoted spelling |
| `code.cxd` program-string-triplequote-001/003 | L15 render-lane escapes (render_canonical is identity-bearing — store put-doc rides it) | re-bless rendered spellings |
| stdlib multiline-render pins ×18: `csv.cxd` ×11 (csv-008, 025–031, 033/034/037) + `json.cxd` 026–028 + `format.cxd` 009/010/012 + `cx.cxd` cx-060 | fixture results are multiline STRINGS; their rendered spelling now carries §2.4 `\n` escapes (values unchanged) | re-pin expected blocks to the escaped spelling |
| `conversions.cxd` conv-006 | row 1 L43: a decimal MAP VALUE now carries its postfix ascription (`score: 3.14::decimal`) — the pre-epoch bare spelling silently re-imported as FLOAT (the defect stream 11 names) | re-pin to the ascribed spelling |
| `code.cxd` program-cast-unknown-kind | row 1 L44: the cast error hint now lists `:decimal`/`:bigint` in the supported-kind set | re-pin the message |
| THE 2b WAVE (row 1, autotype flip): `identity_hash.cxd` idh-022 + idh-023 (THE pinned flip — attr scale now identity; bare −0.0 is a decimal and normalizes) · `extended.cxd` 003/016j/021/029/036 · `xml.cxd` 027 · `table.cxd` tab-007/tab-019 · `ast_bin.cxd` astb-003 · `yaml.cxd` 018 · `data_bin_arrow.cxd` arrow-002/013 · `math.cxd` ×39 · `random.cxd` ×23 · `prof.cxd` ×2 · `env.cxd` ×1 · `code.cxd` ×5 more (cast-truncate + typed-attr-float reads) | bare fixed-point fractions are DECIMALS (exact results replace float artifacts: 0.1+0.2 = 0.3); floats spell exponent-always (1.5 → 1.5e0 in ::float columns); stdlib ::float-typed params + transcendental inputs need exponent spellings | re-bless: exact results, exponent float spellings, re-spelled fixture inputs |

## Pins that FLIP at specific rows (stay red until that row, then re-bless)

- `idh-023` (decimal scale) → row 1 (L40 scale-preserving identity)
- ~~`idh-026` ($x vs '$x') + `cx-094` (quote-hash E210) → row 9~~ FLIPPED + re-blessed at entry 28
- ~~`oph-001…007` semantic flips → row 8~~ FLIPPED + re-blessed at entry 27
- ~~`store-code-003…006` (Tier-2 collisions) → row 13~~ FLIPPED + re-blessed at entry 31
- data-bin decimal/bigint goldens → rows 1+16 (0x18/0x28); ch-008…011 must stay
  BYTE-IDENTICAL (proven-untouched kinds) — if they move, that is a REGRESSION

## Mapping file

`spec/02-working/partition_I1_hash_mapping.md` (authored at re-bless): one row
per moved artifact class with a representative old→new digest pair per row,
plus the full corpus diff as the exhaustive record (the re-bless commit).

## Epoch commits so far

1. W-14 trailing-LF-in-hash (row 2) — every digest +1 byte coverage.
2. W-7/L20 UTC-Z datetime normalization (row 2) — instant identity.
3. Datetime/date typing precedes the float arm (row 2 companion) — fractional
   temporals type correctly everywhere; closes the quoted-attr residual.
4. W-19/L24 duplicate attrs incl. xmlns = parse error `cx-err:E214` (row 2) —
   parse gate green, no corpus reliance. SPEC-EDIT OBLIGATION: E214 row into
   cxdm.md's error table (rides the epoch's spec-edit-map execution).
5. Redundant-annotation strip (row 2) — element-level `::T` clears in a
   canonicalize pass (canonical_annotation.v, after datetimes) when bare
   re-typing of the body image reproduces the value; mirrors the attr lane
   (cx_attr_scalar, D3), which is now LOCKED by the same fixture file.
   Kept: sized/decimal/bigint/duration/period, `::T[]`, empty bodies.
   Eval gate unchanged at the same 47 ledgered reds (zero new).
6. Quote-lane rulings L15+L16+L17 (row 2, W-12/W-13/W-2): §2.4 escapes are
   EMITTED (LF/CR/tab → `\n \r \t`, other C0 → `\u00xx` lowercase, DEL →
   `\u007f`); both-quotes tiebreak = single-quoted `\'` in BOTH lanes
   (cx_choose_quote_render now aliases cx_choose_quote); canonical NEVER
   emits triquote — the verbatim-triquote body and AttValue branches are
   gone; raw control bytes force quoting (cx_has_control_byte). Bijection
   rule untouched (`'\d'` does not churn). New intended reds ledgered
   above (ext-038/039, code triquote ×2, stdlib multiline renders ×18);
   eval gate = those + the prior 47, zero unexplained.
7. Tier-A mechanicals W-1/W-5/W-6/W-10 (row 2): `#id` on an otherwise-
   empty element survives emit (`[a #x1]` → `[a #id-1]`); RawText is
   CONTENT — preserved in strict canonical (`[a [#raw#]]` ≢ `[a]`); the
   EMPTY string is a value — `[a '']` emits `''` (needs-quote covers the
   empty image; whitespace-only NON-empty runs still drop as XML-import
   layout); leading BOM consumed at new_parser, mid-content BOM in bare
   text = CXER0100, BOM inside quoted values stays content (L23 verbatim
   values). Companion fix W-6 exposed: the lossless JSON/YAML envelope
   dropped empty-string children (envelope_child_ll) — now crosses the
   wire. `[n::string '']` strips its annotation again (body survives).
   Zero corpus movers (W-28 coverage gap — pinned by V fixtures in
   canonical_mechanical_warts_test.v instead); gates at the same
   ledgered reds. NOTE (residual, unruled): whitespace-only NON-empty
   quoted strings (`[a ' ']`) still erase — same collision shape as W-6
   but entangled with XML-import layout text; needs its own ruling.
8. Multi-doc addresses L30 (row 2, W-27): a legal multi-document CX file
   HAS a canonical form and an address — per-document strict-canonical
   fragments joined by the bare `\n---\n` line, one file-level trailing
   LF (W-14). cx_text_canonical rides parse_stream (single-doc bytes
   unchanged — same lexer, `---` only at top level); the per-document
   pipeline is extracted as cx_canonical_doc_text, the single source of
   pass order. §3.12.2 alignment: cx_data_bin_hash had DRIFTED (missing
   datetime + annotation passes and the W-14 LF) — it now composes the
   same helper, so data-bin and text lanes hash one logical document
   identically (its digests were never pinned — invariance-only use).
   Zero corpus movers; gates at the same ledgered reds.
9. CX-owned Ryū L18 (row 2, W-14-float) + W-3: float bytes are Ring-0-
   owned — ryu_f64.v vendors the shortest-digits core + pow5 tables from
   the pinned V fork's strconv (MIT; FROZEN — never re-sync without an
   identity migration) and renders §2.5 exactly: mandatory decimal
   point, sci only when STRICTLY shorter (tie → fixed: `0.0001`),
   `1.0e10` mantissa-dot form, bare lowercase exponent (`1.0e-7`, was
   V's `1e-07`), `-0.0` distinct, subnormals exact. Spellings converge:
   `1e10` ≡ `1.0e10` ≡ `10000000000.0` (one address). W-3: non-finite
   floats have NO canonical form — reject_nonfinite_floats errors the
   canonical/hash lane (§1.3), and `::float` coercion of an overflowing
   literal fails loud at parse (CXER0109). Zero corpus movers (corpus
   floats are all simple fixed forms); float-form pins live in
   canonical_float_test.v.
10. Whitespace-only strings are VALUES (W-6 companion, owner-ruled (a)
   2026-08-05): `[a ' ']` survives quoted — the emit-side whitespace
   skip is gone; XML LAYOUT whitespace now strips at IMPORT
   (xml_parser.v text flush), which is where layout exists. The
   lossless envelope forwards every string child. One carve-out: a
   single-space TextNode BETWEEN two siblings is the parser's
   reconstructed join space (`[p &amp; &lt;]` round-trips it) — the
   bare spelling is canonical; multi-space between siblings quotes.
   `[n::string '  ']` strips its ascription (every string body carries
   its own type now). Zero corpus movers after the join-space rule
   (core-013/xml-009 entity fixtures pin the bare spelling and stay
   green); gates at the same ledgered reds.
11. Unicode names L22 (W-9) + UTF-8 validity (L23 first half): both
   engines widen to the grammar's [L10a]/[L10b] ranges IN STEP (data
   lex_name + element-vs-array disambiguator; program-lexer ident
   dispatch + continuation; xml_read_name — CX⇄XML stays bijective).
   The codepoint predicates + UTF-8 decoder live in lexical.v — the
   ranges are the grammar's own, no Unicode database involved. The
   data parse entries (parse / parse_stream) validate UTF-8 up front:
   truncation, bad continuation, overlongs, encoded surrogates, and
   >U+10FFFF all refuse (CXER0100), so no invalid byte can reach a
   name, value, or the canonical byte stream. Non-name codepoints
   (`[© 1]`) keep routing to the array/text lane. Differential
   unchanged (both engines moved together; namechar fork green).
   OPEN half: NFC normalization of names (L23 second half) — BLOCKED
   on the UCD source files (owner asked a/b on downloading them);
   until it lands, NFC-vs-NFD spellings of one name are two names.
   MUST land before the re-bless.

12. Row-1 invariant slice (stream 11, L39/L43/L45/L47): postfix value
   ascription `value::T` in collection positions — map values, sequence/
   array items, AND map keys (`{1.10::decimal: x}`; read_map_key keeps a
   glued `::` in the key token). Typed carriers are STRICT (defect G):
   decimal = fixed-point base-10 only (exponent form is scale-ambiguous
   → CXER0109), bigint = base-10 integer, duration/period validate via
   temporal_span_kind. §6 normalization at coerce: `+`/redundant leading
   zeros strip, `.5` → `0.5`, negative zero → positive with scale kept,
   trailing fraction zeros PRESERVED. Emit: decimal collection values/
   keys always carry the postfix ascription; bigint carries it exactly
   when ≤ i64 (annotation-iff-retyping, both attr + element lanes).
   Ascribed non-key kinds reject as map keys. One corpus mover ledgered
   (conv-006). OWNER RULINGS RECORDED: 2b — bare fixed-point fractions
   become DECIMAL at I1 (floats = exponent form / ::float; float
   canonical amends to exponent-always); 1a — I download the UCD files.
   SEQUENCING: the 2b autotype flip lands WITH/AFTER decimal arithmetic
   (evaluator still rejects decimal math — flipping first would break
   every fraction computation). Remaining row-1 commits: value
   semantics (equality/ordering), arithmetic+casts (L44, CXER3002
   division), the 2b flip + idh-023, data-bin 0x18/0x28 (row 16) +
   ast-bin widening + M23 advisory window, json all-decimal/streaming/
   --strict/host mappings. Table CELLS with decimal columns still ride
   lenient coerce_scalar — normalize at the arithmetic commit.
13. Row-1 value semantics (L40/L42): equality and ordering are
   MATHEMATICAL across the exact family int/bigint/decimal — pure digit
   comparison (cx/numeric_exact.v: cx_exact_num_cmp on the base-10
   images; no f64 round-trip, so bigint ordering is exact beyond 2^53
   and decimal scale digits never merge). `bigint 99 = int 99` and
   `1.10::decimal = 1.1::decimal` are now true; decimal/bigint vs
   STRING is ALWAYS false (the string arm said decimal "1.10" = string
   "1.10"); decimal vs FLOAT stays unbridged — equality false,
   ordering CXER0100 (L44: [cast] is the only bridge). nodes_equal +
   the `<`-family both gained the exact branch; int×int keeps its
   legacy path byte-for-byte. Pinned in
   decimal_bigint_semantics_test.v; zero corpus movers, gates at the
   ledgered reds.
14. Row-1 exact arithmetic + casts (L44): `+ − × ÷` route through Ring-0
   digit arithmetic (numeric_exact.v: schoolbook add/sub/mul, big÷big
   long division) whenever any operand is decimal/bigint — scale rules
   max(s₁,s₂) for +/−, s₁+s₂ for × (trailing zeros preserved: 1.10−0.2
   = 0.90); ÷ computes the EXACT quotient when it terminates (2·5-only
   reduced denominator) and errors CXER3002 otherwise (a rounding
   context is the only path to non-terminating division); div-by-zero
   stays CXER0101; decimal⊕float = CXER0100 (unbridged); result kind =
   decimal if any decimal operand or fractional result, else bigint
   (bigint⊕int→bigint). mod/div/idiv builtins still reject the exact
   family (unruled — unchanged). [cast] gains :decimal (string strict,
   int/bigint embed, float → Ryū shortest digits as fixed-point via
   cx_decimal_image_from_float) and :bigint (string strict, decimal
   integral-only); decimal→int integral-only; decimal→float lossy-
   allowed rides the existing string arm. One corpus mover ledgered
   (program-cast-unknown-kind: the supported-kind hint grew).
   REMAINING row-1: the 2b autotype flip + idh-023 + float-canonical-
   exponent-always; data-bin 0x18/0x28 (row 16) + ast-bin + M23
   advisory window; json all-decimal / streaming / --strict / host
   mappings; table-cell decimal normalization.
15. THE 2b FLIP (row 1): bare fixed-point fractions are DECIMALS in
   BOTH engines (try_autotype + try_autotype_bytes; program lexer's new
   decimal_lit — differential HELD); exponent form / ::float = float;
   float canonical is EXPONENT-ALWAYS incl. zeros (0.0e0 / -0.0e0) so
   the kinds are lexically self-describing — one spelling, one kind,
   one address. decimal/bigint join annotation-iff-retyping in all
   three lanes (attr / element / collection — [a::decimal 1.50] sheds
   its ascription, {p: 19.99} is a decimal map value bare). Evaluator
   companions: EBV decimal/bigint zero falsy; abs keeps kind+scale,
   floor/ceiling/round exact (int-if-fits else bigint); scalar_f64
   config readers (thresholds/ranges) accept exact-family images;
   assert-near reads decimals; the program render emits decimal BARE
   (quoting flipped the kind). idh-023 fires exactly as pinned; the
   wave is ledgered above (≈75 new intended movers). RESIDUAL (named):
   transcendentals on decimal reject with the generic CXER0100
   signature message — the promised CXER3002-specific code rides the
   math re-bless commit.
16. Row 16 (L46): data-bin wire tags 0x18 (bigint) / 0x28 (decimal) —
   the kinds ride the wire as length-prefixed base-10 images and are
   NEVER erased (narrowing-within-kind: an in-i64 bigint encodes 0x18,
   not 0x13). Kind-aware projection (scalar_node_to_dataval /
   attr_to_dataval replace the value-only lane at the four ScalarNode/
   Attribute sites); decode restores the head ascription on scalar
   bodies (the annotation-strip pass sheds it when redundant — the
   existing fixpoint). ast-bin's table-cell kind set widens to include
   decimal/bigint (images ride the string cell slot; the COLUMN type
   carries the kind — full columnar fidelity is I5's lattice, the M23
   advisory window as declared). cx_data_bin_hash now agrees with
   cx_text_hash for decimal/bigint-bearing docs. ch-008…011 stayed
   BYTE-IDENTICAL (the proven-untouched-kinds regression guard held).
   Zero new corpus movers beyond the ledgered 2b wave.

17. NFC names (row 2, L23 second half — ROW 2 COMPLETE): names
   normalize to Unicode NFC at parse in ALL THREE name lanes (data
   intern_name_src, xml_read_name, program read_identifier — in step,
   differential held); values NEVER normalize (NFD string values keep
   their bytes and their distinct addresses). W-11: duplicate-map-key
   comparison is NFC for string keys (stored keys keep authored bytes).
   CX-OWNED tables generated from the PINNED UCD 16.0.0 (committed
   sources at tools/ucd/16.0.0/ with sha256s; committed generator
   tools/gen_nfc_tables.v → nfc_tables.v: 934 ccc / 2081 decomp / 961
   comp pairs); Hangul algorithmic (UAX #15). Regenerating against a
   newer UCD = an owner-ruled identity migration, like re-syncing Ryū.
   ASCII names ride a zero-cost fast path. Pinned in
   canonical_nfc_names_test.v (composition, Hangul LV/LVT, canonical
   reordering, composition exclusions, name-vs-value split, dup-keys,
   idempotence); commit-11's NFD placeholder pin re-blessed to the
   convergence. Zero new corpus movers; gates at the ledgered reds.

18. Row-1 defect tail (stream 11 defect batch, #703): json
   `all-decimal` is GENUINELY exact (cx_decimal_image_from_json_number
   — JSON digits become a fixed-point decimal, no f64; the 17-digit
   probe passes); streaming events emit decimal as a QUOTED string in
   the JSON lane exactly like the batch emitter (defect B) and bigint
   joins the known-scalar sets (events + validate §4.5);
   value_matches_type's bigint/decimal predicates were UNSATISFIABLE
   (checked i64/f64 on string-stored kinds — defect A) and now match
   on the KIND; the lenient coerce_scalar decimal/bigint arms (table
   cells, importers) normalize when the token conforms (verbatim
   fallback keeps them infallible); transcendentals over the exact
   family refuse with their OWN code — CXER3002 with the
   [cast … :float] hint (math.md §4.4) at the $-call terminals. Host-
   mapping corrections (L48) are SPEC EDITS — they ride the spec-edit
   map. Census unchanged at the ledgered reds; ROWS 1 AND 16 ARE
   COMPLETE.

19. Row 3 core (stream 19, L31/L32/L35/L38): SELF-DESCRIBING addresses
   — cx_text_hash / cx_text_hash_algo / cx_data_bin_hash return
   `<multiformats-name>:<hex>` (sha2-256 default; the ONE registry in
   hash_registry.v with codes/lengths/status); legacy `sha256`/`b3`
   spellings fail loud (no dual-accept); bare hex REJECTED
   (cx_parse_tagged_address, CXER0130-32); varint multihash bijection
   (encode/decode, sha2-256=0x12 0x20…); Tier-2 composes
   `code:sha2-256:<hex>` (namespace outermost); journal migrates to
   registry names + the algo-neutral `genesis:` sentinel (L38);
   store keys ride the tagged form automatically (put-doc =
   cx_text_hash). Journal red class extends by 3 (spelling movers,
   same re-bless class); canonical battery 8/8, identity lanes
   unchanged. Shape validators migrated: store_is_doc_hash +
   grpc_list_hashes ride cx_parse_tagged_address (the gRPC store plane
   round-trips tagged addresses end-to-end); the service secret-hash
   accepts `sha2-256:` only. V-test len-64 pins re-blessed to the
   73-char tagged form. REMAINING row 3: verifier fail-closed sweeps
   (#702 — VC type=, pkg-verify registry lookup), SRI registry
   unification, XSP-AUTH suite field + HKDF /2/ bump, provenance
   suite slot, pack u16 + data-bin 0x13.

20. Row-3 tail (L35/L36/#702): the signature-suite registry lands
   (suite_registry.v: ed25519 required+implemented; ecdsa-p256/rsa-2048
   optional; ml-dsa-44/65/87, slh-dsa-128s, ed25519+ml-dsa-65 RESERVED)
   with cx_suite_verify_gate as the fail-closed gate — journal
   snapshot verification validates sig-algo (was ed25519-assumed), VC
   verify READS the proof type (W3C Ed25519Signature2020 maps to the
   registry key; unknown → 'unsupported-suite'), pkg-verify is a
   registry lookup (was hardcoded equality). SRI unified against the
   registry: the module loader accepts sha256/sha384/sha512/blake3
   exactly like the stdlib lane. XSP-AUTH HKDF labels bump
   xsp-auth/1/* → /2/* (the label IS the version handle; the suite
   field changes what it covers). The provenance suite slot is an ATOM
   (alg=:ed25519 — type-strict, closed-vocabulary). Census exactly at
   the ledgered reds. REMAINING row 3: pack u16 multicodec slot +
   data-bin 0x13 multihash schema-ref (additive binary slots).

21. Row-3 binary slots (L34 — ROW 3 COMPLETE): the .cxpack entry's
   formerly-reserved u16 (entry offset 6) is the multicodec code of the
   algorithm naming the 32-byte doc_hash slot (sha2-256 = 0x0012;
   pack.v pack_hash_mh_code, pinned against THE ONE registry by
   pack_multicodec_test.v). Readers FAIL CLOSED at open on any other
   code — including the pre-epoch zero and registered-but-unimplemented
   algos (blake3) — for both v1 self-verifying and v2 keyed packs; all
   1.0 algos are 32-byte, non-32-byte digests require pack v3. The
   committed registry packs (registry/store/store-000{0..3}.cxpack, 26
   entries) were STAMPED IN PLACE 0→0x12: the slot is covered by no CRC
   (entry CRC covers stored payload bytes only), so no hash, CRC, or
   signature moved — the re-seal at re-bless rewrites them wholesale
   anyway. data-bin schema-ref gains the ADDITIVE 0x13 multihash form
   (uvarint code ‖ uvarint len ‖ digest; 0x10/0x11/0x12 unchanged):
   SchemaRefForm.multihash in encoder/decoder/cabi (ref_form=3) +
   conformance runner; decode fails closed on unregistered codes
   (D005/CXER0131), registry-length contradictions (D005/CXER0132), and
   non-sha2-256 algos it cannot recompute. Fixtures sd-010..012 (new,
   green); cxparse differential baseline moved deliberately 706→707
   (sd-010's in-cx row, agree +1, diverge held 18). Census exactly at
   the ledgered reds (7 code.cxd + 133 stdlib). NOTE:
   xap_registry_serve_real_test.v is red as part of the ledgered
   xap-dist class (manifest addresses moved at commit 19; consts flip
   at the registry re-seal) — the stamped packs OPEN cleanly (failure
   is the address miss, not a pack refusal). SPEC-EDIT OBLIGATION:
   data-bin.md §3.13.1 gains the 0x13 row; the pack-entry hash_code
   field row rides store.md/pack-format alignment (docs-src
   pack_format.md already updated in-commit).

22. Row-4 part 1 — L55 registry-repair renames (stream 13): the
   vocabulary's only non-kebab multi-word names are gone —
   `takewhile`/`dropwhile` → `take-while`/`drop-while` in all spelling
   lanes (program parser + emitter + program-XML both directions +
   ast-json atoms + error hints + LSP diagnostic; internal V enum kinds
   keep their names); the OLD spellings stay in for_clause_keywords and
   TOMBSTONE-ERROR loudly ("renamed — spell it [take-while …]") because
   bare removal would silently re-read `[takewhile P]` as a
   pattern-generator (a meaning change). `[?chain]` — the registry's
   ONLY alias (of `[?concat]`) — is RETIRED: dropped from
   program_tokens.v directive_names (79→78; head now parse-errors
   CXER0100 unknown-directive), eval dispatch, the code.md §4.1 row,
   grammar.ebnf [127e], governance.md's combinator list, and the
   directive-doc source (directive-docs gate GREEN at 78/78).
   grammar.ebnf [129m]/[129n] respelled with a retired-spellings note.
   BECAUSE THE GATES COUPLE THEM, these spec edits landed in-commit
   (the general stream-13 spec-edit map still rides the epoch tail).
   Fixtures: code.cxd spellings migrated (case IDs kept); chain-001
   flipped to a retirement negative; take-while/drop-while retirement
   negatives added (both green); the three parse-negatives joined
   code_parse_fixtures_test.v's expected_parse_failures. Tooling:
   tmLanguage (canonical + synced copy) + tree-sitter grammar.js with
   regenerated ABI-14 src/parser.c + cx.dylib (17/17 corpus green;
   tree-sitter-cx.wasm intentionally NOT rebuilt — the pinned
   toolchain's wasm lane re-generates at ABI 15; it lags until the
   epoch tooling pass, per the Makefile's own note). Census: eval gate
   exactly 7 + 133; conform at the ledgered reds; differential HELD
   (707/560/18 — in-code rows don't feed the data differential).
   Docs obligation: docs/guide regeneration picks up the renames at
   the post-re-bless re-record (directives.html still shows chain
   until then); playground note re-worded at source.

23. Row-4 part 2 (L57/L58 — ROW 4 COMPLETE): `r'''…'''` / `r"""…"""`
   RAW strings are legal in DATA mode (one token grammar): the token
   cursor classifies an `r` GLUED to a triple quote as .triple_span,
   and one raw-aware reader (at_raw_triple / read_raw_triple_str,
   riding the ONE shared scanner scan_triple_quoted_opt) serves every
   value position — doc scalar, element body, self-delimiting items,
   attr value (both read_attr_value lanes), collection/slot items,
   table cells. Raw = verbatim (no dedent); canonical NEVER re-emits
   triquote (L15/L17), so it is an input spelling only; bare `r` stays
   text; map keys take no triple form (parity with plain triquote).
   [2a] is a PINS row — the impl was ALREADY line-start-only for the
   `---` separator; ext-055 pins it. CXER0290 UNIFICATION (L57): the
   annotation-coercion error class ("token cannot coerce to ascribed
   T" — [55] attr AND [L25d] body, both engines, incl. the #466
   hex-under-decimal/bigint rows, #457 hex overflow rows, atom-name
   rejections, temporal-span mismatches, ::float overflow, and row-1's
   strict decimal/bigint carrier rejections) mints CXER0290
   (E_CAST_FAILED — the same code as a failed [cast]), retiring
   [55]'s CXER0109 citation (grammar.ebnf [55] + lexicon [L25d] hex
   sentence edited in-commit — gate-coupled like entry 22). CXER0109's
   remaining owners: E_SCOPE_NOT_MAP ([?with-scope], unchanged) and
   canonical_float.v's non-finite-no-canonical-form rejection (W-3,
   entry 9) — a TWO-OWNER RESIDUAL for the spec-edit map / G18 pass
   to re-code or ratify. Fixtures: ext 050-054 (raw-triple family) +
   ext-055 ([2a] witness) NEW and green; 12 CXER0109 pins re-pinned to
   CXER0290 (ext 016-family ×5, code.cxd #457/#466 families ×7; the
   with-scope 0109 pin untouched). Differential moved deliberately
   707→713 (agree +5 raw-triple rows — both engines through the one
   scanner; cx_only +1 bare-text witness; diverge held 18). Census
   exactly 7 + 133. SPEC-EDIT OBLIGATIONS (map): code.md §2.4/string
   sections gain the r-triple data-mode sentence; [L62] sigil-table
   completion + `|` tombstone; the remaining stream-13 repair batch
   (G-1..G-8, [59a] deletion, ModulePrefix opening, reserved-attr
   closure, MIME/extension registry) is SPEC-ONLY and rides the map.

24. Row 5 (stream 15, L50/L51/L52 + #704 — ROW 5 COMPLETE): the CX
   namespace URI is the RFC 4151 tag URI `tag:cxhome.org,2026:ns/cx`
   (namespaces.v cx_namespace_uri + go/python/rust binding constants +
   archived bindings + docs-src table + examples/chapter.cx's doc ns
   migrated to the same scheme); both legacy https spellings are
   RESERVED aliases recognized only to reject. ENFORCEMENT moves from
   literal prefix to RESOLVED URI (#704 was fail-open): binding any
   prefix or the default namespace to the CX URI in ANY spelling =
   E213, and the reserved `cx` prefix may not be re-bound —
   validate_reserved_ns_bindings runs at the tail of EVERY parse entry
   (CX ×2, XML, AST-JSON, ast_bin, MD), and the program reading
   enforces the SAME rule at the element-literal lane
   (eval_construction_attrs → cx_check_reserved_ns_attrs, the one
   shared core; the differential CAUGHT the program-lane gap before
   the fix — both_reject +5 proves the two readings agree).
   Dynamically-built elements are caught at the text/identity boundary
   (cx_text_hash re-parses). ONE carve-out: `xmlns:cx="<tag URI>"` —
   the C14N carrier declaration the XML image mandates on its root —
   is accepted, and strict canonical STRIPS it
   (canonicalize_element_ns), so declared/undeclared spellings share
   one address. #704's canonical∘canonical non-idempotence dies with
   the E213 rejection. Fixtures ns-017..023 (5 × E213 negatives incl.
   both legacy spellings + default-ns + cx-rebind; carrier-decl
   strip; namespaced idempotence pin) — namespaces.cxd 23/23 GREEN
   (zero red: the corpus was already domain-free, so the URI flip
   moved no pinned digest). Gate-coupled spec edits in-commit: cxdm
   §3.4 row, ast.md, grammar.ebnf §namespace (URI + legacy + carve-out
   language), parser-rules :11/:22, canonical.md §2.7a strip row.
   Differential moved deliberately 713→720 (both_reject +5, cx_only +2
   — the positives carry prefixed child names the program reading has
   always rejected; diverge held 18). Census exactly 7 + 133. L52's
   permanence inventory is prose for cx_partition.md §8 — rides the
   spec-edit map.

25. Row 6 (stream 1, E2/L82 — ROW 6 COMPLETE): the schema content-hash
   basis is the strict CANONICAL TEXT bytes — schema_content_hash =
   sha256(cx_text_canonical(schema_text)), so a schema's identity IS
   its Tier-1 document identity (pinned: the 32 raw bytes in the
   0x10/0x12 slots equal the digest inside the schema's tagged
   address; schema_hash_basis_test.v). The former CXCol-encoding basis
   and the #724 framing ambiguity die together. ZERO corpus movers:
   the sd fixtures recompute hashes (byte-literals were deliberately
   never pinned), so both encode and decode sides moved in step —
   sd-006 formatting-invariance holds under the new basis (stronger:
   canonical text normalizes MORE spellings). Census exactly 7 + 133;
   differential unmoved (no new in-cx rows).
   **NAMED CONFLICT for the owner (lettered; recommendation adopted
   per the standing acceptance ruling):** strict canonical STRIPS
   `[?cx …]` directives (longstanding, pre-epoch — row 2 un-stripped
   RawText but kept CXDirective stripped), so `schema-of` and
   `schema-mode` do NOT survive into the hashed bytes — two schemas
   differing only in mode share one identity, contradicting E2's
   "schema-mode rides in the hash as document bytes". Its
   ANTI-PARAMETERIZATION intent (mode is never a separate policy
   input) holds; the inclusion claim does not. No anchoring consumer
   exists until I5 (type-binding is stream-16/I5 work), so no identity
   hole is live at I1. Options: (a) accept the strip at I1, resolve
   mode-in-identity BEFORE I5 anchoring — either by preserving
   content-bearing directives in canonical (an identity change,
   needs its own ruling) or by moving schema-of/schema-mode into
   schema-document BODY data (schema.md surface change) — RECOMMENDED
   and implemented; (b) preserve [?cx] directives in canonical now
   (moves every directive-bearing doc's address mid-epoch, unruled);
   (c) schema-specific canonicalization (violates one-primitive).
   The residual is PINNED by
   test_mode_does_not_survive_canonical_text_named_residual, so the
   eventual resolution flips a test, never a silent behavior.

26. Row 7 (stream 1, L85 / #708 — ROW 7 COMPLETE): Lane 1's
   identity-exclusion is TRUE in the implementation — the `[?meta]`
   wrapper (`__cx_meta__`) is unwrapped at the codec-lane lowering
   chokepoint (cx_mod_lower_value, the ONE place evaluator markers are
   rewritten before the data-codec layer; code.md §4.2), so cx:hash /
   cx:equal / cx:serialize of a meta-annotated value agree with the
   bare value (probe-confirmed leak: the wrapper emitted as a literal
   `[__cx_meta__ …]` element, splitting the digest on the exact bytes
   that feed address-bound approvals). The display renderer already
   unwrapped (three sites); this was the missing codec twin — put-doc
   (render lane) and cx:serialize (codec lane) now agree. Witnesses
   cx-030..032 (hash / serialize / equal pairs) NEW and green — zero
   corpus movers (no digests of meta-annotated values were pinned; the
   "re-bless" the spec anticipated is empty). Census exactly 7 + 133
   (stdlib run count 2523→2526); differential unmoved (witnesses carry
   [empty] in-cx). D5 unchanged: XML remains the one lossless [?meta]
   target via `<cx:meta>`. SPEC-EDIT OBLIGATION (map): code.md §4.2
   gains the lowering-chokepoint sentence naming meta among the
   unwrapped markers; eval.v:437's "rides through serialization"
   comment re-worded in-commit (text serialization is transparent —
   binding/return flow carries the annotation).

27. Row 8 (stream 1, L80 / audit C4 — ROW 8 COMPLETE; the oph red
   class RETIRES): all seven operator heads `+ - * / = < >` parse as
   OPERATOR-NAMED ELEMENTS in the data lane when the single operator
   char is DELIMITED (followed by whitespace or `]`). Three surgical
   sites: peek_is_array_literal routes delimited `+ - / = <` to the
   element side (glued spellings keep their old routes — `[-1, 2]`
   negative-number array, `[+1, 2]` array normalization); the `*`
   dispatch splits delimited (operator element) vs glued (alias
   `[*n]`, unchanged); parse_element's head reader accepts the
   delimited operator char as the name (`*` `>` used to die there
   with "expected name"). Multi-char glyphs (`<=`) are NOT heads.
   operator_heads.cxd re-blessed v1.0→v2.0 PER THE LEDGER'S
   flip-at-row-8 instruction (the ONE re-bless for this class): the
   five stringify pins flip to element form with fresh tagged
   digests, the two reject pins gain their first addresses, plus
   guard rows oph-008..010 (negative-number array, glued alias,
   empty `[+]`) — 10/10 GREEN; the old→new digests ride the epoch
   mapping file from the v1.0 blessing. Differential moved
   deliberately 720→723 (both_reject −2 → cx_only for the two
   ex-rejecting heads; oph-010 `[+]` is the first row where BOTH
   readings accept an operator-headed input and DIVERGE — data:
   element, program: evaluated arity-err value — the ruled
   data/program mode fork, diverge 18→19). Census exactly 7 + 133.
   FOUND IN PASSING: cx fmt mangles/drops BODY-position alias
   references (pre-existing emit-lane defect, parse+canonical
   correct) — filed #736, oph-009 pins the canonical lane.
   OBLIGATIONS (map): grammar.ebnf gains the delimited-operator-head
   production in [50]/name grammar; XML projection of operator-named
   elements is UNRULED (they are not XML NCNames — flagged for the
   spec-edit map to state the conversion behavior); tmLanguage/
   tree-sitter data-element coloring of operator heads rides the
   epoch tooling pass (ledger obligation 3).

29. Row 10 (#712 / bitemporal L116 — ROW 10 COMPLETE) + row 12
   disposition: the journal's DEFAULT synthetic ts is a REAL ISO-8601
   UTC-Z instant — jrn_ts_for emits time.unix(seq) as
   `1970-01-01T00:00:{seq}Z`-style datetimes (epoch-anchored,
   deterministic, capability-free, monotonic; day boundaries ROLL the
   DATE where the old `epoch:HH:MM:SS` spelling silently wrapped at
   24h). opts.clock opt-in unchanged. Vectors + monotonicity + the
   datetime-form assertion pinned in journal_ts_form_test.v (in-module,
   exercising jrn_ts_for directly, incl. the 86400 rollover). Census
   EXACTLY 7 + 133 — every fixture pinning the old `epoch:` spelling
   (23 pins) was already inside the ledgered journal red class, which
   re-blesses ONCE after rows 10-12 per the standing instruction.
   keep-after-time (#712 item 2) is OWNER-RULED additive post-I1 —
   not deferred here, dispositioned by the ruling. ROW 12 REQUIRES NO
   IMPLEMENTATION: manifest class PINS — the entry/snapshot preimage
   wrappers, field order, non-default-only stream binding, algo-tag
   composition are ALREADY normative in journal.md (audit C1), and the
   shipped bytes are what the spec now describes; the reserved
   `fold-id?` slot is omitted-while-unset. Row 12's obligation rides
   the journal-class re-bless verification (chains must verify under
   the normative wrappers).

31. Row 13 (L28 / audit C2 — ROW 13 COMPLETE): the Tier-2
   participating-field set + the named-token stream. Signature fields
   JOIN the hash in normalize_def_node: per-param shape tokens —
   named-param NAMES (the shipped named spelling is the `=`-default
   form; positional names stay alpha-normalized), the rest-kind flag
   (W-23: `($a $b)` vs `($a *$b)` collided), default VALUES through
   the SAME pipeline as body tokens (rule 5 — parse_program + emit,
   never raw source) — and returns-type contributes its
   STRICT-CANONICAL SOURCE TEXT bytes (rule 3: trimmed, internal ws
   collapsed — the one deliberate source-text exception, so the I5
   TypeExpr repair is identity-neutral). purity/scope stay OUT;
   everything else is OUTSIDE Tier-2 (rule 4, closed list — pinned by
   the [throws] excluded-clause invariant). W-22: ALL eleven V-enum-
   ordinal emissions in the T2Emitter flip to NAMED variant tokens
   (clean-room reproducible; enum reorder can never re-hash code
   again). W-24 is a PINS spec-edit (the SCC separator stays the
   shipped `#` byte; the map documents it). Pins: store-code-003..006
   flipped collide→distinct (all green); 007/008 invariants HELD;
   NEW 009 (named-param NAME distinct) + 010 ([throws] excluded —
   same address) both green. Census exactly 7 + 133 (stdlib run
   2526→2528); differential + conform held; Tier-2 V lanes green
   (they pin properties, not literal digests). Persisted `code:`
   re-hash rides the registry re-seal (rule 7 / M19). SPEC-EDIT
   OBLIGATIONS (map): the L28 normal-form re-specification (named
   tokens enumerated, `#` separator, participating list + exclusions)
   into code-identity.md.

32. Rows 14 + 15 (BEHAVIOR — ROWS 14 AND 15 COMPLETE; every manifest
   row is now IN). Row 14 (E1 totality, audit C4): identity
   acquisition REFUSES the three value classes — closures were already
   fail-closed (CXER4101, now pinned normative, cx-033); iterators
   refuse with NEW CXER4117 E_CX_ITERATOR_NO_ADDRESS
   (consumption-state identity; a bounded [$range lo hi] was NEVER an
   iterator — it returns an eager Sequence and hashes normally, noted
   in the fixture; cx-034 pins a genuine lazy [?take]-over-[$iterate]);
   secret-bearing values refuse with NEW CXER4118
   E_CX_SECRET_NO_ADDRESS (neither plaintext-oracle nor
   redacted-collision addresses exist; cx-035). Both walks mirror
   cx_mod_contains_closure at cx_mod_hash. Row 15 (audit M21):
   CXER4604 and CXER1704 are RETIRED — optimistic-concurrency
   conflicts unify on the ONE ref-conflict code CXER1114
   (E_STORE_REF_CONFLICT): jrn_err_stale_tail flips; the CSRP 409
   bodies emit CXER1114 (wire numeric 1114; gRPC frame map + client
   map + wire-test expectations flipped); journal-042/063 stale-tail
   pins re-pinned to CXER1114 (green). Census exactly 7 + 133 (stdlib
   run 2531 — the three refusal pins green); conform 15 green files
   at the ledgered classes; differential held. SPEC-EDIT OBLIGATIONS
   (map): CXER4117/4118 rows into the module-cx 4100-4119 table;
   CXER4604/1704 tombstones + the CXER1114 unification into
   journal.md/store.md/governance §9.6 (the G18 registry).

## Remaining epoch work — THE ENDGAME

All 16 manifest rows are IN. Remaining: (1) the journal-class re-bless
(regenerate journal.cxd ×27-red details + sched-022 + the 3 spelling
movers + the 23 `epoch:` ts pins — chains verify under the normative
wrappers); (2) the spec-edit maps (every ledger entry lists its
obligations — execute as ONE batch); (3) THE ONE COORDINATED RE-BLESS:
regenerate ALL ledgered corpus reds, author
spec/02-working/partition_I1_hash_mapping.md (old→new digest per class
+ the full corpus diff), re-seal registry/ (gtin@0.1.0 re-publishes via
make registry-publish), flip xap_registry_serve_real_test.v consts —
then the eval gate goes to ZERO reds and conform goes fully green; the
owner reviews the mapping file + corpus diff in the PR (ruling 2a).

33. ENDGAME part 1 (spec maps + eval-lane re-bless — IN PROGRESS,
   working tree at this entry): (a) the SPEC-EDIT MAPS batch landed
   (commit b04bd52c, 17 files; residual: the stream-13 G-1..G-8
   formal repair batch, spec-only, enumerated in
   grammar_lexicon_review.md §3). (b) CX_BLESS=epoch landed in
   code_eval_fixtures_test.v (both lanes, enforced-only, advisory
   skipped) — 128 records adopted via the committed applier. (c) THE
   AUDIT CAUGHT, per design: cx-010/011/012 re-formed per the ledger
   note (serialize + "\n" ≡ canonical via [$concat], NOT the
   mechanically-adopted false); jrn_append's RETURN now hydrates the
   event child (reads/folds/appends present one shape); sap-O1-07
   re-spelled 3.14→3.14e0 (float type-test keeps testing floats);
   math/random/env dispatches REFUSE exact-family args with CXER3002 +
   the cast hint instead of falling through to "no callable" (the
   ledger's promised math re-bless commit — entry 15's residual
   discharged; env-044 re-spelled). CODE.CXD IS AT ZERO ENFORCED.
   REMAINING (next cycle, exact plan): (1) the 47 stdlib enforced =
   the 2b input-re-spell set — math.cxd/random.cxd fixtures whose
   in-code decimal literals must become float spellings (eN) because
   their INTENT is float math (then re-run CX_BLESS=epoch to adopt
   exact float outputs; fixtures that now correctly test DECIMALS keep
   their adopted exact results); plus journal-055's forged-signature
   fixture (make the forgery a valid-SHAPED tagged signature so it
   tests signature verification, not tag parsing); xap-dist-037/038
   await the registry re-seal. (2) The conformance-side EBLESS
   machinery (conformance_run.v out_X sites + V applier per the
   design below) for the ~30 conform reds (idh singles, ext-038/039,
   xml-027, tab-007/019, astb-003, yaml-018, arrow-002/013, code
   triquote ×2 — out-canonical/out-hash/out-xml/out-ast sections).
   (3) Then: mapping file, registry re-seal, consts flip, zero-red
   verification, ONE final commit.

34. THE RE-BLESS (endgame part 2 — THE EPOCH CLOSES, pending the final
   suite audit): (1) the 44 float-intent math/random inputs re-spelled
   to exponent form (fixed-string rewriter, exact literals) and their
   exact outputs adopted; journal-055's forgery re-formed to a
   valid-shaped tagged signature (tests SIGNATURE verification again —
   CXER4613); env-044 re-spelled. (2) The conformance EBLESS landed
   (13 mismatch sites hooked in conformance_run.v, section-aware
   records; apply_epoch_blesses.v — the V applier) — 19 records
   adopted, ALL mapping to ledgered classes (idh singles ×5, ext 2b +
   triquote family, xml-027, tab ×2, astb-003, yaml-018); idh-022
   (decimal −0 normalizes → true) and idh-023 (scale-preserving →
   false) pair pins flipped BY HAND with rationale notes; arrow
   expect-values re-spelled to exponent form. CONFORM FULLY GREEN.
   (3) partition_I1_hash_mapping.md authored (representative old→new
   per class + the corpus diff as the exhaustive record). (4) registry
   RE-SEALED: nmea0183@0.1.0 re-published under epoch bytes (manifest
   sha2-256:1032cf6a…, tree sha2-256:a5c6ee0d…; the ledger's earlier
   "gtin" reference was the release-branch package — the impl branch
   registry holds nmea0183); xap-dist pins re-adopted as REAL values;
   xap_registry_serve_real_test.v consts flipped — THE TEST IS GREEN
   (red since entry 19). (5) EVAL GATE: ZERO ENFORCED (was 7+133 all
   epoch). Differential holds at its final baseline. The deliberate-red
   ledger is EMPTY — every class in the red table above is discharged.
   Residual named map item: the stream-13 G-1..G-8 spec-only formal
   repair batch (grammar_lexicon_review.md §3).

**Epoch-bless machinery design (scouted for the executing cycle):** the
shipped CX_BLESS=1 mode is quote-only-diff gated — too narrow for the
epoch. Build: (a) conformance_run.v — under CX_BLESS=epoch, at each
`failures << 'out_X mismatch'` site (out_cx / out_canonical / out_hash /
out_ast / out_xml / out_json[_lossless] / out_yaml[_lossless] / out_toml
/ out_md — NOT out_err, NOT out_hash_eq, which were re-pinned
semantically with their rows), emit a section-aware record
`<<<EBLESS file=X id=Y section=out-hash>>> got <<<ENDEBLESS>>>` to
/tmp/cx_epoch_blesses.txt; (b) code_eval_fixtures_test.v — same mode
emits every ENFORCED out-text mismatch in BOTH lanes (code.cxd +
stdlib), skipping advisory; (c) a V applier (mirror apply_blesses.py's
case-span logic, section-aware; V not python per the standing rule) that
rewrites the named `[section [# … #]]` block in place. EXECUTION ORDER:
(1) spec-edit maps batch commit FIRST (the standing maps-before-re-bless
order); (2) journal-class re-bless MAY ride the general mechanism (its
reds are ordinary out-text mismatches); (3) run all gates with
CX_BLESS=epoch → apply → re-run WITHOUT bless → ZERO reds; (4) the git
diff of conformance/ IS the corpus diff — derive the mapping file's
representative old→new digest pairs from the out-hash hunks; (5)
registry re-seal (make registry-publish, read registry/publish.cx
first) AFTER the corpus re-bless; (6) flip
xap_registry_serve_real_test.v consts from the re-published registry;
(7) full suite: the ONLY acceptable non-green = known-flaky retry
lanes. Every adopted output is REVIEWED against its ledgered cause —
the ledger's red-class table is the checklist; anything the bless
touches that is NOT in the table is a REGRESSION to investigate, not
adopt.

30. Row 11 (#720 / erasure L184, audit C1 — ROW 11 COMPLETE): DETACHED-
   PAYLOAD entries, one form, no dual-accept. The entry-canonical
   preimage replaces its payload body child with a `payload=` attribute
   carrying the payload's own Tier-1 tagged address (wrapper, field
   order, non-default-only `stream` binding unchanged); append persists
   the payload as its OWN store doc inside the same group-commit scope;
   the PERSISTED entry carries only the address (embedding would defeat
   lawful shredding); the READ surface re-hydrates the [event] child by
   address (jrn_hydrate_entry at every read/fold/query chokepoint —
   default + named streams, store-fallback lane, fold hydration
   threaded); verify recomputes over the ADDRESS with no payload fetch —
   THE MANDATE (verify green with payloads destroyed) is pinned in
   journal_detached_payload_test.v (append → shred via store-delete-doc
   → verify STILL valid → shredded entry reads event-less → siblings
   hydrate → address-integrity negative: same envelope, different
   payload address ⇒ different canonical bytes). Dry-run computes the
   address WITHOUT persisting (byte-identical to the committed hash).
   FOUND BY THE PINS: rotation copied entry docs but not payload docs —
   jrn_copy_payload_doc now carries them in both compact loops (named +
   default), and an already-shredded payload copies nothing (the shred
   SURVIVES rotation, by design). Census exactly 7 + 133 (the journal
   red class absorbs the form change); differential + conform held.
   The three-way get-doc discriminator, envelope_open
   shredded-vs-tampered, and the CXER 1143+ registry repair are
   ADDITIVE post-I1 (#720 items 1-3). SPEC-EDIT OBLIGATION (map):
   journal.md §2.2/§4.2 the detached entry form; store.md the payload-
   doc lifecycle note. ALL FOUR MOVES-CLASS JOURNAL ROWS (2/10/11/12)
   ARE NOW IN — the journal-class re-bless is UNBLOCKED.

**Row-11 implementation map (scouted; superseded by entry 30):** ONE entry form, no dual-accept — the `entry-canonical`
preimage (stdlib_journal.v jrn_canonical_bytes:553, wrapper element +
field order + non-default-only `stream` binding all UNCHANGED) replaces
its payload BODY child (`items: [event]`) with a `payload=` ATTRIBUTE
carrying the payload's own Tier-1 tagged address (an envelope field — a
chain coordinate, not domain data). At append (jrn_append:1346): compute
payload_addr = cx_text_hash(render_canonical(event)), persist the
payload as its OWN store doc, and persist the entry WITHOUT embedded
event bytes (else shredding the payload doc would not erase). Read path
resolves payload docs by address to reconstruct the [event] view; verify
covers the ADDRESS only — the fixture-before-fix family is
verify-green-with-payloads-gone (append, delete payload docs, verify →
all three checks PASS) plus an address-integrity negative (tamper the
payload attr → hash mismatch). The three-way get-doc discriminator +
envelope_open shredded-vs-tampered + the CXER 1143+ registry repair are
ADDITIVE post-I1 (#720 items 1-3) — only the entry form is I1. The
journal red class (27 + sched-022 + 3 + the 23 epoch: ts pins)
re-blesses ONCE after this row lands.

28. Row 9 (stream 1, E1 L77-L81 + audit C4 — ROW 9 COMPLETE): the
   authorable variable HOLE + quote lowering. HoleNode joins the Node
   sum (structural kind like AliasNode — NOT a 12th scalar kind, per
   L60): a bare DELIMITED `$name` token (simple name — `.`/`:`
   continuations stay text) parses as a hole in element bodies AND
   collection/slot items, in the [L25b] SELF-DELIMITING class
   (body_is_typed_list admits it, so `[+ $x 2]` = hole + typed int 2
   — required for lowered-image idempotence). Canonical spelling
   `$name`; the STRING "$name" spells '$name' (cx_body_leading_sigil
   gains `$` — $-leading body strings always quote; ZERO corpus
   movers, the corpus had no delimited $-tokens outside verbatim
   directive interiors). Emit joins holes as inline siblings
   (cx_build_inline_body ' ' join; no value-space glue). Projections:
   JSON ast {"type":"Hole"}; XML <cx:var/> (the lift stays
   emitter-internal, L78); ast_bin additive tag 0x18 (node-tag space —
   distinct from data-bin's 0x18 scalar tag); program render `$name`.
   QUOTE LOWERING: program_node_to_data_q lowers a bare no-path
   binding to HoleNode (the <cx:var> element image is gone);
   data_to_program_node lowers HoleNode back to ProgramBinding
   ([?eval] round-trips; eval-env visibility semantics UNCHANGED —
   verified identical at HEAD). Quoted trees now serialize as plain
   authorable CX text and HASH: expression identity IS the Tier-1
   address of the lowered tree — probe-proven cx:hash(serialize(quote
   [total $x])) == cx hash of the data doc `[total $x]` (L77/L81).
   PINS FLIPPED per the flip-at-row-9 instruction: idh-026 hash-eq
   true→false (the collision MUST holds); cx-094 out-err→the real
   tagged digest; program-dc-bare-var-inert re-pinned [a [cx:var 'x']]
   → [a $x]. Census exactly 7 + 133; differential HELD at 723 (zero
   in-cx movement). RESIDUALS (named): mk_cx_expr (path-bearing
   bindings + non-literal program constructs) still emits the
   cx:expr hatch — those quoted trees remain unhashable (E210 →
   CXER4100) pending an authorable expression form (L78 ruled only
   VARIABLE holes; flagged for the spec-edit map); data-bin VALUE
   carriage of holes is unruled (the DataVal projection drops
   structural nodes — same class as XML operator-name projection).
   SPEC-EDIT OBLIGATIONS (map): grammar/lexicon gain the hole
   production ([L25b] self-delim membership + the `$` leading-sigil
   quote rule); ast.md the HoleNode kind; ast-bin.md the 0x18 tag;
   code.md §6.4.3 the lowering.

**Row-9 scouting (superseded by entry 28; kept for the record):** two halves. (A) The
hole-surface collision MUST (L78 amendment): data-mode bare `$x` must
canonicalize DIFFERENTLY from the string `'$x'` — today both collapse
to one TextNode/one address (idh-026 pins hash-eq=true, flips to
false). Needs a distinct hole representation in the data reading +
needs-quote extended so $-leading STRINGS keep their quotes in
canonical (bijection: bare `$x` = hole, quoted `'$x'` = string), BOTH
engines in step. (B) Quote lowering: `[?quote …]` results serialize
via the `cx:var`/`cx:expr` lift (vcx/code/dynamic_construction.v:260,
:521 — mk_cx_node('cx:var', …) / mk_cx_expr) whose image dies on
re-parse (E210 → CXER4100; cx-094 pins the death). At I1 the lowering
emits plain authorable CX source (holes as `$x`, expressions per L78
"annotations retained exactly where the bare spelling would re-type
differently"), so quoted trees gain Tier-1 addresses (DEFINES — no
address existed). The `cx:` lift remains emitter-internal for the XML
projection only, never the identity substrate. PROBED: both `[total
$x]` and `[total '$x']` parse to Text "$x" today (the quoted spelling
UNQUOTES in canonical — the collision is value-level, not just
spelling-level), so half A needs a distinguishable HOLE node in the
data reading (a structural NODE kind like Alias — NOT a 12th scalar
kind, which L60 makes a major-version event) + needs-quote extended so
$-leading STRING images always keep quotes; the existing `cx:var` lift
becomes the hole's XML projection. Both engines + canonical + emit +
eval-inertness of holes in data docs; then half B's lowering emits
holes as `$x`.

35. POST-EPOCH ADOPTION AUDIT (2026-08-06, the obligation-2 pass —
   after the exit-merge): the doc-regeneration gates surfaced 22
   corpus cases whose epoch-blessed outputs were DEGRADED adoptions,
   not reviewed movements — all one class: float-intent inputs missed
   by entry 34's 44-input re-spell, so the 2b flip made their bare
   fractions decimals and the bless adopted the degraded result
   instead of a value. Tell-tales: blank `$r/value` out-text
   (random-026/030/031/032/048), `no callable` fall-throughs
   (random-070/071, prof-013), CXER3002/CXER0100/CXER3001 errs
   adopted over value-intent case ids (math-021..025/027/028/030/034,
   math-061/062 whose float filters left "empty sequence"), and ONE
   silent value corruption (prof-014 count 3→0 — observes failed,
   stats still answered). ALL 22 repaired: inputs re-spelled to
   exponent form, pre-epoch value outputs restored (probe-verified
   against the live binary — every value reproduces exactly);
   prof-016/017/018 re-spelled for intent (outputs unchanged).
   math-116 ADDED: the stdlib-dispatch transcendental-over-decimal
   CXER3002 refusal keeps a deliberate corpus pin (the repairs
   removed the accidental ones; the $sqrt-builtin lane was already
   pinned in decimal_bigint_semantics_test.v). Rest of the movement
   audit came back clean: geo/similar/net/locale/http/ft/adjudicate/
   test corpora never moved; store/json/csv movements all map to
   ledgered classes. Co-located [fn-doc] examples re-pinned to the
   repaired corpus in the same pass (obligation 2).

36. POST-EPOCH DISCHARGE, THE CODE LANE (2026-08-06, the obligation-4
   pass): the L48 bindings work surfaced that `make test-vcx-code` (the
   vcx/code in-module white-box lane — NOT part of test-vcx-suite, the
   per-commit discipline's target) was left RED at the epoch close:
   11 files, all undischarged I1 fallout. Three classes, all repaired:
   (1) ONE REAL WIRE DEFECT — the CSRP binary doc-pair/match frame
   (store_csrp_wire.v) hex.decode'd the now-tagged store key into its
   fixed 32-byte field, failed, and ZERO-PADDED silently: every
   binding's store-client iter lane returned all-zeros hashes (Go,
   Rust, and Python clients all caught it independently). The frame is
   re-formed per the row-3 pack precedent: `[u16 hash_algo_code BE]
   [u8 digest[32]]` (sha2-256 = 0x0012, THE ONE registry), writers
   derive the code from the tagged address and fail CLOSED
   (CXER0130/0131/0132 error frames) on unparseable input, readers
   fail CLOSED on unregistered codes and reconstruct the tagged
   spelling — bare hex never crosses the boundary in either direction.
   cxstore-remote-protocol.md §3.2 re-specified in step; pinned by
   store_csrp_wire_tagged_test.v (round-trip, multicodec byte,
   bare-hex refusal, unknown-code refusal, blake3 reconstruction).
   (2) STALE 64-HEX PINS — 12 `len == 64` assertions across the
   binary-wire/CSRP/gRPC test files re-pinned to the tagged form
   (73 / `sha2-256:` prefix), incl. the grpc round-trip helper whose
   64-len guard silently skipped the GET leg. (3) STALE SPELLINGS —
   `sha256:` secret-hash seeds in service/config-reload tests flipped
   to the registry spelling; the #188 dual-accept test re-formed (the
   legacy `sha256:` now PINNED AS REJECTED per entry 19); the retired
   `takewhile` in worker_cancel_test re-spelled `take-while` (entry
   22). Bindings parity itself (the obligation): Go rides
   cockroachdb/apd v3 (shopspring FAILED the scale pin — "1.10"→"1.1")
   + math/big.Int; Rust bigdecimal::BigDecimal (to_plain_string, the
   Display-exponent trap confirmed) + num_bigint::BigInt; Python
   decimal.Decimal (format 'f') + int — all three native CXCol codecs
   carry 0x18/0x28 with fixed-point images, kind never erased; Go +
   Python ast_bin readers gained the epoch's HoleNode tag and fail
   loud on unknown tags (both silently desynced before); store-client
   address regexes cut to tagged form. binding_api.cxd gains
   111/112 (decimal/bigint emit + hash parity).

## Owner rulings 2026-08-05 (end-of-session batch)

- **CXER codes ratified (1a):** CXER0130 (bare hex), CXER0131 (unknown
  algo), CXER0132 (digest shape), CXER0135 (unsupported-suite) enter the
  error-code registry as minted; the spec-edit maps register them.
- **Re-bless execution (2a):** the ONE re-bless is EXECUTED by the
  implementer; the owner reviews the old→new mapping file
  (partition_I1_hash_mapping.md) and the full corpus diff in the PR.

## Tooling / documentation alignment (epoch obligations)

The partition ships with aligned tooling and docs — tracked here so the
re-bless is not the finish line:

1. **Normative specs** — the per-commit spec-edit obligations (each
   ledger entry names its letters) execute as the spec-edit maps BEFORE
   the re-bless.
2. **Generated docs / guide / playground** — doc examples are
   fixture-backed (make docs, guide-check, directive-docs-check,
   playground gate), so they re-record immediately AFTER the re-bless;
   the drift gates force this — run them and commit the regeneration.
3. **Editor tooling surface** — tree-sitter-cx + LSP highlighting gain
   the epoch's new lexemes: postfix `value::T` ascriptions in collection
   positions, tagged `sha2-256:` addresses, exponent-only float
   spellings, `genesis:` sentinel. check-tmlanguage-sync +
   check-completions-drift gates verify.
4. **Bindings parity (L48)** — Python/Go/Rust host mappings for the
   promoted decimal/bigint kinds (Go exact-decimal lib, Rust bigdecimal,
   Python decimal.Decimal/int); readiness-rubric rows flip
   pending-until-I1 → done; binding-api parity gate re-runs.
5. **CLI surfaces already aligned in-epoch:** cx hash/canonical output,
   cx demo fixture, cx scaffold templates, cx store-token stanzas.
