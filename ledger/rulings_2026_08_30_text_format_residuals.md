# Rulings — text-format residuals (#1117 #1118 #1119 #1120)

2026-08-30, release/0.18. Campaign umbrella #1097. Companion to
`ledger/rulings_2026_08_30_text_format_surface.md` (TF-1..TF-6), which
ruled the audit's §6 owner items. This file rules the four decisions
that were left OPEN when waves 1 and 2 landed — each because the fix
required a normative spec change and the standing rule forbids one
during an implementation phase without prior authorization.

Recorded BEFORE the work, per the ledger discipline. Owner authorization
given in session 2026-08-30 ("proceed with the revised recommendations")
after an explicit re-examination of the four recommendations against the
long-term-best bar. That re-examination CHANGED one of them (TF-8) and
sharpened two others (TF-7, TF-9); the changes are recorded below with
the argument that moved them, because a ruling whose reasoning is not
written down cannot be re-checked later.

## TF-7 — dot-segment removal in the RFC 3986 lane (#1118) (RULED: TF-7 = a)

Audit F15. `[$url:normalize 'HTTPS://X.IO:443/../a/./b']` yields
`https://x.io/../a/./b`. `url.md` §4.3's canonicalization contract lists
four operations and dot-segment removal is not among them, so `normalize`
matches its own spec — which is why this needed a ruling rather than a
fix. The whatwg lane was already corrected as standard-conformance
(#1118, `f4d3c3b60`), because `parse-whatwg` is spec'd as the browser-exact
model and the WHATWG path parser removes them.

- (a) **TAKEN — remove dot segments in the CANONICALIZING BUILD step, and
  extend §4.3's list.** The security argument is decisive:
  `https://x.io/../admin` and `https://x.io/admin` do not compare equal
  after `normalize` while every browser and every server resolves them to
  the same resource. Allowlists, cache keys and SSRF filters are built on
  `normalize`; leaving traversal segments in it is a footgun aimed at
  exactly those decisions. RFC 3986 §6.2.2 places remove_dot_segments in
  syntax-based normalization, and `url:join` already implements §5.2.4
  correctly — so this is the existing machinery reaching the lane that
  needed it, not new behavior invented here.

  **Two placement decisions inside (a), and they are the ruling's
  substance:**

  1. **NOT in `parse` (the RFC 3986 lane).** `parse` is a pure syntax
     split per RFC 3986 §3; if it resolved dot segments then
     `[$url:parse $s]/path` would stop returning what the input actually
     contains, and a caller inspecting components would be reading a
     value the document never carried. WHATWG's parse resolves them
     because the WHATWG model is defined that way — which is precisely
     why changing THAT lane was conformance and changing this one is a
     decision. The faithful-split property of `parse` is worth more than
     the symmetry.
  2. **In the shared canonicalizing build step**, so `build`, `normalize`
     and the parse→build round-trip stay ONE behavior rather than three
     that must be kept in agreement. §4.3 already frames `build` as the
     canonicalizer and `normalize` as `build(parse($s))`; this keeps that
     identity true.

  **`build-raw` SKIPS dot-segment removal**, and §4.3 says so. It is the
  escape for a caller who has a pre-composed path and wants it emitted
  as given — the same role it already plays for percent-encoding. Without
  a stated escape the removal would be unconditional, and a canonicalizer
  with no way to opt out is a lossy transform with no recourse.
- (b) Leave `normalize` as spec'd and document the hazard — rejected. It
  documents a sharp edge instead of removing it, and the callers most
  likely to be hurt (a filter comparing normalized strings) are the least
  likely to read a caveat in §4.3.
- (c) Leave it silently — rejected: the spec would keep calling a form
  canonical that two equivalent URLs do not share.

**Revisit trigger:** none needed. If a consumer appears that must preserve
dot segments through a canonicalizing build, `build-raw` already serves it.

## TF-8 — XML declared encodings (#1117) (RULED: TF-8 = c) — RECOMMENDATION CHANGED

Audit F18's residual half. §0.4 is now enforced in every text lane
(`112f3d392`): invalid UTF-8 refuses, UTF-16/32 BOMs refuse by name, a
UTF-8 BOM is tolerated. What remained open is what to do about
`<?xml version="1.0" encoding="ISO-8859-1"?>` over bytes that ARE valid
UTF-8 (i.e. ASCII), which CX reads correctly today while ignoring the
declaration.

**The agent's first recommendation was (a) — refuse the declaration
outright — and it was WRONG.** Recorded because the correction is the
useful part: since invalid UTF-8 already refuses everywhere, the ONLY
documents (a) changes are the ones CX currently reads CORRECTLY. Declared
latin-1 that is pure ASCII agrees with UTF-8 byte for byte; refusing it
breaks working ingestion for zero data-integrity gain. That is "refusing
valid input", the exact mirror of the "accepting invalid input" failure
this campaign exists to close. The pull toward (a) was the campaign's
strictness theme, not the merits of this case.

- (c) **TAKEN — the declaration is not honored, and `conversions.md` §0.4
  SAYS SO.** The normative sentence states three things together, because
  each is misleading without the others: CX reads UTF-8; an `encoding`
  pseudo-attribute in an XML declaration is not honored and does not
  change how bytes are decoded; and bytes that are not valid UTF-8 refuse
  regardless of what the declaration claims.

  The property that matters — and the reason this is not a shortfall
  dressed as a ruling — is that **there is no input for which CX silently
  produces the wrong characters.** A declared-latin-1 ASCII document reads
  identically under either interpretation; a declared-latin-1 document
  with a real high byte refuses at that byte, loudly and by position. The
  declaration is therefore only ever redundant or already-refuted, never
  quietly wrong.
- (a) Refuse a declared non-UTF-8 encoding — rejected on the argument
  above.
- (b) Honor it — transcode single-byte encodings — rejected for
  sequencing, not direction. It is a real surface (a character-table
  dependency and an encoding registry) and no consumer has asked.
  **Revisit trigger, recorded:** the first feature ingesting a real
  single-byte-encoded corpus. If implemented, it arrives as a declared
  transcoding step at the §0.4 boundary — never as per-parser guessing.

## TF-9 — the codec error shape (#1120) (RULED: TF-9 = a, with sequencing)

Audit F13: five formats, four error shapes on one `--from=` surface. The
defect half is already fixed (`d4d05394d`): every text codec now carries a
`cx-err:` code and a named class, json no longer drops the code its own
value carries, and the XML reader was unified on one refusal shape after
being inconsistent with itself. What was left is whether CSV's
`code + named class + location` becomes the CONTRACT.

- (a) **TAKEN — normative in `codec.md` §3, with the remaining work
  SEQUENCED rather than softened.** The contract states: every parse
  refusal carries (i) a `cx-err:` code, (ii) a stable named class token,
  and (iii) a location in the format's own natural unit — `line:col` for
  the line-oriented text formats, `row` for delimited — where the format
  has one. (i) and (ii) are true in every lane today. (iii) is true for
  xml, yaml and csv, and NOT yet for toml or json.

  **That gap is filed as its own issue with a named landing, not written
  into the spec as a permanent SHOULD.** This is the whole point of the
  sequencing: the spec says what the contract IS, and the tracker carries
  what is left to make it so — the inverse arrangement (a spec that only
  asks for what already ships) is the drift this campaign spent two waves
  removing.
- (b) Normative as a SHOULD, positions per-format — **rejected, and the
  agent should not have offered it.** A SHOULD here is a slower version of
  the exact defect class the campaign closed: a spec claiming something
  the implementation does not do, with the claim weakened just enough that
  nobody has to fix it. "Keep it off the critical path" is a sequencing
  concern and sequencing belongs in the tracker, not in the strength of a
  normative verb.
- (c) Leave it as implementation convention — rejected: F13's complaint is
  that a caller multiplexing formats cannot dispatch without per-format
  string parsing, and a convention nobody is bound to does not fix that.

## TF-10 — the memory multiplier's priority (#1119) (RULED: TF-10 = a)

TF-5 closed #1119's streaming-DIRECTION half and split the representation
cost off, saying to "retitle or refile against the representation, prio
per product". That is the item being ruled here.

- (a) **TAKEN — refile against the representation, and prioritise it above
  the remaining text-format spec items.** Measured: 18.1MB JSON → 2.02GB
  peak RSS (112×); 15.4MB XML → 765MB (~50×).

  The reason this outranks the spec residuals is a difference in KIND, not
  degree. Every other open item in this campaign is about whether CX reads
  or writes something correctly. This one bounds **what size document CX
  can ingest at all**: at 112×, a 200MB payload costs ~22GB, so the limit
  is not throughput but admission. Against the S-0 premise that SaaS gets
  built ON CX — with enterprise feeds at sizes that exist today — that is
  product-limiting rather than a tuning nicety, and no streaming API fixes
  it, because the in-program tree a feature navigates is the thing that
  costs 112× (the split TF-5 already recorded).

  **The agent's earlier "prio per product" was a deferral, not a
  judgement**, and is corrected here: the measurement is the product
  input, and it says this is the highest-value remaining item in the
  campaign.
- (b) Leave it at the TF-5 split with no priority — rejected: an
  actionable item with a measured product-limiting number does not need
  more discovery before it can be ranked.

## Execution order

Rulings (this file) land first, alone. Then: TF-7 in #1118, TF-8 in
#1117 (spec-only — the behavior already conforms; the edit makes §0.4
state it), TF-9 in #1120 plus the filed position-work issue, TF-10 as
the #1119 refile. Each spec-touching commit carries its `RULED:` token.
