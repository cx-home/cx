//! CX-native conformance fixture loader — Rust mirror of
//! `vcx/cx/fixture_loader.v` (and the Python / Go loaders).
//!
//! The canonical fixture format is the CX document (`conformance/*.cxd`,
//! schema `conformance/fixtures.cxs`). This loader reads a suite via the CX
//! parser itself (`crate::ast::parse` → libcx C ABI) and reconstructs each
//! `[case …]` into the legacy-shaped fields the test consumers expect,
//! replacing the per-consumer hand-rolled `=== test:` / `--- key` text
//! parsers.
//!
//! Section keys are returned in their LEGACY snake_case form (`in_cx`,
//! `expected_export_error`, …) so consumers key into `sections` exactly as
//! they did against the old `.txt`.
//!
//! NOTE: the typed `expect-codes` / `expect-warn-codes` atom-array sections
//! require the v0.8.0 collection node-kinds (ast_bin 0x0F/0x10/0x11), which
//! the Rust decoder does not yet model; the suites that drive this loader
//! (`data_bin_arrow`, `streaming_write`) do not use them. `expect-valid`
//! (a plain bool scalar) is reconstructed.

use crate::ast::{self, Element, Node};
use serde_json::Value;
use std::collections::HashMap;
use std::fs;

/// A reconstructed conformance fixture case (mirror of `FixtureCase`).
#[derive(Debug, Clone, Default)]
pub struct FixtureCase {
    /// Legacy test name: id, plus ' ' + title when titled.
    pub name: String,
    /// "" when the case carried no level.
    pub level: String,
    pub tags: Vec<String>,
    /// Extra header lines: view/kind/note/chunk_at/pending/…
    pub meta: HashMap<String, String>,
    /// Legacy section key -> normalized body.
    pub sections: HashMap<String, String>,
    /// Section keys, document order.
    pub order: Vec<String>,
}

/// Parse a `.cxd` conformance suite and return its cases.
pub fn load_fixtures(path: &str) -> Result<Vec<FixtureCase>, String> {
    let src = fs::read_to_string(path)
        .map_err(|e| format!("load_fixtures: cannot read {path}: {e}"))?;
    parse_fixture_suite(&src)
}

/// Parse suite text already in memory.
///
/// Uses `ast::parse` (the single-document entry point). A suite payload may
/// contain a `---` line inside a RawText block (CX multi-doc examples under
/// test); the lexer consumes `---` inside RawText correctly and only treats a
/// top-level `---` as a separator, so such a suite parses to one document.
pub fn parse_fixture_suite(src: &str) -> Result<Vec<FixtureCase>, String> {
    let doc = ast::parse(src)?;
    let mut cases = Vec::new();
    for node in &doc.elements {
        if let Node::Element(root) = node {
            if root.name == "test-suite" {
                for child in &root.items {
                    if let Node::Element(c) = child {
                        if c.name == "case" {
                            cases.push(fixture_case_from(c));
                        }
                    }
                }
            }
        }
    }
    Ok(cases)
}

fn fixture_case_from(c: &Element) -> FixtureCase {
    let mut fc = FixtureCase::default();
    let mut id = String::new();
    for a in &c.attrs {
        match a.name.as_str() {
            "id" => id = value_str(&a.value),
            "level" => fc.level = value_str(&a.value),
            _ => {}
        }
    }
    let mut title = String::new();
    for child in &c.items {
        let el = match child {
            Node::Element(e) => e,
            _ => continue,
        };
        match el.name.as_str() {
            "title" => title = rawtext(el), // inline [#…#] — exact, no normalize
            "tags" => {
                fc.tags = text_join(el)
                    .split([' ', '\t'])
                    .filter(|s| !s.is_empty())
                    .map(|s| s.to_string())
                    .collect();
            }
            "meta" => {
                let body = normalize(&rawtext(el));
                for line in body.split('\n') {
                    if let Some(idx) = line.find(':') {
                        fc.meta
                            .insert(line[..idx].trim().to_string(), line[idx + 1..].trim().to_string());
                    }
                }
            }
            "expect-valid" => {
                fc.sections
                    .insert("sv_assert_valid".to_string(), if fixture_bool(el) { "1" } else { "0" }.to_string());
                fc.order.push("sv_assert_valid".to_string());
            }
            "expect-codes" => {
                fc.sections.insert("sv_expected_codes".to_string(), atom_csv(el));
                fc.order.push("sv_expected_codes".to_string());
            }
            "expect-warn-codes" => {
                fc.sections.insert("sv_expected_warn_codes".to_string(), atom_csv(el));
                fc.order.push("sv_expected_warn_codes".to_string());
            }
            other => {
                let key = other.replace('-', "_");
                fc.sections.insert(key.clone(), normalize(&rawtext(el)));
                fc.order.push(key);
            }
        }
    }
    fc.name = if title.is_empty() {
        id
    } else {
        format!("{id} {title}")
    };
    fc
}

/// Concatenate the RawText payload(s) of a section element.
fn rawtext(e: &Element) -> String {
    let mut s = String::new();
    for it in &e.items {
        if let Node::RawText(v) = it {
            s.push_str(v);
        }
    }
    s
}

/// Join text/scalar body (used for the tags line).
fn text_join(e: &Element) -> String {
    let mut s = String::new();
    for it in &e.items {
        match it {
            Node::Text(v) => s.push_str(v),
            Node::Scalar { value, .. } => s.push_str(&value_str(value)),
            _ => {}
        }
    }
    s
}

/// Loader rule: strip one leading and one trailing newline.
fn normalize(raw: &str) -> String {
    let s = raw.strip_prefix('\n').unwrap_or(raw);
    let s = s.strip_suffix('\n').unwrap_or(s);
    s.to_string()
}

/// Comma-join the atom names inside an array-literal section body
/// (`[expect-codes [:S002, :S004]]` → "S002,S004"). Mirrors the
/// fixture_atom_csv reconstruction in the V / Python / Go loaders.
fn atom_csv(e: &Element) -> String {
    let mut names: Vec<String> = Vec::new();
    for it in &e.items {
        if let Node::ArrayNode(items) = it {
            for item in items {
                if let Node::Scalar { value, .. } = item {
                    names.push(value_str(value));
                }
            }
        }
    }
    names.join(",")
}

fn fixture_bool(e: &Element) -> bool {
    for it in &e.items {
        if let Node::Scalar { value: Value::Bool(b), .. } = it {
            return *b;
        }
    }
    false
}

fn value_str(v: &Value) -> String {
    match v {
        Value::String(s) => s.clone(),
        Value::Null => String::new(),
        other => other.to_string(),
    }
}
