"""Tests for ID/IDREF resolution per spec/identity.md.

Mirrors the V core conformance/identity.txt cases for the Python binding
accessor surface (`Element.id`, `Attr.is_ref`, `Document.resolve_id()`,
`Document.elements_by_id()`). The fields are populated by the V core
parser and threaded through the v2 ast_bin wire format; the binding
re-emits via `to_cx()` so we also check the round-trip.
"""
from cxlib import parse
from cxlib.ast import Element


def _root(doc):
    return doc.root()


def test_id_declaration_only_round_trips():
    cx_in = "[user #u-1 name=alice]"
    doc = parse(cx_in)
    user = _root(doc)
    assert user.id == "u-1"
    assert doc.to_cx() == cx_in


def test_id_with_anchor_coexists():
    cx_in = "[item &a #u-1 v=42]"
    doc = parse(cx_in)
    item = _root(doc)
    assert item.anchor == "a"
    assert item.id == "u-1"
    assert doc.to_cx() == cx_in


def test_attribute_value_reference_marked_is_ref():
    doc = parse("[users [user #u-1 name=alice] [reviewer assigned-to=@u-1]]")
    reviewer = doc.find_first("reviewer")
    ref_attr = next(a for a in reviewer.attrs if a.name == "assigned-to")
    assert ref_attr.is_ref is True
    assert ref_attr.value == "u-1"


def test_resolve_id_finds_declared_element():
    doc = parse("[users [user #u-1 name=alice] [user #u-2 name=bob]]")
    el = doc.resolve_id("u-1")
    assert el is not None
    assert el.attr("name") == "alice"
    assert doc.resolve_id("u-2").attr("name") == "bob"
    assert doc.resolve_id("u-3") is None


def test_elements_by_id_builds_full_map():
    doc = parse("[a #x v=1] [b #y v=2] [c #z v=3]")
    by_id = doc.elements_by_id()
    assert set(by_id.keys()) == {"x", "y", "z"}
    assert by_id["x"].name == "a"
    assert by_id["y"].name == "b"
    assert by_id["z"].name == "c"


def test_quoted_at_literal_is_not_a_reference():
    cx_in = "[item label='@literal']"
    doc = parse(cx_in)
    item = _root(doc)
    label = next(a for a in item.attrs if a.name == "label")
    assert label.is_ref is False
    assert label.value == "@literal"
    assert doc.to_cx() == cx_in


def test_forward_reference_resolves():
    doc = parse(
        "[users [reviewer assigned-to=@u-1] [user #u-1 name=alice]]"
    )
    user = doc.resolve_id("u-1")
    assert user is not None
    assert user.attr("name") == "alice"


def test_nested_id_and_ref_round_trip():
    cx_in = "[doc\n  [users\n    [user #u-1 name=alice]\n  ]\n  [reviews\n    [review target=@u-1 score=5]\n  ]\n]"
    doc = parse(cx_in)
    user = doc.resolve_id("u-1")
    assert user is not None
    review = doc.find_first("review")
    target = next(a for a in review.attrs if a.name == "target")
    assert target.is_ref is True
    assert target.value == "u-1"


def test_multiple_refs_to_same_id():
    doc = parse(
        "[users [user #u-1 name=alice] "
        "[reviewer assigned-to=@u-1] "
        "[approver checked-by=@u-1]]"
    )
    refs = [a for el in doc.find_all("reviewer") + doc.find_all("approver")
            for a in el.attrs if a.is_ref]
    assert len(refs) == 2
    assert all(r.value == "u-1" for r in refs)
    assert doc.resolve_id("u-1").attr("name") == "alice"


def test_body_ref_survives_ast_bin_round_trip():
    """Phase 7.70 — ast_bin v3 carries body_ref through the V↔binding
    boundary. The field is populated post-parse from the v3 wire bytes,
    not re-detected from text."""
    cx_in = "[doc [section #section-3 [para See [ref @section-3].]]]"
    doc = parse(cx_in)
    section = doc.find_first("section")
    para = section.find_first("para")
    body_ref_node = next(c for c in para.items
                          if isinstance(c, Element) and c.name == "ref")
    assert body_ref_node.body_ref == "section-3"
    assert body_ref_node.attrs == []
    assert body_ref_node.items == []
    # body_ref participates in the binding's local CX-text emit
    assert "[ref @section-3]" in doc.to_cx()


def main():
    import sys, traceback
    tests = [g for n, g in sorted(globals().items()) if n.startswith("test_") and callable(g)]
    passed = 0
    failed = 0
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
