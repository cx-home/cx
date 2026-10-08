# `third_party/suites/` — the published conformance corpora

`make conformance-suites` (`scripts/conformance_suites.cx`, cx-private#1840)
runs these through the built cx's standard library and grades the run against
`scripts/conformance_suites.cxd`. Every file here is a verbatim copy of its
upstream at the commit named below; nothing is edited. Where only part of a
repository is kept, the table says which part.

| Directory | Upstream | Commit / version | License | Kept |
|---|---|---|---|---|
| `jsontestsuite/` | https://github.com/nst/JSONTestSuite | `1ef36fa01286573e846ac449e8683f8833c5b26a` | MIT (`LICENSE`) | `test_parsing/` (318 files: `y_` accept, `n_` refuse, `i_` implementation-defined) |
| `toml-test/` | https://github.com/toml-lang/toml-test | `ff49d109861c1ad25af53f687f2aef19ab650600` | MIT (`LICENSE`) | `tests/files-toml-1.0.0` and the 917 files it lists (`valid/` with the tagged-JSON answers, `invalid/`), at their `tests/` paths |
| `yaml-test-suite/` | https://github.com/yaml/yaml-test-suite (`data` branch) | `6ad3d2c62885d82fc349026c136ef560838fdf3d` (license from `main` `da267a5c4782e7361e82889e76c0dc7df0e1e870`) | MIT (`License`) | per case `in.yaml`, `in.json`, `error`, `===` (402 cases) |
| `unicode-16.0.0/` | https://www.unicode.org/Public/16.0.0/ucd/ | UCD 16.0.0 (the version cx's case tables pin) | Unicode License v3 (`LICENSE`, unicode.org/license.txt) | `UnicodeData.txt`, `SpecialCasing.txt`, `CaseFolding.txt` |
| `re2-search/` | `re2-search.txt` from https://github.com/golang/go `src/regexp/testdata/` — RE2's own `make log` output (https://github.com/google/re2) | Go `21bcca17dca7136155524ef46a88312ee23e20e7`; RE2 license from `2da0056814cf180480a19f5cf811e7e1c054bf6d` | BSD-3-Clause (`LICENSE` Go, `RE2-LICENSE` RE2) | `re2-search.txt` |
| `csv-spectrum/` | https://github.com/max-mapper/csv-spectrum | `d30e80f8b99d2eecb3778f1d7b9ed1cb425502ec` | BSD-2-Clause (declared in `package.json`; the repository carries no LICENSE file) | `csvs/`, `json/`, `readme.md`, `package.json` |

To move a corpus: copy the new upstream files in their place, update the
commit here, run `cx --allow-read --allow-write scripts/conformance_suites.cx
--record`, and give every new failure a `[known]` row with its owner (an open
issue, a ruling, or an upstream defect).
