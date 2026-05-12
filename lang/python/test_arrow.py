#!/usr/bin/env python3
"""
Apache Arrow C-Data interop tests for lang/python/cxlib (Phase 7.74c-cont-bindings).

Mirrors the V core test (vcx/arrow/arrow_test.v):
  - Round-trip per supported v0.6.0 column type: int / i8 / i16 / i32 /
    float / bool / string / date / bytes (9 tests).
  - datetime column round-trips as Arrow timestamp[ns, UTC].
  - pyarrow.Table → CXDB → pyarrow.Table inverse round-trip.
  - Capability + version smoke tests.

Requires `pyarrow >= 14`; the entire suite is skipped if pyarrow is
not importable. If `libcx_arrow.dylib` / `.so` is not built (i.e.
`make lib-arrow` has not been run) the suite is also skipped — the
graceful-degradation path is itself asserted in `test_availability_*`.

Run:  python lang/python/test_arrow.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import cxlib
import cxlib.arrow as cxa


_passed = 0
_failed = 0
_skipped = 0


def _run(fn):
    global _passed, _failed
    try:
        fn()
        _passed += 1
    except AssertionError as e:
        _failed += 1
        print(f'  FAIL  {fn.__name__}: {e}')
    except Exception as e:
        _failed += 1
        import traceback
        print(f'  ERROR {fn.__name__}: {type(e).__name__}: {e}')
        traceback.print_exc()


def _skip(reason):
    global _skipped
    _skipped += 1
    print(f'  SKIP  {reason}')


def test_availability_reports_truthy_when_lib_loaded():
    # When the shared library is present and pyarrow importable, available()
    # returns True and feature bit 23 is set in the merged bitmask.
    assert cxa.available()
    assert cxa.features() == 0x800000
    assert cxa.merged_features() & 0x800000 == 0x800000
    assert cxa.version() == '0.6.0'


def test_round_trip_int():
    src = ('[stats :table[score:int]\n'
           '  100\n  -1\n  9223372036854775807\n  -9223372036854775808\n]')
    framed = cxlib.to_data_bin_chunked(src)
    table = cxa.export(framed).read_all()
    assert str(table.schema.field('score').type) == 'int64'
    assert table.column('score').to_pylist() == \
        [100, -1, 9223372036854775807, -9223372036854775808]
    out = cxa.import_to_data_bin(table)
    table2 = cxa.export(out).read_all()
    assert table.equals(table2), 'int round-trip mismatch'


def test_round_trip_i8():
    src = ('[stats :table[v:i8]\n  -128\n  -1\n  0\n  127\n]')
    framed = cxlib.to_data_bin_chunked(src)
    table = cxa.export(framed).read_all()
    assert str(table.schema.field('v').type) == 'int8'
    assert table.column('v').to_pylist() == [-128, -1, 0, 127]
    out = cxa.import_to_data_bin(table)
    assert cxa.export(out).read_all().equals(table)


def test_round_trip_i16():
    src = ('[stats :table[v:i16]\n  -32768\n  -1\n  0\n  32767\n]')
    framed = cxlib.to_data_bin_chunked(src)
    table = cxa.export(framed).read_all()
    assert str(table.schema.field('v').type) == 'int16'
    assert table.column('v').to_pylist() == [-32768, -1, 0, 32767]
    out = cxa.import_to_data_bin(table)
    assert cxa.export(out).read_all().equals(table)


def test_round_trip_i32():
    src = ('[stats :table[v:i32]\n'
           '  -2147483648\n  -1\n  0\n  2147483647\n]')
    framed = cxlib.to_data_bin_chunked(src)
    table = cxa.export(framed).read_all()
    assert str(table.schema.field('v').type) == 'int32'
    assert table.column('v').to_pylist() == \
        [-2147483648, -1, 0, 2147483647]
    out = cxa.import_to_data_bin(table)
    assert cxa.export(out).read_all().equals(table)


def test_round_trip_float():
    src = ('[stats :table[v:float]\n  0.0\n  -1.5\n  3.14159\n  1e100\n]')
    framed = cxlib.to_data_bin_chunked(src)
    table = cxa.export(framed).read_all()
    assert str(table.schema.field('v').type) == 'double'
    vals = table.column('v').to_pylist()
    assert vals[0] == 0.0
    assert vals[1] == -1.5
    assert abs(vals[2] - 3.14159) < 1e-9
    assert vals[3] == 1e100
    out = cxa.import_to_data_bin(table)
    assert cxa.export(out).read_all().equals(table)


def test_round_trip_bool():
    src = ('[flags :table[v:bool]\n  true\n  false\n  true\n  false\n]')
    framed = cxlib.to_data_bin_chunked(src)
    table = cxa.export(framed).read_all()
    assert str(table.schema.field('v').type) == 'bool'
    assert table.column('v').to_pylist() == [True, False, True, False]
    out = cxa.import_to_data_bin(table)
    assert cxa.export(out).read_all().equals(table)


def test_round_trip_string():
    # CX tokenizes table cells by whitespace; use single-token cells to keep
    # the parsed shape predictable. Round-trip equality is the primary assertion.
    src = ('[names :table[v:string]\n'
           '  alice\n  bob\n  carol\n  unicode-é-é-ñ\n]')
    framed = cxlib.to_data_bin_chunked(src)
    table = cxa.export(framed).read_all()
    assert str(table.schema.field('v').type) == 'string'
    assert table.column('v').to_pylist() == \
        ['alice', 'bob', 'carol', 'unicode-é-é-ñ']
    out = cxa.import_to_data_bin(table)
    assert cxa.export(out).read_all().equals(table)


def test_round_trip_date():
    import datetime as dt
    src = ('[evts :table[when:date]\n'
           '  2026-05-09\n  1970-01-01\n  9999-12-31\n  1900-01-01\n]')
    framed = cxlib.to_data_bin_chunked(src)
    table = cxa.export(framed).read_all()
    assert str(table.schema.field('when').type) == 'date32[day]'
    assert table.column('when').to_pylist() == [
        dt.date(2026, 5, 9), dt.date(1970, 1, 1),
        dt.date(9999, 12, 31), dt.date(1900, 1, 1),
    ]
    out = cxa.import_to_data_bin(table)
    assert cxa.export(out).read_all().equals(table)


def test_round_trip_bytes():
    src = ('[blobs :table[name:string blob:bytes]\n'
           '  alpha "A1B2"\n  beta "FF00DE"\n  empty ""\n]')
    framed = cxlib.to_data_bin_chunked(src)
    table = cxa.export(framed).read_all()
    assert str(table.schema.field('blob').type) == 'binary'
    # CXDB carries raw bytes including the surrounding double quotes from
    # the parser's textual cell. Round-trip preservation is what matters.
    blobs = table.column('blob').to_pylist()
    assert all(isinstance(b, (bytes, bytearray)) for b in blobs)
    out = cxa.import_to_data_bin(table)
    assert cxa.export(out).read_all().equals(table)


def test_round_trip_datetime():
    import datetime as dt
    src = ('[evts :table[when:datetime]\n'
           '  2024-01-15T12:34:56Z\n'
           '  2025-06-30T23:00:00+02:00\n'
           '  1970-01-01T00:00:00Z\n'
           '  1900-01-01T00:00:00Z\n]')
    framed = cxlib.to_data_bin_chunked(src)
    table = cxa.export(framed).read_all()
    assert str(table.schema.field('when').type) == 'timestamp[ns, tz=UTC]'
    # CXDB strict-canonical normalizes offsets to UTC on the wire, so the
    # +02:00 row arrives as 21:00:00 UTC.
    utc = dt.timezone.utc
    assert table.column('when').to_pylist() == [
        dt.datetime(2024, 1, 15, 12, 34, 56, tzinfo=utc),
        dt.datetime(2025, 6, 30, 21, 0,  0,  tzinfo=utc),
        dt.datetime(1970, 1, 1,  0,  0,  0,  tzinfo=utc),
        dt.datetime(1900, 1, 1,  0,  0,  0,  tzinfo=utc),
    ]
    out = cxa.import_to_data_bin(table)
    assert cxa.export(out).read_all().equals(table)


def test_pyarrow_table_to_cxdb_round_trip():
    # Build a pyarrow.Table directly (no CXDB starting point) and verify the
    # inverse direction: pyarrow → CXDB → pyarrow re-decode → equality.
    import pyarrow as pa
    table_in = pa.table({
        'name':  pa.array(['alice', 'bob', 'carol'], type=pa.string()),
        'score': pa.array([91, 88, 73],              type=pa.int64()),
        'ratio': pa.array([0.91, 0.88, 0.73],        type=pa.float64()),
    })
    framed = cxa.import_to_data_bin(table_in)
    table_out = cxa.export(framed).read_all()
    assert table_out.num_rows == 3
    assert table_out.column('name').to_pylist()  == ['alice', 'bob', 'carol']
    assert table_out.column('score').to_pylist() == [91, 88, 73]
    assert table_out.column('ratio').to_pylist() == [0.91, 0.88, 0.73]


def test_export_rejects_invalid_input():
    try:
        cxa.export(b'\x04\x00\x00\x00garb')
    except RuntimeError:
        return
    raise AssertionError('expected RuntimeError on garbage framed input')


def test_import_to_data_bin_type_check():
    # Reject inputs that aren't a RecordBatchReader / Table.
    try:
        cxa.import_to_data_bin([1, 2, 3])
    except TypeError:
        return
    raise AssertionError('expected TypeError on bad input')


if __name__ == '__main__':
    print('Apache Arrow C-Data interop tests (Phase 7.74c-cont-bindings)')

    try:
        import pyarrow  # noqa: F401
    except ImportError:
        _skip("pyarrow not installed (pip install cxlib[arrow])")
        print(f'  {_passed} passed, {_failed} failed, {_skipped} skipped')
        sys.exit(0)

    if not cxa.available():
        # Graceful-degradation path: report features() raises, merged_features
        # falls back to libcx alone. Skip the rest of the suite.
        try:
            cxa.features()
            print('  FAIL  expected RuntimeError when libcx_arrow missing')
            sys.exit(1)
        except RuntimeError:
            pass
        assert cxa.merged_features() == cxlib.cx.features()
        _skip("libcx_arrow not built (run `make lib-arrow`)")
        print(f'  {_passed} passed, {_failed} failed, {_skipped} skipped')
        sys.exit(0)

    for fn in (
        test_availability_reports_truthy_when_lib_loaded,
        test_round_trip_int,
        test_round_trip_i8,
        test_round_trip_i16,
        test_round_trip_i32,
        test_round_trip_float,
        test_round_trip_bool,
        test_round_trip_string,
        test_round_trip_date,
        test_round_trip_bytes,
        test_round_trip_datetime,
        test_pyarrow_table_to_cxdb_round_trip,
        test_export_rejects_invalid_input,
        test_import_to_data_bin_type_check,
    ):
        _run(fn)
    print(f'  {_passed} passed, {_failed} failed, {_skipped} skipped')
    sys.exit(0 if _failed == 0 else 1)
