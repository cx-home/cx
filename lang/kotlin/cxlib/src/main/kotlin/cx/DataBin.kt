package cx

import java.io.ByteArrayOutputStream
import java.math.BigInteger
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.charset.StandardCharsets
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.time.ZonedDateTime

/**
 * CXDB v1 codec — strict canonical binary data format.
 *
 * Spec: spec/data_bin.md. Decoder consumes the 12-byte-header-prefixed
 * PAYLOAD returned by libcx.cx_to_data_bin (the [u32 LE size] frame is
 * stripped by [CxLib.toDataBin] before this object sees it). Encoder
 * produces a FRAMED buffer suitable for direct hand-off to
 * libcx.cx_from_data_bin.
 *
 * Replaces the JSON-string detour previously used by [CXDocument.loads]
 * / [CXDocument.dumps] (audit finding CB-3). Type fidelity preserved:
 * integers stay Long (not coerced via JSON's number type), floats stay
 * Double, booleans stay Boolean, byte arrays round-trip as ByteArray,
 * dates as LocalDate / OffsetDateTime.
 *
 * Type mapping:
 *   null                                   <-> CXDB null
 *   Boolean                                <-> CXDB false/true
 *   Byte/Short/Int/Long/BigInteger         <-> CXDB int8/int16/int32/int64
 *   Float/Double                           <-> CXDB float64
 *   String                                 <-> CXDB string
 *   ByteArray                              <-> CXDB bytes
 *   LocalDate                              <-> CXDB date
 *   LocalDateTime/OffsetDateTime/          <-> CXDB datetime
 *     Instant/ZonedDateTime
 *   Map<String, Any?>                      <-> CXDB map (LinkedHashMap insertion order)
 *   List<Any?> / Array<Any?>               <-> CXDB array
 */
object DataBin {

    // ── Tag bytes (spec/data_bin.md §3.2) ─────────────────────────────────────
    private const val TAG_NULL         = 0x00
    private const val TAG_FALSE        = 0x01
    private const val TAG_TRUE         = 0x02
    private const val TAG_INT8         = 0x10
    private const val TAG_INT16        = 0x11
    private const val TAG_INT32        = 0x12
    private const val TAG_INT64        = 0x13
    private const val TAG_FLOAT64      = 0x20
    private const val TAG_STRING       = 0x30
    private const val TAG_DATE         = 0x31
    private const val TAG_DATETIME     = 0x32
    private const val TAG_BYTES        = 0x33
    private const val TAG_ARRAY        = 0x40
    private const val TAG_ARRAY_EMPTY  = 0x41
    private const val TAG_MAP          = 0x50
    private const val TAG_MAP_EMPTY    = 0x51
    private const val TAG_TABLE        = 0x60
    private const val TAG_TABLE_EMPTY  = 0x61

    private val CXDB_MAGIC = byteArrayOf('C'.code.toByte(), 'X'.code.toByte(), 'D'.code.toByte(), 'B'.code.toByte())
    private const val CXDB_VERSION  : Byte = 0x01
    private const val CXDB_FLAGS_LE : Byte = 0x01
    private const val CXDB_DEFAULT_DEPTH = 64

    private val I64_MAX = BigInteger("9223372036854775807")
    private val I64_MIN = BigInteger("-9223372036854775808")

    // ── Decoder ───────────────────────────────────────────────────────────────

    private class Reader(private val buf: ByteArray, private val maxDepth: Int) {
        private var pos = 0
        private var depth = 0

        private fun need(n: Int) {
            if (pos + n > buf.size) throw RuntimeException(
                "cxdb: $n bytes requested, ${buf.size - pos} remaining")
        }

        fun u8(): Int {
            if (pos >= buf.size) throw RuntimeException("cxdb: unexpected end of input")
            return buf[pos++].toInt() and 0xFF
        }

        fun u16(): Int {
            need(2)
            val v = (buf[pos].toInt() and 0xFF) or ((buf[pos + 1].toInt() and 0xFF) shl 8)
            pos += 2
            return v
        }

        fun u32(): Int {
            need(4)
            val v = (buf[pos].toInt() and 0xFF) or
                    ((buf[pos + 1].toInt() and 0xFF) shl 8) or
                    ((buf[pos + 2].toInt() and 0xFF) shl 16) or
                    ((buf[pos + 3].toInt() and 0xFF) shl 24)
            pos += 4
            return v
        }

        fun i64(): Long {
            need(8)
            var v = 0L
            for (i in 0 until 8) v = v or ((buf[pos + i].toLong() and 0xFF) shl (8 * i))
            pos += 8
            return v
        }

        fun f64(): Double = Double.fromBits(i64())

        fun take(n: Int): ByteArray {
            need(n)
            val out = ByteArray(n)
            System.arraycopy(buf, pos, out, 0, n)
            pos += n
            return out
        }

        fun uvarint(): Int {
            var x = 0
            var shift = 0
            for (i in 0 until 5) {
                val b = u8()
                if (b < 0x80) {
                    if (i == 4 && b > 0x0F) throw RuntimeException("cxdb: varint overflow (>2^32-1)")
                    if (i > 0 && b == 0) throw RuntimeException("cxdb: non-canonical varint (extra zero byte)")
                    return x or (b shl shift)
                }
                x = x or ((b and 0x7F) shl shift)
                shift += 7
            }
            throw RuntimeException("cxdb: varint exceeds 5 bytes")
        }

        fun stringPayload(): String {
            val n = uvarint()
            need(n)
            val s = String(buf, pos, n, StandardCharsets.UTF_8)
            pos += n
            return s
        }

        fun value(): Any? {
            depth++
            if (depth > maxDepth) {
                throw RuntimeException("cxdb: recursion depth exceeds limit ($maxDepth)")
            }
            try {
                val tag = u8()
                return when (tag) {
                    TAG_NULL    -> null
                    TAG_FALSE   -> false
                    TAG_TRUE    -> true
                    TAG_INT8    -> { need(1); buf[pos++].toLong() }
                    TAG_INT16   -> {
                        need(2)
                        val v = ((buf[pos].toInt() and 0xFF) or ((buf[pos + 1].toInt() and 0xFF) shl 8)).toShort().toLong()
                        pos += 2
                        v
                    }
                    TAG_INT32   -> u32().toLong()
                    TAG_INT64   -> i64()
                    TAG_FLOAT64 -> f64()
                    TAG_STRING  -> stringPayload()
                    TAG_BYTES   -> take(uvarint())
                    TAG_DATE    -> {
                        need(4)
                        val year  = (((buf[pos].toInt() and 0xFF) or ((buf[pos + 1].toInt() and 0xFF) shl 8))).toShort().toInt()
                        val month = buf[pos + 2].toInt() and 0xFF
                        val day   = buf[pos + 3].toInt() and 0xFF
                        pos += 4
                        LocalDate.of(year, month, day)
                    }
                    TAG_DATETIME -> {
                        take(10) // 10 reserved placeholder bytes
                        val srcLen = u16()
                        val src = String(take(srcLen), StandardCharsets.UTF_8)
                        try { OffsetDateTime.parse(src) } catch (_: Exception) { src }
                    }
                    TAG_ARRAY -> {
                        val count = uvarint()
                        if (count == 0) throw RuntimeException("cxdb: array tag 0x40 with count=0; use 0x41 for empty")
                        val out = ArrayList<Any?>(count)
                        for (i in 0 until count) out.add(value())
                        out
                    }
                    TAG_ARRAY_EMPTY -> ArrayList<Any?>(0)
                    TAG_MAP -> {
                        val count = uvarint()
                        if (count == 0) throw RuntimeException("cxdb: map tag 0x50 with count=0; use 0x51 for empty")
                        val out = LinkedHashMap<String, Any?>(count)
                        for (i in 0 until count) {
                            val keyTag = u8()
                            if (keyTag != TAG_STRING) {
                                throw RuntimeException(String.format("cxdb: map key must be string; got 0x%02x", keyTag))
                            }
                            val key = stringPayload()
                            out[key] = value()
                        }
                        out
                    }
                    TAG_MAP_EMPTY -> LinkedHashMap<String, Any?>()
                    TAG_TABLE, TAG_TABLE_EMPTY -> tablePayload(tag)
                    else -> throw RuntimeException(String.format("cxdb: unknown tag 0x%02x at offset %d", tag, pos - 1))
                }
            } finally {
                depth--
            }
        }

        private fun tablePayload(tag: Int): Any {
            if (tag == TAG_TABLE_EMPTY) return ArrayList<Any?>(0)
            val colCount = uvarint()
            val cols = Array(colCount) { "" }
            for (i in 0 until colCount) {
                val keyTag = u8()
                if (keyTag != TAG_STRING) {
                    throw RuntimeException(String.format("cxdb: table column name must be string; got 0x%02x", keyTag))
                }
                cols[i] = stringPayload()
                u8() // column type code (informational; per-cell tags drive decode)
            }
            val rowCount = uvarint()
            val rows = ArrayList<LinkedHashMap<String, Any?>>(rowCount)
            for (i in 0 until rowCount) rows.add(LinkedHashMap(colCount))
            for (c in 0 until colCount) {
                for (r in 0 until rowCount) {
                    rows[r][cols[c]] = value()
                }
            }
            return rows
        }
    }

    /**
     * Decode a CXDB v1 PAYLOAD (12-byte header + value section). The
     * [u32 LE size] frame is expected to have already been stripped by
     * [CxLib.toDataBin]; pass the raw payload bytes directly.
     */
    fun decode(payload: ByteArray, maxDepth: Int = CXDB_DEFAULT_DEPTH): Any? {
        if (payload.size < 12) throw RuntimeException("cxdb: payload too short for 12-byte header")
        if (payload[0] != 'C'.code.toByte() || payload[1] != 'X'.code.toByte() ||
            payload[2] != 'D'.code.toByte() || payload[3] != 'B'.code.toByte()) {
            throw RuntimeException("cxdb: bad magic (expected 'CXDB')")
        }
        if (payload[4] != CXDB_VERSION) {
            throw RuntimeException("cxdb: unsupported version ${payload[4].toInt() and 0xFF}")
        }
        val flags = payload[5].toInt() and 0xFF
        if ((flags and 0xFE) != 0) throw RuntimeException("cxdb: reserved flag bits set in header")
        if ((flags and 0x01) == 0) throw RuntimeException("cxdb: only little-endian payloads supported in v1")
        if (payload[10].toInt() != 0 || payload[11].toInt() != 0) {
            throw RuntimeException("cxdb: reserved header bytes must be zero")
        }
        val tail = ByteArray(payload.size - 12)
        System.arraycopy(payload, 12, tail, 0, tail.size)
        return Reader(tail, maxDepth).value()
    }

    // ── Encoder ───────────────────────────────────────────────────────────────

    private class Writer {
        val buf = ByteArrayOutputStream(256)

        fun u8(v: Int)  { buf.write(v and 0xFF) }
        fun u16(v: Int) { buf.write(v and 0xFF); buf.write((v ushr 8) and 0xFF) }
        fun u32(v: Int) {
            buf.write(v and 0xFF)
            buf.write((v ushr 8)  and 0xFF)
            buf.write((v ushr 16) and 0xFF)
            buf.write((v ushr 24) and 0xFF)
        }
        fun i64(v: Long) { for (i in 0 until 8) buf.write(((v ushr (8 * i)) and 0xFF).toInt()) }
        fun f64(v: Double) { i64(v.toRawBits()) }
        fun raw(b: ByteArray) { buf.write(b, 0, b.size) }

        fun uvarint(v: Long) {
            var x = v
            while (java.lang.Long.compareUnsigned(x, 0x80) >= 0) {
                buf.write(((x and 0x7F) or 0x80).toInt())
                x = x ushr 7
            }
            buf.write((x and 0x7F).toInt())
        }

        fun stringValue(s: String) {
            u8(TAG_STRING)
            val enc = s.toByteArray(StandardCharsets.UTF_8)
            uvarint(enc.size.toLong())
            raw(enc)
        }

        fun intCanonical(v: BigInteger) {
            if (v < I64_MIN || v > I64_MAX) throw RuntimeException("cxdb: integer $v exceeds i64 range")
            val n = v.longValueExact()
            when {
                n in -128..127 -> { u8(TAG_INT8); buf.write((n and 0xFF).toInt()) }
                n in -32768..32767 -> { u8(TAG_INT16); u16(n.toInt()) }
                n in -2147483648L..2147483647L -> { u8(TAG_INT32); u32(n.toInt()) }
                else -> { u8(TAG_INT64); i64(n) }
            }
        }

        fun value(v: Any?) {
            when (v) {
                null -> u8(TAG_NULL)
                is Boolean -> u8(if (v) TAG_TRUE else TAG_FALSE)
                is Byte, is Short, is Int, is Long ->
                    intCanonical(BigInteger.valueOf((v as Number).toLong()))
                is BigInteger -> intCanonical(v)
                is Float, is Double -> { u8(TAG_FLOAT64); f64((v as Number).toDouble()) }
                is String -> stringValue(v)
                is ByteArray -> {
                    u8(TAG_BYTES)
                    uvarint(v.size.toLong())
                    raw(v)
                }
                is LocalDate -> {
                    u8(TAG_DATE)
                    u16(v.year and 0xFFFF)
                    u8(v.monthValue)
                    u8(v.dayOfMonth)
                }
                is OffsetDateTime, is ZonedDateTime, is Instant, is LocalDateTime -> {
                    val iso = when (v) {
                        is OffsetDateTime -> v.toString()
                        is ZonedDateTime  -> v.toOffsetDateTime().toString()
                        is Instant        -> v.atOffset(ZoneOffset.UTC).toString()
                        is LocalDateTime  -> v.atOffset(ZoneOffset.UTC).toString()
                        else -> throw IllegalStateException()
                    }
                    u8(TAG_DATETIME)
                    raw(ByteArray(10)) // 10 reserved placeholder bytes
                    val enc = iso.toByteArray(StandardCharsets.UTF_8)
                    u16(enc.size)
                    raw(enc)
                }
                is Map<*, *> -> {
                    if (v.isEmpty()) { u8(TAG_MAP_EMPTY); return }
                    u8(TAG_MAP)
                    uvarint(v.size.toLong())
                    for ((k, vv) in v) {
                        if (k !is String) throw RuntimeException(
                            "cxdb: map keys must be String; got ${k?.javaClass?.name ?: "null"}")
                        stringValue(k)
                        value(vv)
                    }
                }
                is List<*> -> {
                    if (v.isEmpty()) { u8(TAG_ARRAY_EMPTY); return }
                    u8(TAG_ARRAY)
                    uvarint(v.size.toLong())
                    for (item in v) value(item)
                }
                is Array<*> -> {
                    if (v.isEmpty()) { u8(TAG_ARRAY_EMPTY); return }
                    u8(TAG_ARRAY)
                    uvarint(v.size.toLong())
                    for (item in v) value(item)
                }
                else -> throw RuntimeException("cxdb: unsupported type ${v.javaClass.name}")
            }
        }

        fun toBytes(): ByteArray = buf.toByteArray()
    }

    /**
     * Encode a Kotlin value to a FRAMED CXDB v1 buffer suitable for passing
     * directly to [CxLib.fromDataBin]. Output layout:
     * [u32 LE size][CXDB magic][version][flags][u32 max_depth][u16 reserved][value...]
     */
    fun encode(value: Any?): ByteArray {
        val w = Writer()
        w.raw(CXDB_MAGIC)
        w.u8(CXDB_VERSION.toInt())
        w.u8(CXDB_FLAGS_LE.toInt())
        w.u32(CXDB_DEFAULT_DEPTH)
        w.u8(0); w.u8(0)
        w.value(value)
        val payload = w.toBytes()
        val framed = ByteBuffer.allocate(4 + payload.size).order(ByteOrder.LITTLE_ENDIAN)
        framed.putInt(payload.size)
        framed.put(payload)
        return framed.array()
    }
}
