# frozen_string_literal: true
#
# Round-trip tests for the Ruby data_bin one-shot wrappers
# (Phase 7.28 V core; Phase 7.38 Ruby binding).
#
# Loaders return UNFRAMED PAYLOAD bytes (frame stripped via _call_bin).
# Dumpers expect FRAMED input. Tests use reframe() to bridge.
#
# Run from ruby/cxlib/: ruby test/test_data_bin_one_shots.rb
#
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'cxlib'

# ── test runner ──────────────────────────────────────────────────────────────

$passed = 0
$failed = 0

def run_test(name)
  yield
  $passed += 1
  print "  PASS  #{name}\n"
rescue => e
  $failed += 1
  print "  FAIL  #{name}: #{e.message}\n"
end

def reframe(payload)
  size = [payload.bytesize].pack('V')
  size + payload
end

# ── XML one-shot ─────────────────────────────────────────────────────────────

run_test 'xml_to_data_bin returns CXDB payload' do
  payload = CXLib.xml_to_data_bin('<server><host>localhost</host><port>8080</port></server>')
  raise "expected non-empty payload, got #{payload.bytesize}" unless payload.bytesize > 4
  raise "expected CXDB magic, got #{payload[0,4].inspect}" unless payload[0, 4] == 'CXDB'
end

run_test 'xml round-trip through data_bin' do
  payload = CXLib.xml_to_data_bin('<server><host>localhost</host><port>8080</port></server>')
  out = CXLib.data_bin_to_xml(reframe(payload))
  raise "expected server: #{out}" unless out.include?('server')
  raise "expected localhost: #{out}" unless out.include?('localhost')
  raise "expected 8080: #{out}" unless out.include?('8080')
end

# ── JSON / YAML / TOML / MD round-trips ──────────────────────────────────────

run_test 'json round-trip through data_bin' do
  payload = CXLib.json_to_data_bin('{"name": "alice", "id": 1}')
  out = CXLib.data_bin_to_json(reframe(payload))
  raise "expected alice: #{out}" unless out.include?('alice')
  raise "expected 1: #{out}" unless out.include?('1')
end

run_test 'yaml round-trip through data_bin' do
  payload = CXLib.yaml_to_data_bin("name: alice\nid: 1\n")
  out = CXLib.data_bin_to_yaml(reframe(payload))
  raise "expected alice: #{out}" unless out.include?('alice')
end

run_test 'toml round-trip through data_bin' do
  payload = CXLib.toml_to_data_bin("name = \"alice\"\nid = 1\n")
  out = CXLib.data_bin_to_toml(reframe(payload))
  raise "expected alice: #{out}" unless out.include?('alice')
end

run_test 'md round-trip through data_bin' do
  payload = CXLib.md_to_data_bin("# Title\n\nA paragraph.\n")
  out = CXLib.data_bin_to_md(reframe(payload))
  raise "expected Title: #{out}" unless out.include?('Title')
end

# ── Cross-format compositions ────────────────────────────────────────────────

run_test 'xml → data_bin → json' do
  payload = CXLib.xml_to_data_bin('<user id="1" name="alice"/>')
  out = CXLib.data_bin_to_json(reframe(payload))
  raise "expected alice: #{out}" unless out.include?('alice')
  raise "expected 1: #{out}" unless out.include?('1')
end

run_test 'json → data_bin → yaml' do
  payload = CXLib.json_to_data_bin('{"name": "alice", "active": true}')
  out = CXLib.data_bin_to_yaml(reframe(payload))
  raise "expected alice: #{out}" unless out.include?('alice')
end

run_test 'toml → data_bin → xml' do
  payload = CXLib.toml_to_data_bin("host = \"localhost\"\nport = 8080\n")
  out = CXLib.data_bin_to_xml(reframe(payload))
  raise "expected localhost: #{out}" unless out.include?('localhost')
  raise "expected 8080: #{out}" unless out.include?('8080')
end

# ── summary ──────────────────────────────────────────────────────────────────

status = $failed.zero? ? 'OK' : 'FAILED'
puts "\nruby/test_data_bin_one_shots.rb: #{$passed} passed, #{$failed} failed  [#{status}]"
exit($failed.zero? ? 0 : 1)
