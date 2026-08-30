# Audit — the codec/Ring layering (2026-08-30)

**Scope.** Structural audit behind #1126 (libcx-core has no json text parser),
#1127 (conformance runner passes unknown input sections vacuously), #1128
(toml/json refusals carry no location) — and the four wider questions the
#1097 campaign surfaced and deliberately did not decide: (1) whether the
Ring-0/Ring-1 line is drawn where it should be, or error style has been
standing in for a dependency boundary; (2) whether every codec's parse/emit
core is Ring-0 by contract; (3) what else differs between the shipped
profiles that nobody chose; (4) the general fix for the vacuous-pass hole.

**Instrument.** Direct code reading at HEAD (`5a3b6192b`), the built
`vcx/target/cx` + `vcx/target/profiles/data/cx`, and three targeted sweeps
(dependency classification of vcx/code, gate-coverage mapping, profile
divergence). Every load-bearing claim carries a file:line. No code, spec, or
fixture was modified. Working-tree files from the parallel SAML session
(`ledger/rulings_2026_08_29_saml_sp_1091.md`, `governance.md`, `saml.md`,
`devbox.lock`) were left untouched.

Umbrella: #1097 (complete, gates green). Prior constraints honored: TF-3
(codec layer stays core and uniform; module promotion needs format-intrinsic
VERBS), #1077 (full option space before any structural recommendation),
R2.2/I4 (per-profile install verification is blocking at the cut).

---

## §1. The finding, mechanism confirmed

Three release profiles ship (scripts/release.sh:145): `data` = cx
(cannot-execute) + libcx-core + cx.h; `embed` = cx + embed-shape libcx +
cx.h; `cli` = cx only. libcx-core builds ONLY `vcx/cx/` (vcx/Makefile:586,
the I2 Ring-0 strict sink); the data-profile cx builds from `cmd_data/`
which imports only `cx` + `cli`, and `cli/` imports only `cx` + `os` — so
both data-profile artifacts have the hole by construction, not just the
library.

The registry (vcx/cx/codec.v): the static base table carries `json` with
**emit only** (codec.v:131 — the comment says why: the strict parser lives
in `code`, which `cx` cannot import); `html` and `url` are absent from the
base table entirely. The runtime overlay (`register_codec`, codec.v:80) is
populated from exactly one place: `vcx/code/stdlib_codec.v:init()`
(stdlib_codec.v:224 json parse, :240 html, :245 url). In any artifact that
does not link `code`, that init never runs.

Measured on the shipped shapes (both divergences live right now, all gates
green):

```
echo '{"a":1}' | vcx/target/cx --from=json --to=cx        → {a: 1}          rc=0
echo '{"a":1}' | vcx/target/profiles/data/cx --from=json  → error: codec json has no text parser   rc=1
echo '<p>x</p>' | vcx/target/cx --from=html --to=cx       → [html-document [p x] '\n']             rc=0
echo '<p>x</p>' | vcx/target/profiles/data/cx --from=html → error: unknown source format: html     rc=1
```

The refusal names the registry ("codec json has no text parser"), so it
reads as a misconfiguration rather than a build-profile consequence.

## §2. Q1 — is the Ring-0/Ring-1 line drawn right? (the dependency sweep)

The claim under test: error PRESENTATION decided ring. Verdict: **confirmed
for the three codecs, and the pattern is narrower than feared elsewhere.**

**What `mk_err` actually is.** `mk_err` (vcx/code/eval.v:8865) constructs a
plain `cx.Element` — Ring-0 data — and then calls `fire_raise_observe(e)`
(eval.v:8880), the §9.6 raise-stage hook, which walks evaluator frames and
can invoke closures (error_hooks.v:80-96). That ONE call is what drags the
evaluator behind every codec. `mk_err_quiet` (eval.v:8888) is the identical
builder without the hook and is pure `cx.Node` construction.

**The three codecs' actual Ring-1 dependencies:**

- `stdlib_json.v` (1205 lines): the whole tokenizer/parser/number-mode logic
  and JsonEmitter (lines 1–877) contain **zero** cross-file `code` symbols.
  Failures accumulate internally via `p.fail(code, msg)` into
  `p.err_code`/`p.err_msg` (stdlib_json.v:234) and only materialize as an
  err VALUE at the boundary — every `mk_err` sits at line ≥ 881, inside
  `json_do_parse`/`json_emit_with` wrappers. The file is already structured
  for the split. Its one cx call-out, `cx_decimal_image_from_json_number`
  (vcx/cx/numeric_exact.v:669), is a JSON-specific routine that lives in
  Ring-0 **solely to serve this Ring-1 parser** — the seam already leaks
  upward.
- `stdlib_html.v` (1396 lines) and `stdlib_url.v` (1244): import only `cx`;
  every err construction is funneled through 3–4 one-line local constructors
  (stdlib_html.v:48,52,56; stdlib_url.v:175,179,183,187). Both headers state
  "pure — no process-global state". Peer helpers they lean on
  (`utf8_validate` stdlib_bytes.v:602, `utf32_to_str` stdlib_json.v:1176)
  are self-contained pure functions.
- `note_operand_fault` (stdlib_operand_fault.v:67) appears only in the
  module-verb argument-extraction arms, never in a parse/emit core.

So the three parser/emitter cores are Ring-0-portable with only an
error-shape conversion at the boundary — and that conversion already exists
in both directions in `stdlib_codec.v`: value→`!` (`codec_node_err`,
stdlib_codec.v:301) and `!`→value (`or { return mk_err(…) }`, ~12 sites).
Two directions for one boundary is itself a finding (§6.2).

**The wider sweep (16 data-plane files + 20 more checked):** no data-plane
file in vcx/code takes evaluator context (`Interp` does not exist; `MatchEnv`
appears in exactly one, `stdlib_validate.v`, whose env-taking half is genuine
evaluator code). The blockers cluster into exactly three kinds:

1. **Error-value construction only** (mk_err / note_operand_fault):
   stdlib_json, stdlib_html, stdlib_url, stdlib_csv, stdlib_bytes,
   stdlib_strings, stdlib_re, stdlib_hash, stdlib_math, stdlib_geo,
   datetime_core (zero deps — an explicitly Ring-0-shaped file sitting in
   Ring-1). These COULD move; only the codec three have a reason to (§3).
2. **`render_canonical`** (render.v:172) — looks portable (render.v imports
   only cx + strings) but calls `iterate` (eval.v:15648, forces lazy
   iterators against ProgramState) and eval.v map-entry helpers. Blocks
   stdlib_format.v:649 and stdlib_jsonschema.v:128. A real, non-cosmetic
   Ring-1 dependency — correctly placed today.
3. **Arm-level `cap_guard`/effects** (stdlib_mime, stdlib_crypto's
   JWKS-fetch lane, stdlib_path, stdlib_tar/zip's single `iterate` call
   each) — genuine effect/evaluator seams, correctly Ring-1/2.

**Verdict on Q1:** the ring line is drawn right everywhere EXCEPT the codec
registry's own entries. Stdlib packs are correctly Ring-1 — nothing in the
data profile can call a module verb (no evaluator), so their placement is
consequence-free. The codec halves are the one place where Ring-1 placement
subtracts capability from a shipped artifact, because the registry is Ring-0
and profile-visible. Error style decided ring exactly there, and only the
consequences there matter.

## §3. Q2 — is a codec's parse/emit core Ring-0 by contract?

The specs already say yes, three ways:

- **codec.md §4** lists json, html, url as MANDATORY full-contract codecs;
  §5 classifies codecs as **pure** ("parsing them charges no capability" —
  evaluator-free by classification); §6 mandates ONE registry that CLI, ABI,
  and module surface all route through.
- **cx_partition.md §2** puts "conversions" in Ring 0; **§4** gives the
  `data` profile the verb set `parse/emit/convert/…` with adopter column
  "embed/**parse**/validate; **untrusted input**". A data profile that
  cannot `--from=json` fails its own §4 row. (§2's wording "format emitters
  (json/xml/yaml/toml/md)" — emitters — is the residue of the retired
  element-synthesizing `parse_json_cx`; it predates the strict parser and
  html/url registration, and needs the ruling to update it either way.)
- **cx_partition.md §7/§8** freeze the Ring-0 contract at 1.0 including "the
  libcx-core C ABI". An ABI whose `cx_json_to_cx` symbol is exported
  (baseline libcx_abi_surface.txt:70, and present in libcx-core per nm) but
  non-functional is the worst reading of that freeze.

The overlay's own header (codec.v:58-67) frames itself as a workaround:
"`cx` is the lowest layer and cannot import `code`, yet some codecs'
canonical parser/emitter live THERE." The dispatch chain comment
(stdlib_codec.v:15-19) already calls module-first precedence temporary
("until S3 folds their implementations onto this same registry"). Direction
was never in dispute — it was never sequenced.

**Also noted (not this ruling's scope, recorded for honesty):** Ring-0
already holds a second, lenient JSON reader (`JReader`/`JV`,
parser_json.v:19 — retained as shared machinery for the yaml/toml/ast-json
importers), and the json module carries its own `JsonEmitter` distinct from
the registry's Ring-0 `json_codec_emit`. Content agreed on probes; the
S3-fold direction is where those converge eventually. No new fact requires
acting on them in this wave.

## §4. Q3 — what else differs between the shipped profiles that nobody chose

**The gate architecture cannot see capability differences.** Every
divergence gate is a fixture-reachability gate; none asserts a property OF
the artifact:

- The **extraction gate ABI lane** (extraction_gate_probe.v) dlopens both
  libraries, replays the effective-Ring-0 corpus, and `cmp`s transcripts
  byte-for-byte (Makefile:929-933). It even HAS an `in_json` battery
  (probe:427-436 → cx_json_to_* family) — which has never fired, because the
  corpus contains **zero** `[in-json]` sections (vs in-cx 1916, in-xml 47,
  in-yaml 49, in-toml 18). No in-html/in-url section kind exists at all.
  The F-15 vacuous-pass defenses (case floor 1564, zero-record check) catch
  the adjacent class only: a capability with NO case is invisible by
  construction. "The monolith is the oracle" (probe:9-30) holds only over
  inputs a fixture supplies.
- The circularity is airtight: the corpus can't carry json-input fixtures
  because the cx-only conformance runner cannot parse json
  (conversions.cxd:17-19 says so explicitly), and the extraction gate
  borrows that same corpus. #1126 and #1127 are one root cause.
- **libcx-abi-gate** is symbol-freeze only, and runs against libcx ONLY
  (Makefile:995-996). `cx_json_to_cx` is present in both artifacts; the
  capability behind it is not. Symbol gating cannot express this.
- **profile_gate** imports `code` (cli/embed engine composition) and
  explicitly delegates the data profile to the extraction gate
  (vcx/Makefile:804: "the data profile's corpus clause is the I2 extraction
  gate") — delegating exactly the surface that diverged to the gate that
  couldn't see it.
- **R2.2 release gate** (r22_profile_gate) extracts each tarball, runs
  `cx -v`, and checks FILE PRESENCE of libcx-core — the library is never
  loaded and no codec is exercised (lib/r22_profile_gate.sh:36 admits the
  "lib-content hole"). A libcx-core that cannot parse json ships green
  through the blocking cut gate.

**`cx_features` makes an actively false claim.** The capability mask
(vcx/cx/cabi.v:287, `0x37fff7fffff`) is a compiled-in constant in Ring-0,
identical in both libraries. abi.md §3: bindings parse it on load and
"refuse to use features the loaded library does not implement" — bit 28
("CX code evaluator — a libcx setting this bit COMMITS to the evaluator"),
bits 34/35 (`[?def]`/`[?lib]`), bit 38 (capability security) are all set in
the mask libcx-core returns, while libcx-core exports no `cx_code_*` symbol
at all. The mask-agreement gate (feature_mask_agreement_test.v, in
identity_umbrella_test.v:1335) imports `code` + `platform` — it can only
ever attest the monolith composition, so the core artifact's mask is checked
against nothing. Same shape as the extraction-gate hole: the enforcement
instrument lives above the artifact it should check. Only bit 23 (arrow)
composes at comptime — the mechanism the rest of the mask needs.

**The full divergence sweep.** There is exactly ONE cross-ring mutable hook
in Ring 0 (verified exhaustively: the codec overlay is the only
`&Struct{}` singleton, `register_codec` the only registration fn, the only
upper-layer mutator call; the only `$if` gates in vcx/cx are the two
`cx_arrow_files` arms, and the only `init()` is the RE2 cache). Every
Ring-0/Ring-1 divergence is downstream of the overlay or of static Ring-0
state never made ring-aware:

| Divergence | Mechanism | Verdict |
|---|---|---|
| 10 `cx_code_*`/`cx_wasm_*` symbols absent from libcx-core | code/cabi.v not in lib-core | CHOSEN (partition §5) |
| `cx_features` claims bits 28/30/31/34/35/38 + half of 41 that libcx-core cannot honor | static const cabi.v:287, no ring arm (bit 23's `$if` at :317 proves the pattern exists) | **INCIDENTAL** |
| The guard named in cabi.v's comment (`feature_mask_agreement_test.v`) does not exist as a file; the real gate (identity_umbrella_test.v:1353) imports `code` and cannot audit core; the probe never records `cx_features` | — | **INCIDENTAL** |
| **9** `cx_json_to_*` exports exist but fail in libcx-core (`_to_cx/_to_xml/_to_ast/_to_json/_to_yaml/_to_toml/_to_ast_bin/_to_data_bin/_to_data_bin_schema_driven`, cabi.v:460-1152) | base table has no json parse | **INCIDENTAL** — no OTHER cx_* export consults the registry (verified) |
| `cx --from=json` AND `cx foo.json` extension autodetect fail on the data CLI | cli/data_verbs.v:275, cmd_data/main.v:375 | **INCIDENTAL** |
| Data-profile `--help` advertises JSON reading it cannot do | hardcoded prose cmd_data/main.v:209-210, vs the monolith's registry-derived list (cmd/main.v:1265) | **INCIDENTAL** — the data binary has NO registry-derived list surface at all |
| Monolith help + shipped docs (docs/llm/reference-cli.md:145-147, no profile qualifier) list html/url; data profile answers `unknown source format` | registry-derived list sees the overlay | **INCIDENTAL** |
| `cx schema infer` over a `.json` corpus works on monolith, fails on data profile | cli/schema_verbs.v:188 (divergence documented at :185-187); the gate never runs `schema infer` | CHOSEN at the call site; gate gap INCIDENTAL |
| `--lossless` list + refusal text | lossless flags live in the base table independent of parse halves | **NO DIVERGENCE** (verified — well built) |
| `code-tree` refused by the data CLI with "no evaluator" rationale, though `cx.code_tree` is Ring-0 and libcx-core EXPORTS `cx_code_tree` (cabi.v:2132) | cmd_data/main.v:41-43,74 | verb set CHOSEN (§4); the rationale text and the ABI/CLI asymmetry INCIDENTAL |
| `fmt`/`lint` refused with the same "no evaluator" rationale though both impls are Ring-0 (cx/tooling.v, cx/lint.v) — spec §2's "fmt/lint are Ring-1" is stale | cmd_data/main.v:41,74 | verb set CHOSEN; rationale INCIDENTAL; verb-set expansion = owner surface question |
| wasm control surface split across the ring line: `cx_wasm_set_arena_size`/`reset` Ring-0, `set_wall_sleep`/`is_asyncify` Ring-1 — the §6 playground target (data profile) gets a partial wasm surface | file placement | INCIDENTAL (low consequence today) |
| Embed-profile libcx vs monolith: all Ring-2 pack dispatch (~250 verbs, 6 directives, sub-ops, `pkg:` resolver) absent, empty-registry refusal fallthrough | platform_init.v → ring2_register.v, ring_registry.v:98 | CHOSEN & pack-gated — **no data-plane leak found** |
| `codec_parse_opt_keys`/`codec_emit_opt_keys` are hardcoded match arms (codec.v:~640) — overlay-registered codecs can never gain a `-with-opts` verb | registry-vs-hardcode drift, same file | INCIDENTAL (not artifact divergence; same drift class) |

## §4a. The per-format picture (owner-requested appendix)

One row per format; `→` marks what this wave changes (CR-1/CR-5):

| Format | Registry entry | Parse core | Emit core | Ring-1 module (layer 2) | lossless | Data profile | Refusal location |
|---|---|---|---|---|---|---|---|
| cx | base | R0 | R0 | `cx:` always-on | yes | full | ✅ line:col |
| xml | base | R0 | R0 | none (synthesized + with-opts) | yes | full | ✅ line:col |
| json | base emit-only → base complete | R1 → R0 | R0 | json.md (pretty/stream/opts) | yes | emit-only → full | ❌ → ✅ line:col |
| yaml | base | R0 | R0 | none | yes | full | ✅ line:col |
| toml | base | R0 | R0 | none | no (refuses by name) | full | ❌ → ✅ line:col |
| md | base | R0 | R0 | none (lossy per D-B) | no | full | ◐ |
| csv/tsv/psv | base (dialects) | R0 delimited.v | R0 | csv.md — deliberately DIFFERENT impl (§8.2 ruled dual surface) | no | full | ✅ row |
| html | overlay → base | R1 → R0 | R1 → R0 | html.md (sanitize/extract-text) | no | absent → full | ✅ |
| url | overlay → base | R1 → R0 | R1 → R0 | url.md (query/join/idn) | no | absent → full | ✅ |
| cxcol/data-bin/ast | base | R0 bytes-only | R0 bytes-only | none (binary) | n/a | full | n/a |

Post-wave invariants the table encodes: every codec half in the base
table (overlay = extension seam only, #1130-watched); module presence is
the TF-3 verb-richness axis and moves for no format; csv is the one
ruled two-implementation format; TF-9's code+class+location holds in
every lane with a natural unit (md residual ◐). tar/zip/mime/geo are
correctly absent: stdlib packs, not codecs, promised to no profile.

## §5. Q4 — the vacuous-pass hole (#1127)

conformance_run.v:299-320: the input-format dispatch is a hand-maintained
if-chain over eight `in_*` section names, calling Ring-0 parse functions
directly; the `else` arm `return failures` — empty — counts as PASS. Any
unknown `[in-*]` section (in-json today; in-html/in-url tomorrow) passes
vacuously, its out-* sections never compared.

Two structural observations beyond the missing branch:

1. The runner imports only `cx` (conformance_run.v:3-6) — an `in_json`
   branch was IMPOSSIBLE to write, which is why it is missing. The hole and
   #1126 are the same fact observed from two sides.
2. The if-chain duplicates the registry: the runner maintains its own
   format→parser map while `cx.codec_lookup` holds the same information.
   A registry-driven dispatch (`in-<fmt>` → codec text-parse half) removes
   the hand-list AND makes "unknown section" a decidable, refusable
   condition: section name not matching any registered codec with a text
   parser = hard failure naming the section. The extraction-gate probe and
   CLI lane carry the same hand-maintained format maps
   (probe:427-436/477-483, cli:229-235) — same drift class.

## §6. Orthogonality findings

1. **One registry, two populations.** The base table and the overlay are two
   population mechanisms for one registry, split by build accident rather
   than by decision. After the codec cores land in Ring-0 the overlay's
   remaining legitimate role is genuine runtime extension — which no shipped
   codec uses. Any future overlay registration recreates #1126 silently
   unless the gate gains a registry-parity record (§4).
2. **Two error-conversion directions at one boundary.** json's core returns
   err VALUES converted value→`!` for the registry (codec_node_err), while
   xml/yaml/toml cores return `!` converted `!`→value at the dispatch arms.
   One boundary, both directions — the contract should name one direction:
   cores speak `!` (the registry's native signature), the Ring-1 boundary
   converts to err values via mk_err exactly once, which is also where the
   §9.6 raise-observe hook correctly fires (a core-born err VALUE would
   bypass observation today — mk_err_quiet exists precisely because the hook
   is evaluator territory).
3. **Format capability maps are hand-maintained in four places** — the
   conformance runner (§5), the extraction-gate probe, the extraction-gate
   CLI lane, and `convert_text_format_names` (vcx/cmd/main.v:1265, monolith
   cmd only, so the data binary can't even print its own format list). The
   registry is the single source all four should read.
4. **Profile-invariant constants claiming profile-variant capability.**
   `cx_features` (§4) — the mask needs to compose from what is actually in
   the build (bit 23 already shows how) or be attested per artifact.

## §7. Issues touched / to file

| # | Disposition |
|---|---|
| #1126 | ruled here (CR-1/CR-2); execution this wave |
| #1127 | ruled here (CR-4); execution this wave |
| #1128 | ruled here (CR-5); json half rides CR-1's rework, toml half is mechanical |
| #1129 (filed): cx_features false capability claim in libcx-core | bug, area:cx-lang, prio:high — direction ruled in CR-6, execution this wave per the prio:high standing policy |
| #1130 (filed): registry-parity record in the extraction gate | bug, area:cx-lang, prio:medium — ruled in CR-3, execution this wave |
| #1131 (filed): R2.2 release gate never loads the staged library (PGC-1 residue) | design, area:cx-lang, prio:medium — direction in CR-3, execution deferred to the release lane (touches the blocking cut gate; not this wave) |
| data-profile CLI refusal rationale + hardcoded help prose | rides CR-3's execution (#1130 — registry-derived list lifted to cli/) |
| OPEN LETTER (not auto-ruled): should fmt/lint/code-tree join the data profile's verb set now that all three impls are Ring-0? | surface expansion on a shipped profile — owner call, posed in the session summary (CR-7) |
| #1132 (filed): wasm control-surface split across the ring line | design, area:cx-lang, prio:low |
