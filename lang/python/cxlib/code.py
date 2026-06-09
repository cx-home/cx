"""v0.8.0 Layer-1 CX code surface — Python binding.

Per `spec/bindings.md` §2.1, every binding exposes a 16-method Layer-1
surface for parsing, hashing, evaluating, and modifying CX documents.
This module wires the v0.8.0 additions to the existing `cxlib`
foundation:

  * `cx_code_eval` — already exposed as `cxlib.eval_code` (see
    `cxlib.cx`).  Re-exported here for parity with the `cx_code_*`
    naming. This is the canonical v0.8.0 name; the
    v0.7.0 / v0.7.5 `cx_eval` symbol is gone.
  * `cx_code_diagram(source) -> str` — wasm-safe Mermaid emit, behind
    cap bit 31.  Source must be non-empty; only `'mermaid'` is supported
    in the wasm tier.
  * `cx_code_tree(source) -> dict` — JSON projection of the parsed
    source, cap bit 32. Each node carries
    ``{kind, name?, value?, loc:{start,end}, children?}``; `loc` byte
    offsets enable the bidirectional selection bridge.  The Phase 2.11
    stub returns a minimal-shape root element with `loc:{0,len(src)}`;
    the wrapper here is forward-compatible with the full walker.

The Layer-1 `Doc` class (a thin façade over the existing `Document` AST
plus `cxlib.eval_code` and the new code-projection helpers) lives below
the C-ABI wrappers.  Per `spec/bindings.md` §2.1 the canonical 16
methods are:

    parse(bytes) -> Doc
    Doc.bytes() -> bytes
    Doc.hash() -> str
    Doc.equals(other) -> bool
    Doc.eval(code) -> str
    Doc.select_all(cxpath) -> list[Node]
    Doc.select(cxpath) -> Node | None
    Doc.modify(focus, action) -> Doc
    Doc.find_all(name) -> list[Node]
    Doc.root() -> Node
    Node.name() -> str
    Node.attr(name) -> Any
    Node.attrs() -> dict
    Node.children() -> list[Node]
    Node.body() -> Any
    Node.kind() -> str

Plus the three free-function atoms (`atom`, `is_atom`, `atom_name`) per
re-exported via `cxlib.__init__` and not part of the 16
Doc/Node methods.
"""
from __future__ import annotations

import ctypes
import json
from typing import Any, Optional

from . import ast as _ast
from . import cx as _cx


# ── Layer-1 error type (spec/bindings.md §2.4) ──────────────────────────────
#
# All Layer-1 methods raise host-native exceptions on error.  The
# exception carries:
#   - ``code``    — CX error code (e.g. ``"cx-err:CXER0100"``)
#   - ``message`` — human-readable
# The error-code set is identical across bindings; the message text is
# binding-agnostic.  ``str(exc)`` prepends the ``cx-err:CXERnnnn`` token
# so parity diffs (and the runner's CXER-extracting regex) see the same
# wire format that V emits via its ``EvalError{code, message}`` struct.


class CxError(RuntimeError):
    """Layer-1 binding error per spec/bindings.md §2.4."""

    __slots__ = ("code", "_message")

    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self._message = message
        super().__init__(f"{code}: {message}")

    @property
    def message(self) -> str:
        return self._message


# ── C ABI wiring for the v0.8.0 additions ───────────────────────────────────

_lib = _cx._lib  # noqa: SLF001 — re-use the loaded handle.

# cx_code_diagram(source, source_len, format, format_len) -> char*
# Error wire format: in-band `CXERnnnn:msg`.  Caller frees with cx_free.
_lib.cx_code_diagram.restype = ctypes.c_char_p
_lib.cx_code_diagram.argtypes = [
    ctypes.c_char_p, ctypes.c_size_t,
    ctypes.c_char_p, ctypes.c_size_t,
]

# cx_code_tree(source, source_len, out_len*) -> char* (JSON)
# Heap-allocated UTF-8 JSON; caller frees via cx_free.  out_len receives
# the byte length of the JSON payload (NUL terminator NOT included).
_lib.cx_code_tree.restype = ctypes.c_char_p
_lib.cx_code_tree.argtypes = [
    ctypes.c_char_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t),
]


# ── Layer-1 free functions: cx_code_eval / cx_code_diagram / cx_code_tree ───

# Re-export the canonical v0.8.0 evaluator entry point under its
# `cx_code_eval` Pythonic name for symmetry with diagram / tree.  The
# legacy `eval_code` (already exported from `cxlib.cx`) stays — see
# spec/bindings.md §2.1: "snake_case" is the Python convention for
# Layer-1.
def cx_code_eval(source: str, program: str, output_target: str = "") -> str:
    """Evaluate a CX program against an optional CX source document.

    Thin alias for ``cxlib.eval_code`` — the underlying C ABI symbol is
    ``cx_code_eval_with_len``. Identical semantics; the
    name here mirrors the C ABI for clarity in Layer-1 conformance
    fixtures (per `conformance/binding_api.txt`).
    """
    return _cx.eval_code(source, program, output_target)


def cx_code_diagram(source: str, format: str = "mermaid") -> str:
    """Render a CX program / source to a diagram representation.

    Wasm-safe Mermaid emit (cap bit 31). Only
    ``'mermaid'`` is supported at v0.8.0; SVG / PNG are CLI-only.

    Raises ``RuntimeError`` on parse / render failure — the error
    message starts with the ``CXERnnnn:`` wire prefix.
    """
    src_b = source.encode("utf-8")
    fmt_b = format.encode("utf-8")
    raw = _lib.cx_code_diagram(src_b, len(src_b), fmt_b, len(fmt_b))
    if raw is None:
        raise RuntimeError("cx_code_diagram: null return (allocation failure)")
    out = raw.decode("utf-8")
    if out.startswith("CXER") and ":" in out[:10]:
        raise RuntimeError(out)
    return out


def cx_code_tree(source: str) -> dict:
    """Return the JSON projection of the parsed CX source.

    The resulting dict carries at minimum a top-level
    ``{kind, name, loc:{start,end}}`` element; nested ``children`` and
    per-node ``value`` / ``name`` fields appear as the walker
    materialises them.  Byte offsets in ``loc`` index into the original
    UTF-8 source.

    Phase 2.11 in vcx ships a stub that returns a single root element
    with ``loc:{0, len(source)}``.  This wrapper is forward-compatible
    — the JSON shape is stable across the stub-vs-walker transition per

    Raises ``RuntimeError`` if the C ABI returns NULL (allocation
    failure) or the payload is not valid JSON.
    """
    src_b = source.encode("utf-8") if source else b""
    out_len = ctypes.c_size_t(0)
    raw = _lib.cx_code_tree(src_b, len(src_b), ctypes.byref(out_len))
    if raw is None:
        # NULL return: per cabi.v contract, out_len is also set to 0.
        raise RuntimeError("cx_code_tree: NULL return (allocation failure)")
    payload = ctypes.string_at(raw, int(out_len.value)) if out_len.value else raw
    text = payload.decode("utf-8") if isinstance(payload, (bytes, bytearray)) else payload
    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        raise RuntimeError(
            f"cx_code_tree: payload is not valid JSON: {exc.msg}"
        ) from exc


# ── Layer-1 Doc / Node façades (spec/bindings.md §2.1) ──────────────────────
#
# Wrappers around the existing `cxlib.ast.Document` + `Element` types
# that expose the canonical 16-method surface.  These do NOT replace
# the dataclass-style AST API — they sit alongside it as a stable
# Layer-1 contract.  Test-suite fixtures (`conformance/binding_api.txt`)
# bind against the names defined here.


class Node:
    """Layer-1 wrapper around `cxlib.ast.Element`.

    The 6-method Node surface (name / attr / attrs / children / body /
    kind) wraps the corresponding Element accessors.  Body returns the
    element's text/scalar content when present; otherwise it returns the
    raw items list (sequence of child nodes — Text / Scalar / Element
    / etc.) so consumers can introspect non-element content.
    """

    __slots__ = ("_el",)

    def __init__(self, element: _ast.Element) -> None:
        self._el = element

    # Method 11 — Node.name() -> string
    def name(self) -> str:
        return self._el.name

    # Method 12 — Node.attr(name) -> Value?
    def attr(self, name: str) -> Any:
        return self._el.attr(name)

    # Method 13 — Node.attrs() -> Map
    def attrs(self) -> dict[str, Any]:
        return {a.name: a.value for a in self._el.attrs}

    # Method 14 — Node.children() -> [Node]
    def children(self) -> list["Node"]:
        return [Node(c) for c in self._el.children()]

    # Method 15 — Node.body() -> Value
    def body(self) -> Any:
        # Prefer the first scalar-typed value when present (preserves
        # int / bool / atom round-trip); fall back to the concatenated
        # text content; finally fall back to the raw items list when
        # the element carries only structural children.
        scalar = self._el.scalar()
        if scalar is not None:
            return scalar
        txt = self._el.text()
        if txt:
            return txt
        return list(self._el.items)

    # Method 16 — Node.kind() -> string
    def kind(self) -> str:
        return "element"

    # Layer-2 conveniences (not part of the 16-method surface; safe to
    # ignore for conformance).
    @property
    def element(self) -> _ast.Element:
        """Underlying `cxlib.ast.Element` — for callers that need the
        full Element API (find_all, set_attr, …)."""
        return self._el

    def __repr__(self) -> str:
        return f"Node(name={self._el.name!r})"


class Doc:
    """Layer-1 Doc façade per `spec/bindings.md` §2.1.

    Holds the canonical CX bytes plus a parsed `cxlib.ast.Document`.
    Methods that return a new Doc do NOT mutate the receiver
    (pure-functional contract).
    """

    __slots__ = ("_bytes", "_doc")

    def __init__(self, source: bytes, document: Optional[_ast.Document] = None) -> None:
        if isinstance(source, str):
            source = source.encode("utf-8")
        self._bytes = bytes(source)
        if document is not None:
            self._doc = document
        else:
            # Wrap the pure-Python parser's RuntimeError so the wire
            # format matches V's `EvalError{code: 'cx-err:CXER0100', …}`
            # per spec/bindings.md §2.4.  Keeps the original parser
            # message after the code token so debugging output survives.
            try:
                self._doc = _ast.parse(self._bytes.decode("utf-8"))
            except CxError:
                raise
            except Exception as exc:  # noqa: BLE001
                raise CxError("cx-err:CXER0100", str(exc)) from exc

    # Method 1 — parse(bytes) -> Doc  (classmethod constructor).
    @classmethod
    def parse(cls, source: bytes) -> "Doc":
        """Parse canonical CX bytes into a Doc value."""
        if isinstance(source, str):
            source = source.encode("utf-8")
        return cls(source)

    # Method 2 — Doc.bytes() -> bytes
    def bytes(self) -> bytes:
        """Serialize Doc to canonical CX bytes."""
        return self._doc.to_cx().encode("utf-8")

    # Method 3 — Doc.hash() -> string
    def hash(self) -> str:
        """SHA-256 hex of the strict-canonical bytes (spec/abi.md §2.6)."""
        return _cx.hash(self._doc.to_cx())

    # Method 4 — Doc.equals(other) -> bool
    def equals(self, other: "Doc") -> bool:
        """Canonical-bytes equality.  Two Docs compare equal iff
        ``cx_canonical`` yields the same bytes for both."""
        if not isinstance(other, Doc):
            return NotImplemented  # type: ignore[return-value]
        return _cx.eq(self._doc.to_cx(), other._doc.to_cx())

    # Method 5 — Doc.eval(code) -> Value
    def eval(self, code: str, output_target: str = "") -> str:
        """Evaluate a CX code program against this Doc (wraps
        ``cx_code_eval``)."""
        return _cx.eval_code(self._doc.to_cx(), code, output_target)

    # Method 6 — Doc.select_all(cxpath) -> [Node]
    def select_all(self, cxpath: str) -> list[Node]:
        """Evaluate a CXPath value expression and return the matching
        nodes."""
        return [Node(el) for el in self._doc.select_all(cxpath)]

    # Method 7 — Doc.select(cxpath) -> Node?
    def select(self, cxpath: str) -> Optional[Node]:
        """First match of ``select_all``, or None when the path matches
        nothing."""
        matches = self._doc.select_all(cxpath)
        return Node(matches[0]) if matches else None

    # Method 8 — Doc.modify(focus, action) -> Doc
    def modify(self, focus: str, action: str) -> "Doc":
        """Pure-functional update. Returns a new Doc; the
        receiver is unchanged.

        ``action`` carries the trailing modify-action clause + args,
        e.g. ``'[delete]'``, ``'[set "Alicia"]'``, ``'[rename component]'``.
        """
        new_doc = self._doc.modify(focus, action)
        return Doc(new_doc.to_cx().encode("utf-8"), new_doc)

    # Method 9 — Doc.find_all(name) -> [Node]
    def find_all(self, name: str) -> list[Node]:
        """Name-only convenience — no CXPath parse, depth-first walk."""
        return [Node(el) for el in self._doc.find_all(name)]

    # Method 10 — Doc.root() -> Node
    def root(self) -> Optional[Node]:
        """Root element, or None for an empty document."""
        r = self._doc.root()
        return Node(r) if r is not None else None

    # ── Layer-1 code-projection helpers ──────────────────────────
    #
    # Both pass the canonical CX bytes through `cx_code_diagram` /
    # `cx_code_tree`.  Kept on Doc for ergonomic parity with `.eval()`.

    def diagram(self, format: str = "mermaid") -> str:
        """Mermaid diagram of this Doc's source."""
        return cx_code_diagram(self._doc.to_cx(), format)

    def tree(self) -> dict:
        """JSON tree projection of this Doc's source."""
        return cx_code_tree(self._doc.to_cx())

    @property
    def document(self) -> _ast.Document:
        """Underlying `cxlib.ast.Document` — for callers that need the
        full Document API (resolve_id, to_xml, to_json, …)."""
        return self._doc

    def __repr__(self) -> str:
        return f"Doc(bytes={len(self._bytes)})"


# ── Module-level `parse` alias matching `spec/bindings.md` §2.1 ─────────────

def parse(source: bytes) -> Doc:
    """Parse canonical CX bytes into a Doc value.  Equivalent to
    ``Doc.parse(source)``."""
    return Doc.parse(source)
