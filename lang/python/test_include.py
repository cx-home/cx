"""GG4 — Python parse(include_root=...) regression tests.

Smoke-tests the include resolver wired through cx_to_ast_bin_with_include_root.
The substantive engine coverage lives at vcx/tests/include_test.v (13 V-level
regressions). These tests confirm the per-binding wrapper plumbing is wired.
"""

import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(__file__))

from cxlib.ast import parse


class TestParseWithIncludeRoot(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix='cx_py_inc_')

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp, ignore_errors=True)

    def write(self, rel_path, content):
        full = os.path.join(self.tmp, rel_path)
        os.makedirs(os.path.dirname(full), exist_ok=True) if os.path.dirname(rel_path) else None
        with open(full, 'w') as f:
            f.write(content)

    def test_no_include_root_preserves_directive(self):
        doc = parse('[?cx include=defaults.cx]')
        # Top-level directive ends up in prolog (per is_prolog_node_type)
        self.assertGreaterEqual(len(doc.prolog), 1)

    def test_include_root_splices_top_level_elements(self):
        self.write('defaults.cx', '[server host=localhost]\n[server host=backup]')
        doc = parse(
            '[config\n  [?cx include=defaults.cx]\n  [client retries=3]\n]',
            include_root=self.tmp,
        )
        self.assertEqual(len(doc.elements), 1)
        config = doc.elements[0]
        # 2 servers (from include) + 1 client (trailing) = 3 items
        names = [it.name for it in config.items if hasattr(it, 'name')]
        self.assertEqual(names, ['server', 'server', 'client'])

    def test_e901_absolute_path_rejected(self):
        with self.assertRaises(RuntimeError) as cm:
            parse('[?cx include=/etc/passwd]', include_root=self.tmp)
        self.assertIn('E901', str(cm.exception))

    def test_e902_traversal_rejected(self):
        with self.assertRaises(RuntimeError) as cm:
            parse('[?cx include=../escape.cx]', include_root=self.tmp)
        self.assertIn('E902', str(cm.exception))

    def test_e906_not_found(self):
        with self.assertRaises(RuntimeError) as cm:
            parse('[?cx include=missing.cx]', include_root=self.tmp)
        self.assertIn('E906', str(cm.exception))

    def test_nested_include(self):
        self.write('leaf.cx', '[leaf v=42]')
        self.write('mid.cx', '[mid\n  [?cx include=leaf.cx]\n]')
        doc = parse('[?cx include=mid.cx]', include_root=self.tmp)
        self.assertEqual(len(doc.elements), 1)
        mid = doc.elements[0]
        self.assertEqual(mid.name, 'mid')
        self.assertEqual(len(mid.items), 1)
        leaf = mid.items[0]
        self.assertEqual(leaf.name, 'leaf')


if __name__ == '__main__':
    unittest.main()
