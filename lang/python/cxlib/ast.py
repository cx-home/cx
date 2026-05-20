"""CX native AST types — parse, emit, and query."""
from __future__ import annotations
import json
import re
from dataclasses import dataclass, field
from typing import Any, Optional, Union
from . import cx as _cx


# ── Node types ────────────────────────────────────────────────────────────────

@dataclass
class Attr:
    name: str
    value: Any          # str | int | float | bool | None
    data_type: Optional[str] = None  # None means string (omitted in JSON)
    # v3.4 (ADR 0002): expanded-name fields populated by
    # resolve_namespaces(). `local` is the part after the first ':' in
    # `name` (or the whole name); `ns_uri` is the resolved namespace
    # URI. Per XML Namespaces 1.0 §6.2 the default namespace does not
    # apply to unprefixed attributes — `ns_uri` is None for them.
    local: str = ""
    ns_uri: Optional[str] = None
    # v3.4 (ADR 0003): True when the source attribute value was a bare
    # `@id` token (e.g. `assigned-to=@u-1`). Quoted strings starting
    # with '@' have is_ref = False. Round-trip preserves the bare form.
    is_ref: bool = False
    # v3.5 (ADR 0016): BracketBody attribute value — `name=[BodyItem*]`.
    # When set, `value` is unused and the attribute's content is the parsed
    # body sequence. Used by CXL evaluation directives like
    # `[?if cond :then=[BODY] :else=[BODY]]`. Inert outside CXL evaluation;
    # round-trips as opaque structure (ADR 0016 R5). ast_bin format
    # version 5 carries this field; v1-4 decoders see attrs without it.
    body: Optional[list["Node"]] = None

    def local_name(self) -> str:
        """Local part of the attribute name (post-colon, or whole name)."""
        return self.local

    def namespace_uri(self) -> Optional[str]:
        """Resolved namespace URI for prefixed attributes; None otherwise."""
        return self.ns_uri


@dataclass
class Text:
    value: str


@dataclass
class Scalar:
    data_type: str      # int | float | bool | null | string | date | datetime | bytes
    value: Any          # native Python value


@dataclass
class Comment:
    value: str


@dataclass
class RawText:
    value: str


@dataclass
class EntityRef:
    name: str


@dataclass
class Alias:
    name: str


@dataclass
class PI:
    target: str
    data: Optional[str] = None


@dataclass
class XMLDecl:
    version: str = "1.0"
    encoding: Optional[str] = None
    standalone: Optional[str] = None


@dataclass
class CXDirective:
    attrs: list[Attr] = field(default_factory=list)
    # v0.6.0 — directives may carry an `&anchor` and/or nested elements.
    # Currently used by `[?cx frag &name [body :TYPE :flags]]` (spec
    # schema.md §8 standalone fragment form). ast_bin format version 4
    # carries them; v1-3 decoders see attrs-only and leave these empty.
    anchor: Optional[str] = None
    items: list["Node"] = field(default_factory=list)


@dataclass
class BlockContent:
    items: list["Node"] = field(default_factory=list)


@dataclass
class Interpolation:
    """v3.5 (ADR 0016) [58] — `[?=EXPR]`. EXPR is opaque text at v0.6.0;
    the CXL evaluator at v0.7.0+ parses it as CXPath at evaluation time."""
    expr: str


@dataclass
class EvalDirective:
    """v3.5 (ADR 0016) [59] — `[?Name attrs body]`. Reserved EvalNames
    (if/for/with/cond/include/def/use/let/fn/match/try) parse into this
    node. Inert at v0.6.0; CXL evaluator dispatches on `name`."""
    name: str
    attrs: list[Attr] = field(default_factory=list)
    items: list["Node"] = field(default_factory=list)


@dataclass
class DoctypeDecl:
    name: str
    external_id: Optional[dict] = None
    int_subset: list = field(default_factory=list)


@dataclass
class Element:
    name: str
    anchor: Optional[str] = None
    merge: Optional[str] = None
    data_type: Optional[str] = None  # TypeAnnotation e.g. "int[]"
    attrs: list[Attr] = field(default_factory=list)
    items: list["Node"] = field(default_factory=list)
    # v3.4 (ADR 0002): expanded-name fields populated by
    # resolve_namespaces(). See Attr docstring.
    local: str = ""
    ns_uri: Optional[str] = None
    # v3.4 (ADR 0003): syntactic ID declaration — set when the source has
    # a `#name` token immediately after the element name (e.g.
    # `[user #u-1 name=alice]`). Distinct from anchors and from user-data
    # attributes literally named `id`.
    id: Optional[str] = None
    # v3.4 (ADR 0003 D1): body-position reference — set when the source had
    # `[ref @<name>]` (an element named `ref` whose body is a single
    # `@name` token). Carries the bare-ref target id; `name` is fixed to
    # `"ref"` and `attrs`/`items` are empty in that case. Round-trips
    # across the C ABI via ast_bin v3+ (Phase 7.70).
    body_ref: Optional[str] = None
    # v0.7.0 Z2 (spec/i18n.md §1.3): in-scope BCP 47 language tag.
    # Populated by resolve_languages() called from parse_cx(). See
    # Element.lang() for the public accessor and the None vs "" vs
    # "<tag>" semantics.
    lang_resolved: Optional[str] = None

    def local_name(self) -> str:
        """Local part of the element name (post-colon, or whole name)."""
        return self.local

    def namespace_uri(self) -> Optional[str]:
        """Resolved namespace URI for this element; None when no
        binding is in scope and the prefix is not reserved."""
        return self.ns_uri

    def lang(self) -> str:
        """BCP 47 language tag in scope at this element per
        spec/i18n.md §1.3.

        Returns the resolved tag when cx:lang is in scope (locally
        declared or inherited from an ancestor); returns the empty
        string when no cx:lang is in scope or when an ancestor's
        declaration was shadowed by an explicit cx:lang="".
        """
        return self.lang_resolved or ""

    def get(self, name: str) -> Optional["Element"]:
        """First child Element with this name."""
        for item in self.items:
            if isinstance(item, Element) and item.name == name:
                return item
        return None

    def get_all(self, name: str) -> list["Element"]:
        """All child Elements with this name."""
        return [i for i in self.items if isinstance(i, Element) and i.name == name]

    def attr(self, name: str) -> Any:
        """Attribute value by name, or None."""
        for a in self.attrs:
            if a.name == name:
                return a.value
        return None

    def text(self) -> str:
        """Concatenated Text and Scalar child content."""
        parts = []
        for item in self.items:
            if isinstance(item, Text):
                parts.append(item.value)
            elif isinstance(item, Scalar):
                parts.append("null" if item.value is None else str(item.value))
        return " ".join(parts)

    def scalar(self) -> Any:
        """Value of first Scalar child, or None."""
        for item in self.items:
            if isinstance(item, Scalar):
                return item.value
        return None

    def children(self) -> list["Element"]:
        """All child Elements (excludes Text, Scalar, and other nodes)."""
        return [i for i in self.items if isinstance(i, Element)]

    def find_all(self, name: str) -> list["Element"]:
        """All descendant Elements with this name (depth-first)."""
        result = []
        for item in self.items:
            if isinstance(item, Element):
                if item.name == name:
                    result.append(item)
                result.extend(item.find_all(name))
        return result

    def find_first(self, name: str) -> Optional["Element"]:
        """First descendant Element with this name (depth-first)."""
        for item in self.items:
            if isinstance(item, Element):
                if item.name == name:
                    return item
                found = item.find_first(name)
                if found is not None:
                    return found
        return None

    def at(self, path: str) -> Optional["Element"]:
        """Navigate by slash-separated path: el.at('server/host')."""
        parts = [p for p in path.split('/') if p]
        cur: Optional[Element] = self
        for part in parts:
            if cur is None:
                return None
            cur = cur.get(part)
        return cur

    def append(self, node: "Node") -> None:
        """Append a child node."""
        self.items.append(node)

    def prepend(self, node: "Node") -> None:
        """Prepend a child node."""
        self.items.insert(0, node)

    def insert(self, index: int, node: "Node") -> None:
        """Insert a child node at index."""
        self.items.insert(index, node)

    def remove(self, node: "Node") -> None:
        """Remove a child node by identity."""
        self.items = [i for i in self.items if i is not node]

    def remove_child(self, name: str) -> None:
        """Remove all direct child Elements with the given name."""
        self.items = [i for i in self.items if not (isinstance(i, Element) and i.name == name)]

    def remove_at(self, index: int) -> None:
        """Remove child node at index; no-op if index is out of bounds."""
        if 0 <= index < len(self.items):
            self.items = self.items[:index] + self.items[index + 1:]

    def select(self, expr: str) -> Optional["Element"]:
        """First descendant matching a CXPath expression (excludes self)."""
        results = self.select_all(expr)
        return results[0] if results else None

    def select_all(self, expr: str) -> list["Element"]:
        """All descendants matching a CXPath expression (excludes self), depth-first.

        v3.4: thunks to libcx via cx_select_all_paths (CB-5). Returned
        Elements are live references into this Element's tree —
        mutations propagate, preserving prior behavior. Semantics match
        V's Element.select_all: the element's items become the top-
        level candidate set, so a child-axis expression like "child"
        matches direct children, and "//child" matches at any descendant
        depth.
        """
        from . import cx as _cx
        # Emit each Element child of self as a top-level node. This puts
        # self.items into doc.elements after the round-trip, so V's
        # Document.select_all_paths walks the same candidate set that
        # V's Element.select_all would. Track a mapping from
        # serialized-doc index back to the original self.items index;
        # CXPath only matches Elements anyway, so non-Element items can
        # be skipped from the docStr without affecting matches.
        parts: list[str] = []
        doc_to_orig: list[int] = []
        for i, item in enumerate(self.items):
            if isinstance(item, Element):
                parts.append(_emit_element_as_doc(item))
                doc_to_orig.append(i)
        doc_str = '\n'.join(parts)
        paths = _cx.select_all_paths(doc_str, expr)
        out: list[Element] = []
        for p in paths:
            if not p:
                continue
            top = p[0]
            if top < 0 or top >= len(doc_to_orig):
                continue
            node: Any = self.items[doc_to_orig[top]]
            for k in p[1:]:
                if not isinstance(node, Element) or k >= len(node.items):
                    node = None; break
                node = node.items[k]
            if isinstance(node, Element):
                out.append(node)
        return out

    def set_attr(self, name: str, value: Any, data_type: Optional[str] = None) -> None:
        """Set an attribute value, updating if it already exists."""
        for a in self.attrs:
            if a.name == name:
                a.value = value
                a.data_type = data_type
                return
        self.attrs.append(Attr(name, value, data_type))

    def remove_attr(self, name: str) -> None:
        """Remove an attribute by name."""
        self.attrs = [a for a in self.attrs if a.name != name]


Node = Union[
    Element, Text, Scalar, Comment, RawText, EntityRef, BlockContent,
    Alias, PI, XMLDecl, CXDirective, DoctypeDecl,
    Interpolation, EvalDirective,
]


@dataclass
class Document:
    elements: list[Node] = field(default_factory=list)
    prolog: list[Node] = field(default_factory=list)
    doctype: Optional[DoctypeDecl] = None

    def root(self) -> Optional[Element]:
        """First top-level Element."""
        for e in self.elements:
            if isinstance(e, Element):
                return e
        return None

    def get(self, name: str) -> Optional[Element]:
        """First top-level Element with this name."""
        for e in self.elements:
            if isinstance(e, Element) and e.name == name:
                return e
        return None

    def at(self, path: str) -> Optional[Element]:
        """Navigate by slash-separated path from root: doc.at('article/body/p')."""
        parts = [p for p in path.split('/') if p]
        if not parts:
            return self.root()
        cur = self.get(parts[0])
        if cur is None or len(parts) == 1:
            return cur
        return cur.at('/'.join(parts[1:]))

    def find_all(self, name: str) -> list[Element]:
        """All descendant Elements with this name (depth-first through entire document)."""
        result = []
        for e in self.elements:
            if isinstance(e, Element):
                if e.name == name:
                    result.append(e)
                result.extend(e.find_all(name))
        return result

    def find_first(self, name: str) -> Optional[Element]:
        """First descendant Element with this name (depth-first through entire document)."""
        for e in self.elements:
            if isinstance(e, Element):
                if e.name == name:
                    return e
                found = e.find_first(name)
                if found is not None:
                    return found
        return None

    def append(self, node: Node) -> None:
        """Append a top-level node."""
        self.elements.append(node)

    def prepend(self, node: Node) -> None:
        """Prepend a top-level node."""
        self.elements.insert(0, node)

    def select(self, expr: str) -> Optional[Element]:
        """First element matching a CXPath expression."""
        results = self.select_all(expr)
        return results[0] if results else None

    def select_all(self, expr: str) -> list[Element]:
        """All elements matching a CXPath expression, depth-first.

        v3.4: thunks to libcx via cx_select_all_paths (CB-5). Returned
        Elements are live references into this Document's tree —
        mutations propagate, preserving prior behavior.
        """
        from . import cx as _cx
        from .cxpath import navigate_doc_path
        paths = _cx.select_all_paths(self.to_cx(), expr)
        out: list[Element] = []
        for p in paths:
            el = navigate_doc_path(self, p)
            if el is not None:
                out.append(el)
        return out

    def transform(self, path: str, f) -> "Document":
        """Return a new Document with the element at path replaced by f(el). Original unchanged."""
        from .cxpath import elem_detached, doc_replace_at, path_copy_element
        parts = [p for p in path.split('/') if p]
        if not parts:
            return self
        for i, node in enumerate(self.elements):
            if isinstance(node, Element) and node.name == parts[0]:
                if len(parts) == 1:
                    return doc_replace_at(self, i, f(elem_detached(node)))
                updated = path_copy_element(node, parts[1:], f)
                if updated is not None:
                    return doc_replace_at(self, i, updated)
                return self
        return self

    def transform_all(self, expr: str, f) -> "Document":
        """Return a new Document with every element matching expr replaced by f(el). Original unchanged.

        v3.4: thunks to libcx via cx_select_all_paths (CB-5). Paths are
        applied bottom-up (longest first) so that when a parent is
        rewritten, its f-input already contains the f-results of
        descendant matches — matching the prior post-order semantics.
        """
        from . import cx as _cx
        from .cxpath import elem_detached, navigate_doc_path, replace_at_doc_path
        paths = _cx.select_all_paths(self.to_cx(), expr)
        if not paths:
            return self
        # Sort longest-first; descendants get rewritten before ancestors.
        paths_sorted = sorted(paths, key=len, reverse=True)
        new_doc = self
        for p in paths_sorted:
            target = navigate_doc_path(new_doc, p)
            if target is None:
                continue
            new_doc = replace_at_doc_path(new_doc, p, f(elem_detached(target)))
        return new_doc

    def resolve_id(self, id: str) -> Optional[Element]:
        """Return the Element declaring `#id`, or None. v3.4 (ADR 0003)."""
        for tree in (self.elements, self.prolog):
            found = _find_element_by_id(tree, id)
            if found is not None:
                return found
        return None

    def resolve_body_ref(self, e: Element) -> Optional[Element]:
        """Return the Element targeted by ``e.body_ref`` in this document,
        or None when ``e.body_ref`` is unset or the target ID is undeclared.
        v0.7.0 (ADR 0003 D1 second bullet / GG13 row at v0_7_0_status.md).
        """
        if e.body_ref is None:
            return None
        return self.resolve_id(e.body_ref)

    def elements_by_id(self) -> dict[str, Element]:
        """Build a {id: Element} map for the whole document. v3.4 (ADR 0003)."""
        out: dict[str, Element] = {}
        _collect_elements_by_id(self.elements, out)
        _collect_elements_by_id(self.prolog, out)
        return out

    def to_cx(self) -> str:
        return _emit_doc(self)

    def to_ast_bin(self) -> bytes:
        """Serialize this Document to a FRAMED binary AST buffer
        ([u32 LE size][payload]). Used by to_xml / to_json / etc. and
        spec/ast_bin.md describes the wire format.

        v3.4: encoder added in Phase 5 (CB-1) so format conversions
        skip the cx_to_<fmt>(self.to_cx()) round-trip.
        """
        from .binary import encode_ast
        return encode_ast(self)

    # v3.4: each format method now goes through cx_ast_bin_to_<fmt>
    # directly (CB-1), avoiding the prior emit-CX-and-reparse detour.
    def to_xml(self) -> str:
        from .binary import call_bin_in_text_out
        return call_bin_in_text_out('cx_ast_bin_to_xml', self.to_ast_bin())

    def to_json(self) -> str:
        from .binary import call_bin_in_text_out
        return call_bin_in_text_out('cx_ast_bin_to_json', self.to_ast_bin())

    def to_yaml(self) -> str:
        from .binary import call_bin_in_text_out
        return call_bin_in_text_out('cx_ast_bin_to_yaml', self.to_ast_bin())

    def to_toml(self) -> str:
        from .binary import call_bin_in_text_out
        return call_bin_in_text_out('cx_ast_bin_to_toml', self.to_ast_bin())

    def to_md(self) -> str:
        from .binary import call_bin_in_text_out
        return call_bin_in_text_out('cx_ast_bin_to_md', self.to_ast_bin())


# ── Deserialization: AST JSON dict → native types ─────────────────────────────

def _node_from_dict(d: dict) -> Node:
    t = d.get("type", "")
    if t == "Element":
        return Element(
            name=d["name"],
            anchor=d.get("anchor"),
            merge=d.get("merge"),
            data_type=d.get("dataType"),
            attrs=[Attr(a["name"], a["value"], a.get("dataType")) for a in d.get("attrs", [])],
            items=[_node_from_dict(n) for n in d.get("items", [])],
        )
    if t == "Text":
        return Text(d["value"])
    if t == "Scalar":
        return Scalar(d["dataType"], d["value"])
    if t == "Comment":
        return Comment(d["value"])
    if t == "RawText":
        return RawText(d["value"])
    if t == "EntityRef":
        return EntityRef(d["name"])
    if t == "Alias":
        return Alias(d["name"])
    if t == "PI":
        return PI(d["target"], d.get("data"))
    if t == "XMLDecl":
        return XMLDecl(d.get("version", "1.0"), d.get("encoding"), d.get("standalone"))
    if t == "CXDirective":
        return CXDirective([Attr(a["name"], a["value"]) for a in d.get("attrs", [])])
    if t == "DoctypeDecl":
        return DoctypeDecl(d["name"], d.get("externalID"), d.get("intSubset", []))
    if t == "BlockContent":
        return BlockContent([_node_from_dict(n) for n in d.get("items", [])])
    return Text(str(d))  # unknown node — preserve as text


def _find_element_by_id(nodes: list, id: str) -> Optional[Element]:
    for n in nodes:
        if isinstance(n, Element):
            if n.id == id:
                return n
            found = _find_element_by_id(n.items, id)
            if found is not None:
                return found
    return None


def _collect_elements_by_id(nodes: list, out: dict[str, Element]) -> None:
    for n in nodes:
        if isinstance(n, Element):
            if n.id:
                out[n.id] = n
            _collect_elements_by_id(n.items, out)


def _doc_from_dict(d: dict) -> Document:
    doctype = None
    if "doctype" in d:
        dt = d["doctype"]
        doctype = DoctypeDecl(dt["name"], dt.get("externalID"), dt.get("intSubset", []))
    return Document(
        prolog=[_node_from_dict(n) for n in d.get("prolog", [])],
        doctype=doctype,
        elements=[_node_from_dict(n) for n in d.get("elements", [])],
    )


# ── Namespace resolution (ADR 0002 / spec/namespaces.md) ──────────────────────
#
# Mirrors V core's vcx/cx/namespaces.v. Walks a parsed Document,
# populating Element.{local, ns_uri} and Attr.{local, ns_uri} based on
# in-scope xmlns / xmlns: declarations. Called at the tail of every
# parse entry point (parse, parse_xml, parse_json, parse_yaml,
# parse_toml, parse_md) so consumers see a uniform expanded-name view.
#
# Reserved prefixes:
#   - `xml`   → http://www.w3.org/XML/1998/namespace
#   - `cx`    → https://cx-home.org/ns/cx
#   - `xmlns` → declaration-only; never resolves as a name prefix

XML_NAMESPACE_URI = "http://www.w3.org/XML/1998/namespace"
CX_NAMESPACE_URI = "https://cx-home.org/ns/cx"


def _split_ns_prefix(name: str) -> tuple[str, str]:
    i = name.find(':')
    if i < 0:
        return '', name
    return name[:i], name[i + 1:]


def _lookup_ns(prefix: str, scope: list[dict[str, str]]) -> Optional[str]:
    if prefix == 'xml':
        return XML_NAMESPACE_URI
    if prefix == 'cx':
        return CX_NAMESPACE_URI
    if prefix == 'xmlns':
        return None
    for frame in reversed(scope):
        if prefix in frame:
            uri = frame[prefix]
            return uri if uri else None  # empty URI undeclares
    return None


def _resolve_element(e: Element, scope: list[dict[str, str]]) -> None:
    frame: dict[str, str] = {}
    for a in e.attrs:
        if a.name == 'xmlns':
            frame[''] = '' if a.value is None else str(a.value)
        elif a.name.startswith('xmlns:') and len(a.name) > 6:
            frame[a.name[6:]] = '' if a.value is None else str(a.value)
    pushed = bool(frame)
    if pushed:
        scope.append(frame)

    prefix, local = _split_ns_prefix(e.name)
    e.local = local
    e.ns_uri = _lookup_ns(prefix, scope)

    for a in e.attrs:
        ap, al = _split_ns_prefix(a.name)
        a.local = al
        if a.name == 'xmlns' or ap == 'xmlns':
            a.ns_uri = None
            continue
        if ap == '':
            # Default ns does not apply to unprefixed attributes.
            a.ns_uri = None
            continue
        a.ns_uri = _lookup_ns(ap, scope)

    for item in e.items:
        if isinstance(item, Element):
            _resolve_element(item, scope)

    if pushed:
        scope.pop()


def resolve_namespaces(doc: Document) -> None:
    """Populate Element.{local, ns_uri} and Attr.{local, ns_uri} on
    every node in `doc` per ADR 0002 / spec/namespaces.md. Also
    propagates cx:lang inherited scope per spec/i18n.md §1.3 — sets
    Element.lang_resolved on every Element. Idempotent.
    Called automatically by parse(), parse_xml(), parse_json(),
    parse_yaml(), parse_toml(), parse_md()."""
    scope: list[dict[str, str]] = []
    for node in doc.elements:
        if isinstance(node, Element):
            _resolve_element(node, scope)
    lang_stack: list[Optional[str]] = []
    for node in doc.elements:
        if isinstance(node, Element):
            _resolve_element_lang(node, lang_stack)


def _resolve_element_lang(el: "Element", stack: list[Optional[str]]) -> None:
    """Propagate cx:lang per spec/i18n.md §1.3. Mirrors V's
    vcx/cx/namespaces.v::resolve_element_lang."""
    own_lang: Optional[str] = None
    declared = False
    for a in el.attrs:
        if a.name == "cx:lang":
            v = a.value
            own_lang = v if isinstance(v, str) else (str(v) if v is not None else "")
            declared = True
            break
    if declared:
        resolved = own_lang
    elif stack:
        resolved = stack[-1]
    else:
        resolved = None
    el.lang_resolved = resolved
    stack.append(resolved)
    for item in el.items:
        if isinstance(item, Element):
            _resolve_element_lang(item, stack)
    stack.pop()


def parse(cx_str: str, *, include_root: Optional[str] = None) -> Document:
    """Parse a CX string into a Document.

    ``include_root`` (v0.7.0, ADR 0023 GG4) opts into the
    spec/include.md §1-§8 ?include resolver. When set to an absolute
    directory path, every ``[?cx include=path]`` directive in the
    source is resolved against that root before the Document is
    decoded. ``None`` / empty preserves directives in the AST.
    """
    from .binary import ast_bin, ast_bin_with_include_root, decode_ast
    if include_root:
        doc = decode_ast(ast_bin_with_include_root(cx_str, include_root))
    else:
        doc = decode_ast(ast_bin(cx_str))
    resolve_namespaces(doc)
    return doc


# v3.4: parse_<fmt> goes through cx_<fmt>_to_ast_bin (CB-2), avoiding
# the prior cx_<fmt>_to_ast → JSON.parse → walk-dict pipeline.

def parse_xml(xml_str: str) -> Document:
    """Parse an XML string into a Document."""
    from .binary import call_bin_in, decode_ast
    doc = decode_ast(call_bin_in('cx_xml_to_ast_bin', xml_str))
    resolve_namespaces(doc)
    return doc


def parse_json(json_str: str) -> Document:
    """Parse a JSON string into a Document."""
    from .binary import call_bin_in, decode_ast
    doc = decode_ast(call_bin_in('cx_json_to_ast_bin', json_str))
    resolve_namespaces(doc)
    return doc


def parse_yaml(yaml_str: str) -> Document:
    """Parse a YAML string into a Document."""
    from .binary import call_bin_in, decode_ast
    doc = decode_ast(call_bin_in('cx_yaml_to_ast_bin', yaml_str))
    resolve_namespaces(doc)
    return doc


def parse_toml(toml_str: str) -> Document:
    """Parse a TOML string into a Document."""
    from .binary import call_bin_in, decode_ast
    doc = decode_ast(call_bin_in('cx_toml_to_ast_bin', toml_str))
    resolve_namespaces(doc)
    return doc


def parse_md(md_str: str) -> Document:
    """Parse a Markdown string into a Document."""
    from .binary import call_bin_in, decode_ast
    doc = decode_ast(call_bin_in('cx_md_to_ast_bin', md_str))
    resolve_namespaces(doc)
    return doc


# ── Data binding: loads / dumps ───────────────────────────────────────────────

def loads(cx_str: str) -> Any:
    """Deserialize CX data string into native Python types (dict/list/scalar).

    v3.4: parses through CXDB v1 (cx_to_data_bin) directly into Python
    types — no JSON-string detour. Type fidelity preserved (int stays
    int, bool stays bool, dates round-trip as datetime.date, etc.).
    Closes audit finding CB-3.
    """
    from . import data_bin
    return data_bin.decode(_cx.to_data_bin(cx_str))

def loads_xml(xml_str: str) -> Any:
    """Deserialize XML string into native Python types."""
    return json.loads(_cx.xml_to_json(xml_str))

def loads_json(json_str: str) -> Any:
    """Deserialize JSON string via the CX semantic bridge."""
    return json.loads(_cx.json_to_json(json_str))

def loads_yaml(yaml_str: str) -> Any:
    """Deserialize YAML string into native Python types."""
    return json.loads(_cx.yaml_to_json(yaml_str))

def loads_toml(toml_str: str) -> Any:
    """Deserialize TOML string into native Python types."""
    return json.loads(_cx.toml_to_json(toml_str))

def loads_md(md_str: str) -> Any:
    """Deserialize Markdown string into native Python types."""
    return json.loads(_cx.md_to_json(md_str))

def dumps(data: Any) -> str:
    """Serialize native Python types (dict/list/scalar) to a CX string.

    v3.4: encodes Python value as CXDB v1 bytes directly, then calls
    cx_from_data_bin to produce canonical CX. No JSON-string detour.
    Type fidelity preserved on round-trip with loads(). Closes audit
    finding CB-3.
    """
    from . import data_bin
    return _cx.from_data_bin(data_bin.encode(data))


# ── CX emitter ────────────────────────────────────────────────────────────────

_DATE_RE = re.compile(r'^\d{4}-\d{2}-\d{2}$')
_DATETIME_RE = re.compile(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}')
_HEX_RE = re.compile(r'^0[xX][0-9a-fA-F]+$')


def _would_autotype(s: str) -> bool:
    if ' ' in s:
        return False
    if _HEX_RE.match(s):
        return True
    try:
        int(s); return True
    except ValueError:
        pass
    if ('.' in s or 'e' in s.lower()):
        try:
            float(s); return True
        except ValueError:
            pass
    if s in ('true', 'false', 'null'):
        return True
    if _DATETIME_RE.match(s):
        return True
    if _DATE_RE.match(s):
        return True
    return False


def _cx_choose_quote(s: str) -> str:
    if "'" not in s:
        return f"'{s}'"
    if '"' not in s:
        return f'"{s}"'
    if "'''" not in s:
        return f"'''{s}'''"
    return f'"{s}"'  # best effort; embedded ''' stays as-is


def _cx_quote_text(s: str) -> str:
    needs = (
        s.startswith(' ') or s.endswith(' ')
        or '  ' in s or '\n' in s or '\t' in s
        or '[' in s or ']' in s or '&' in s
        or s.startswith(':') or s.startswith("'") or s.startswith('"')
        or _would_autotype(s)
    )
    return _cx_choose_quote(s) if needs else s


def _cx_quote_attr(s: str) -> str:
    if not s or ' ' in s or "'" in s or '"' in s:
        return f"'{s}'"
    return s


def _emit_scalar(s: Scalar) -> str:
    v = s.value
    if v is None:
        return 'null'
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        f = f'{v}'
        return f if ('.' in f or 'e' in f.lower()) else f + '.0'
    return str(v)


def _emit_attr(a: Attr) -> str:
    if a.is_ref:
        # ADR 0003 D1: bare `@id` round-trips verbatim.
        return f'{a.name}=@{a.value}'
    dt = a.data_type
    if dt == 'int':
        return f'{a.name}={int(a.value)}'
    if dt == 'float':
        f = f'{float(a.value)}'
        v = f if ('.' in f or 'e' in f.lower()) else f + '.0'
        return f'{a.name}={v}'
    if dt == 'bool':
        return f'{a.name}={"true" if a.value else "false"}'
    if dt == 'null':
        return f'{a.name}=null'
    # string attr — quote if would autotype OR starts with '@' (else
    # would mis-parse as is_ref reference per ADR 0003).
    s = str(a.value)
    if _would_autotype(s) or (s and s[0] == '@'):
        v = _cx_choose_quote(s)
    else:
        v = _cx_quote_attr(s)
    return f'{a.name}={v}'


def _emit_inline(node: Node) -> str:
    if isinstance(node, Text):
        return _cx_quote_text(node.value) if node.value.strip() else ''
    if isinstance(node, Scalar):
        return _emit_scalar(node)
    if isinstance(node, EntityRef):
        return f'&{node.name};'
    if isinstance(node, RawText):
        return f'[#{node.value}#]'
    if isinstance(node, Element):
        return _emit_element(node, 0).rstrip('\n')
    if isinstance(node, BlockContent):
        inner = ''.join(
            (n.value if isinstance(n, Text) else _emit_element(n, 0).rstrip('\n'))
            for n in node.items
        )
        return f'[|{inner}|]'
    return ''


def _emit_element(e: Element, depth: int) -> str:
    ind = '  ' * depth
    # v3.4 (ADR 0003 D1): body-position reference shape `[ref @<id>]`.
    # No anchor / merge / id / type meta or attrs / items per parser
    # contract — just the bare-ref body.
    if e.body_ref is not None:
        return f'{ind}[{e.name} @{e.body_ref}]\n'
    has_child_elems = any(isinstance(i, Element) for i in e.items)
    has_text = any(isinstance(i, (Text, Scalar, EntityRef, RawText)) for i in e.items)
    is_multiline = has_child_elems and not has_text

    meta_parts = []
    if e.anchor:
        meta_parts.append(f'&{e.anchor}')
    if e.merge:
        meta_parts.append(f'*{e.merge}')
    if e.id:
        meta_parts.append(f'#{e.id}')
    if e.data_type:
        meta_parts.append(f':{e.data_type}')
    for a in e.attrs:
        meta_parts.append(_emit_attr(a))
    meta = (' ' + ' '.join(meta_parts)) if meta_parts else ''

    if is_multiline:
        lines = [f'{ind}[{e.name}{meta}\n']
        for item in e.items:
            lines.append(_emit_node(item, depth + 1))
        lines.append(f'{ind}]\n')
        return ''.join(lines)

    if not e.items and not meta:
        return f'{ind}[{e.name}]\n'

    body_parts = [p for p in (_emit_inline(i) for i in e.items) if p]
    body = ' '.join(body_parts)
    sep = ' ' if body else ''
    return f'{ind}[{e.name}{meta}{sep}{body}]\n'


def _emit_node(node: Node, depth: int) -> str:
    ind = '  ' * depth
    if isinstance(node, Element):
        return _emit_element(node, depth)
    if isinstance(node, Text):
        return _cx_quote_text(node.value)
    if isinstance(node, Scalar):
        return _emit_scalar(node)
    if isinstance(node, Comment):
        return f'{ind}[-{node.value}]\n'
    if isinstance(node, RawText):
        return f'{ind}[#{node.value}#]\n'
    if isinstance(node, EntityRef):
        return f'&{node.name};'
    if isinstance(node, Alias):
        return f'{ind}[*{node.name}]\n'
    if isinstance(node, BlockContent):
        inner = ''.join(_emit_node(i, 0) for i in node.items)
        return f'{ind}[|{inner}|]\n'
    if isinstance(node, PI):
        data = f' {node.data}' if node.data else ''
        return f'{ind}[?{node.target}{data}]\n'
    if isinstance(node, XMLDecl):
        parts = [f'version={node.version}']
        if node.encoding:
            parts.append(f'encoding={node.encoding}')
        if node.standalone:
            parts.append(f'standalone={node.standalone}')
        return f'[?xml {" ".join(parts)}]\n'
    if isinstance(node, CXDirective):
        attrs = ' '.join(f'{a.name}={_cx_quote_attr(str(a.value))}' for a in node.attrs)
        return f'[?cx {attrs}]\n'
    if isinstance(node, DoctypeDecl):
        ext = ''
        if node.external_id:
            if 'public' in node.external_id:
                pub, sys = node.external_id['public'], node.external_id.get('system', '')
                ext = f" PUBLIC '{pub}' '{sys}'"
            elif 'system' in node.external_id:
                ext = f" SYSTEM '{node.external_id['system']}'"
        return f'[!DOCTYPE {node.name}{ext}]\n'
    return ''


def _emit_doc(doc: Document) -> str:
    parts = []
    for node in doc.prolog:
        parts.append(_emit_node(node, 0))
    if doc.doctype:
        parts.append(_emit_node(doc.doctype, 0))
    for node in doc.elements:
        parts.append(_emit_node(node, 0))
    return ''.join(parts).rstrip('\n')


def _emit_element_as_doc(e: Element) -> str:
    """Emit a single Element as a top-level CX document. Used by
    Element.select_all when wrapping self for the path-based thunk."""
    return _emit_node(e, 0).rstrip('\n')
