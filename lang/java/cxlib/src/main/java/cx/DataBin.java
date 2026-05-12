package cx;

import java.io.ByteArrayOutputStream;
import java.math.BigInteger;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * CXDB v1 codec — strict canonical binary data format.
 *
 * <p>Spec: spec/data_bin.md. Decoder consumes the 12-byte-header-prefixed
 * PAYLOAD returned by libcx.cx_to_data_bin (the [u32 LE size] frame is
 * stripped by {@link CxLib#toDataBin} before this class sees it). Encoder
 * produces a FRAMED buffer suitable for direct hand-off to
 * libcx.cx_from_data_bin.
 *
 * <p>Replaces the JSON-string detour previously used by
 * {@link CXDocument#loads} / {@link CXDocument#dumps} (audit finding CB-3).
 * Type fidelity preserved: integers stay {@link Long} (not coerced to
 * {@link Double} via Gson's JSON), floats stay {@link Double}, booleans
 * stay {@link Boolean}, dates round-trip as {@link LocalDate}, bytes as
 * {@code byte[]}.
 *
 * <p>Type mapping:
 * <pre>
 *   null                                 &lt;-&gt; CXDB null
 *   Boolean                              &lt;-&gt; CXDB false/true
 *   Byte/Short/Integer/Long/BigInteger   &lt;-&gt; CXDB int8/int16/int32/int64
 *   Float/Double                         &lt;-&gt; CXDB float64
 *   String                               &lt;-&gt; CXDB string
 *   byte[]                               &lt;-&gt; CXDB bytes
 *   LocalDate                            &lt;-&gt; CXDB date
 *   LocalDateTime/OffsetDateTime/        &lt;-&gt; CXDB datetime
 *     Instant/ZonedDateTime
 *   Map&lt;String,Object&gt;                   &lt;-&gt; CXDB map (LinkedHashMap insertion order)
 *   List&lt;Object&gt; / Object[]              &lt;-&gt; CXDB array
 * </pre>
 */
public final class DataBin {

    private DataBin() {}

    // ── Tag bytes (spec/data_bin.md §3.2) ─────────────────────────────────────
    private static final byte TAG_NULL         = 0x00;
    private static final byte TAG_FALSE        = 0x01;
    private static final byte TAG_TRUE         = 0x02;
    private static final byte TAG_INT8         = 0x10;
    private static final byte TAG_INT16        = 0x11;
    private static final byte TAG_INT32        = 0x12;
    private static final byte TAG_INT64        = 0x13;
    private static final byte TAG_FLOAT64      = 0x20;
    private static final byte TAG_STRING       = 0x30;
    private static final byte TAG_DATE         = 0x31;
    private static final byte TAG_DATETIME     = 0x32;
    private static final byte TAG_BYTES        = 0x33;
    private static final byte TAG_ARRAY        = 0x40;
    private static final byte TAG_ARRAY_EMPTY  = 0x41;
    private static final byte TAG_MAP          = 0x50;
    private static final byte TAG_MAP_EMPTY    = 0x51;
    private static final byte TAG_TABLE        = 0x60;
    private static final byte TAG_TABLE_EMPTY  = 0x61;

    private static final byte[] CXDB_MAGIC     = {'C', 'X', 'D', 'B'};
    private static final byte   CXDB_VERSION   = 0x01;
    private static final byte   CXDB_FLAGS_LE  = 0x01;
    private static final int    CXDB_DEFAULT_DEPTH = 64;

    private static final BigInteger I64_MAX = new BigInteger("9223372036854775807");
    private static final BigInteger I64_MIN = new BigInteger("-9223372036854775808");

    // ── Decoder ───────────────────────────────────────────────────────────────

    private static final class Reader {
        private final byte[] buf;
        private int pos = 0;
        private int depth = 0;
        private final int maxDepth;

        Reader(byte[] buf, int maxDepth) {
            this.buf = buf;
            this.maxDepth = maxDepth;
        }

        private void need(int n) {
            if (pos + n > buf.length) {
                throw new RuntimeException("cxdb: " + n + " bytes requested, " + (buf.length - pos) + " remaining");
            }
        }

        int u8() {
            if (pos >= buf.length) throw new RuntimeException("cxdb: unexpected end of input");
            return buf[pos++] & 0xFF;
        }

        int u16() {
            need(2);
            int v = (buf[pos] & 0xFF) | ((buf[pos + 1] & 0xFF) << 8);
            pos += 2;
            return v;
        }

        int u32() {
            need(4);
            int v = (buf[pos] & 0xFF)
                    | ((buf[pos + 1] & 0xFF) << 8)
                    | ((buf[pos + 2] & 0xFF) << 16)
                    | ((buf[pos + 3] & 0xFF) << 24);
            pos += 4;
            return v;
        }

        long i64() {
            need(8);
            long lo = ((long) buf[pos]     & 0xFF)
                    | ((long)(buf[pos + 1] & 0xFF) << 8)
                    | ((long)(buf[pos + 2] & 0xFF) << 16)
                    | ((long)(buf[pos + 3] & 0xFF) << 24)
                    | ((long)(buf[pos + 4] & 0xFF) << 32)
                    | ((long)(buf[pos + 5] & 0xFF) << 40)
                    | ((long)(buf[pos + 6] & 0xFF) << 48)
                    | ((long)(buf[pos + 7] & 0xFF) << 56);
            pos += 8;
            return lo;
        }

        double f64() {
            return Double.longBitsToDouble(i64());
        }

        byte[] take(int n) {
            need(n);
            byte[] out = new byte[n];
            System.arraycopy(buf, pos, out, 0, n);
            pos += n;
            return out;
        }

        int uvarint() {
            int x = 0;
            int shift = 0;
            for (int i = 0; i < 5; i++) {
                int b = u8();
                if (b < 0x80) {
                    if (i == 4 && b > 0x0F) {
                        throw new RuntimeException("cxdb: varint overflow (>2^32-1)");
                    }
                    if (i > 0 && b == 0) {
                        throw new RuntimeException("cxdb: non-canonical varint (extra zero byte)");
                    }
                    return x | (b << shift);
                }
                x |= (b & 0x7F) << shift;
                shift += 7;
            }
            throw new RuntimeException("cxdb: varint exceeds 5 bytes");
        }

        String stringPayload() {
            int n = uvarint();
            need(n);
            String s = new String(buf, pos, n, StandardCharsets.UTF_8);
            pos += n;
            return s;
        }

        Object value() {
            depth++;
            if (depth > maxDepth) {
                throw new RuntimeException("cxdb: recursion depth exceeds limit (" + maxDepth + ")");
            }
            try {
                int tag = u8();
                switch (tag) {
                    case TAG_NULL & 0xFF:    return null;
                    case TAG_FALSE & 0xFF:   return Boolean.FALSE;
                    case TAG_TRUE & 0xFF:    return Boolean.TRUE;
                    case TAG_INT8 & 0xFF: {
                        need(1);
                        return (long) buf[pos++];
                    }
                    case TAG_INT16 & 0xFF: {
                        need(2);
                        long v = (short) ((buf[pos] & 0xFF) | ((buf[pos + 1] & 0xFF) << 8));
                        pos += 2;
                        return v;
                    }
                    case TAG_INT32 & 0xFF: {
                        return (long) u32();
                    }
                    case TAG_INT64 & 0xFF: {
                        return i64();
                    }
                    case TAG_FLOAT64 & 0xFF: return f64();
                    case TAG_STRING & 0xFF:  return stringPayload();
                    case TAG_BYTES & 0xFF: {
                        int n = uvarint();
                        return take(n);
                    }
                    case TAG_DATE & 0xFF: {
                        need(4);
                        int year  = (short) ((buf[pos] & 0xFF) | ((buf[pos + 1] & 0xFF) << 8));
                        int month = buf[pos + 2] & 0xFF;
                        int day   = buf[pos + 3] & 0xFF;
                        pos += 4;
                        return LocalDate.of(year, month, day);
                    }
                    case TAG_DATETIME & 0xFF: {
                        take(10); // 10 reserved placeholder bytes
                        int srcLen = u16();
                        String src = new String(take(srcLen), StandardCharsets.UTF_8);
                        try {
                            return OffsetDateTime.parse(src);
                        } catch (Exception ignored) {
                            return src;
                        }
                    }
                    case TAG_ARRAY & 0xFF: {
                        int count = uvarint();
                        if (count == 0) {
                            throw new RuntimeException("cxdb: array tag 0x40 with count=0; use 0x41 for empty");
                        }
                        ArrayList<Object> out = new ArrayList<>(count);
                        for (int i = 0; i < count; i++) out.add(value());
                        return out;
                    }
                    case TAG_ARRAY_EMPTY & 0xFF: return new ArrayList<>(0);
                    case TAG_MAP & 0xFF: {
                        int count = uvarint();
                        if (count == 0) {
                            throw new RuntimeException("cxdb: map tag 0x50 with count=0; use 0x51 for empty");
                        }
                        LinkedHashMap<String, Object> out = new LinkedHashMap<>(count);
                        for (int i = 0; i < count; i++) {
                            int keyTag = u8();
                            if (keyTag != (TAG_STRING & 0xFF)) {
                                throw new RuntimeException(String.format(
                                    "cxdb: map key must be string; got 0x%02x", keyTag));
                            }
                            String key = stringPayload();
                            out.put(key, value());
                        }
                        return out;
                    }
                    case TAG_MAP_EMPTY & 0xFF: return new LinkedHashMap<String, Object>();
                    case TAG_TABLE & 0xFF:
                    case TAG_TABLE_EMPTY & 0xFF:
                        return tablePayload(tag);
                    default:
                        throw new RuntimeException(String.format(
                            "cxdb: unknown tag 0x%02x at offset %d", tag, pos - 1));
                }
            } finally {
                depth--;
            }
        }

        private Object tablePayload(int tag) {
            if (tag == (TAG_TABLE_EMPTY & 0xFF)) return new ArrayList<>(0);
            int colCount = uvarint();
            String[] cols = new String[colCount];
            for (int i = 0; i < colCount; i++) {
                int keyTag = u8();
                if (keyTag != (TAG_STRING & 0xFF)) {
                    throw new RuntimeException(String.format(
                        "cxdb: table column name must be string; got 0x%02x", keyTag));
                }
                cols[i] = stringPayload();
                u8(); // column type code (informational; per-cell tags drive decode)
            }
            int rowCount = uvarint();
            ArrayList<Object> rows = new ArrayList<>(rowCount);
            for (int i = 0; i < rowCount; i++) rows.add(new LinkedHashMap<String, Object>(colCount));
            for (int c = 0; c < colCount; c++) {
                for (int r = 0; r < rowCount; r++) {
                    @SuppressWarnings("unchecked")
                    Map<String, Object> row = (Map<String, Object>) rows.get(r);
                    row.put(cols[c], value());
                }
            }
            return rows;
        }
    }

    /**
     * Decode a CXDB v1 PAYLOAD (12-byte header + value section). The
     * [u32 LE size] frame is expected to have already been stripped by
     * {@link CxLib#toDataBin}; pass the raw payload bytes directly.
     */
    public static Object decode(byte[] payload) {
        return decode(payload, CXDB_DEFAULT_DEPTH);
    }

    public static Object decode(byte[] payload, int maxDepth) {
        if (payload.length < 12) {
            throw new RuntimeException("cxdb: payload too short for 12-byte header");
        }
        if (payload[0] != 'C' || payload[1] != 'X' || payload[2] != 'D' || payload[3] != 'B') {
            throw new RuntimeException("cxdb: bad magic (expected 'CXDB')");
        }
        if (payload[4] != CXDB_VERSION) {
            throw new RuntimeException("cxdb: unsupported version " + (payload[4] & 0xFF));
        }
        int flags = payload[5] & 0xFF;
        if ((flags & 0xFE) != 0) {
            throw new RuntimeException("cxdb: reserved flag bits set in header");
        }
        if ((flags & 0x01) == 0) {
            throw new RuntimeException("cxdb: only little-endian payloads supported in v1");
        }
        if (payload[10] != 0 || payload[11] != 0) {
            throw new RuntimeException("cxdb: reserved header bytes must be zero");
        }
        byte[] tail = new byte[payload.length - 12];
        System.arraycopy(payload, 12, tail, 0, tail.length);
        return new Reader(tail, maxDepth).value();
    }

    // ── Encoder ───────────────────────────────────────────────────────────────

    private static final class Writer {
        final ByteArrayOutputStream buf = new ByteArrayOutputStream(256);

        void u8(int v)  { buf.write(v & 0xFF); }
        void u16(int v) { buf.write(v & 0xFF); buf.write((v >>> 8) & 0xFF); }
        void u32(int v) {
            buf.write(v & 0xFF);
            buf.write((v >>> 8)  & 0xFF);
            buf.write((v >>> 16) & 0xFF);
            buf.write((v >>> 24) & 0xFF);
        }
        void i64(long v) {
            for (int i = 0; i < 8; i++) buf.write((int) ((v >>> (8 * i)) & 0xFF));
        }
        void f64(double v) { i64(Double.doubleToLongBits(v)); }

        void raw(byte[] b) { buf.write(b, 0, b.length); }

        void uvarint(long v) {
            while (Long.compareUnsigned(v, 0x80) >= 0) {
                buf.write((int) ((v & 0x7F) | 0x80));
                v >>>= 7;
            }
            buf.write((int) (v & 0x7F));
        }

        void stringValue(String s) {
            u8(TAG_STRING);
            byte[] enc = s.getBytes(StandardCharsets.UTF_8);
            uvarint(enc.length);
            raw(enc);
        }

        void intCanonical(BigInteger v) {
            if (v.compareTo(I64_MIN) < 0 || v.compareTo(I64_MAX) > 0) {
                throw new RuntimeException("cxdb: integer " + v + " exceeds i64 range");
            }
            long n = v.longValueExact();
            if (n >= -128 && n <= 127) {
                u8(TAG_INT8);
                buf.write((int) (n & 0xFF));
                return;
            }
            if (n >= -32768 && n <= 32767) {
                u8(TAG_INT16);
                u16((int) n);
                return;
            }
            if (n >= -2147483648L && n <= 2147483647L) {
                u8(TAG_INT32);
                u32((int) n);
                return;
            }
            u8(TAG_INT64);
            i64(n);
        }

        void value(Object v) {
            if (v == null) { u8(TAG_NULL); return; }
            if (v instanceof Boolean) {
                u8(((Boolean) v) ? TAG_TRUE : TAG_FALSE);
                return;
            }
            if (v instanceof Byte || v instanceof Short || v instanceof Integer || v instanceof Long) {
                intCanonical(BigInteger.valueOf(((Number) v).longValue()));
                return;
            }
            if (v instanceof BigInteger) {
                intCanonical((BigInteger) v);
                return;
            }
            if (v instanceof Float || v instanceof Double) {
                u8(TAG_FLOAT64);
                f64(((Number) v).doubleValue());
                return;
            }
            if (v instanceof String) {
                stringValue((String) v);
                return;
            }
            if (v instanceof byte[]) {
                byte[] b = (byte[]) v;
                u8(TAG_BYTES);
                uvarint(b.length);
                raw(b);
                return;
            }
            if (v instanceof LocalDate) {
                LocalDate d = (LocalDate) v;
                u8(TAG_DATE);
                int year = d.getYear();
                u16(year & 0xFFFF);
                u8(d.getMonthValue());
                u8(d.getDayOfMonth());
                return;
            }
            if (v instanceof OffsetDateTime || v instanceof ZonedDateTime
                    || v instanceof Instant || v instanceof LocalDateTime) {
                String iso;
                if (v instanceof OffsetDateTime) iso = ((OffsetDateTime) v).toString();
                else if (v instanceof ZonedDateTime) iso = ((ZonedDateTime) v).toOffsetDateTime().toString();
                else if (v instanceof Instant) iso = ((Instant) v).atOffset(ZoneOffset.UTC).toString();
                else iso = ((LocalDateTime) v).atOffset(ZoneOffset.UTC).toString();
                u8(TAG_DATETIME);
                raw(new byte[10]); // 10 reserved placeholder bytes
                byte[] enc = iso.getBytes(StandardCharsets.UTF_8);
                u16(enc.length);
                raw(enc);
                return;
            }
            if (v instanceof Map<?, ?>) {
                Map<?, ?> m = (Map<?, ?>) v;
                if (m.isEmpty()) { u8(TAG_MAP_EMPTY); return; }
                u8(TAG_MAP);
                uvarint(m.size());
                for (Map.Entry<?, ?> e : m.entrySet()) {
                    if (!(e.getKey() instanceof String)) {
                        throw new RuntimeException("cxdb: map keys must be String; got "
                                + (e.getKey() == null ? "null" : e.getKey().getClass().getName()));
                    }
                    stringValue((String) e.getKey());
                    value(e.getValue());
                }
                return;
            }
            if (v instanceof List<?>) {
                List<?> list = (List<?>) v;
                if (list.isEmpty()) { u8(TAG_ARRAY_EMPTY); return; }
                u8(TAG_ARRAY);
                uvarint(list.size());
                for (Object item : list) value(item);
                return;
            }
            if (v instanceof Object[]) {
                Object[] arr = (Object[]) v;
                if (arr.length == 0) { u8(TAG_ARRAY_EMPTY); return; }
                u8(TAG_ARRAY);
                uvarint(arr.length);
                for (Object item : arr) value(item);
                return;
            }
            throw new RuntimeException("cxdb: unsupported type " + v.getClass().getName());
        }

        byte[] toBytes() { return buf.toByteArray(); }
    }

    /**
     * Encode a Java value to a FRAMED CXDB v1 buffer suitable for passing
     * directly to {@link CxLib#fromDataBin}. Output layout:
     * {@code [u32 LE size][CXDB magic][version][flags][u32 max_depth][u16 reserved][value...]}.
     */
    public static byte[] encode(Object value) {
        Writer w = new Writer();
        w.raw(CXDB_MAGIC);
        w.u8(CXDB_VERSION);
        w.u8(CXDB_FLAGS_LE);
        w.u32(CXDB_DEFAULT_DEPTH);
        w.u8(0); w.u8(0);
        w.value(value);
        byte[] payload = w.toBytes();
        ByteBuffer framed = ByteBuffer.allocate(4 + payload.length).order(ByteOrder.LITTLE_ENDIAN);
        framed.putInt(payload.length);
        framed.put(payload);
        return framed.array();
    }
}
