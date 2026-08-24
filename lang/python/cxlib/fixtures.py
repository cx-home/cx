"""CX-native conformance fixture loader — Python mirror of
vcx/fixtures/fixture_loader.v.

The canonical fixture format is the CX document (``conformance/*.cxd``, schema
``conformance/fixtures.cxs``). This loader reads a suite via the CX parser
itself (``cxlib.parse`` → libcx) and reconstructs each ``[case …]`` into the
legacy-shaped fields the test consumers expect, replacing the per-consumer
hand-rolled ``=== test:`` / ``--- key`` text parsers.

Section keys are returned in their LEGACY snake_case form (``in_cx``,
``out_ast``, ``sv_expected_codes``, …) so consumers key into ``sections``
exactly as they did against the old ``.txt``. Typed sections (atom arrays /
bools) are rendered back to their legacy textual form.

This is a faithful port of ``fixture_case_from`` in fixture_loader.v: same
name = id + ' ' + title rule, same kebab→snake section keys, same
strip-one-leading/one-trailing-newline normalization, same typed-section
reconstruction (expect-valid→'1'/'0', expect-codes→comma-joined atom names).
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

from . import ast as _ast
from .ast import Element, RawText, Text, Scalar, parse as _parse
from .ast import is_atom, atom_name


@dataclass
class FixtureCase:
    name: str = ""                       # legacy test name: id, plus ' ' + title when titled
    level: str = ""                      # '' when the case carried no level
    tags: list = field(default_factory=list)
    meta: dict = field(default_factory=dict)   # extra header lines: view/kind/note/chunk_at/pending/…
    sections: dict = field(default_factory=dict)  # legacy section key -> normalized body
    order: list = field(default_factory=list)     # section keys, document order


def load_fixtures(path: str) -> list[FixtureCase]:
    """Parse a ``.cxd`` conformance suite and return its cases."""
    with open(path, "r", encoding="utf-8") as f:
        src = f.read()
    return parse_fixture_suite(src, path)


def parse_fixture_suite(src: str, path: str = "<string>") -> list[FixtureCase]:
    """Parse suite text already in memory (``path`` is for error messages).

    Uses ``cxlib.parse`` (the single-document entry point). A suite payload
    may contain a ``---`` line inside a RawText block (CX multi-doc *examples*
    under test); the lexer consumes ``---`` inside RawText correctly and only
    treats a TOP-LEVEL ``---`` as a separator, so such a suite parses to a
    single intact document.
    """
    doc = _parse(src)
    cases: list[FixtureCase] = []
    root = doc.root()
    if root is None:
        return cases
    # Mirror fixture_loader.v: only a top-level [test-suite] with [case]
    # children contributes cases.
    if getattr(root, "name", "") == "test-suite":
        for child in root.items:
            if isinstance(child, Element) and child.name == "case":
                cases.append(_fixture_case_from(child))
    return cases


def _fixture_case_from(c: Element) -> FixtureCase:
    fc = FixtureCase()
    cid = ""
    for a in c.attrs:
        if a.name == "id":
            cid = _scalar_str(a.value)
        elif a.name == "level":
            fc.level = _scalar_str(a.value)
    title = ""
    for child in c.items:
        if not isinstance(child, Element):
            continue
        name = child.name
        if name == "title":
            title = _rawtext(child)              # inline [#…#] — exact, no normalize
        elif name == "tags":
            fc.tags = [t for t in _text(child).replace("\t", " ").split(" ") if t]
        elif name == "meta":
            body = _normalize(_rawtext(child))
            for line in body.split("\n"):
                idx = line.find(":")
                if idx < 0:
                    continue
                fc.meta[line[:idx].strip()] = line[idx + 1:].strip()
        elif name == "expect-valid":
            fc.sections["sv_assert_valid"] = "1" if _bool(child) else "0"
            fc.order.append("sv_assert_valid")
        elif name == "expect-codes":
            fc.sections["sv_expected_codes"] = _atom_csv(child)
            fc.order.append("sv_expected_codes")
        elif name == "expect-warn-codes":
            fc.sections["sv_expected_warn_codes"] = _atom_csv(child)
            fc.order.append("sv_expected_warn_codes")
        else:
            key = name.replace("-", "_")
            fc.sections[key] = _normalize(_rawtext(child))
            fc.order.append(key)
    fc.name = f"{cid} {title}" if title != "" else cid
    return fc


def _rawtext(e: Element) -> str:
    """Concatenate the RawText payload(s) of a section element. (A literal
    ``#]`` in the payload is carried as adjacent RawText siblings;
    concatenation rejoins them.)"""
    s = ""
    for it in e.items:
        if isinstance(it, RawText):
            s += it.value
    return s


def _text(e: Element) -> str:
    """Join text/scalar body (used for the tags line)."""
    s = ""
    for it in e.items:
        if isinstance(it, Text):
            s += it.value
        elif isinstance(it, Scalar):
            s += _scalar_str(it.value)
    return s


def _normalize(raw: str) -> str:
    """Loader rule: strip one leading and one trailing newline (the ones
    introduced by the ``[#`` ⏎ … ⏎ ``#]`` layout)."""
    s = raw
    if s.startswith("\n"):
        s = s[1:]
    if s.endswith("\n"):
        s = s[:-1]
    return s


def _bool(e: Element) -> bool:
    for it in e.items:
        if isinstance(it, Scalar) and isinstance(it.value, bool):
            return it.value
    return False


def _atom_csv(e: Element) -> str:
    """Comma-join the atom names inside an array-literal section body —
    mirrors fixture_atom_csv (sv_expected_codes / sv_expected_warn_codes)."""
    names: list[str] = []
    for it in e.items:
        items = getattr(it, "items", None)
        if items is None:
            continue
        for item in items:
            if isinstance(item, Scalar):
                if item.data_type == "atom":
                    names.append(atom_name(item.value) if is_atom(item.value) else str(item.value))
                elif isinstance(item.value, str):
                    names.append(item.value)
    return ",".join(names)


def _scalar_str(v) -> str:
    """Render an attr/scalar value to its plain string form."""
    if is_atom(v):
        return atom_name(v)
    if isinstance(v, bool):
        return "true" if v else "false"
    if v is None:
        return "null"
    return str(v)
