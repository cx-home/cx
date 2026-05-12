#!/usr/bin/env python3
"""
Round-trip tests for the Python delimited (CSV/TSV/PSV) wrappers
(Phase 7.67 V core; Phase 7.68 Python binding).

Mirrors the eight-case shape of vcx/tests/v34_delimited_test.v.

Run:  python lang/python/test_delimited.py
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import cxlib

_passed = 0
_failed = 0

def _run(fn):
    global _passed, _failed
    try:
        fn()
        _passed += 1
    except AssertionError as e:
        _failed += 1
        print(f'  FAIL {fn.__name__}: {e}')
    except Exception as e:
        _failed += 1
        print(f'  ERR  {fn.__name__}: {type(e).__name__}: {e}')


# ── Emit ─────────────────────────────────────────────────────────────────────

def test_emit_table_direct():
    src = '[users :table[name:string age:int active:bool]\n  alice 30 true\n  bob 25 false\n]'
    out = cxlib.to_csv(src)
    assert out == 'name,age,active\r\nalice,30,true\r\nbob,25,false\r\n', repr(out)

def test_emit_repeated_row():
    src = '[users\n  [user id=1 name=alice +admin]\n  [user id=2 name=bob]\n  [user id=3 name=carol +admin]\n]'
    out = cxlib.to_csv(src)
    assert out == 'id,name,admin\r\n1,alice,true\r\n2,bob,\r\n3,carol,true\r\n', repr(out)

def test_emit_dotted_path():
    src = '[config\n  [server host=localhost port=8080 +tls]\n  [logging level=info format=json]\n]'
    out = cxlib.to_csv(src)
    expected = 'server.host,server.port,server.tls,logging.level,logging.format\r\nlocalhost,8080,true,info,json\r\n'
    assert out == expected, repr(out)

def test_emit_tsv():
    src = '[t :table[a b c]\n  x y z\n]'
    out = cxlib.to_tsv(src)
    assert out == 'a\tb\tc\r\nx\ty\tz\r\n', repr(out)

def test_emit_psv():
    src = '[t :table[a b]\n  x y\n]'
    out = cxlib.to_psv(src)
    assert out == 'a|b\r\nx|y\r\n', repr(out)


# ── Parse ────────────────────────────────────────────────────────────────────

def test_parse_csv_basic_autotypes():
    csv_in = 'name,age,active\nalice,30,true\nbob,25,false\n'
    out = cxlib.from_csv(csv_in)
    expected = '[table :table[name age:int active:bool]\n  alice 30 true\n  bob 25 false\n]'
    assert out == expected, repr(out)

def test_parse_quoted_stays_string():
    csv_in = 'name,age\nalice,"30"\nbob,"25"\n'
    out = cxlib.from_csv(csv_in)
    expected = '[table :table[name age]\n  alice 30\n  bob 25\n]'
    assert out == expected, repr(out)

def test_parse_empty_cell_is_null():
    csv_in = 'name,age\nalice,30\nbob,\n'
    out = cxlib.from_csv(csv_in)
    expected = '[table :table[name age:int]\n  alice 30\n  bob null\n]'
    assert out == expected, repr(out)


# ── Arbitrary delimiter + data_bin one-shots ─────────────────────────────────

def test_to_delimited_arbitrary():
    src = '[t :table[a b]\n  x y\n]'
    out = cxlib.to_delimited(src, ';')
    assert out == 'a;b\r\nx;y\r\n', repr(out)

def test_csv_to_data_bin_round_trip():
    framed = cxlib.csv_to_data_bin('name,age\nalice,30\nbob,25\n')
    assert isinstance(framed, bytes)
    assert framed[4:8] == b'CXDB'
    out = cxlib.data_bin_to_csv(framed)
    assert out == 'name,age\r\nalice,30\r\nbob,25\r\n', repr(out)

def test_tsv_to_data_bin_round_trip():
    framed = cxlib.tsv_to_data_bin('a\tb\nx\ty\n')
    out = cxlib.data_bin_to_tsv(framed)
    assert out == 'a\tb\r\nx\ty\r\n', repr(out)

def test_psv_to_data_bin_round_trip():
    framed = cxlib.psv_to_data_bin('a|b\nx|y\n')
    out = cxlib.data_bin_to_psv(framed)
    assert out == 'a|b\r\nx|y\r\n', repr(out)


# ── main ──────────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    module = sys.modules[__name__]
    fns = sorted(
        [v for k, v in vars(module).items() if k.startswith('test_') and callable(v)],
        key=lambda f: f.__code__.co_firstlineno,
    )
    for fn in fns:
        _run(fn)
    total = _passed + _failed
    status = 'OK' if _failed == 0 else 'FAILED'
    print(f'python/test_delimited.py: {_passed} passed, {_failed} failed  [{status}]')
    sys.exit(0 if _failed == 0 else 1)
