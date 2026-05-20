"""Parquet read/write bridge for cxlib (X-row / v0.7.0).

Per ADR 0015 D11, Parquet lives at the binding layer (not inside
libcx). This module composes the existing cx → Arrow path with
pyarrow.parquet to provide one-call CX ↔ Parquet round-trips
without adding any C++ Parquet dependency to libcx.

API:
    cxlib.parquet.write_table(cx_data_bin, path, ...)
    cxlib.parquet.read_table(path) -> bytes  # CXDB chunked-table

CLI parity (when wired into the `cx` command):
    cx table dump --parquet OUT.parquet --input table.cx
    cx table load --parquet IN.parquet  > table.cx
"""

from __future__ import annotations

from typing import Optional
from . import arrow as _cxa


def _require_pyarrow():
    try:
        import pyarrow as pa  # noqa: F401
        import pyarrow.parquet as pq  # noqa: F401
    except ImportError as e:
        raise RuntimeError(
            "pyarrow + pyarrow.parquet are required; install via "
            "`pip install pyarrow` or `pip install cxlib[parquet]`"
        ) from e
    import pyarrow as pa
    import pyarrow.parquet as pq
    return pa, pq


def write_table(
    cx_data_bin: bytes,
    path: str,
    *,
    compression: Optional[str] = "snappy",
    row_group_size: Optional[int] = None,
) -> None:
    """Write framed CXDB chunked-table bytes to a Parquet file.

    Composes cxlib.arrow.export → pyarrow.Table → pq.write_table.

    Arguments:
        cx_data_bin     framed `[u32 LE size][CXDB payload]` (the shape
                        cxlib.to_data_bin_chunked() returns)
        path            output filesystem path
        compression     pyarrow.parquet compression codec ('snappy',
                        'gzip', 'zstd', 'brotli', 'lz4', or None for
                        uncompressed). Default 'snappy' matches
                        pyarrow's default.
        row_group_size  rows per Parquet row group; None lets
                        pyarrow choose.

    Raises:
        RuntimeError if pyarrow is missing or the chunked-table
        payload fails Arrow export (e.g., uses a deferred type).
    """
    _, pq = _require_pyarrow()
    reader = _cxa.export(cx_data_bin)
    table = reader.read_all()
    kwargs = {"compression": compression} if compression else {}
    if row_group_size is not None:
        kwargs["row_group_size"] = row_group_size
    pq.write_table(table, path, **kwargs)


def read_table(path: str) -> bytes:
    """Read a Parquet file and return framed CXDB chunked-table bytes.

    Composes pq.read_table → pyarrow.Table → cxlib.arrow.import_to_data_bin.
    The returned bytes are framed (`[u32 LE size][CXDB payload]`) and
    feed directly into cxlib.from_data_bin() or cxlib.TableReader.

    Arguments:
        path    input Parquet file path

    Returns:
        bytes — framed CXDB chunked-table payload

    Raises:
        RuntimeError if pyarrow is missing or import_to_data_bin
        encounters a column type that cx can't represent yet
        (decimal / dictionary / nested — these surface clear errors).
    """
    _, pq = _require_pyarrow()
    table = pq.read_table(path)
    return _cxa.import_to_data_bin(table)


# X1/X2 v0.7.0: module-level CLI for `cx table dump --parquet`. The V
# CLI shells out to this entry point so the V binary stays free of
# Parquet linkage (pyarrow is the canonical reference per X-row).
def _main() -> int:
    import sys
    if len(sys.argv) < 4 or sys.argv[1] not in ("dump", "load"):
        sys.stderr.write(
            "Usage:\n"
            "  python -m cxlib.parquet dump <input.cxdb> <output.parquet>\n"
            "  python -m cxlib.parquet load <input.parquet> <output.cxdb>\n"
        )
        return 2
    verb, src_path, dst_path = sys.argv[1], sys.argv[2], sys.argv[3]
    if verb == "dump":
        with open(src_path, "rb") as f:
            framed = f.read()
        write_table(framed, dst_path)
    else:  # load
        framed = read_table(src_path)
        with open(dst_path, "wb") as f:
            f.write(framed)
    return 0


if __name__ == "__main__":
    import sys as _sys
    _sys.exit(_main())
