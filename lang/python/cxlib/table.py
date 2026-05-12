"""CX Python binding — Public Table API per ADR 0018 D1.

Implements the 17-member canonical Table API surface against the V
core's `:table` blocks via the C ABI. Adopters import `cxlib.Table`
and call `Table.from_cx(src)` (or `Table.from_cx_all(src)` for
multi-table sources) to get a Table instance; the 17 methods provide
the public surface.

Per ADR 0018 §D2 per-binding naming: Python uses snake_case matching
the canonical surface exactly. `select` is renamed to `select_cols`
to avoid shadowing the standard-library `select` module.
"""

from __future__ import annotations

import json
from typing import Any, Iterator, Optional

from . import data_bin as _data_bin
from . import cx as _cx


class Table:
    """Immutable handle over a single `:table` block from a CX source.

    Per ADR 0018 §D3 tables are immutable values; modification returns
    a new Table. Cells admit any of the ADR 0017 §D5 Item kinds
    (scalars + Array / Map / Sequence). Arrays/maps materialize as
    Python `list` / `dict` respectively at the data-binding layer.
    """

    __slots__ = ("_cols", "_types", "_rows")

    def __init__(self, cols: list[str], types: list[str],
                 rows: list[list[Any]]):
        """Construct directly from cols / types / rows. Validates the
        4 invariants per ADR 0018 §D7. Adopters typically use
        `Table.from_cx(src)` instead.
        """
        if len(cols) != len(types):
            raise ValueError(
                f"cxlib: len(cols)={len(cols)} != len(types)={len(types)}"
            )
        seen: set[str] = set()
        for c in cols:
            if c in seen:
                raise ValueError(f'cxlib: duplicate column name "{c}"')
            seen.add(c)
        for row_idx, row in enumerate(rows):
            if len(row) != len(cols):
                raise ValueError(
                    f"cxlib: row {row_idx} has {len(row)} cells; "
                    f"expected {len(cols)}"
                )
        self._cols = list(cols)
        self._types = list(types)
        self._rows = [list(r) for r in rows]

    # ── Construction ─────────────────────────────────────────────────────────

    @classmethod
    def from_cx(cls, src: str) -> "Table":
        """Parse CX source and return the first `:table` block as a Table.

        Errors when the source contains no `:table` block; use
        `Table.from_cx_all(src)` for multi-table sources.
        """
        tables = cls.from_cx_all(src)
        if not tables:
            raise ValueError("cxlib: no :table block found in source")
        return tables[0]

    @classmethod
    def from_cx_all(cls, src: str) -> list["Table"]:
        """Parse CX source and return every `:table` block in document
        order. Walks the data_bin decode result recursively to find
        tables at any nesting depth.
        """
        # cx_to_data_bin produces FRAMED bytes (4-byte LE size + payload).
        # data_bin.decode handles the framing.
        framed = _cx.to_data_bin(src)
        decoded = _data_bin.decode(framed)
        tables: list[Table] = []
        _collect_tables(decoded, tables)
        return tables

    # ── Properties (4) ───────────────────────────────────────────────────────

    @property
    def cols(self) -> list[str]:
        """Ordered list of column names."""
        return list(self._cols)

    @property
    def types(self) -> list[str]:
        """Ordered list of column types (canonical string form, e.g.
        'int', 'string', 'bool'). Empty string means string default."""
        return list(self._types)

    @property
    def row_count(self) -> int:
        return len(self._rows)

    @property
    def col_count(self) -> int:
        return len(self._cols)

    # ── Access (9) ───────────────────────────────────────────────────────────

    def row(self, i: int) -> dict[str, Any]:
        """Row at index i as an ordered map."""
        if i < 0 or i >= len(self._rows):
            raise IndexError(
                f"cxlib: row index {i} out of bounds "
                f"[0, {len(self._rows)})"
            )
        return dict(zip(self._cols, self._rows[i]))

    def column(self, name: str) -> list[Any]:
        """All values in the named column, in row order."""
        try:
            col_idx = self._cols.index(name)
        except ValueError:
            raise KeyError(f'cxlib: unknown column "{name}"')
        return self.col_at(col_idx)

    def col_at(self, i: int) -> list[Any]:
        if i < 0 or i >= len(self._cols):
            raise IndexError(
                f"cxlib: column index {i} out of bounds "
                f"[0, {len(self._cols)})"
            )
        return [row[i] for row in self._rows]

    def cell(self, r: int, c: int) -> Any:
        if r < 0 or r >= len(self._rows):
            raise IndexError(
                f"cxlib: row index {r} out of bounds "
                f"[0, {len(self._rows)})"
            )
        if c < 0 or c >= len(self._cols):
            raise IndexError(
                f"cxlib: column index {c} out of bounds "
                f"[0, {len(self._cols)})"
            )
        return self._rows[r][c]

    def cell_by_name(self, r: int, name: str) -> Any:
        try:
            c = self._cols.index(name)
        except ValueError:
            raise KeyError(f'cxlib: unknown column "{name}"')
        return self.cell(r, c)

    def slice(self, start: int, end: int) -> "Table":
        if start < 0 or start > len(self._rows):
            raise IndexError(f"cxlib: slice start {start} out of bounds")
        if end < start or end > len(self._rows):
            raise IndexError(
                f"cxlib: slice end {end} out of bounds (start={start})"
            )
        new = Table.__new__(Table)
        new._cols = list(self._cols)
        new._types = list(self._types)
        new._rows = [list(r) for r in self._rows[start:end]]
        return new

    def head(self, n: int) -> "Table":
        return self.slice(0, max(0, min(n, len(self._rows))))

    def tail(self, n: int) -> "Table":
        start = max(0, len(self._rows) - n)
        return self.slice(start, len(self._rows))

    def select_cols(self, names: list[str]) -> "Table":
        """New Table with only the named columns, in the given order.

        Renamed from canonical `select` to avoid shadowing the
        standard-library `select` module name in Python.
        """
        indices: list[int] = []
        new_cols: list[str] = []
        new_types: list[str] = []
        for name in names:
            try:
                idx = self._cols.index(name)
            except ValueError:
                raise KeyError(f'cxlib: unknown column "{name}"')
            indices.append(idx)
            new_cols.append(self._cols[idx])
            new_types.append(self._types[idx])
        new_rows = [[row[i] for i in indices] for row in self._rows]
        new = Table.__new__(Table)
        new._cols = new_cols
        new._types = new_types
        new._rows = new_rows
        return new

    # ── Iteration (2) ────────────────────────────────────────────────────────

    def __iter__(self) -> Iterator[dict[str, Any]]:
        """`for row in t` yields ordered maps in row order."""
        for i in range(len(self._rows)):
            yield self.row(i)

    def iter_cols(self) -> Iterator[tuple[str, str, list[Any]]]:
        """Yields (name, type_name, values) per column in declaration
        order."""
        for i, name in enumerate(self._cols):
            yield (name, self._types[i], self.col_at(i))

    # ── Conversion (5) ───────────────────────────────────────────────────────

    def to_cx(self) -> str:
        """Canonical CX text — the `:table` block form per ADR 0018 §D6
        + spec/canonical.md §2.11.
        """
        header_parts = []
        for name, type_name in zip(self._cols, self._types):
            if type_name == "":
                header_parts.append(name)
            else:
                header_parts.append(f"{name}:{type_name}")
        header = " ".join(header_parts)
        lines = [f"[_ :table[{header}]"]
        for row in self._rows:
            cells = [_format_cx_cell(v) for v in row]
            lines.append("  " + " ".join(cells))
        lines.append("]")
        return "\n".join(lines) + "\n"

    def to_csv(self, delim: str = ",") -> str:
        """CSV (comma-separated) by default; pass `delim` for other
        single-char delimiters per ADR 0001 §D6. Collection cells emit
        as JSON-encoded strings per ADR 0001 §D7 / ADR 0018 §D6.
        """
        if len(delim) != 1:
            raise ValueError(
                f"cxlib: to_csv delim must be 1 char; got {len(delim)}"
            )
        out_lines = [delim.join(self._cols)]
        for row in self._rows:
            cells = [_format_csv_cell(v, delim) for v in row]
            out_lines.append(delim.join(cells))
        return "\r\n".join(out_lines) + "\r\n"

    def to_json(self) -> str:
        """Semantic JSON: list of row objects with cells as host-native
        JSON (Array → JSON array, Map → JSON object, scalars → JSON
        scalars). Per ADR 0018 §D6.
        """
        return json.dumps(self.to_dict_list(), separators=(",", ":"))

    def to_data_bin(self) -> bytes:
        """CXDB binary form via cx_to_data_bin. Plain `0x60` form for
        collection-cell tables (per Phase 2.2 wire-format rule);
        chunked `0x63` form is scalar-only and routed automatically.
        """
        return _cx.to_data_bin(self.to_cx())

    def to_dict_list(self) -> list[dict[str, Any]]:
        """Eager copy — each row materializes as a separate dict."""
        return [self.row(i) for i in range(len(self._rows))]

    # ── Equality ─────────────────────────────────────────────────────────────

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, Table):
            return False
        return (
            self._cols == other._cols
            and self._types == other._types
            and self._rows == other._rows
        )

    def __repr__(self) -> str:
        return (
            f"Table(cols={self._cols!r}, types={self._types!r}, "
            f"rows={len(self._rows)})"
        )


# ── Internal: walk a decoded data_bin payload to find tables ─────────────────

def _collect_tables(value: Any, out: list[Table]) -> None:
    """Recursively walk a data_bin decode result, looking for tables.

    Python's data_bin decoder represents tables as `list[dict[str, Any]]`
    — list of row dicts where keys are column names. We detect tables
    by: a non-empty list of dicts where all dicts share the same key
    set (and that key set is non-empty). Nested structures recurse.

    Note: this is a heuristic; the data_bin format itself does not
    carry an explicit "this is a table" marker post-decode in the
    Python representation. For unambiguous table detection we'd need
    to extend the decoder to mark table values — followup item.
    """
    if isinstance(value, dict):
        for child in value.values():
            _collect_tables(child, out)
    elif isinstance(value, list):
        if _looks_like_table(value):
            cols = list(value[0].keys())
            # Types not preserved by data_bin decode; default to empty
            # string (string). Followup: extend decoder to carry types.
            types = [""] * len(cols)
            rows = [[row[c] for c in cols] for row in value]
            out.append(Table(cols=cols, types=types, rows=rows))
        else:
            for child in value:
                _collect_tables(child, out)


def _looks_like_table(value: list) -> bool:
    if not value:
        return False
    if not all(isinstance(item, dict) for item in value):
        return False
    keys = set(value[0].keys())
    if not keys:
        return False
    return all(set(item.keys()) == keys for item in value)


# ── Internal: cell formatters ─────────────────────────────────────────────────

def _format_cx_cell(v: Any) -> str:
    """Canonical CX cell rendering per ADR 0017 §D14."""
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, list):
        # Array literal
        return "[" + ", ".join(_format_cx_cell(item) for item in v) + "]"
    if isinstance(v, dict):
        # Map literal — keys lex-sorted per ADR 0017 §D14 canonical
        items = sorted(v.items())
        return "{" + ", ".join(
            f"{_format_cx_key(k)}: {_format_cx_cell(val)}"
            for k, val in items
        ) + "}"
    # String — quote if it contains whitespace / special chars
    s = str(v)
    if (not s) or any(c in s for c in (" \t\n'[](){},")):
        # Prefer single-quotes; escape internal single quotes with doubling.
        return "'" + s.replace("'", "''") + "'"
    return s


def _format_cx_key(k: Any) -> str:
    """Map-key rendering: bare-name when possible, quoted otherwise."""
    s = str(k)
    if s.isidentifier() and not any(c in s for c in "-:"):
        return s
    return "'" + s.replace("'", "''") + "'"


def _format_csv_cell(v: Any, delim: str) -> str:
    """CSV cell — collection cells emit as JSON-encoded strings per
    ADR 0001 §D7.
    """
    if v is None:
        return ""
    if isinstance(v, (list, dict)):
        # JSON-encode then quote per CSV rules.
        json_str = json.dumps(v, separators=(",", ":"))
        return '"' + json_str.replace('"', '""') + '"'
    if isinstance(v, bool):
        return "true" if v else "false"
    s = str(v)
    if delim in s or '"' in s or "\n" in s or "\r" in s:
        return '"' + s.replace('"', '""') + '"'
    return s
