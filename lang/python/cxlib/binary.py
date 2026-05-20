"""
Binary wire protocol decoder for cx_to_ast_bin and cx_to_events_bin.

Buffer returned by C:
  [u32 LE: payload_size][payload bytes]

All integers little-endian.
Strings:  u32(byte_len) + raw UTF-8 bytes  (no null terminator)
OptStr:   u8(0|1) + str if 1
Attr:     str:name  str:value  str:inferred_type
"""
from __future__ import annotations
import struct
import ctypes
from typing import Any, Optional
from . import cx as _cx
from .ast import (Attr, Document, Element, Text, Scalar, Comment, RawText,
                  EntityRef, Alias, PI, XMLDecl, CXDirective, BlockContent,
                  Interpolation, EvalDirective)
from .stream import StreamEvent, Attr as SAttr


# ── scalar coercion ───────────────────────────────────────────────────────────

def _coerce(type_str: str, value_str: str) -> Any:
    if type_str == 'int':
        return int(value_str)
    if type_str == 'float':
        return float(value_str)
    if type_str == 'bool':
        return value_str == 'true'
    if type_str == 'null':
        return None
    return value_str  # string / date / datetime / bytes


# ── buffer reader ─────────────────────────────────────────────────────────────

_UNP_I = struct.Struct('<I')
_UNP_H = struct.Struct('<H')


class _Buf:
    __slots__ = ('_d', '_p')

    def __init__(self, data: bytes):
        self._d = data
        self._p = 0

    def u8(self) -> int:
        p = self._p; self._p = p + 1; return self._d[p]

    def u16(self) -> int:
        p = self._p; self._p = p + 2; return _UNP_H.unpack_from(self._d, p)[0]

    def u32(self) -> int:
        p = self._p; self._p = p + 4; return _UNP_I.unpack_from(self._d, p)[0]

    def str_(self) -> str:
        p = self._p
        n = _UNP_I.unpack_from(self._d, p)[0]
        p += 4
        self._p = p + n
        return self._d[p:p + n].decode('utf-8')

    def optstr(self) -> Optional[str]:
        p = self._p
        flag = self._d[p]
        self._p = p + 1
        if not flag:
            return None
        p = self._p
        n = _UNP_I.unpack_from(self._d, p)[0]
        p += 4
        self._p = p + n
        return self._d[p:p + n].decode('utf-8')

    def bytes_n(self, n: int) -> bytes:
        p = self._p
        self._p = p + n
        return self._d[p:p + n]


# ── AST decoder — builds Document/Element/Node objects directly ───────────────

def _read_attr(b: _Buf, version: int):
    name = b.str_()
    value_str = b.str_()
    t = b.str_()
    # Pass data_type so the CX emitter formats int/float/bool/null correctly.
    dt = t if t != 'string' else None
    is_ref = bool(b.u8()) if version >= 2 else False
    a = Attr(name, _coerce(t, value_str), dt)
    a.is_ref = is_ref
    if version >= 5:
        # v3.5 (ADR 0016): BracketBody attribute body tail.
        body_flag = b.u8()
        if body_flag == 1:
            count = b.u16()
            a.body = [_read_node(b, version) for _ in range(count)]
        elif body_flag != 0:
            raise ValueError(f'ast_bin: invalid attr body_flag {body_flag}')
    return a


def _read_node(b: _Buf, version: int):
    tid = b.u8()
    if tid == 0x01:
        name   = b.str_()
        anchor = b.optstr()
        dt     = b.optstr()
        merge  = b.optstr()
        eid      = b.optstr() if version >= 2 else None
        body_ref = b.optstr() if version >= 3 else None
        attrs  = [_read_attr(b, version) for _ in range(b.u16())]
        items  = [_read_node(b, version) for _ in range(b.u16())]
        e = Element(name, anchor, merge, dt, attrs, items)
        e.id = eid
        e.body_ref = body_ref
        return e
    if tid == 0x02:
        return Text(b.str_())
    if tid == 0x03:
        t = b.str_(); return Scalar(t, _coerce(t, b.str_()))
    if tid == 0x04:
        return Comment(b.str_())
    if tid == 0x05:
        return RawText(b.str_())
    if tid == 0x06:
        return EntityRef(b.str_())
    if tid == 0x07:
        return Alias(b.str_())
    if tid == 0x08:
        target = b.str_(); data = b.optstr()
        return PI(target, data)
    if tid == 0x09:
        decl_version = b.str_(); encoding = b.optstr(); standalone = b.optstr()
        return XMLDecl(decl_version, encoding, standalone)
    if tid == 0x0A:
        attrs = [_read_attr(b, version) for _ in range(b.u16())]
        # v0.6.0 (format version 4) — directive `&anchor` + nested children.
        if version >= 4:
            anchor = b.optstr()
            items = [_read_node(b, version) for _ in range(b.u16())]
            return CXDirective(attrs, anchor, items)
        return CXDirective(attrs)
    if tid == 0x0C:
        return BlockContent([_read_node(b, version) for _ in range(b.u16())])
    if tid == 0x0D:
        # v3.5 (ADR 0016) [58] — `[?=EXPR]`.
        return Interpolation(b.str_())
    if tid == 0x0E:
        # v3.5 (ADR 0016) [59] — `[?Name attrs body]`.
        name = b.str_()
        attrs = [_read_attr(b, version) for _ in range(b.u16())]
        items = [_read_node(b, version) for _ in range(b.u16())]
        return EvalDirective(name, attrs, items)
    # 0xFF = unknown/DTD skip — no payload
    return Text('')


def decode_ast(raw: bytes):
    b = _Buf(raw)
    version  = b.u8()
    prolog   = [_read_node(b, version) for _ in range(b.u16())]
    elements = [_read_node(b, version) for _ in range(b.u16())]
    return Document(prolog=prolog, elements=elements)


# ── Events decoder — builds StreamEvent objects directly ──────────────────────

_EVT = {
    0x01: 'StartDoc', 0x02: 'EndDoc', 0x03: 'StartElement',
    0x04: 'EndElement', 0x05: 'Text', 0x06: 'Scalar',
    0x07: 'Comment', 0x08: 'PI', 0x09: 'EntityRef',
    0x0A: 'RawText', 0x0B: 'Alias',
    0x0C: 'StartTable', 0x0D: 'RowGroup', 0x0E: 'EndTable',
}


def _decode_one_event(b: _Buf) -> StreamEvent:
    """Decode a single event starting at the tid byte. Used by both
    decode_events (whole-buffer) and the handle-based Stream (per-call)."""
    tid = b.u8()
    t = _EVT.get(tid, 'Unknown')
    e = StreamEvent(type=t)
    if tid == 0x03:
        e.name   = b.str_()
        e.anchor = b.optstr()
        e.data_type = b.optstr()
        _ = b.optstr()  # merge
        n_attrs = b.u16()
        e.attrs = []
        for _ in range(n_attrs):
            name = b.str_()
            val_str = b.str_()
            typ = b.str_()
            _is_ref = b.u8()  # v3.4 (ADR 0003): is_ref flag
            # v3.5 (ADR 0016): BracketBody attr body tail. Event-stream
            # attrs share the ast_bin attr layout; skip body items at the
            # event layer (CXL semantics live above streaming).
            body_flag = b.u8()
            if body_flag == 1:
                body_count = b.u16()
                for _ in range(body_count):
                    _read_node(b, 5)
            e.attrs.append(SAttr(name, _coerce(typ, val_str), typ))
    elif tid == 0x04:
        e.name = b.str_()
    elif tid in (0x05, 0x07, 0x0A):
        e.value = b.str_()
    elif tid == 0x06:
        dt = b.str_(); e.data_type = dt; e.value = _coerce(dt, b.str_())
    elif tid == 0x08:
        e.target = b.str_(); e.data = b.optstr()
    elif tid in (0x09, 0x0B):
        e.value = b.str_()
    elif tid == 0x0C:
        e.name = b.str_()
        n = b.u32()
        e.col_spec = bytes(b.bytes_n(n))
    elif tid == 0x0D:
        e.row_count = b.u32()
        n = b.u32()
        e.payload = bytes(b.bytes_n(n))
    elif tid == 0x0E:
        e.name = b.str_()
    return e


def decode_events(raw: bytes) -> list:
    b = _Buf(raw)
    n = b.u32()
    return [_decode_one_event(b) for _ in range(n)]


def decode_one_event_framed(framed: bytes) -> StreamEvent:
    """Decode a single event from a framed [u32 LE size][payload] buffer
    (the shape returned by cx_events_next)."""
    size = _UNP_I.unpack_from(framed, 0)[0]
    return _decode_one_event(_Buf(framed[4:4 + size]))


# ── C ABI bridge ──────────────────────────────────────────────────────────────
# Binary functions have restype=c_void_p (set in cx.py), so they return an
# integer address rather than auto-converting to bytes like c_char_p would.

def _call_bin(fn, cx_str: str) -> bytes:
    err = ctypes.c_char_p(None)
    addr = fn(cx_str.encode(), ctypes.byref(err))  # int address or None
    if addr is None:
        raise RuntimeError(err.value.decode() if err.value else 'unknown error')
    size = struct.unpack_from('<I', ctypes.string_at(addr, 4))[0]
    payload = bytes(ctypes.string_at(addr + 4, size))
    _cx._lib.cx_free(ctypes.cast(addr, ctypes.c_char_p))
    return payload


def ast_bin(cx_str: str) -> bytes:
    return _call_bin(_cx._lib.cx_to_ast_bin, cx_str)


def ast_bin_with_include_root(cx_str: str, include_root: str) -> bytes:
    """Same as ast_bin but with opt-in ?include resolution per
    spec/include.md §1-§8 (v0.7.0 GG3 / GG4). The include_root is
    passed verbatim to the C ABI; an absolute directory is normalised
    in libcx via realpath()-equivalent before being used as the
    resolver root."""
    err = ctypes.c_char_p(None)
    addr = _cx._lib.cx_to_ast_bin_with_include_root(
        cx_str.encode(),
        include_root.encode() if include_root else b'',
        ctypes.byref(err),
    )
    if addr is None:
        raise RuntimeError(err.value.decode() if err.value else 'unknown error')
    size = struct.unpack_from('<I', ctypes.string_at(addr, 4))[0]
    payload = bytes(ctypes.string_at(addr + 4, size))
    _cx._lib.cx_free(ctypes.cast(addr, ctypes.c_char_p))
    return payload


def events_bin(cx_str: str) -> bytes:
    return _call_bin(_cx._lib.cx_to_events_bin, cx_str)


def call_bin_in_text_out(fn_name: str, ast_bin_bytes: bytes) -> str:
    """Call an ast_bin → text C function (cx_ast_bin_to_*) with FRAMED
    binary AST input and return the text result. Used by CB-1 thunks.
    """
    fn = getattr(_cx._lib, fn_name)
    err = ctypes.c_char_p(None)
    out = fn(ast_bin_bytes, ctypes.byref(err))
    if out is None:
        raise RuntimeError(err.value.decode() if err.value else 'unknown error')
    return out.decode()


def call_bin_in(fn_name: str, src: str) -> bytes:
    """Call a text → ast_bin C function (cx_<fmt>_to_ast_bin) and
    return the payload bytes (frame stripped). Used by CB-2 thunks.
    """
    fn = getattr(_cx._lib, fn_name)
    return _call_bin(fn, src)


# ── Binary AST encoder (Phase 5 / CB-1) ──────────────────────────────────────
# Inverse of decode_ast. Produces a FRAMED [u32 LE size][payload] buffer that
# matches V's emit_ast_bin output. Used by Document.to_ast_bin() to feed
# cx_ast_bin_to_<format> directly without round-tripping through CX text.

_PCK_I = struct.Struct('<I')
_PCK_H = struct.Struct('<H')


def _scalar_value_str(dt: str, v: Any) -> str:
    """Serialize a Scalar/Attr value to its canonical CX string form
    matching V's scalar_value_str. Bool first since bool is a subclass
    of int in Python."""
    if dt == 'null' or v is None:
        return 'null'
    if dt == 'bool' or isinstance(v, bool):
        return 'true' if v else 'false'
    if dt == 'string':
        return v if isinstance(v, str) else str(v)
    return str(v)


def _enc_str(out: bytearray, s: str) -> None:
    enc = s.encode('utf-8')
    out += _PCK_I.pack(len(enc))
    out += enc


def _enc_optstr(out: bytearray, s: Optional[str]) -> None:
    if s is None:
        out.append(0)
    else:
        out.append(1)
        _enc_str(out, s)


def _enc_attr(out: bytearray, a: Attr) -> None:
    _enc_str(out, a.name)
    inferred = a.data_type if a.data_type else 'string'
    _enc_str(out, _scalar_value_str(inferred, a.value))
    _enc_str(out, inferred)
    # v3.4 (ADR 0003): is_ref flag — format version 2.
    out.append(1 if getattr(a, 'is_ref', False) else 0)
    # v3.5 (ADR 0016): BracketBody attribute body tail — format version 5.
    body = getattr(a, 'body', None)
    if body is None:
        out.append(0)
    else:
        out.append(1)
        out += _PCK_H.pack(len(body))
        for n in body:
            _enc_node(out, n)


def _enc_node(out: bytearray, n: Any) -> None:
    if isinstance(n, Element):
        out.append(0x01)
        _enc_str(out, n.name)
        _enc_optstr(out, n.anchor)
        _enc_optstr(out, n.data_type)
        _enc_optstr(out, n.merge)
        # v3.4 (ADR 0003): syntactic ID declaration — format version 2.
        _enc_optstr(out, getattr(n, 'id', None))
        # v3.4 (ADR 0003 D1): body-position reference — format version 3.
        _enc_optstr(out, getattr(n, 'body_ref', None))
        out += _PCK_H.pack(len(n.attrs))
        for a in n.attrs:
            _enc_attr(out, a)
        out += _PCK_H.pack(len(n.items))
        for c in n.items:
            _enc_node(out, c)
    elif isinstance(n, Text):
        out.append(0x02); _enc_str(out, n.value)
    elif isinstance(n, Scalar):
        out.append(0x03)
        _enc_str(out, n.data_type)
        _enc_str(out, _scalar_value_str(n.data_type, n.value))
    elif isinstance(n, Comment):
        out.append(0x04); _enc_str(out, n.value)
    elif isinstance(n, RawText):
        out.append(0x05); _enc_str(out, n.value)
    elif isinstance(n, EntityRef):
        out.append(0x06); _enc_str(out, n.name)
    elif isinstance(n, Alias):
        out.append(0x07); _enc_str(out, n.name)
    elif isinstance(n, PI):
        out.append(0x08)
        _enc_str(out, n.target)
        _enc_optstr(out, n.data)
    elif isinstance(n, XMLDecl):
        out.append(0x09)
        _enc_str(out, n.version)
        _enc_optstr(out, n.encoding)
        _enc_optstr(out, n.standalone)
    elif isinstance(n, CXDirective):
        out.append(0x0A)
        out += _PCK_H.pack(len(n.attrs))
        for a in n.attrs:
            _enc_attr(out, a)
        # v0.6.0 (format version 4) — directive `&anchor` + nested children.
        _enc_optstr(out, n.anchor)
        out += _PCK_H.pack(len(n.items))
        for it in n.items:
            _enc_node(out, it)
    elif isinstance(n, BlockContent):
        out.append(0x0C)
        out += _PCK_H.pack(len(n.items))
        for it in n.items:
            _enc_node(out, it)
    elif isinstance(n, Interpolation):
        # v3.5 (ADR 0016) [58] — `[?=EXPR]`.
        out.append(0x0D)
        _enc_str(out, n.expr)
    elif isinstance(n, EvalDirective):
        # v3.5 (ADR 0016) [59] — `[?Name attrs body]`.
        out.append(0x0E)
        _enc_str(out, n.name)
        out += _PCK_H.pack(len(n.attrs))
        for a in n.attrs:
            _enc_attr(out, a)
        out += _PCK_H.pack(len(n.items))
        for it in n.items:
            _enc_node(out, it)
    else:
        # DTD / unknown node — emit 0xFF skip marker. Bindings don't
        # round-trip these; the C ABI's ast_bin_to_<format> ignores them.
        out.append(0xFF)


def encode_ast(doc: Document) -> bytes:
    """Encode a Document to a FRAMED [u32 LE size][payload] binary AST
    buffer suitable for direct hand-off to cx_ast_bin_to_<format>."""
    out = bytearray()
    out.append(0x05)  # version — bumped 4 → 5 for v0.6.0 grammar v3.5
                      #           (Interpolation/EvalDirective tags +
                      #            BracketBody attr body tail)
    out += _PCK_H.pack(len(doc.prolog))
    for n in doc.prolog:
        _enc_node(out, n)
    out += _PCK_H.pack(len(doc.elements))
    for n in doc.elements:
        _enc_node(out, n)
    framed = bytearray()
    framed += _PCK_I.pack(len(out))
    framed += out
    return bytes(framed)
