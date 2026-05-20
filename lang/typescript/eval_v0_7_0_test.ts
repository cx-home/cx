#!/usr/bin/env tsx
/**
 * v0.7.0 evaluator-surface smoke tests through the TypeScript binding.
 * Per spec/v0_7_0_status.md H5. Cross-binding parity sanity check;
 * the V conformance runner against conformance/eval.txt is the
 * authoritative per-feature gate.
 *
 * Run via `make test-typescript-eval-v0-7-0` or:
 *   tsx lang/typescript/eval_v0_7_0_test.ts
 */
import * as assert from 'assert';
import { evalCxl, evalCxlStreaming } from './cxlib/src/index';

function check(label: string, doc: string, prog: string, expected: string) {
  const got = evalCxl(doc, prog, '');
  assert.strictEqual(got, expected, `${label}: got ${JSON.stringify(got)} want ${JSON.stringify(expected)}`);
  console.log(`✓ ${label}`);
}

// A7 ?let
check('let_positional', '[product price=12]', '[?let [v, @price, [?=v]]]', '12');
check('let_labeled', '[product name=Pocket]', '[?let g :be @name :return [?=g]]', 'Pocket');

// A8/A9/A10 FLWOR
check('flwor_where',
  '[p [v s=A in=1] [v s=B in=0] [v s=C in=2]]',
  '[?for x :in //v :where x/@in > 0 :return [?=x/@s];]',
  'A;C;');
check('flwor_order_by',
  '[p [v s=C] [v s=A] [v s=B]]',
  '[?for x :in //v :order-by x/@s :return [?=x/@s];]',
  'A;B;C;');

// A13 ?for-tumbling
check('for_tumbling',
  '[r [v n=1] [v n=2] [v n=3] [v n=4] [v n=5]]',
  '[?for-tumbling w :in //v :size 2 :return [?for x :in w :return [?=x/@n]];]',
  '12;34;5;');

// A19/A20 ?fn + apply
check('fn_and_apply', '[p]',
  "[?let dbl :be [?fn :params [n] :body [?=n][?=n]] :return [?=[?apply [dbl, 'X']]]]",
  'XX');

// A23 ?partial middle-position [?_]
check('partial_middle_placeholder', '[p]',
  "[?let f :be [?partial [[?fn-ref [concat, 2]], [?_], '!']] :return [?=[?apply [f, 'hi']]]]",
  'hi!');

// A16 ?try multi-catch
check('try_multi_catch', '[p]',
  "[?try [[?error ['FORG0006', 'wrong type']], [FOAR*, math], [FORG*, generic], [*, other]]]",
  'generic');

// B-row CXPath axes
check('parent_axis',
  '[root [outer tag=O [inner n=42]]]',
  '[?for x :in //inner/parent::* :return [?=x/@tag];]',
  'O;');
check('following_sibling',
  '[r [a n=1] [b n=2] [c n=3]]',
  '[?for x :in //a/following-sibling::* :return [?=x/@n];]',
  '2;3;');

// Operator-token forms
check('op_pipeline', '[p name=alice]', '[?=@name |> upper]', 'ALICE');
check('op_to_range', '[p]', '[?for x :in 1 to 4 :return [?=x];]', '1;2;3;4;');
check('op_string_concat',
  '[u first=Alice last=Smith]',
  "[?=@first || '-' || @last]",
  'Alice-Smith');

// J0 attr-value interpolation
check('attr_value_interpolation',
  '[p [c cid=42 name=Joe]]',
  '[?for c :in //c :return [a href=/u/[?=c/@cid]/p/[?=c/@name]]]',
  '[a href=/u/42/p/Joe]');

// C5 regex
check('fn_matches_regex',
  "[p s='hello42']",
  "[?=[?matches ['[a-z]+[0-9]+', @s]]]",
  'true');

// Y row streaming
{
  const doc = '[r [v n=1] [v n=2] [v n=3]]';
  const prog = '[?for x :in //v :return [?=x/@n]]';
  const buffered = evalCxl(doc, prog, '');
  let streamed = '';
  evalCxlStreaming(doc, prog, (chunk) => { streamed += chunk; });
  assert.strictEqual(buffered, streamed,
    `streaming_matches_buffered: ${JSON.stringify(buffered)} vs ${JSON.stringify(streamed)}`);
  console.log('✓ streaming_matches_buffered');
}

// ── DD (cx: self-host module) cross-binding smoke tests ──────────────

function checkContains(label: string, doc: string, prog: string, substr: string) {
  const got = evalCxl(doc, prog, '');
  assert.ok(got.includes(substr),
    `${label}: substring ${JSON.stringify(substr)} not in ${JSON.stringify(got)}`);
  console.log(`✓ ${label}`);
}

function checkRaises(label: string, doc: string, prog: string, codeSubstr: string) {
  let raised = false;
  try {
    evalCxl(doc, prog, '');
  } catch (e: any) {
    raised = true;
    const msg = (e && e.message) || String(e);
    assert.ok(msg.includes(codeSubstr),
      `${label}: expected ${codeSubstr} in error, got ${msg}`);
  }
  assert.ok(raised, `${label}: expected ${codeSubstr} but eval succeeded`);
  console.log(`✓ ${label}`);
}

// DD3 cx:canonical — idempotent
checkContains('cx_canonical_smoke',
  '[p]',
  "[?=[?cx:canonical [[?cx:parse ['[product name=A]']]]]]",
  'product');

// DD4 cx:hash — SHA-256 hex, deterministic
{
  const prog = "[?=[?cx:hash [[?cx:parse ['[r x=1]']]]]]";
  const h1 = evalCxl('[p]', prog, '');
  const h2 = evalCxl('[p]', prog, '');
  assert.strictEqual(h1, h2, 'hash not deterministic');
  assert.strictEqual(h1.length, 64, `expected 64-char digest, got ${h1.length}: ${h1}`);
  console.log('✓ cx_hash_deterministic');
}

// DD7 cx:to-format json
checkContains('cx_to_format_json',
  '[p]',
  "[?=[?cx:to-format [[?cx:parse ['[u name=alice]']], 'json']]]",
  'alice');

// DD9 cx:equal — identical / distinct
check('cx_equal_identical',
  '[p]',
  "[?=[?cx:equal [[?cx:parse ['[r a=1]']], [?cx:parse ['[r a=1]']]]]]",
  'true');
check('cx_equal_distinct',
  '[p]',
  "[?=[?cx:equal [[?cx:parse ['[a]']], [?cx:parse ['[b]']]]]]",
  'false');

// DD11 cx:eval — default off → CXER0041
checkRaises('cx_eval_default_off_raises',
  '[p]',
  "[?cx:eval ['[?=1]', {}]]",
  'CXER0041');

// DD11 cx:eval — engine runs once allow-eval set
checkContains('cx_eval_with_allow_eval',
  '[p]',
  "[?cx allow-eval=true][?cx:eval ['[?=1]', {}]]",
  '1');

// DD12 cx:render — engine returns rendered text
checkContains('cx_render_with_allow_eval',
  '[p]',
  "[?cx allow-eval=true][?cx:render ['[?=42]', {}]]",
  '42');

// FF3 log:info under [?cx pure-only] refused (EE4)
checkRaises('log_info_under_pure_only_refused',
  '[p]',
  "[?cx pure-only][?log:info ['hi', {}]]",
  'CXER0040');

// FF6 log:level — ReadOnly; returns current effective level
check('log_level_returns_string',
  '[p]',
  '[?cx log-level=debug][?=[?log:level]]',
  'debug');

console.log('\nAll H5 v0.7.0 evaluator-surface tests pass');
