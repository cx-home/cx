using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Numerics;
using System.Text;

namespace CX;

/// <summary>
/// CXDB v1 codec — strict canonical binary data format.
///
/// <para>Spec: spec/data_bin.md. Decoder consumes the 12-byte-header-prefixed
/// PAYLOAD returned by libcx.cx_to_data_bin (the [u32 LE size] frame is
/// stripped by <see cref="CxLib.ToDataBin"/> before this class sees it).
/// Encoder produces a FRAMED buffer suitable for direct hand-off to
/// libcx.cx_from_data_bin.</para>
///
/// <para>Replaces the JSON-string detour previously used by
/// <see cref="CXDocument.Loads"/> / <see cref="CXDocument.Dumps"/>
/// (audit finding CB-3). Type fidelity preserved: integers stay
/// <see cref="long"/> (not coerced via <c>System.Text.Json</c>'s number
/// element), floats stay <see cref="double"/>, booleans stay
/// <see cref="bool"/>, byte arrays round-trip as <c>byte[]</c>, dates
/// as <see cref="DateTime"/>.</para>
/// </summary>
public static class DataBin
{
    // ── Tag bytes (spec/data_bin.md §3.2) ─────────────────────────────────────
    private const byte TAG_NULL         = 0x00;
    private const byte TAG_FALSE        = 0x01;
    private const byte TAG_TRUE         = 0x02;
    private const byte TAG_INT8         = 0x10;
    private const byte TAG_INT16        = 0x11;
    private const byte TAG_INT32        = 0x12;
    private const byte TAG_INT64        = 0x13;
    private const byte TAG_FLOAT64      = 0x20;
    private const byte TAG_STRING       = 0x30;
    private const byte TAG_DATE         = 0x31;
    private const byte TAG_DATETIME     = 0x32;
    private const byte TAG_BYTES        = 0x33;
    private const byte TAG_ARRAY        = 0x40;
    private const byte TAG_ARRAY_EMPTY  = 0x41;
    private const byte TAG_MAP          = 0x50;
    private const byte TAG_MAP_EMPTY    = 0x51;
    private const byte TAG_TABLE        = 0x60;
    private const byte TAG_TABLE_EMPTY  = 0x61;

    private static readonly byte[] CXDB_MAGIC = { (byte)'C', (byte)'X', (byte)'D', (byte)'B' };
    private const byte CXDB_VERSION  = 0x01;
    private const byte CXDB_FLAGS_LE = 0x01;
    private const int  CXDB_DEFAULT_DEPTH = 64;

    // ── Decoder ───────────────────────────────────────────────────────────────

    private sealed class Reader
    {
        private readonly byte[] _buf;
        private int _pos;
        private int _depth;
        private readonly int _maxDepth;

        public Reader(byte[] buf, int maxDepth) { _buf = buf; _maxDepth = maxDepth; }

        private void Need(int n)
        {
            if (_pos + n > _buf.Length)
                throw new InvalidOperationException(
                    $"cxdb: {n} bytes requested, {_buf.Length - _pos} remaining");
        }

        public byte U8()
        {
            if (_pos >= _buf.Length) throw new InvalidOperationException("cxdb: unexpected end of input");
            return _buf[_pos++];
        }

        public ushort U16()
        {
            Need(2);
            ushort v = (ushort)(_buf[_pos] | (_buf[_pos + 1] << 8));
            _pos += 2;
            return v;
        }

        public uint U32()
        {
            Need(4);
            uint v = (uint)_buf[_pos]
                   | ((uint)_buf[_pos + 1] << 8)
                   | ((uint)_buf[_pos + 2] << 16)
                   | ((uint)_buf[_pos + 3] << 24);
            _pos += 4;
            return v;
        }

        public long I64()
        {
            Need(8);
            ulong v = 0;
            for (int i = 0; i < 8; i++) v |= (ulong)_buf[_pos + i] << (8 * i);
            _pos += 8;
            return unchecked((long)v);
        }

        public double F64() => BitConverter.Int64BitsToDouble(I64());

        public byte[] Take(int n)
        {
            Need(n);
            var outBuf = new byte[n];
            Array.Copy(_buf, _pos, outBuf, 0, n);
            _pos += n;
            return outBuf;
        }

        public int Uvarint()
        {
            int x = 0, shift = 0;
            for (int i = 0; i < 5; i++)
            {
                int b = U8();
                if (b < 0x80)
                {
                    if (i == 4 && b > 0x0F)
                        throw new InvalidOperationException("cxdb: varint overflow (>2^32-1)");
                    if (i > 0 && b == 0)
                        throw new InvalidOperationException("cxdb: non-canonical varint (extra zero byte)");
                    return x | (b << shift);
                }
                x |= (b & 0x7F) << shift;
                shift += 7;
            }
            throw new InvalidOperationException("cxdb: varint exceeds 5 bytes");
        }

        public string StringPayload()
        {
            int n = Uvarint();
            Need(n);
            string s = Encoding.UTF8.GetString(_buf, _pos, n);
            _pos += n;
            return s;
        }

        public object? Value()
        {
            _depth++;
            if (_depth > _maxDepth)
                throw new InvalidOperationException($"cxdb: recursion depth exceeds limit ({_maxDepth})");
            try
            {
                byte tag = U8();
                switch (tag)
                {
                    case TAG_NULL:    return null;
                    case TAG_FALSE:   return false;
                    case TAG_TRUE:    return true;
                    case TAG_INT8:    Need(1); return (long)(sbyte)_buf[_pos++];
                    case TAG_INT16:   return (long)(short)U16();
                    case TAG_INT32:   return (long)(int)U32();
                    case TAG_INT64:   return I64();
                    case TAG_FLOAT64: return F64();
                    case TAG_STRING:  return StringPayload();
                    case TAG_BYTES:   return Take(Uvarint());
                    case TAG_DATE:
                    {
                        Need(4);
                        int year  = (short)((_buf[_pos]) | (_buf[_pos + 1] << 8));
                        int month = _buf[_pos + 2];
                        int day   = _buf[_pos + 3];
                        _pos += 4;
                        return new DateTime(year, month, day, 0, 0, 0, DateTimeKind.Utc);
                    }
                    case TAG_DATETIME:
                    {
                        Take(10); // 10 reserved placeholder bytes
                        int srcLen = U16();
                        string src = Encoding.UTF8.GetString(Take(srcLen));
                        if (DateTime.TryParse(src, System.Globalization.CultureInfo.InvariantCulture,
                            System.Globalization.DateTimeStyles.RoundtripKind, out var dt))
                        {
                            return dt;
                        }
                        return src;
                    }
                    case TAG_ARRAY:
                    {
                        int count = Uvarint();
                        if (count == 0)
                            throw new InvalidOperationException("cxdb: array tag 0x40 with count=0; use 0x41 for empty");
                        var outList = new List<object?>(count);
                        for (int i = 0; i < count; i++) outList.Add(Value());
                        return outList;
                    }
                    case TAG_ARRAY_EMPTY: return new List<object?>(0);
                    case TAG_MAP:
                    {
                        int count = Uvarint();
                        if (count == 0)
                            throw new InvalidOperationException("cxdb: map tag 0x50 with count=0; use 0x51 for empty");
                        var outMap = new Dictionary<string, object?>(count);
                        for (int i = 0; i < count; i++)
                        {
                            byte keyTag = U8();
                            if (keyTag != TAG_STRING)
                                throw new InvalidOperationException(
                                    $"cxdb: map key must be string; got 0x{keyTag:X2}");
                            string key = StringPayload();
                            outMap[key] = Value();
                        }
                        return outMap;
                    }
                    case TAG_MAP_EMPTY: return new Dictionary<string, object?>();
                    case TAG_TABLE:
                    case TAG_TABLE_EMPTY: return TablePayload(tag);
                    default:
                        throw new InvalidOperationException(
                            $"cxdb: unknown tag 0x{tag:X2} at offset {_pos - 1}");
                }
            }
            finally { _depth--; }
        }

        private object TablePayload(byte tag)
        {
            if (tag == TAG_TABLE_EMPTY) return new List<object?>(0);
            int colCount = Uvarint();
            var cols = new string[colCount];
            for (int i = 0; i < colCount; i++)
            {
                byte keyTag = U8();
                if (keyTag != TAG_STRING)
                    throw new InvalidOperationException(
                        $"cxdb: table column name must be string; got 0x{keyTag:X2}");
                cols[i] = StringPayload();
                U8(); // column type code (informational; per-cell tags drive decode)
            }
            int rowCount = Uvarint();
            var rows = new List<Dictionary<string, object?>>(rowCount);
            for (int i = 0; i < rowCount; i++) rows.Add(new Dictionary<string, object?>(colCount));
            for (int c = 0; c < colCount; c++)
            for (int r = 0; r < rowCount; r++)
                rows[r][cols[c]] = Value();
            return rows;
        }
    }

    /// <summary>
    /// Decode a CXDB v1 PAYLOAD (12-byte header + value section). The
    /// [u32 LE size] frame is expected to have already been stripped by
    /// <see cref="CxLib.ToDataBin"/>; pass the raw payload bytes directly.
    /// </summary>
    public static object? Decode(byte[] payload, int maxDepth = CXDB_DEFAULT_DEPTH)
    {
        if (payload.Length < 12)
            throw new InvalidOperationException("cxdb: payload too short for 12-byte header");
        if (payload[0] != 'C' || payload[1] != 'X' || payload[2] != 'D' || payload[3] != 'B')
            throw new InvalidOperationException("cxdb: bad magic (expected 'CXDB')");
        if (payload[4] != CXDB_VERSION)
            throw new InvalidOperationException($"cxdb: unsupported version {payload[4]}");
        int flags = payload[5];
        if ((flags & 0xFE) != 0)
            throw new InvalidOperationException("cxdb: reserved flag bits set in header");
        if ((flags & 0x01) == 0)
            throw new InvalidOperationException("cxdb: only little-endian payloads supported in v1");
        if (payload[10] != 0 || payload[11] != 0)
            throw new InvalidOperationException("cxdb: reserved header bytes must be zero");

        var tail = new byte[payload.Length - 12];
        Array.Copy(payload, 12, tail, 0, tail.Length);
        return new Reader(tail, maxDepth).Value();
    }

    // ── Encoder ───────────────────────────────────────────────────────────────

    private sealed class Writer
    {
        public readonly MemoryStream Buf = new(256);

        public void U8(int v)  => Buf.WriteByte((byte)(v & 0xFF));
        public void U16(int v) { U8(v & 0xFF); U8((v >> 8) & 0xFF); }
        public void U32(uint v)
        {
            U8((int)(v & 0xFF));
            U8((int)((v >> 8)  & 0xFF));
            U8((int)((v >> 16) & 0xFF));
            U8((int)((v >> 24) & 0xFF));
        }
        public void I64(long v)
        {
            ulong u = unchecked((ulong)v);
            for (int i = 0; i < 8; i++) U8((int)((u >> (8 * i)) & 0xFF));
        }
        public void F64(double v) => I64(BitConverter.DoubleToInt64Bits(v));
        public void Raw(byte[] b) => Buf.Write(b, 0, b.Length);
        public void Raw(ReadOnlySpan<byte> b) { foreach (var x in b) Buf.WriteByte(x); }

        public void Uvarint(long v)
        {
            ulong x = unchecked((ulong)v);
            while (x >= 0x80)
            {
                U8((int)((x & 0x7F) | 0x80));
                x >>= 7;
            }
            U8((int)(x & 0x7F));
        }

        public void StringValue(string s)
        {
            U8(TAG_STRING);
            byte[] enc = Encoding.UTF8.GetBytes(s);
            Uvarint(enc.Length);
            Raw(enc);
        }

        public void IntCanonical(long n)
        {
            if (n >= -128 && n <= 127)
            {
                U8(TAG_INT8);
                Buf.WriteByte(unchecked((byte)(sbyte)n));
            }
            else if (n >= -32768 && n <= 32767)
            {
                U8(TAG_INT16);
                U16((int)(short)n);
            }
            else if (n >= -2147483648L && n <= 2147483647L)
            {
                U8(TAG_INT32);
                U32(unchecked((uint)(int)n));
            }
            else
            {
                U8(TAG_INT64);
                I64(n);
            }
        }
    }

    private static void EncodeValue(object? v, Writer w)
    {
        switch (v)
        {
            case null:
                w.U8(TAG_NULL); return;
            case bool b:
                w.U8(b ? TAG_TRUE : TAG_FALSE); return;
            case sbyte sb: w.IntCanonical(sb); return;
            case byte by:  w.IntCanonical(by); return;
            case short sh: w.IntCanonical(sh); return;
            case ushort us: w.IntCanonical(us); return;
            case int i:    w.IntCanonical(i); return;
            case uint ui:  w.IntCanonical(ui); return;
            case long l:   w.IntCanonical(l); return;
            case ulong ul:
                if (ul > long.MaxValue)
                    throw new InvalidOperationException($"cxdb: ulong {ul} exceeds i64 range");
                w.IntCanonical((long)ul);
                return;
            case BigInteger bi:
            {
                if (bi < long.MinValue || bi > long.MaxValue)
                    throw new InvalidOperationException($"cxdb: BigInteger {bi} exceeds i64 range");
                w.IntCanonical((long)bi);
                return;
            }
            case float f:  w.U8(TAG_FLOAT64); w.F64(f); return;
            case double d: w.U8(TAG_FLOAT64); w.F64(d); return;
            case decimal dec: w.U8(TAG_FLOAT64); w.F64((double)dec); return;
            case string s: w.StringValue(s); return;
            case byte[] bytes:
                w.U8(TAG_BYTES);
                w.Uvarint(bytes.Length);
                w.Raw(bytes);
                return;
            case DateTime dt:
            {
                string iso = dt.Kind == DateTimeKind.Unspecified
                    ? DateTime.SpecifyKind(dt, DateTimeKind.Utc).ToString("o", System.Globalization.CultureInfo.InvariantCulture)
                    : dt.ToString("o", System.Globalization.CultureInfo.InvariantCulture);
                w.U8(TAG_DATETIME);
                w.Raw(new byte[10]); // 10 reserved placeholder bytes
                byte[] enc = Encoding.UTF8.GetBytes(iso);
                w.U16(enc.Length);
                w.Raw(enc);
                return;
            }
            case DateTimeOffset dto:
            {
                string iso = dto.ToString("o", System.Globalization.CultureInfo.InvariantCulture);
                w.U8(TAG_DATETIME);
                w.Raw(new byte[10]);
                byte[] enc = Encoding.UTF8.GetBytes(iso);
                w.U16(enc.Length);
                w.Raw(enc);
                return;
            }
            case DateOnly dateOnly:
            {
                w.U8(TAG_DATE);
                w.U16(dateOnly.Year & 0xFFFF);
                w.U8(dateOnly.Month);
                w.U8(dateOnly.Day);
                return;
            }
            case IDictionary<string, object?> map:
                EncodeMap(map, map.Count, w);
                return;
            case IDictionary dict:
            {
                int count = dict.Count;
                if (count == 0) { w.U8(TAG_MAP_EMPTY); return; }
                w.U8(TAG_MAP);
                w.Uvarint(count);
                foreach (DictionaryEntry e in dict)
                {
                    if (e.Key is not string ks)
                        throw new InvalidOperationException(
                            $"cxdb: map keys must be string; got {e.Key?.GetType().Name ?? "null"}");
                    w.StringValue(ks);
                    EncodeValue(e.Value, w);
                }
                return;
            }
            case IEnumerable<object?> typedList:
                EncodeList(typedList, w);
                return;
            case IList list:
            {
                int count = list.Count;
                if (count == 0) { w.U8(TAG_ARRAY_EMPTY); return; }
                w.U8(TAG_ARRAY);
                w.Uvarint(count);
                foreach (var item in list) EncodeValue(item, w);
                return;
            }
            default:
                throw new InvalidOperationException($"cxdb: unsupported type {v.GetType().FullName}");
        }
    }

    private static void EncodeMap(IDictionary<string, object?> map, int count, Writer w)
    {
        if (count == 0) { w.U8(TAG_MAP_EMPTY); return; }
        w.U8(TAG_MAP);
        w.Uvarint(count);
        foreach (var kv in map)
        {
            w.StringValue(kv.Key);
            EncodeValue(kv.Value, w);
        }
    }

    private static void EncodeList(IEnumerable<object?> list, Writer w)
    {
        // Materialize so we can write count then elements.
        var arr = new List<object?>(list);
        if (arr.Count == 0) { w.U8(TAG_ARRAY_EMPTY); return; }
        w.U8(TAG_ARRAY);
        w.Uvarint(arr.Count);
        foreach (var item in arr) EncodeValue(item, w);
    }

    /// <summary>
    /// Encode a .NET value to a FRAMED CXDB v1 buffer suitable for passing
    /// directly to <see cref="CxLib.FromDataBin"/>. Output layout:
    /// [u32 LE size][CXDB magic][version][flags][u32 max_depth][u16 reserved][value...].
    /// </summary>
    public static byte[] Encode(object? value)
    {
        var w = new Writer();
        w.Raw(CXDB_MAGIC);
        w.U8(CXDB_VERSION);
        w.U8(CXDB_FLAGS_LE);
        w.U32(CXDB_DEFAULT_DEPTH);
        w.U8(0); w.U8(0);
        EncodeValue(value, w);
        byte[] payload = w.Buf.ToArray();
        var framed = new byte[4 + payload.Length];
        uint sz = (uint)payload.Length;
        framed[0] = (byte)(sz & 0xFF);
        framed[1] = (byte)((sz >> 8) & 0xFF);
        framed[2] = (byte)((sz >> 16) & 0xFF);
        framed[3] = (byte)((sz >> 24) & 0xFF);
        Array.Copy(payload, 0, framed, 4, payload.Length);
        return framed;
    }
}
