#!/usr/bin/env python3
"""
Round-trip tests for the Python data_bin one-shot wrappers
(Phase 7.28 V core; Phase 7.30 Python binding).

Each test exercises a per-format loader (text → CXCol v1 framed bytes)
and the symmetric dumper (framed bytes → text) using the new
xml_to_data_bin / json_to_data_bin / etc. and their reverses.

Run:  python lang/python/test_data_bin_one_shots.py
"""
import struct
import sys, os
from decimal import Decimal
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import cxlib
from cxlib import data_bin

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
    # Frame: [u32 LE size][CXCol ...]
    size = int.from_bytes(framed[:4], 'little')
    assert len(framed) == 4 + size
    assert framed[4:9] == b'CXCol'

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


# ── Native codec: bigint (0x18) / decimal (0x28) — I1 row 16, L48 ────────────
#
# Wire shape for both tags = the string tag's length-prefixed byte payload
# carrying the base-10 IMAGE. decimal is fixed-point only (scale preserved);
# bigint is a base-10 integer string. Host mapping (type-mapping.md):
# 0x18 <-> int, 0x28 <-> decimal.Decimal.

def _frame_value(body: bytes) -> bytes:
    """Hand-build a framed CXCol v1 buffer around a raw value body."""
    payload = b'CXCol' + bytes([0x01, 0x01]) + struct.pack('<I', 64) + b'\x00' + body
    return struct.pack('<I', len(payload)) + payload

def _root_body(framed: bytes) -> bytes:
    """Strip frame + 12-byte header, returning the root value body."""
    size = int.from_bytes(framed[:4], 'little')
    assert len(framed) == 4 + size
    return framed[4 + 12:]

def test_decode_decimal_0x28_preserves_scale():
    image = b'1.10'
    framed = _frame_value(bytes([0x28, len(image)]) + image)
    v = data_bin.decode(framed)
    assert isinstance(v, Decimal), f'expected Decimal, got {type(v).__name__}'
    assert v == Decimal('1.10')
    assert str(v) == '1.10', f'scale lost: {v!r}'   # trailing zero preserved

def test_decode_bigint_0x18_beyond_i64():
    image = b'99999999999999999999999'
    framed = _frame_value(bytes([0x18, len(image)]) + image)
    v = data_bin.decode(framed)
    assert type(v) is int, f'expected int, got {type(v).__name__}'
    assert v == 99999999999999999999999

def test_decode_bigint_0x18_within_i64():
    # Narrowing-within-kind: an in-i64 bigint still rides 0x18 on the
    # wire; the host type is int either way.
    image = b'42'
    framed = _frame_value(bytes([0x18, len(image)]) + image)
    v = data_bin.decode(framed)
    assert type(v) is int
    assert v == 42

def test_encode_big_int_rides_0x18():
    big = 99999999999999999999999
    framed = data_bin.encode(big)
    body = _root_body(framed)
    assert body[0] == 0x18, f'expected bigint tag 0x18, got 0x{body[0]:02x}'
    assert body[2:] == b'99999999999999999999999'
    assert data_bin.decode(framed) == big

def test_encode_int_within_i64_still_rides_int_tags():
    # L20 promotion applies beyond i64 ONLY; in-range ints keep 0x10-0x13.
    framed = data_bin.encode((2**63) - 1)
    assert _root_body(framed)[0] == 0x13
    assert data_bin.decode(framed) == (2**63) - 1

def test_encode_decimal_fixed_point_image():
    framed = data_bin.encode(Decimal('1.10'))
    body = _root_body(framed)
    assert body[0] == 0x28, f'expected decimal tag 0x28, got 0x{body[0]:02x}'
    assert body[2:] == b'1.10', f'scale lost on wire: {body[2:]!r}'
    v = data_bin.decode(framed)
    assert v == Decimal('1.10') and str(v) == '1.10'

def test_encode_decimal_exponent_form_becomes_fixed_point():
    # str(Decimal('1E+2')) == '1E+2' — exponent notation is NOT a legal
    # wire image; the encoder must emit the fixed-point rendering.
    framed = data_bin.encode(Decimal('1E+2'))
    body = _root_body(framed)
    assert body[0] == 0x28
    assert body[2:] == b'100', f'exponent leaked onto the wire: {body[2:]!r}'
    assert data_bin.decode(framed) == Decimal('100')

def test_encode_beyond_i64_no_longer_raises():
    # The pre-I1 encoder raised RuntimeError('... bigint not yet supported
    # in Python encoder') for ints beyond i64. That path is gone (L20).
    for v in (2**63, -(2**63) - 1, 2**200, -(2**200)):
        framed = data_bin.encode(v)
        assert data_bin.decode(framed) == v, f'round-trip failed for {v}'

def test_encode_non_finite_decimal_rejected():
    for bad in (Decimal('NaN'), Decimal('Infinity'), Decimal('-Infinity')):
        try:
            data_bin.encode(bad)
        except RuntimeError:
            pass
        else:
            raise AssertionError(f'{bad!r} must not encode (no wire image)')

def test_engine_round_trip_decimal_bigint():
    # Cross-engine parity: libcx-produced buffers decode to the mapped
    # host types, and Python-encoded buffers restore the CX ascription.
    v = data_bin.decode(cxlib.to_data_bin('[price::decimal 1.10]'))
    assert v == {'price': Decimal('1.10')} and str(v['price']) == '1.10'
    v = data_bin.decode(cxlib.to_data_bin('[n::bigint 99999999999999999999999]'))
    assert v == {'n': 99999999999999999999999} and type(v['n']) is int
    out = cxlib.from_data_bin(data_bin.encode({'price': Decimal('1.10')}))
    assert out == '[price::decimal 1.10]', out
    out = cxlib.from_data_bin(data_bin.encode({'n': 2**80}))
    assert out == '[n::bigint 1208925819614629174706176]', out

def test_bigint_decimal_nest_in_collections():
    value = {'big': 2**80, 'price': Decimal('0.10'), 'xs': [Decimal('2.50'), 2**70]}
    out = data_bin.decode(data_bin.encode(value))
    assert out['big'] == 2**80
    assert str(out['price']) == '0.10'
    assert str(out['xs'][0]) == '2.50'
    assert out['xs'][1] == 2**70



# ── #807(c)/(d) (packet §10 arc-2): the 0x82 declared-name col-spec
# annotation + the datetime-offset transport carriage. Vectors are
# V-emitted (cx --cxcol) framed buffers.

def test_decode_col_spec_declared_name_annotation():
    # [t [table[v::f64 s::string]] 1.5e0 x] — both col-specs carry the
    # 0x82 annotation; the decoder consumes the declared spelling and
    # reads payloads from the real codes.
    framed = bytes.fromhex(
        '350000004358436f6c010140000000005001300174600230017682300366363420'
        '300173823006737472696e673001000000000000f83f0178')
    v = data_bin.decode(framed)
    assert v == {'t': [{'v': 1.5, 's': 'x'}]}, v


def test_decode_datetime_offset_rides_transport():
    # [t [table[w::datetime]] '2026-01-01T23:00:00+02:00'] — the §3.6.1
    # offset_minutes field rides the transport; the local tz surfaces.
    framed = bytes.fromhex(
        '240000004358436f6c0101400000000050013001746001300177320100201fed13b7861878000000')
    v = data_bin.decode(framed)
    dt = v['t'][0]['w']
    assert dt.isoformat() == '2026-01-01T23:00:00+02:00', dt.isoformat()


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
