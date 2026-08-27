# Linguist submission package (#954)

The staged, ready-to-send PR for adding CX to
[github-linguist](https://github.com/github-linguist/linguist), so GitHub's
language bar counts `.cx` / `.cxd` / `.cxs` bytes. **Held until CX clears
Linguist's adoption criteria** — their contribution guide requires evidence
the language is in real-world use across roughly hundreds of unique public
repositories (checked via their `script/check-eligibility` search counts).
Until then, the README's CX badge (`scripts/lang_stats.cx`, refreshed by
`make docs`) is the self-reported number, and `.gitattributes` keeps the
vendored/generated marks honest.

## Why the badge is the only self-report possible

`.gitattributes` cannot put CX on the bar. Linguist resolves
`linguist-language=NAME` through `Language.find_by_alias`; an unknown name
returns nil and `lazy_blob.rb` falls through to ordinary detection, so the
override is silently dropped. Their override docs name the case exactly — a
language "not yet mentioned in `languages.yml` will not be included in the
language statistics, even if you specify … `linguist-language=MyCoolLang
linguist-detectable`". `linguist-detectable` cannot rescue it either:
`include_in_language_stats?` gates on `!vendored? && !documentation? &&
!generated?` and a resolved `language` *before* it consults detectability.
There is no self-registration path; the submission below is the only one.

The `*.cx` / `*.cxd` / `*.cxs` overrides are nonetheless committed in
`.gitattributes` **ahead of** the submission. They are inert today and cost
nothing, and they mean the public bar becomes truthful the moment the PR
merges — no follow-up commit, and no chance of the claimed extensions
drifting from the submitted ones.

One override *does* land today, and it settles the other half of the bar
#954 measured: `*.v linguist-language=V`. V is a registered Linguist
language (`language_id` 603371597, alias `vlang`), and `.v` is contested
enough that their disambiguation heuristic was filing `vcx/` as
**Verilog**. The explicit override bypasses the heuristic, so the bar
reports the V bytes as V — agreeing with `scripts/lang_stats.cx`, which
buckets `.v` the same way.

## What the PR needs (all staged here or already shipped)

1. **`languages.yml` entry** — `languages.yml.snippet` in this directory.
   Extensions claimed: `.cx`, `.cxd` (conformance fixture documents),
   `.cxs` (schemas). Registry checked **2026-08-25** against
   `github-linguist/linguist@master`: none of the three appears anywhere in
   `lib/linguist/languages.yml`, and `CX` sorts cleanly between `CWeb` and
   `Cabal Config`, as the snippet assumes. Re-verify at submission — the
   registry moves.
2. **A TextMate grammar** — already shipped and maintained at
   `tooling/vscode/syntaxes/cx.tmLanguage.json` (`source.cx`), kept in sync
   by the `check-tmlanguage-sync` gate. Linguist vendors grammars by
   referencing the repository; the public mirror (cx-home/cx) carries it.
3. **Sample files** — Linguist requires representative samples under
   `samples/CX/`. Use PUBLIC-mirror files at submission time (license
   travels with the repo): a data document, a program, a schema — e.g.
   `examples/cxpath-tour.cx`, a `conformance/*.cxd` excerpt, a `.cxs`
   schema. Pick from cx-home/cx, never cx-private.
4. **Eligibility evidence** — run Linguist's `script/check-eligibility`
   (or the documented GitHub search counts) and paste the numbers into the
   PR body.

## Submission checklist

- [ ] Adoption bar met (search counts pasted)
- [ ] Registry re-checked: `.cx`/`.cxd`/`.cxs` still unclaimed
- [ ] `languages.yml.snippet` merged into their `lib/linguist/languages.yml`
      (alphabetical position; `language_id` minted with their
      `script/update-ids`)
- [ ] Samples copied from the public mirror into `samples/CX/`
- [ ] Their test suite green (`bundle exec rake test`)
- [ ] PR references the grammar repo (cx-home/cx) + license
