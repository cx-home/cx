# `cx-stdlib/locale` — locale-aware collation, formatting

```cx
[module-meta name=locale tier=A status=current
  [standard ref='BCP 47' title='Language tags']
  [standard ref='Unicode UCA' title='Collation']
  [standard ref='CLDR' title='Locale data']
  [standard ref='ISO 4217' title='Currency codes']
  [standard ref='ICU/LDML' title='Patterns']]
```

**Status:** Current

Normative reference for the `cx-stdlib/locale` sub-package.

---

## §1. Scope

`cx-stdlib/locale` provides the **primitives** layer of CX's internationalization surface:

- **Locale-aware collation** — compare strings per a locale's sort order.
- **Locale-aware number / date / time / currency formatting.**
- **Locale-aware case mapping** — Turkish dotted-i, Lithuanian, etc.

Message catalogs, translation lookup, CLDR plural rules, and ICU MessageFormat live in the sibling module [`cx-stdlib/i18n`](i18n.md). `locale` is one-way depended on by `i18n`; it carries no message-formatting surface.

RTL bidi-aware string operations are explicitly deferred.

## §2. Conceptual model

A **locale** is a BCP 47 language tag — `"en-US"`, `"de-DE"`, `"ja-JP"`, `"zh-Hans-CN"`. The module ships a CLDR-subset catalog as a zero-dependency offline fallback (~50 collation tables; ~80 locales for number / currency / date / time patterns).

### §2.1. Locale-data resolution

Locale data is resolved at runtime in this order:

1. **Explicit override** — `CX_LOCALE_DIR` env var (CLDR/ICU layout) or an open-time option.
2. **System locale data** — system CLDR / ICU when present.
3. **Bundled snapshot** — the bundled CLDR-subset catalog.

This mirrors `cx-stdlib/time`'s tz resolution and the `cx-stdlib/mime` registry model.

## §3. Public function surface

### §3.1. Collation

Collation is pinned to the **Unicode Collation Algorithm (UCA / TR10)** — DUCET plus per-locale CLDR tailorings. Both `collate` ordering and `collate-key` bytes are deterministic and identical across all bindings for a given `(locale, strength)`.

```
[?def collate           scope=public pure [returns int]   ($a::string $b::string $locale::string) ...]
[?def collate-with-opts scope=public pure [returns int]   ($a::string $b::string $opts::map) ...]
[?def collate-key       scope=public pure [returns bytes] ($s::string $locale::string) ...]
```

Returns `-1` / `0` / `1`. `collate-key` produces an opaque UCA sort key — byte-comparing keys yields the same order as `collate`. Keys are safe to persist (e.g. in a `cx-stdlib/store` index).

Opts:

| Key | Default | Semantics |
|---|---|---|
| `locale` | `"en-US"` | BCP 47 locale |
| `strength` | `"tertiary"` | `"primary"` (base only) / `"secondary"` (+diacritics) / `"tertiary"` (+case) / `"quaternary"` (+variants) |
| `case-first` | `"locale-default"` | `"locale-default"` / `"upper-first"` / `"lower-first"` |
| `numeric` | `false` | Treat embedded digits as numbers (`"file2"` before `"file10"`) |
| `ignore-punctuation` | `false` | Skip punctuation in comparison |

### §3.2. Number formatting

```
[?def format-number          scope=public pure [returns string] ($n::any $locale::string) ...]
[?def format-number-with-opts scope=public pure [returns string] ($n::any $opts::map) ...]
[?def parse-number-locale    scope=public pure [returns number] ($s::string $locale::string) ...]
```

```
1234567.89  en-US → "1,234,567.89"
1234567.89  de-DE → "1.234.567,89"
1234567.89  fr-FR → "1 234 567,89"
```

Opts:

| Key | Default | Semantics |
|---|---|---|
| `locale` | `"en-US"` | |
| `max-fraction-digits` | `3` | Round precision |
| `min-fraction-digits` | `0` | Trailing-zero padding |
| `grouping` | `true` | Use group separators |
| `notation` | `"standard"` | `"standard"` / `"scientific"` / `"engineering"` / `"compact"` |

### §3.3. Date / time formatting

```
[?def format-date       scope=public pure [returns string] ($d::date $locale::string $pattern::string) ...]
[?def format-datetime   scope=public pure [returns string] ($dt::datetime $locale::string $pattern::string) ...]
[?def format-date-style scope=public pure [returns string] ($d::date $locale::string $style::atom) ...]
[?def parse-date-locale scope=public pure [returns date]   ($s::string $locale::string $pattern::string) ...]
```

Pattern syntax is the single normative ICU/LDML token table for CX. [`cx-stdlib/time`](time.md)'s `format-with-format` / `parse-with-format` reference this table — the two modules cannot drift on token meaning; `[$locale:format-date]` is the locale-aware variant, `[$time:format-with-format]` is the root / default-locale variant.

Tokens:

- `yyyy` 4-digit year, `yy` 2-digit
- `MM` zero-padded month number, `MMM` short month name, `MMMM` full month name
- `dd` zero-padded day, `d` non-padded
- `HH` 24-hour, `hh` 12-hour, `a` AM/PM
- `EEEE` full weekday, `EEE` short
- `mm` minute, `ss` second, `SSS` millisecond
- `z` time zone name, `Z` offset

```cx
[$locale:format-date $today "fr-FR" "EEEE d MMMM yyyy"]
  # → "mardi 26 mai 2026"
```

Style atoms — `:short` / `:medium` / `:long` / `:full` — emit the locale's conventional date style:

```
en-US :short  → "5/26/26"
en-US :full   → "Tuesday, May 26, 2026"
```

### §3.4. Currency formatting

```
[?def format-currency scope=public pure [returns string] ($n::any $currency::string $locale::string) ...]
[?def currency-symbol scope=public pure [returns string] ($currency::string $locale::string) ...]
```

`currency` is ISO 4217 (`"USD"`, `"EUR"`, `"JPY"`):

```
1234.56  "USD"  "en-US"  → "$1,234.56"
1234.56  "EUR"  "de-DE"  → "1.234,56 €"
1234.56  "JPY"  "ja-JP"  → "￥1,235"
```

### §3.5. Locale information

```
[?def list-locales      scope=public pure   [returns [sequence string]] () ...]
[?def is-supported      scope=public pure   [returns bool]   ($locale::string) ...]
[?def default-locale    scope=public impure [returns string] () ...]
[?def locale-name       scope=public pure   [returns string] ($locale::string $display-locale::string) ...]
[?def language-of       scope=public pure   [returns string] ($locale::string) ...]
[?def country-of        scope=public pure   [returns string] ($locale::string) ...]
[?def script-of         scope=public pure   [returns string] ($locale::string) ...]
[?def text-direction    scope=public pure   [returns atom]   ($locale::string) ...]
```

`default-locale` reads `$LANG` / Windows LCID. `text-direction` returns `:ltr` or `:rtl`.

`locale-name` renders a locale's display name in the requested display-locale, per CLDR:

```
locale-name("de-DE", "en-US") → "German (Germany)"
```

### §3.6. Locale-aware case mapping

```
[?def upper-locale scope=public pure [returns string] ($s::string $locale::string) ...]
[?def lower-locale scope=public pure [returns string] ($s::string $locale::string) ...]
[?def title-locale scope=public pure [returns string] ($s::string $locale::string) ...]
```

Handles locale-specific cases (Turkish `"i"` ↔ `"İ"`, Lithuanian combining-dot, German `"ß"` → `"SS"`). Called by the `cx-stdlib/strings` module's `upper-locale` function (`[$strings:upper-locale]`).

`title-locale` applies per-word title casing under the locale's case rules:

```
title-locale("hello world", "en-US") → "Hello World"
```

## §4. Edge cases and policy

### §4.1. Locale fallback

Lookup falls through: exact match → language match (`"en-US"` → `"en"`) → default `"en-US"` → synthetic minimal data. `is-supported` returns true at any fallback level.

### §4.2. Numeric sort gotcha

`collate("file10", "file2", "en-US")` returns `-1` lexicographically by default. Set `numeric=true` for natural sort.

### §4.3. Shared pattern syntax with `time`

`format-date` and `cx-stdlib/time/format-with-format` use the same ICU/LDML pattern (§3.3). The split is locale-data, not syntax. `time` retains a parsing-only `parse-strftime` escape hatch.

### §4.4. Currency edge cases

Some currencies have no fraction (JPY, KRW), some have three (BHD, IQD). The module respects the ISO 4217 minor-unit field.

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER3500` | `E_LOCALE_DATA_UNAVAILABLE` | Operation requiring locale data the catalog doesn't ship |
| `CXER3501` | `E_LOCALE_TAG_INVALID` | Non-BCP-47 locale tag |
| `CXER3502` | `E_LOCALE_PATTERN_INVALID` | Unparseable ICU date format pattern |
| `CXER3503` | `E_LOCALE_CURRENCY_INVALID` | Non-ISO-4217 currency code |
| `CXER3504` | `E_LOCALE_NUMBER_PARSE_FAILED` | `parse-number-locale` on string not matching locale conventions |

## §6. Conformance fixtures

Under `conformance/stdlib/locale.cxd`:

- Collation: German "ä" before / after / equal to "a" depending on `strength`.
- Numeric collation: `"file2"` before `"file10"` with `numeric=true`.
- Collation key: byte-compare produces same order as `collate`.
- Number format en-US: `1234567.89` → `"1,234,567.89"`.
- Number format de-DE: `1234567.89` → `"1.234.567,89"`.
- Compact notation: `1234567` `notation="compact"` `en-US` → `"1.2M"`.
- Parse round-trip: `parse-number-locale(format-number(n, l), l) ≈ n`.
- Date format ICU: `"yyyy-MM-dd"` canonical.
- Date style `:full` en-US: `"Tuesday, May 26, 2026"`.
- Date style `:full` ja-JP: `"2026年5月26日火曜日"`.
- Currency USD en-US: `"$1,234.56"`; JPY: no fraction digits.
- Locale fallback: `"en-GB-oxendict"` → `"en-GB"` → `"en"`.
- Turkish case: `upper-locale("i", "tr-TR")` → `"İ"`.

## §7. Cross-references

- [`spec/std-lib/i18n.md`](i18n.md) — sibling message catalogs / plural / MessageFormat layered on this module.
- [`spec/std-lib/strings.md`](strings.md) — `upper-locale` delegates here.
- [`spec/std-lib/time.md`](time.md) — references the §3.3 LDML token table.
- BCP 47, Unicode Collation Algorithm (UCA / TR10), ISO 4217, ICU.
