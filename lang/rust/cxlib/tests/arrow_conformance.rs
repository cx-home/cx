#![cfg(feature = "arrow")]

// Cross-binding Arrow conformance runner (W3).
//
// Reads conformance/data_bin_arrow.cxd — the canonical Arrow C-Data
// round-trip fixture corpus — and runs each test through the Rust
// binding's cxlib::arrow::{export, import_to_data_bin} path. Mirrors
// lang/python/test_arrow_conformance.py and
// lang/go/cxlib/arrow_conformance_test.go so the fixture file is
// the single source of truth across active bindings.

use std::path::{Path, PathBuf};

use arrow::array::RecordBatchReader;

fn repo_root() -> PathBuf {
    // Walk up from CARGO_MANIFEST_DIR until conformance/data_bin_arrow.cxd
    // is reachable. The crate lives at lang/rust/cxlib/Cargo.toml so the
    // root is three levels up; the loop is defensive.
    let mut p = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    for _ in 0..8 {
        if p.join("conformance/data_bin_arrow.cxd").exists() {
            return p;
        }
        if !p.pop() {
            break;
        }
    }
    panic!("could not locate conformance/data_bin_arrow.cxd from {}",
        env!("CARGO_MANIFEST_DIR"));
}

#[derive(Default, Debug)]
struct Fixture {
    name: String,
    sections: std::collections::HashMap<String, String>,
}

// Load conformance/data_bin_arrow.cxd via the CX-native loader
// (cxlib::fixtures::load_fixtures), replacing the bespoke === test: / --- key
// scanner. The consumer keys into fx.sections[...] and fx.name as before.
fn parse_fixtures(path: &Path) -> Vec<Fixture> {
    cxlib::fixtures::load_fixtures(path.to_str().expect("utf-8 fixture path"))
        .expect("load conformance fixtures")
        .into_iter()
        .map(|c| Fixture {
            name: c.name,
            sections: c.sections,
        })
        .collect()
}

fn arrow_rust_type_to_format(s: &str) -> &str {
    // arrow-rs DataType.to_string() forms → Arrow C-Data format strings
    // (cx convention; see vcx/arrow/arrow.v::arrow_format_for_cxcol_type).
    match s {
        "Int64" => "l",
        "Int8" => "c",
        "Int16" => "s",
        "Int32" => "i",
        "Float64" => "g",
        "Boolean" => "b",
        "Utf8" => "u",
        "Date32" => "tdD",
        "Timestamp(Nanosecond, Some(\"UTC\"))" => "tsn:UTC",
        "Binary" => "z",
        other => other,
    }
}

#[test]
fn arrow_conformance() {
    if !cxlib::arrow::available() {
        eprintln!("libcx_arrow not loaded — skipping conformance");
        return;
    }
    let path = repo_root().join("conformance/data_bin_arrow.cxd");
    let fixtures = parse_fixtures(&path);
    assert!(!fixtures.is_empty(), "no fixtures parsed from {path:?}");
    let mut failed = Vec::new();
    for fx in &fixtures {
        if let Err(e) = run_one(fx) {
            failed.push(format!("{}: {e}", fx.name));
        }
    }
    if !failed.is_empty() {
        panic!("{} of {} fixtures failed:\n{}",
            failed.len(), fixtures.len(), failed.join("\n"));
    }
    println!("arrow_conformance: {}/{} fixtures pass",
        fixtures.len(), fixtures.len());
}

fn run_one(fx: &Fixture) -> Result<(), String> {
    let in_cx = fx.sections.get("in_cx").map(|s| s.trim_matches('\n')).unwrap_or("");
    let expect_err = fx.sections.get("expected_export_error")
        .map(|s| s.trim()).unwrap_or("");
    let formats = fx.sections.get("arrow_children_formats")
        .map(|s| s.trim()).unwrap_or("");

    // Encode CX → CXCol chunked.
    let framed = match cxlib::streaming_table::to_data_bin_chunked(in_cx) {
        Ok(b) => b,
        Err(e) => {
            if !expect_err.is_empty() && e.contains(expect_err) {
                return Ok(());
            }
            return Err(format!("to_data_bin_chunked: {e}"));
        }
    };

    // Export to Arrow.
    let mut reader = match cxlib::arrow::export(&framed) {
        Ok(r) => r,
        Err(e) => {
            if !expect_err.is_empty() && e.contains(expect_err) {
                return Ok(());
            }
            return Err(format!("export: {e}"));
        }
    };

    // Drain to collect schema types.
    let schema = reader.schema();
    let mut actual_fmts: Vec<String> = schema.fields()
        .iter()
        .map(|f| arrow_rust_type_to_format(&format!("{:?}", f.data_type())).to_string())
        .collect();
    while let Some(batch) = reader.next() {
        batch.map_err(|e| format!("reader.next: {e}"))?;
    }

    if !formats.is_empty() {
        let expected: Vec<&str> = formats.lines().collect();
        // arrow-rs Debug formatting for DataType differs from to_string();
        // re-map via the helper.
        actual_fmts = schema.fields()
            .iter()
            .map(|f| arrow_rust_type_to_format(&format!("{:?}", f.data_type())).to_string())
            .collect();
        if actual_fmts.len() != expected.len() {
            return Err(format!("arrow_children_formats count: expected {} got {} ({:?})",
                expected.len(), actual_fmts.len(), actual_fmts));
        }
        for (i, e) in expected.iter().enumerate() {
            if actual_fmts[i] != *e {
                return Err(format!("arrow_children_formats[{i}]: expected {e:?} got {:?}",
                    actual_fmts[i]));
            }
        }
    }

    // Round-trip via re-export → import → re-export. Verify schema
    // identity at the per-field type level (matches the Go runner's
    // granularity; Arrow binary bytes are intentionally not asserted).
    let reader2 = cxlib::arrow::export(&framed)
        .map_err(|e| format!("export (round-trip): {e}"))?;
    let out = cxlib::arrow::import_to_data_bin(reader2)
        .map_err(|e| format!("import_to_data_bin: {e}"))?;
    let reader3 = cxlib::arrow::export(&out)
        .map_err(|e| format!("export (post-round-trip): {e}"))?;
    let schema3 = reader3.schema();
    let after: Vec<String> = schema3.fields()
        .iter()
        .map(|f| arrow_rust_type_to_format(&format!("{:?}", f.data_type())).to_string())
        .collect();
    if after != actual_fmts {
        return Err(format!("post-round-trip schema mismatch: before={actual_fmts:?} after={after:?}"));
    }
    Ok(())
}
