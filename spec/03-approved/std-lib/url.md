# `cx-stdlib/url` — URL parse, build, encode, decode

```cx
[module-meta name=url tier=A status=current
  [standard ref='RFC 3986' title='URI']
  [standard ref='WHATWG URL' title='URL standard']
  [standard ref='Unicode UTS #46' title='IDNA']]
```

**Status:** Current

Normative reference for the `cx-stdlib/url` sub-package.

---

## §1. Scope

`cx-stdlib/url` provides RFC 3986 + WHATWG-URL-aligned URL parsing, building, and component encoding. Coverage: split URLs into components, reconstruct them, percent-encode arbitrary byte sequences, parse and serialize query strings.

**Transport is out of scope.** Network requests live at the directive layer (`[?http-client]`); this module produces URL strings and parsed components for those directives.

## §2. Conceptual model

A **parsed URL** is a CX element with named children:

```cx
[url
  [scheme "https"]
  [userinfo "user:pass"]
  [host "example.com"]
  [port "8080"]
  [path "/api/v1/users"]
  [query "limit=10&offset=20"]
  [fragment "section-2"]]
```

`[$url:parse]` produces this shape from a URL string; `[$url:build]` consumes it and produces a URL string. The round-trip is **canonical, not byte-identical**: `build(parse($s))` always produces a normalized form (default port stripped for known schemes, scheme and host lowercased, percent-encoding normalized to uppercase hex). See §3.1 and §4.3 for the canonicalization contract.

### §2.1. Alignment

The default decomposition is **RFC 3986 generic** (scheme / authority / path / query / fragment). It handles all schemes uniformly — web (`http`, `https`), store backends (`s3`, `sftp`, `cx-store`, `file`), and others (`mailto`, `data`, custom).

WHATWG URL Standard mode is opt-in for browser-exact web-URL behavior. WHATWG splits schemes into *special* (`http`, `https`, `ws`, `wss`, `ftp`, `file`) and *non-special*, parsing them differently — non-special schemes get an opaque path that is not split on `/`. CX's [`cx-stdlib/store`](store.md) dispatches on backend URLs (`s3://bucket/key`, `sftp://host/path`) and relies on structural path decomposition for every scheme.

WHATWG mode is available via `[$url:parse-whatwg]` or `[$url:parse-with-opts]` with `model="whatwg"`.

#### §2.1.1. RFC-3986-vs-WHATWG divergence

| Divergence point | RFC-3986 default (`parse`) | WHATWG mode (`parse-whatwg`) |
|---|---|---|
| Backslash `\` in path/authority | Literal; rejected in authority, percent-encoded in path. | Treated as `/` for special schemes. |
| Scheme-relative `//host` reference | Authority-bearing reference with no scheme. | Inherits base scheme on resolve; special schemes require a scheme. |
| Default-port on parse | Port preserved verbatim. | Default port for the scheme dropped on parse. |
| Per-component percent-encoding sets | RFC 3986 §2.4 sets (see §2.2). | WHATWG encode sets (wider). |
| Empty host | Allowed for `file`; rejected for schemes requiring authority. | Special schemes other than `file` reject empty host; non-special permit it. |
| Trailing-dot host | Preserved. | Stripped during host normalization for special schemes. |

Element shape is identical in both modes; only field contents differ. `build` re-applies default-port stripping and percent-encoding normalization regardless of parse mode (§4.3).

### §2.2. Percent-encoding sets

| Component | Encoded characters |
|---|---|
| `userinfo` | gen-delims, sub-delims except `:`, `@`, `/`, `?`, `#` |
| `host` | gen-delims, sub-delims except `[`, `]` |
| `path` | gen-delims, sub-delims except `/` |
| `query` | gen-delims, sub-delims except `?` and `/` |
| `fragment` | gen-delims, sub-delims |
| Generic (`encode`) | all reserved chars except unreserved (`A-Z a-z 0-9 - _ . ~`) |

`[$url:encode]` uses the generic set. `[$url:build]` applies the component-specific set automatically, treating each component value as **raw** input — see §4.5. The escape hatch for already-encoded components is `[$url:build-raw]`.

## §3. Public function surface

### §3.1. Parse and build

```
[?def parse           scope=public pure [returns element] ($s::string) ...]
[?def parse-lenient   scope=public pure [returns element] ($s::string) ...]
[?def parse-whatwg    scope=public pure [returns element] ($s::string) ...]
[?def parse-with-opts scope=public pure [returns element] ($s::string $opts::map) ...]
[?def build           scope=public pure [returns string]  ($parts::element) ...]
[?def build-raw       scope=public pure [returns string]  ($parts::element) ...]
[?def normalize       scope=public pure [returns string]  ($s::string) ...]
```

- `parse($s)` — RFC 3986 generic, **strict**. Raises `CXER1400 E_URL_MALFORMED` with byte offset on malformed input. For messy real-world input use `parse-lenient`; for browser-exact behavior use `parse-whatwg`.

  Examples:
  - `"https://example.com/path?q=1"` → `[url [scheme "https"] [host "example.com"] [path "/path"] [query "q=1"]]`
  - `"//example.com/path"` → `[url [host "example.com"] [path "/path"]]`
  - `"/path?q=1"` → `[url [path "/path"] [query "q=1"]]`
  - `"file:///etc/passwd"` → `[url [scheme "file"] [host ""] [path "/etc/passwd"]]`

- `parse-lenient($s)` — best-effort recovery (trims C0/space, repairs stray backslashes, encodes unescaped reserved chars, tolerates missing authority delimiters). Rarely fails; raises `CXER1400` only when recovery is impossible.

- `parse-whatwg($s)` — WHATWG URL model (special-scheme handling, backslash-as-slash, default-port dropping, WHATWG encode sets, host normalization).

- `parse-with-opts($s $opts)` — explicit options:

  | Key | Default | Semantics |
  |---|---|---|
  | `model` | `"rfc3986"` | Parsing model: `"rfc3986"` or `"whatwg"`. |
  | `permissive` | `false` | Legacy alias for `model="whatwg"`. |
  | `default-scheme` | `null` | If set and `$s` has no scheme, treat as prefixed with `<scheme>:`. |

- `build($parts)` — assembles a URL string from a parsed element. **Auto-encodes**: each component value is treated as raw (un-encoded) and percent-encoded per §2.2. Removes URL-injection footguns from concatenated raw input. Also **canonicalizes**: strips default port for known schemes (`http:80`, `https:443`, `ftp:21`, `ssh:22`, `ws:80`, `wss:443`), normalizes percent-encoding hex to uppercase, lowercases scheme and host. Therefore `build(parse($s))` is canonical but not necessarily byte-identical to `$s` — see §4.3.

- `build-raw($parts)` — assembles components verbatim without re-encoding. Performs structural assembly (authority delimiters, IPv6 bracketing, scheme/host casing) but leaves byte content untouched. Use only for pre-encoded components.

- `normalize($s)` — equivalent to `build(parse($s))`. Explicit canonicalizing entry point. Raises `CXER1400` if `$s` does not parse.

### §3.2. Generic encode/decode

```
[?def encode scope=public pure [returns string] ($s::string) ...]
[?def decode scope=public pure [returns string] ($s::string) ...]
```

- `encode($s)` — percent-encode with the generic set (unreserved chars left alone, everything else `%XX` of UTF-8 bytes).
- `decode($s)` — percent-decode and return UTF-8. Raises `CXER1401 E_URL_INVALID_PERCENT` on malformed `%XX` and on invalid UTF-8. Lossy decode via `decode-with-opts $lossy=true`.

### §3.3. Query strings

```
[?def query-parse  scope=public pure [returns map]    ($s::string) ...]
[?def query-encode scope=public pure [returns string] ($m::map) ...]
```

- `query-parse($s)` — repeated keys produce a sequence value; `key=` and bare `key` map to empty string. Percent-decoding applied. Example: `"a=1&b=2&a=3"` → `[map [a [sequence "1" "3"]] [b "2"]]`.
- `query-encode($m)` — sequence values produce repeated keys; query-component percent-encoding applied; key order matches map insertion order.

### §3.4. Composition

```
[?def join        scope=public pure [returns string] ($base::string $ref::string) ...]
[?def is-absolute scope=public pure [returns bool]   ($s::string) ...]
```

`join` resolves `$ref` relative to `$base` per RFC 3986 §5. `is-absolute` is true iff `$s` has a scheme component.

## §4. Edge cases and policy

### §4.1. IPv6 hosts

Hosts may be IP-literal form `[2001:db8::1]` with brackets. `parse` strips brackets in the `host` field; `build` re-adds them when the host contains colons.

### §4.2. IDN hosts

Internationalized domain names are stored in the parsed element as **U-labels** (Unicode form). `parse` normalizes the host to U-labels regardless of input form, so a host mixing U-labels and A-labels normalizes every label to U-label. Two URLs naming the same host compare equal after parse.

`build` always emits **A-labels** (Punycode) on the wire. Conversion uses IDNA 2008 (UTS #46 default profile). Raises `CXER1402 E_URL_IDN_INVALID` on IDN validation failure in either direction.

### §4.3. Canonicalization contract

`build` is canonicalizing, so `build(parse($s))` (equivalently `[$url:normalize $s]`) yields a canonical URL that may not be byte-identical to `$s`:

- **Default-port stripping** for known schemes (`http:80`, `https:443`, `ftp:21`, `ssh:22`, `ws:80`, `wss:443`). Non-default ports preserved.
- **Scheme lowercasing**: `HTTPS://x/` → `https://x/`.
- **Host lowercasing** and IDN A-label emission.
- **Percent-encoding normalization** to uppercase hex; encoded unreserved chars decoded (`%41` → `A`).

For byte-faithful round-trip of pre-encoded components, pair `parse` with `build-raw`.

### §4.4. Empty components

- Empty scheme: bare `://host/path` rejected with `CXER1400`.
- Empty host: allowed for `file://`; rejected for `http://`, `https://`, `ftp://`.
- Empty path: parsed as empty string; `build` emits as `""` between host and query.
- Empty query: `?` with no pairs parses to empty map; `query-parse("")` returns empty map.

### §4.5. Reserved character handling

`build` auto-encodes every component with its component-specific set (§2.2). Callers pass raw values — including reserved chars, spaces, and Unicode — and `build` produces a correctly-encoded URL.

```cx
[?let [= $username "a/b c"]
  [$url:build
    [url [scheme "https"]
         [host "api.example.com"]
         [path [$strings:join ["/users/" $username "/profile"] ""]]]]]
[; → https://api.example.com/users/a%2Fb%20c/profile ]
```

For pre-encoded values use `build-raw`. Never pre-encode then call `build`, or values double-encode.

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER1400` | `E_URL_MALFORMED` | `parse` / `parse-with-opts` / `parse-whatwg` / `normalize` on unparseable input; `parse-lenient` only when recovery is impossible |
| `CXER1401` | `E_URL_INVALID_PERCENT` | `decode` on malformed `%XX` sequences |
| `CXER1402` | `E_URL_IDN_INVALID` | `parse` on IDN-invalid hostname; `build` / `build-raw` on host that fails IDNA round-trip |
| `CXER1403` | `E_URL_SCHEME_REQUIRED` | `build` raises when a relative reference is supplied where absolute is required |

## §6. Conformance fixtures

Under `conformance/stdlib/url.cxd`:

- Parse + build round-trip: 20 URL shapes parse → element → string; output matches canonical form.
- Scheme variations: `http`, `https`, `ftp`, `ssh`, `file`, `mailto`, `data`, custom-scheme each parse.
- IPv6 host: `https://[2001:db8::1]:8080/path` parses with brackets stripped in host; build re-adds them.
- IDN host: `https://例え.test/path` U-label round-trips through Punycode (`xn--r8jz45g.test`).
- Userinfo: `https://user:pass@host/` parses and re-emits.
- Query parse: repeated keys, empty values, bare keys, `+`-as-space variants.
- Percent-encoding: generic encode round-trips bytes 0–255 except the unreserved set; decode raises on malformed sequences.
- Join: 20 RFC 3986 §5.4 examples all produce expected output.
- Default-port stripping: `https://example.com:443/` builds as `https://example.com/`; explicit non-default port preserved.
- Canonicalizing build: `HTTPS://EXAMPLE.com:443/%2f` round-trips to `https://example.com/%2F`.
- Auto-encoding build: raw path `a/b c` produces `.../a%2Fb%20c`; `build-raw` with pre-encoded `a%2Fb%20c` produces same without re-encoding.
- WHATWG parse: `https://example.com\path` normalized to `/` by `parse-whatwg`; rejected by `parse`.
- Lenient parse: messy input recovered by `parse-lenient` where `parse` raises `CXER1400`.
- Store-scheme decomposition: `s3://bucket/key`, `sftp://host/dir/file`, `cx-store://ns/id` decompose structurally under the default model.

## §7. Open follow-ups

- IRI (RFC 3987) beyond IDN-only.
- Stricter canonicalization profiles (sort query keys, aggressive dot-segment collapse) via `build-with-opts`.
- Structured `data:` URL parsing (content-type + payload).

## §8. Cross-references

- [`spec/std-lib/store.md`](store.md) — depends on `[$url:parse]` for backend dispatch.
- [`spec/std-lib/mime.md`](mime.md) — sibling module.
- [`spec/std-lib/README.md`](README.md) — sub-package surface enumeration.
- RFC 3986, WHATWG URL Standard, IDNA 2008 (RFC 5890–5895, UTS #46) — external normative references.
