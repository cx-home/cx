# `cx-stdlib/time` — date, datetime, duration

```cx
[module-meta name=time tier=A status=current
  [standard ref='ISO 8601' title='Date/time']
  [standard ref='RFC 3339' title='Timestamps']
  [standard ref='RFC 2822' title='Email date']
  [standard ref='RFC 5545' title='RRULE']
  [standard ref='ICU/LDML' title='Formatting']
  [standard ref='IANA TZ' title='Time zones']]
```

**Status:** Current for v0.8.0

Normative reference for the `cx-stdlib/time` sub-package.

---

## §1. Scope

`cx-stdlib/time` operates on CXDM's `date` / `datetime` scalar kinds and the `duration` / `instant` storage-precision refinements (`duration` refines `int`, `instant` refines `datetime`; not new semantic kinds — per [`spec/core/cxdm.md`](../core/cxdm.md) §2.3) and their wall-clock / monotonic / mockable sources. Coverage:

- Instants — wall-clock and monotonic now.
- Date / datetime construction and decomposition.
- Duration arithmetic.
- Parsing and formatting — ISO 8601 + RFC 3339 / 2822 + ICU/LDML pattern parse and format at the root locale (locale-aware formatting lives in [`cx-stdlib/locale`](locale.md)).
- Timezone handling.
- Calendar arithmetic.
- Mock sources for deterministic-time testing.

`[?sleep]` is a directive (per [`spec/core/code.md`](../core/code.md)), not a function — cancellation contract and scheduler integration belong at the language level.

## §2. Type model

| Kind | Representation | Range |
|---|---|---|
| `date` | year + month + day | Year ±9999 |
| `datetime` | date + time-of-day + offset | Same year range |
| `instant` | UTC-anchored timestamp, nanosecond precision | ~±292 years either side of Unix epoch |
| `duration` | signed nanosecond count | ~±292 years |

Duration literals: `100ms`, `5s`, `1h`, `3d`. Date / datetime values come from parse functions on canonical-form strings.

### §2.1. Duration vs Period — exact-time vs calendar arithmetic

Time arithmetic splits into two categories:

- **Duration (exact / instant-based).** `add` / `subtract` (with a `duration`) and `add-hours` / `add-minutes` / `add-seconds` operate on the underlying **instant** — they add real elapsed seconds. Across a DST boundary the local wall-clock representation shifts: 1:00 am + `duration-h(1)` across spring-forward renders as 3:00 am local but is exactly 3600 real seconds later.
- **Period (calendar-based).** `add-days` / `add-months` / `add-years` keep the same wall-clock time on a later calendar unit. `add-days($d 1)` lands on the next calendar day regardless of DST. `add-months` / `add-years` apply month-end clamping (§4.1).

## §3. Public function surface

### §3.1. Time sources

```
[?def now              scope=public impure [returns datetime] () ...]
[?def today            scope=public impure [returns date]     () ...]
[?def instant-now      scope=public impure [returns instant]  () ...]
[?def monotonic-now    scope=public impure [returns int]      () ...]
[?def utc-now          scope=public impure [returns datetime] () ...]
[?def now-mock         scope=public pure   [returns datetime] ($t::datetime) ...]
[?def today-mock       scope=public pure   [returns date]     ($d::date) ...]
[?def instant-now-mock scope=public pure   [returns instant]  ($i::instant) ...]
[?def mock-advance     scope=public impure [returns null]     ($d::duration) ...]
[?def mock-set         scope=public impure [returns null]     ($t::instant) ...]
```

The `*-mock` variants establish the pinned value; tests typically use the directive-level `$mock` flag rather than calling these directly.

**Frozen by default.** A mocked clock is *frozen*: within a `$mock` scope every `now` / `today` / `instant-now` / `utc-now` returns the same instant until explicitly advanced. `mock-advance($d)` steps the clock by `$d`; `mock-set($t)` re-pins to an absolute instant. Both are no-ops outside a `$mock` scope.

### §3.2. Construction

```
[?def date             scope=public pure [returns date]     ($year::int $month::int $day::int) ...]
[?def datetime         scope=public pure [returns datetime] ($year::int $month::int $day::int $hour::int $minute::int $second::int) ...]
[?def datetime-with-tz scope=public pure [returns datetime] ($year::int $month::int $day::int $hour::int $minute::int $second::int $tz::string) ...]
[?def from-unix        scope=public pure [returns instant]  ($unix-seconds::int) ...]
[?def from-unix-ms     scope=public pure [returns instant]  ($unix-millis::int) ...]
[?def from-unix-ns     scope=public pure [returns instant]  ($unix-nanos::int) ...]
[?def epoch            scope=public pure [returns instant]  () ...]
```

Raises `CXER3300 E_TIME_INVALID_COMPONENT` on out-of-range components.

### §3.3. Decomposition

```
[?def year            scope=public pure [returns int]  ($d::any) ...]
[?def month           scope=public pure [returns int]  ($d::any) ...]
[?def day             scope=public pure [returns int]  ($d::any) ...]
[?def hour            scope=public pure [returns int]  ($dt::datetime) ...]
[?def minute          scope=public pure [returns int]  ($dt::datetime) ...]
[?def second          scope=public pure [returns int]  ($dt::datetime) ...]
[?def nanosecond      scope=public pure [returns int]  ($dt::datetime) ...]
[?def weekday         scope=public pure [returns atom] ($d::any) ...]
[?def day-of-year     scope=public pure [returns int]  ($d::any) ...]
[?def week-of-year    scope=public pure [returns int]  ($d::any) ...]
[?def timezone-offset scope=public pure [returns int]  ($dt::datetime) ...]
[?def to-unix         scope=public pure [returns int]  ($dt::datetime) ...]
[?def to-unix-ms      scope=public pure [returns int]  ($dt::datetime) ...]
[?def to-unix-ns      scope=public pure [returns int]  ($dt::datetime) ...]
```

`weekday` returns one of `:monday`, `:tuesday`, …, `:sunday`. `timezone-offset` returns seconds from UTC.

### §3.4. Arithmetic

```
[?def add               scope=public pure [returns any]      ($t::any $d::duration) ...]
[?def subtract          scope=public pure [returns any]      ($t::any $d::duration) ...]
[?def diff              scope=public pure [returns duration] ($a::any $b::any) ...]
[?def add-days          scope=public pure [returns date]     ($d::date $n::int) ...]
[?def add-months        scope=public pure [returns date]     ($d::date $n::int) ...]
[?def add-months-strict scope=public pure [returns date]     ($d::date $n::int) ...]
[?def add-years         scope=public pure [returns date]     ($d::date $n::int) ...]
[?def add-hours         scope=public pure [returns datetime] ($dt::datetime $n::int) ...]
[?def add-minutes       scope=public pure [returns datetime] ($dt::datetime $n::int) ...]
[?def add-seconds       scope=public pure [returns datetime] ($dt::datetime $n::int) ...]
```

`add` / `subtract` / `add-hours` / `add-minutes` / `add-seconds` are Duration operations (§2.1). `add-days` / `add-months` / `add-years` are Period operations. `add-months` clamps to end-of-month (e.g. Jan 31 + 1 month → Feb 28); `add-months-strict` raises `CXER3300` instead. `diff($a $b)` returns the duration from `$b` to `$a`.

### §3.5. Duration construction and conversion

```
[?def duration-ms       scope=public pure [returns duration] ($ms::int) ...]
[?def duration-s        scope=public pure [returns duration] ($s::int) ...]
[?def duration-m        scope=public pure [returns duration] ($m::int) ...]
[?def duration-h        scope=public pure [returns duration] ($h::int) ...]
[?def duration-d        scope=public pure [returns duration] ($d::int) ...]
[?def duration-parts    scope=public pure [returns element]  ($d::duration) ...]
[?def duration-total-ms scope=public pure [returns int]      ($d::duration) ...]
[?def duration-total-s  scope=public pure [returns int]      ($d::duration) ...]
[?def duration-total-h  scope=public pure [returns float]    ($d::duration) ...]
[?def duration-add      scope=public pure [returns duration] ($a::duration $b::duration) ...]
[?def duration-sub      scope=public pure [returns duration] ($a::duration $b::duration) ...]
[?def duration-mul      scope=public pure [returns duration] ($d::duration $n::int) ...]
[?def duration-div      scope=public pure [returns duration] ($d::duration $n::int) ...]
```

`duration-parts` returns `[duration-parts days=1 hours=2 minutes=30 seconds=45 nanoseconds=0]`.

### §3.6. Parsing

```
[?def parse-date        scope=public pure [returns date]     ($s::string) ...]
[?def parse-datetime    scope=public pure [returns datetime] ($s::string) ...]
[?def parse-instant     scope=public pure [returns instant]  ($s::string) ...]
[?def parse-duration    scope=public pure [returns duration] ($s::string) ...]
[?def parse-rfc3339     scope=public pure [returns datetime] ($s::string) ...]
[?def parse-rfc2822     scope=public pure [returns datetime] ($s::string) ...]
[?def parse-with-format scope=public pure [returns datetime] ($s::string $format::string) ...]
[?def parse-strftime    scope=public pure [returns datetime] ($s::string $format::string) ...]
```

- `parse-date` / `parse-datetime` — ISO 8601.
- `parse-instant` — ISO 8601 normalized to UTC.
- `parse-duration` — ISO 8601 duration (`"PT1H30M"`) or shorthand (`"1h30m"`, `"100ms"`).
- `parse-rfc3339` / `parse-rfc2822` — strict variants for those formats.
- `parse-with-format` — pattern-driven parse using ICU/LDML symbols (§3.7), at the root locale.
- `parse-strftime` — parse-only escape hatch for ingesting strings produced by external strftime-based tools (C/Python `%Y-%m-%d %H:%M:%S` tokens). No strftime emission counterpart; CXDM emits LDML exclusively.

Raises `CXER3301 E_TIME_PARSE_MALFORMED` with byte offset on failure.

### §3.7. Formatting

```
[?def format-iso8601     scope=public pure [returns string] ($dt::any) ...]
[?def format-rfc3339     scope=public pure [returns string] ($dt::datetime) ...]
[?def format-rfc2822     scope=public pure [returns string] ($dt::datetime) ...]
[?def format-with-format scope=public pure [returns string] ($dt::any $format::string) ...]
[?def format-duration    scope=public pure [returns string] ($d::duration) ...]
[?def format-relative    scope=public pure [returns string] ($dt::datetime $now-dt::datetime) ...]
```

`format-with-format` accepts ICU/LDML pattern symbols (same language as [`cx-stdlib/locale`](locale.md) §3.3) rendered at the root locale:

- `yyyy` 4-digit year, `yy` 2-digit
- `MM` zero-padded month number, `MMM` short month name, `MMMM` full month name (root-locale English here; locale-aware via `locale/format-date`)
- `dd` zero-padded day, `d` non-padded
- `HH` 24-hour, `hh` 12-hour, `a` AM/PM
- `EEEE` full weekday name, `EEE` short
- `mm` minute, `ss` second, `SSS` millisecond
- `z` time zone name, `Z` offset

### §3.8. Timezone

```
[?def timezone         scope=public pure   [returns element]         ($name::string) ...]
[?def to-timezone      scope=public pure   [returns datetime]        ($dt::datetime $tz::string) ...]
[?def to-utc           scope=public pure   [returns datetime]        ($dt::datetime) ...]
[?def system-timezone  scope=public impure [returns string]          () ...]
[?def list-timezones   scope=public pure   [returns [sequence string]] () ...]
```

Timezone names are IANA tz database identifiers (`"America/New_York"`). The tz database is resolved at runtime in order:

1. `CX_TZ_DIR` environment variable (zoneinfo-layout directory) — explicit override.
2. System tz database (`/usr/share/zoneinfo` on Unix-like systems) — if present.
3. Bundled snapshot — fallback compiled into the binary.

Raises `CXER3302 E_TIME_UNKNOWN_TIMEZONE` for unrecognized identifiers.

### §3.9. Predicates

```
[?def is-leap-year  scope=public pure [returns bool] ($year::int) ...]
[?def is-before     scope=public pure [returns bool] ($a::any $b::any) ...]
[?def is-after      scope=public pure [returns bool] ($a::any $b::any) ...]
[?def is-same       scope=public pure [returns bool] ($a::any $b::any) ...]
[?def is-same-day   scope=public pure [returns bool] ($a::datetime $b::datetime) ...]
[?def days-in-month scope=public pure [returns int]  ($year::int $month::int) ...]
```

### §3.10. Recurrence rules — RFC 5545 RRULE + cron

A **`[recurrence]`** is a pure, homoiconic VALUE describing a repeating schedule (the RRULE-grade rule type); expansion reads **no clock** (the anchor and query instants are passed in), so it is referentially transparent and fixture-reproducible. The consumer that *acts* on a schedule is `cx-stdlib/sched` (XAP); this surface only computes *when*.

```cx
[recurrence
  freq=:weekly                      ; SECONDLY|MINUTELY|HOURLY|DAILY|WEEKLY|MONTHLY|YEARLY (atom)
  interval=1                        ; positive int; default 1
  anchor="2026-06-01T09:00:00"      ; wall-clock seed (ISO-8601 local datetime, §3.6)
  tz="America/New_York"             ; IANA tz (§3.8); anchor + BYHOUR/MINUTE/SECOND are LOCAL to it
  wkst=:monday                      ; week-start atom; default :monday (RFC 5545 MO)
  count=10                          ; bound — at most 10 fires (mutually exclusive with until)
  [by-second 0] [by-minute 0 30] [by-hour 9 17]
  [by-day :tuesday [nth -1 :friday]]   ; weekday atoms, or [nth N :weekday] ordinal pairs (MONTHLY/YEARLY only)
  [by-month-day 1 15 -1] [by-year-day 1 -1] [by-week-no 1 -1] [by-month 1 6 12]
  [by-set-pos 1 -1]]                ; pick the i-th / i-th-from-last candidate of each interval
```

Field semantics mirror RFC 5545 §3.3.10: `freq`+`interval` set the base interval; `BY*` parts coarser-than-or-equal-to `freq` **filter**, finer parts **expand**, in the RFC's fixed evaluation order; `BYSETPOS` selects from the fully-expanded sorted candidate set of one interval. `anchor`/`until` are **wall-clock local in `tz`** so a rule round-trips through DST without drift (§4.2, gap→forward/overlap→earlier adopted verbatim). With neither `count` nor `until` the rule is infinite. `[recurrence]` is a new tag, not a handle (no `on-close`).

```
[?def recurrence       scope=public pure [returns element]            ($freq::atom $anchor::datetime $tz::string $opts::map {}) ...]
[?def validate-rule    scope=public pure [returns element]            ($rule::element) ...]
[?def is-valid-rule    scope=public pure [returns bool]               ($rule::element) ...]
[?def parse-rrule      scope=public pure [returns element]            ($s::string $anchor::datetime $tz::string $opts::map {}) ...]
[?def format-rrule     scope=public pure [returns string]             ($rule::element) ...]
[?def parse-cron       scope=public pure [returns element]            ($s::string $tz::string $opts::map {}) ...]
[?def format-cron      scope=public pure [returns element]            ($rule::element) ...]
[?def next-occurrence  scope=public pure [returns datetime]           ($rule::element $after::datetime) ...]
[?def occurrences-in   scope=public pure [returns [sequence datetime]] ($rule::element $from::datetime $to::datetime) ...]
[?def nth-occurrence   scope=public pure [returns datetime]           ($rule::element $n::int) ...]
[?def rule-freq        scope=public pure [returns atom]               ($rule::element) ...]
[?def rule-bound       scope=public pure [returns element]            ($rule::element) ...]
[?def rule-is-finite   scope=public pure [returns bool]               ($rule::element) ...]
```

- **Construction/validation** — `recurrence` builds + **validates eagerly** (a malformed field → `CXER3322`; a contradictory combination → `CXER3323`); `validate-rule` runs the full check on a hand-written `[recurrence]` literal and **raises** on a fault (a malformed rule is a genuine fault, not a value); `is-valid-rule` is the total never-raising predicate.
- **Surface parse/format** — `parse-rrule` (RFC 5545 `RRULE`; anchor + `tz` explicit; `BYDAY=3TH`→`[nth 3 :thursday]`; malformed → `CXER3320`); `format-rrule` is **total** (every rule has an RRULE form). `parse-cron` (5/6-field or `@macro`; malformed → `CXER3321`); `format-cron` **raises `CXER3324`** for a rule cron cannot express (`INTERVAL>1`, `BYSETPOS`, ordinal `BYDAY`, etc.) rather than fabricate a lossy result.
- **Expansion** (the sched-facing surface) — `next-occurrence` (first occurrence **strictly after** `$after`, DST-resolved; past a bounded rule's last → **absence**, not `null`/error, SAP §1); `occurrences-in` (half-open `[from,to)`, ascending; empty window → empty sequence); `nth-occurrence` (1-based from anchor; `$n<1` → `CXER3326`; beyond a bounded last → absence). An (near-)infinite expansion is bounded by a `max-occurrences` guard → `CXER3325`, never a hang.
- **Introspection** — `rule-freq`, `rule-bound` (`[count N]`/`[until $dt]`/absence), `rule-is-finite`.

All recurrence functions are **pure** (no clock, no host) — the only impurity in a recurrence-driven schedule is the caller's own `[$time:now]` anchor and the `sched` arm, neither of which lives here.

## §4. Edge cases and policy

### §4.1. Calendar ambiguity

Period operations on `add-months` / `add-years` clamp toward end-of-month when the source day-of-month does not exist in the destination month. `add-months-strict` raises `CXER3300` instead.

### §4.2. Daylight Saving

Duration operations (`add` with a `duration`, `add-hours` / `add-minutes` / `add-seconds`) add real elapsed seconds; the local wall-clock representation shifts across DST. Period operations (`add-days` / `add-months` / `add-years`) keep the same wall-clock time on the later calendar unit; gap times roll forward to the next valid local time, overlap times resolve to the earlier offset.

### §4.3. Leap seconds

Not represented. CXDM models UTC without leap-second adjustment, matching Python `datetime`, Java `java.time`, Go `time`, and JavaScript `Date`/`Temporal`. TAI / GPS time are out of scope.

### §4.4. Precision

Datetime stores nanoseconds internally; sub-nanosecond input truncates. Actual clock precision is OS-dependent.

### §4.5. Format string compatibility

`format-with-format` and `parse-with-format` use ICU/LDML patterns, the same pattern language as [`cx-stdlib/locale`](locale.md) §3.3. CXDM emits LDML only; strftime is a parse-only escape hatch (§3.6).

### §4.6. Mock clock semantics

A `$mock`-scoped clock is frozen: reads return the same pinned instant until `mock-advance` or `mock-set` moves it. `now-mock` / `today-mock` / `instant-now-mock` establish the initial pin; `mock-advance($d)` steps it; `mock-set($t)` re-pins.

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER3300` | `E_TIME_INVALID_COMPONENT` | Construction with out-of-range component; `add-months-strict` on non-existent target day; `days-in-month` with an out-of-range month or component |
| `CXER3301` | `E_TIME_PARSE_MALFORMED` | Parse failure with byte offset |
| `CXER3302` | `E_TIME_UNKNOWN_TIMEZONE` | Unknown IANA tz identifier |
| `CXER3303` | `E_TIME_FORMAT_TOKEN_UNKNOWN` | Unknown token in LDML pattern or strftime token |
| `CXER3304` | `E_TIME_DURATION_OVERFLOW` | Duration arithmetic exceeds nanosecond representation range |
| `CXER3305` | `E_TIME_DURATION_DIV_ZERO` | `duration-div` (or any duration numeric division/modulo) by zero |
| `CXER3320` | `E_TIME_RRULE_MALFORMED` | `parse-rrule` on an unparseable RRULE string (byte offset) |
| `CXER3321` | `E_TIME_CRON_MALFORMED` | `parse-cron` on a wrong-field-count / malformed cron or unknown `@macro` |
| `CXER3322` | `E_TIME_RULE_FIELD_INVALID` | a `BY*` value out of range, a non-positive `interval`, an unknown `freq`/`wkst` atom, or an ordinal `BYDAY` under a freq < `MONTHLY` |
| `CXER3323` | `E_TIME_RULE_CONTRADICTORY` | a rule that can never produce an occurrence (`BYMONTH=2`+`BYMONTHDAY=30`, both `count` and `until`, etc.) |
| `CXER3324` | `E_TIME_CRON_INEXPRESSIBLE` | `format-cron` on a rule cron cannot express (`INTERVAL>1`, `BYSETPOS`, ordinal `BYDAY`, `COUNT`/`UNTIL`, …) |
| `CXER3325` | `E_TIME_OCCURRENCE_LIMIT` | expansion of an (near-)infinite rule exceeded the `max-occurrences` search budget (guard, never a hang) |
| `CXER3326` | `E_TIME_OCCURRENCE_INDEX` | `nth-occurrence` with `$n < 1` |

`CXER3306–CXER3319` are reserved for future non-recurrence `time` growth; `CXER3327–CXER3349` are reserved for future recurrence extensions (`RDATE`/`EXDATE`, non-Gregorian calendars, an optional per-rule `dst=` override). Empty/exhausted expansion is **absence**, not a code (§3.10).

## §6. Conformance fixtures

Under `conformance/stdlib/time.cxd`:

- ISO 8601 round-trip: parse → format produces canonical form.
- RFC 3339 and RFC 2822 round-trip.
- Duration shorthand: `"1h30m"`, `"100ms"`, `"P1DT2H"` parse to expected nanoseconds.
- Component decomposition returns expected ints.
- Calendar arithmetic: `add-months` clamps Jan 31 + 1 month to Feb 28; `add-months-strict` raises `CXER3300`.
- Duration vs Period: `add-hours` across spring-forward is exactly 3600s later with local rendering shifted; `add-days` keeps the same wall-clock time on the next calendar day.
- Timezone conversion: UTC → `America/New_York` returns expected offset.
- Timezone resolution: `CX_TZ_DIR` honored; bundled snapshot serves when no system zoneinfo is present.
- DST: adding hours across spring-forward / fall-back produces correct UTC.
- Mock now: two reads without advancing return the same instant; `mock-advance` steps it; `mock-set` re-pins.
- Leap year: 2024 true, 2025 false, 2100 false.
- Days in month: 29 in Feb 2024, 28 in Feb 2025.
- LDML format: `yyyy-MM-dd HH:mm:ss` produces canonical form.
- `parse-strftime` ingests `%Y-%m-%d %H:%M:%S`.
- **Recurrence — RRULE round-trip**: `parse-rrule → format-rrule` is identity for RFC 5545-grade rules; `BYDAY=3TH` ↔ `[nth 3 :thursday]`; a malformed RRULE raises `CXER3320`.
- **Recurrence — cron round-trip**: 5/6-field + `@macro` parse; `format-cron` round-trips a cron-expressible rule and raises `CXER3324` for one it cannot express (`INTERVAL=2`, `BYSETPOS`, …).
- **Recurrence — expansion**: `occurrences-in` over a window matches the RFC 5545 reference set (incl. `BYSETPOS=-1` "last weekday of month", DST-spanning weekly rule keeps 09:00 local); `next-occurrence` is exclusive of `$after`; a bounded rule's post-last query and an empty window are **absence**/empty sequence (not error); `nth-occurrence $n<1` raises `CXER3326`; a contradictory rule raises `CXER3323` at construction.
- **Recurrence — purity**: identical `(rule, anchor, query)` always yields the identical occurrence set (no clock read).

## §7. Open follow-ups

- Lunar / Hijri / Hebrew calendars.
- Sub-microsecond clock (representation supports nanos; OS precision varies).
- Combined `add-period($dt "P1M2D")` for mixed months+days in one call.
- `tz-database-version` introspection and a documented refresh cadence for the bundled snapshot.
- Ranges and intervals: `interval`, `is-within`, etc.

## §8. Capabilities

Effectful functions in `cx-stdlib/time` run under deny-by-default capabilities ([`spec/core/security.md`](../core/security.md) §2): the effect point checks the active set and raises `cx-err:CXER0271` (E_CAP_DENIED, naming the missing capability and resource) when the grant is absent. Pure functions (in-memory transforms, parsing, formatting) require no capability.

Only the wall-clock and timezone reads consult the host. The mock controls (`mock-set`, `mock-advance`) and all duration/calendar arithmetic, parsing, and formatting are pure.

| Capability | Functions |
|---|---|
| `clock` | `now`, `utc-now`, `today`, `instant-now`, `monotonic-now`, `system-timezone` |
| (none) | `mock-set`, `mock-advance`, all duration/calendar arithmetic & formatting, and the entire **recurrence** surface (§3.10 — pure, no clock) |

## §9. Cross-references

- [`spec/std-lib/locale.md`](locale.md) — locale-aware date/time formatting.
- [`spec/core/cxdm.md`](../core/cxdm.md) — date / datetime / instant / duration scalar kinds.
- Recurrence (§3.10): RFC 5545 §3.3.10 (RRULE) + §3.8.5 (recurrence rule property); cron 5/6-field convention. The acting consumer is `cx-stdlib/sched` (XAP) — this surface computes occurrence instants; sched arms timers on them.
- [`spec/core/code.md`](../core/code.md) — `[?sleep]` directive.
- IANA tz database, RFC 3339, RFC 2822, ISO 8601, ICU/LDML — external normative references.
