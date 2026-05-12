#!/usr/bin/env tsx
/**
 * Namespace resolution tests for the TypeScript binding (ADR 0002).
 * Mirrors lang/python/test_namespaces.py.
 */
import * as assert from 'assert';
import {
  parse, resolveNamespaces, Element, Document,
  XML_NAMESPACE_URI, CX_NAMESPACE_URI,
} from './cxlib/src/ast';

function root(d: Document): Element {
  for (const n of d.elements) {
    if (n instanceof Element) return n;
  }
  throw new Error('no root element');
}

const tests: Array<[string, () => void]> = [
  ['default_namespace_inherits_to_descendants', () => {
    const doc = parse('[html xmlns=http://www.w3.org/1999/xhtml [body [p Hi]]]');
    const html = root(doc);
    assert.strictEqual(html.localName(), 'html');
    assert.strictEqual(html.namespaceUri(), 'http://www.w3.org/1999/xhtml');
    const body = html.get('body')!;
    assert.strictEqual(body.namespaceUri(), 'http://www.w3.org/1999/xhtml');
  }],
  ['default_namespace_does_not_apply_to_attrs', () => {
    const doc = parse('[html xmlns=urn:x id=top body]');
    const id = root(doc).attrs.find(a => a.name === 'id')!;
    assert.strictEqual(id.nsUri ?? null, null);
    assert.strictEqual(id.local, 'id');
  }],
  ['prefixed_element_resolves', () => {
    const doc = parse('[doc xmlns:dc=http://purl.org/dc/elements/1.1/ [dc:title Hi]]');
    const title = root(doc).get('dc:title')!;
    assert.strictEqual(title.localName(), 'title');
    assert.strictEqual(title.namespaceUri(), 'http://purl.org/dc/elements/1.1/');
  }],
  ['prefixed_attribute_resolves', () => {
    const doc = parse(
      '[doc xmlns:xl=http://www.w3.org/1999/xlink [link xl:href=https://example.com Click]]'
    );
    const link = root(doc).get('link')!;
    const href = link.attrs.find(a => a.name === 'xl:href')!;
    assert.strictEqual(href.local, 'href');
    assert.strictEqual(href.nsUri, 'http://www.w3.org/1999/xlink');
  }],
  ['reserved_xml_prefix_resolves_without_declaration', () => {
    const doc = parse('[doc xml:base=https://example.com content]');
    const base = root(doc).attrs.find(a => a.name === 'xml:base')!;
    assert.strictEqual(base.nsUri, XML_NAMESPACE_URI);
  }],
  ['reserved_cx_prefix_resolves_without_declaration', () => {
    const doc = parse('[doc [cx:meta key=value]]');
    const meta = root(doc).get('cx:meta')!;
    assert.strictEqual(meta.namespaceUri(), CX_NAMESPACE_URI);
  }],
  ['undeclared_prefix_passes_through_unbound', () => {
    const doc = parse('[doc [foo:bar baz]]');
    const bar = root(doc).get('foo:bar')!;
    assert.strictEqual(bar.localName(), 'bar');
    assert.strictEqual(bar.namespaceUri(), null);
  }],
  ['redeclaration_in_subtree_overrides_default', () => {
    const doc = parse(
      '[html xmlns=http://www.w3.org/1999/xhtml\n  [body\n    [svg xmlns=http://www.w3.org/2000/svg\n      [circle r=10]\n    ]\n  ]\n]'
    );
    const html = root(doc);
    const body = html.get('body')!;
    const svg = body.get('svg')!;
    const circle = svg.get('circle')!;
    assert.strictEqual(html.namespaceUri(), 'http://www.w3.org/1999/xhtml');
    assert.strictEqual(body.namespaceUri(), 'http://www.w3.org/1999/xhtml');
    assert.strictEqual(svg.namespaceUri(), 'http://www.w3.org/2000/svg');
    assert.strictEqual(circle.namespaceUri(), 'http://www.w3.org/2000/svg');
  }],
  ['xmlns_undeclaration_with_empty_uri', () => {
    const doc = parse("[outer xmlns=urn:x [inner xmlns='' [child x=1]]]");
    const outer = root(doc);
    const inner = outer.get('inner')!;
    const child = inner.get('child')!;
    assert.strictEqual(outer.namespaceUri(), 'urn:x');
    assert.strictEqual(inner.namespaceUri(), null);
    assert.strictEqual(child.namespaceUri(), null);
  }],
  ['resolve_namespaces_is_idempotent', () => {
    const doc = parse('[doc xmlns:dc=http://purl.org/dc/elements/1.1/ [dc:title Hi]]');
    const first = root(doc).get('dc:title')!.namespaceUri();
    resolveNamespaces(doc);
    resolveNamespaces(doc);
    const second = root(doc).get('dc:title')!.namespaceUri();
    assert.strictEqual(first, second);
    assert.strictEqual(first, 'http://purl.org/dc/elements/1.1/');
  }],
  ['xmlns_declaration_attrs_have_no_resolved_uri', () => {
    const doc = parse('[doc xmlns:dc=http://purl.org/dc/elements/1.1/ body]');
    const decl = root(doc).attrs.find(a => a.name === 'xmlns:dc')!;
    assert.strictEqual(decl.nsUri ?? null, null);
    assert.strictEqual(decl.local, 'dc');
  }],
];

let passed = 0, failed = 0;
for (const [name, fn] of tests) {
  try {
    fn();
    console.log(`ok  ${name}`);
    passed++;
  } catch (e: any) {
    console.log(`FAIL ${name}: ${e?.message ?? e}`);
    failed++;
  }
}
console.log(`\n${passed}/${tests.length} passed`);
process.exit(failed ? 1 : 0);
