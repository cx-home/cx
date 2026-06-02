# SAP errors/effects/fp — Stage-B clause → fixture coverage map

The `COVERAGE` + `RED-COMPLETE` gate evidence: every Stage-A normative clause has
≥ 1 conformance fixture. **G** = grounded (enforced, true today); **A** = advisory
(expected-red, flips enforced when its impl lands in Stage C). Fixtures live in
`conformance/code.cxd` (core) and `conformance/stdlib/fp.cxd` (fp, all advisory).

## §8.13 `[?else]` value-or-default (truth table)
| clause | fixtures | gate |
|---|---|---|
| err → default | `sap-else-01-err-defaults` | A |
| empty → default | `sap-else-02-empty-defaults` | A |
| null passes | `sap-else-03-null-passes` | A |
| false/0/''/[]/{} pass (not EBV-coalescing) | `sap-else-04..08` | A |
| `[invalid]` passes | `sap-else-09-invalid-passes` | A |
| value passes | `sap-else-10-value-passes` | A |
| lazy default | `sap-else-11-lazy-default` | A |

## §8.2 `[?match]` scrutinee + O1 uniform pattern grammar
| clause | fixtures | gate |
|---|---|---|
| bind-first err catch (V1a) | `sap-match-01-catch-bindfirst` | G |
| inline ProgramExpr scrutinee (§9.2-exempt) | `sap-match-02-inline-scrutinee` | A |
| wildcard `_` | `sap-O1-00-wildcard` | G |
| attr `@a=v` predicate (rule 6) | `sap-O1-01-attr-predicate` | G |
| plain `a=v` equality (rule 9, conformance gap) | `sap-O1-01p-attr-plain-equality` | A |
| attr capture `@a=$c` (rule 10) | `sap-O1-01b-attr-capture` | A |
| map literal (rule 11) | `sap-O1-02-map-literal` | G |
| map capture `{k: $x}` | `sap-O1-02b-map-capture` | A |
| map rest `{k:v, *$rest}` | `sap-O1-02c-map-rest` | A |
| sequence closed-arity (rule 12) | `sap-O1-03-seq-closed` | G |
| sequence spread `(1, *$rest)` | `sap-O1-03b-seq-spread` | A |
| array literal `[1,$x,3]` (rule 13) | `sap-O1-04-array-literal` | A |
| array rest `[1, *$rest]` | `sap-O1-04b-array-rest` | A |
| `::T` typed bind / anon (rule 14) — int/str/float/bool/null/atom | `sap-O1-05..10` | A |
| attr type-test `@a::T` | `sap-O1-11-attr-type-test` | A |
| scalar-spread NON-MATCH (n/a, falls to else) | `sap-O1-12-scalar-spread-nonmatch` | A |

## O4 path/@attr distribution over sequence
`sap-O4-01-path-over-seq` (A), `-02-empty-in-empty-out` (A), `-03-missing-attr-skipped` (A), `-04-nonelement-skipped` (A).

## O2 `[?fallback]` binds `$err`
`sap-O2-01-fallback-binds-err` (A).

## §8.9 `[?pipe]` reshape
| clause | fixtures | gate |
|---|---|---|
| bare stages | `sap-pipe-01-bare-stages` | G |
| absence continues (railway on err only) | `sap-pipe-02-absence-continues` | G |
| infix `|` removed | `sap-pipe-03-infix-removed` | G (neg) |
| `[through]` removed | `sap-pipe-04-through-removed` | A (neg) |
| non-callable stage → CXER0100 | `sap-pipe-05-noncallable-stage` | A (neg) |
| `[tap]` passes through | `sap-pipe-06-tap-passes` | A |
| `[tap]` fn-errors, value survives | `sap-pipe-07-tap-error-survives` | A |
| railway short-circuit on err | `sap-pipe-08-skip-on-err` | A |
| tap skipped after upstream err | `sap-pipe-09-tap-skipped-after-err` | A |

## §8.8/§9.3 `[?try]`/`[catch]`/`[on-error]` retirement
| clause | fixtures | gate |
|---|---|---|
| `[?try]` → unknown directive (neg) | `sap-try-01-removed-negative` | A (neg) |
| `[on-error]` → unknown clause (neg) | `sap-try-02-on-error-removed-negative` | A (neg) |
| V2: `[on-error]` ≡ yield-body `[?match]` | `sap-try-03-onerror-equiv-match` | G |
| catchability: arithmetic / unbound | `sap-catch-01-arith`, `sap-catch-02-unbound` | G |

## §9.1.2.1 null-totality matrix
`sap-null-01-arith-clean-err` (G), `-02-concat-value` (G), `-03-eq` (G), `-04-count` (G), `-05-first` (G).

## §10.5.7 concurrency precedence
`sap-cancel-01-checkcancel-after-cancel` (A — cancel → CXER0260).

## §3 `cx-stdlib/fp` (all advisory — Phase C4)
sequence/Maybe (`fp-001..006`), result railway (`fp-010/011`), E_NO_INSTANCE=CXER4400 (`fp-020`), fold (`fp-030`), laws (`fp-040..042`), traverse/sequence (`fp-050/051`).

## Deferred to Stage C (standing guards / harnesses)
- `check-effect-alignment` (ALIGNMENT gate, Phase C2) — capability-gated ⇒ impure.
- `NO-LEGACY-TRY` / `NO-LEGACY-PIPE` AST-aware guards (Phase C3c / C3a).
- `check-null-absence-conflation` standing scan (Phase C1).
- pipe skip-proof counter harness — the current `sap-pipe-08/09` pin the err
  result; the captured-counter probe is added when `[tap]`/log side effects land.
- queryable-instance check + binding-parity (Phase C4/C6).
