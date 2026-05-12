# frozen_string_literal: true
#
# Public Table API tests (ADR 0018 D1). Run from lang/ruby/:
#   ruby cxlib/test/test_table.rb
#
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'cxlib'

$passed = 0
$failed = 0

def run_test(name)
  yield
  $passed += 1
  print "  PASS  #{name}\n"
rescue => e
  $failed += 1
  print "  FAIL  #{name}: #{e.class}: #{e.message}\n"
  e.backtrace.first(3).each { |l| print "        #{l}\n" }
end

def assert_eq(a, b, msg = nil)
  raise "expected #{b.inspect}, got #{a.inspect}#{msg ? " — #{msg}" : ''}" unless a == b
end

def assert(cond, msg = nil)
  raise (msg || 'assertion failed') unless cond
end

def assert_raises(klass = StandardError, includes: nil)
  yield
  raise "expected #{klass} to be raised"
rescue klass => e
  if includes && !e.message.include?(includes)
    raise "expected error to include #{includes.inspect}, got #{e.message.inspect}"
  end
end

puts "\n── Table API — construction"

run_test('from_cx parses simple table') do
  src = <<~CX
    [users :table[name age:int]
      alice 30
      bob 25
    ]
  CX
  t = CXLib::Table.from_cx(src)
  assert_eq(t.row_count, 2)
  assert_eq(t.col_count, 2)
end

run_test('from_cx with no table raises') do
  assert_raises(includes: 'no :table') do
    CXLib::Table.from_cx("[product name=alice]")
  end
end

run_test('create validates len mismatch') do
  assert_raises(includes: 'len(cols)') do
    CXLib::Table.create(%w[a b], ['int'], [])
  end
end

run_test('create validates duplicate column names') do
  assert_raises(includes: 'duplicate') do
    CXLib::Table.create(%w[a a], %w[int int], [])
  end
end

puts "\n── Table API — access"

run_test('row + column by name') do
  t = CXLib::Table.create(%w[a b], %w[int string], [[1, 'x'], [2, 'y']])
  r = t.row(0)
  assert_eq(r['a'], 1)
  assert_eq(r['b'], 'x')
  assert_eq(t.column('b'), %w[x y])
end

run_test('slice / head / tail') do
  t = CXLib::Table.create(%w[v], %w[int], [[1], [2], [3], [4], [5]])
  assert_eq(t.head(2).row_count, 2)
  assert_eq(t.tail(2).row_count, 2)
  assert_eq(t.slice(1, 4).row_count, 3)
end

run_test('select_cols reorders') do
  t = CXLib::Table.create(%w[a b c], %w[int int int], [[1, 2, 3]])
  sel = t.select_cols(%w[c a])
  assert_eq(sel.cols, %w[c a])
end

puts "\n── Table API — iteration / conversion"

run_test('each iterates rows') do
  t = CXLib::Table.create(%w[a], %w[int], [[1], [2]])
  sum = 0
  t.each { |row| sum += row['a'] }
  assert_eq(sum, 3)
end

run_test('to_cx contains header') do
  t = CXLib::Table.create(%w[a], %w[int], [[1]])
  assert(t.to_cx.include?(':table[a:int]'))
end

run_test('to_json contains key/value') do
  t = CXLib::Table.create(%w[a], %w[int], [[1], [2]])
  assert(t.to_json.include?('"a":1'))
end

run_test('equality on equal tables') do
  a = CXLib::Table.create(%w[a], %w[int], [[1]])
  b = CXLib::Table.create(%w[a], %w[int], [[1]])
  assert_eq(a, b)
end

run_test('from_cx collection cells produce arrays') do
  src = <<~CX
    [u :table[name tags]
      alice [admin, user,]
    ]
  CX
  t = CXLib::Table.from_cx(src)
  r = t.row(0)
  assert(r['tags'].is_a?(Array), "tags should be Array, got: #{r['tags'].inspect}")
end

puts "\nruby/test_table: #{$passed} passed, #{$failed} failed  [#{$failed.zero? ? 'OK' : 'FAILED'}]"
exit($failed.zero? ? 0 : 1)
