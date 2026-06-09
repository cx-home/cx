"""v0.8.0 Layer-2 Pythonic idioms — opt-in sugar over the Layer-1 surface.

Per `spec/bindings.md` §3.1, Layer 2 wraps Layer 1 with host-idiomatic
conveniences.  Every Layer-2 expression has a **single, documented**
Layer-1 desugaring; `explain(expr)` returns it as a string.

Importing from `cxlib.idioms` is OPTIONAL — Layer-1 is the byte-identical
cross-binding contract and lives at `cxlib.code.Doc`.  Layer-2 is
strictly additive sugar; it never replaces or modifies Layer-1
semantics.

Examples
--------

    from cxlib.idioms import Doc

    doc = Doc.parse(open("users.cx", "rb").read())

    # Subscript with CXPath — desugars to Layer-1 `select_all`.
    active = doc["//user[@active=true]"]
    # ≡ doc.select_all("//user[@active=true]")

    # Division-operator iterator — desugars to `select_all`.
    for email in doc / "//user/@email":
        print(email)
    # ≡ for email in doc.select_all("//user/@email"):

    # Subscript-assignment desugars to `modify` + Set.
    new_doc = doc.clone()
    new_doc["//user[@id=1]/@name"] = "Alice"
    # ≡ new_doc = new_doc.modify("//user[@id=1]/@name", '[set "Alice"]')

    # `explain(...)` returns the desugaring for any Layer-2 expression.
    explain(doc / "//user") == 'doc.select_all("//user")'

Wasm-blocked items deferred
---------------------------

The Layer-2 surface specified in `spec/bindings.md` §3.1 includes
generator-style iteration plus list comprehensions over Nodes.  The
comprehension path requires CXPath-from-AST inference at host-language
level and ships in a later phase; the iterator/subscript pair landed
here covers the common path.
"""
from __future__ import annotations

from typing import Any, Iterator, Optional

from . import code as _code
from .code import Doc as _BaseDoc
from .code import Node


__all__ = ["Doc", "Node", "explain"]


class Doc(_BaseDoc):
    """`cxlib.code.Doc` plus Pythonic dunder sugar.

    Every dunder method documents its Layer-1 desugaring inline so
    `cxlib.idioms.explain` can read it back at runtime.
    """

    __slots__ = ()

    # `doc["//user[...]"]` ≡ `doc.select_all("//user[...]")`.
    def __getitem__(self, cxpath: str) -> list[Node]:
        if not isinstance(cxpath, str):
            raise TypeError(
                f"Doc[...] expects a CXPath string, got {type(cxpath).__name__}"
            )
        return self.select_all(cxpath)

    # `doc["//path"] = "value"` ≡ `doc.modify("//path", '[set "value"]')`.
    # Mutates in place — Layer-2 sugar over the Layer-1 pure-functional
    # `modify` (we swap out the underlying Document atomically).
    def __setitem__(self, cxpath: str, value: Any) -> None:
        if not isinstance(cxpath, str):
            raise TypeError(
                f"Doc[...] = ... expects a CXPath string, got {type(cxpath).__name__}"
            )
        action = f'[set {_format_value(value)}]'
        new_doc = self.modify(cxpath, action)
        # Swap the underlying state — preserves identity semantics for
        # in-place subscript-assign.  Layer-1 callers who want pure-
        # functional update use `Doc.modify` directly.
        # Bypass __slots__ + immutable façade by writing through the
        # parent's slot names.
        object.__setattr__(self, "_bytes", new_doc.bytes())
        object.__setattr__(self, "_doc", new_doc.document)

    # `doc / "//user"` ≡ iterator over `doc.select_all("//user")`.
    # Returns a generator so the consumer can `for x in doc / "//y":`.
    def __truediv__(self, cxpath: str) -> Iterator[Node]:
        if not isinstance(cxpath, str):
            raise TypeError(
                f"Doc / ... expects a CXPath string, got {type(cxpath).__name__}"
            )
        return iter(self.select_all(cxpath))

    # `iter(doc)` ≡ iterator over the document's root-level children
    # (NOT a CXPath query — Python-idiomatic "iterate over the
    # document").  Desugaring: `doc.root().children()` when the root is
    # an element, else an empty iterator.
    def __iter__(self) -> Iterator[Node]:
        root = self.root()
        if root is None:
            return iter(())
        return iter(root.children())

    def __contains__(self, cxpath: str) -> bool:
        """``"//user" in doc`` ≡ ``len(doc.select_all("//user")) > 0``."""
        if not isinstance(cxpath, str):
            return False
        return bool(self.select_all(cxpath))

    # Layer-2 conveniences with no dunder hook.
    def clone(self) -> "Doc":
        """Return an independent Doc sharing no mutable state with the
        receiver.  ≡ ``Doc.parse(self.bytes())``."""
        return Doc.parse(self.bytes())


def _format_value(value: Any) -> str:
    """Render a Python value as CX literal text for ``[set V]`` actions.

    Strings are double-quoted (any embedded `"` is JSON-escaped); ints,
    floats, bools, and None map to their CX surface forms.  Other types
    raise ``TypeError`` — Layer-2 deliberately stays narrow so the
    desugaring is unambiguous.
    """
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        # Minimal CX-string escape: backslash + double-quote.
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'
    raise TypeError(
        f"cxlib.idioms: unsupported value type {type(value).__name__} for '[set]' — "
        f"Layer-2 sugar supports None/bool/int/float/str only.  Drop down "
        f"to Layer-1 `Doc.modify(focus, action)` for richer shapes."
    )


# ── explain() — read back the Layer-1 desugaring ────────────────────────────
#
# Per spec/bindings.md §3.1: `cxlib.idioms.explain(expr)` returns the
# equivalent Layer-1 call for any Layer-2 expression.  We can't
# introspect arbitrary Python expressions, so the public signature
# accepts a (doc, op, *args) triple — used by fixtures + LSP hovers.

def explain(*args: Any) -> str:
    """Return the Layer-1 desugaring for a Layer-2 operation.

    Calling conventions:

        explain(doc, "getitem", cxpath)        → 'doc.select_all(cxpath)'
        explain(doc, "setitem", cxpath, value) → 'doc.modify(cxpath, "[set V]")'
        explain(doc, "truediv", cxpath)        → 'iter(doc.select_all(cxpath))'
        explain(doc, "iter")                   → 'doc.root().children()'
        explain(doc, "contains", cxpath)       → 'bool(doc.select_all(cxpath))'
    """
    if len(args) < 2:
        raise TypeError("explain(doc, op, *args) requires at least 2 positional args")
    _doc, op, *rest = args
    if op == "getitem":
        (cxpath,) = rest
        return f'doc.select_all({cxpath!r})'
    if op == "setitem":
        cxpath, value = rest
        return f'doc.modify({cxpath!r}, "[set {_format_value(value)}]")'
    if op == "truediv":
        (cxpath,) = rest
        return f'iter(doc.select_all({cxpath!r}))'
    if op == "iter":
        return 'doc.root().children()'
    if op == "contains":
        (cxpath,) = rest
        return f'bool(doc.select_all({cxpath!r}))'
    raise ValueError(f"explain: unknown Layer-2 op {op!r}")
