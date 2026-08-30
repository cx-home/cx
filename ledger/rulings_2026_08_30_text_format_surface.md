# Rulings — text-format surface audit owner items (#1110 #1111 #1119 #1121 #1122)

2026-08-30, release/0.18. Campaign umbrella #1097. Rules the five owner
items from `ledger/audit_2026_08_30_text_format_surface.md` §6, recorded
BEFORE any implementation per the ledger discipline. Recommendations
verified against the long-term-best bar under the standing
letter-acceptance ruling (2026-08-05); none fell below the confidence
line that would have made it an open letter instead.

One fact that postdates the audit and bears on TF-1 and TF-3: the SAML
amendment S-8 (`ledger/rulings_2026_08_29_saml_sp_1091.md`, 2026-08-30)
ruled that `cx-stdlib/saml` carries its OWN infoset-faithful XML reader,
because `cx.parse_xml` is a data-oriented importer (W-6 whitespace strip,
autotype-adjacent lanes) that cannot reproduce the octet stream an IdP
signed. That removes the signature consumer from the core codec lane's
requirements, and both rulings below lean on it.

## TF-1 — per-format canonical emission and XML C14N (#1110) (RULED: TF-1 = a)

canonical.md §§5–10 document `--to-<fmt> --canonical` for
json/yaml/toml/xml/csv/md and §11.1 mandates a `canonical` flag on every
emitter; none of it exists (audit F2: no flag, no emitter signature, no
attr sort). §8 additionally claims "Base: C14N 1.1 … required by C14N for
cryptographic interop."

- (a) **Split ruling — TAKEN.**
  - **(a1) The C14N claim is REMOVED from the codec lane, permanently —
    not reserved.** It is not merely unimplemented; it is unimplementable
    on this substrate by design: W-6 (owner-ruled 2026-08-05) strips
    layout whitespace at import, and the import lane is data-oriented
    (S-8, measured), so the CXDM tree a codec emitter sees can never
    reproduce the signed octet stream. A `--to-xml --canonical` built
    here would emit something C14N-shaped that no signature over real
    input verifies against — a false cryptographic-interop promise, which
    is worse than no promise. Signature-grade canonicalization lives
    where the faithful bytes live: `cx-stdlib/saml`'s exclusive C14N over
    its own reader (S-4 + S-8). canonical.md §8 is rewritten to a
    deterministic XML emission canonical with the C14N branding and the
    "cryptographic interop" sentence deleted, plus a pointer to saml.md
    for signature canonicalization.
  - **(a2) §§5–7, 9–10 and the §11.1 `canonical` flag stay as the
    committed design, marked `status: reserved — specified, not
    implemented`.** Not deleted: the registry-level flag is the right
    single mechanism (audit §5 orthogonality finding 4 — canonical
    emission must be one mechanism, not per-format ad-hoc-ness), and the
    section content (CXC-JSON, YAML block-style rules, RFC 4180 quoting)
    is design work worth keeping. Implementation waits for a consumer.
    **Revisit trigger:** the first feature needing deterministic non-CX
    emission — reproducible exports, hash-of-projection, diff-stable
    output. `cx canonical`/`hash`/`fmt`/`eq` over CX text (§§2–3, §11.2)
    are implemented and correct; their status does not change.
- (b) Implement §§5–10 now — rejected. No consumer exists for any of the
  six; surface ahead of need (the S-1/S-6 precedent), and without (a1)
  it ships the false C14N claim.
- (c) Keep the spec as-is behind an implementation-debt marker —
  rejected. A known-false normative claim cannot stand behind a debt
  marker; the SAML workstream nearly built on §8 before S-8 was measured.

This is not "truing the spec to the shortfall": (a2) keeps the committed
design and records the gap loudly instead of silently, and (a1) corrects
a claim that measurement proved structurally false, with the capability
relocated (saml), not dropped.

## TF-2 — YAML ambition (#1111) (RULED: TF-2 = b)

Audit F10: the YAML parser is a private line-based dialect — anchors and
merge keys corrupt structure, block scalars lose content silently,
multi-doc merges into one map, malformed input never refuses (pinned by
fixture `yaml-022-flow-malformed-fallback`, contradicting the spec's
strict-refusal posture), and booleans are lowercase-only YAML 1.1 (the
Norway problem, shipped).

- (a) Implement YAML 1.2 core now — rejected for sequencing, not
  direction: it is a large parser project with no consumer at the head
  of the queue, and the honest interim state is available immediately.
- (b) **Normative subset + loud refusal — TAKEN.**
  - **Dialect target:** YAML 1.2 core schema. Booleans are `true`/`false`
    only; `yes/no/on/off` in any case are plain strings — this kills the
    Norway problem in both directions, and the current lowercase
    `on` → true behavior is a defect under this ruling.
  - **In the subset:** plain/quoted scalars, block and flow maps and
    sequences, comments, the lossless `$tag`/`!!cx:T`/`!!binary`
    envelope, **block scalars** (`|`, `>`), and **multi-document `---` →
    CX multi-document stream**. The last two are new implementation work
    but belong in the subset: both are already promised by conversions.md
    §5.1, and block scalars are table stakes for the config-file consumer
    class (k8s, CI, compose) this codec exists for.
  - **Refused, loudly:** anchors (`&`), aliases (`*`), merge keys
    (`<<:`), non-CX tags, `%` directives — CXER refusal with the
    **unsupported** class per the #1100 malformed-vs-unsupported rule.
    Malformed input (unterminated flow, impossible indentation) refuses
    as **malformed**. Nothing outside the subset may parse silently;
    "successfully into wrong data" is the one posture ruled out.
  - **Fixture flip:** `yaml-022-flow-malformed-fallback` inverts to pin
    the refusal. The spec posture wins over the fixture; the fixture
    pinned a defect.
  - **Spec:** conversions.md §5.1's anchor/alias rows are rewritten from
    "resolved before CX output" to "refused (unsupported)", and a
    normative dialect statement ("YAML 1.2 core schema, CX subset" with
    an explicit exclusion table) lands so F10's "no spec says which YAML
    this is" is closed.
  - **Revisit trigger for anchors/aliases/merge:** the first real
    consumer corpus that needs them. If implemented, an expansion size
    guard is mandatory from day one — alias/merge bombs are YAML's
    billion-laughs, and CX's XML lane is structurally immune to its twin;
    that posture is not given away.
- (c) Document the current dialect as normative — rejected: it would
  normatively bless silent data corruption (block scalars, multi-doc).
- (d) Drop yaml from the codec registry — rejected: breaking at a frozen
  surface, and the subset serves the config-file class honestly.

## TF-3 — xml's side of the module split (#1121) (RULED: TF-3 = a)

Audit §4: xml sits on the synthesized side (4 codec verbs, no opts);
promotion to a dedicated `cx-stdlib/xml` module crosses the deliberate
codec-core/stdlib boundary and is an owner call.

- (a) **Extend the synthesized codec surface with
  `parse-with-opts`/`emit-with-opts` — TAKEN.** These verbs are already
  named by codec.md §3's optional list, so no new surface shape and no
  frozen-surface event. The opts maps get spec'd per format; xml first,
  carrying at minimum: entity policy, whitespace policy (TF-4 consumes
  this), and lossless typing — which also closes F16's "lossless image
  unreachable in-program" for xml, and the same mechanism closes it for
  json/yaml (#1115 rides this ruling). The codec layer stays core and
  uniform — the audit's layer-1 rule — and the criterion is affirmed: a
  format earns a dedicated module on **format-intrinsic verbs**, and
  every xml need on the table today is an *option*, not a verb.
- (b) Promote xml to a dedicated stdlib module — rejected. Zero verb
  payload to justify crossing the boundary: the strongest driver
  (signature-grade parse + canonicalize) is self-hosted by
  `cx-stdlib/saml` per S-8, and everything else is opts. **Revisit
  trigger:** the first consumer needing a format-intrinsic xml VERB —
  schema validation, xml-specific streaming verbs, XPath-dialect
  features. Promotion is cheap later (the `cx-stdlib/xml` name already
  resolves); demotion never is.
- (c) Nothing — rejected: leaves the registry capability welded to the
  CLI `--lossless` flag (audit §5 finding 6), the exact inversion of
  codec.md §6's intent.

## TF-4 — W-6 mixed-content whitespace carve-out (#1122) (RULED: TF-4 = c)

Audit F6: `<p><b>x</b> <i>y</i></p>` loses the significant inter-element
space. The W-6 strip itself (layout whitespace strips at XML import,
owner-ruled 2026-08-05, `partition_I1_rebless.md` items 7/10) **stands as
the default** — it is right for the dominant data-document lane and its
canonical-identity consequences are settled. The refinement:

- (a) Heuristic mixed-content preservation (keep whitespace-only runs
  when a non-whitespace text run exists among the siblings) — rejected.
  The classic infoset heuristic FAILS the motivating example: in
  `<p><b>x</b> <i>y</i></p>` the parent's children are elements and
  whitespace only, so the heuristic strips exactly the space F6
  measured. And guessing document-ness is the "never guesses" posture
  violation dressed as a fix.
- (b) Retire the strip (preserve everything) — rejected: overturns a
  settled owner ruling that is correct for data documents; every
  imported config/payload would grow layout text nodes and churn
  identities.
- (c) **Explicit policy, two signals, default unchanged — TAKEN:**
  1. **`xml:space="preserve"` is honored in ALL lanes** — attribute-
     scoped and inherited per XML 1.0 §2.10. A document that declares
     preservation gets it; this is the document's own instruction, not a
     heuristic, and it beats the layout presumption. `xml:space=
     "default"` re-enables the strip for a subtree.
  2. **`whitespace: preserve` opt** on TF-3's `xml:parse-with-opts`
     surface for document-oriented consumers importing mixed-content XML
     that (typically) declares nothing.
  W-6's text is refined to name both escapes; the default strip and the
  item-10 join-space carve-out are untouched.

## TF-5 — streaming direction (#1119) (RULED: TF-5 = a)

Audit F14: 18MB JSON → 2.0GB RSS (112×), 15MB XML → 765MB (~50×);
`json:parse-stream` is NDJSON record streaming only; streaming.md's
32-event read model exists but only over CX source input, with
"streaming from non-CX input formats" explicitly deferred (§5).

- (a) **Direction committed, implementation demand-triggered — TAKEN.**
  The 32-event model IS the one streaming mechanism and is MEANT to
  reach the codec surface; NDJSON is a lane, not the ceiling. The
  streaming.md §5 deferral stands as *sequencing* but is now a committed
  *direction*: read-side pull events from non-CX input, json and xml
  first (the formats with enterprise-scale feeds). No per-format
  streaming hack may land in the meantime — when streaming parse
  arrives, it arrives through the event model. **Trigger:** the first
  consumer whose documents break the whole-document model.
- **Split recorded:** the constant factor is NOT the streaming question.
  112×/50× is representation overhead — a 200MB payload costing ~22GB
  in-tree is a defect whether or not a streaming API exists, and no
  event API fixes the in-program tree a feature actually navigates.
  #1119's direction half closes with this ruling; the memory-multiplier
  half stays open as an actionable perf item (retitle or refile against
  the representation, prio per product).
- (b) NDJSON-as-ceiling, document the limit in limits.md — rejected: it
  caps the iPaaS/platform posture (the S-0 premise — SaaS built ON CX)
  below feed sizes that exist today.
- (c) Implement streaming codec parse now — rejected: no consumer at the
  head of the queue; the enterprise SSO campaign is.

## Execution order

Rulings (this file) land first, alone. Execution stays with the issues:
spec edits per TF-1/TF-2 in #1110/#1111 (fixture flip yaml-022 with
TF-2's parser work, never before it); the opts surface per TF-3 in
#1121 + #1115; TF-4 = `xml:space` in the parser + the whitespace opt,
in #1122, sequenced after the TF-3 opts surface exists; #1119 direction
half closes on this file, perf half stays open. None of that is this
session's implementation scope — this session fixes only the
ruling-independent defects: #1114, #1105, #1106, #1107, #1116.
