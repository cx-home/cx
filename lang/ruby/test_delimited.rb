# frozen_string_literal: true
#
# Round-trip tests for the Ruby delimited (CSV/TSV/PSV) wrappers
# (Phase 7.67 V core; Phase 7.68 Ruby binding).
#
# Mirrors the 12-case shape of lang/python/test_delimited.py and
# lang/go/cxlib/delimited_test.go.
#
# Run: ruby lang/ruby/test_delimited.rb
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

def reframe(payload)
  size = [payload.bytesize].pack('V')
  size + payload
end

# ── Emit (5) ─────────────────────────────────────────────────────────────────

run_test 'to_csv table direct' do
  src = "[users :table[name:string age:int active:bool]\n  alice 30 true\n  bob 25 false\n]"
  out = CXLib.to_csv(src)
  assert_eq("name,age,active\r\nalice,30,true\r\nbob,25,false\r\n", out)
end

run_test 'to_csv repeated row' do
  src = "[users\n  [user id=1 name=alice +admin]\n  [user id=2 name=bob]\n  [user id=3 name=carol +admin]\n]"
  out = CXLib.to_csv(src)
  assert_eq("id,name,admin\r\n1,alice,true\r\n2,bob,\r\n3,carol,true\r\n", out)
end

run_test 'to_csv dotted path' do
  src = "[config\n  [server host=localhost port=8080 +tls]\n  [logging level=info format=json]\n]"
  out = CXLib.to_csv(src)
  expected = "server.host,server.port,server.tls,logging.level,logging.format\r\nlocalhost,8080,true,info,json\r\n"
  assert_eq(expected, out)
end

run_test 'to_tsv' do
  src = "[t :table[a b c]\n  x y z\n]"
  out = CXLib.to_tsv(src)
  assert_eq("a\tb\tc\r\nx\ty\tz\r\n", out)
end

run_test 'to_psv' do
  src = "[t :table[a b]\n  x y\n]"
  out = CXLib.to_psv(src)
  assert_eq("a|b\r\nx|y\r\n", out)
end

# ── Parse (3) ────────────────────────────────────────────────────────────────

run_test 'from_csv basic auto-types' do
  csv_in = "name,age,active\nalice,30,true\nbob,25,false\n"
  out = CXLib.from_csv(csv_in)
  expected = "[table :table[name age:int active:bool]\n  alice 30 true\n  bob 25 false\n]"
  assert_eq(expected, out)
end

run_test 'from_csv quoted stays string' do
  csv_in = "name,age\nalice,\"30\"\nbob,\"25\"\n"
  out = CXLib.from_csv(csv_in)
  expected = "[table :table[name age]\n  alice 30\n  bob 25\n]"
  assert_eq(expected, out)
end

run_test 'from_csv empty cell is null' do
  csv_in = "name,age\nalice,30\nbob,\n"
  out = CXLib.from_csv(csv_in)
  expected = "[table :table[name age:int]\n  alice 30\n  bob null\n]"
  assert_eq(expected, out)
end

# ── Arbitrary delimiter + binary one-shots (4) ───────────────────────────────

run_test 'to_delimited semicolon' do
  src = "[t :table[a b]\n  x y\n]"
  out = CXLib.to_delimited(src, ';')
  assert_eq("a;b\r\nx;y\r\n", out)
end

run_test 'csv_to_data_bin round-trip' do
  payload = CXLib.csv_to_data_bin("name,age\nalice,30\nbob,25\n")
  raise "expected non-empty payload" unless payload.bytesize > 4
  raise "expected CXDB magic, got #{payload[0, 4].inspect}" unless payload[0, 4] == 'CXDB'
  out = CXLib.data_bin_to_csv(reframe(payload))
  assert_eq("name,age\r\nalice,30\r\nbob,25\r\n", out)
end

run_test 'tsv_to_data_bin round-trip' do
  payload = CXLib.tsv_to_data_bin("a\tb\nx\ty\n")
  out = CXLib.data_bin_to_tsv(reframe(payload))
  assert_eq("a\tb\r\nx\ty\r\n", out)
end

run_test 'psv_to_data_bin round-trip' do
  payload = CXLib.psv_to_data_bin("a|b\nx|y\n")
  out = CXLib.data_bin_to_psv(reframe(payload))
  assert_eq("a|b\r\nx|y\r\n", out)
end

# ── summary ──────────────────────────────────────────────────────────────────

status = $failed.zero? ? 'OK' : 'FAILED'
puts "\nruby/test_delimited.rb: #{$passed} passed, #{$failed} failed  [#{status}]"
exit($failed.zero? ? 0 : 1)
