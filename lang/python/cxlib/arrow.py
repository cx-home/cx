"""Apache Arrow C-Data interop for cxlib.

Bridges CXDB chunked-tables to Arrow ArrowArrayStream via libcx_arrow
(spec/abi.md §2.11, ADR 0015 D9, capability bit 0x800000). The bridge
handles all 9 v0.6.0 column types (int, i8, i16, i32, float, bool,
string, date, bytes); datetime / decimal / dictionary columns are
deferred and surface the V core's deferred-type error.

PyArrow >= 14 is required (`pip install cxlib[arrow]` or
`pip install pyarrow`). libcx_arrow is loaded as a separate dynamic
library; if absent (or pyarrow missing), `available()` reports False
and consumers can fall back to materializing through CSV / JSON via
`cxlib`'s data_bin entry points. Any direct call to `export()` /
`import_to_data_bin()` raises RuntimeError if either dependency is
missing.

Usage:

    import cxlib
    import cxlib.arrow as cxa

    framed = cxlib.to_data_bin_chunked(
        '[points :table[name:string score:int] alice 91 bob 88]')
    reader = cxa.export(framed)        # pyarrow.RecordBatchReader
    table = reader.read_all()          # pyarrow.Table

    framed_again = cxa.import_to_data_bin(table)
"""
from __future__ import annotations
import ctypes
import os
import pathlib
from typing import Optional

from . import cx as _cx


def _load_libcx_arrow() -> Optional[ctypes.CDLL]:
    """Locate and dlopen libcx_arrow. Returns None if not found.

    Search order:
      1. LIBCX_ARROW_PATH env var (explicit path).
      2. Same directory as the libcx that cxlib already loaded.
      3. LIBCX_LIB_DIR env var (directory containing both libs).
      4. Standard system library paths.
      5. Repo-relative fallback (`vcx/target/`, `dist/lib/`).
    """
    lib_name = "libcx_arrow.dylib" if os.uname().sysname == "Darwin" else "libcx_arrow.so"

    if env := os.environ.get("LIBCX_ARROW_PATH"):
        try:
            return ctypes.CDLL(env)
        except OSError:
            return None

    candidates: list[pathlib.Path] = []

    libcx_name = getattr(_cx._lib, '_name', None)
    if libcx_name:
        candidates.append(pathlib.Path(libcx_name).resolve().parent / lib_name)

    if env_dir := os.environ.get("LIBCX_LIB_DIR"):
        candidates.append(pathlib.Path(env_dir) / lib_name)

    for sys_dir in ("/usr/local/lib", "/opt/homebrew/lib", "/usr/lib",
                    "/usr/lib/x86_64-linux-gnu", "/usr/lib/aarch64-linux-gnu"):
        candidates.append(pathlib.Path(sys_dir) / lib_name)

    base = pathlib.Path(__file__).resolve().parent.parent.parent.parent
    candidates += [
        base / "vcx" / "target" / lib_name,
        base / "dist" / "lib" / lib_name,
    ]

    for p in candidates:
        if p.exists():
            try:
                return ctypes.CDLL(str(p))
            except OSError:
                continue
    return None


_lib = _load_libcx_arrow()

if _lib is not None:
    _lib.cx_arrow_free.restype  = None
    _lib.cx_arrow_free.argtypes = [ctypes.c_void_p]

    _lib.cx_arrow_features.restype  = ctypes.c_char_p
    _lib.cx_arrow_features.argtypes = []

    _lib.cx_arrow_version.restype  = ctypes.c_char_p
    _lib.cx_arrow_version.argtypes = []

    # NULL on success or NULL with err_out set on failure (libcx convention).
    _lib.cx_arrow_export_open.restype     = ctypes.c_void_p
    _lib.cx_arrow_export_open.argtypes    = [
        ctypes.c_char_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_char_p)
    ]
    _lib.cx_arrow_export_open_fd.restype  = ctypes.c_void_p
    _lib.cx_arrow_export_open_fd.argtypes = [
        ctypes.c_int, ctypes.c_void_p, ctypes.POINTER(ctypes.c_char_p)
    ]

    # Returns framed [u32 LE size][CXDB] heap buffer; caller frees via cx_arrow_free.
    _lib.cx_arrow_import_to_data_bin.restype     = ctypes.c_void_p
    _lib.cx_arrow_import_to_data_bin.argtypes    = [
        ctypes.c_void_p, ctypes.POINTER(ctypes.c_char_p)
    ]
    _lib.cx_arrow_import_to_data_bin_fd.restype  = ctypes.c_void_p
    _lib.cx_arrow_import_to_data_bin_fd.argtypes = [
        ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_char_p)
    ]


def available() -> bool:
    """True if libcx_arrow loaded successfully AND pyarrow is importable."""
    if _lib is None:
        return False
    try:
        import pyarrow  # noqa: F401
        import pyarrow.cffi  # noqa: F401
        return True
    except ImportError:
        return False


def features() -> int:
    """libcx_arrow capability bitmask. Raises if libcx_arrow missing."""
    _require_lib()
    return int(_lib.cx_arrow_features().decode(), 16)


def version() -> str:
    """libcx_arrow build version string. Raises if libcx_arrow missing."""
    _require_lib()
    return _lib.cx_arrow_version().decode()


def merged_features() -> int:
    """OR of libcx and libcx_arrow capability bitmasks. If libcx_arrow is
    missing, returns libcx's bitmask alone (bit 23 unset)."""
    base = _cx.features()
    if _lib is None:
        return base
    return base | int(_lib.cx_arrow_features().decode(), 16)


def _require_lib() -> None:
    if _lib is None:
        raise RuntimeError(
            "libcx_arrow not available. Build with `make lib-arrow` or set "
            "LIBCX_ARROW_PATH; bit 23 (0x800000) reports unset until present."
        )


def _require_pyarrow():
    try:
        import pyarrow as pa
        import pyarrow.cffi as _pa_cffi
    except ImportError as e:
        raise RuntimeError(
            "pyarrow is required for the Arrow bridge. Install via "
            "`pip install pyarrow` or `pip install cxlib[arrow]`."
        ) from e
    return pa, _pa_cffi


def export(data_bin: bytes):
    """Export framed CXDB chunked-table bytes as a pyarrow.RecordBatchReader.

    `data_bin` is the framed `[u32 LE size][CXDB payload]` shape produced by
    `cxlib.to_data_bin_chunked()` or `TableWriter.close_get_bytes()`. The
    payload root MUST be a chunked-table (tag 0x63), optionally wrapped in a
    single-pair map per the chunked emit convention.

    Memory: cxlib copies the input into a stream-owned buffer; the caller
    may release `data_bin` immediately. The returned reader owns the
    underlying ArrowArrayStream and releases it on drop / close.
    """
    _require_lib()
    pa, _pa_cffi = _require_pyarrow()
    ffi = _pa_cffi.ffi

    stream = ffi.new('struct ArrowArrayStream*')
    stream_ptr = int(ffi.cast('uintptr_t', stream))

    err = ctypes.c_char_p(None)
    _lib.cx_arrow_export_open(data_bin, stream_ptr, ctypes.byref(err))
    if err.value:
        msg = err.value.decode()
        raise RuntimeError(msg)

    # _import_from_c moves the stream callbacks into a pyarrow-owned struct
    # per the Arrow C-Data ABI move semantics; after this call our cffi-
    # allocated buffer is empty and is freed by cffi GC.
    return pa.RecordBatchReader._import_from_c(stream_ptr)


def import_to_data_bin(source) -> bytes:
    """Drain a pyarrow source into framed CXDB chunked-table bytes.

    Accepts pyarrow.RecordBatchReader (preferred — single-pass), or
    pyarrow.Table (converted via `Table.to_reader()`). Returns the framed
    `[u32 LE size][CXDB payload]` buffer.
    """
    _require_lib()
    pa, _pa_cffi = _require_pyarrow()
    ffi = _pa_cffi.ffi

    if isinstance(source, pa.Table):
        reader = source.to_reader()
    elif isinstance(source, pa.RecordBatchReader):
        reader = source
    else:
        raise TypeError(
            f"expected pyarrow.RecordBatchReader or pyarrow.Table; got {type(source).__name__}"
        )

    stream = ffi.new('struct ArrowArrayStream*')
    stream_ptr = int(ffi.cast('uintptr_t', stream))
    reader._export_to_c(stream_ptr)

    err = ctypes.c_char_p(None)
    addr = _lib.cx_arrow_import_to_data_bin(stream_ptr, ctypes.byref(err))
    if not addr:
        msg = err.value.decode() if err.value else 'cx_arrow_import_to_data_bin: unknown error'
        raise RuntimeError(msg)
    size = int.from_bytes(ctypes.string_at(addr, 4), 'little')
    out = bytes(ctypes.string_at(addr, 4 + size))
    _lib.cx_arrow_free(ctypes.c_void_p(addr))
    return out


# W2 v0.7.0: Arrow IPC stream format read/write.
#
# Implements .arrow file IPC reader/writer by delegating to pyarrow's
# IPC layer over the existing C-Data Interface export/import bridge.
# The pipeline:
#
#   data_bin → export → pyarrow.RecordBatchReader → ipc.RecordBatchStreamWriter → bytes
#   bytes → ipc.RecordBatchStreamReader → pyarrow.RecordBatchReader → import → data_bin
#
# pyarrow's IPC layer handles flatbuffer encoding/decoding; we never
# touch flatbuffer bytes directly. This is the canonical Apache Arrow
# pattern — IPC is a wire format whose codec lives in each language's
# Arrow library, not in CX.

def to_ipc(data_bin: bytes) -> bytes:
    """Convert framed CXDB chunked-table bytes to Arrow IPC stream bytes.

    Returns a `bytes` object suitable for writing to a `.arrow` file
    or piping into another Arrow IPC consumer.

    Memory: copies the table through pyarrow's IPC writer.
    """
    _require_lib()
    pa, _pa_cffi = _require_pyarrow()
    import io
    import pyarrow.ipc as paipc
    reader = export(data_bin)
    sink = io.BytesIO()
    with paipc.new_stream(sink, reader.schema) as writer:
        for batch in reader:
            writer.write_batch(batch)
    return sink.getvalue()


def from_ipc(ipc_bytes: bytes) -> bytes:
    """Convert Arrow IPC stream bytes to framed CXDB chunked-table bytes.

    Accepts the byte stream a `.arrow` file would contain. Returns
    framed CXDB bytes (`[u32 LE size][CXDB payload]`) that round-trip
    through `cxlib.from_data_bin_chunked()`.
    """
    _require_lib()
    pa, _pa_cffi = _require_pyarrow()
    import io
    import pyarrow.ipc as paipc
    source = io.BytesIO(ipc_bytes)
    with paipc.open_stream(source) as reader:
        # RecordBatchReader is the interchange shape import_to_data_bin
        # expects.
        return import_to_data_bin(reader)


def write_ipc_file(data_bin: bytes, path: str) -> None:
    """Write framed CXDB bytes to a `.arrow` IPC file at `path`."""
    with open(path, "wb") as f:
        f.write(to_ipc(data_bin))


def read_ipc_file(path: str) -> bytes:
    """Read a `.arrow` IPC file and return framed CXDB bytes."""
    with open(path, "rb") as f:
        return from_ipc(f.read())


# W2 v0.7.0: module-level CLI for `cx table dump --arrow` and IPC
# read/write. The V CLI shells out to this entry point so the V binary
# stays free of Arrow IPC linkage (pyarrow is the canonical reference).
def _main() -> int:
    import sys
    if len(sys.argv) < 4 or sys.argv[1] not in ("dump", "load"):
        sys.stderr.write(
            "Usage:\n"
            "  python -m cxlib.arrow dump <input.cxdb> <output.arrow>\n"
            "  python -m cxlib.arrow load <input.arrow> <output.cxdb>\n"
        )
        return 2
    verb, src_path, dst_path = sys.argv[1], sys.argv[2], sys.argv[3]
    if verb == "dump":
        with open(src_path, "rb") as f:
            framed = f.read()
        write_ipc_file(framed, dst_path)
    else:  # load
        framed = read_ipc_file(src_path)
        with open(dst_path, "wb") as f:
            f.write(framed)
    return 0


if __name__ == "__main__":
    import sys as _sys
    _sys.exit(_main())
