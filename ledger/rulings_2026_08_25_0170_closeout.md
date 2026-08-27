# Rulings — v0.17.0 close-out campaign (2026-08-25)

Owner reply: "1a 2a 3a 4a 5a 6a — and #963 (a)", conditioned on long-term-best
per the standing letter-acceptance policy; each recommendation re-verified
against that bar before recording (CO-2 carries the one honest refinement the
verification produced). Context: the downstream (sponsor) v0.16.0 feedback,
verified against `release/0.17` HEAD and filed as #974–#979; evidence comments
on each issue.

## CO-1 (#974, ruled 1a) — store multicodec read-compat

A cxpack pack entry whose hash-multicodec slot reads `0x0000` is accepted as
the sha2-256 it implicitly was: v0.15's writer emitted a literal reserved `0`
in that slot, so zero MEANS sha2-256 for every pack that can legally exist.
Readers accept exactly {0x0000, 0x0012}; every other code still fails closed.
On the first write to a store containing zero-slot entries, the writer stamps
them forward to 0x0012 in place (the slot is covered by no CRC/signature —
the I1 in-repo migration already relied on this). Gate: a committed
v0.15-shaped pack fixture (the 5-byte zeroing witness from the #974
verification) must open, read, AND accept a republish, forever. CHANGELOG
erratum under [Unreleased] correcting the v0.16.0 "stored formats are
unchanged" claim (published notes are a separate artifact and are not
rewritten).

## CO-2 (#975, ruled 2a) — refusals refuse at the EFFECT boundary

**No frozen matrix cell moves.** The measured collection-literal member cells
(paren sequence, array literal, map literal: an [err] member rests as data,
construction succeeds) are CONFIRMED as ruled — err-as-value composition is
load-bearing (stdlib/supervise's `([sup-note …], $err)` pair transits channels
as data; the #853 position table stands). The new rule is additive and lives
where the value leaves the program: **an effect that externalizes a document
containing an [err] element at any depth refuses** — `[out …]`, store writes,
http response emission — with a typed refusal naming the first contained err's
code and path, **unless the effect names the permission explicitly**
(attribute `errs=:permit` on the effect form; exact spelling settled at spec
time, one spelling for all three effect families). Pure functions are
untouched: `$format:*` over a document containing [err] stays legal (rendering
an error to log it is legitimate); channels, bindings, matching stay legal.
This closes the downstream `written=0 errors=25`-with-exit-0 class and the
err-into-HTML escape at the only honest place: the boundary. Spec text lands
in the effects section; conformance: one refusal case per effect family + one
:permit case + the supervise-pair regression pin (channel transit of an err
stays data). Spec edit authorized by THIS ruling (RULED: CO-2).

## CO-3 (#978, ruled 3a) — $format:pretty becomes round-trip faithful

Strings stay quoted (the documented `string-quote` option semantics);
non-string scalars are NEVER quoted by pretty (or diff-friendly, which shares
the fault). This restores the module's own normative claim
(stdlib/format.cx:30 "every form round-trips"). The pretty↔canonical quoting
divergence that remains (pretty always-quotes strings; canonical bare-when-
safe) is documented in the module doc + spec. Pin: for each formatter form,
parse(format(v)) is structurally equal to v; plus the score=1.5 regression
witness. The "started quoting" downstream claim is recorded as refuted
(quoting is v0.8.0-original; archaeology in the #978 evidence comment).

## CO-4 (#979, ruled 4a) — release-ness derives from HEAD==tag

`cx version`'s headline stamp derives release-ness from git state at build
time: HEAD exactly at the annotated release tag matching repo-root VERSION and
a clean tree ⇒ `cx v0.17.0`; anything else ⇒ `cx v0.17.0-dev+<commit>`
(pre-release ordering is semantically correct: unreleased source IS a
pre-release of VERSION). No second hand-maintained value — VERSION + git
state only (the derive-don't-multiply rule). Wired into the version-stamp
derivation consumed by scripts/release.sh BEFORE the v0.17.0 tag, so the
0.17.0 artifacts are the first honest ones. The commit/-dirty/V-fork lines
stay as they are.

## CO-5 (#969, ruled 5a) — clean-state bootstrap = offline identity mint

A shipped verb mints an XSP principal OFFLINE: generates an ed25519 seed,
derives the DID (`$did:key-create` — the primitive already exists), writes
the seed to a file the operator controls (0600; never stdout by default),
and prints (i) the `[grant …]` stanza to splice into the daemon's
`[xsp [grants …]]` table and (ii) the client's `xsp-did` + `xsp-seed-env`
usage. Config remains the SOLE authority; nothing transits a wire; no
trust-on-first-use machinery; no bearer minting (G1a–G3a stand). Ships in the
platform profile beside store-serve. Docs: a clean-state bootstrap walkthrough
(mint → grant in config → start deny-by-default → client presents), replacing
the out-of-band shrug #968's corrections currently state. Naming settled at
implementation next to the existing verb family; spec addition authorized
(RULED: CO-5).

## CO-6 (#968 riders, ruled 6a) — retired verbs name their retirement; CSRP-era store docs get their own issue

(i) On top of #970's unknown-verb guard: a retired-verb list so `cx
store-token` (and future retirees) answers "retired at v0.16.0; credentials
are XSP-AUTH principals; see #969's successor" instead of "unknown
subcommand" — the #426 lesson applied to retirement. The cmd_data
`absent_profile_verbs` entry and its extraction-gate pin move consistently.
(ii) The CSRP-era content in docs/dev/store-service.md +
docs/dev/store-management.md beyond store-token (four auth providers,
bearer-in-URL, RBAC-gated ops) is filed as its own docs issue.

## CO-7 (#963, ruled (a)) — EXECUTED

The three agent branches verified FULLY LANDED (11/11 commits rebased twins;
9 patch-id-identical; 2 resolved to base drift + upstream conflict-marker
cleanup; 338 paths, 0 absent; ledger content byte-identical) are deleted,
worktrees pruned, #963 closed. Evidence chain on the issue.

## AMENDMENT 1 (2026-08-25) — CO-2 scope resolutions from implementation

1. **The "[out …]" family is vacuous on the current surface**: there is no
   `[out]` effect form — the fixtures that used the name used it as a plain
   element. The run-surface print is deliberately NOT a refusal point (it is
   how errors are inspected; a top-level err already exits nonzero). Recorded
   in commands_effects.md §7.5 so the ruling's scope stays honest.
2. **Guarded store family named precisely**: put-doc, put-doc-stream,
   put-doc-text (stores a PARSED document — not an opaque byte write), and
   modify-doc (the action payload is the injection vehicle). Blob and
   string/bytes file writes exempt by construction. The store verbs grow an
   optional trailing `$opts::map {}` (the existing pull/status idiom) as the
   `errs=:permit` carrier — backward-compatible.
3. **http guard site**: cx_response_to_wire — every user-handler lane
   (module serve, [?http-service] resources, xap host adapter routes)
   funnels there; framework-built error wires (mk_wire/xap_wire_cx) bypass
   it and stay loud as they are. A bare [err] handler result previously
   left as a 200 with the err serialized — now the loud 500.
4. **Two adjacent families observed, NOT guarded here, needing their own
   letter**: `$journal:append` (an event that is an err — but the journal
   is arguably exactly where errors belong as events) and `$fabric:emit`
   (a channel-like fan-out — the channel exemption reading suggests exempt).
   Left unguarded; raised as a question rather than slipped either way.

## Second letter batch (owner: "1a 2a 3a", 2026-08-25 late)

### CO-8 (AMENDMENT 1 item 4, ruled 1a) — journal and fabric stay UNGUARDED

`$journal:append` and `$fabric:emit` are NOT err-at-boundary refusal points:
the journal is exactly where error events belong as first-class records, and
fabric emit is channel-shaped fan-out — the CO-2 channel exemption applies.
CONFIRMED exemptions, to be pinned (one fixture each: an err event journals
green; an err value fabric-emits green) with the next fixture-touching commit.

### CO-9 (#982, ruled 2a) — hosted bindings are DEPLOYMENT-DOCUMENT DATA

The hosted-XAP binding surface for `journal:`, `sources:`, `resolver:`, and
`log-reduce:` is the `*.xap.cxd` wiring layer — data in the deployment
document, where the composition spec already places deriver principals — so a
XAP with durable bindings stays "zero server code" (§6.3). The opts map stays
the DIRECT `[$xap:run]` surface; the document is the HOSTED surface; the host
compiles document bindings into the same run opts `xap_run` already validates
(one validator, never two). The #977 opts forwarding for `derivers:` stands as
the direct-run parity path; the document's deriver principals, when bound,
supersede per the composition spec. Spec-edit authorization: RULED: CO-9.

### CO-10 (#969 edges, ruled 3a) — all three mint hardenings

(i) `store-mint-principal` REFUSES an --id whose derived seed-env name
collides with a different id (hyphen/underscore aliasing) — named refusal,
never a silent second seed that does not load; (ii) `--for identity` emits the
daemon-side `[xsp [identity …]]` row so the walkthrough's daemon step becomes
copy-paste; (iii) `--caps` becomes REQUIRED — an explicit authority choice at
mint time, no default. (iii) is a surface change to a verb shipped this
session with no external users: cutover, no dual-accept.

## AMENDMENT 2 (2026-08-26) — CO-4 extension recorded from #984

libcx's `cx_version()` carries version + release state (`X.Y.Z` at a clean
annotated tag, `X.Y.Z-dev` otherwise) and both join LIB_BUILD_ID; **the
commit is deliberately NOT claimed by the library** — measured: tracking it
relinks the -prod dylib ~95 s on every commit incl. no-build-input ones and
reopens the #902 dlopen-mid-write window, while stamping it untracked is the
unfalsifiable-stamp class #666/#979 exist to remove. The ABI has no
provenance surface; `cx --version` is. Implementation decision under CO-4's
stamp semantics, recorded here so it is not re-litigated; owner may override.
spec/abi.md §2.1's cx_version sentence extended accordingly (RULED: CO-4).

## Third letter batch (owner: "1a / 2 = long-term-best, no deferral, no
partial fix", 2026-08-26)

### CO-11 (#990, ruled 1a) — $eq's attribute atomization IS the ruled compare

Two equality notions, both deliberate: `$eq` is VALUE equality under the
settled atomization policy (atomize in compare/arith only), so
`[$eq [u a=1.5] [u a='1.5']]` is true BY DESIGN; canonical/hash are the
type-faithful IDENTITY and already distinguish the forms. The ScalarType
comment claiming "atom never equals string of same characters" is the liar
and is corrected; `$eq`'s fn-doc states the two-notion split; a conformance
pin asserts value-eq true + identity distinct on the same pair, so neither
notion can drift into the other silently.

### CO-12 (#991, ruled full-fidelity) — canonical serialization is BIJECTIVE;
the emitter fixed points that lose a kind are DEFECTS and are repaired now

The settled policy's own sentence ("serialization bijective") mandates it:
measure each divergence first (does float 1.5 truly share a canonical image
with decimal 1.5? does a canonical-quoted date/datetime attribute re-parse
as a string?), and every measured kind-loss is repaired in canonical/compact
— type-faithful images for every scalar kind in every position. Addresses
MOVE where the old image was lossy; per the #976 precedent every movement is
named in the commit and affected pins/goldens migrate WITH the movement
recorded — never silently. Fixed points that measure as NOT lossy (the image
re-parses to the same typed value) are pinned as deliberate instead. No
deferral, no partial fix (owner's words). Spec: canonical.md's image table
gains the per-kind attribute/body forms (RULED: CO-12).

### CO-13 (#1003, delegated disposition, 2026-08-26) — check_capabilities.cx RETIRED

Retire-vs-fix decided against what the script actually covered: its 15-key
EXPECTED was a second hardcoded copy of the harness's roster (which pins the
set in BOTH directions with strictly stronger shape assertions); its headline
claim ("fails when the server and this table disagree") was vacuous — a copy
of a roster is not a reading of one; nothing invoked it. Its ONE unique
assertion (list providers answer [] not null) ported to the harness —
CORRECTED, because the script had been agreeing with a stale README row
(inlayHint has been live since Phase 4.5; pinning the script's claim would
have frozen the drift). probe.cx fixed, not retired: a manual exploration
driver gates nothing by design and is not the vacuous-gate class. The hang's
mechanism (stdlib process: no safe streaming-child primitive; both shapes
deadlock at the 64 KiB pipe boundary, bisected exactly) is filed as its own
prio:high with a named landing.

## Standing scope notes

- Tag gate for v0.17.0 (owner 1a, first message): #973 ✅(f28c43ff9) ·
  #951-disposition · #963 ✅ · #970 · #968 · #957-verify ✅(branch pending
  integration) + the downstream blockers #969 #974 #975 #976. #826 does NOT
  gate the tag (dedicated Fable session follows, ruled 2a).
- #971/#972 (upstream V, linux/os.Process) are next-wave Opus; #834 stays
  excluded (structural dead end, its own issue).

### CO-14 (aggregates numeric policy, owner "2a", 2026-08-26) — AGGREGATES ADOPT THE OPERATORS' DISCIPLINE

The letter (residue of #1017): today `[+ 39.98 1.5e0]` refuses ([cast] is the
only decimal↔float bridge) while `[$sum (39.98, 1.5e0)]` silently returns a
float — a documented §6.5 promotion whose text predates decimal's promotion to
a full semantic kind. RULED (a): the aggregate family ($sum/$min/$max/$avg and
kin) adopts the operators' discipline — mixed decimal+float REFUSES like the
heads; exact families stay exact end-to-end; $avg over decimals yields decimal
via the ruled exact-division rules; §6.5's aggregate rows get the authorized
pass stating all of it (RULED: CO-14). Silent f64 bridging is precisely what
caused #1017, and one numeric discipline everywhere is the orthogonality
objective. CONDITION carried from L44: if $avg's exact division reaches a
non-terminating quotient with no ruled scale/rounding context, the impl STOPS
on that cell and the rounding ruling is taken together with #1044 ($div/$idiv,
same question) — no invented rounding.

### CO-15 (§3.3 pipeline per-stage keys, owner "1a", 2026-08-26) — NARROWING RATIFIED + PER-STAGE ENV IS REAL, NOW

Two halves, one ruling. (1) The #1028 spec correction (held commit: §3.3 stops
promising "same keys as run") is RATIFIED — the five per-stage-incoherent keys
($timeout-ms/$kill-on-timeout, $new-process-group, $check, $encoding) refuse
BY NAME with the tabulated §4.3/§4.5/§4.7 citations; refusal-by-name is the
forward-compatibility mechanism. (2) Per-stage env is NOT deferred (owner:
"why would we push that capability down the road") — it is the one refused key
whose blocker was spelling, not coherence. RULED spelling: a child element of
the stage's opts, `[opts [env {KEY: "value", …}]]` (map value as element
content — legal under the frozen matrix; the scalar-only-attribute rule is
untouched). RULED semantics: override per KEY, applied in the order env-clear
→ pipeline $env → stage [env …], POSIX `FOO=1 cmd1 | BAR=2 cmd2` precedent.
§3.3 therefore names FOUR stage keys: cwd, env-clear, search-path, env — and
this ruling carries the spec-edit authorization for that amendment
(RULED: CO-15). Implementation rides the #1028 per-stage opts machinery;
red-proof + granted-path conformance twins both directions.

### CO-16 (run dispositions + spawn encoding + process spec pass, owner "1b 2a 3b", 2026-08-26)

(1b) #1023: §3.1/§4.3 are AMENDED — `run`'s $capture adopts spawn's FULL
disposition vocabulary (:pipe→capture, :inherit, :discard, file path; CXER4013
semantics), retracting §4.3's "run has no file target" clause. One disposition
vocabulary across all entry points (orthogonality objective; same no-deferral
logic as CO-15). (2a) spawn's $encoding stays VALIDATED-AND-INERT — §4.7 gains
the sentence saying spawn captures nothing so encoding decodes nothing there;
text-vs-bytes stays on each io read per io.md. (3b) the #1034/#1035 drafted
prose (§4.4 descriptor-release contract, §4.7 accepted-set + per-entry-point
scoping) lands BATCHED with the 1b/2a amendments in ONE spec pass, so
§4.3/§4.7 change once. All spec edits under this entry carry RULED: CO-16.
Sequencing: implementation rides after #1047 (same file) integrates.

### CO-17 (exact division context + §6.5 operand sentence, owner "1a 2a", 2026-08-26)

(1a) #1044: the CORE lane REFUSES BY NAME on any non-terminating exact
division — $div (and $idiv's family), and the $avg-over-decimals cell CO-14
reserved (5.00÷3): the refusal names $math:div-decimal as the explicit
precision+mode context. Terminating quotients return exact decimals via the
heads' lane (cx_exact_div scale convention). Refuse-loudly beats a hidden
default context; the co14-017/017a reservation pins FLIP to refusal under this
ruling. (2a) #1045: code.md §6.5's stale operand sentence ("numerically typed
(int/float)") is corrected to state the shipped exact-family discipline per
L44. Both edits carry RULED: CO-17.

#### CO-17 execution note

CO-14's reservation is FLIPPED as this entry directs: `[$avg (1.00, 2.00,
2.00)]` refuses with CXER3002 naming `$math:div-decimal` instead of promoting
to `1.6666666666666667e0` — pins co14-017 (renamed
`…-avg-nonterminating-refuses`) and the umbrella's reserved-cell test flip
with it, and co14-017a's twin message follows the one shared refusal. `$idiv`
needed no rounding ruling and STOPPED on no cell: an integral quotient always
terminates, and §6.5 already rules truncation toward zero, so CXER3002 cannot
arise there — result kind is the exact family's integral representation (int
while it fits i64, bigint past it), the convention floor/ceiling/round already
use. No cell was invented.

#### #1019 disposition — WORKS AS SPECIFIED (existing rulings applied; no new CO)

#1019 reported an orthogonality defect: `cx --ast --compact` refuses (E211) a
resource the evaluator runs, and #1020's comment made it three-way by adding
the walker's best-effort image. Reading the governing clauses closes it as
SPECIFIED — the three lanes are not one surface disagreeing with itself, they
are three readings the spec already distinguishes, each behaving as written:

- **code.md §6.4.1 (element construction).** `attr=VALUE` — `VALUE` is any
  expression, and "at evaluation time `VALUE` MUST reduce to a scalar". The
  constraint is stated AT EVAL, on the reduced value. The evaluator is right
  to accept `[m x=[+ 1 2]]`: the head reduces to `3`, a scalar.
- **lexicon.ebnf §10 (D2, attributes are scalar-only).** The DATA reading has
  no evaluator, so it can only decide the question at PARSE, on the SYNTAX. A
  bracket opener in attribute-value position is refused outright — cx-err:E211
  (cxdm.md §11 E_ATTR_NODE_VALUED). That is the graduated 2026-06-03 rule and
  the whole point of the 037-041 family.
- **code.md §1.3 (the data / program reading).** DATA is a SUBSET of PROGRAM.
  A form the program reading admits is therefore NOT required to survive the
  data reading; the reverse would be the defect. `--ast` is the data reading
  (cli.md §2.2), so its refusal is the contracted direction, not a stale
  strictness.
- **cli.md §2.2 (the bare convert surface).** Conversion is the data reading
  by construction. Nothing on that lane may evaluate, so nothing on that lane
  can apply the §6.4.1 eval-time test.

Precedent: `ledger/rulings_2026_08_20_diagram_wave3.md` — "the SCANNER was
fixed", the module was not contorted. Same shape here: the lane whose
INSTRUMENT was wrong gets fixed, and the ruled semantics of the other lanes
are not bent to match a tool's convenience.

Disposition (option b of the close-out analysis): **no semantic change.** The
residue was orientation, not verdict — a program-shaped resource refused on
the DATA projection reads as one surface contradicting itself. Delivered:

1. `--ast` appends ONE line when E211 fires on a source whose data reading
   carries a registered program directive — "this resource is program-shaped;
   --ast is the DATA projection (cli.md §2.2)". Message-only; the verdict,
   exit code, and every other lane are byte-unchanged. The predicate is
   `cx.source_carries_program_directive`, a LEXICAL twin of
   `code.data_reading_has_program_directive` — needed because the tree the
   latter walks is exactly what E211 prevented from existing.
2. `conformance/core.cxd` 041a-attr-value-call-rejected pins the split as a
   contract: `[m x=[+ 1 2]]` → E211 in the data reading, joining 037-041. It
   is the family's one `code_only` census row (the siblings are both_reject —
   a paren/brace/bare bracket has no head for the program reading to reduce
   either), and the cxparse corpus baseline moves deliberately for it.

The walker's third verdict (#1020's comment) is NOT touched here: it images,
it does not adjudicate, and #1038 is the open item on that image.

### CO-18 (#1042/#1048 dispositions, owner "1a 1a", 2026-08-26)

(#1042 → a) The wasm [?worker]/[?async] capability gap is a NAMED POST-TAG
design item — the honest fixes (cooperative in-engine scheduler for the JSPI
build, or pthreads bundle behind COOP/COEP) are design-track scale; the ten
affected playground examples are honestly marked with reason + remedy, so
nothing ships deceptive. Not a tag blocker. (#1048 → a) math.md is AUTHORIZED
to state the family-wide exact-kind discipline the impl has had since I1 and
CO-14 leaned on: every $math: verb refuses exact-family (decimal/bigint)
operands with CXER3002 — the single carve-out $math:div-decimal (the CO-17
explicit division context); exact arithmetic lives on the CORE heads per L44.
§4.4's "basic ops on decimals" sentence and §4.3's "statistical ops always
return float regardless of input" both fall to that pass; the §5 CXER3002 row
follows. Edits carry RULED: CO-18.

### CO-19 (release-eve letters, owner "1a 2a 3a 4a", 2026-08-27)

(1a) The two approved-spec grant examples the #1059 refusal contradicts are
AUTHORIZED to correct: security.md §3's invocation and journal.md's
--allow-write example move to bare flags, with the scoped form explicitly
named as the TARGET STATE of #1061 (real path scoping) — never silently
dropped. Edits carry RULED: CO-19. (2a) The external registrations (#954
Linguist, #958 nvim-treesitter/mason) are AUTHORIZED for submission
immediately after the v0.17.0 GitHub release is live — the standing owner
stop-point is hereby exercised, not bypassed. (3a) #1062 (--errs=refuse:
CXER0275 discipline applied opt-in to the process result) is RULED IN as a
0.18 design item. (4a) #1060 (the sponsor-side comparison publication) is
DEFERRED until its measurements are re-taken against the released
cx v0.17.0 binary; nothing publishes to the mirror without a further owner
letter.

## Execution notes from the 2026-08-27 pre-tag adversarial audit (Fable)

### CO-8 execution note — the exemption was defeated by its own plumbing

Measured at 9a9ba3c4c: `$journal:append` and `$fabric:publish` refused
CXER0275 on an event carrying an [err] at rest — the journal's ONE internal
store write funnel (jrn_store_put_doc_err → store-put-doc, fabric rides it)
carried no errs=:permit, so the CO-2 store guard fired where CO-8 rules the
exemption. Fixed at the funnel (the permit is the journal family's, stated
once); the CO-8 pins CO-8 promised "with the next fixture-touching commit"
(and which no commit had delivered) land with the fix: journal-160 +
fabric-040, both with the err in a RESTING position (map value as element
content), because a BARE err argument propagates per the frozen #853
position table before append is ever reached — the general rule, not this
exemption, and the reason the pins are shaped as they are.

### CO-18 execution note — the authorized sentence overclaimed; corrected to
the measured roster

CO-18's object was "state the family-wide exact-kind discipline the impl
HAS HAD since I1". Measured at 9a9ba3c4c, that discipline has FIVE exact
carve-outs, not one: abs/floor/ceiling/min/max share the core heads' exact
implementation and answer exactly ([$math:abs 2.50] = 2.50 — four of them
green-pinned in math.cxd since I1), while sign/round/truncate/clamp/gcd and
the statistical verbs refuse CXER3002. math.md §4.4/§5 are corrected to
state that roster (the delegating five named; their siblings' exact-lane
delegation named an OPEN item, never a shipped behavior) — executing
CO-18's object over the measured truth rather than truing the impl down to
an unmeasured sentence (capability regression) or shipping spec prose the
repo's own green pins contradict. Owner may override.

### CO-17 execution note (band) — the narrowing helper saturated

The "int while it fits i64, bigint past it" convention was implemented on
strconv.parse_int, which SATURATES out-of-range input instead of erroring:
every integral image in (i64.max, 2^64) came back a clamped i64.max —
$idiv, $floor, $ceiling, $round; co17-013's operand sat one binade above
the band, so the suite was green. Fixed by round-trip narrowing
(exact_int_or_bigint); the band is pinned. With it, the int-only lane's
overflow cells join the checked discipline the heads already carry
([$div MIN -1], [$idiv MIN -1], [$abs MIN] → CXER3000; int ÷ int computes
in i64, never through f64 — quotients past 2^53 were float-rounded to the
WRONG integer with exit 0), and code.md's "equal wherever they answer"
sentence gains its measured qualifier (over exact-family operands;
div-co17-009 already pinned the int-row divergence the sentence denied).
