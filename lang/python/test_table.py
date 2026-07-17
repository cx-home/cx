"""Public Table API tests — Python binding.

stdlib-unittest only (no pytest dep) so the `test-python` Makefile lane
can run it with a bare interpreter, matching its siblings.

Run from the repo root:

    cd lang/python && python3 -m unittest test_table -v
"""
from __future__ import annotations

import json
import os
import sys
import unittest

# Allow `python3 -m unittest test_table` from lang/python/.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import cxlib  # noqa: E402,F401
from cxlib import Table  # noqa: E402


# ── Construction ─────────────────────────────────────────────────────────────

class TestConstruction(unittest.TestCase):

    def test_from_cx_simple_table(self):
        src = """[users [table[name age::int]]
  alice 30
  bob 25
]"""
        t = Table.from_cx(src)
        self.assertEqual(t.cols, ["name", "age"])
        self.assertEqual(t.row_count, 2)
        self.assertEqual(t.col_count, 2)

    def test_from_cx_no_table_errors(self):
        with self.assertRaisesRegex(ValueError, "no :table"):
            Table.from_cx("[product name=alice]")

    def test_from_cx_all_finds_multiple(self):
        src = """[doc
  [t1 [table[a]] x]
  [t2 [table[b]] y]
]"""
        tables = Table.from_cx_all(src)
        # At least the inner tables should be found.
        self.assertGreaterEqual(len(tables), 1)

    def test_new_validates_len_mismatch(self):
        with self.assertRaisesRegex(ValueError, "len.cols"):
            Table(cols=["a", "b"], types=["int"], rows=[])

    def test_new_validates_unique_cols(self):
        with self.assertRaisesRegex(ValueError, "duplicate"):
            Table(cols=["a", "a"], types=["int", "int"], rows=[])

    def test_new_validates_row_width(self):
        with self.assertRaisesRegex(ValueError, "cells"):
            Table(cols=["a", "b"], types=["int", "int"], rows=[[1]])


# ── Properties ───────────────────────────────────────────────────────────────

class TestProperties(unittest.TestCase):

    def test_properties(self):
        t = Table(cols=["a", "b"], types=["int", "string"],
                  rows=[[1, "x"], [2, "y"]])
        self.assertEqual(t.cols, ["a", "b"])
        self.assertEqual(t.types, ["int", "string"])
        self.assertEqual(t.row_count, 2)
        self.assertEqual(t.col_count, 2)


# ── Access ───────────────────────────────────────────────────────────────────

class TestAccess(unittest.TestCase):

    def test_row(self):
        t = Table(cols=["a", "b"], types=["int", "string"],
                  rows=[[1, "x"], [2, "y"]])
        self.assertEqual(t.row(0), {"a": 1, "b": "x"})
        self.assertEqual(t.row(1), {"a": 2, "b": "y"})

    def test_row_out_of_bounds(self):
        t = Table(cols=["a"], types=["int"], rows=[[1]])
        with self.assertRaisesRegex(IndexError, "out of bounds"):
            t.row(5)

    def test_column_by_name(self):
        t = Table(cols=["a", "b"], types=["int", "string"],
                  rows=[[1, "x"], [2, "y"]])
        self.assertEqual(t.column("a"), [1, 2])
        self.assertEqual(t.column("b"), ["x", "y"])

    def test_column_unknown(self):
        t = Table(cols=["a"], types=["int"], rows=[])
        with self.assertRaisesRegex(KeyError, "unknown column"):
            t.column("missing")

    def test_cell(self):
        t = Table(cols=["a", "b"], types=["int", "string"],
                  rows=[[1, "x"], [2, "y"]])
        self.assertEqual(t.cell(1, 0), 2)
        self.assertEqual(t.cell_by_name(1, "b"), "y")

    def test_slice_head_tail(self):
        t = Table(cols=["v"], types=["int"], rows=[[i] for i in range(5)])
        self.assertEqual(t.head(2).row_count, 2)
        self.assertEqual(t.tail(2).row_count, 2)
        self.assertEqual(t.slice(1, 4).row_count, 3)

    def test_select_cols_reorders(self):
        t = Table(cols=["a", "b", "c"], types=["int", "int", "int"],
                  rows=[[1, 2, 3]])
        sel = t.select_cols(["c", "a"])
        self.assertEqual(sel.cols, ["c", "a"])
        self.assertEqual(sel.row(0), {"c": 3, "a": 1})


# ── Iteration ────────────────────────────────────────────────────────────────

class TestIteration(unittest.TestCase):

    def test_iter_rows(self):
        t = Table(cols=["a"], types=["int"], rows=[[1], [2], [3]])
        rows = list(t)
        self.assertEqual(len(rows), 3)
        self.assertEqual(rows[0], {"a": 1})

    def test_iter_cols(self):
        t = Table(cols=["a", "b"], types=["int", "string"],
                  rows=[[1, "x"], [2, "y"]])
        cols = list(t.iter_cols())
        self.assertEqual(len(cols), 2)
        self.assertEqual(cols[0], ("a", "int", [1, 2]))
        self.assertEqual(cols[1], ("b", "string", ["x", "y"]))


# ── Conversion ───────────────────────────────────────────────────────────────

class TestConversion(unittest.TestCase):

    def test_to_cx_roundtrip(self):
        t = Table(cols=["name", "age"], types=["", "int"],
                  rows=[["alice", 30], ["bob", 25]])
        out = t.to_cx()
        self.assertIn("alice 30", out)
        self.assertIn("bob 25", out)
        self.assertIn("[table[name age::int]]", out)

    def test_to_csv(self):
        t = Table(cols=["name", "age"], types=["", "int"],
                  rows=[["alice", 30], ["bob", 25]])
        csv = t.to_csv()
        self.assertIn("name,age", csv)
        self.assertIn("alice,30", csv)

    def test_to_csv_delim_validation(self):
        t = Table(cols=["a"], types=["int"], rows=[])
        with self.assertRaisesRegex(ValueError, "1 char"):
            t.to_csv(",,")

    def test_to_json_scalar(self):
        t = Table(cols=["name", "age"], types=["", "int"],
                  rows=[["alice", 30]])
        js = json.loads(t.to_json())
        self.assertEqual(js, [{"name": "alice", "age": 30}])

    def test_to_json_collection_cells(self):
        # When loaded from CX with collection cells, the Table should
        # carry list/dict values; to_json emits them natively.
        t = Table(cols=["name", "tags"], types=["", ""],
                  rows=[["alice", ["admin", "user"]],
                        ["bob", {"role": "user"}]])
        js = json.loads(t.to_json())
        self.assertEqual(js[0]["tags"], ["admin", "user"])
        self.assertEqual(js[1]["tags"], {"role": "user"})

    def test_to_data_bin_returns_bytes(self):
        t = Table(cols=["a"], types=["int"], rows=[[1]])
        bytes_out = t.to_data_bin()
        self.assertIsInstance(bytes_out, bytes)
        self.assertGreater(len(bytes_out), 4)  # at least size header

    def test_to_dict_list(self):
        t = Table(cols=["a"], types=["int"], rows=[[1], [2]])
        dl = t.to_dict_list()
        self.assertEqual(dl, [{"a": 1}, {"a": 2}])


# ── Equality ─────────────────────────────────────────────────────────────────

class TestEquality(unittest.TestCase):

    def test_equality(self):
        t1 = Table(cols=["a"], types=["int"], rows=[[1]])
        t2 = Table(cols=["a"], types=["int"], rows=[[1]])
        t3 = Table(cols=["a"], types=["int"], rows=[[2]])
        self.assertEqual(t1, t2)
        self.assertNotEqual(t1, t3)
        self.assertNotEqual(t1, "not a table")


if __name__ == "__main__":
    unittest.main()
