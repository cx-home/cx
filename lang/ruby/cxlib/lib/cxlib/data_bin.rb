# frozen_string_literal: true
#
# CXDB v1 codec — strict canonical binary data format.
#
# Spec: spec/data_bin.md. Decoder consumes the 12-byte-header-prefixed
# PAYLOAD returned by libcx.cx_to_data_bin (the [u32 LE size] frame is
# stripped by CXLib.to_data_bin before this module sees it). Encoder
# produces a FRAMED buffer suitable for direct hand-off to
# libcx.cx_from_data_bin.
#
# Replaces the JSON-string detour previously used by CXLib.loads /
# CXLib.dumps (audit finding CB-3). Type fidelity preserved: integers
# stay Integer (not coerced via JSON.parse's number type), floats stay
# Float, booleans stay TrueClass/FalseClass, byte strings round-trip,
# dates as Date / Time.
#
# Type mapping:
#   nil                                      <-> CXDB null
#   TrueClass / FalseClass                   <-> CXDB false/true
#   Integer                                  <-> CXDB int8/int16/int32/int64 (canonical width)
#   Float                                    <-> CXDB float64
#   String (Encoding::UTF_8 or compatible)   <-> CXDB string
#   String (Encoding::BINARY / ASCII-8BIT)   <-> CXDB bytes
#   Date                                     <-> CXDB date
#   Time / DateTime                          <-> CXDB datetime (placeholder source string in v1)
#   Hash                                     <-> CXDB map (insertion order preserved)
#   Array                                    <-> CXDB array

require 'date'
require 'time'

module CXLib
  module DataBin
    # ── Tag bytes (spec/data_bin.md §3.2) ─────────────────────────────────────
    TAG_NULL         = 0x00
    TAG_FALSE        = 0x01
    TAG_TRUE         = 0x02
    TAG_INT8         = 0x10
    TAG_INT16        = 0x11
    TAG_INT32        = 0x12
    TAG_INT64        = 0x13
    TAG_FLOAT64      = 0x20
    TAG_STRING       = 0x30
    TAG_DATE         = 0x31
    TAG_DATETIME     = 0x32
    TAG_BYTES        = 0x33
    TAG_ARRAY        = 0x40
    TAG_ARRAY_EMPTY  = 0x41
    TAG_MAP          = 0x50
    TAG_MAP_EMPTY    = 0x51
    TAG_TABLE        = 0x60
    TAG_TABLE_EMPTY  = 0x61

    CXDB_MAGIC          = 'CXDB'.b
    CXDB_VERSION        = 0x01
    CXDB_FLAGS_LE       = 0x01
    CXDB_DEFAULT_DEPTH  = 64

    I64_MIN = -(2**63)
    I64_MAX =   2**63 - 1

    # ── Decoder ───────────────────────────────────────────────────────────────

    class Reader
      def initialize(buf, max_depth)
        @buf = buf
        @pos = 0
        @depth = 0
        @max_depth = max_depth
      end

      def need(n)
        if @pos + n > @buf.bytesize
          raise "cxdb: #{n} bytes requested, #{@buf.bytesize - @pos} remaining"
        end
      end

      def u8
        raise "cxdb: unexpected end of input" if @pos >= @buf.bytesize
        v = @buf.getbyte(@pos)
        @pos += 1
        v
      end

      def u16
        need(2)
        v = @buf.byteslice(@pos, 2).unpack1('v')
        @pos += 2
        v
      end

      def u32
        need(4)
        v = @buf.byteslice(@pos, 4).unpack1('V')
        @pos += 4
        v
      end

      def i64
        need(8)
        bs = @buf.byteslice(@pos, 8)
        @pos += 8
        bs.unpack1('q<')  # little-endian signed 64
      end

      def f64
        need(8)
        bs = @buf.byteslice(@pos, 8)
        @pos += 8
        bs.unpack1('E')   # little-endian double
      end

      def take(n)
        need(n)
        out = @buf.byteslice(@pos, n)
        @pos += n
        out
      end

      def uvarint
        x = 0
        shift = 0
        5.times do |i|
          b = u8
          if b < 0x80
            raise "cxdb: varint overflow (>2^32-1)"      if i == 4 && b > 0x0F
            raise "cxdb: non-canonical varint (extra zero byte)" if i > 0 && b == 0
            return x | (b << shift)
          end
          x |= (b & 0x7F) << shift
          shift += 7
        end
        raise "cxdb: varint exceeds 5 bytes"
      end

      def string_payload
        n = uvarint
        s = take(n)
        s.force_encoding(Encoding::UTF_8)
      end

      def value
        @depth += 1
        raise "cxdb: recursion depth exceeds limit (#{@max_depth})" if @depth > @max_depth
        begin
          tag = u8
          case tag
          when TAG_NULL    then nil
          when TAG_FALSE   then false
          when TAG_TRUE    then true
          when TAG_INT8
            need(1)
            v = @buf.byteslice(@pos, 1).unpack1('c')
            @pos += 1
            v
          when TAG_INT16
            need(2)
            v = @buf.byteslice(@pos, 2).unpack1('s<')
            @pos += 2
            v
          when TAG_INT32
            need(4)
            v = @buf.byteslice(@pos, 4).unpack1('l<')
            @pos += 4
            v
          when TAG_INT64   then i64
          when TAG_FLOAT64 then f64
          when TAG_STRING  then string_payload
          when TAG_BYTES
            n = uvarint
            take(n).force_encoding(Encoding::BINARY)
          when TAG_DATE
            need(4)
            year  = @buf.byteslice(@pos, 2).unpack1('s<')
            month = @buf.getbyte(@pos + 2)
            day   = @buf.getbyte(@pos + 3)
            @pos += 4
            ::Date.new(year, month, day)
          when TAG_DATETIME
            take(10) # 10 reserved placeholder bytes
            src_len = u16
            src = take(src_len).force_encoding(Encoding::UTF_8)
            (begin
               ::Time.iso8601(src)
             rescue ArgumentError
               src
             end)
          when TAG_ARRAY
            count = uvarint
            raise "cxdb: array tag 0x40 with count=0; use 0x41 for empty" if count == 0
            out = Array.new(count)
            count.times { |i| out[i] = value }
            out
          when TAG_ARRAY_EMPTY then []
          when TAG_MAP
            count = uvarint
            raise "cxdb: map tag 0x50 with count=0; use 0x51 for empty" if count == 0
            out = {}
            count.times do
              key_tag = u8
              raise format("cxdb: map key must be string; got 0x%02x", key_tag) unless key_tag == TAG_STRING
              key = string_payload
              out[key] = value
            end
            out
          when TAG_MAP_EMPTY then {}
          when TAG_TABLE, TAG_TABLE_EMPTY then table_payload(tag)
          else
            raise format("cxdb: unknown tag 0x%02x at offset %d", tag, @pos - 1)
          end
        ensure
          @depth -= 1
        end
      end

      private

      def table_payload(tag)
        return [] if tag == TAG_TABLE_EMPTY
        col_count = uvarint
        cols = Array.new(col_count)
        col_count.times do |i|
          key_tag = u8
          raise format("cxdb: table column name must be string; got 0x%02x", key_tag) unless key_tag == TAG_STRING
          cols[i] = string_payload
          u8 # column type code (informational; per-cell tags drive decode)
        end
        row_count = uvarint
        rows = Array.new(row_count) { {} }
        col_count.times do |c|
          row_count.times do |r|
            rows[r][cols[c]] = value
          end
        end
        rows
      end
    end

    # Decode a CXDB v1 PAYLOAD (12-byte header + value section). The
    # [u32 LE size] frame is expected to have already been stripped by
    # CXLib.to_data_bin; pass the raw payload bytes directly.
    def self.decode(payload, max_depth: CXDB_DEFAULT_DEPTH)
      raise "cxdb: payload too short for 12-byte header" if payload.bytesize < 12
      raise "cxdb: bad magic (expected 'CXDB')" unless payload.byteslice(0, 4) == CXDB_MAGIC
      raise "cxdb: unsupported version #{payload.getbyte(4)}" unless payload.getbyte(4) == CXDB_VERSION

      flags = payload.getbyte(5)
      raise "cxdb: reserved flag bits set in header" if (flags & 0xFE) != 0
      raise "cxdb: only little-endian payloads supported in v1" if (flags & 0x01) == 0
      raise "cxdb: reserved header bytes must be zero" unless payload.getbyte(10) == 0 && payload.getbyte(11) == 0

      tail = payload.byteslice(12, payload.bytesize - 12).force_encoding(Encoding::BINARY)
      Reader.new(tail, max_depth).value
    end

    # ── Encoder ───────────────────────────────────────────────────────────────

    class Writer
      attr_reader :buf

      def initialize
        @buf = String.new(capacity: 256, encoding: Encoding::BINARY)
      end

      def u8(v)  ; @buf << [v].pack('C')  ; end
      def u16(v) ; @buf << [v].pack('v')  ; end
      def u32(v) ; @buf << [v].pack('V')  ; end
      def i64(v) ; @buf << [v].pack('q<') ; end
      def f64(v) ; @buf << [v].pack('E')  ; end
      def raw(b) ; @buf << b              ; end

      def uvarint(v)
        while v >= 0x80
          @buf << [(v & 0x7F) | 0x80].pack('C')
          v >>= 7
        end
        @buf << [v & 0x7F].pack('C')
      end

      def string_value(s)
        u8(TAG_STRING)
        enc = s.encode(Encoding::UTF_8)
        bytes = enc.b
        uvarint(bytes.bytesize)
        raw(bytes)
      end

      def int_canonical(v)
        raise "cxdb: integer #{v} exceeds i64 range" if v < I64_MIN || v > I64_MAX
        if v >= -128 && v <= 127
          u8(TAG_INT8)
          @buf << [v].pack('c')
        elsif v >= -32768 && v <= 32767
          u8(TAG_INT16)
          @buf << [v].pack('s<')
        elsif v >= -2_147_483_648 && v <= 2_147_483_647
          u8(TAG_INT32)
          @buf << [v].pack('l<')
        else
          u8(TAG_INT64)
          i64(v)
        end
      end
    end

    def self.encode_value(v, w)
      case v
      when nil
        w.u8(TAG_NULL)
      when true
        w.u8(TAG_TRUE)
      when false
        w.u8(TAG_FALSE)
      when Integer
        w.int_canonical(v)
      when Float
        w.u8(TAG_FLOAT64)
        w.f64(v)
      when String
        if v.encoding == Encoding::BINARY
          w.u8(TAG_BYTES)
          w.uvarint(v.bytesize)
          w.raw(v)
        else
          w.string_value(v)
        end
      when Symbol
        w.string_value(v.to_s)
      when ::Date
        # ::Date is the parent class of DateTime; check for that case first.
        if v.is_a?(::DateTime)
          encode_datetime(v.to_time, w)
        else
          w.u8(TAG_DATE)
          w.u16(v.year & 0xFFFF)
          w.u8(v.month)
          w.u8(v.day)
        end
      when ::Time
        encode_datetime(v, w)
      when Hash
        if v.empty?
          w.u8(TAG_MAP_EMPTY)
        else
          w.u8(TAG_MAP)
          w.uvarint(v.size)
          v.each do |k, vv|
            unless k.is_a?(String) || k.is_a?(Symbol)
              raise "cxdb: map keys must be String/Symbol; got #{k.class}"
            end
            w.string_value(k.to_s)
            encode_value(vv, w)
          end
        end
      when Array
        if v.empty?
          w.u8(TAG_ARRAY_EMPTY)
        else
          w.u8(TAG_ARRAY)
          w.uvarint(v.size)
          v.each { |item| encode_value(item, w) }
        end
      else
        raise "cxdb: unsupported type #{v.class}"
      end
    end

    def self.encode_datetime(t, w)
      iso = t.utc.iso8601(9)  # nanosecond precision; round-trips through Time.iso8601
      w.u8(TAG_DATETIME)
      w.raw("\x00".b * 10) # 10 reserved placeholder bytes
      enc = iso.b
      w.u16(enc.bytesize)
      w.raw(enc)
    end
    private_class_method :encode_datetime

    # Encode a Ruby value to a FRAMED CXDB v1 buffer suitable for passing
    # directly to CXLib.from_data_bin. Output layout:
    #   [u32 LE size][CXDB magic][version][flags][u32 max_depth][u16 reserved][value...]
    def self.encode(value)
      w = Writer.new
      w.raw(CXDB_MAGIC)
      w.u8(CXDB_VERSION)
      w.u8(CXDB_FLAGS_LE)
      w.u32(CXDB_DEFAULT_DEPTH)
      w.u8(0); w.u8(0)
      encode_value(value, w)
      payload = w.buf
      framed = String.new(capacity: 4 + payload.bytesize, encoding: Encoding::BINARY)
      framed << [payload.bytesize].pack('V')
      framed << payload
      framed
    end
  end
end
