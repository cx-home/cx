//! CX Rust binding — Public Table API.
//!
//! Implements the 17-member canonical Table API surface against the
//! V core's `:table` blocks via the C ABI. Per per-binding
//! naming, Rust uses snake_case methods matching the
//! canonical surface exactly.
//!
//! Cells admit any Item kind — represented as
//! `serde_json::Value` (which natively handles scalars, arrays, and
//! object/maps via its existing variants).
//!
//! Per: tables are immutable values. All methods that
//! produce a new table (`slice`, `head`, `tail`, `select_cols`)
//! return a fresh `Table` rather than mutating in place.

use serde_json::{json, Map, Value};
use std::collections::HashSet;
use std::fmt;

use crate::data_bin;

/// Immutable handle over a single `:table` block.
#[derive(Clone, Debug, PartialEq)]
pub struct Table {
    cols: Vec<String>,
    types: Vec<String>,
    rows: Vec<Vec<Value>>,
}

impl Table {
    // ── Construction ─────────────────────────────────────────────────────────

    /// Parse CX source and return the first `:table` block as a Table.
    /// Errors when the source contains no `:table` block.
    pub fn from_cx(src: &str) -> Result<Self, String> {
        let mut tables = Self::from_cx_all(src)?;
        if tables.is_empty() {
            return Err("cxlib: no :table block found in source".to_string());
        }
        Ok(tables.remove(0))
    }

    /// Return every `:table` block in the source in document order.
    pub fn from_cx_all(src: &str) -> Result<Vec<Self>, String> {
        let framed = data_bin::to_data_bin(src)?;
        let value = data_bin::decode_payload(&framed)?;
        let mut out = Vec::new();
        collect_tables(&value, &mut out);
        Ok(out)
    }

    /// Construct directly with 4-invariant validation.
    pub fn new(
        cols: Vec<String>,
        types: Vec<String>,
        rows: Vec<Vec<Value>>,
    ) -> Result<Self, String> {
        if cols.len() != types.len() {
            return Err(format!(
                "cxlib: len(cols)={} != len(types)={}",
                cols.len(),
                types.len()
            ));
        }
        let mut seen = HashSet::new();
        for c in &cols {
            if !seen.insert(c.clone()) {
                return Err(format!("cxlib: duplicate column name \"{}\"", c));
            }
        }
        for (row_idx, row) in rows.iter().enumerate() {
            if row.len() != cols.len() {
                return Err(format!(
                    "cxlib: row {} has {} cells; expected {}",
                    row_idx,
                    row.len(),
                    cols.len()
                ));
            }
        }
        Ok(Self { cols, types, rows })
    }

    // ── Properties (4) ───────────────────────────────────────────────────────

    pub fn cols(&self) -> &[String] {
        &self.cols
    }

    pub fn types(&self) -> &[String] {
        &self.types
    }

    pub fn row_count(&self) -> usize {
        self.rows.len()
    }

    pub fn col_count(&self) -> usize {
        self.cols.len()
    }

    // ── Access (9) ───────────────────────────────────────────────────────────

    pub fn row(&self, i: usize) -> Result<Map<String, Value>, String> {
        if i >= self.rows.len() {
            return Err(format!(
                "cxlib: row index {} out of bounds [0, {})",
                i,
                self.rows.len()
            ));
        }
        let mut out = Map::new();
        for (c, name) in self.cols.iter().enumerate() {
            out.insert(name.clone(), self.rows[i][c].clone());
        }
        Ok(out)
    }

    pub fn column(&self, name: &str) -> Result<Vec<Value>, String> {
        let idx = self
            .cols
            .iter()
            .position(|c| c == name)
            .ok_or_else(|| format!("cxlib: unknown column \"{}\"", name))?;
        self.col_at(idx)
    }

    pub fn col_at(&self, i: usize) -> Result<Vec<Value>, String> {
        if i >= self.cols.len() {
            return Err(format!(
                "cxlib: column index {} out of bounds [0, {})",
                i,
                self.cols.len()
            ));
        }
        Ok(self.rows.iter().map(|r| r[i].clone()).collect())
    }

    pub fn cell(&self, r: usize, c: usize) -> Result<Value, String> {
        if r >= self.rows.len() {
            return Err(format!(
                "cxlib: row index {} out of bounds [0, {})",
                r,
                self.rows.len()
            ));
        }
        if c >= self.cols.len() {
            return Err(format!(
                "cxlib: column index {} out of bounds [0, {})",
                c,
                self.cols.len()
            ));
        }
        Ok(self.rows[r][c].clone())
    }

    pub fn cell_by_name(&self, r: usize, name: &str) -> Result<Value, String> {
        let idx = self
            .cols
            .iter()
            .position(|c| c == name)
            .ok_or_else(|| format!("cxlib: unknown column \"{}\"", name))?;
        self.cell(r, idx)
    }

    pub fn slice(&self, start: usize, end: usize) -> Result<Self, String> {
        if start > self.rows.len() {
            return Err(format!("cxlib: slice start {} out of bounds", start));
        }
        if end < start || end > self.rows.len() {
            return Err(format!(
                "cxlib: slice end {} out of bounds (start={})",
                end, start
            ));
        }
        Ok(Self {
            cols: self.cols.clone(),
            types: self.types.clone(),
            rows: self.rows[start..end].to_vec(),
        })
    }

    pub fn head(&self, n: usize) -> Self {
        let end = n.min(self.rows.len());
        self.slice(0, end).unwrap()
    }

    pub fn tail(&self, n: usize) -> Self {
        let start = self.rows.len().saturating_sub(n);
        self.slice(start, self.rows.len()).unwrap()
    }

    /// `select_cols` mirrors the canonical `select`.
    /// Renamed because `select` is a Rust reserved-ish word in async
    /// contexts (tokio's `select!` macro shadows it heavily).
    pub fn select_cols(&self, names: &[&str]) -> Result<Self, String> {
        let mut indices = Vec::with_capacity(names.len());
        let mut new_cols = Vec::with_capacity(names.len());
        let mut new_types = Vec::with_capacity(names.len());
        for name in names {
            let idx = self
                .cols
                .iter()
                .position(|c| c == name)
                .ok_or_else(|| format!("cxlib: unknown column \"{}\"", name))?;
            indices.push(idx);
            new_cols.push(self.cols[idx].clone());
            new_types.push(self.types[idx].clone());
        }
        let new_rows = self
            .rows
            .iter()
            .map(|row| indices.iter().map(|&i| row[i].clone()).collect())
            .collect();
        Ok(Self {
            cols: new_cols,
            types: new_types,
            rows: new_rows,
        })
    }

    // ── Iteration (2) ────────────────────────────────────────────────────────

    /// `iter` returns an iterator over rows. Each row is an ordered map.
    /// Use `for row in &table` (via IntoIterator below) for ergonomic
    /// iteration; this method exposes the explicit form.
    pub fn iter(&self) -> impl Iterator<Item = Map<String, Value>> + '_ {
        (0..self.rows.len()).map(move |i| self.row(i).unwrap())
    }

    pub fn iter_cols(&self) -> impl Iterator<Item = ColView<'_>> + '_ {
        self.cols
            .iter()
            .enumerate()
            .map(move |(i, name)| ColView {
                name,
                type_name: &self.types[i],
                values: self.rows.iter().map(|r| r[i].clone()).collect(),
            })
    }

    // ── Conversion (5) ───────────────────────────────────────────────────────

    pub fn to_cx(&self) -> String {
        let header: Vec<String> = self
            .cols
            .iter()
            .zip(self.types.iter())
            .map(|(name, ty)| {
                if ty.is_empty() {
                    name.clone()
                } else {
                    // v0.8.0 table columns use the glued double-colon type
                    // annotation (`name::int`); single `:` is the namespace
                    // qualifier (grammar [26]/[29]).
                    format!("{}::{}", name, ty)
                }
            })
            .collect();
        let mut out = format!("[_ [table[{}]]\n", header.join(" "));
        for row in &self.rows {
            let cells: Vec<String> = row.iter().map(format_cx_cell).collect();
            out.push_str("  ");
            out.push_str(&cells.join(" "));
            out.push('\n');
        }
        out.push_str("]\n");
        out
    }

    pub fn to_csv(&self, delim: char) -> Result<String, String> {
        if !delim.is_ascii() {
            return Err(format!(
                "cxlib: to_csv delim must be ASCII; got {:?}",
                delim
            ));
        }
        let mut out = String::new();
        out.push_str(&self.cols.join(&delim.to_string()));
        out.push_str("\r\n");
        for row in &self.rows {
            let cells: Vec<String> =
                row.iter().map(|v| format_csv_cell(v, delim)).collect();
            out.push_str(&cells.join(&delim.to_string()));
            out.push_str("\r\n");
        }
        Ok(out)
    }

    pub fn to_json(&self) -> Result<String, String> {
        let rows: Vec<Map<String, Value>> = (0..self.rows.len())
            .map(|i| self.row(i).unwrap())
            .collect();
        serde_json::to_string(&rows).map_err(|e| e.to_string())
    }

    pub fn to_data_bin(&self) -> Result<Vec<u8>, String> {
        data_bin::to_data_bin(&self.to_cx())
    }

    pub fn to_dict_list(&self) -> Vec<Map<String, Value>> {
        (0..self.rows.len()).map(|i| self.row(i).unwrap()).collect()
    }
}

/// `ColView` is the (name, type_name, values) triple yielded by `iter_cols`.
pub struct ColView<'a> {
    pub name: &'a str,
    pub type_name: &'a str,
    pub values: Vec<Value>,
}

impl fmt::Display for Table {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.to_cx())
    }
}

// ── Internal: walk a decoded data_bin Value to find tables ───────────────────

fn collect_tables(value: &Value, out: &mut Vec<Table>) {
    match value {
        Value::Object(map) => {
            for v in map.values() {
                collect_tables(v, out);
            }
        }
        Value::Array(arr) => {
            if looks_like_table(arr) {
                let first = arr[0].as_object().unwrap();
                let mut cols: Vec<String> = first.keys().cloned().collect();
                cols.sort();
                let types = vec!["".to_string(); cols.len()];
                let rows: Vec<Vec<Value>> = arr
                    .iter()
                    .map(|item| {
                        let m = item.as_object().unwrap();
                        cols.iter().map(|c| m[c].clone()).collect()
                    })
                    .collect();
                out.push(Table { cols, types, rows });
            } else {
                for child in arr {
                    collect_tables(child, out);
                }
            }
        }
        _ => {}
    }
}

fn looks_like_table(arr: &[Value]) -> bool {
    if arr.is_empty() {
        return false;
    }
    let first = match arr[0].as_object() {
        Some(m) if !m.is_empty() => m,
        _ => return false,
    };
    let keys: HashSet<&String> = first.keys().collect();
    arr.iter().all(|item| {
        let m = match item.as_object() {
            Some(m) => m,
            None => return false,
        };
        if m.len() != keys.len() {
            return false;
        }
        m.keys().all(|k| keys.contains(k))
    })
}

// ── Internal: cell formatters ────────────────────────────────────────────────

fn format_cx_cell(v: &Value) -> String {
    match v {
        Value::Null => "null".to_string(),
        Value::Bool(b) => {
            if *b {
                "true".to_string()
            } else {
                "false".to_string()
            }
        }
        Value::Number(n) => n.to_string(),
        Value::Array(arr) => {
            let parts: Vec<String> = arr.iter().map(format_cx_cell).collect();
            format!("[{}]", parts.join(", "))
        }
        Value::Object(map) => {
            let mut keys: Vec<&String> = map.keys().collect();
            keys.sort();
            let parts: Vec<String> = keys
                .iter()
                .map(|k| format!("{}: {}", format_cx_key(k), format_cx_cell(&map[*k])))
                .collect();
            format!("{{{}}}", parts.join(", "))
        }
        Value::String(s) => {
            let needs_quote = s.is_empty()
                || s.chars().any(|c| {
                    c.is_whitespace() || matches!(c, '\'' | '[' | ']' | '(' | ')' | '{' | '}' | ',')
                });
            if needs_quote {
                format!("'{}'", s.replace('\'', "''"))
            } else {
                s.clone()
            }
        }
    }
}

fn format_cx_key(k: &str) -> String {
    let is_bare = !k.is_empty()
        && k.chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '_');
    if is_bare {
        k.to_string()
    } else {
        format!("'{}'", k.replace('\'', "''"))
    }
}

fn format_csv_cell(v: &Value, delim: char) -> String {
    match v {
        Value::Null => String::new(),
        Value::Array(_) | Value::Object(_) => {
            let json_str = serde_json::to_string(v).unwrap_or_default();
            format!("\"{}\"", json_str.replace('"', "\"\""))
        }
        Value::Bool(b) => {
            if *b {
                "true".to_string()
            } else {
                "false".to_string()
            }
        }
        Value::Number(n) => n.to_string(),
        Value::String(s) => {
            if s.contains(delim) || s.contains('"') || s.contains('\n') || s.contains('\r') {
                format!("\"{}\"", s.replace('"', "\"\""))
            } else {
                s.clone()
            }
        }
    }
}

// Allow `json!` to be unused if not required by the format helpers.
#[allow(unused_imports)]
use json as _json;

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn test_table_from_cx_simple() {
        let src = "[users [table[name age::int]]\n  alice 30\n  bob 25\n]";
        let t = Table::from_cx(src).expect("parse");
        assert_eq!(t.row_count(), 2);
        assert_eq!(t.col_count(), 2);
    }

    #[test]
    fn test_table_from_cx_no_table_errors() {
        let err = Table::from_cx("[product name=alice]").unwrap_err();
        assert!(err.contains("no :table"));
    }

    #[test]
    fn test_table_new_validates() {
        // len mismatch
        let r = Table::new(
            vec!["a".to_string(), "b".to_string()],
            vec!["int".to_string()],
            vec![],
        );
        assert!(r.unwrap_err().contains("len(cols)"));

        // duplicate
        let r = Table::new(
            vec!["a".to_string(), "a".to_string()],
            vec!["int".to_string(), "int".to_string()],
            vec![],
        );
        assert!(r.unwrap_err().contains("duplicate"));

        // row width
        let r = Table::new(
            vec!["a".to_string(), "b".to_string()],
            vec!["int".to_string(), "int".to_string()],
            vec![vec![json!(1)]],
        );
        assert!(r.unwrap_err().contains("cells; expected"));
    }

    #[test]
    fn test_table_row_and_column() {
        let t = Table::new(
            vec!["a".to_string(), "b".to_string()],
            vec!["int".to_string(), "string".to_string()],
            vec![vec![json!(1), json!("x")], vec![json!(2), json!("y")]],
        )
        .unwrap();
        let row = t.row(0).unwrap();
        assert_eq!(row["a"], json!(1));
        let col = t.column("b").unwrap();
        assert_eq!(col, vec![json!("x"), json!("y")]);
    }

    #[test]
    fn test_table_cell_out_of_bounds() {
        let t = Table::new(
            vec!["a".to_string()],
            vec!["int".to_string()],
            vec![vec![json!(1)]],
        )
        .unwrap();
        let err = t.row(5).unwrap_err();
        assert!(err.contains("out of bounds"));
    }

    #[test]
    fn test_table_slice_head_tail() {
        let rows: Vec<Vec<Value>> = (0..5).map(|i| vec![json!(i)]).collect();
        let t = Table::new(vec!["v".to_string()], vec!["int".to_string()], rows).unwrap();
        assert_eq!(t.head(2).row_count(), 2);
        assert_eq!(t.tail(2).row_count(), 2);
        assert_eq!(t.slice(1, 4).unwrap().row_count(), 3);
    }

    #[test]
    fn test_table_select_cols() {
        let t = Table::new(
            vec!["a".to_string(), "b".to_string(), "c".to_string()],
            vec!["int".to_string(), "int".to_string(), "int".to_string()],
            vec![vec![json!(1), json!(2), json!(3)]],
        )
        .unwrap();
        let sel = t.select_cols(&["c", "a"]).unwrap();
        assert_eq!(sel.cols(), &["c", "a"]);
    }

    #[test]
    fn test_table_to_cx() {
        let t = Table::new(
            vec!["a".to_string()],
            vec!["int".to_string()],
            vec![vec![json!(1)]],
        )
        .unwrap();
        let out = t.to_cx();
        assert!(out.contains("[table[a::int]]"));
        assert!(out.contains("  1"));
    }

    #[test]
    fn test_table_to_json() {
        let t = Table::new(
            vec!["a".to_string()],
            vec!["int".to_string()],
            vec![vec![json!(1)], vec![json!(2)]],
        )
        .unwrap();
        let js = t.to_json().unwrap();
        assert!(js.contains("\"a\":1"));
    }

    #[test]
    fn test_table_to_csv() {
        let t = Table::new(
            vec!["name".to_string(), "age".to_string()],
            vec!["".to_string(), "int".to_string()],
            vec![vec![json!("alice"), json!(30)]],
        )
        .unwrap();
        let csv = t.to_csv(',').unwrap();
        assert!(csv.contains("name,age"));
        assert!(csv.contains("alice,30"));
    }

    #[test]
    fn test_table_eq() {
        let a = Table::new(
            vec!["a".to_string()],
            vec!["int".to_string()],
            vec![vec![json!(1)]],
        )
        .unwrap();
        let b = a.clone();
        assert_eq!(a, b);
    }

    #[test]
    fn test_table_from_cx_collection_cells() {
        let src = "[u [table[name tags]]\n  alice [admin, user,]\n]";
        let t = Table::from_cx(src).expect("parse");
        let row = t.row(0).unwrap();
        let tags = row["tags"].as_array().expect("array");
        assert_eq!(tags.len(), 2);
        assert_eq!(tags[0], json!("admin"));
    }
}
