# Rulings 2026-08-20 — schema-evolution automation (the cut-blocking campaign)

## SEA-1 — the four automation gaps close; sound-refusal-first everywhere

**Status:** RULED (owner authorization 2026-08-20, quoted verbatim: **"the cut
waits until we properly handle schema-evolution."** — the #826 scope amendment's
four automation gaps, with the target sentence as acceptance: *"a feature author
changes a field, publishes, and is stopped ONLY when the change genuinely
reinterprets data — with a specific prompt naming the missing rule. Additive
changes deploy silently."*).

**Ruling.** The stream-21 approved surface (schema_event_evolution.md L146–L153;
journal.md §3.9; the L149 compat predicate "surfaced as `cx schema compat`")
graduates from documented-discipline to enforced automation, in four landings:

1. **`cx schema compat OLD.cxs NEW.cxs`** — the L149 three-valued predicate as a
   shipped Ring-0 verb. Every field-level change classifies into a closed class
   set; the mechanically-derivable classes derive their translator (an upcaster
   document: the Lane-2 `[schema-lineage]` claim + a generated pure upcaster
   def); the reinterpreting classes REFUSE with a specific prompt naming the
   missing rule per change. Normative home: `spec/03-approved/core/schema.md`
   (the compat § the L149 spec-edit map named and never wrote).
2. **Lineage emitted at publish** — `[$xap:pkg-publish]` diffs the new version's
   schema entries against the previous published version's, derives the lineage
   claim mechanically for derivable changes, stores it Lane-2 in the registry
   store, and REFUSES the publish (new `CXER4890`) on a reinterpreting change
   the package does not itself cover with an authored claim. Normative home:
   `spec/03-approved/xap/xap_feature_distribution_market.md` §6/§6.1.
3. **Re-checkpointing under the current fold** — the "named maintenance
   discipline" (L147) gains its verb: `[$journal:resnapshot]` re-derives a
   snapshot at its own at-seq under the CURRENT fold quadruple (fn, init,
   upcast chain, fold-id), signing per §4.8, refusing loudly where unsound
   (pruned prefix, uncovered entries, unsigned tier). `snapshot` itself gains
   `opts.upcast` (without it "snapshot under the current fold" was impossible
   to spell whenever the current fold includes a chain). The CXER4640/4616
   teachings now NAME the verb. Normative home: journal.md §3.7 (additive).
4. **Coverage checked at install** — the L151 coverage pre-flight ("a pure
   query over declared versions × lineage graph") runs inside
   `[$xap:pkg-install]` whenever the installing deployment supplies its
   journal, and REFUSES on gaps (new `CXER4891`) naming every uncovered schema
   address. Same spec home as (2).

No clause weakened anywhere: every existing refusal stays; the automation adds
surfaces and teaches existing refusals better.

**Riders (lettered, sound-refusal-first — recorded, not re-litigated):**

- **SEA-1a (rename is declared, never guessed).** A removed field plus an added
  same-shaped field is mechanically indistinguishable from a rename; deriving a
  rename translator on a guess would silently MOVE data — a reinterpretation.
  `compat` therefore never auto-derives a rename: the candidate pair is named
  in the refusal prompt, and the explicit declaration (`--rename TYPE/OLD=NEW`)
  derives the rename translator. Publishes carry the declaration as an authored
  claim in the package when needed.
- **SEA-1b (the derived upcaster's discriminator).** A derived upcaster rewrites
  exactly the entries whose payload declares `schema=` = the OLD address;
  entries declaring the NEW address pass through; entries declaring a THIRD
  address REFUSE (`[err]` → the seam's loud CXER4641 — stale vocabulary must
  never silently pass); entries declaring NO schema pass through (there is no
  claim to translate — the same posture as the seam's own absence handling).
  Derivation is LOSSLESS by construction: `[?modify]` surgery on the authored
  payload (undeclared/open-mode fields ride through untouched); a derived
  upcaster never enumerates-and-rebuilds.
- **SEA-1c (removal refuses by default).** Dropping a field loses data; the
  default classification is a refusal naming the field. The explicit
  acknowledgment (`--allow-remove TYPE/FIELD`) derives the dropping translator
  (a field-level `[delete-attr]` is payload rewriting, not a shred — the seam's
  never-shred rule binds the WHOLE `[event]` payload). Constraint NARROWING and
  TYPE reinterpretation have no acknowledgment path: they refuse until the
  author supplies a hand-written upcaster via an authored lineage claim.
- **SEA-1d (publish conventions).** The lineage document (claims + derived
  upcaster defs) is stored beside the manifest and aliased
  `<name>@<version>+lineage`. Author-supplied claims ride the package tree in
  entries whose path ends `lineage.cx`; publish verifies their endpoints cover
  the detected old→new pair before accepting a non-derivable change. Changed
  schema files are matched by tree PATH; an added schema file links nothing; a
  removed schema file publishes (feature pruning is legal) — the install-time
  coverage gate still guards any journal history it leaves behind.
- **SEA-1e (install coverage scope).** The install-time query is scoped to the
  package's own history: in-scope journal addresses are those appearing in the
  package's published lineage graph (all `+lineage` docs for the name, plus
  `opts.lineage` claims supplied by the installer), the schema content-hashes
  of ANY published version of the name (so a pre-lineage v1 address is still
  in scope), or a current address; each in-scope non-current address must
  admit the unique lineage path
  to a current address, else the install REFUSES (`CXER4891`). A journal with
  no reachable handle at install time has no history to check — the check is
  vacuous, stated honestly in the spec (an install without `opts.journal`
  checks nothing; deployments that carry journals supply them).
- **SEA-1g (derived translators are DATA, applied natively at the seam).**
  Discovered at implementation: `[?modify]` — the only lossless in-language
  element surgery — is RULED impure (code.md §6.5.0, tables-1a), so a
  *generated pure def* cannot spell a lossless field rewrite, and a lossy
  enumerate-and-rebuild def would shred open-mode content (refused by SEA-1b).
  The two candidate repairs were (i) minting a pure `$cx:modify` twin
  (re-opens the ruled purity classification's rationale and a modify-engine
  refactor) and (ii) carrying the derived rules AS DATA inside the lineage
  claim and applying them NATIVELY at the journal seam. Ruled (ii), the
  sound-refusal-first shape: the translator document is the Lane-2
  `[schema-lineage … [upcaster NAME] [derived root=… RULE*]]` claim itself
  (closed rule vocabulary: `set-default` / `rename-attr` / `drop-attr` /
  `rename-elem` / `drop-elem`), and `{upcast: …}` additively accepts a claim
  (or a `lineage-path`-ordered claim sequence) wherever it accepts a fn chain
  — the engine applies `[derived]` rules losslessly and purely by
  construction; a claim WITHOUT `[derived]` rules refuses `CXER4610` (a
  hand-written upcaster is a fn chain, never guessed from a claim). Chain-wise
  discriminator: an entry's declared address unknown to the claim set refuses
  (the SEA-1b third-address posture, evaluated over the whole chain); absent
  schema passes; each claim applies exactly where the current address equals
  its `from`. The fn-chain surface is byte-identically untouched. journal.md
  §3.9 and schema.md §16.5.2 carry the normative text.
- **SEA-1f (resnapshot idempotence).** `resnapshot` with a declared current
  fold-id equal to the snapshot's own returns the snapshot unchanged — nothing
  landed, nothing re-derives. All refusal codes are EXISTING journal codes
  (4610/4615/4613/4641/4991/4614); no new journal code is minted.

**Gates (new, all enforced):** the compat classification matrix
(`vcx/tests/schema_compat_test.v` — every class → derived translator or named
refusal, plus the derived-translator round-trip: v1 entries fold correctly
under v2 through the GENERATED upcaster); publish-lineage + install-coverage
fixtures (`conformance/stdlib/xap-dist.cxd`); resnapshot identity-preservation
+ refusal fixtures (`conformance/stdlib/journal.cxd`).

**Docs re-taught after implementation (claims live-verified):**
`docs-src/canonical/sections/04a-schema.cxd` (the 4a.2 "has not yet shipped as
a callable check" honesty note → the real verb) and `18c-event-evolution.cxd`
(the manual re-snapshot discipline + coverage pre-flight paragraphs → the
automated path).

---

## Implementation record (appended at landing, same session)

**Landed, all four gaps:**

1. `cx schema compat` — `vcx/cx/schema_compat.v` (Ring-0 pure classifier +
   translator emitter; ships in the monolith AND the data profile),
   `vcx/cli/schema_verbs.v` (the sub-verb; exits 0/1/2 per §16.5.3),
   help in `vcx/cmd/main.v` + `vcx/cmd_data/main.v`. Spec:
   schema.md §16.5 (new) + the §13.3 status truing.
2. Publish-lineage — `xap_pkg_publish_lineage_stage` in
   `vcx/platform/stdlib_xap_dist.v` (prev-version discovery by semver key;
   path-matched `*.cxs` diff; derived claims stored + aliased
   `NAME@VERSION+lineage`; authored `…lineage.cx` claims accepted;
   `CXER4890` refusal carrying `[missing-rule]` prompts). Spec:
   distribution spec §6 step 3 + §6.1 pkg-publish row + error table.
3. Re-checkpointing — `jrn_resnapshot` + `opts.upcast` on `snapshot`
   (single, stream, and SET forms) in `vcx/platform/stdlib_journal.v`;
   `stdlib/journal.cx` def + fn-doc; ring2 impure registration; the
   CXER4640/4616 teachings now name the verb. Spec: journal.md §3.7
   (resnapshot block + snapshot opts.upcast) + §7 matrix row.
4. Install-coverage — `xap_pkg_coverage_gate` in stdlib_xap_dist.v
   (default chain + every named stream; SEA-1e scope; `CXER4891` naming
   every uncovered address + entry count; `opts.lineage` supplements;
   vacuous without `opts.journal`). Spec: §6.1 pkg-install row + error
   table + fixtures §11.19/§11.20.

SEA-1g substrate: the §3.9 derived-chain form — `jrn_chain_check` /
`jrn_chain_derived_claims` / `jrn_upcast_apply_derived` (native, lossless
rule application; chain-wise discriminator; claims-without-rules refuse
`CXER4610`); every chain engagement site (fold/replay/coherence/fold-from/
upcast/snapshot/resnapshot) routes through the one check.

**Gates (all green, this session):** NEW `vcx/tests/schema_compat_test.v`
(12 tests — the full class matrix, SEA-1a candidate-naming, SEA-1c
acknowledgment, determinism); NEW conformance journal-154/155/156
(fn-doc-backed resnapshot; derived chain lossless + third-address CXER4641 +
no-rules CXER4610; resnapshot identity-preservation `fold-from ≡ full fold`
+ idempotence + CXER4610 refusal); NEW conformance xap-dist-051/052
(publish derive/refuse/authored-accept with the stored claim pinned
byte-for-byte; install covered/gap/opts.lineage/vacuous). Lanes:
code_eval_fixtures (stdlib corpus incl. the new fixtures),
platform_journal_umbrella, platform_misc_umbrella, xap_umbrella (repo-root
cwd), stdlib_umbrella, lexicon_surface_umbrella, cli_umbrella,
http_h2_serve, cxparse_full_corpus_diff — all 1 passed/0 failed;
guide-check OK (58 modules, example backing green); verify-doc-blocks
361 passed/0 failed; verify-doc-links 230+1420+68 / 0 failed; guide
rebuilt, rendered claims spot-verified.

**In-line find (pre-existing, fixed):** the `-prod` lib build at the
release-cut tip refused `vcx/platform/http_h2_serve_notd_wasm32_emcc.v`
(two map-of-pointer-array appends without `or {}` — the stricter -prod
checker; dev builds passed). Fixed with the explicit read-modify-write
idiom; http_h2_serve lane green after.
