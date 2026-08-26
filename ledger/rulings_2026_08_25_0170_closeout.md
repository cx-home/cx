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
