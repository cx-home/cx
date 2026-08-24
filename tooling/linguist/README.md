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

## What the PR needs (all staged here or already shipped)

1. **`languages.yml` entry** — `languages.yml.snippet` in this directory.
   Extensions claimed: `.cx`, `.cxd` (conformance fixture documents),
   `.cxs` (schemas). As of 2026-08, none of the three is claimed by any
   language in Linguist's registry (re-verify at submission — the registry
   moves).
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
