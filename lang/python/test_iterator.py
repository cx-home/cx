"""Iterator wire-format round-trip tests for the Python binding.

Covers (Iterator wire format, tag 0x16, cap bit 37)
 (Iterator value kind, single-use, identity
equality). W3f scope: synthetic IteratorNode round-trip via ast_bin
encoder/decoder. True lazy-pull via a C ABI `cx_iterator_pull` export
lands in a follow-on ADR; this milestone covers wire transport +
binding-side Iterator type surface.

The W3c renderer (V core) materialises iterators at the host emit
boundary — i.e. `cxlib.eval_code` returns a rendered string, never an
IteratorNode directly. This test exercises the lower-level ast_bin
codec where Iterator values are observable as a transport between
CX-aware consumers (cxbin payloads, persisted caches).
"""
from cxlib import (
    IteratorNode, iter_kind_name,
    ITER_RANGE, ITER_MAP, ITER_FILTER, ITER_TAKE, ITER_REDUCE,
)
from cxlib.ast import Document, Scalar, EvalDirective, Attr
from cxlib.binary import encode_ast, decode_ast


# ── construction + identity ────────────────────────────────────

def test_iterator_construction_defaults():
    it = IteratorNode(ITER_RANGE, [Scalar('int', 0), Scalar('int', 10), Scalar('int', 1)])
    assert it.source_kind == ITER_RANGE
    assert it.kind_name == 'iter_range'
    assert len(it.source_args) == 3
    assert it.single_use is False
    assert it.materialize() == [] # no memo populated


def test_iterator_identity_equality_oq4():
    """identity-only equality. Same shape ≠ same iterator."""
    a = IteratorNode(ITER_RANGE, [Scalar('int', 0), Scalar('int', 3)])
    b = IteratorNode(ITER_RANGE, [Scalar('int', 0), Scalar('int', 3)])
    assert a == a
    assert a != b
    assert hash(a) == hash(a)  # hashable + stable per instance


def test_iterator_single_use_rewalk_raises():
    """single-use iterator raises on second walk."""
    it = IteratorNode(ITER_RANGE, [], single_use=True,
                      memo=[Scalar('int', 1), Scalar('int', 2)])
    out = list(iter(it))
    assert len(out) == 2
    try:
        list(iter(it))
    except RuntimeError as e:
        assert 'single-use' in str(e)
        assert 'CXER0105' in str(e)
    else:
        raise AssertionError('expected RuntimeError on single-use re-walk')


def test_iterator_multi_use_rewalk_ok():
    """Default iterators (single_use=False) can be re-walked."""
    it = IteratorNode(ITER_RANGE, [], memo=[Scalar('int', 1), Scalar('int', 2)])
    out1 = list(iter(it))
    out2 = list(iter(it))
    assert out1 == out2
    assert len(out1) == 2


# ── ast_bin round-trip ─────────────────────────────────────────────

def _wrap_doc(node):
    """Wrap a single node in a minimal Document for ast_bin round-trip."""
    return Document(elements=[node])


def test_iterator_node_roundtrip_range():
    """Round-trip iter_range with three int source args."""
    src = IteratorNode(ITER_RANGE, [
        Scalar('int', 0), Scalar('int', 10), Scalar('int', 2),
    ])
    doc = _wrap_doc(src)
    decoded = decode_ast(encode_ast(doc)[4:])  # strip [u32 size] frame
    out = decoded.elements[0]
    assert isinstance(out, IteratorNode)
    assert out.source_kind == ITER_RANGE
    assert out.kind_name == 'iter_range'
    assert len(out.source_args) == 3
    assert all(isinstance(a, Scalar) for a in out.source_args)
    assert [a.value for a in out.source_args] == [0, 10, 2]
    # decoded iterator starts fresh; memo NOT preserved.
    assert out.materialize() == []
    # identity NOT preserved across the wire.
    assert out != src


def test_iterator_node_roundtrip_single_use_flag():
    """`single_use` byte must round-trip verbatim."""
    src = IteratorNode(ITER_MAP, [Scalar('int', 1)], single_use=True)
    decoded = decode_ast(encode_ast(_wrap_doc(src))[4:])
    out = decoded.elements[0]
    assert isinstance(out, IteratorNode)
    assert out.single_use is True
    assert out.source_kind == ITER_MAP


def test_iterator_node_roundtrip_nested_eval_directive_closure():
    """combinator slot-1 closure is an EvalDirective and
    round-trips through ast_bin via the existing tag 0x0E. Synthetic
    iter_map with [src_iter, closure] source_args."""
    inner_iter = IteratorNode(ITER_RANGE, [Scalar('int', 0), Scalar('int', 3)])
    closure = EvalDirective(
        name='fn',
        attrs=[Attr('x', 'x', None)],
        items=[Scalar('int', 42)],
    )
    src = IteratorNode(ITER_MAP, [inner_iter, closure])
    decoded = decode_ast(encode_ast(_wrap_doc(src))[4:])
    out = decoded.elements[0]
    assert isinstance(out, IteratorNode)
    assert out.source_kind == ITER_MAP
    assert len(out.source_args) == 2
    # Nested iterator round-trip (recursive encoding).
    nested = out.source_args[0]
    assert isinstance(nested, IteratorNode)
    assert nested.source_kind == ITER_RANGE
    # Closure round-trip via tag 0x0E.
    assert isinstance(out.source_args[1], EvalDirective)
    assert out.source_args[1].name == 'fn'


def test_iterator_node_roundtrip_all_w3a_w3c_kinds():
    """All W3a/W3c source kinds (iter_range … iter_group_by) and the
    reserved iter_reduce slot must round-trip. The
    v0.8.0-permissible ordinals are enumerated by the iterator wire
    format."""
    for kind in range(1, ITER_REDUCE + 1):
        src = IteratorNode(kind, [Scalar('int', kind)])
        decoded = decode_ast(encode_ast(_wrap_doc(src))[4:])
        out = decoded.elements[0]
        assert isinstance(out, IteratorNode), f'kind {kind} ({iter_kind_name(kind)})'
        assert out.source_kind == kind, f'kind {kind} mismatch'


# ── error path ─────────────────────────────────────────────

def test_iterator_decode_rejects_unknown_kind_ordinal():
    """decoder rejects ordinals above the current enum
    range. Hand-craft a buffer with kind=0xFF to verify the guard."""
    import struct
    # ast_bin v5 envelope: version + 0 prolog + 1 elements
    buf = bytearray()
    buf.append(0x05)               # version
    buf += struct.pack('<H', 0)    # prolog count
    buf += struct.pack('<H', 1)    # elements count
    buf.append(0x16)               # Iterator tag
    buf.append(0xFF)               # bogus source_kind ordinal
    buf.append(0)                  # single_use
    buf += struct.pack('<H', 0)    # source_args_count
    try:
        decode_ast(bytes(buf))
    except ValueError as e:
        assert 'IteratorSourceKind' in str(e)
        assert '255' in str(e) or '0xFF' in str(e).upper()
    else:
        raise AssertionError('expected ValueError on unknown ordinal')


if __name__ == '__main__':
    import sys
    funcs = [v for k, v in list(globals().items()) if k.startswith('test_')]
    failed = 0
    for fn in funcs:
        try:
            fn()
            print(f'  ok  {fn.__name__}')
        except Exception as e:
            failed += 1
            print(f'  FAIL {fn.__name__}: {type(e).__name__}: {e}')
    if failed:
        print(f'\n{failed} / {len(funcs)} tests failed')
        sys.exit(1)
    print(f'\nall {len(funcs)} tests passed')
