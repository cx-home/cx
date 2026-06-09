"""Public Table API tests — Python binding."""

import json
import sys
import pytest

import cxlib
from cxlib import Table


# ── Construction ─────────────────────────────────────────────────────────────

def test_from_cx_simple_table():
    src = """[users [table[name age::int]]
  alice 30
  bob 25
]"""
    t = Table.from_cx(src)
    assert t.cols == ["name", "age"]
    assert t.row_count == 2
    assert t.col_count == 2


def test_from_cx_no_table_errors():
    with pytest.raises(ValueError, match="no :table"):
        Table.from_cx("[product name=alice]")


def test_from_cx_all_finds_multiple():
    src = """[doc
  [t1 [table[a]] x]
  [t2 [table[b]] y]
]"""
    tables = Table.from_cx_all(src)
    # At least the inner tables should be found.
    assert len(tables) >= 1


def test_new_validates_len_mismatch():
    with pytest.raises(ValueError, match="len.cols"):
        Table(cols=["a", "b"], types=["int"], rows=[])


def test_new_validates_unique_cols():
    with pytest.raises(ValueError, match="duplicate"):
        Table(cols=["a", "a"], types=["int", "int"], rows=[])


def test_new_validates_row_width():
    with pytest.raises(ValueError, match="cells"):
        Table(cols=["a", "b"], types=["int", "int"], rows=[[1]])


# ── Properties ───────────────────────────────────────────────────────────────

def test_properties():
    t = Table(cols=["a", "b"], types=["int", "string"],
              rows=[[1, "x"], [2, "y"]])
    assert t.cols == ["a", "b"]
    assert t.types == ["int", "string"]
    assert t.row_count == 2
    assert t.col_count == 2


# ── Access ───────────────────────────────────────────────────────────────────

def test_row():
    t = Table(cols=["a", "b"], types=["int", "string"],
              rows=[[1, "x"], [2, "y"]])
    assert t.row(0) == {"a": 1, "b": "x"}
    assert t.row(1) == {"a": 2, "b": "y"}


def test_row_out_of_bounds():
    t = Table(cols=["a"], types=["int"], rows=[[1]])
    with pytest.raises(IndexError, match="out of bounds"):
        t.row(5)


def test_column_by_name():
    t = Table(cols=["a", "b"], types=["int", "string"],
              rows=[[1, "x"], [2, "y"]])
    assert t.column("a") == [1, 2]
    assert t.column("b") == ["x", "y"]


def test_column_unknown():
    t = Table(cols=["a"], types=["int"], rows=[])
    with pytest.raises(KeyError, match="unknown column"):
        t.column("missing")


def test_cell():
    t = Table(cols=["a", "b"], types=["int", "string"],
              rows=[[1, "x"], [2, "y"]])
    assert t.cell(1, 0) == 2
    assert t.cell_by_name(1, "b") == "y"


def test_slice_head_tail():
    t = Table(cols=["v"], types=["int"], rows=[[i] for i in range(5)])
    assert t.head(2).row_count == 2
    assert t.tail(2).row_count == 2
    assert t.slice(1, 4).row_count == 3


def test_select_cols_reorders():
    t = Table(cols=["a", "b", "c"], types=["int", "int", "int"],
              rows=[[1, 2, 3]])
    sel = t.select_cols(["c", "a"])
    assert sel.cols == ["c", "a"]
    assert sel.row(0) == {"c": 3, "a": 1}


# ── Iteration ────────────────────────────────────────────────────────────────

def test_iter_rows():
    t = Table(cols=["a"], types=["int"], rows=[[1], [2], [3]])
    rows = list(t)
    assert len(rows) == 3
    assert rows[0] == {"a": 1}


def test_iter_cols():
    t = Table(cols=["a", "b"], types=["int", "string"],
              rows=[[1, "x"], [2, "y"]])
    cols = list(t.iter_cols())
    assert len(cols) == 2
    assert cols[0] == ("a", "int", [1, 2])
    assert cols[1] == ("b", "string", ["x", "y"])


# ── Conversion ───────────────────────────────────────────────────────────────

def test_to_cx_roundtrip():
    t = Table(cols=["name", "age"], types=["", "int"],
              rows=[["alice", 30], ["bob", 25]])
    out = t.to_cx()
    assert "alice 30" in out
    assert "bob 25" in out
    assert "[table[name age::int]]" in out


def test_to_csv():
    t = Table(cols=["name", "age"], types=["", "int"],
              rows=[["alice", 30], ["bob", 25]])
    csv = t.to_csv()
    assert "name,age" in csv
    assert "alice,30" in csv


def test_to_csv_delim_validation():
    t = Table(cols=["a"], types=["int"], rows=[])
    with pytest.raises(ValueError, match="1 char"):
        t.to_csv(",,")


def test_to_json_scalar():
    t = Table(cols=["name", "age"], types=["", "int"],
              rows=[["alice", 30]])
    js = json.loads(t.to_json())
    assert js == [{"name": "alice", "age": 30}]


def test_to_json_collection_cells():
    # When loaded from CX with collection cells, the Table should
    # carry list/dict values; to_json emits them natively.
    t = Table(cols=["name", "tags"], types=["", ""],
              rows=[["alice", ["admin", "user"]],
                    ["bob", {"role": "user"}]])
    js = json.loads(t.to_json())
    assert js[0]["tags"] == ["admin", "user"]
    assert js[1]["tags"] == {"role": "user"}


def test_to_data_bin_returns_bytes():
    t = Table(cols=["a"], types=["int"], rows=[[1]])
    bytes_out = t.to_data_bin()
    assert isinstance(bytes_out, bytes)
    assert len(bytes_out) > 4  # at least size header


def test_to_dict_list():
    t = Table(cols=["a"], types=["int"], rows=[[1], [2]])
    dl = t.to_dict_list()
    assert dl == [{"a": 1}, {"a": 2}]


# ── Equality ─────────────────────────────────────────────────────────────────

def test_equality():
    t1 = Table(cols=["a"], types=["int"], rows=[[1]])
    t2 = Table(cols=["a"], types=["int"], rows=[[1]])
    t3 = Table(cols=["a"], types=["int"], rows=[[2]])
    assert t1 == t2
    assert t1 != t3
    assert t1 != "not a table"
