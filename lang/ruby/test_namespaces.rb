# frozen_string_literal: true
#
# Namespace resolution tests for the Ruby CX binding (ADR 0002).
# Mirrors lang/python/test_namespaces.py.
# Run: ruby lang/ruby/test_namespaces.rb
#
require_relative 'cxlib/lib/cxlib'

$passed = 0
$failed = 0

def run_test(name)
  yield
  $passed += 1
  print "  PASS  #{name}\n"
rescue => e
  $failed += 1
  print "  FAIL  #{name}\n"
  print "    #{e.class}: #{e.message}\n"
  print "    #{e.backtrace.first(2).join("\n    ")}\n"
end

def assert_eq(expected, actual, msg = nil)
  raise "expected #{expected.inspect}, got #{actual.inspect}#{" (#{msg})" if msg}" \
    if expected != actual
end

def root(d)
  d.elements.find { |n| n.is_a?(CXLib::Element) } or raise 'no root element'
end

run_test('default_namespace_inherits_to_descendants') do
  doc = CXLib.parse('[html xmlns=http://www.w3.org/1999/xhtml [body [p Hi]]]')
  html = root(doc)
  assert_eq 'html', html.local_name
  assert_eq 'http://www.w3.org/1999/xhtml', html.namespace_uri
  body = html.items.find { |n| n.is_a?(CXLib::Element) && n.name == 'body' }
  assert_eq 'http://www.w3.org/1999/xhtml', body.namespace_uri
end

run_test('default_namespace_does_not_apply_to_attrs') do
  doc = CXLib.parse('[html xmlns=urn:x id=top body]')
  id = root(doc).attrs.find { |a| a.name == 'id' }
  assert_eq nil, id.namespace_uri
  assert_eq 'id', id.local_name
end

run_test('prefixed_element_resolves') do
  doc = CXLib.parse('[doc xmlns:dc=http://purl.org/dc/elements/1.1/ [dc:title Hi]]')
  title = root(doc).items.find { |n| n.is_a?(CXLib::Element) && n.name == 'dc:title' }
  assert_eq 'title', title.local_name
  assert_eq 'http://purl.org/dc/elements/1.1/', title.namespace_uri
end

run_test('prefixed_attribute_resolves') do
  doc = CXLib.parse('[doc xmlns:xl=http://www.w3.org/1999/xlink [link xl:href=https://example.com Click]]')
  link = root(doc).items.find { |n| n.is_a?(CXLib::Element) && n.name == 'link' }
  href = link.attrs.find { |a| a.name == 'xl:href' }
  assert_eq 'href', href.local_name
  assert_eq 'http://www.w3.org/1999/xlink', href.namespace_uri
end

run_test('reserved_xml_prefix') do
  doc = CXLib.parse('[doc xml:base=https://example.com content]')
  base = root(doc).attrs.find { |a| a.name == 'xml:base' }
  assert_eq CXLib::XML_NAMESPACE_URI, base.namespace_uri
end

run_test('reserved_cx_prefix') do
  doc = CXLib.parse('[doc [cx:meta key=value]]')
  meta = root(doc).items.find { |n| n.is_a?(CXLib::Element) && n.name == 'cx:meta' }
  assert_eq CXLib::CX_NAMESPACE_URI, meta.namespace_uri
end

run_test('undeclared_prefix') do
  doc = CXLib.parse('[doc [foo:bar baz]]')
  bar = root(doc).items.find { |n| n.is_a?(CXLib::Element) && n.name == 'foo:bar' }
  assert_eq 'bar', bar.local_name
  assert_eq nil, bar.namespace_uri
end

run_test('redeclaration_overrides_default') do
  doc = CXLib.parse(
    "[html xmlns=http://www.w3.org/1999/xhtml\n  [body\n    [svg xmlns=http://www.w3.org/2000/svg\n      [circle r=10]\n    ]\n  ]\n]"
  )
  html = root(doc)
  body = html.items.find { |n| n.is_a?(CXLib::Element) && n.name == 'body' }
  svg = body.items.find { |n| n.is_a?(CXLib::Element) && n.name == 'svg' }
  circle = svg.items.find { |n| n.is_a?(CXLib::Element) && n.name == 'circle' }
  assert_eq 'http://www.w3.org/1999/xhtml', html.namespace_uri
  assert_eq 'http://www.w3.org/1999/xhtml', body.namespace_uri
  assert_eq 'http://www.w3.org/2000/svg', svg.namespace_uri
  assert_eq 'http://www.w3.org/2000/svg', circle.namespace_uri
end

run_test('empty_uri_undeclares') do
  doc = CXLib.parse("[outer xmlns=urn:x [inner xmlns='' [child x=1]]]")
  outer = root(doc)
  inner = outer.items.find { |n| n.is_a?(CXLib::Element) && n.name == 'inner' }
  child = inner.items.find { |n| n.is_a?(CXLib::Element) && n.name == 'child' }
  assert_eq 'urn:x', outer.namespace_uri
  assert_eq nil, inner.namespace_uri
  assert_eq nil, child.namespace_uri
end

run_test('resolve_is_idempotent') do
  doc = CXLib.parse('[doc xmlns:dc=http://purl.org/dc/elements/1.1/ [dc:title Hi]]')
  title = root(doc).items.find { |n| n.is_a?(CXLib::Element) && n.name == 'dc:title' }
  first = title.namespace_uri
  CXLib.resolve_namespaces(doc)
  CXLib.resolve_namespaces(doc)
  second = title.namespace_uri
  assert_eq first, second
  assert_eq 'http://purl.org/dc/elements/1.1/', first
end

run_test('xmlns_declaration_attrs_have_no_uri') do
  doc = CXLib.parse('[doc xmlns:dc=http://purl.org/dc/elements/1.1/ body]')
  decl = root(doc).attrs.find { |a| a.name == 'xmlns:dc' }
  assert_eq nil, decl.namespace_uri
  assert_eq 'dc', decl.local_name
end

print "\nruby/test_namespaces: #{$passed} passed, #{$failed} failed  [#{$failed.zero? ? 'OK' : 'FAILED'}]\n"
exit($failed.zero? ? 0 : 1)
