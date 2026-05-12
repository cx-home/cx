# frozen_string_literal: true
#
# Streaming Table + schema-driven + chunked-table tests for the Ruby
# binding (Phase 7.74b-cont-3). Mirrors the Python / Swift / C# /
# Java / Kotlin / Go / Rust / TypeScript suites: 4 streaming-Table
# cases (in-memory round-trip, fd round-trip, closed-handle errors,
# multi-row-group reuse) + 1 schema-driven round-trip.
#
# Run from ruby/cxlib/: ruby test/test_streaming_table.rb

require 'tempfile'
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

# Six-row table; values stay distinctive after the round trip even after
# the col-spec exchange normalizes the outer element name.
SMALL_TABLE_CX = <<~CX.freeze
  [points :table[name:string score:i32]
    alice 91
    bob 88
    carol 73
    dave 95
    eve 84
    frank 60
  ]
CX

# ── 1. in-memory round-trip ──────────────────────────────────────────────────

run_test 'in-memory round-trip via TableReader → TableWriter' do
  payload = CXLib.to_data_bin_chunked(SMALL_TABLE_CX)
  raise "expected payload >12 bytes, got #{payload.bytesize}" unless payload.bytesize > 12
  framed = reframe(payload)

  reader = CXLib::TableReader.new(data_bin: framed)
  schema = reader.schema
  raise "expected non-empty framed schema, got #{schema.bytesize}" unless schema.bytesize > 4
  groups = reader.to_a
  reader.close
  raise "expected at least one row group, got #{groups.size}" if groups.empty?

  writer = CXLib::TableWriter.new(schema)
  groups.each { |g| writer.emit(g) }
  rebuilt = writer.close_get_bytes
  cx = CXLib.from_data_bin(rebuilt)
  raise "rebuilt CX must contain :table marker; got: #{cx}" unless cx.include?(':table')
  %w[alice frank 91 60].each do |needle|
    raise "rebuilt CX must include row value #{needle}; got: #{cx}" unless cx.include?(needle)
  end
end

# ── 2. fd round-trip ─────────────────────────────────────────────────────────

run_test 'fd round-trip via TableWriter(fd:) → TableReader(fd:)' do
  payload = CXLib.to_data_bin_chunked(SMALL_TABLE_CX)
  reader_in = CXLib::TableReader.new(data_bin: reframe(payload))
  schema = reader_in.schema
  groups = reader_in.to_a
  reader_in.close

  Tempfile.create(['cx_ruby_streaming_', '.cxdb']) do |tf|
    tf.binmode
    writer = CXLib::TableWriter.new(schema, fd: tf.fileno)
    groups.each { |g| writer.emit(g) }
    writer.close
    tf.flush
    tf.rewind

    rfile = File.open(tf.path, 'rb')
    begin
      reader_out = CXLib::TableReader.new(fd: rfile.fileno)
      schema_out = reader_out.schema
      groups_out = reader_out.to_a
      reader_out.close
      raise 'fd schema drift' unless schema_out == schema
      raise "fd group count drift #{groups_out.size} vs #{groups.size}" \
        unless groups_out.size == groups.size
    ensure
      rfile.close
    end
  end
end

# ── 3. closed-handle errors ──────────────────────────────────────────────────

run_test 'closed-handle errors on reader and writer' do
  payload = CXLib.to_data_bin_chunked(SMALL_TABLE_CX)
  framed = reframe(payload)

  # Reader: schema() on closed handle raises.
  reader = CXLib::TableReader.new(data_bin: framed)
  reader.close
  raise 'next_row_group on closed reader should yield nil' unless reader.next_row_group.nil?
  begin
    reader.schema
    raise 'expected RuntimeError from schema() on closed reader'
  rescue RuntimeError => e
    raise "expected 'closed' in error: #{e.message}" unless e.message.include?('closed')
  end

  # Writer: emit() after close_get_bytes raises.
  reader2 = CXLib::TableReader.new(data_bin: framed)
  schema = reader2.schema
  groups = reader2.to_a
  reader2.close

  writer = CXLib::TableWriter.new(schema)
  groups.each { |g| writer.emit(g) }
  writer.close_get_bytes
  begin
    writer.emit(groups.first)
    raise 'expected RuntimeError from emit() after close_get_bytes'
  rescue RuntimeError => e
    raise "expected 'closed' in error: #{e.message}" unless e.message.include?('closed')
  end
end

# ── 4. multi-row-group reuse via writer pipe ─────────────────────────────────

run_test 'multi-row-group merge through one TableWriter' do
  cx1 = '[points :table[name:string score:i32] alice 91 bob 88]'
  cx2 = '[points :table[name:string score:i32] carol 73 dave 95 eve 84]'
  p1 = CXLib.to_data_bin_chunked(cx1)
  p2 = CXLib.to_data_bin_chunked(cx2)

  r1 = CXLib::TableReader.new(data_bin: reframe(p1))
  schema = r1.schema
  g1 = r1.to_a
  r1.close

  r2 = CXLib::TableReader.new(data_bin: reframe(p2))
  g2 = r2.to_a
  r2.close

  raise 'expected at least one group from each source' if g1.empty? || g2.empty?

  writer = CXLib::TableWriter.new(schema)
  g1.each { |g| writer.emit(g) }
  g2.each { |g| writer.emit(g) }
  rebuilt = writer.close_get_bytes
  cx = CXLib.from_data_bin(rebuilt)
  %w[alice bob carol dave eve].each do |needle|
    raise "merged CX must include #{needle}; got: #{cx}" unless cx.include?(needle)
  end
end

# ── 5. schema-driven round-trip ──────────────────────────────────────────────

run_test 'schema-driven encode/decode round-trip' do
  cx_text  = '[server [host "localhost"] [port 8080]]'
  schema   = '[server [host :string] [port :int]]'
  payload  = CXLib.to_data_bin_schema_driven(cx_text, schema)
  raise "expected payload >12 bytes, got #{payload.bytesize}" unless payload.bytesize > 12

  framed = reframe(payload)
  out = CXLib.from_data_bin_schema_driven(framed, schema_hint: schema)
  raise "round-trip must reproduce 'server'; got: #{out}"    unless out.include?('server')
  raise "round-trip must reproduce 'localhost'; got: #{out}" unless out.include?('localhost')
  raise "round-trip must reproduce '8080'; got: #{out}"      unless out.include?('8080')
end

# ── summary ──────────────────────────────────────────────────────────────────

status = $failed.zero? ? 'OK' : 'FAILED'
puts "\nruby/test_streaming_table.rb: #{$passed} passed, #{$failed} failed  [#{status}]"
exit($failed.zero? ? 0 : 1)
