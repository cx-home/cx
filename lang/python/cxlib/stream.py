"""CX streaming event API."""
from __future__ import annotations
import json
from dataclasses import dataclass, field
from typing import Any, Iterator, Optional
from . import cx as _cx


@dataclass
class Attr:
    name: str
    value: Any
    data_type: Optional[str] = None


@dataclass
class StreamEvent:
    type: str
    # StartElement fields
    name: Optional[str] = None
    attrs: list = field(default_factory=list)
    data_type: Optional[str] = None
    anchor: Optional[str] = None
    merge: Optional[str] = None
    # Scalar / Text / Comment / RawText / EntityRef / Alias fields
    value: Any = None
    # PI fields
    target: Optional[str] = None
    data: Optional[str] = None
    # Chunked-table fields (StartTable / RowGroup / EndTable, ADR 0015 D10).
    # col_spec is the §1.1 events-layer encoding: [u32 LE: count]
    # ([u32 LE: name_len]name [u8: col_type_code])*. payload is the §3.11.2
    # plain-body bytes uvarint(row_count) <col-payload>(col_count) — already
    # decompressed if the source row group used §3.12 zstd wrapping.
    col_spec: bytes = b''
    row_count: int = 0
    payload: bytes = b''

    @classmethod
    def from_dict(cls, d: dict) -> 'StreamEvent':
        t = d.get('type', '')
        e = cls(type=t)
        if t == 'StartElement':
            e.name = d.get('name')
            e.attrs = [Attr(a['name'], a['value'], a.get('dataType')) for a in d.get('attrs', [])]
            e.data_type = d.get('dataType')
            e.anchor = d.get('anchor')
            e.merge = d.get('merge')
        elif t == 'EndElement':
            e.name = d.get('name')
        elif t in ('Text', 'Comment', 'RawText', 'Alias', 'EntityRef'):
            e.value = d.get('value') or d.get('name')
        elif t == 'Scalar':
            e.data_type = d.get('dataType')
            e.value = d.get('value')
        elif t == 'PI':
            e.target = d.get('target')
            e.data = d.get('data')
        elif t == 'StartTable':
            import base64
            e.name = d.get('name')
            e.col_spec = base64.b64decode(d.get('colSpecBase64', ''))
        elif t == 'RowGroup':
            import base64
            e.row_count = int(d.get('rowCount', 0))
            e.payload = base64.b64decode(d.get('payloadBase64', ''))
        elif t == 'EndTable':
            e.name = d.get('name')
        return e

    def is_start_element(self, name: Optional[str] = None) -> bool:
        return self.type == 'StartElement' and (name is None or self.name == name)

    def is_end_element(self, name: Optional[str] = None) -> bool:
        return self.type == 'EndElement' and (name is None or self.name == name)


class Stream:
    """Iterator over CX streaming events.

    Usage:
        with cx.Stream('[config host=localhost]') as s:
            for event in s:
                if event.is_start_element():
                    print(event.name, event.attrs)

    v3.4: handle-based pull API via cx_events_open / cx_events_next /
    cx_events_close (Phase 5 / CB-4). Replaces the prior eager-buffered
    `decode_events(events_bin(cx_str))` which materialized the full
    event list up-front.
    """

    def __init__(self, cx_str: str):
        import ctypes
        from . import cx as _cx_mod
        err = ctypes.c_char_p(None)
        h = _cx_mod._lib.cx_events_open(cx_str.encode(), ctypes.byref(err))
        if not h:
            raise RuntimeError(err.value.decode() if err.value else 'cx_events_open: unknown error')
        self._handle = h
        self._closed = False

    def __iter__(self) -> Iterator[StreamEvent]:
        return self

    def __next__(self) -> StreamEvent:
        import ctypes
        from . import cx as _cx_mod
        from .binary import decode_one_event_framed
        if self._closed or not self._handle:
            raise StopIteration
        err = ctypes.c_char_p(None)
        addr = _cx_mod._lib.cx_events_next(self._handle, ctypes.byref(err))
        if not addr:
            # NULL with err set = error; NULL with no err = EOF.
            if err.value:
                msg = err.value.decode()
                self.close()
                raise RuntimeError(msg)
            self.close()
            raise StopIteration
        # Read framed [u32 size][payload] from the C-owned buffer, copy
        # the bytes out, then free the buffer.
        size = int.from_bytes(ctypes.string_at(addr, 4), 'little')
        framed = bytes(ctypes.string_at(addr, 4 + size))
        _cx_mod._lib.cx_free(ctypes.cast(addr, ctypes.c_char_p))
        return decode_one_event_framed(framed)

    def next(self) -> Optional[StreamEvent]:
        """Return next event or None when exhausted."""
        try:
            return self.__next__()
        except StopIteration:
            return None

    def collect(self) -> list:
        """Return all remaining events as a list."""
        return list(self)

    def close(self) -> None:
        """Release the underlying handle. Idempotent."""
        if self._closed:
            return
        self._closed = True
        if self._handle:
            from . import cx as _cx_mod
            _cx_mod._lib.cx_events_close(self._handle)
            self._handle = None

    def __enter__(self): return self
    def __exit__(self, *_): self.close()
    def __del__(self):
        # Best-effort release if the user forgot the context manager.
        try: self.close()
        except Exception: pass


def stream(cx_str: str) -> Stream:
    """Create a Stream from a CX string."""
    return Stream(cx_str)
