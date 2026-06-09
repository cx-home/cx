# `cx-stdlib/email` — RFC 5322 + MIME multipart parser and builder

```cx
[module-meta name=email tier=A status=current
  [standard ref='RFC 5322' title='Message format']
  [standard ref='RFC 2047' title='Encoded words']
  [standard ref='RFC 2045' title='MIME']
  [standard ref='RFC 2046' title='Multipart']
  [standard ref='RFC 3464' title='DSN/bounce']]
```

**Status:** Current for v0.8.0

Normative reference for the `cx-stdlib/email` sub-package.

---

## §1. Scope

`cx-stdlib/email` provides full RFC 5322 + MIME multipart message parsing and emission. The surface covers parsing inbound messages, inspecting headers and bodies, extracting attachments, and building outgoing messages with text + HTML alternatives and attachments.

**Transport is out of scope** — email send/receive lives at the directive layer (vendor APIs via `[?http-client]`, or future `[?smtp-client]` / `[?imap-client]` / `[?mail-webhook]`). This module ships the data layer those transports produce or consume.

## §2. Conceptual model

An email message is a CX element:

```cx
[message
  [headers
    [from "John Doe <john@example.com>"]
    [to "support@example.com"]
    [subject "Invoice question"]
    [date "2026-05-26T14:30:00Z"]
    [message-id "<abc123@example.com>"]
    [in-reply-to "<def456@example.com>"]
    ...]
  [body
    [parts
      [part content-type="text/plain" encoding="quoted-printable"
        "Plaintext body content..."]
      [part content-type="text/html" encoding="quoted-printable"
        "<p>HTML body content...</p>"]
      [part content-type="application/pdf" encoding="base64" filename="invoice.pdf"
        "<base64 bytes...>"]]
    [is-multipart "true"]
    [boundary "----=_Part_12345_67890"]]]
```

`[$email:parse]` always produces this shape from RFC 5322 bytes; `[$email:emit]` always consumes it. Round-trip is byte-stable for messages produced by `[$email:emit]`.

### §2.1. Header model

Headers are an ordered map (order matters for some headers). Common headers have typed accessors. Multi-instance headers (multiple `Received:`) are returned as a sequence.

### §2.2. Body model

Either a single part (`is-multipart = false`) or a multipart tree. Parts may recursively contain multipart bodies. Each part carries `content-type`, `encoding` (`7bit` / `8bit` / `quoted-printable` / `base64`), `charset`, `filename`, `content-id`, and decoded body bytes.

### §2.3. Address model

An address is a tagged element:

```cx
[address
  [display-name "John Doe"]
  [local-part "john"]
  [domain "example.com"]
  [raw "John Doe <john@example.com>"]]
```

RFC 5322 group syntax (`team: a@x, b@x;`) is represented as `[address-group]`:

```cx
[address-group name="team"
  [address [local-part "a"] [domain "x"] [raw "a@x"]]
  [address [local-part "b"] [domain "x"] [raw "b@x"]]]
```

`parse-address-list` returns a heterogeneous sequence mixing `[address]` and `[address-group]`; consumers discriminate on the tag.

## §3. Public function surface

### §3.1. Parse and emit

```
[?def parse scope=public pure [returns element] ($bytes::bytes) ...]
[?def emit  scope=public pure [returns bytes]   ($msg::element) ...]
```

`parse` handles CRLF/LF line endings, header continuation lines (RFC 5322 §2.2.3), encoded-word headers (RFC 2047), quoted-printable + base64 body decoding, and multipart tree extraction. Unparseable input raises `CXER1300 E_EMAIL_MALFORMED` with byte-offset diagnostics.

`emit` re-encodes encoded-word subjects (using `=?UTF-8?B?...?=` or `=?UTF-8?Q?...?=` per shorter result), quoted-printable for non-ASCII text, base64 for binary parts, and multipart boundaries (existing or freshly generated via `[$mime:multipart-boundary]`). Output is canonical: same input element produces byte-identical output.

### §3.2. Header inspection

```
[?def headers       scope=public pure [returns map]              ($msg::element) ...]
[?def header        scope=public pure [returns string]           ($msg::element $name::string) ...]
[?def header-values scope=public pure [returns [sequence string]] ($msg::element $name::string) ...]
```

`headers` returns a map of `header-name → [sequence string]`. Each value is **uniformly** a `[sequence string]` (length 0 / 1 / N per header name) — never a scalar-for-single / sequence-for-multi union — so callers index or iterate without branching on shape (mirrors Go `net/http`'s `map[string][]string`). Names are lowercased per RFC 5322 case-insensitivity. `header` returns the first occurrence (empty string if absent).

`header-values` returns **all** values of the named header as a `[sequence string]` (length 0 if absent, 1 for a single-instance header, N for a multi-instance header such as `Received`). It is the always-sequence companion to the single-valued `header` accessor: `header` is the convenience first-value reading, `header-values` exposes the full multi-instance set without callers re-deriving it from the `headers` map. Name matching is case-insensitive per RFC 5322.

Typed accessors (all pure, all take `($msg::element)`):

```
[?def subject          scope=public pure [returns string]            ($msg::element) ...]
[?def from-addr        scope=public pure [returns element]           ($msg::element) ...]
[?def to-addrs         scope=public pure [returns [sequence element]] ($msg::element) ...]
[?def cc-addrs         scope=public pure [returns [sequence element]] ($msg::element) ...]
[?def bcc-addrs        scope=public pure [returns [sequence element]] ($msg::element) ...]
[?def date-header      scope=public pure [returns datetime]          ($msg::element) ...]
[?def message-id       scope=public pure [returns string]            ($msg::element) ...]
[?def in-reply-to      scope=public pure [returns string]            ($msg::element) ...]
[?def references       scope=public pure [returns [sequence string]] ($msg::element) ...]
[?def list-unsubscribe scope=public pure [returns [sequence string]] ($msg::element) ...]
```

| Function | Returns | Notes |
|---|---|---|
| `from-addr` | `element` | First From address |
| `to-addrs` | `[sequence element]` | All To addresses (handles groups) |
| `cc-addrs` | `[sequence element]` | All Cc addresses |
| `bcc-addrs` | `[sequence element]` | All Bcc addresses |
| `subject` | `string` | Decoded encoded-words |
| `date-header` | `datetime` | Parsed RFC 5322 date |
| `message-id` | `string` | Without angle brackets |
| `in-reply-to` | `string` | Without angle brackets |
| `references` | `[sequence string]` | Threading chain |
| `list-unsubscribe` | `[sequence string]` | URIs from `List-Unsubscribe` |

### §3.3. Body navigation

```
[?def parts        scope=public pure [returns [sequence element]] ($msg::element) ...]
[?def attachments  scope=public pure [returns [sequence element]] ($msg::element) ...]
[?def text-body    scope=public pure [returns string]             ($msg::element) ...]
[?def html-body    scope=public pure [returns string]             ($msg::element) ...]
[?def is-multipart scope=public pure [returns bool]               ($msg::element) ...]
```

- `parts` — all parts flat (one part for non-multipart messages).
- `attachments` — parts with `Content-Disposition: attachment` or inline-with-filename; result carries `filename`, `content-type`, decoded bytes.
- `text-body` / `html-body` — first `text/plain` / `text/html` part decoded to UTF-8 (empty if absent).
- `html-body` returns **raw, unsanitized** HTML. Rendering untrusted HTML without sanitization is an XSS risk; pass through `[$html:sanitize]` from [`cx-stdlib/html`](html.md) before rendering. The flow is: `parse` → `html-body` → `[$html:sanitize]` → render.

### §3.4. Encoding helpers

```
[?def decode-encoded-word scope=public pure [returns string] ($s::string) ...]
[?def encode-encoded-word scope=public pure [returns string] ($s::string $charset::string $encoding::string) ...]
```

`decode-encoded-word` decodes RFC 2047 (`=?charset?encoding?text?=`); handles `Q` and `B`. Charset conversion per the §4.4 pinned set; an unsupported charset raises `CXER1303 E_EMAIL_CHARSET_UNKNOWN` and preserves the raw undecoded bytes.

`encode-encoded-word`: `encoding` is `"Q"` or `"B"`; returns the encoded-word form (always wrapped in `=?...?=`).

### §3.5. Address parsing and formatting

```
[?def parse-address       scope=public pure [returns element]            ($s::string) ...]
[?def parse-address-list  scope=public pure [returns [sequence element]] ($s::string) ...]
[?def format-address      scope=public pure [returns string]             ($addr::element) ...]
[?def format-address-list scope=public pure [returns string]             ($addrs::[sequence element]) ...]
```

`parse-address` parses a single address; malformed → `CXER1301 E_EMAIL_ADDRESS_MALFORMED`.

`parse-address-list` parses zero or more addresses with optional RFC 5322 groups (`team: a@x, b@x;`, `undisclosed-recipients:;`); returns a heterogeneous sequence mixing `[address]` and `[address-group]`.

`format-address-list` accepts a heterogeneous sequence: `[address]` emits as a plain mailbox; `[address-group]` re-emits in RFC 5322 group syntax. Display names with special chars are quoted; non-ASCII names are encoded-word-wrapped.

Canonical emission (pinned, per RFC 5322 and the §2.3 example):

- **Plain mailbox list** — members joined by `", "` (comma + single space), no trailing separator. Example: `alice@x.com, bob@y.com`.
- **Group** — `name: member, member;`: the group name, then `": "` (colon + single space), then the group members joined by `", "` exactly as a plain list, then a terminating `";"` with **no** space before it. Example: `team: alice@x, bob@x;`. An empty group (e.g. `undisclosed-recipients:;`) emits `name:;`.

### §3.6. Outgoing-message builder

```
[?def build           scope=public pure [returns element] ($parts::map) ...]
[?def build-multipart scope=public pure [returns element] ($parts::map $alternatives::[sequence element]) ...]
```

`build` — convenience for plaintext messages. Required `parts` keys: `from`, `to`, `subject`, `body`. Optional: `cc`, `bcc`, `reply-to`, `date`, `headers`.

Recipient fields `to` / `cc` / `bcc` accept **either** a single address (string or `[address]` element) **or** a sequence of addresses. The builder normalizes single → one-element sequence internally.

```cx
[?let [= $msg [$email:build {"from": "agent@example.com",
                            "to":   "customer@example.com",
                            "subject": "Re: Invoice question",
                            "body": "Thank you for reaching out..."}]]
  [$email:emit $msg]]
```

`build-multipart` — same `parts` keys plus an `alternatives` sequence of part elements (each carrying `content-type`, `body`, optional `filename`).

### §3.7. Reply and forward

```
[?def reply   scope=public pure [returns element] ($orig::element $parts::map) ...]
[?def forward scope=public pure [returns element] ($orig::element $parts::map) ...]
```

`reply` preserves threading (`In-Reply-To`, `References`); recipient defaults to `orig.from-addr` (overridable via `parts.to`, single-or-sequence per §3.6). Subject auto-prefixed `"Re: "` unless present. A pure `reply` does **not** synthesize a sender identity: the new message's `From` is left **unset** unless supplied via `parts.from` (no transport identity is available at this layer). A still-missing `From` surfaces only later, at emit, as `CXER1304` (§6).

`forward` wraps `orig` as a `message/rfc822` attachment. Subject auto-prefixed `"Fwd: "` unless present. The wrapping `message/rfc822` part carries `Content-Disposition: attachment`, so it is surfaced by `attachments` (§3.3).

### §3.8. Delivery-status notifications (DSN / bounce)

A delivery-status notification is an RFC 3464 bounce report carried as `multipart/report; report-type=delivery-status`. `parse-dsn` lifts that shape into a structured element.

```
[?def parse-dsn       scope=public pure [returns element] ($msg::element) ...]
[?def parse-dsn-bytes scope=public pure [returns element] ($bytes::bytes) ...]
[?def is-bounce       scope=public pure [returns bool]    ($dsn::element) ...]
[?def is-hard-bounce  scope=public pure [returns bool]    ($dsn::element) ...]
```

`parse-dsn` takes an already-parsed message; `parse-dsn-bytes` parses raw bytes first. Non-DSN input raises `CXER1306 E_EMAIL_NOT_DSN`.

Result shape:

```cx
[dsn
  [original-message-id "<abc123@example.com>"]
  [reporting-mta "dns; mail.example.com"]
  [recipients
    [recipient final="user@example.com"  action="failed"  status="5.1.1" diagnostic="550 no such user" remote-mta="dns; mx.example.com"]
    [recipient final="queue@example.com" action="delayed" status="4.4.1" diagnostic="421 connection timed out"]]]
```

Per-recipient attributes map RFC 3464 `delivery-status`: `final`, `action` (`failed` / `delayed` / `delivered` / `relayed` / `expanded`), `status` (RFC 3463; `5.x.x` permanent, `4.x.x` transient, `2.x.x` success), `diagnostic`, `remote-mta`.

- `is-bounce` — any recipient action is `failed` or `delayed`.
- `is-hard-bounce` — any recipient action is `failed` with `5.x.x` status.

## §4. Encoding policy

### §4.1. Subject and free-text headers

RFC 2047 encoded-word encoding when any non-ASCII character is present or the accumulated header line exceeds 78 chars. Encoding choice: `B` (base64) for >50% non-ASCII; `Q` (quoted-printable) otherwise. Outgoing encoded-words emit UTF-8.

### §4.2. Body transfer encoding defaults

| Part | Default encoding |
|---|---|
| `text/plain` ASCII-only | `7bit` |
| `text/plain` non-ASCII | `quoted-printable` |
| `text/html` | `quoted-printable` |
| Other text/* | `quoted-printable` |
| Binary (images / PDFs / etc.) | `base64` |

Override via explicit `encoding` field on the part.

An **unsupported** transfer encoding (one outside `7bit` / `8bit` / `quoted-printable` / `base64`) does not fail `parse` itself. The trigger for `CXER1302 E_EMAIL_ENCODING_UNKNOWN` (§6) is **lazy on decode**: parsing retains the part with its raw, undecoded bytes, and the error is raised only when the affected body is decoded (`text-body`, `html-body`, or `attachments`), parallel to the §4.4 charset behavior for `CXER1303`.

### §4.3. Multipart boundary generation

Generated via `[$mime:multipart-boundary]` — random, guaranteed not to occur in part bodies. v0.8.0 uses 24 random hex chars prefixed with `=_Part_`.

### §4.4. Supported decode charsets

Both `decode-encoded-word` and text-body decoding convert from the declared charset to UTF-8. v0.8.0 pins:

- **Unicode** — UTF-8.
- **Western/European** — ISO-8859-1 through ISO-8859-15 (Latin-1 … Latin-9), Windows-1250 through Windows-1258.
- **Asian** — Shift_JIS, GB2312, GBK, Big5, EUC-KR, ISO-2022-JP.

Charsets outside this set raise `CXER1303 E_EMAIL_CHARSET_UNKNOWN` and **preserve the raw undecoded bytes** in the result.

## §5. Threading

Email threading is application-layer. The stdlib exposes raw materials: `message-id`, `in-reply-to`, `references` accessors.

## §6. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER1300` | `E_EMAIL_MALFORMED` | `parse` on unparseable RFC 5322 input |
| `CXER1301` | `E_EMAIL_ADDRESS_MALFORMED` | `parse-address` / `parse-address-list` on malformed address |
| `CXER1302` | `E_EMAIL_ENCODING_UNKNOWN` | unsupported transfer encoding — raised lazily on decode (`text-body` / `html-body` / `attachments`), per §4.2 |
| `CXER1303` | `E_EMAIL_CHARSET_UNKNOWN` | unsupported charset declared (raw bytes preserved) |
| `CXER1304` | `E_EMAIL_REQUIRED_HEADER_MISSING` | `emit` missing `From` or at least one recipient |
| `CXER1305` | `E_EMAIL_BOUNDARY_COLLISION` | multipart boundary appears in a part body |
| `CXER1306` | `E_EMAIL_NOT_DSN` | `parse-dsn` / `parse-dsn-bytes` on non-DSN input |

## §7. Conformance fixtures

Under `conformance/stdlib/email.cxd`:

- Plaintext RFC 822 round-trip preserves bytes.
- Multipart/alternative — text + HTML; both `text-body` and `html-body` return correct content.
- Multipart/mixed with PDF + image attachments; `attachments` returns both with correct filenames.
- Encoded-word subjects (`Q` and `B`): `=?UTF-8?Q?Hello_=E4=B8=96=E7=95=8C?=` and `=?UTF-8?B?SGVsbG8g5LiW55WM?=` decode to `"Hello 世界"`.
- Address with display name, encoded-word display name (`"José"`).
- Address-list with groups: `"team: alice@x, bob@x;"` parses as `[address-group name="team" ...]`; `format-address-list` round-trips group syntax.
- Quoted-printable + base64 body decoding.
- Multi-instance `Received:` headers preserved as sequence.
- Header continuation (long subject wrapping).
- CRLF vs LF parsed identically.
- Threading: `In-Reply-To` and `References` round-trip through `reply`.
- HTML-only and plaintext-only messages: opposite body accessor returns empty.
- `List-Unsubscribe` with multiple URIs parses as sequence.
- `build` and `build-multipart` round-trip via `parse(emit($msg))`.
- `reply($orig, …)` sets `In-Reply-To = orig.message-id` and `References = orig.references ++ [orig.message-id]`.
- Recipient string-or-sequence: `to "a@b.com"` and `to ["a@b.com", "c@d.com"]` both produce valid messages.
- DSN hard bounce (`failed` / `5.1.1`) parses to `[dsn]`; `is-bounce` and `is-hard-bounce` both true.
- DSN soft bounce (`delayed` / `4.x.x`): `is-bounce` true, `is-hard-bounce` false.
- Non-DSN input to `parse-dsn` raises `CXER1306`.
- Encoded-word decode across pinned charsets (Shift_JIS, GB2312).
- Unknown charset raises `CXER1303` and preserves raw bytes.
- `html-body` returns raw; fixture documents the `html-body` → `[$html:sanitize]` flow.

## §8. Sanitization, security, deliverability

This module does not sanitize HTML, validate sender authenticity, or sign outgoing mail. Those are sibling-module, application-layer, or transport-layer concerns:

- **HTML sanitization** — use `[$html:sanitize]` from [`cx-stdlib/html`](html.md).
- **DKIM signing / DMARC / SPF / spam filtering** — transport layer or out-of-scope.

The module DOES emit correct `List-Unsubscribe`, `Message-ID`, and `Date` headers via `build` / `build-multipart`.

## §9. Cross-references

- [`spec/std-lib/mime.md`](mime.md) — MIME content-type parsing and multipart boundary helpers.
- [`spec/std-lib/html.md`](html.md) — sibling HTML module; `[$html:sanitize]` makes raw inbound HTML from `html-body` safe to render.
- [`spec/std-lib/bytes.md`](bytes.md) — byte-buffer primitives.
- [`spec/std-lib/time.md`](time.md) — `datetime` returned by `date-header`.
- [`spec/std-lib/README.md`](README.md) — sub-package surface enumeration.
- [`spec/core/code.md §10.3`](../core/code.md) — `[?http-client]` directive (vendor API transport path).
