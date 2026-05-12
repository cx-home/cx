"""Tests for the ID/IDREF C ABI surface (cx_id_lookup / cx_resolve_ref /
cx_node_id) per ADR 0003 / Phase 7.65. The Document-level resolve_id /
elements_by_id surface is already covered by test_identity.py; these
tests exercise the stateless string-in/string-out C ABI variants.
"""
import json
from cxlib.cx import id_lookup, resolve_ref, node_id


DOC = (
    "[users\n"
    "  [user #u-1 name=alice]\n"
    "  [user #u-2 name=bob]\n"
    "  [reviewer assigned-to=@u-1]\n"
    "]"
)


def test_id_lookup_returns_ast_json_for_declared_id():
    out = id_lookup(DOC, "u-1")
    assert out is not None
    payload = json.loads(out)
    assert payload["type"] == "Element"
    assert payload["name"] == "user"
    assert payload["id"] == "u-1"


def test_id_lookup_missing_returns_none():
    assert id_lookup(DOC, "does-not-exist") is None


def test_resolve_ref_matches_id_lookup():
    a = id_lookup(DOC, "u-2")
    b = resolve_ref(DOC, "u-2")
    assert a == b


def test_node_id_returns_id_for_id_bearing_element():
    assert node_id(DOC, "//user") == "u-1"


def test_node_id_empty_for_non_id_bearing_element():
    assert node_id(DOC, "//reviewer") is None


def main():
    import sys, traceback
    tests = [g for n, g in sorted(globals().items()) if n.startswith("test_") and callable(g)]
    passed = failed = 0
    for t in tests:
        try:
            t()
            print(f"ok  {t.__name__}")
            passed += 1
        except Exception:
            traceback.print_exc()
            print(f"FAIL {t.__name__}")
            failed += 1
    print(f"\n{passed}/{passed + failed} passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
