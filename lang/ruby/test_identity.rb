# frozen_string_literal: true
#
# ID/IDREF tests for the Ruby CX binding (ADR 0003).
# Mirrors V conformance/identity.txt and lang/python/test_identity.py.
# Run: ruby lang/ruby/test_identity.rb
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

def assert_true(cond, msg = nil)
  raise "expected true#{" (#{msg})" if msg}" unless cond
end

def root(d)
  d.elements.find { |e| e.is_a?(CXLib::Element) }
end

run_test('id_declaration_only_round_trips') do
  cx_in = '[user #u-1 name=alice]'
  doc = CXLib.parse(cx_in)
  assert_eq 'u-1', root(doc).id
  assert_eq cx_in, doc.to_cx
end

run_test('id_with_anchor_coexists') do
  doc = CXLib.parse('[item &a #u-1 v=42]')
  item = root(doc)
  assert_eq 'a',   item.anchor
  assert_eq 'u-1', item.id
end

run_test('attribute_value_reference_marked_is_ref') do
  doc = CXLib.parse('[users [user #u-1 name=alice] [reviewer assigned-to=@u-1]]')
  reviewer = doc.find_first('reviewer')
  a = reviewer.attrs.find { |x| x.name == 'assigned-to' }
  assert_true a.is_ref
  assert_eq 'u-1', a.value
end

run_test('resolve_id_finds_declared_element') do
  doc = CXLib.parse('[users [user #u-1 name=alice] [user #u-2 name=bob]]')
  assert_eq 'alice', doc.resolve_id('u-1').attr('name')
  assert_eq 'bob',   doc.resolve_id('u-2').attr('name')
  assert_true doc.resolve_id('u-3').nil?
end

run_test('elements_by_id_builds_full_map') do
  doc = CXLib.parse('[a #x v=1] [b #y v=2] [c #z v=3]')
  m = doc.elements_by_id
  assert_eq 3, m.size
  assert_eq 'a', m['x'].name
  assert_eq 'b', m['y'].name
  assert_eq 'c', m['z'].name
end

run_test('quoted_at_literal_is_not_a_reference') do
  cx_in = "[item label='@literal']"
  doc = CXLib.parse(cx_in)
  label = root(doc).attrs.find { |a| a.name == 'label' }
  assert_true !label.is_ref
  assert_eq '@literal', label.value
  assert_eq cx_in, doc.to_cx
end

run_test('forward_reference_resolves') do
  doc = CXLib.parse('[users [reviewer assigned-to=@u-1] [user #u-1 name=alice]]')
  user = doc.resolve_id('u-1')
  assert_true !user.nil?
  assert_eq 'alice', user.attr('name')
end

run_test('nested_id_and_ref_round_trip') do
  cx_in = "[doc\n  [users\n    [user #u-1 name=alice]\n  ]\n  [reviews\n    [review target=@u-1 score=5]\n  ]\n]"
  doc = CXLib.parse(cx_in)
  assert_true !doc.resolve_id('u-1').nil?
  review = doc.find_first('review')
  target = review.attrs.find { |a| a.name == 'target' }
  assert_true target.is_ref
  assert_eq 'u-1', target.value
end

run_test('body_ref_survives_ast_bin_round_trip') do
  # Phase 7.70 — ast_bin v3 carries body_ref through the V↔binding
  # boundary. The field is populated post-parse from the v3 wire bytes,
  # not re-detected from text.
  cx_in = '[doc [section #section-3 [para See [ref @section-3].]]]'
  doc = CXLib.parse(cx_in)
  section = doc.find_first('section')
  para = section.find_first('para')
  body_ref_node = para.items.find { |c| c.is_a?(CXLib::Element) && c.name == 'ref' }
  assert_true !body_ref_node.nil?
  assert_eq 'section-3', body_ref_node.body_ref
  assert_eq [], body_ref_node.attrs
  assert_eq [], body_ref_node.items
  assert_true doc.to_cx.include?('[ref @section-3]')
end

run_test('multiple_refs_to_same_id') do
  doc = CXLib.parse(
    "[users [user #u-1 name=alice] " \
    "[reviewer assigned-to=@u-1] " \
    "[approver checked-by=@u-1]]"
  )
  count = 0
  (doc.find_all('reviewer') + doc.find_all('approver')).each do |el|
    el.attrs.each { |a| count += 1 if a.is_ref && a.value == 'u-1' }
  end
  assert_eq 2, count
end

print "\n#{$passed}/#{$passed + $failed} passed\n"
exit($failed == 0 ? 0 : 1)
