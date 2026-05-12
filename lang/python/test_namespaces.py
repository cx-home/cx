"""Tests for namespace resolution per ADR 0002 / spec/namespaces.md.

Mirrors the V core conformance/namespaces.txt cases for the Python binding
accessor surface (`Element.local_name()` / `Element.namespace_uri()` /
`Attr.local_name()` / `Attr.namespace_uri()`). Resolution is performed
in-language via `cxlib.ast.resolve_namespaces`, which the parse entry
points (`parse`, `parse_xml`, `parse_json`, etc.) call automatically.
"""
from cxlib import parse
from cxlib.ast import (
    Element, Attr, resolve_namespaces,
    XML_NAMESPACE_URI, CX_NAMESPACE_URI,
)


def _root(doc):
    return doc.root()


def test_default_namespace_inherits_to_descendants():
    doc = parse("[html xmlns=http://www.w3.org/1999/xhtml [body [p Hi]]]")
    html = _root(doc)
    assert html.local_name() == "html"
    assert html.namespace_uri() == "http://www.w3.org/1999/xhtml"
    body = html.get("body")
    assert body.namespace_uri() == "http://www.w3.org/1999/xhtml"
    assert body.local_name() == "body"


def test_default_namespace_does_not_apply_to_attrs():
    doc = parse("[html xmlns=urn:x id=top body]")
    html = _root(doc)
    id_attr = next(a for a in html.attrs if a.name == "id")
    assert id_attr.namespace_uri() is None
    assert id_attr.local_name() == "id"


def test_prefixed_element_resolves():
    doc = parse(
        "[doc xmlns:dc=http://purl.org/dc/elements/1.1/ [dc:title Hello]]"
    )
    title = _root(doc).get("dc:title")
    assert title.local_name() == "title"
    assert title.namespace_uri() == "http://purl.org/dc/elements/1.1/"


def test_prefixed_attribute_resolves():
    doc = parse(
        "[doc xmlns:xl=http://www.w3.org/1999/xlink [link xl:href=https://example.com Click]]"
    )
    link = _root(doc).get("link")
    href = next(a for a in link.attrs if a.name == "xl:href")
    assert href.local_name() == "href"
    assert href.namespace_uri() == "http://www.w3.org/1999/xlink"


def test_reserved_xml_prefix_resolves_without_declaration():
    doc = parse("[doc xml:base=https://example.com content]")
    base = next(a for a in _root(doc).attrs if a.name == "xml:base")
    assert base.namespace_uri() == XML_NAMESPACE_URI
    assert base.local_name() == "base"


def test_reserved_cx_prefix_resolves_without_declaration():
    doc = parse("[doc [cx:meta key=value]]")
    meta = _root(doc).get("cx:meta")
    assert meta.namespace_uri() == CX_NAMESPACE_URI
    assert meta.local_name() == "meta"


def test_undeclared_prefix_passes_through_unbound():
    doc = parse("[doc [foo:bar baz]]")
    bar = _root(doc).get("foo:bar")
    assert bar.local_name() == "bar"
    assert bar.namespace_uri() is None


def test_redeclaration_in_subtree_overrides_default():
    doc = parse("""
[html xmlns=http://www.w3.org/1999/xhtml
  [body
    [svg xmlns=http://www.w3.org/2000/svg
      [circle r=10]
    ]
  ]
]
""".strip())
    html = _root(doc)
    body = html.get("body")
    svg = body.get("svg")
    circle = svg.get("circle")
    assert html.namespace_uri() == "http://www.w3.org/1999/xhtml"
    assert body.namespace_uri() == "http://www.w3.org/1999/xhtml"
    assert svg.namespace_uri() == "http://www.w3.org/2000/svg"
    assert circle.namespace_uri() == "http://www.w3.org/2000/svg"


def test_xmlns_undeclaration_with_empty_uri():
    doc = parse("[outer xmlns=urn:x [inner xmlns='' [child x=1]]]")
    outer = _root(doc)
    inner = outer.get("inner")
    child = inner.get("child")
    assert outer.namespace_uri() == "urn:x"
    assert inner.namespace_uri() is None
    assert child.namespace_uri() is None


def test_resolve_namespaces_is_idempotent():
    doc = parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ [dc:title Hi]]")
    title_first = _root(doc).get("dc:title").namespace_uri()
    resolve_namespaces(doc)
    resolve_namespaces(doc)
    title_second = _root(doc).get("dc:title").namespace_uri()
    assert title_first == title_second == "http://purl.org/dc/elements/1.1/"


def test_xmlns_declaration_attrs_have_no_resolved_uri():
    doc = parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ body]")
    decl = next(a for a in _root(doc).attrs if a.name == "xmlns:dc")
    assert decl.namespace_uri() is None
    assert decl.local_name() == "dc"


if __name__ == "__main__":
    import sys
    tests = [
        test_default_namespace_inherits_to_descendants,
        test_default_namespace_does_not_apply_to_attrs,
        test_prefixed_element_resolves,
        test_prefixed_attribute_resolves,
        test_reserved_xml_prefix_resolves_without_declaration,
        test_reserved_cx_prefix_resolves_without_declaration,
        test_undeclared_prefix_passes_through_unbound,
        test_redeclaration_in_subtree_overrides_default,
        test_xmlns_undeclaration_with_empty_uri,
        test_resolve_namespaces_is_idempotent,
        test_xmlns_declaration_attrs_have_no_resolved_uri,
    ]
    failures = 0
    for t in tests:
        try:
            t()
            print(f"ok  {t.__name__}")
        except Exception as e:
            print(f"FAIL {t.__name__}: {e!r}")
            failures += 1
    print(f"\n{len(tests) - failures}/{len(tests)} passed")
    sys.exit(1 if failures else 0)
