#!/usr/bin/env tsx
/**
 * ID/IDREF tests for the TypeScript binding (ADR 0003).
 * Mirrors lang/python/test_identity.py and V conformance/identity.txt.
 */
import * as assert from 'assert';
import { parse, Element, Document } from './cxlib/src/ast';
import { idLookup, resolveRef, nodeId } from './cxlib/src/index';

function root(d: Document): Element {
  for (const n of d.elements) {
    if (n instanceof Element) return n;
  }
  throw new Error('no root element');
}

const tests: Array<[string, () => void]> = [
  ['id_declaration_only_round_trips', () => {
    const cxIn = '[user #u-1 name=alice]';
    const doc = parse(cxIn);
    assert.strictEqual(root(doc).id, 'u-1');
    assert.strictEqual(doc.to_cx(), cxIn);
  }],
  ['id_with_anchor_coexists', () => {
    const doc = parse('[item &a #u-1 v=42]');
    const item = root(doc);
    assert.strictEqual(item.anchor, 'a');
    assert.strictEqual(item.id, 'u-1');
  }],
  ['attribute_value_reference_marked_is_ref', () => {
    const doc = parse('[users [user #u-1 name=alice] [reviewer assigned-to=@u-1]]');
    const reviewer = doc.findFirst('reviewer')!;
    const a = reviewer.attrs.find(x => x.name === 'assigned-to')!;
    assert.strictEqual(a.isRef, true);
    assert.strictEqual(a.value, 'u-1');
  }],
  ['resolve_id_finds_declared_element', () => {
    const doc = parse('[users [user #u-1 name=alice] [user #u-2 name=bob]]');
    assert.strictEqual(doc.resolveId('u-1')!.attr('name'), 'alice');
    assert.strictEqual(doc.resolveId('u-2')!.attr('name'), 'bob');
    assert.strictEqual(doc.resolveId('u-3'), null);
  }],
  ['elements_by_id_builds_full_map', () => {
    const doc = parse('[a #x v=1] [b #y v=2] [c #z v=3]');
    const m = doc.elementsById();
    assert.strictEqual(Object.keys(m).length, 3);
    assert.strictEqual(m['x'].name, 'a');
    assert.strictEqual(m['y'].name, 'b');
    assert.strictEqual(m['z'].name, 'c');
  }],
  ['quoted_at_literal_is_not_a_reference', () => {
    const cxIn = "[item label='@literal']";
    const doc = parse(cxIn);
    const label = root(doc).attrs.find(a => a.name === 'label')!;
    assert.ok(!label.isRef);
    assert.strictEqual(label.value, '@literal');
    assert.strictEqual(doc.to_cx(), cxIn);
  }],
  ['forward_reference_resolves', () => {
    const doc = parse('[users [reviewer assigned-to=@u-1] [user #u-1 name=alice]]');
    const user = doc.resolveId('u-1');
    assert.notStrictEqual(user, null);
    assert.strictEqual(user!.attr('name'), 'alice');
  }],
  ['nested_id_and_ref_round_trip', () => {
    const cxIn = '[doc\n  [users\n    [user #u-1 name=alice]\n  ]\n  [reviews\n    [review target=@u-1 score=5]\n  ]\n]';
    const doc = parse(cxIn);
    assert.notStrictEqual(doc.resolveId('u-1'), null);
    const review = doc.findFirst('review')!;
    const target = review.attrs.find(a => a.name === 'target')!;
    assert.strictEqual(target.isRef, true);
    assert.strictEqual(target.value, 'u-1');
  }],
  // ── Phase 7.65 / ADR 0003 — ID/IDREF C ABI wrappers ────────────────────────
  ['c_abi_id_lookup_happy_path', () => {
    const cxIn = '[users [user #u-1 name=alice] [user #u-2 name=bob] [reviewer assigned-to=@u-1]]';
    const out = idLookup(cxIn, 'u-1');
    assert.notStrictEqual(out, null);
    const obj = JSON.parse(out!);
    assert.strictEqual(obj.type, 'Element');
    assert.strictEqual(obj.name, 'user');
    assert.strictEqual(obj.id, 'u-1');
  }],
  ['c_abi_id_lookup_missing_returns_null', () => {
    const cxIn = '[users [user #u-1 name=alice] [user #u-2 name=bob] [reviewer assigned-to=@u-1]]';
    assert.strictEqual(idLookup(cxIn, 'does-not-exist'), null);
  }],
  ['c_abi_resolve_ref_equals_id_lookup', () => {
    const cxIn = '[users [user #u-1 name=alice] [user #u-2 name=bob] [reviewer assigned-to=@u-2]]';
    assert.strictEqual(resolveRef(cxIn, 'u-2'), idLookup(cxIn, 'u-2'));
  }],
  ['c_abi_node_id_at_cxpath', () => {
    const cxIn = '[users [user #u-1 name=alice] [user #u-2 name=bob] [reviewer assigned-to=@u-1]]';
    assert.strictEqual(nodeId(cxIn, '//user'), 'u-1');
    assert.strictEqual(nodeId(cxIn, '//reviewer'), null);
  }],
  ['body_ref_survives_ast_bin_round_trip', () => {
    // ADR 0003 D1 / Phase 7.70: ast_bin v3 carries Element.bodyRef.
    const cxIn = '[doc [section #section-3 [para See [ref @section-3].]]]';
    const doc = parse(cxIn);
    const para = doc.findFirst('para')!;
    let ref: Element | null = null;
    for (const item of para.items) {
      if (item instanceof Element && item.name === 'ref') {
        ref = item;
        break;
      }
    }
    assert.notStrictEqual(ref, null);
    assert.strictEqual(ref!.bodyRef, 'section-3');
    assert.strictEqual(ref!.attrs.length, 0);
    assert.strictEqual(ref!.items.length, 0);
    assert.ok(doc.to_cx().includes('[ref @section-3]'));
  }],
  ['multiple_refs_to_same_id', () => {
    const doc = parse(
      '[users [user #u-1 name=alice] '
      + '[reviewer assigned-to=@u-1] '
      + '[approver checked-by=@u-1]]'
    );
    let count = 0;
    for (const el of [...doc.findAll('reviewer'), ...doc.findAll('approver')]) {
      for (const a of el.attrs) {
        if (a.isRef && a.value === 'u-1') count++;
      }
    }
    assert.strictEqual(count, 2);
  }],
];

let passed = 0;
let failed = 0;
for (const [name, fn] of tests) {
  try {
    fn();
    console.log(`ok  ${name}`);
    passed++;
  } catch (e: any) {
    console.log(`FAIL ${name}: ${e.message}`);
    failed++;
  }
}
console.log(`\n${passed}/${passed + failed} passed`);
process.exit(failed ? 1 : 0);
