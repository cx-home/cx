"""Tree-mutation helpers used by Document.transform / transform_all.

The CXPath parser/lexer/evaluator/predicate types that previously lived
here were deleted in Phase 4 (CB-5): bindings now thunk to libcx for
expression evaluation via `cx.select_all_paths`. Only the host-language
tree-mutation utilities remain — those are not duplication, they are
Python-level structural editing.

The utilities here are:
  - elem_detached(e):       deep-ish copy so user callbacks can't mutate source.
  - doc_replace_at(d, i):   functional replace of doc.elements[i].
  - elem_replace_item_at:   functional replace of element.items[i].
  - path_copy_element:      Document.transform helper (slash-path semantics).
  - replace_at_doc_path:    path-based replacement used by transform_all.
"""
from __future__ import annotations
from typing import Any, Callable, Optional, Sequence


def elem_detached(e) -> Any:
    """Return a copy of e with independent attrs/items lists so f cannot mutate the source."""
    from .ast import Element, Attr
    return Element(
        name=e.name,
        anchor=e.anchor,
        merge=e.merge,
        data_type=e.data_type,
        attrs=[Attr(a.name, a.value, a.data_type) for a in e.attrs],
        items=list(e.items),
    )


def doc_replace_at(d, idx: int, el) -> Any:
    from .ast import Document
    return Document(
        elements=[el if i == idx else n for i, n in enumerate(d.elements)],
        prolog=d.prolog,
        doctype=d.doctype,
    )


def elem_replace_item_at(e, idx: int, child) -> Any:
    from .ast import Element
    return Element(
        name=e.name,
        anchor=e.anchor,
        merge=e.merge,
        data_type=e.data_type,
        attrs=e.attrs,
        items=[child if i == idx else n for i, n in enumerate(e.items)],
    )


def path_copy_element(e, parts: list, f: Callable) -> Optional[Any]:
    """Returns a new Element with f applied at parts[...], or None if path not found."""
    from .ast import Element
    for i, item in enumerate(e.items):
        if isinstance(item, Element) and item.name == parts[0]:
            if len(parts) == 1:
                return elem_replace_item_at(e, i, f(elem_detached(item)))
            updated = path_copy_element(item, parts[1:], f)
            if updated is not None:
                return elem_replace_item_at(e, i, updated)
            return None
    return None


# ── Path-based replacement (CB-5 / Phase 4) ──────────────────────────────────

def navigate_doc_path(doc, path: Sequence[int]):
    """Walk `path` (indices into Document.elements then Element.items)
    and return the element at that position. Returns None if any step is
    out-of-bounds or hits a non-Element item.
    """
    from .ast import Element
    if not path:
        return None
    if path[0] >= len(doc.elements):
        return None
    node = doc.elements[path[0]]
    for k in path[1:]:
        if not isinstance(node, Element):
            return None
        if k >= len(node.items):
            return None
        node = node.items[k]
    return node if isinstance(node, Element) else None


def replace_at_doc_path(doc, path: Sequence[int], new_elem) -> Any:
    """Return a new Document with the element at `path` replaced by
    `new_elem`. Original document is unchanged (functional update —
    only the spine along `path` is rebuilt).
    """
    from .ast import Document
    if not path:
        raise ValueError("replace_at_doc_path: empty path")
    new_elements = list(doc.elements)
    if len(path) == 1:
        new_elements[path[0]] = new_elem
    else:
        top = new_elements[path[0]]
        new_elements[path[0]] = _replace_in_element(top, path[1:], new_elem)
    return Document(
        elements=new_elements,
        prolog=doc.prolog,
        doctype=doc.doctype,
    )


def _replace_in_element(el, path: Sequence[int], new_elem):
    from .ast import Element
    if not path:
        return new_elem
    new_items = list(el.items)
    if len(path) == 1:
        new_items[path[0]] = new_elem
    else:
        child = new_items[path[0]]
        new_items[path[0]] = _replace_in_element(child, path[1:], new_elem)
    return Element(
        name=el.name,
        anchor=el.anchor,
        merge=el.merge,
        data_type=el.data_type,
        attrs=list(el.attrs),
        items=new_items,
    )
