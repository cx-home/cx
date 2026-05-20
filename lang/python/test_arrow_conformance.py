"""Cross-binding Arrow conformance runner (W3 / v0.7.0).

Reads conformance/data_bin_arrow.txt — the canonical Arrow C-Data
round-trip fixture corpus — and runs each test through the Python
binding's cxlib.arrow path. Asserts on:

  - in_cx → emit_data_bin_chunked → cxa.export(...) → import_to_data_bin
    round-trips without losing data
  - per-column Arrow format strings (arrow_children_formats) match
    what the Python pyarrow.Schema reports
  - emitted CX text contains every value listed under expect_values
  - negative tests with expected_export_error surface the documented
    substring

This file is invoked by `make test-python-arrow-conformance`. Other
bindings will mirror the pattern with their own conformance runners
that consume the same fixture file — that's the cross-binding-
parity gate (W9).
"""

from __future__ import annotations

import os
import re
import sys
import unittest

try:
    import pyarrow as pa  # type: ignore
except ImportError:
    pa = None

THIS_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(THIS_DIR, '..', '..'))
FIXTURE_PATH = os.path.join(REPO_ROOT, 'conformance', 'data_bin_arrow.txt')

sys.path.insert(0, os.path.join(REPO_ROOT, 'lang', 'python'))

try:
    import cxlib  # type: ignore
    from cxlib import arrow as cxa  # type: ignore
    _import_err: Exception | None = None
except Exception as e:  # pragma: no cover — surface load failures
    cxlib = None  # type: ignore
    cxa = None    # type: ignore
    _import_err = e


# ── Fixture parser ─────────────────────────────────────────────────────

_SECTION_RE = re.compile(r'^---\s+([\w-]+)\s*$')
_TEST_RE = re.compile(r'^===\s+test:\s+(\S+)\s*$')
_HEADER_KV_RE = re.compile(r'^(\w+):\s*(.+?)\s*$')


def _parse_fixtures(path: str) -> list[dict]:
    """Parse the conformance file into a list of test dicts."""
    tests: list[dict] = []
    cur: dict | None = None
    section: str | None = None
    section_lines: list[str] = []

    def flush_section():
        if cur is None or section is None:
            return
        cur.setdefault('sections', {})[section] = '\n'.join(section_lines)

    with open(path, 'r', encoding='utf-8') as f:
        for raw in f:
            line = raw.rstrip('\n')
            if line.startswith('# '):
                continue
            m = _TEST_RE.match(line)
            if m:
                flush_section()
                if cur is not None:
                    tests.append(cur)
                cur = {'name': m.group(1), 'headers': {}, 'sections': {}}
                section = None
                section_lines = []
                continue
            m = _SECTION_RE.match(line)
            if m:
                flush_section()
                section = m.group(1)
                section_lines = []
                continue
            if section is not None:
                section_lines.append(line)
                continue
            m = _HEADER_KV_RE.match(line)
            if m and cur is not None:
                cur['headers'][m.group(1)] = m.group(2)

    flush_section()
    if cur is not None:
        tests.append(cur)
    return tests


# ── Test execution ─────────────────────────────────────────────────────

def _build_test_method(fixture: dict):
    name = fixture['name']

    def method(self):
        if cxa is None or cxlib is None:
            self.skipTest(f'cxlib import failed: {_import_err}')
        if pa is None:
            self.skipTest('pyarrow not installed')
        if not cxa.available():
            self.skipTest('libcx_arrow not loaded')

        in_cx = fixture['sections'].get('in_cx', '').strip('\n')
        expect_err = fixture['sections'].get('expected_export_error', '').strip()
        formats = fixture['sections'].get('arrow_children_formats', '').strip()
        expect_values = fixture['sections'].get('expect_values', '').strip()

        # Encode CX → CXDB chunked-table.
        try:
            framed = cxlib.to_data_bin_chunked(in_cx)
        except Exception as e:
            if expect_err and expect_err in str(e):
                return  # Negative test: encode-side error matches.
            raise

        # Export to Arrow → consume → import back.
        try:
            reader = cxa.export(framed)
            table = reader.read_all()
        except Exception as e:
            if expect_err and expect_err in str(e):
                return
            raise

        # Schema-format assertion (when present).
        if formats:
            expected_fmts = [ln for ln in formats.splitlines() if ln]
            # pyarrow reports type names, not Arrow format strings; map via
            # the cx convention so comparison is direct.
            actual_fmts = [_pa_type_to_arrow_format(f.type) for f in table.schema]
            self.assertEqual(actual_fmts, expected_fmts,
                f'{name}: arrow_children_formats mismatch')

        # Round-trip import.
        out_bytes = cxa.import_to_data_bin(table)
        table_after = cxa.export(out_bytes).read_all()
        self.assertTrue(
            table.equals(table_after),
            f'{name}: round-trip pyarrow.Table inequality',
        )

        # Value assertion — every line in expect_values must appear
        # somewhere in the post-round-trip CX text.
        if expect_values:
            cx_text = cxlib.from_data_bin(out_bytes)
            for v in expect_values.splitlines():
                v = v.strip()
                if v == '':
                    continue
                self.assertIn(v, cx_text,
                    f'{name}: expected value "{v}" not in round-trip output')

    method.__name__ = f'test_{name.replace("-", "_")}'
    return method


def _pa_type_to_arrow_format(t) -> str:
    """Map pyarrow.DataType → Arrow C-Data format string (cx convention)."""
    s = str(t)
    return {
        'int64':     'l',
        'int8':      'c',
        'int16':     's',
        'int32':     'i',
        'double':    'g',
        'bool':      'b',
        'string':    'u',
        'utf8':      'u',
        'date32[day]':              'tdD',
        'timestamp[ns, tz=UTC]':    'tsn:UTC',
        'binary':    'z',
    }.get(s, s)


class ArrowConformance(unittest.TestCase):
    """Populated dynamically below from the conformance corpus."""
    pass


if os.path.exists(FIXTURE_PATH):
    _fixtures = _parse_fixtures(FIXTURE_PATH)
    for _fx in _fixtures:
        setattr(ArrowConformance, f'test_{_fx["name"].replace("-", "_")}',
                _build_test_method(_fx))
else:
    raise FileNotFoundError(f'conformance fixture not found at {FIXTURE_PATH}')


if __name__ == '__main__':
    unittest.main(verbosity=2)
