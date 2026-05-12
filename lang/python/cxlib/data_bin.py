"""
CXDB v1 codec — strict canonical binary data format.

Spec: spec/data_bin.md. Decoder consumes the framed [u32 LE size][payload]
buffer returned by libcx.cx_to_data_bin; encoder produces the same shape
for input to libcx.cx_from_data_bin.

This module replaces the JSON-string detour previously used by ast.loads
and ast.dumps (audit finding CB-3). Python types are produced/consumed
directly:
    int   <-> CXDB int8/int16/int32/int64
    float <-> CXDB float64
    bool  <-> CXDB false/true
    None  <-> CXDB null
    str   <-> CXDB string
    bytes <-> CXDB bytes
    dict  <-> CXDB map (insertion order preserved)
    list  <-> CXDB array
    datetime.date     <-> CXDB date
    datetime.datetime <-> CXDB datetime (placeholder source string in v1)

Tables are returned as a Table object (cxlib.Table); see cxlib/table.py
once that lands. For now table tags decode as a list of dicts (one
per row).
"""
from __future__ import annotations
import datetime
import struct
from typing import Any


# Tag bytes — see spec/data_bin.md §3.2.
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

_MAGIC = b"CXDB"
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
            raise RuntimeError(f"cxdb: {n} bytes requested, {len(self._d) - self._p} remaining")
        out = self._d[self._p:self._p + n]
        self._p += n
        return out

    def _u8(self) -> int:
        if self._p >= len(self._d):
            raise RuntimeError("cxdb: unexpected end of input")
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
                    raise RuntimeError("cxdb: varint overflow (>2^32-1)")
                if i > 0 and b == 0:
                    raise RuntimeError("cxdb: non-canonical varint (extra zero byte)")
                return x | (b << shift)
            x |= (b & 0x7F) << shift
            shift += 7
        raise RuntimeError("cxdb: varint exceeds 5 bytes")

    def _string(self) -> str:
        n = self._uvarint()
        return self._take(n).decode('utf-8')

    def _value(self) -> Any:
        self._depth += 1
        if self._depth > self._max_depth:
            raise RuntimeError(f"cxdb: recursion depth exceeds limit ({self._max_depth})")
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
                    raise RuntimeError("cxdb: array tag 0x40 with count=0; use 0x41 for empty")
                return [self._value() for _ in range(count)]
            if tag == _TAG_ARRAY_EMPTY:
                return []
            if tag == _TAG_MAP:
                count = self._uvarint()
                if count == 0:
                    raise RuntimeError("cxdb: map tag 0x50 with count=0; use 0x51 for empty")
                out = {}
                for _ in range(count):
                    key_tag = self._u8()
                    if key_tag != _TAG_STRING:
                        raise RuntimeError(f"cxdb: map key must be string; got 0x{key_tag:02x}")
                    # Bind key first — Python evaluates the RHS of subscript
                    # assignment before the key, so read order would reverse.
                    key = self._string()
                    out[key] = self._value()
                return out
            if tag == _TAG_MAP_EMPTY:
                return {}
            if tag == _TAG_TABLE or tag == _TAG_TABLE_EMPTY:
                return self._table_payload(tag)
            raise RuntimeError(f"cxdb: unknown tag 0x{tag:02x} at offset {self._p - 1}")
        finally:
            self._depth -= 1

    def _table_payload(self, tag: int) -> Any:
        if tag == _TAG_TABLE_EMPTY:
            return []
        col_count = self._uvarint()
        cols = []
        for _ in range(col_count):
            key_tag = self._u8()
            if key_tag != _TAG_STRING:
                raise RuntimeError(f"cxdb: table column name must be string; got 0x{key_tag:02x}")
            name = self._string()
            self._u8()  # column type code (informational; we use per-cell tags)
            cols.append(name)
        row_count = self._uvarint()
        rows: list[dict[str, Any]] = [dict() for _ in range(row_count)]
        for col_idx in range(col_count):
            for row_idx in range(row_count):
                rows[row_idx][cols[col_idx]] = self._value()
        return rows


def decode(framed: bytes, max_depth: int = _DEFAULT_MAX_DEPTH) -> Any:
    """Decode a framed CXDB v1 buffer into Python types."""
    if len(framed) < 4:
        raise RuntimeError("cxdb: input too short for size header")
    payload_size = _UNP_U32.unpack_from(framed, 0)[0]
    if 4 + payload_size > len(framed):
        raise RuntimeError(f"cxdb: declared payload ({payload_size}) exceeds remaining input")
    payload = framed[4:4 + payload_size]
    if len(payload) < 12:
        raise RuntimeError("cxdb: payload too short for 12-byte header")
    if payload[0:4] != _MAGIC:
        raise RuntimeError("cxdb: bad magic (expected 'CXDB')")
    if payload[4] != _VERSION:
        raise RuntimeError(f"cxdb: unsupported version {payload[4]}")
    flags = payload[5]
    if flags & 0xFE != 0:
        raise RuntimeError("cxdb: reserved flag bits set in header")
    if flags & 0x01 == 0:
        raise RuntimeError("cxdb: only little-endian payloads supported in v1")
    # bytes 6-9 max_depth; 10-11 reserved (must be zero)
    if payload[10] != 0 or payload[11] != 0:
        raise RuntimeError("cxdb: reserved header bytes must be zero")
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
                    raise RuntimeError(f"cxdb: map keys must be str; got {type(k).__name__}")
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
        raise RuntimeError(f"cxdb: unsupported type {type(v).__name__}")

    def _int_canonical(self, v: int):
        if -128 <= v <= 127:
            self._u8(_TAG_INT8); self._buf += _UNP_I8.pack(v); return
        if -32768 <= v <= 32767:
            self._u8(_TAG_INT16); self._buf += _UNP_I16.pack(v); return
        if -2147483648 <= v <= 2147483647:
            self._u8(_TAG_INT32); self._buf += _UNP_I32.pack(v); return
        if -(2**63) <= v <= (2**63) - 1:
            self._u8(_TAG_INT64); self._buf += _UNP_I64.pack(v); return
        raise RuntimeError(f"cxdb: integer {v} exceeds i64 range; bigint not yet supported in Python encoder")


def encode(value: Any) -> bytes:
    """Encode Python value to a framed CXDB v1 buffer."""
    w = _Writer()
    # Header
    w._buf += _MAGIC
    w._u8(_VERSION)
    w._u8(_FLAGS_LE)
    w._u32(_DEFAULT_MAX_DEPTH)
    w._u8(0); w._u8(0)
    # Root value
    w._value(value)
    payload = bytes(w._buf)
    framed = _UNP_U32.pack(len(payload)) + payload
    return framed
