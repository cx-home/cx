#!/usr/bin/env python3
"""
Streaming Table API tests for lang/python/cxlib (Phase 7.74b).

Mirrors the V core test (vcx/tests/v34_streaming_table_test.v):
  - bytes-mode round-trip: chunked emit → reader → writer → re-decode.
  - fd-mode round-trip via temp file.
  - cx_to_data_bin_chunked one-shot exercises the chunked-table path.

Run:  python lang/python/test_streaming_table.py
"""
import os
import sys
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import cxlib

SIX_ROW_INPUT = (
    '[points [table[name::string score::i32]]\n'
    '  alice 91\n'
    '  bob 88\n'
    '  carol 73\n'
    '  dave 95\n'
    '  eve 84\n'
    '  frank 60\n'
    ']'
)

_passed = 0
_failed = 0

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


def test_to_data_bin_chunked_round_trip():
    framed = cxlib.to_data_bin_chunked(SIX_ROW_INPUT)
    assert isinstance(framed, bytes) and len(framed) > 4
    cx_text = cxlib.from_data_bin(framed)
    assert 'alice' in cx_text and 'frank' in cx_text


def test_streaming_table_bytes_round_trip():
    framed = cxlib.to_data_bin_chunked(SIX_ROW_INPUT)
    with cxlib.TableReader(framed) as r:
        schema = r.schema()
        groups = list(r)
    assert len(groups) >= 1, f'no row groups; got {len(groups)}'
    with cxlib.TableWriter(schema) as w:
        for g in groups:
            w.emit(g)
        out = w.close_get_bytes()
    assert isinstance(out, bytes) and len(out) > 4
    cx_text = cxlib.from_data_bin(out)
    # The writer drops the outer element name (col-spec exchange normalizes
    # to 'table'), so we compare content rather than byte-equality.
    assert 'alice' in cx_text, cx_text
    assert 'frank' in cx_text, cx_text


def test_streaming_table_fd_round_trip():
    framed = cxlib.to_data_bin_chunked(SIX_ROW_INPUT)
    with cxlib.TableReader(framed) as r:
        schema = r.schema()
        groups = list(r)

    fd_path = tempfile.mktemp(prefix='cx_streaming_table_py_', suffix='.cxcol')
    wfd = os.open(fd_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o644)
    try:
        with cxlib.TableWriter(schema, fd=wfd) as w:
            for g in groups:
                w.emit(g)
        # close() flushes end-of-table; then close the OS fd.
    finally:
        os.close(wfd)

    rfd = os.open(fd_path, os.O_RDONLY)
    try:
        with cxlib.TableReader(fd=rfd) as r:
            roundtrip_schema = r.schema()
            roundtrip_groups = list(r)
    finally:
        os.close(rfd)
        os.unlink(fd_path)

    assert roundtrip_schema == schema, 'fd schema drift'
    assert len(roundtrip_groups) == len(groups), \
        f'fd group count drift {len(roundtrip_groups)} vs {len(groups)}'


def test_reader_invalid_input_errors():
    try:
        with cxlib.TableReader(b'\x04\x00\x00\x00garb'):
            pass
    except RuntimeError:
        return
    raise AssertionError('expected RuntimeError on invalid framed buffer')


if __name__ == '__main__':
    print('Streaming Table tests (Phase 7.74b)')
    for fn in (
        test_to_data_bin_chunked_round_trip,
        test_streaming_table_bytes_round_trip,
        test_streaming_table_fd_round_trip,
        test_reader_invalid_input_errors,
    ):
        _run(fn)
    print(f'  {_passed} passed, {_failed} failed')
    sys.exit(0 if _failed == 0 else 1)
