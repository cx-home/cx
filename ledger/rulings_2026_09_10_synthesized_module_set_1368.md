# RULED: 1368-a — the synthesized codec modules become a fourth ENUMERATED set; `codec.md` §3 is their normative text

**Fable, 2026-09-10 06:35Z, under the owner's delegation** (letters drafted by
worker A on #1368; owner may override on #1354): 1(a) and 2(c). Refused 1(b)
and 1(c) — both pay for gate coverage by deleting the synthesis's one property,
that the codec surface cannot drift from the registry, and (c) also leaves four
fifths of the gap open behind one fixed symptom. Refused 2(a) — a widened
SPEC_SET glob is more machinery than the single `modules/cx.md` case needs;
refused 2(b) — four new spec documents restating four derived verbs is the
drift surface the synthesis exists to avoid.

## What was wrong

`register_bundled_codecs` (`vcx/code/stdlib_bundle.v:535`) is a **fourth
module registration path** that no gate enumerated. Five modules —
`cx`, `xml`, `yaml`, `toml`, `md` (`bundled_codec_module_names()`, `:472`) —
ship as `[?lib 'cx-stdlib/<m>']`-resolvable modules whose source is
*synthesized* from the codec registry (`codec_module_source`, `:491`), with no
file on disk.

Three scripts assumed a module is a file:

- `scripts/gen_guide/stdlib_docs_check.cx:78` — the `[fn-doc]` grader run by
  `guide-check` — globs `stdlib/*.cx` + `x/*.cx` only.
- `scripts/gen_guide/guide_build.cx:945-946` — the guide renderer — the same
  two globs.
- `scripts/stdlib_catalog_gate.cx` — `SPEC_SET == (BUNDLE_SET ∪ DISPATCH_SET)`,
  where SPEC_SET globs `spec/03-approved/std-lib/*.md` (`:55`) and BUNDLE_SET
  globs `stdlib/*.cx` (`:64`).

`stdlib_dispatch.v` has **zero** `<m>_stdlib_builtin` hits for all five, and
none of the five has a `stdlib/<m>.cx`. So the five sat in **none of the three
sets**: the catalog gate was not exempting them, it could not see them, and its
invariant held vacuously while five live modules shipped ungraded. That is the
defect — a missing SET, not a missing file. The issue's premise that adding
`stdlib/cx.cx` would be blocked by the resulting SPEC_SET obligation is
inverted: that obligation is the accounting the fix creates.

## What is ruled

**1(a).** Both fn-doc graders and the catalog gate learn the synthesized set.
The catalog gate's invariant becomes

```
SPEC_SET == (BUNDLE_SET ∪ DISPATCH_SET)          (unchanged, directions 1–2)
SYNTH_SET == CODEC_SET − (BUNDLE_SET ∪ DISPATCH_SET)   (new, directions 3–5)
```

and the graders read a synthesized module's source **from the synthesizer**,
never from disk.

**2(c).** SYNTH_SET modules are **exempt from SPEC_SET**: `codec.md` §3 is
their normative text, being what the synthesis is generated from.
`spec/03-approved/modules/cx.md` stays where it is — it carries `cx`'s
genuinely larger surface (§2.1's self-host core, §2.2's `carries-err`) and is
already replayed by `docs-check`. No spec sentence moves, so no spec-side
`RULED:` token is owed; this record is the ruling's home.

**The source surface** is a tooling verb on the CLI, not a language builtin:
`cx stdlib source MODULE` prints the exact source the loader registers (disk-
backed or synthesized alike) and `cx stdlib list --synthesized` names
SYNTH_SET. The graders and the catalog gate call those verbs, so a fifth
registration path tomorrow shows up in the list or reds the gate.

**Rider (i), load-bearing:** the synthesizer emits an `[fn-doc]` per verb from
ONE template, the codec name interpolated. Without it 1(a) makes the fn-doc
graders red on five modules for want of docs, and hand-written docs per codec
would be the drift surface again. No `[example]` is emitted: only `cx` and
`xml` of the five have a `conformance/stdlib/*.cxd`, and an unbacked example is
exactly the drift the graders exist to catch.

**Rider (ii), load-bearing:** a red-proof. The catalog gate must FAIL when one
synthesized name is removed from the enumeration — the set exists to be
checked, not listed. Hence SYNTH_SET is compared against an **independent**
basis, `text_codec_module_names()` (the non-dialect text codecs of the codec
registry), rather than against itself; `Codec.dialect_of` carries `codec.md`
§4's "TSV and PSV are dialects" sentence into the registry so §6's calls have
one source of truth.

## How it is verified

`lane_A_1368`, port-free, all rows at one sha. Three red-proofs, each shown to
fire and each restored:

- **(3)** drop `md` from `bundled_codec_module_names()` (a rebuild — the
  enumeration is compiled in) → the gate must refuse and NAME `md`.
- **(4)** create a temporary `stdlib/xml.cx` → `[orphan synth]` must fire.
- **(5)** create a temporary `spec/03-approved/std-lib/xml.md` with a
  `status=current` `[module-meta]` → `[synth + spec page]` must fire.

The gate must be green on the fixed tree before the first proof and green again
after the last: a red-proof that does not restore has proved the break, not the
fix.
