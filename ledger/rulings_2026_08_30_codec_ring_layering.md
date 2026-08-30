# Rulings — the codec/Ring layering (#1126 #1127 #1128)

2026-08-30, release/0.18. Companion to
`ledger/audit_2026_08_30_codec_ring_layering.md`, which carries every
measurement cited here. Recorded BEFORE any implementation, per the ledger
discipline. Recommendations verified against the long-term-best bar under
the standing letter-acceptance ruling (2026-08-05); one item did NOT clear
the bar for auto-ruling and is posed as an open letter (CR-7) instead.

Prior rulings honored: TF-3 (the codec layer stays core and uniform; a
format earns a dedicated MODULE only on format-intrinsic verbs — this file
moves no module boundary), #1077 (the full option space is surfaced per
item), R2.2/I4 (nothing here changes a profile's contents at the cut
without the gate seeing it — CR-3 makes the gate see MORE).

## CR-1 — where a codec's parse/emit core lives (#1126) (RULED: CR-1 = a)

The registry (Ring-0, read by the CLI, the C ABI, and convert_by_name)
carries json with emit only and does not know html/url; the overlay that
completes it runs only in artifacts that link `code`. Audit §1–§3: the
three cores' ONLY Ring-1 dependency is error-value construction; codec.md
§4 lists all three as mandatory codecs, §5 classifies codecs pure, §6
mandates one registry; partition §4 gives the data profile
`parse/emit/convert` over untrusted input. Options, full space per #1077:

- (a) **TAKEN — every registered codec's text parse/emit core is Ring-0 by
  contract; the three cores move to `vcx/cx/`.** The strict json parser
  (stdlib_json.v lines ~1–877 — measured: zero cross-file `code` symbols),
  the html parse/serialize cores, and the url parse/build cores move into
  the Ring-0 module; the base codec table registers all three directly; the
  Ring-1 stdlib modules become wrappers over the cx cores (module verbs,
  argument extraction, err-value conversion — TF-3's layer-2 verb richness
  is untouched). This is not new doctrine; it is what codec.md §5/§6 and
  partition §4 already say, executed. The overlay mechanism REMAINS as the
  runtime-extension seam (pub register_codec is surface), but no shipped
  codec uses it after this — and CR-3 makes any future overlay use visible
  at the gate instead of silent.
  - Small carried facts: `cx_decimal_image_from_json_number` (Ring-0,
    audit §2) stops being a cross-ring one-off and becomes an internal
    call; peer helpers (`utf8_validate`, `utf32_to_str`) move with their
    callers; no identifier collisions exist in vcx/cx for the moved types
    (verified).
- (b) Keep the layering; make libcx-core's refusal name the profile;
  document the difference — rejected AS THE RESOLUTION: it documents a
  broken contract instead of honoring it (partition §4's data row promises
  parse/convert; codec.md §4 says mandatory; the §8 freeze covers the
  libcx-core ABI, and nine exported `cx_json_to_*` symbols currently fail
  at runtime). Its refusal-shape half is ABSORBED as a general rule: any
  capability genuinely absent from a profile (evaluator verbs today,
  future Ring-1-only codecs if one is ever ruled) refuses NAMING THE
  PROFILE and what carries the capability — never "the registry has no X",
  which reads as misconfiguration.
- (c) Rule the data profile a reduced codec set — rejected: it inverts the
  product (the data profile's whole pitch is conversion of untrusted
  input; json is the single most common ingest format), contradicts three
  normative texts at once, and would make #1115's html/url registration a
  monolith-only feature by accident of file placement.
- (d) Build the data artifacts from `code/` with the evaluator compiled
  out — rejected: cannot-execute is ruled as a property of the ARTIFACT
  (partition §4), and Ring-0's strict-sink import contract (§3) is the
  security posture for the untrusted-input profile; weakening either to
  avoid moving three pure files is backwards.

**Revisit trigger:** a future codec whose parse core has a REAL Ring-1
dependency (not error style). If one appears, it registers via the overlay,
CR-3's parity record shows it differing between artifacts, and THAT is the
moment option (c) gets ruled for that codec by name — deliberately, at the
gate, not by omission.

## CR-2 — one error conversion, one direction (RULED: CR-2 = a)

Today the ring boundary converts err shapes in BOTH directions: json's
core returns err VALUES converted value→`!` for the registry
(codec_node_err), while xml/yaml/toml cores return `!` converted `!`→value
at the dispatch arms (audit §6.2).

- (a) **TAKEN — codec cores speak V `!` errors; the Ring-1 boundary
  converts to err values exactly once, via mk_err, at the dispatch/module
  layer.** The `!` message carries the TF-9 contract shape (`cx-err:CODE
  CLASS: [location: ]message`) so the CLI/ABI surface it verbatim. This
  direction is forced, not chosen for taste: the §9.6 raise-stage observe
  hook (fire_raise_observe) is evaluator territory and fires when the err
  VALUE is born — a core-born err value in Ring-0 would either bypass
  observation or drag the hook below the evaluator. mk_err stays Ring-1;
  Ring-0 never constructs err elements. codec_node_err is deleted with the
  move; json's registry adapter inversion (the #1120 code-drop fix)
  becomes structurally impossible to regress.
- (b) Move mk_err's data shape to Ring-0 and let cores return err values —
  rejected: splits err-value construction from its observation hook, so
  hook coverage would depend on which layer built the value — a new silent
  divergence class, replacing the one being removed.
- (c) Leave both directions — rejected: two conversions at one boundary is
  how json alone dropped its code one frame from the surface (#1120).

## CR-3 — capability parity becomes a property the gates check, not an
accident fixtures reach (RULED: CR-3 = a)

Audit §4: every divergence gate is fixture-reachability-shaped; the corpus
has zero `[in-json]` sections; the probe's `in_json` battery has never
fired; profile_gate delegates the data profile to the extraction gate;
R2.2 never loads the library it stages. The circularity (no json fixtures
because the cx-only runner couldn't parse json) dissolves with CR-1, but
the CLASS survives: anything registered via the overlay is invisible again.

- (a) **TAKEN — an artifact-intrinsic registry inventory joins the
  extraction gate's byte-identical transcript.** One Ring-0 ABI entry
  (cabi.v) renders the sorted codec inventory — name + which of
  parse/parse_bytes/emit/emit_bytes/lossless are present — and the probe
  records it once, before the corpus walk, in both artifacts' transcripts.
  The `cmp` then fails on ANY registry divergence with zero fixtures
  required, the day it appears. Costs: +1 symbol in the frozen surface
  baseline + cx.h (additive), one deliberate re-bless of the pinned
  verdict digest. The CLI lane analogue: `convert_text_format_names` lifts
  from `cmd/` into the shared `cli/` layer so BOTH binaries derive their
  format lists from the live registry (killing cmd_data's hardcoded prose
  that advertises json reading, audit §4) and the extraction-gate CLI lane
  compares the printed lists.
- (b) Fixture-level closure only (add `[in-json]` cases) — rejected as the
  resolution (taken as a COMPONENT of CR-4): it closes today's instance,
  not the class; a capability with no case stays invisible.
- (c) Leave gate coverage as-is — rejected: #1126 was found by accident
  during unrelated work; the shipped artifacts diverged for an unknown
  period with every gate green.

**Sequenced, not dropped:** the R2.2 release-lane check (dlopen the staged
libcx-core and read the same inventory) is the same primitive at the cut.
It touches the blocking release gate, so it lands as its own filed issue on
the release lane, not in this wave.

## CR-4 — the vacuous-pass hole (#1127) (RULED: CR-4 = a, registry-driven)

- (a) **TAKEN — the runner's input dispatch becomes registry-driven and an
  unknown `[in-*]` section is a HARD FAILURE naming the section.**
  `in-<fmt>` resolves through `cx.codec_lookup(fmt)` to the text-parse
  half (the runner imports cx; after CR-1 that covers json/html/url too);
  a section naming no registered text parser fails the case loudly. This
  removes the hand-maintained format map (one of FOUR copies of the same
  map, audit §6.3) rather than extending it — the same fix shape #1116
  applied at the dispatch layer. Minimum new fixtures: `[in-json]` cases
  pinning parse + refusal (which also makes the extraction gate's dormant
  `in_json` battery fire for the first time), plus the conversions.cxd
  header comment (which documents the old impossibility) updated.
- (b) Add `in_json` only — rejected: the missing branch is worth less than
  closing the hole; the next section kind reopens it.
- (c) Leave it — rejected: a runner that reports PASS for a case it did
  not run undermines every count it produces (the corpus is the executable
  truth).

## CR-5 — refusal locations, the #1128 gap (RULED: CR-5 = a)

- (a) **TAKEN — json's line:col rides CR-1's move** (the error-shape
  conversion touches every refusal site in the reader anyway; doing
  position threading separately would mean two passes over the same
  sites), **toml's rides this wave as its own mechanical item** (TReader
  gains line/col in advance(), threaded through toml_parse_error — the
  same treatment the XML reader has). json.md §5's error shape gains the
  position; codec.md §3.1 invariant 4 becomes true in every lane.
- (b) Do positions later, separately — rejected: sequencing waste (json's
  sites are all being edited this wave) and it leaves the TF-9 contract
  half-true across another cut for no gain.

## CR-6 — cx_features must tell the truth per artifact (RULED: CR-6 = a)

Audit §4: libcx-core returns the monolith's static mask — bits 28/30/31/
34/35/38 and half of 41 claim capabilities whose symbols are absent.
abi.md §3 says bindings refuse/degrade based on this mask. Filed prio:high;
per the standing policy (prio:high fixed ASAP in-line), execution rides
this wave.

- (a) **TAKEN — the mask composes per build**, the way bit 23 already
  does: the lib-core recipe passes a build flag (e.g. `-d cx_ring0_only`)
  and cabi.v's mask arm clears the evaluator-family bits (28/30/31/34/35/
  38) and bit 41 (spec: set only when BOTH halves ship; core has only the
  columnar half). Attestation follows the same both-directions rule the
  monolith gate uses: the extraction gate asserts, per artifact, that
  mask-bit ⟺ dlsym agreement holds for the symbol-gated bits (the mask is
  NOT put in the cmp'd transcript — the two artifacts' masks legitimately
  differ). The stale cabi.v comment naming a nonexistent gate file is
  corrected in passing.
- (b) Derive the mask at runtime from registration (overlay-style) —
  rejected: reintroduces init-order-dependent capability state, the exact
  mechanism class this campaign is removing.
- (c) Document that libcx-core's mask is advisory — rejected: abi.md §3
  makes it load-bearing for every binding; "advisory" is a euphemism for
  false.

## CR-7 — the data profile's verb set (RULED: CR-7 = a, BY OWNER 2026-08-30)

Posed as an open letter (surface expansion on a shipped profile is a
product call, not a defect); the owner ruled **(a)** in-session: fmt, lint,
and code-tree join the data profile's verb set. All three are pure Ring-0
implementations; cannot-execute is untouched; the library/CLI asymmetry on
code-tree disappears. Execution notes: `fmt --migrate-predicates` reaches
the code layer and is NOT part of the data profile — the flag refuses
naming the profile; partition §4's verb table and §2's stale fmt/lint
sentence are corrected with the RULED token; the profile/extraction-gate
refusal rosters that list these verbs as absent are updated in the same
change. Original letter text below for the record.

fmt, lint, and code-tree are pure Ring-0 implementations today (audit §4;
partition §2's "fmt/lint are Ring-1" is stale), libcx-core already EXPORTS
`cx_code_tree`, yet the data CLI refuses all three with a factually wrong
rationale ("no evaluator"). Two separable pieces:

- **Ruled here (defect class):** the refusal RATIONALE becomes honest —
  "not in the data profile's verb set" — and partition §2's stale
  fmt/lint sentence is corrected to describe where the impls live. Rides
  this wave.
- **Posed, not ruled (surface expansion):** whether fmt/lint/code-tree
  JOIN the data profile's verb set. This expands a ruled, shipped
  profile's surface (§4 verb table) — a product decision, not a defect,
  and the standing letter-acceptance bar is for recommendations, not for
  growing frozen-adjacent surface. Options for the owner:
  (a) add all three (they are Ring-0 pure; the ABI/CLI asymmetry on
  code-tree disappears; the data profile becomes the complete "inspect
  and normalize CX text" tool),
  (b) add code-tree only (fixes the one artifact-internal asymmetry —
  the library exports what the sibling CLI refuses),
  (c) keep the verb set as ruled.
  My recommendation is (a): the verbs are pure functions of their input,
  the cannot-execute property is untouched, and a data-profile adopter
  who can parse/validate but not fmt/lint the same text has to install
  the full CLI for a capability their artifact already contains.

## CR-8 — the ABI conversion surface (#1133) (RULED: CR-8 = a, BY OWNER 2026-08-30)

Matrix row D13, the one UNJUSTIFIED divergence the matrix surfaced:
codec.md §6 says the ABI exposes the registry, not bespoke `cx_X_to_Y`
functions; the shipped ABI is the inverse, and md/html/url have no ABI
conversion path at all.

- (a) **TAKEN (owner, in-session)** — ONE registry-generic ABI entry
  (from-name + to-name + payload → converted text; a bytes variant if the
  binary codecs warrant it) resolving through codec_lookup/convert_by_name,
  serving every current and future codec including overlay-registered
  ones. The bespoke families are FROZEN legacy sugar: kept (ABI freeze,
  partition §8), documented as legacy in abi.md, never extended to new
  formats. codec.md §6 is amended to state exactly that split. md/html/url
  become ABI-reachable through the generic entry with zero new bespoke
  symbols.
- (b) Bless the families and add md/html/url families — rejected:
  perpetuates the N×M growth this drift class comes from.
- (c) Leave and note — rejected: leaves three registry codecs unreachable
  from every binding.

## Execution order

Rulings (this file + the audit) land first, alone. Then, each with its
issue and `RULED:` token where a spec is touched:

1. CR-1 + CR-2 + CR-5(json): the core moves, boundary conversion, json
   line:col (#1126, #1128-json).
2. CR-4: runner dispatch + in-json fixtures + conversions.cxd comment
   (#1127) — after 1 (the runner needs the Ring-0 parser).
3. CR-3: inventory ABI + probe record + digest re-bless + CLI-lane list
   derivation + cmd_data prose/rationale fix (#1130).
4. CR-5(toml): TReader positions (#1128-toml).
5. CR-6: per-build mask + agreement attestation (#1129, prio:high).
6. Spec touches, each with RULED: token: cx_partition.md §2 (Ring-0
   content wording: codec text cores; fmt/lint sentence per CR-7's ruled
   half), json.md §5 (position in the error shape), abi.md §3 (core-build
   mask statement).
7. CR-7 (ruled a): fmt/lint/code-tree wired into cmd_data + honest refusal
   text for what stays absent + partition §2/§4 corrections (RULED: CR-7)
   + gate refusal-roster updates. Sequenced after CR-3's cmd_data touches
   to avoid file conflicts.
8. CR-8 (ruled a): the registry-generic ABI conversion entry + codec.md §6
   amendment + abi.md legacy-sugar framing (#1133) — sequenced after CR-3's
   cabi.v/cx.h/baseline touches (same files).
9. Filed: #1131 (R2.2 lib-load follow-up), #1132 (wasm split, prio:low).
10. NEXT SESSION (owner-scheduled 2026-08-30): the #1119 representation
   design session — Fable 5, design-first per the model policy. Scope
   pinned on the issue.

Exit gate: full `make test`, verdict from the log.
