"""Streaming Table reader / writer for the chunked-table CXDB format.

Per spec/abi.md §2.10 (capability bit 21) and ADR 0015 D8. Pull / push
one row group at a time; memory bounded by the largest single row
group plus a constant.

Wire conventions (mirroring the C ABI):
  - In-memory variants consume / produce framed `[u32 LE size][CXDB payload]`.
  - fd variants operate on bare CXDB bytes (no size prefix).

Col-spec exchange: framed ast_bin with one root Element 'table' and
one Attribute per column (name = column name, value = type-name).

Usage (in-memory round-trip):

    framed = cxlib.to_data_bin_chunked('[points :table[a:int b:int] 1 2]')
    with cxlib.TableReader(framed) as r:
        schema = r.schema()
        groups = list(r)
    with cxlib.TableWriter(schema) as w:
        for g in groups: w.emit(g)
        out = w.close_get_bytes()
"""
from __future__ import annotations
import ctypes
from typing import Iterator, Optional
from . import cx as _cx


def _read_framed(addr: int) -> bytes:
    """Read a [u32 LE size][payload] buffer from a libcx-owned address."""
    size = int.from_bytes(ctypes.string_at(addr, 4), 'little')
    return bytes(ctypes.string_at(addr, 4 + size))


class TableReader:
    """Streaming reader over a chunked-table CXDB buffer or fd.

    Iterating yields each row group as framed `[u32 LE size][plain body]`
    bytes (compressed groups are decompressed by the V core before return).
    """

    def __init__(self, data_bin: bytes | None = None, *, fd: Optional[int] = None):
        if (data_bin is None) == (fd is None):
            raise ValueError('TableReader: pass exactly one of data_bin / fd')
        err = ctypes.c_char_p(None)
        if data_bin is not None:
            h = _cx._lib.cx_table_reader_open(data_bin, ctypes.byref(err))
        else:
            h = _cx._lib.cx_table_reader_open_fd(fd, ctypes.byref(err))
        if not h:
            raise RuntimeError(err.value.decode() if err.value else
                               'cx_table_reader_open: unknown error')
        self._handle = h
        self._closed = False

    def schema(self) -> bytes:
        """Return the table's col-spec as framed ast_bin."""
        if self._closed or not self._handle:
            raise RuntimeError('TableReader: handle closed')
        err = ctypes.c_char_p(None)
        addr = _cx._lib.cx_table_reader_schema(self._handle, ctypes.byref(err))
        if not addr:
            msg = err.value.decode() if err.value else 'cx_table_reader_schema: unknown error'
            raise RuntimeError(msg)
        out = _read_framed(int(addr))
        _cx._lib.cx_free(ctypes.cast(addr, ctypes.c_char_p))
        return out

    def __iter__(self) -> Iterator[bytes]:
        return self

    def __next__(self) -> bytes:
        if self._closed or not self._handle:
            raise StopIteration
        err = ctypes.c_char_p(None)
        addr = _cx._lib.cx_table_reader_next(self._handle, ctypes.byref(err))
        if not addr:
            if err.value:
                msg = err.value.decode()
                self.close()
                raise RuntimeError(msg)
            raise StopIteration
        out = _read_framed(int(addr))
        _cx._lib.cx_free(ctypes.cast(addr, ctypes.c_char_p))
        return out

    def close(self) -> None:
        if self._closed:
            return
        self._closed = True
        if self._handle:
            _cx._lib.cx_table_reader_close(self._handle)
            self._handle = None

    def __enter__(self): return self
    def __exit__(self, *_): self.close()
    def __del__(self):
        try: self.close()
        except Exception: pass


class TableWriter:
    """Streaming writer for the chunked-table CXDB format.

    `col_spec_payload` is the framed ast_bin shape returned by
    TableReader.schema(). Provide `fd` for fd-streaming output;
    otherwise the writer accumulates in-memory and `close_get_bytes()`
    returns the complete framed buffer.
    """

    def __init__(self, col_spec_payload: bytes, *, fd: Optional[int] = None):
        err = ctypes.c_char_p(None)
        if fd is None:
            h = _cx._lib.cx_table_writer_open(col_spec_payload, ctypes.byref(err))
        else:
            h = _cx._lib.cx_table_writer_open_fd(col_spec_payload, fd, ctypes.byref(err))
        if not h:
            raise RuntimeError(err.value.decode() if err.value else
                               'cx_table_writer_open: unknown error')
        self._handle = h
        self._closed = False
        self._fd = fd

    def emit(self, row_group_payload: bytes) -> None:
        """Append one row group. `row_group_payload` is the framed
        `[u32 LE size][plain body]` shape yielded by TableReader."""
        if self._closed or not self._handle:
            raise RuntimeError('TableWriter: handle closed')
        err = ctypes.c_char_p(None)
        ret = _cx._lib.cx_table_writer_emit_row_group(
            self._handle, row_group_payload, ctypes.byref(err))
        # Convention: returns NULL on success; NULL with err set on failure.
        if ret is not None and err.value:
            raise RuntimeError(err.value.decode())
        if err.value:
            raise RuntimeError(err.value.decode())

    def close_get_bytes(self) -> bytes:
        """In-memory writers only: emit end-of-table and return the
        complete framed chunked-table buffer."""
        if self._fd is not None:
            raise RuntimeError('close_get_bytes is for in-memory writers; use close() for fd writers')
        if self._closed or not self._handle:
            raise RuntimeError('TableWriter: handle closed')
        err = ctypes.c_char_p(None)
        addr = _cx._lib.cx_table_writer_close_get_bytes(self._handle, ctypes.byref(err))
        # The V core releases the handle inside close_get_bytes; mark closed.
        self._handle = None
        self._closed = True
        if not addr:
            msg = err.value.decode() if err.value else 'cx_table_writer_close_get_bytes: unknown error'
            raise RuntimeError(msg)
        out = _read_framed(int(addr))
        _cx._lib.cx_free(ctypes.cast(addr, ctypes.c_char_p))
        return out

    def close(self) -> None:
        """Release the handle. For fd writers, flushes the end-of-table marker."""
        if self._closed:
            return
        self._closed = True
        if self._handle:
            _cx._lib.cx_table_writer_close(self._handle)
            self._handle = None

    def __enter__(self): return self
    def __exit__(self, exc_type, *_):
        # If the user didn't already drain via close_get_bytes(), release the handle.
        if not self._closed:
            self.close()
    def __del__(self):
        try: self.close()
        except Exception: pass
