# frozen_string_literal: true
#
# ID/IDREF C ABI tests for the Ruby CX binding (ADR 0003 / Phase 7.65).
# Mirrors lang/python/test_id_abi.py and lang/go/cxlib/id_abi_test.go.
# Run: ruby lang/ruby/test_id_abi.rb
#
require 'json'
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

DOC = <<~CX
  [users
    [user #u-1 name=alice]
    [user #u-2 name=bob]
    [reviewer assigned-to=@u-1]
  ]
CX

run_test('id_lookup_happy_path') do
  out = CXLib.id_lookup(DOC, 'u-1')
  assert_true !out.empty?, 'expected non-empty AST-JSON for #u-1'
  obj = JSON.parse(out)
  assert_eq 'Element', obj['type']
  assert_eq 'user',    obj['name']
  assert_eq 'u-1',     obj['id']
end

run_test('id_lookup_missing_returns_empty') do
  out = CXLib.id_lookup(DOC, 'does-not-exist')
  assert_eq '', out
end

run_test('resolve_ref_equals_id_lookup') do
  a = CXLib.id_lookup(DOC, 'u-2')
  b = CXLib.resolve_ref(DOC, 'u-2')
  assert_true !a.empty?, 'id_lookup u-2 should return non-empty'
  assert_eq a, b
end

run_test('node_id_at_cxpath') do
  assert_eq 'u-1', CXLib.node_id(DOC, '//user')
  assert_eq '',    CXLib.node_id(DOC, '//reviewer')
end

print "\n#{$passed} passed, #{$failed} failed\n"
exit($failed.zero? ? 0 : 1)
