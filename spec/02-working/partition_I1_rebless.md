# I1 identity epoch — deliberate-red ledger + re-bless obligations

**Status:** live working ledger on `impl/I1-identity-epoch`. Every entry is a
fixture class that is RED ON PURPOSE mid-epoch (its pinned bytes moved by a
manifest row) plus the obligations the final coordinated re-bless must
discharge. Nothing here is a regression; anything red that is NOT in this
ledger IS one. Updated per epoch commit.

## Red classes (verified intended, per triage)

| Class | Cause (manifest row) | Re-bless action |
|---|---|---|
| `identity_hash.cxd` singles idh-001…005 | W-14 LF (row 2) — every Tier-1 digest moved | re-bless digests; record old→new in the mapping file |
| `operator_heads.cxd` oph-001…005 digests | W-14 LF now; row 8 will move them AGAIN (stringify → element) | re-bless ONCE, after row 8 lands |
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
- `idh-026` ($x vs '$x') + `cx-094` (quote-hash E210) → row 9 (quote lowering)
- `oph-001…007` semantic flips → row 8 (operator-head lexer fix)
- `store-code-003…006` (Tier-2 collisions) → row 13 (participating-field set)
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

## Remaining epoch work

Rows 5-7, 8-9 (oph/idh-026/cx-094 pins flip), 10-15, then spec-edit
maps + the ONE re-bless with the old→new mapping file + registry
re-seal.

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
