//! Rust-side runner for `conformance/streaming_write.txt`. Mirrors the
//! Python (`lang/python/conformance.py`) and Go (`lang/go/conformance/main.go`)
//! streaming-write dispatchers — same fixture file, identical W-code matching.

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Mutex;

use cxlib::event_writer::EventWriter;

static TEST_LOCK: Mutex<()> = Mutex::new(());

// ── suite parser ──────────────────────────────────────────────────────────────

struct TestCase {
    name: String,
    sections: HashMap<String, String>,
}

fn parse_suite(path: &PathBuf) -> Vec<TestCase> {
    let text = std::fs::read_to_string(path).expect("read suite");
    let mut tests: Vec<TestCase> = Vec::new();
    let mut cur: Option<TestCase> = None;
    let mut section: Option<String> = None;
    let mut buf: Vec<String> = Vec::new();

    fn flush(cur: &mut Option<TestCase>, section: &Option<String>, buf: &mut Vec<String>) {
        if let (Some(tc), Some(sec)) = (cur.as_mut(), section.as_ref()) {
            let mut lines = buf.clone();
            while lines.first().map(|s| s.trim().is_empty()).unwrap_or(false) { lines.remove(0); }
            while lines.last().map(|s| s.trim().is_empty()).unwrap_or(false) { lines.pop(); }
            tc.sections.insert(sec.clone(), lines.join("\n"));
        }
        buf.clear();
    }

    for raw in text.lines() {
        if let Some(name) = raw.strip_prefix("=== test:") {
            flush(&mut cur, &section, &mut buf);
            if let Some(prev) = cur.take() { tests.push(prev); }
            cur = Some(TestCase { name: name.trim().to_owned(), sections: HashMap::new() });
            section = None;
        } else if let Some(sec) = raw.strip_prefix("--- ") {
            flush(&mut cur, &section, &mut buf);
            section = Some(sec.trim().to_owned());
        } else if cur.is_some() && section.is_some() {
            buf.push(raw.to_owned());
        }
    }
    flush(&mut cur, &section, &mut buf);
    if let Some(prev) = cur { tests.push(prev); }
    tests
}

// ── event-line decoder ───────────────────────────────────────────────────────

fn decode_quoted(s: &str) -> String {
    let s = s.trim();
    if s.starts_with('"') && s.ends_with('"') && s.len() >= 2 {
        return s[1..s.len()-1].to_owned();
    }
    s.to_owned()
}

fn hex_bytes(s: &str) -> Vec<u8> {
    let s = s.trim();
    let mut out = Vec::with_capacity(s.len() / 2);
    let bytes = s.as_bytes();
    let mut i = 0;
    while i + 1 < bytes.len() {
        out.push(u8::from_str_radix(std::str::from_utf8(&bytes[i..i+2]).unwrap(), 16).unwrap());
        i += 2;
    }
    out
}

fn dispatch(w: &mut EventWriter, op: &str, rest: &str) -> Result<(), String> {
    match op {
        "StartDoc" => w.start_doc(),
        "EndDoc"   => w.end_doc(),
        "StartElement" => {
            let toks: Vec<&str> = rest.split_whitespace().collect();
            let name = toks.first().copied().unwrap_or("");
            let mut anchor: Option<&str> = None;
            let mut data_type: Option<&str> = None;
            let mut merge: Option<&str> = None;
            for tok in &toks[1..] {
                if let Some((k, v)) = tok.split_once('=') {
                    match k {
                        "anchor"    => anchor    = Some(leak(v)),
                        "data_type" => data_type = Some(leak(v)),
                        "merge"     => merge     = Some(leak(v)),
                        _ => {}
                    }
                }
            }
            let opts = cxlib::event_writer::StartElementOpts {
                anchor, data_type, merge, attrs: &[],
            };
            w.start_element_opts(name, &opts)
        }
        "EndElement" => w.end_element(rest.trim()),
        "Text"       => w.text(&decode_quoted(rest)),
        "Scalar" => {
            // Scalar <type>:<value>
            let (typ, val) = rest.split_once(':').unwrap_or((rest, ""));
            w.scalar(val, typ.trim())
        }
        "Comment" => w.comment(&decode_quoted(rest)),
        "PI" => {
            let mut it = rest.splitn(2, char::is_whitespace);
            let target = it.next().unwrap_or("").trim();
            let data = it.next()
                .and_then(|s| s.trim().strip_prefix("data=").map(decode_quoted))
                .unwrap_or_default();
            w.pi(target, &data)
        }
        "EntityRef" => w.entity_ref(rest.trim()),
        "RawText"   => w.raw_text(&decode_quoted(rest)),
        "Alias"     => w.alias(rest.trim()),
        "StartTable"=> w.start_table(&hex_bytes(rest)),
        "RowGroup"  => w.row_group(&hex_bytes(rest)),
        "EndTable"  => w.end_table(),
        other => Err(format!("unknown event op: {other:?}")),
    }
}

// Leak owned token strings so we can hand &str slices to start_element_opts
// without lifetime gymnastics — each fixture is short-lived so the cost is
// negligible, and the test process exits at end of suite.
fn leak(s: &str) -> &'static str {
    Box::leak(s.to_owned().into_boxed_str())
}

fn first_nonblank_noncomment(text: &str) -> &str {
    for line in text.lines() {
        let t = line.trim();
        if !t.is_empty() && !t.starts_with('#') {
            return t;
        }
    }
    ""
}

fn strip_comments(text: &str) -> String {
    text.lines()
        .filter(|l| !l.trim_start().starts_with('#'))
        .collect::<Vec<_>>()
        .join("\n")
}

fn run_case(tc: &TestCase) -> Vec<String> {
    let mut failures = Vec::new();
    let s = &tc.sections;
    let fmt = s.get("format").map(|s| s.trim()).unwrap_or("cx");
    let events = match s.get("events") { Some(e) => e.as_str(), None => return failures };
    let expect_err = s.get("expect_err").map(|t| first_nonblank_noncomment(t)).unwrap_or("");
    let expect_ok = s.get("expect_ok").map(|t| strip_comments(t));
    let expect_ok_contains = s.get("expect_ok_contains").map(|t| strip_comments(t));

    let mut w = match EventWriter::new(fmt) {
        Ok(w) => w,
        Err(e) => {
            if !expect_err.is_empty() && e.starts_with(expect_err) { return failures; }
            failures.push(format!("EventWriter::new({fmt:?}) failed: {e}"));
            return failures;
        }
    };

    let mut triggered: Option<String> = None;
    for raw in events.lines() {
        let line = raw.trim();
        if line.is_empty() { continue; }
        let (op, rest) = match line.split_once(char::is_whitespace) {
            Some((h, r)) => (h, r),
            None         => (line, ""),
        };
        match dispatch(&mut w, op, rest) {
            Ok(()) => {}
            Err(e) => { triggered = Some(e); break; }
        }
    }

    if !expect_err.is_empty() {
        if triggered.is_none() {
            // try to surface on close
            match w.close_get_bytes() {
                Ok(_) => {}
                Err(e) => triggered = Some(e),
            }
        } else {
            // ensure writer is dropped; close_get_bytes is consumed but
            // we already broke before completing — drop will release the handle.
            drop(w);
        }
        match triggered {
            None => failures.push(format!("expected {expect_err} but writer produced no error")),
            Some(msg) if !msg.contains(expect_err) =>
                failures.push(format!("expected {expect_err} in error, got {msg:?}")),
            _ => {}
        }
        return failures;
    }

    if let Some(t) = triggered {
        failures.push(format!("unexpected error: {t}"));
        return failures;
    }
    let bytes = match w.close_get_bytes() {
        Ok(b) => b,
        Err(e) => { failures.push(format!("close_get_bytes raised: {e}")); return failures; }
    };
    let out_str = String::from_utf8_lossy(&bytes).into_owned();
    if let Some(exp) = expect_ok {
        if exp.trim() != out_str.trim() {
            failures.push(format!("expect_ok mismatch\n  expected:\n{exp}\n  got:\n{out_str}"));
        }
    }
    if let Some(needles) = expect_ok_contains {
        for needle in needles.lines() {
            let needle = needle.trim();
            if !needle.is_empty() && !out_str.contains(needle) {
                failures.push(format!("expect_ok_contains: missing {needle:?} in output:\n{out_str}"));
            }
        }
    }
    failures
}

fn conformance_path() -> PathBuf {
    // tests run from lang/rust/cxlib; conformance/ is at ../../../conformance/
    let mut p = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    p.push("../../../conformance/streaming_write.txt");
    p
}

#[test]
fn streaming_write_conformance_suite() {
    let _g = TEST_LOCK.lock().unwrap();
    let path = conformance_path();
    assert!(path.exists(), "missing conformance fixture: {path:?}");
    let tests = parse_suite(&path);
    assert!(!tests.is_empty(), "no fixtures parsed from {path:?}");

    let mut failed = 0;
    for tc in &tests {
        let f = run_case(tc);
        if !f.is_empty() {
            failed += 1;
            eprintln!("FAIL  {}", tc.name);
            for line in f { for sub in line.split('\n') { eprintln!("      {sub}"); } }
        }
    }
    assert_eq!(failed, 0, "{failed} streaming_write.txt fixtures failed");
}
