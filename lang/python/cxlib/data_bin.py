"""
CXCol v1 codec — strict canonical binary data format.

Spec: spec/core/data-bin.md. Decoder consumes the framed [u32 LE size][payload]
buffer returned by libcx.cx_to_data_bin; encoder produces the same shape
for input to libcx.cx_from_data_bin.

This module replaces the JSON-string detour previously used by ast.loads
and ast.dumps (audit finding CB-3). Python types are produced/consumed
directly:
    int   <-> CXCol int8/int16/int32/int64 (bigint 0x18 beyond i64;
              an in-i64 bigint on the wire still decodes to int)
    decimal.Decimal <-> CXCol decimal (0x28; fixed-point base-10 image,
              scale preserved — "1.10" stays Decimal('1.10'))
    float <-> CXCol float64
    bool  <-> CXCol false/true
    None  <-> CXCol null
    str   <-> CXCol string
    bytes <-> CXCol bytes
    dict  <-> CXCol map (insertion order preserved)
    list  <-> CXCol array
    datetime.date     <-> CXCol date
    datetime.datetime <-> CXCol datetime (placeholder source string in v1)

Tables are returned as a Table object (cxlib.Table); see cxlib/table.py
once that lands. For now table tags decode as a list of dicts (one
per row).
"""
from __future__ import annotations
import datetime
import decimal
import struct
from typing import Any


# Tag bytes — see spec/core/data-bin.md §3.2.
_TAG_NULL          = 0x00
_TAG_FALSE         = 0x01
_TAG_TRUE          = 0x02
_TAG_INT8          = 0x10
_TAG_INT16         = 0x11
_TAG_INT32         = 0x12
_TAG_INT64         = 0x13
_TAG_UINT8         = 0x14
_TAG_UINT16        = 0x15
_TAG_UINT32        = 0x16
_TAG_UINT64        = 0x17
_TAG_BIGINT        = 0x18
_TAG_FLOAT64       = 0x20
_TAG_FLOAT32       = 0x21
_TAG_FLOAT16       = 0x22
_TAG_DECIMAL       = 0x28
_TAG_STRING        = 0x30
_TAG_DATE          = 0x31
_TAG_DATETIME      = 0x32
_TAG_BYTES         = 0x33
_TAG_ARRAY         = 0x40
_TAG_ARRAY_EMPTY   = 0x41
_TAG_MAP           = 0x50
_TAG_MAP_EMPTY     = 0x51
_TAG_TABLE         = 0x60
_TAG_TABLE_EMPTY   = 0x61

_MAGIC = b"CXCol"
_VERSION = 0x01
_FLAGS_LE = 0x01
_DEFAULT_MAX_DEPTH = 64

_UNP_U32 = struct.Struct('<I')
_UNP_F64 = struct.Struct('<d')
_UNP_I8 = struct.Struct('<b')
_UNP_I16 = struct.Struct('<h')
_UNP_I32 = struct.Struct('<i')
_UNP_I64 = struct.Struct('<q')
_UNP_U16 = struct.Struct('<H')


# ── Decoder ───────────────────────────────────────────────────────────────────

class _Reader:
    __slots__ = ('_d', '_p', '_depth', '_max_depth')

    def __init__(self, data: bytes, max_depth: int = _DEFAULT_MAX_DEPTH):
        self._d = data
        self._p = 0
        self._depth = 0
        self._max_depth = max_depth

    def _take(self, n: int) -> bytes:
        if self._p + n > len(self._d):
            raise RuntimeError(f"cxcol: {n} bytes requested, {len(self._d) - self._p} remaining")
        out = self._d[self._p:self._p + n]
        self._p += n
        return out

    def _u8(self) -> int:
        if self._p >= len(self._d):
            raise RuntimeError("cxcol: unexpected end of input")
        v = self._d[self._p]
        self._p += 1
        return v

    def _u16(self) -> int:
        return _UNP_U16.unpack(self._take(2))[0]

    def _u32(self) -> int:
        return _UNP_U32.unpack(self._take(4))[0]

    def _uvarint(self) -> int:
        x = 0
        shift = 0
        for i in range(5):
            b = self._u8()
            if b < 0x80:
                if i == 4 and b > 0x0F:
                    raise RuntimeError("cxcol: varint overflow (>2^32-1)")
                if i > 0 and b == 0:
                    raise RuntimeError("cxcol: non-canonical varint (extra zero byte)")
                return x | (b << shift)
            x |= (b & 0x7F) << shift
            shift += 7
        raise RuntimeError("cxcol: varint exceeds 5 bytes")

    def _string(self) -> str:
        n = self._uvarint()
        return self._take(n).decode('utf-8')

    def _value(self) -> Any:
        self._depth += 1
        if self._depth > self._max_depth:
            raise RuntimeError(f"cxcol: recursion depth exceeds limit ({self._max_depth})")
        try:
            tag = self._u8()
            if tag == _TAG_NULL: return None
            if tag == _TAG_FALSE: return False
            if tag == _TAG_TRUE: return True
            if tag == _TAG_INT8:    return _UNP_I8.unpack(self._take(1))[0]
            if tag == _TAG_INT16:   return _UNP_I16.unpack(self._take(2))[0]
            if tag == _TAG_INT32:   return _UNP_I32.unpack(self._take(4))[0]
            if tag == _TAG_INT64:   return _UNP_I64.unpack(self._take(8))[0]
            if tag == _TAG_UINT8:   return self._u8()
            if tag == _TAG_UINT16:  return self._u16()
            if tag == _TAG_UINT32:  return self._u32()
            if tag == _TAG_UINT64:  return struct.unpack('<Q', self._take(8))[0]
            if tag == _TAG_BIGINT:
                # I1 row 16 (L48): base-10 integer image, same length-prefixed
                # payload shape as string. Narrowing-within-kind means an
                # in-i64 value may still ride 0x18; host type is int either way.
                return int(self._string())
            if tag == _TAG_DECIMAL:
                # Fixed-point base-10 image; Decimal preserves scale natively
                # ("1.10" -> Decimal('1.10'), trailing zero kept).
                return decimal.Decimal(self._string())
            if tag == _TAG_FLOAT64: return _UNP_F64.unpack(self._take(8))[0]
            if tag == _TAG_STRING:  return self._string()
            if tag == _TAG_BYTES:
                n = self._uvarint()
                return bytes(self._take(n))
            if tag == _TAG_DATE:
                bs = self._take(4)
                year = int.from_bytes(bs[0:2], 'little', signed=True)
                return datetime.date(year, bs[2], bs[3])
            if tag == _TAG_DATETIME:
                # v1 placeholder: 10 bytes unused + u16 source-len + UTF-8 source.
                self._take(10)
                src_len = self._u16()
                src = self._take(src_len).decode('utf-8')
                # Best-effort parse; fall back to source string.
                try:
                    return datetime.datetime.fromisoformat(src.replace('Z', '+00:00'))
                except ValueError:
                    return src
            if tag == _TAG_ARRAY:
                count = self._uvarint()
                if count == 0:
                    raise RuntimeError("cxcol: array tag 0x40 with count=0; use 0x41 for empty")
                return [self._value() for _ in range(count)]
            if tag == _TAG_ARRAY_EMPTY:
                return []
            if tag == _TAG_MAP:
                count = self._uvarint()
                if count == 0:
                    raise RuntimeError("cxcol: map tag 0x50 with count=0; use 0x51 for empty")
                out = {}
                for _ in range(count):
                    key_tag = self._u8()
                    if key_tag != _TAG_STRING:
                        raise RuntimeError(f"cxcol: map key must be string; got 0x{key_tag:02x}")
                    # Bind key first — Python evaluates the RHS of subscript
                    # assignment before the key, so read order would reverse.
                    key = self._string()
                    out[key] = self._value()
                return out
            if tag == _TAG_MAP_EMPTY:
                return {}
            if tag == _TAG_TABLE or tag == _TAG_TABLE_EMPTY:
                return self._table_payload(tag)
            raise RuntimeError(f"cxcol: unknown tag 0x{tag:02x} at offset {self._p - 1}")
        finally:
            self._depth -= 1

    def _table_payload(self, tag: int) -> Any:
        if tag == _TAG_TABLE_EMPTY:
            return []
        col_count = self._uvarint()
        cols = []
        codes = []
        for _ in range(col_count):
            key_tag = self._u8()
            if key_tag != _TAG_STRING:
                raise RuntimeError(f"cxcol: table column name must be string; got 0x{key_tag:02x}")
            name = self._string()
            code = self._u8()  # §3.10.3 column type code (payload contract)
            if code == 0x82:  # §3.10.1 declared-name annotation (#807(c))
                ann_tag = self._u8()
                if ann_tag != _TAG_STRING:
                    raise RuntimeError(f"cxcol: declared-name annotation must carry a string; got 0x{ann_tag:02x}")
                self._string()  # declared spelling — a CX-render concern; codes drive payloads here
                code = self._u8()
                if code == 0x82:
                    raise RuntimeError("cxcol: duplicate declared-name annotation in col-spec")
            codes.append(code)
            cols.append(name)
        row_count = self._uvarint()
        rows: list[dict[str, Any]] = [dict() for _ in range(row_count)]
        for col_idx in range(col_count):
            cells = self._column_payload(codes[col_idx], row_count)
            for row_idx in range(row_count):
                rows[row_idx][cols[col_idx]] = cells[row_idx]
        return rows

    # ── §3.10.3 typed column payloads (stream 17 W3 — the lattice
    # rise: per-column TYPED payloads, no per-cell tags; 0x80 nullable
    # bitmap wrapper; 0x81 mixed per-row tagged; 0x01 bit-packed bool).
    def _column_payload(self, code: int, row_count: int) -> list:
        if code == 0x00:  # all-null
            return [None] * row_count
        if code == 0x81:  # mixed — per-row tagged values
            return [self._value() for _ in range(row_count)]
        if code == 0x80:  # nullable wrapper
            inner = self._u8()
            bitmap = self._take((row_count + 7) // 8)
            nulls = [(bitmap[i // 8] >> (i % 8)) & 1 == 1 for i in range(row_count)]
            nonnull = self._typed_cells(inner, row_count - sum(nulls))
            out, vi = [], 0
            for i in range(row_count):
                if nulls[i]:
                    out.append(None)
                else:
                    out.append(nonnull[vi])
                    vi += 1
            return out
        return self._typed_cells(code, row_count)

    def _typed_cells(self, code: int, n: int) -> list:
        if code == 0x01:  # bool, bit-packed LSB-first (§3.10.4)
            bits = self._take((n + 7) // 8)
            return [((bits[i // 8] >> (i % 8)) & 1) == 1 for i in range(n)]
        if code in (0x10, 0x14):  # i8 / u8
            raw = self._take(n)
            return [b - 256 if code == 0x10 and b > 127 else b for b in raw]
        if code in (0x11, 0x15):  # i16 / u16
            raw = self._take(2 * n)
            fmt = '<h' if code == 0x11 else '<H'
            return [struct.unpack_from(fmt, raw, 2 * i)[0] for i in range(n)]
        if code in (0x12, 0x16):  # i32 / u32
            raw = self._take(4 * n)
            fmt = '<i' if code == 0x12 else '<I'
            return [struct.unpack_from(fmt, raw, 4 * i)[0] for i in range(n)]
        if code in (0x13, 0x17):  # i64 / u64
            raw = self._take(8 * n)
            fmt = '<q' if code == 0x13 else '<Q'
            return [struct.unpack_from(fmt, raw, 8 * i)[0] for i in range(n)]
        if code == 0x20:  # f64
            raw = self._take(8 * n)
            return [struct.unpack_from('<d', raw, 8 * i)[0] for i in range(n)]
        if code == 0x21:  # f32
            raw = self._take(4 * n)
            return [struct.unpack_from('<f', raw, 4 * i)[0] for i in range(n)]
        if code == 0x22:  # f16
            raw = self._take(2 * n)
            return [struct.unpack_from('<e', raw, 2 * i)[0] for i in range(n)]
        if code in (0x18, 0x28, 0x30, 0x33, 0x70):  # bigint/decimal/string/bytes/atom — length-prefixed
            out = []
            for _ in range(n):
                ln = self._uvarint()
                out.append(self._take(ln).decode('utf-8'))
            return out
        if code == 0x31:  # date — 4 bytes y16/m/d (matches the scalar arm's type)
            out = []
            for _ in range(n):
                b = self._take(4)
                y = struct.unpack_from('<h', b, 0)[0]
                out.append(datetime.date(y, b[2], b[3]))
            return out
        if code == 0x32:  # datetime — 12 bytes (ns i64 + offset i16 + reserved)
            out = []
            for _ in range(n):
                b = self._take(12)
                ns = struct.unpack_from('<q', b, 0)[0]
                # #807(d): offset_minutes rides the transport — surface
                # the local tz so the render round-trips.
                off = struct.unpack_from('<h', b, 8)[0]
                tz = datetime.timezone.utc if off == 0 else datetime.timezone(datetime.timedelta(minutes=off))
                secs, rem = divmod(ns, 1_000_000_000)
                dt = datetime.datetime.fromtimestamp(secs, tz=datetime.timezone.utc).astimezone(tz)
                out.append(dt.replace(microsecond=rem // 1000))
            return out
        raise RuntimeError(f"cxcol: unknown column type code 0x{code:02x}")


def decode(framed: bytes, max_depth: int = _DEFAULT_MAX_DEPTH) -> Any:
    """Decode a framed CXCol v1 buffer into Python types."""
    if len(framed) < 4:
        raise RuntimeError("cxcol: input too short for size header")
    payload_size = _UNP_U32.unpack_from(framed, 0)[0]
    if 4 + payload_size > len(framed):
        raise RuntimeError(f"cxcol: declared payload ({payload_size}) exceeds remaining input")
    payload = framed[4:4 + payload_size]
    if len(payload) < 12:
        raise RuntimeError("cxcol: payload too short for 12-byte header")
    # Wire magic — 5-byte "CXCol"; header is 12 bytes total.
    # See spec/core/data-bin.md §3.1.
    if payload[0:5] != _MAGIC:
        raise RuntimeError("cxcol: bad magic (expected 'CXCol')")
    if payload[5] != _VERSION:
        raise RuntimeError(f"cxcol: unsupported version {payload[5]}")
    flags = payload[6]
    if flags & 0xFE != 0:
        raise RuntimeError("cxcol: reserved flag bits set in header")
    if flags & 0x01 == 0:
        raise RuntimeError("cxcol: only little-endian payloads supported in v1")
    # bytes 7-10 max_depth (u32 LE); byte 11 reserved (must be zero)
    if payload[11] != 0:
        raise RuntimeError("cxcol: reserved header byte must be zero")
    r = _Reader(payload[12:], max_depth)
    return r._value()


# ── Encoder ───────────────────────────────────────────────────────────────────

class _Writer:
    __slots__ = ('_buf',)

    def __init__(self):
        self._buf = bytearray()

    def _u8(self, v: int): self._buf.append(v)
    def _u16(self, v: int): self._buf += _UNP_U16.pack(v)
    def _u32(self, v: int): self._buf += _UNP_U32.pack(v)

    def _uvarint(self, v: int):
        while v >= 0x80:
            self._buf.append((v & 0x7F) | 0x80)
            v >>= 7
        self._buf.append(v & 0x7F)

    def _string(self, s: str):
        self._u8(_TAG_STRING)
        self._string_payload(s)

    def _string_payload(self, s: str):
        # Length-prefixed byte payload WITHOUT a leading tag — the caller
        # has already written its kind tag (0x30 / 0x28 / 0x18). Mirrors
        # vcx encode_string_payload.
        encoded = s.encode('utf-8')
        self._uvarint(len(encoded))
        self._buf += encoded

    def _value(self, v: Any):
        if v is None:
            self._u8(_TAG_NULL); return
        if v is True:
            self._u8(_TAG_TRUE); return
        if v is False:
            self._u8(_TAG_FALSE); return
        if isinstance(v, decimal.Decimal):
            # Wire image is FIXED-POINT base-10 only — exponent notation is
            # not a legal wire image. format(..., 'f') renders fixed-point
            # while preserving scale (Decimal('1.10') -> '1.10').
            if not v.is_finite():
                raise RuntimeError(
                    f"cxcol: decimal must be finite; got {v!r} (NaN/Infinity "
                    "have no wire image)")
            self._u8(_TAG_DECIMAL)
            self._string_payload(format(v, 'f'))
            return
        if isinstance(v, int):
            self._int_canonical(v); return
        if isinstance(v, float):
            self._u8(_TAG_FLOAT64)
            self._buf += struct.pack('<d', v)
            return
        if isinstance(v, str):
            self._string(v); return
        if isinstance(v, (bytes, bytearray)):
            self._u8(_TAG_BYTES)
            self._uvarint(len(v))
            self._buf += bytes(v)
            return
        if isinstance(v, datetime.datetime):
            iso = v.isoformat()
            self._u8(_TAG_DATETIME)
            self._buf += b'\x00' * 10
            self._u16(len(iso.encode('utf-8')))
            self._buf += iso.encode('utf-8')
            return
        if isinstance(v, datetime.date):
            self._u8(_TAG_DATE)
            self._buf += int(v.year).to_bytes(2, 'little', signed=True)
            self._u8(v.month); self._u8(v.day)
            return
        if isinstance(v, dict):
            if len(v) == 0:
                self._u8(_TAG_MAP_EMPTY); return
            self._u8(_TAG_MAP)
            self._uvarint(len(v))
            for k, vv in v.items():
                if not isinstance(k, str):
                    raise RuntimeError(f"cxcol: map keys must be str; got {type(k).__name__}")
                self._string(k)
                self._value(vv)
            return
        if isinstance(v, list):
            if len(v) == 0:
                self._u8(_TAG_ARRAY_EMPTY); return
            self._u8(_TAG_ARRAY)
            self._uvarint(len(v))
            for x in v:
                self._value(x)
            return
        raise RuntimeError(f"cxcol: unsupported type {type(v).__name__}")

    def _int_canonical(self, v: int):
        if -128 <= v <= 127:
            self._u8(_TAG_INT8); self._buf += _UNP_I8.pack(v); return
        if -32768 <= v <= 32767:
            self._u8(_TAG_INT16); self._buf += _UNP_I16.pack(v); return
        if -2147483648 <= v <= 2147483647:
            self._u8(_TAG_INT32); self._buf += _UNP_I32.pack(v); return
        if -(2**63) <= v <= (2**63) - 1:
            self._u8(_TAG_INT64); self._buf += _UNP_I64.pack(v); return
        # L20 auto-promotion: an int beyond i64 rides the wire as bigint
        # (0x18) — base-10 integer image, never an encode error.
        self._u8(_TAG_BIGINT)
        self._string_payload(str(v))


def encode(value: Any) -> bytes:
    """Encode Python value to a framed CXCol v1 buffer."""
    w = _Writer()
    # Header — 5-byte magic + 1 ver + 1 flags + 4 max_depth + 1 reserved
    # = 12 bytes. (v0.8.0 layout; pre-v0.8.0 was 4-byte magic + 2 reserved.)
    w._buf += _MAGIC
    w._u8(_VERSION)
    w._u8(_FLAGS_LE)
    w._u32(_DEFAULT_MAX_DEPTH)
    w._u8(0)  # reserved (1 byte)
    # Root value
    w._value(value)
    payload = bytes(w._buf)
    framed = _UNP_U32.pack(len(payload)) + payload
    return framed
