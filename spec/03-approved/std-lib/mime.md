# `cx-stdlib/mime` — MIME type registry and content-type parsing

```cx
[module-meta name=mime tier=A status=current
  [standard ref='RFC 2045' title='MIME']
  [standard ref='RFC 2046' title='Multipart']
  [standard ref='RFC 6838' title='Media types']
  [standard ref='RFC 5987' title='Extended params']
  [standard ref='RFC 6266' title='Content-Disposition']
  [standard ref='RFC 7231' title='Accept']]
```

**Status:** Current for v0.8.0

Normative reference for the `cx-stdlib/mime` sub-package.

---

## §1. Scope

`cx-stdlib/mime` handles MIME data-shape work: a type registry, Content-Type / Content-Disposition parsing, multipart boundary generation, type classification, and Accept-header content negotiation. The data-shape companion to [`spec/std-lib/url.md`](url.md); composes with [`spec/std-lib/email.md`](email.md) for multipart messages.

## §2. Conceptual model

### §2.1. Parsed content type

```cx
[content-type
  type="text"
  subtype="html"
  [parameters
    charset="utf-8"
    boundary="----=_Part_12345"]]
```

`text/html; charset=utf-8` parses to the above. `parameters` preserves casing where required (boundary values are case-sensitive; charset values are not).

### §2.2. Parsed content disposition

```cx
[content-disposition
  type="attachment"
  [parameters
    filename="report.pdf"
    filename*="UTF-8''Report%20Final.pdf"]]
```

RFC 6266 alignment. `filename*` (RFC 5987 extended form) is preserved separately so callers may decode if needed.

### §2.3. Type registry

The module ships a built-in extension → MIME type map covering ~200 common file extensions (zero-dependency, offline default). The registry is extensible: `register-type` adds one mapping programmatically; `load-mime-types` merges an OS or custom `mime.types` file. Later registrations override built-ins.

## §3. Public function surface

### §3.1. Type lookup

```
[?def type-for-extension       scope=public pure   [returns string]            ($ext::string) ...]
[?def extension-for-type       scope=public pure   [returns string]            ($mime-type::string) ...]
[?def all-extensions-for-type  scope=public pure   [returns [sequence string]] ($mime-type::string) ...]
[?def register-type            scope=public impure [returns null]              ($ext::string $mime-type::string) ...]
[?def load-mime-types          scope=public impure [returns int]               ($path::string) ...]
```

- `type-for-extension` — `ext` may include or omit the leading dot. Returns the canonical type string, or `"application/octet-stream"` for unknown extensions.
- `extension-for-type` — returns the most common extension for a type, or empty string if unknown.
- `all-extensions-for-type` — every known extension for a type.
- `register-type` — mutates the process-wide registry; later registrations override built-ins.
- `load-mime-types` — merges a `mime.types` file; returns the count loaded. Raises `CXER2804` on a missing or malformed file.

### §3.2. Content-Type parsing

```
[?def parse-content-type   scope=public pure [returns element] ($header-value::string) ...]
[?def format-content-type  scope=public pure [returns string]  ($parsed::element) ...]
[?def get-parameter        scope=public pure [returns string]  ($parsed::element $name::string) ...]
```

- `parse-content-type` — handles quoted values, escape sequences, optional whitespace. Raises `CXER2800` on parse failure.
- `format-content-type` — inverse; quotes values containing `;`, `,`, `"`, etc.
- `get-parameter` — returns the parameter value, or empty string if absent.

### §3.3. Content-Disposition parsing

```
[?def parse-content-disposition   scope=public pure [returns element] ($header-value::string) ...]
[?def format-content-disposition  scope=public pure [returns string]  ($parsed::element) ...]
[?def disposition-filename        scope=public pure [returns string]  ($parsed::element) ...]
```

- `parse-content-disposition` raises `CXER2801` on parse failure.
- `disposition-filename` returns the decoded filename, preferring `filename*` over `filename`. Raises `CXER2803` on a malformed `filename*` value.
- `format-content-disposition` — ASCII filenames emit a plain `filename="…"`. Non-ASCII filenames emit both a `filename*=UTF-8''…` (RFC 5987 extended) parameter and an ASCII `filename=` fallback (RFC 6266). Parse and emit round-trip.

### §3.4. Multipart boundary

```
[?def multipart-boundary   scope=public impure [returns string] () ...]
[?def is-valid-boundary    scope=public pure   [returns bool]   ($s::string) ...]
```

- `multipart-boundary` — generates `=_Part_<17 random hex chars>` (24 chars total: the 7-char `=_Part_` prefix plus 17 hex chars) via [`spec/std-lib/random.md`](random.md).
- `is-valid-boundary` — true iff `s` is a valid multipart boundary per RFC 2046 (1–70 chars, restricted character set).

### §3.5. Type classification

```
[?def is-text-type          scope=public pure [returns bool]   ($mime-type::string) ...]
[?def is-binary-type        scope=public pure [returns bool]   ($mime-type::string) ...]
[?def is-image-type         scope=public pure [returns bool]   ($mime-type::string) ...]
[?def is-audio-type         scope=public pure [returns bool]   ($mime-type::string) ...]
[?def is-video-type         scope=public pure [returns bool]   ($mime-type::string) ...]
[?def is-message-type       scope=public pure [returns bool]   ($mime-type::string) ...]
[?def is-multipart-type     scope=public pure [returns bool]   ($mime-type::string) ...]
[?def is-application-type   scope=public pure [returns bool]   ($mime-type::string) ...]
[?def is-structured-syntax  scope=public pure [returns string] ($mime-type::string) ...]
```

- Predicates return true based on the top-level type.
- `is-structured-syntax` returns the structured-syntax suffix per RFC 6838 §4.2.8 (`"application/ld+json"` → `"json"`; `"image/svg+xml"` → `"xml"`; empty string if none).

### §3.6. Charset operations

```
[?def charset-of    scope=public pure [returns string]  ($parsed::element) ...]
[?def with-charset  scope=public pure [returns element] ($parsed::element $charset::string) ...]
```

- `charset-of` — extract the `charset` parameter; empty string if absent.
- `with-charset` — return a new content-type element with `charset` set (replacing any existing).

### §3.7. Accept-header content negotiation

```
[?def parse-accept  scope=public pure [returns [sequence element]] ($header-value::string) ...]
[?def match-accept  scope=public pure [returns string]             ($header-value::string $offered::[sequence string]) ...]
```

`parse-accept` parses an Accept header (e.g. `"text/html;q=0.9, */*;q=0.8"`) into a q-ranked sequence of `accept` elements:

```cx
[accept
  type="text"
  subtype="html"
  q=0.9
  [params]]
```

Absent `q` defaults to `1.0` (RFC 7231 §5.3.1). The sequence is sorted by `q` descending, then by specificity (`type/subtype` > `type/*` > `*/*`).

`match-accept` returns the best-matching MIME type from `offered` per RFC 7231 §5.3.2 precedence, q-weighted. Returns empty string if nothing in `offered` is acceptable (e.g. every candidate carries `q=0`).

## §4. Edge cases

- **Case sensitivity.** Type/subtype names and parameter names are case-insensitive (parsers lowercase them); parameter values are case-sensitive in general (`boundary`) but case-insensitive where the parameter's grammar says so (`charset`).
- **Wildcards.** `text/*` and `*/*` are valid in Accept headers but not as Content-Types. The parser accepts them; predicates return true for the matching top-level type.
- **Vendor / personal trees.** `application/vnd.example.foo` and `application/prs.foo` parse; `is-application-type` returns true; `is-structured-syntax` returns the suffix if present.
- **Quoted parameter values.** `charset="UTF-8"` parses identically to `charset=UTF-8`; quoting is normalised away unless required.
- **RFC 5987 extended parameters.** A header may carry both `filename` and `filename*`; `disposition-filename` prefers the extended form.

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER2800` | `E_MIME_CONTENT_TYPE_MALFORMED` | `parse-content-type` on unparseable input |
| `CXER2801` | `E_MIME_CONTENT_DISPOSITION_MALFORMED` | `parse-content-disposition` on unparseable input |
| `CXER2802` | `E_MIME_BOUNDARY_INVALID` | Boundary fails RFC 2046 validation in an emitter |
| `CXER2803` | `E_MIME_EXTENDED_PARAM_DECODE_FAILED` | `disposition-filename` on a malformed `filename*` |
| `CXER2804` | `E_MIME_TYPES_FILE_INVALID` | `load-mime-types` on a missing or malformed file |

## §6. Conformance fixtures

Under `conformance/stdlib/mime.cxd`:

- Extension lookup: `.txt` → `"text/plain"`; `.jpg` and `.jpeg` → `"image/jpeg"`; unknown → `"application/octet-stream"`.
- Reverse lookup: `"image/jpeg"` → `.jpg`.
- Content-Type round-trip: parse → format produces canonical form; quoted vs unquoted parses identically.
- Content-Disposition: `attachment; filename="report.pdf"` parses; `filename*=UTF-8''Report%20Final.pdf` decodes to `"Report Final.pdf"`.
- Registry override: `register-type(".avif", "image/avif")` then `type-for-extension(".avif")` → `"image/avif"`.
- `load-mime-types` returns the count loaded; missing/malformed file raises `CXER2804`.
- Accept q-ranking: `parse-accept("text/html;q=0.9, */*;q=0.8")` orders `text/html` before `*/*`; absent `q` defaults to `1.0`.
- Accept precedence: `match-accept("text/*;q=0.5, text/html;q=0.9", ["text/plain","text/html"])` → `"text/html"`; all-`q=0` → empty string.
- RFC 5987 emit: non-ASCII filename emits both `filename*` and an ASCII `filename=` fallback and round-trips.
- Multipart boundary: 24 chars, hex content, prefixed `=_Part_`.
- Type predicates: `text/html` → text; `application/pdf` → application + binary; `image/svg+xml` → image + structured-syntax `"xml"`; `multipart/mixed` → multipart.

## §7. Capabilities

Effectful functions in `cx-stdlib/mime` run under deny-by-default capabilities ([`spec/core/security.md`](../core/security.md) §2): the effect point checks the active set and raises `cx-err:CXER0271` (E_CAP_DENIED, naming the missing capability and resource) when the grant is absent. Pure functions (in-memory transforms, parsing, formatting) require no capability.

Only loading a type database from disk touches the filesystem and requires `read`. Runtime type registration, boundary generation, and all type lookups and parsing operate in memory.

| Capability | Functions |
|---|---|
| `read` | `load-mime-types` |
| (none) | `register-type`, `multipart-boundary`, and all type lookups / parsing |

## §8. Cross-references

- [`spec/std-lib/email.md`](email.md) — multipart messages use this module's boundary generator.
- [`spec/std-lib/url.md`](url.md) — sibling data-shape module for URLs.
- [`spec/std-lib/random.md`](random.md) — source for multipart boundaries.
- RFC 2045 / 2046, RFC 5987, RFC 6266, RFC 6838, RFC 7231 §5.3.
