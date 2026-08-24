"""Regression tests for the CX-native Python fixture loader
(cxlib.load_fixtures) — the Python mirror of vcx/fixtures/fixture_loader.v.

Includes a parser canary (inline, file-free bootstrap guard, mirroring the
V-side test_loader_parser_canary) plus a parity smoke over code.cxd (case
count derived from the file, not hardcoded; `---` inside RawText, `#]`
splits). The canary keeps the loader's parse path honest even if the .cxd
files are absent or relocated.

Exit codes: 0 = all pass, 1 = a check failed.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import cxlib  # noqa: E402


def _conformance(name: str) -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(here, "..", "..", "conformance", name))


def test_parser_canary() -> None:
    """Parse a tiny INLINE .cxd-shaped document — no file load — and assert
    the loader reconstructs legacy-shaped fields. Bootstrap guard: if the
    parser/loader path breaks, this fails without depending on any file."""
    src = (
        "[test-suite\n"
        "[case id=canary-001 level=core\n"
        "[tags a b c]\n"
        "[in-cx [#\n[doc [x 1]]\n#]]\n"
        "[in-code [#\n[?find [x]]\n#]]\n"
        "[out-text [#\n[x 1]\n#]]\n"
        "]\n"
        "]"
    )
    cases = cxlib.parse_fixture_suite(src, "<canary>")
    assert len(cases) == 1, f"expected 1 case, got {len(cases)}"
    c = cases[0]
    assert c.name == "canary-001", c.name
    assert c.level == "core", c.level
    assert c.tags == ["a", "b", "c"], c.tags
    # RawText bodies: one leading + one trailing newline stripped.
    assert c.sections["in_cx"] == "[doc [x 1]]", repr(c.sections["in_cx"])
    assert c.sections["in_code"] == "[?find [x]]", repr(c.sections["in_code"])
    assert c.sections["out_text"] == "[x 1]", repr(c.sections["out_text"])
    assert c.order == ["in_cx", "in_code", "out_text"], c.order


def test_rawtext_with_top_level_dashes() -> None:
    """A `---` line inside a RawText payload must NOT split the suite — the
    loader's parse path must keep it as one document (Task 1 regression)."""
    src = (
        "[test-suite\n"
        "[case id=multidoc-001\n"
        "[in-cx [#\n[a]\n---\n[b]\n#]]\n"
        "]\n"
        "]"
    )
    cases = cxlib.parse_fixture_suite(src, "<canary>")
    assert len(cases) == 1, f"expected 1 case, got {len(cases)}"
    assert cases[0].sections["in_cx"] == "[a]\n---\n[b]", repr(cases[0].sections["in_cx"])


def test_collection_decode() -> None:
    """Regression: cxlib's binary decoder must consume the v0.8.0 collection
    node tags (0x0F SequenceNode / 0x10 ArrayNode / 0x11 MapNode). Before the
    fix these hit the no-payload 0xFF fallback and desynced the stream — one
    array silently dropped content; an array followed by a sibling crashed
    with IndexError / UnicodeDecodeError. This is what blocked schema_validate
    (`[expect-codes [:Sxxx]]` atom arrays)."""
    # An atom array followed by a sibling — the exact desync shape.
    d = cxlib.parse("[s [a [:S002]] [b [:S003]]]")
    s = d.root()
    assert s.name == "s" and len(s.items) == 2, s
    arr = s.items[0].items[0]               # the [:S002] ArrayNode
    assert hasattr(arr, "items") and len(arr.items) == 1, arr
    # Sequence + nested array + map all decode without desync.
    cxlib.parse("[x (1, 2, 3)]")
    cxlib.parse("[x [1, 2, 3]]")
    cxlib.parse("[x {k: 1, j: 2}]")


def test_expect_codes_atom_array() -> None:
    """The loader reconstructs sv_expected_codes from an atom-array section
    body — end-to-end over schema_validate.cxd (previously un-loadable)."""
    path = _conformance("schema_validate.cxd")
    if not os.path.exists(path):
        return
    cases = cxlib.load_fixtures(path)
    assert len(cases) > 0
    sv002 = next((c for c in cases if c.name.startswith("sv-002")), None)
    assert sv002 is not None, "missing sv-002"
    assert sv002.sections.get("sv_expected_codes") == "S002", sv002.sections


def test_code_cxd_smoke() -> None:
    """Parity smoke over the real code.cxd corpus.

    The Python loader must read exactly the cases present in the file. The
    expected count is DERIVED from the file (top-level `[case id=` markers),
    so it tracks the corpus automatically — no hand-maintained magic number —
    while still catching a loader that drops or duplicates cases.
    """
    path = _conformance("code.cxd")
    if not os.path.exists(path):
        return  # safe no-op before the file exists
    cases = cxlib.load_fixtures(path)
    with open(path, encoding="utf-8") as fh:
        expected = sum(1 for line in fh if line.lstrip().startswith("[case id="))
    assert expected > 0, "code.cxd has no `[case id=` markers — corpus moved?"
    assert len(cases) == expected, (
        f"loader read {len(cases)} cases; file has {expected} `[case id=` markers"
    )
    by_id = {c.name: c for c in cases}
    # A representative case with in_cx / in_code / out_text sections.
    c = by_id.get("program-for-001-all-emails")
    assert c is not None, "missing program-for-001-all-emails"
    assert c.level == "core", c.level
    assert "in_cx" in c.sections and "in_code" in c.sections


def _run() -> int:
    failures = []
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            try:
                fn()
            except AssertionError as exc:
                failures.append(f"{name}: {exc}")
            except Exception as exc:  # noqa: BLE001
                failures.append(f"{name}: {type(exc).__name__}: {exc}")
    if failures:
        print(f"{len(failures)} fixture-loader check(s) failed:")
        for f in failures:
            print(f"  {f}")
        return 1
    print("OK: cxlib.load_fixtures canary + code.cxd smoke pass")
    return 0


if __name__ == "__main__":
    sys.exit(_run())
