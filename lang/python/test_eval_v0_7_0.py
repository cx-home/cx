"""v0.7.0 evaluator-surface smoke tests through the Python binding.

Per spec/v0_7_0_status.md H2. These tests exercise the new v0.7.0
evaluator features end-to-end through cxlib (which calls libcx via
C ABI). The same surface is exercised at much higher granularity by
the V conformance runner against conformance/eval.txt; this file
is the cross-binding parity sanity check.

Run via `make test-python-eval-v0-7-0` or:

    DYLD_LIBRARY_PATH=vcx/target python3 -m unittest \\
      lang.python.test_eval_v0_7_0 -v
"""

import os
import sys
import unittest

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'lang', 'python'))

import cxlib  # noqa: E402


class EvalV070(unittest.TestCase):
    """Each test names the corresponding A/B/C/J/Y row item per
    spec/v0_7_0_status.md."""

    def assertEval(self, doc: str, prog: str, expected: str, target: str = ''):
        actual = cxlib.eval_cxl(doc, prog, target)
        self.assertEqual(actual, expected,
                         f'\n  doc:      {doc}\n  prog:     {prog}'
                         f'\n  expected: {expected!r}\n  got:      {actual!r}')

    # A7 ?let positional / labeled
    def test_let_positional(self):
        self.assertEval(
            '[product price=12]',
            '[?let [v, @price, [?=v]]]',
            '12',
        )

    def test_let_labeled(self):
        self.assertEval(
            '[product name=Pocket]',
            '[?let g :be @name :return [?=g]]',
            'Pocket',
        )

    # A8/A9/A10 FLWOR
    def test_flwor_where(self):
        self.assertEval(
            '[p [v s=A in=1] [v s=B in=0] [v s=C in=2]]',
            '[?for x :in //v :where x/@in > 0 :return [?=x/@s];]',
            'A;C;',
        )

    def test_flwor_order_by(self):
        self.assertEval(
            '[p [v s=C] [v s=A] [v s=B]]',
            '[?for x :in //v :order-by x/@s :return [?=x/@s];]',
            'A;B;C;',
        )

    def test_flwor_group_by(self):
        self.assertEval(
            '[p [v c=red n=1] [v c=blue n=2] [v c=red n=3]]',
            '[?for x :in //v :group-by [k, x/@c] :return [g [?=k]:[?for y :in x :return [?=y/@n];]] ]',
            '[g red:1;3;][g blue:2;]',
        )

    # A13/A14 windowing
    def test_for_tumbling(self):
        self.assertEval(
            '[r [v n=1] [v n=2] [v n=3] [v n=4] [v n=5]]',
            '[?for-tumbling w :in //v :size 2 :return [?for x :in w :return [?=x/@n]];]',
            '12;34;5;',
        )

    # A19-A23 ?fn + partial
    def test_fn_and_apply(self):
        self.assertEval(
            '[p]',
            "[?let dbl :be [?fn :params [n] :body [?=n][?=n]] :return [?=[?apply [dbl, 'X']]]]",
            'XX',
        )

    def test_partial_middle_placeholder(self):
        self.assertEval(
            '[p]',
            "[?let f :be [?partial [[?fn-ref [concat, 2]], [?_], '!']] :return [?=[?apply [f, 'hi']]]]",
            'hi!',
        )

    # A16/A17 ?try multi-catch
    def test_try_multi_catch(self):
        self.assertEval(
            '[p]',
            "[?try [[?error ['FORG0006', 'wrong type']], [FOAR*, math], [FORG*, generic], [*, other]]]",
            'generic',
        )

    # B-row CXPath axes
    def test_parent_axis(self):
        self.assertEval(
            '[root [outer tag=O [inner n=42]]]',
            '[?for x :in //inner/parent::* :return [?=x/@tag];]',
            'O;',
        )

    def test_following_sibling(self):
        self.assertEval(
            '[r [a n=1] [b n=2] [c n=3]]',
            '[?for x :in //a/following-sibling::* :return [?=x/@n];]',
            '2;3;',
        )

    # Operator-token forms
    def test_op_pipeline(self):
        self.assertEval(
            '[p name=alice]',
            '[?=@name |> upper]',
            'ALICE',
        )

    def test_op_to_range(self):
        self.assertEval(
            '[p]',
            '[?for x :in 1 to 4 :return [?=x];]',
            '1;2;3;4;',
        )

    def test_op_string_concat(self):
        self.assertEval(
            '[u first=Alice last=Smith]',
            "[?=@first || '-' || @last]",
            'Alice-Smith',
        )

    # J0 attribute-value interpolation
    def test_attr_value_interpolation(self):
        self.assertEval(
            '[p [c cid=42 name=Joe]]',
            '[?for c :in //c :return [a href=/u/[?=c/@cid]/p/[?=c/@name]]]',
            '[a href=/u/42/p/Joe]',
        )

    # C5 regex
    def test_fn_matches_regex(self):
        self.assertEval(
            "[p s='hello42']",
            "[?=[?matches ['[a-z]+[0-9]+', @s]]]",
            'true',
        )

    # C14/C15 date — current-date returns a 10-char ISO date
    def test_fn_current_date_shape(self):
        out = cxlib.eval_cxl('[p]', '[?=[?string-length [[?current-date]]]]', '')
        self.assertEqual(out, '10', f'current-date string-length: {out!r}')

    # Y row streaming — same output as buffered eval
    def test_streaming_matches_buffered(self):
        doc = '[r [v n=1] [v n=2] [v n=3]]'
        prog = '[?for x :in //v :return [?=x/@n]]'
        buffered = cxlib.eval_cxl(doc, prog, '')
        chunks = []
        cxlib.eval_cxl_streaming(doc, prog, lambda b: chunks.append(b))
        streamed = b''.join(chunks).decode('utf-8')
        self.assertEqual(buffered, streamed)

    # ── DD (cx: self-host module) cross-binding smoke tests ──────────────

    # DD3 cx:canonical wraps cx_text_canonical — idempotent on already-
    # canonical input
    def test_cx_canonical_smoke(self):
        out = cxlib.eval_cxl(
            "[p]",
            "[?=[?cx:canonical [[?cx:parse ['[product name=A]']]]]]",
            '',
        )
        self.assertIn('product', out)
        self.assertIn('name=A', out)

    # DD4 cx:hash — SHA-256 hex of canonical form; same input → same hash
    def test_cx_hash_deterministic(self):
        prog = "[?=[?cx:hash [[?cx:parse ['[r x=1]']]]]]"
        h1 = cxlib.eval_cxl("[p]", prog, '')
        h2 = cxlib.eval_cxl("[p]", prog, '')
        self.assertEqual(h1, h2)
        self.assertEqual(len(h1), 64, f'expected 64-char hex digest, got: {h1!r}')

    # DD7 cx:to-format json
    def test_cx_to_format_json(self):
        out = cxlib.eval_cxl(
            "[p]",
            "[?=[?cx:to-format [[?cx:parse ['[u name=alice]']], 'json']]]",
            '',
        )
        self.assertIn('alice', out)
        self.assertIn('"', out, f'expected JSON quotes, got: {out!r}')

    # DD9 cx:equal — canonical-aware equality (identical inputs)
    def test_cx_equal_identical(self):
        out = cxlib.eval_cxl(
            "[p]",
            "[?=[?cx:equal [[?cx:parse ['[r a=1]']], [?cx:parse ['[r a=1]']]]]]",
            '',
        )
        self.assertEqual(out, 'true', f'identical inputs should be equal: {out!r}')

    def test_cx_equal_distinct(self):
        out = cxlib.eval_cxl(
            "[p]",
            "[?=[?cx:equal [[?cx:parse ['[a]']], [?cx:parse ['[b]']]]]]",
            '',
        )
        self.assertEqual(out, 'false', f'distinct inputs should differ: {out!r}')

    # DD11 cx:eval — gated; missing allow-eval raises CXER0041
    def test_cx_eval_default_off_raises(self):
        try:
            cxlib.eval_cxl("[p]", "[?cx:eval ['[?=1]', {}]]", '')
            self.fail('expected CXER0041 from cx:eval without allow-eval')
        except Exception as e:
            self.assertIn('CXER0041', str(e), f'got: {e!r}')

    # DD11 cx:eval — engine runs once allow-eval set
    def test_cx_eval_with_allow_eval(self):
        out = cxlib.eval_cxl(
            "[p]",
            "[?cx allow-eval=true][?cx:eval ['[?=1]', {}]]",
            '',
        )
        self.assertIn('1', out)

    # DD12 cx:render — same engine, returns rendered text
    def test_cx_render_with_allow_eval(self):
        out = cxlib.eval_cxl(
            "[p]",
            "[?cx allow-eval=true][?cx:render ['[?=42]', {}]]",
            '',
        )
        self.assertIn('42', out)

    # ── FF (log: structured-logging) cross-binding smoke tests ───────────

    # FF3 log:info — SideEffect; output goes to stderr or file. Under
    # [?cx pure-only] (EE4) it raises CXER0040; verify the gate fires
    # since stdout/stderr capture isn't portable across binding shims.
    def test_log_info_under_pure_only_refused(self):
        try:
            cxlib.eval_cxl(
                "[p]",
                "[?cx pure-only][?log:info ['hello', {}]]",
                '',
            )
            self.fail('expected CXER0040 — log: is SideEffect under pure-only')
        except Exception as e:
            self.assertIn('CXER0040', str(e), f'got: {e!r}')

    # FF6 log:level — ReadOnly; returns current effective level
    def test_log_level_returns_string(self):
        out = cxlib.eval_cxl(
            "[p]",
            "[?cx log-level=debug][?=[?log:level]]",
            '',
        )
        self.assertEqual(out, 'debug', f'got: {out!r}')


if __name__ == '__main__':
    unittest.main(verbosity=2)
