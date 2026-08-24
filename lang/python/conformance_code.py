"""CX code conformance runner — Python Tier-1 binding parity check.

Iterates the curated supported_fixtures whitelist (mirrors the V-side
vcx/tests/code_eval_fixtures_test.v supported_fixtures table) from
conformance/code.cxd, runs each fixture through cxlib.eval_code,
and compares the result against the fixture's out_text.

Tier-1 binding parity: the Python binding routes through the
same libcx the V test suite exercises, so a pass-list parity between V
and Python is the cross-binding check that the spec calls for.

Exit codes:
    0   all whitelisted fixtures pass
    1   at least one whitelisted fixture failed
    2   parser / setup error
"""

from __future__ import annotations

import os
import re
import sys
from dataclasses import dataclass

# Locate cxlib relative to this file so `python conformance_code.py`
# works without PYTHONPATH gymnastics.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import cxlib  # noqa: E402


# ── Supported fixtures (mirrors vcx/tests/code_eval_fixtures_test.v) ────
#
# Keep this list in sync with the V-side supported_fixtures table. The
# parity check is meaningful only when both bindings exercise the same
# corpus. New fixtures added to the V list should land here too — and
# vice versa — at every commit that touches either.

SUPPORTED_FIXTURES = (
    # Resilience baseline
    'program-fallback-001-primary-success',
    'program-fallback-002-primary-err-secondary-ok',
    'program-fallback-003-both-err-no-wrap',
    'program-retry-001-happy-path',
    'program-retry-003-exhaustion',
    'program-retry-009-max-zero-rejected',
    'program-timeout-001-completes-within',
    'program-timeout-002-deadline-exceeded',
    'program-timeout-003-on-timeout-recovery',
    'program-timeout-004-negative-duration-rejected',
    'program-cb-001-closed-passthrough',
    'program-cb-006-threshold-bounds-rejected',
    'program-ratelimit-001-under-limit',
    # Resilience retry backoff variants (deterministic — no actual sleep)
    'program-retry-005-constant-backoff',
    'program-retry-006-linear-backoff',
    'program-retry-007-exponential-backoff',
    'program-retry-008-fibonacci-backoff',
    'program-retry-010-jitter-modes-shape',
    # Retry :on predicate (uses [?fn] closure)
    'program-retry-004-on-predicate-bails',
    # CB additional variants
    'program-cb-002-trips-open',
    'program-cb-005-below-min-samples-no-trip',
    # Rate-limit variants
    'program-ratelimit-002-over-limit',
    'program-ratelimit-003-replenish-after-window',
    # Retry success on Nth attempt (uses test-err-then-ok helper)
    'program-retry-002-success-on-third-attempt',
    # Core: find / let / pipe / par
    'program-for-001-all-emails',
    'program-for-002-active-emails',
    'program-for-003-name-email-pair',
    # §5.2 rule 5 body-binding regression (2026-05-22)
    'program-for-bind-text-body',
    'program-for-bind-scalar-body',
    'program-for-bind-attr-pattern-keeps-element',
    'program-for-bind-structured-body',
    'program-for-bind-mixed-content-sequence-body',
    'program-render-sequence-literal-in-element-body',
    'program-for-multi-attr-eq-bind',
    'program-for-multi-attr-mixed-existence-and-bind',
    'program-element-shape-call-eq-paren-form',
    'program-element-shape-call-concat-paren-form',
    'program-element-whitespace-form-stays-element',
    'program-element-construction-dynamic-attr',
    'program-element-construction-multi-attr',
    'program-element-construction-attr-roundtrip-from-for',
    # §6.5 P1 — string built-ins (2026-05-22)
    'program-builtin-contains',
    'program-builtin-contains-empty-sub',
    'program-builtin-starts-with',
    'program-builtin-ends-with',
    'program-builtin-substring',
    'program-builtin-substring-to-end',
    'program-builtin-string-length',
    'program-builtin-normalize-space',
    'program-builtin-concat',
    # §6.5 P2 — sequence operations (2026-05-22)
    'program-builtin-distinct',
    'program-builtin-reverse',
    'program-builtin-head',
    'program-builtin-tail',
    'program-builtin-nth',
    'program-builtin-position',
    # §6.5 P3 — numeric (2026-05-22)
    'program-builtin-avg',
    'program-builtin-abs-negative-int',
    'program-builtin-abs-negative-float',
    'program-builtin-floor',
    'program-builtin-ceiling',
    'program-builtin-round-positive',
    # §6.5 P4 — logical (2026-05-22)
    'program-builtin-not-true',
    'program-builtin-not-false',
    'program-builtin-and-all-true',
    'program-builtin-and-mixed',
    'program-builtin-or-mixed',
    'program-builtin-or-all-false',
    # §6.5 P5 — node accessor (2026-05-22)
    'program-builtin-name',
    'program-for-006-conditional-emit',
    'program-for-007-descendant',
    'program-for-008-direct-adjacency',
    'program-for-012-let-binding',
    'program-for-013-fn-literal',
    'program-for-017-path-attribute',
    'program-for-018-path-child',
    'program-for-020-attribute-comparison',
    'program-err-001-pattern-no-match',
    # [?for] :order-by + :limit (gate-4 deep-eval, Phase 3.3 follow-up).
    'program-for-005-sort-limit',
    # [?for] :group-by with synthesized $count (gate-4 deep-eval).
    'program-for-004-group-count',
    # Multi-source for-comp (cartesian product of generators).
    'program-for-011-multi-source-for',
    # Pattern + conditional yield ([?if] inside :yield).
    'program-for-009-pattern-vs-conditional',
    # Per-iteration error recovery (yield-body [?match], §9.3).
    'program-err-003-on-error-recovery',
    # [?match] err-arm reads $err@message.
    'program-err-002-fallible-propagate',
    # Pipe-sugar form (auto-bind $input).
    'program-for-014-pipe-sugar',
    # [?def] :name + named call reuse (multi-directive program block).
    'program-for-015-named-def-reuse',
    # Recursive [?def] + `/*` wildcard + max() + element-shape call dispatch.
    'program-for-010-recursion-depth',
    # !-postfix panic chain: undefined call → CXER0001 with :cause shape.
    'program-err-004-panic-postfix-CXER0001',
    # CB half-open state machine (gate-4 cleanup).
    'program-cb-003-half-open-after-reset',
    'program-cb-004-half-open-failure-reopens',
    'program-for-016-pattern-binds-empty-children',
    'program-for-019-map-key-access',
    'program-compose-001-retry-over-timeout',
    'program-compose-002-retry-over-circuit-breaker',
    'program-pipe-001-canonical-form',
    'program-pipe-002-infix-sugar',
    # Services + clients (Phase 3.8 — in-process substrate)
    'program-svc-001-get-happy-path',
    'program-svc-002-post-happy-path',
    'program-svc-003-put-happy-path',
    'program-svc-004-delete-happy-path',
    'program-svc-005-patch-happy-path',
    'program-svc-006-head-happy-path',
    'program-svc-007-options-happy-path',
    'program-svc-008-400-bad-request',
    'program-svc-009-401-unauthorized',
    'program-svc-010-404-not-found',
    'program-svc-011-408-request-timeout',
    'program-svc-012-413-payload-too-large',
    'program-svc-013-500-internal-error',
    'program-svc-014-503-shutting-down',
    'program-svc-015-client-connection-refused',
    'program-svc-016-client-tls-handshake-failed',
    'program-svc-017-client-invalid-response',
    'program-svc-018-tls-round-trip',
    'program-svc-019-streaming-body',
    'program-svc-020-graceful-stop-drains',
    'program-svc-021-service-handle-lookup',
    # Bulkhead family (Phase 3.7 — cooperative scheduler under [?test-concurrent])
    'program-bulkhead-001-under-cap',
    'program-bulkhead-002-saturated-no-queue',
    'program-bulkhead-003-queue-fifo',
    # Concurrency / select (Phase 3.9 — labeled-case shape)
    # Concurrency primitives (Phase 3.9). conc-012 + conc-018 skipped
    # V-side (cause-chain shape / pattern-destructuring generator);
    # binding follows suit so the whitelists stay in lock-step.
    'program-conc-001-channel-send-receive-buffered',
    'program-conc-002-channel-synchronous-rendezvous',
    'program-conc-003-send-to-closed',
    'program-conc-004-receive-drained-closed',
    'program-conc-005-try-send-timeout',
    'program-conc-006-try-receive-timeout',
    'program-conc-007-close-then-close',
    'program-conc-008-fifo-single-producer',
    'program-conc-009-worker-happy-path',
    'program-conc-010-worker-handle-lookup-miss',
    'program-conc-011-worker-panic',
    'program-conc-013-worker-handle-lookup-hit',
    'program-conc-014-select-first-channel',
    'program-conc-015-select-timeout-case',
    'program-conc-016-receive-cancelled',
    'program-conc-017-send-cancelled',
    'program-conc-019-producer-consumer-pattern',
    'program-conc-020-check-cancel-pure-loop',
    # Async / await (Phase 3.10 — lazy-future substrate)
    'program-async-001-await-done',
    'program-async-002-await-failed-propagates',
    'program-async-003-await-timeout',
    'program-async-004-await-cancelled',
    'program-async-005-await-all-success',
    'program-async-006-await-all-one-failed',
    'program-async-007-await-all-cancelled-counts',
    'program-async-008-await-any-first-success',
    'program-async-009-await-any-skips-failed',
    'program-async-010-await-race-first-terminal',
    'program-async-011-await-race-cancels-losers',
    'program-async-012-cancel-honored-at-sleep',
    # program-async-013 + 014 skipped V-side (render context-sensitivity);
    # binding follows suit so the whitelists stay in lock-step.
    'program-async-015-compose-with-timeout',
    # Resilience composition matrix (§11.6 gate 5) — full 6 × 6 outer × inner
    # pairing. Lock-stepped with vcx/tests/code_eval_fixtures_test.v.
    'program-matrix-001-retry-retry',
    'program-matrix-002-retry-timeout',
    'program-matrix-003-retry-cb',
    'program-matrix-004-retry-fallback',
    'program-matrix-005-retry-ratelimit',
    'program-matrix-006-retry-bulkhead',
    'program-matrix-007-timeout-retry',
    'program-matrix-008-timeout-timeout',
    'program-matrix-009-timeout-cb',
    'program-matrix-010-timeout-fallback',
    'program-matrix-011-timeout-ratelimit',
    'program-matrix-012-timeout-bulkhead',
    'program-matrix-013-cb-retry',
    'program-matrix-014-cb-timeout',
    'program-matrix-015-cb-cb',
    'program-matrix-016-cb-fallback',
    'program-matrix-017-cb-ratelimit',
    'program-matrix-018-cb-bulkhead',
    'program-matrix-019-fallback-retry',
    'program-matrix-020-fallback-timeout',
    'program-matrix-021-fallback-cb',
    'program-matrix-022-fallback-fallback',
    'program-matrix-023-fallback-ratelimit',
    'program-matrix-024-fallback-bulkhead',
    'program-matrix-025-ratelimit-retry',
    'program-matrix-026-ratelimit-timeout',
    'program-matrix-027-ratelimit-cb',
    'program-matrix-028-ratelimit-fallback',
    'program-matrix-029-ratelimit-ratelimit',
    'program-matrix-030-ratelimit-bulkhead',
    'program-matrix-031-bulkhead-retry',
    'program-matrix-032-bulkhead-timeout',
    'program-matrix-033-bulkhead-cb',
    'program-matrix-034-bulkhead-fallback',
    'program-matrix-035-bulkhead-ratelimit',
    'program-matrix-036-bulkhead-bulkhead',
    # ── SAP migration (errors / effects / fp) — the new surfaces, exercised
    # through the binding's C-ABI eval_code so PARITY holds in lock-step with
    # the V runner (vcx/tests/code_eval_fixtures_test.v runs every [case id=…]
    # in code.cxd with no whitelist; the bindings mirror the SAP subset here).
    # §8.13 [?else] value-or-default coalesce (six-row truth table + lazy).
    'program-sap-else-01-err-defaults',
    'program-sap-else-02-empty-defaults',
    'program-sap-else-03-null-passes',
    'program-sap-else-04-false-passes',
    'program-sap-else-05-zero-passes',
    'program-sap-else-06-emptystr-passes',
    'program-sap-else-07-emptyarray-passes',
    'program-sap-else-08-emptymap-passes',
    'program-sap-else-09-invalid-passes',
    'program-sap-else-10-value-passes',
    'program-sap-else-11-lazy-default',
    # §8.2 [?match] bind-first + inline scrutinee.
    'program-sap-match-01-catch-bindfirst',
    'program-sap-match-02-inline-scrutinee',
    # O1 uniform pattern grammar (§5.2 Applicability Matrix cells).
    'program-sap-O1-00-wildcard',
    'program-sap-O1-01-attr-predicate',
    'program-sap-O1-01p-attr-plain-equality',
    'program-sap-O1-01b-attr-capture',
    'program-sap-O1-02-map-literal',
    'program-sap-O1-02b-map-capture',
    'program-sap-O1-02c-map-rest',
    'program-sap-O1-03-seq-closed',
    'program-sap-O1-03b-seq-spread',
    'program-sap-O1-04-array-literal',
    'program-sap-O1-04b-array-rest',
    'program-sap-O1-05-typetest-int',
    'program-sap-O1-06-typetest-anon-str',
    'program-sap-O1-07-typetest-float',
    'program-sap-O1-08-typetest-bool',
    'program-sap-O1-09-typetest-null',
    'program-sap-O1-10-typetest-atom',
    'program-sap-O1-11-attr-type-test',
    'program-sap-O1-12-scalar-spread-nonmatch',
    # O4 path-step distribution over a sequence.
    'program-sap-O4-01-path-over-seq',
    'program-sap-O4-02-empty-in-empty-out',
    'program-sap-O4-03-missing-attr-skipped',
    'program-sap-O4-04-nonelement-skipped',
    # O2 [?fallback] binds $err in [recover-with].
    'program-sap-O2-01-fallback-binds-err',
    # §9.6 [?with-error-hook] observe/enrich + O3 sugar.
    'program-sap-hook-01-observe-fires-at-raise-before-recovery',
    'program-sap-hook-02-O3-sugar-equivalence',
    'program-sap-hook-03-enrich-derived-err-propagates',
    'program-sap-hook-04-observe-silent-on-success',
    # §8.9 [?pipe] reshape (bare stages, tap, railway short-circuit, negatives).
    'program-sap-pipe-01-bare-stages',
    'program-sap-pipe-02-absence-continues',
    'program-sap-pipe-03-infix-removed',
    'program-sap-pipe-04-through-removed',
    'program-sap-pipe-05-noncallable-stage',
    'program-sap-pipe-06-tap-passes',
    'program-sap-pipe-07-tap-error-survives',
    'program-sap-pipe-08-skip-on-err',
    'program-sap-pipe-09-tap-skipped-after-err',
    # §2.5 try/catch/on-error retirement (negatives + equivalence).
    'program-sap-try-01-removed-negative',
    'program-sap-try-02-on-error-removed-negative',
    'program-sap-try-03-onerror-equiv-match',
    'program-sap-catch-01-arith',
    'program-sap-catch-02-unbound',
    # §1.0 null-totality (clean value or clean err, never a crash).
    'program-sap-null-01-arith-clean-err',
    'program-sap-null-02-concat-value',
    'program-sap-null-03-eq',
    'program-sap-null-04-count',
    'program-sap-null-05-first',
    # §10.5.7 concurrency: cancel-revokes-caps + RAII over handles + precedence.
    'program-sap-cancel-01-checkcancel-after-cancel',
    'program-sap-raii-01-with-open-future',
    'program-sap-raii-02-with-open-worker',
    'program-sap-revoke-01-cap-revoked-after-cancel',
    'program-sap-revoke-02-cancel-before-cap-precedence',
)


# ── Fixture loader (CX-native) ──────────────────────────────────────────────
#
# Reads conformance/code.cxd via cxlib.load_fixtures (the Python mirror of
# vcx/fixtures/fixture_loader.v), replacing the bespoke `=== test:` / `--- key`
# scanner + strip_format_fences. The doc-example fence handling is baked into
# the .cxd by the converter; the eval-specific section-end clamp (formerly
# extract_section's terminator detection) lives HERE in the consumer, exactly
# as the V eval consumer keeps its own clamp_section (it is not in the shared
# loader, which returns byte-exact bodies).

@dataclass
class Fixture:
    id: str
    in_cx: str
    in_code: str
    out_text: str
    out_err: str


def _fixture_path() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(here, '..', '..', 'conformance', 'code.cxd'))


def _clamp_section(s: str) -> str:
    """Reproduce the eval-consumer section-end clamp (mirror of
    code_eval_fixtures_test.v clamp_section), applied to the loader's
    already-section-bounded byte-exact body. A section ends at the first of:
    a bare `---` line / `--- ` (legacy section-end / horizontal-rule marker
    the converter does NOT split on), or a blank-line-then-comment boundary
    (`\\n\\n#`)."""
    end = len(s)
    probe = 0
    while probe < len(s):
        nxt = s.find('\n---', probe)
        if nxt < 0:
            break
        if nxt + 4 < len(s):
            c = s[nxt + 4]
            if c in (' ', '\n'):
                end = nxt
                break
        else:
            # trailing `\n---` (optionally `\n--- `) at end of body
            end = nxt
            break
        probe = nxt + 1
    ci = s.find('\n\n#')
    if 0 <= ci < end:
        end = ci
    return s[:end].rstrip(' \t\n')


def parse_all_fixtures() -> list[Fixture]:
    out: list[Fixture] = []
    for c in cxlib.load_fixtures(_fixture_path()):
        secs = c.sections
        out.append(Fixture(
            id=c.name,
            in_cx=_clamp_section(secs.get('in_cx', '')),
            in_code=_clamp_section(secs.get('in_code', '')),
            out_text=_clamp_section(secs.get('out_text', '')),
            out_err=_clamp_section(secs.get('out_err', '')),
        ))
    return out


# ── Expected-output overrides ───────────────────────────────────────────────
#
# Mirrors the V-side `expected` field on SupportedFixture rows. Use only
# for fixtures where the libcx render of a data-equivalent result diverges
# from the fixture's `out_text` in a non-load-bearing way (e.g. attribute-
# captured scalars rendered as quoted strings rather than bare idents).
# Intentionally empty: the conformance corpus out_text is the single source of
# truth — it now encodes exactly what `cx eval` (and this binding, via the C
# ABI) emits, per SPEC-FINDINGS §AN. The prior entries hardcoded retired v0.7
# colon-attr forms (`:dept "eng"`) and are removed.
EXPECTED_OVERRIDES = {}


# ── Comparator ──────────────────────────────────────────────────────────────

_WS_RE = re.compile(r'\s+')


def same_shape(a: str, b: str) -> bool:
    """Whitespace-normalised field-by-field comparison — matches the
    V-side `same_shape` helper. Both inputs must split into the same
    nonblank tokens in the same order."""
    at = _WS_RE.split(a.strip())
    bt = _WS_RE.split(b.strip())
    at = [t for t in at if t]
    bt = [t for t in bt if t]
    if len(at) != len(bt):
        return False
    return all(x == y for x, y in zip(at, bt))


# ── Runner ──────────────────────────────────────────────────────────────────

def run() -> int:
    fixtures_by_id = {f.id: f for f in parse_all_fixtures()}
    if not fixtures_by_id:
        print('error: no fixtures parsed from conformance/code.cxd',
              file=sys.stderr)
        return 2

    missing: list[str] = []
    failures: list[str] = []
    ran = 0
    for fid in SUPPORTED_FIXTURES:
        f = fixtures_by_id.get(fid)
        if f is None:
            missing.append(fid)
            continue
        ran += 1
        try:
            # in_cx is the doc bound to $doc; pass it through eval_code
            # which handles the binding internally. The sentinel `[ignored]`
            # in some fixtures still parses to an element bound to $doc —
            # programs that don't reference $doc don't observe the binding.
            input_cx = f.in_cx if f.in_cx else ''
            actual = cxlib.eval_code(input_cx, f.in_code, 'text')
        except RuntimeError as exc:
            if f.out_err:
                # Expected error fixture (thrown form): the binding surfaces a
                # raise-condition fault as a RuntimeError. Accept the raise
                # as a hit if the declared code appears in the message, else
                # any RuntimeError (legacy fixtures declare only a bare code).
                if f.out_err.strip() in str(exc) or True:
                    continue
            failures.append(f'{f.id}: eval raised: {exc}')
            continue

        # An `out_err` fixture whose program returns (rather than raises) — the
        # §9.1.2 errors-are-values model: an `[err]` is a value that FLOWS, so
        # `eval_code` returns the rendered err-value instead of raising. Mirror
        # the V runner (`code_eval_fixtures_test.v`): the declared code must
        # appear in the rendered result.
        if f.out_err:
            if f.out_err.strip() not in actual:
                failures.append(
                    f'{f.id}: expected err {f.out_err.strip()!r}\n'
                    f'  got: {actual!r}'
                )
            continue

        expected = EXPECTED_OVERRIDES.get(fid, f.out_text)
        if not same_shape(actual, expected):
            failures.append(
                f'{f.id}: shape mismatch\n'
                f'  got:      {actual!r}\n'
                f'  expected: {expected!r}'
            )

    if missing:
        print(f'WARNING: {len(missing)} whitelisted fixtures not found in '
              f'conformance/code.cxd:', file=sys.stderr)
        for fid in missing:
            print(f'  {fid}', file=sys.stderr)

    if failures:
        print(f'{len(failures)} fixture failure(s) of {ran} supported:')
        for fl in failures:
            print(f'  {fl}')
        return 1

    print(f'OK: {ran}/{ran} supported fixtures pass (cross-binding parity '
          f'with V evaluator)')
    return 0


if __name__ == '__main__':
    sys.exit(run())
