"""Streaming-write API binding — `cxlib.EventWriter`.

Per spec/streaming.md §6 + spec/abi.md §2.15. Thin wrapper
around the 25 cx_events_writer_* C ABI symbols. The writer accepts
the 14 stream events defined in §1 and emits format-targeted output
(cx / xml / json / yaml / toml / md, selected at open time). The CX
and XML output formats are implemented in v0.6.0; json / yaml / toml /
md emits surface a W009 RuntimeError until their per-format follow-ups
land. Capability bit 27.

Usage (in-memory):

    with cxlib.EventWriter('cx') as w:
        w.start_doc()
        w.start_element('greet')
        w.text('hello')
        w.end_element('greet')
        w.end_doc()
        out = w.close_get_bytes()       # bytes

Usage (fd):

    with cxlib.EventWriter('xml', fd=sys.stdout.fileno()) as w:
        w.start_doc(); ... ; w.end_doc()
    # bytes already flushed; close_get_bytes returns b''.

Errors raise RuntimeError; the message carries the W-code prefix
(W001-W013) verbatim so callers can match on it. The writer fails
closed — once a W-code is raised, subsequent emits raise the same
diagnostic without effect.
"""
from __future__ import annotations
import ctypes
import decimal
import struct
from typing import Iterable, Optional, Tuple, Union

from . import cx as _cx


# ── capability probe ─────────────────────────────────────────────────────────

_CAP_BIT_STREAMING_WRITE = 1 << 27


def _has_capability() -> bool:
    try:
        return bool(_cx.features() & _CAP_BIT_STREAMING_WRITE)
    except Exception:
        return False


# ── framed-bytes helpers ─────────────────────────────────────────────────────

def _read_framed(addr: int) -> bytes:
    size = int.from_bytes(ctypes.string_at(addr, 4), 'little')
    return bytes(ctypes.string_at(addr + 4, size))


def _frame(payload: bytes) -> bytes:
    return struct.pack('<I', len(payload)) + payload


# ── attribute payload encoder ────────────────────────────────────────────────

AttrTuple = Tuple[str, object, Optional[str]]      # (name, value, data_type)


_KNOWN_TYPES = {'int', 'i8', 'i16', 'i32', 'i64',
                'u8', 'u16', 'u32', 'u64',
                'float', 'f32', 'f64', 'decimal', 'bigint', 'f16',
                'bool', 'null', 'string', 's',
                'date', 'datetime', 'bytes'}


def _infer_type(v: object) -> str:
    if isinstance(v, bool):     return 'bool'
    if isinstance(v, int):
        # L20 auto-promotion: beyond i64 the kind is bigint, never an error.
        return 'int' if -(2**63) <= v <= (2**63) - 1 else 'bigint'
    if isinstance(v, decimal.Decimal):
        return 'decimal'
    if isinstance(v, float):    return 'float'
    if v is None:               return 'null'
    return 'string'


def _attr_value_str(typ: str, v: object) -> str:
    if v is None:                                 return 'null'
    if isinstance(v, bool):                       return 'true' if v else 'false'
    if isinstance(v, decimal.Decimal):
        # Decimal images are fixed-point base-10 (scale preserved);
        # str(Decimal('1E+5')) would emit exponent notation.
        return format(v, 'f')
    if isinstance(v, (int, float)):               return str(v)
    return str(v)


def _enc_lp(out: bytearray, s: str) -> None:
    enc = s.encode('utf-8')
    out += struct.pack('<I', len(enc))
    out += enc


def _build_attrs_payload(attrs: Optional[Iterable[Union[AttrTuple, Tuple[str, object]]]]) -> bytes:
    """Encode attrs as `u16 count + [u32 name_len][name][u32 val_len][val]
    [u32 typ_len][typ][u8 is_ref]` (per V parse_attrs_payload). Returns
    empty bytes when attrs is None/empty.
    """
    if not attrs:
        return b''
    items = list(attrs)
    out = bytearray()
    out += struct.pack('<H', len(items))
    for entry in items:
        if len(entry) == 2:
            name, value = entry                              # type: ignore[misc]
            data_type = None
        else:
            name, value, data_type = entry                   # type: ignore[misc]
        typ = data_type if data_type else _infer_type(value)
        _enc_lp(out, name)
        _enc_lp(out, _attr_value_str(typ, value))
        _enc_lp(out, typ)
        out.append(0)                                         # is_ref
    return bytes(out)


# ── error helpers ────────────────────────────────────────────────────────────

def _raise_if_err(ret_ptr, err_holder, op: str) -> None:
    """Per §6.4, emit returns NULL on success or a heap-allocated diagnostic
    string. The same string is mirrored into err_holder for ergonomic access.
    `ret_ptr` is a c_char_p; truthy = diagnostic present = error."""
    if ret_ptr:
        msg = ret_ptr.decode('utf-8', errors='replace') if isinstance(ret_ptr, bytes) else str(ret_ptr)
        raise RuntimeError(msg)
    if err_holder.value:
        raise RuntimeError(err_holder.value.decode('utf-8', errors='replace'))


# ── EventWriter ──────────────────────────────────────────────────────────────


class EventWriter:
    """Thread-local event writer. One writer = one thread (per §6.2)."""

    def __init__(self, output_format: str, *, fd: Optional[int] = None):
        if not _has_capability():
            raise RuntimeError(
                'cxlib.EventWriter requires libcx capability bit 27 '
                '(streaming-write API; v0.6.0+). cx_features did not advertise it.'
            )
        err = ctypes.c_char_p(None)
        fmt = output_format.encode()
        if fd is None:
            h = _cx._lib.cx_events_writer_open(fmt, ctypes.byref(err))
        else:
            h = _cx._lib.cx_events_writer_open_fd(fmt, fd, ctypes.byref(err))
        if not h:
            raise RuntimeError(err.value.decode() if err.value
                               else f'cx_events_writer_open({output_format}): unknown error')
        self._handle = ctypes.c_void_p(h)
        self._closed = False
        self._fd = fd
        self._format = output_format

    # ── lifecycle ────────────────────────────────────────────────────────────

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        if not self._closed:
            # Release the handle without finalising bytes. The caller
            # decides whether to drain via close_get_bytes; if they
            # didn't, we still need to free the libcx-side handle here.
            self._closed = True
            if self._handle:
                _cx._lib.cx_events_writer_close(self._handle)
                self._handle = None

    def __del__(self):
        try:
            if not getattr(self, '_closed', True) and getattr(self, '_handle', None):
                _cx._lib.cx_events_writer_close(self._handle)
        except Exception:
            pass

    def close_get_bytes(self) -> bytes:
        """Finalise the writer and return the accumulated output bytes.
        For fd writers the returned buffer is empty (output already flushed).
        Implicitly emits EndDoc — raises W004 if elements / table remain open.
        """
        if self._closed or not self._handle:
            raise RuntimeError('EventWriter: already closed')
        err = ctypes.c_char_p(None)
        addr = _cx._lib.cx_events_writer_close_get_bytes(self._handle, ctypes.byref(err))
        self._closed = True
        # The writer is single-use; libcx-side handle is consumed by
        # close_get_bytes either via success (writer state marked closed
        # in V) or via error. Either way we should not call close again.
        old_handle = self._handle
        self._handle = None
        if not addr:
            msg = err.value.decode() if err.value else 'cx_events_writer_close_get_bytes: unknown error'
            # Free the handle to release V-side resources on error path.
            _cx._lib.cx_events_writer_close(old_handle)
            raise RuntimeError(msg)
        out = _read_framed(int(addr))
        _cx._lib.cx_free(ctypes.cast(addr, ctypes.c_char_p))
        # V-side close_get_bytes marks the writer closed and the handle
        # is no longer usable. Still call close() to release any internal
        # bookkeeping (idempotent on V side).
        _cx._lib.cx_events_writer_close(old_handle)
        return out

    # ── emits ────────────────────────────────────────────────────────────────

    def start_doc(self) -> None:
        err = ctypes.c_char_p(None)
        ret = _cx._lib.cx_events_writer_start_doc(self._handle, ctypes.byref(err))
        _raise_if_err(ret, err, 'start_doc')

    def end_doc(self) -> None:
        err = ctypes.c_char_p(None)
        ret = _cx._lib.cx_events_writer_end_doc(self._handle, ctypes.byref(err))
        _raise_if_err(ret, err, 'end_doc')

    def start_element(self, name: str, *, anchor: Optional[str] = None,
                      data_type: Optional[str] = None, merge: Optional[str] = None,
                      attrs: Optional[Iterable[Union[AttrTuple, Tuple[str, object]]]] = None) -> None:
        err = ctypes.c_char_p(None)
        attrs_raw = _build_attrs_payload(attrs)
        if attrs_raw:
            framed = _frame(attrs_raw)
            ret = _cx._lib.cx_events_writer_start_element_with_len(
                self._handle,
                name.encode(),
                anchor.encode() if anchor is not None else None,
                data_type.encode() if data_type is not None else None,
                merge.encode() if merge is not None else None,
                framed, len(framed),
                ctypes.byref(err),
            )
        else:
            ret = _cx._lib.cx_events_writer_start_element_with_len(
                self._handle,
                name.encode(),
                anchor.encode() if anchor is not None else None,
                data_type.encode() if data_type is not None else None,
                merge.encode() if merge is not None else None,
                None, 0,
                ctypes.byref(err),
            )
        _raise_if_err(ret, err, 'start_element')

    def end_element(self, name: str) -> None:
        err = ctypes.c_char_p(None)
        ret = _cx._lib.cx_events_writer_end_element(self._handle, name.encode(), ctypes.byref(err))
        _raise_if_err(ret, err, 'end_element')

    def text(self, value: str) -> None:
        err = ctypes.c_char_p(None)
        ret = _cx._lib.cx_events_writer_text(self._handle, value.encode(), ctypes.byref(err))
        _raise_if_err(ret, err, 'text')

    def scalar(self, value: str, *, data_type: Optional[str] = None) -> None:
        err = ctypes.c_char_p(None)
        ret = _cx._lib.cx_events_writer_scalar(
            self._handle,
            data_type.encode() if data_type is not None else None,
            value.encode(),
            ctypes.byref(err))
        _raise_if_err(ret, err, 'scalar')

    def comment(self, value: str) -> None:
        err = ctypes.c_char_p(None)
        ret = _cx._lib.cx_events_writer_comment(self._handle, value.encode(), ctypes.byref(err))
        _raise_if_err(ret, err, 'comment')

    def pi(self, target: str, data: Optional[str] = None) -> None:
        err = ctypes.c_char_p(None)
        ret = _cx._lib.cx_events_writer_pi(
            self._handle, target.encode(),
            data.encode() if data is not None else None,
            ctypes.byref(err))
        _raise_if_err(ret, err, 'pi')

    def entity_ref(self, name: str) -> None:
        err = ctypes.c_char_p(None)
        ret = _cx._lib.cx_events_writer_entity_ref(self._handle, name.encode(), ctypes.byref(err))
        _raise_if_err(ret, err, 'entity_ref')

    def raw_text(self, value: str) -> None:
        err = ctypes.c_char_p(None)
        ret = _cx._lib.cx_events_writer_raw_text(self._handle, value.encode(), ctypes.byref(err))
        _raise_if_err(ret, err, 'raw_text')

    def alias(self, name: str) -> None:
        err = ctypes.c_char_p(None)
        ret = _cx._lib.cx_events_writer_alias(self._handle, name.encode(), ctypes.byref(err))
        _raise_if_err(ret, err, 'alias')

    # ── chunked-table emits (CX output only — non-CX targets raise W009) ─────

    def start_table(self, col_spec_payload: bytes) -> None:
        """Open a chunked table. `col_spec_payload` is the unframed
        column-spec wire form per spec/core/data-bin.md §3.10.1:
            [u32 LE count] ([u32 LE name_len] name [u8 type_code])*
        """
        err = ctypes.c_char_p(None)
        framed = _frame(col_spec_payload)
        ret = _cx._lib.cx_events_writer_start_table_with_len(
            self._handle, framed, len(framed), ctypes.byref(err))
        _raise_if_err(ret, err, 'start_table')

    def row_group(self, payload: bytes) -> None:
        """Append a row group. `payload` is the unframed §3.11.2 plain
        body: `uvarint(row_count) + col-payload[col_count]`."""
        err = ctypes.c_char_p(None)
        framed = _frame(payload)
        ret = _cx._lib.cx_events_writer_row_group_with_len(
            self._handle, framed, len(framed), ctypes.byref(err))
        _raise_if_err(ret, err, 'row_group')

    def end_table(self) -> None:
        err = ctypes.c_char_p(None)
        ret = _cx._lib.cx_events_writer_end_table(self._handle, ctypes.byref(err))
        _raise_if_err(ret, err, 'end_table')
