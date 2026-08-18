# I1 identity epoch — old→new hash mapping

**Status:** authored at the epoch re-bless (ruling 2a: the implementer
executes; the owner reviews this file plus the FULL corpus diff in the
PR — the diff of `conformance/` across the `impl/I1-identity-epoch`
branch is the exhaustive record; this file carries one representative
old→new pair per moved class plus the movement rationale).

Address form note: pre-epoch digests were bare lowercase hex; every
post-epoch address is the self-describing tagged form
`sha2-256:<hex>` (stream 19, L31/L32). The byte movement underneath is
the sum of every MOVES row that touches the class (trailing-LF W-14,
§2.4 escapes, UTC-Z datetimes, NFC names, decimal autotype 2b,
detached payloads, operator heads, holes, …) — the manifest rows are
enumerated per class below.

| Class (ledger red-table row) | Representative OLD | Representative NEW | Moving rows |
|---|---|---|---|
| `identity_hash.cxd` singles (idh-001) | `122ee481d4a4413b3a091c7810e30d2c64fc32503384bdc561d21387f0042ac1` | `sha2-256:ab59c402c089bacb770b111ceb2b1ff7d85327191664c0bbd870e4904f367ff3` | rows 2, 3 (every Tier-1 digest: +LF coverage, tagged form) |
| idh-002 | `ddf4c4a6d00ff2f966dc7fbac58e8ddadafbd61379d3600a49e014f2b8139529` | `sha2-256:ef19e945a672c480a97b0ffa50b69cbe92cc0fae2092c927c74239b9e6325034` | rows 2, 3 |
| idh-003 (typed scalars incl. float attr) | `9f719216f85396ea8114d2713d7db2d61ba2350fe2a03866fc6d398559f2f651` | `sha2-256:2e0eccd2c97196966fa9acccfef982c51257e8697306bcacb847cbbd4f1bd5aa` | rows 1, 2, 3 (decimal autotype moved `1.25`) |
| idh-004 (escaped string) | `85437a96fa82df8dbfb2815ef4b2951c4937b6c78bff00c655eef3e6e16b4023` | `sha2-256:0388c04e42fa092f317700e8cb785d74730a7e12aba2412e3fccc59610af49bb` | rows 2 (§2.4 escapes), 3 |
| idh-005 (#id declaration) | `ff5ecb5d59cb6f50386ec104042ee3a8060444da3103c4bcb88ba41558082acf` | `sha2-256:b7aa2162d97ee262f67bd549ec4cda46d30b94d57c77dda1c50355bffdf29125` | rows 2, 3 |
| Pair flips (no digest — semantics) | idh-022 `false` / idh-023 `true` / idh-026 `true` / store-code-003..006 `true` | idh-022 `true` (decimal −0 normalizes) / idh-023 `false` (scale-preserving L40) / idh-026 `false` (hole ≢ string L78) / store-code `false` (participating fields C2) | rows 1, 9, 13 |
| `operator_heads.cxd` (oph-001, `[+ $x 2]`) | stringified `['+ $x 2']`, digest `ff10e2c01b67c646c8870877d4246c4bb82685a798fd32b6fc84b7082d006c53` | element `[+ $x 2]`, `sha2-256:7478d6bbf1e9ba55b778993530972b389ac28c2148a084b7460d2815d559d01c` | row 8 (meaning AND address; v1.0→v2.0 of the file at commit 9eefd2e2 records all seven) |
| Quote lowering (cx-094) | NO address (E210 → CXER4100) | `sha2-256:cf1204b421c2179448e1fe82338d37e64998a1897ea67d8c27674204ebf2c5a0` (= `cx hash` of the lowered `[total $x]`) | row 9 (DEFINES) |
| Journal chains (journal-001 entry 1 hash) | `epoch:`-ts, embedded-payload preimage (old digests in the pre-epoch corpus) | `sha2-256:902dfe8cf83616e030e70ec30429c632601d4bd29308b757049706a3afb218a4` (UTC-Z ts + detached `payload=sha2-256:1c28ab1f…`) | rows 2, 10, 11, 12 |
| Registry re-seal (`registry/store/`, xap-dist pins, `xap_registry_serve_real_test.v` consts) | manifest `dfc7a847dfe0748e4491ee9d9cfc7854bb4fa8fbf9ed53b74ec9f50b9dd0eed6`, tree `9420de8aa767372ec3afe4def2a78723abb3cd76c78818a4a76cf9e77aae6b7c` | manifest `sha2-256:1032cf6a11c164d29e9c173055d0c877c3ccdf24e4ff22bf0858d9ed223ee43c`, tree `sha2-256:a5c6ee0dbdc76d49cc4b610c8bbcc27adb689129dfeff951ba2759a83b9098c4` | all Tier-1 rows (nmea0183@0.1.0 re-published under epoch bytes; signatures cover the tagged address STRING, so re-publish not migrate) |
| Store literals (`store.cxd` ×6, bus-026, `cx.cxd` address literals, cx-024 CLI digest) | bare-hex put-doc literals (see corpus diff) | tagged `sha2-256:` literals (e.g. store-id-001 → `sha2-256:6d8460dd10c5fb09c542c81d617efef1eba054a71755f4e1c96a6af7830ddeeb`) | rows 2, 3 |
| The 2b wave (~75: math/random/ext/xml/table/astb/yaml/arrow/…) | float artifacts (`0.30000000000000004`), decimal-merging spellings, `0.91`-style float renders | exact decimal results (`0.3`), exponent-always float spellings (`9.1e-1`), re-spelled float-intent inputs (`2.5e0`) | rows 1, 16 |
| Schema hashes (`0x10`/`0x12`/`0x13` embedded digests) | CXCol-encoding basis (never pinned as literals — recomputed) | canonical-TEXT basis (E2/L82) | row 6 (zero pinned movers by design) |
| Stdlib multiline renders ×18 + triquote pins (ext-038/039, code ×2) | verbatim/triquote spellings | §2.4-escaped single-quoted spellings | row 2 (L15/L17) |

**Verification state at authoring:** eval gate ZERO enforced; conform
fully green (all suites); cxparse differential holds at its final
baseline (723/566/19/87/1/26/24); the full-suite audit rides the
re-bless commit's gate run.
