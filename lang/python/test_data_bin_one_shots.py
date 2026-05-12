#!/usr/bin/env python3
"""
Round-trip tests for the Python data_bin one-shot wrappers
(Phase 7.28 V core; Phase 7.30 Python binding).

Each test exercises a per-format loader (text → CXDB v1 framed bytes)
and the symmetric dumper (framed bytes → text) using the new
xml_to_data_bin / json_to_data_bin / etc. and their reverses.

Run:  python lang/python/test_data_bin_one_shots.py
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


# ── XML one-shot ─────────────────────────────────────────────────────────────

def test_xml_to_data_bin_returns_framed_bytes():
    framed = cxlib.xml_to_data_bin('<server><host>localhost</host><port>8080</port></server>')
    assert isinstance(framed, bytes)
    assert len(framed) > 8
    # Frame: [u32 LE size][CXDB ...]
    size = int.from_bytes(framed[:4], 'little')
    assert len(framed) == 4 + size
    assert framed[4:8] == b'CXDB'

def test_xml_round_trip_through_data_bin():
    src = '<server><host>localhost</host><port>8080</port></server>'
    framed = cxlib.xml_to_data_bin(src)
    out = cxlib.data_bin_to_xml(framed)
    assert 'server' in out
    assert 'localhost' in out
    assert '8080' in out


# ── JSON one-shot ────────────────────────────────────────────────────────────

def test_json_round_trip_through_data_bin():
    src = '{"name": "alice", "id": 1}'
    framed = cxlib.json_to_data_bin(src)
    out = cxlib.data_bin_to_json(framed)
    assert 'alice' in out
    assert '1' in out


# ── YAML one-shot ────────────────────────────────────────────────────────────

def test_yaml_round_trip_through_data_bin():
    src = 'name: alice\nid: 1\n'
    framed = cxlib.yaml_to_data_bin(src)
    out = cxlib.data_bin_to_yaml(framed)
    assert 'alice' in out


# ── TOML one-shot ────────────────────────────────────────────────────────────

def test_toml_round_trip_through_data_bin():
    src = 'name = "alice"\nid = 1\n'
    framed = cxlib.toml_to_data_bin(src)
    out = cxlib.data_bin_to_toml(framed)
    assert 'alice' in out


# ── Markdown one-shot ────────────────────────────────────────────────────────

def test_md_round_trip_through_data_bin():
    src = '# Title\n\nA paragraph.\n'
    framed = cxlib.md_to_data_bin(src)
    out = cxlib.data_bin_to_md(framed)
    assert 'Title' in out


# ── Cross-format compositions ────────────────────────────────────────────────

def test_xml_to_data_bin_to_json():
    framed = cxlib.xml_to_data_bin('<user id="1" name="alice"/>')
    out = cxlib.data_bin_to_json(framed)
    assert 'alice' in out
    assert '1' in out

def test_json_to_data_bin_to_yaml():
    framed = cxlib.json_to_data_bin('{"name": "alice", "active": true}')
    out = cxlib.data_bin_to_yaml(framed)
    assert 'alice' in out

def test_toml_to_data_bin_to_xml():
    framed = cxlib.toml_to_data_bin('host = "localhost"\nport = 8080\n')
    out = cxlib.data_bin_to_xml(framed)
    assert 'localhost' in out
    assert '8080' in out


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
    print(f'python/test_data_bin_one_shots.py: {_passed} passed, {_failed} failed  [{status}]')
    sys.exit(0 if _failed == 0 else 1)
