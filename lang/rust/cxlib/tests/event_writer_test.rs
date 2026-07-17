//! Streaming-write tests for the Rust binding (Phase 7.74i — Tier-2 wrappers).
//! Mirrors lang/python/test_event_writer.py and lang/go/cxlib/event_writer_test.go.

use std::sync::Mutex;
static TEST_LOCK: Mutex<()> = Mutex::new(());

use cxlib::event_writer::{EventAttr, EventWriter, StartElementOpts, has_capability};

/// 2-col col_spec wire form (spec/core/data-bin.md §3.10.1):
/// name:string (0x30), score:i32 (0x12).
fn col_spec_2() -> Vec<u8> {
    let mut out = Vec::with_capacity(32);
    out.extend_from_slice(&2u32.to_le_bytes());            // col count
    out.extend_from_slice(&4u32.to_le_bytes()); out.extend_from_slice(b"name");  out.push(0x30);
    out.extend_from_slice(&5u32.to_le_bytes()); out.extend_from_slice(b"score"); out.push(0x12);
    out
}

/// 2-row row group: uvarint(2) + col1 strings ("alice","bob") + col2 i32 LE (91,88).
fn row_group_2() -> Vec<u8> {
    let mut out = Vec::with_capacity(32);
    out.push(2);                              // uvarint(2)
    out.push(5); out.extend_from_slice(b"alice");
    out.push(3); out.extend_from_slice(b"bob");
    out.extend_from_slice(&91i32.to_le_bytes());
    out.extend_from_slice(&88i32.to_le_bytes());
    out
}

#[test]
fn capability_bit_advertised() {
    let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    assert!(has_capability(),
            "expected libcx to advertise capability bit 27 (streaming-write)");
}

#[test]
fn cx_minimal_round_trip() {
    let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let mut w = EventWriter::new("cx").expect("open cx writer");
    w.start_doc().unwrap();
    w.start_element("greet", &[]).unwrap();
    w.text("hello").unwrap();
    w.end_element("greet").unwrap();
    w.end_doc().unwrap();
    let out = w.close_get_bytes().expect("close_get_bytes");
    let s = String::from_utf8(out).expect("utf-8");
    assert!(s.contains("[greet"), "got {s:?}");
    assert!(s.contains("hello"),  "got {s:?}");
}

#[test]
fn cx_attrs_emitted() {
    let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let mut w = EventWriter::new("cx").unwrap();
    w.start_doc().unwrap();
    w.start_element("book", &[
        EventAttr::typed("id",  "b1", "string"),
        EventAttr::typed("yr",  "2024", "int"),
    ]).unwrap();
    w.end_element("book").unwrap();
    w.end_doc().unwrap();
    let s = String::from_utf8(w.close_get_bytes().unwrap()).unwrap();
    assert!(s.contains("id="),  "missing id= in {s:?}");
    assert!(s.contains("b1"),   "missing b1 in {s:?}");
}

#[test]
fn xml_minimal_round_trip() {
    let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let mut w = EventWriter::new("xml").unwrap();
    w.start_doc().unwrap();
    w.start_element("greet", &[]).unwrap();
    w.text("hello").unwrap();
    w.end_element("greet").unwrap();
    w.end_doc().unwrap();
    let s = String::from_utf8(w.close_get_bytes().unwrap()).unwrap();
    assert!(s.contains("<?xml version=\"1.0\"?>"), "got {s:?}");
    assert!(s.contains("<greet>"),  "got {s:?}");
    assert!(s.contains("hello"),    "got {s:?}");
    assert!(s.contains("</greet>"), "got {s:?}");
}

#[test]
fn w001_double_start_doc() {
    let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let mut w = EventWriter::new("cx").unwrap();
    w.start_doc().unwrap();
    let e = w.start_doc().expect_err("expected W001");
    assert!(e.starts_with("W001"), "got {e:?}");
}

#[test]
fn w002_text_before_start_doc() {
    let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let mut w = EventWriter::new("cx").unwrap();
    let e = w.text("premature").expect_err("expected W002");
    assert!(e.starts_with("W002"), "got {e:?}");
}

#[test]
fn w003_text_after_end_doc() {
    let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let mut w = EventWriter::new("cx").unwrap();
    w.start_doc().unwrap();
    w.end_doc().unwrap();
    let e = w.text("post").expect_err("expected W003");
    assert!(e.starts_with("W003"), "got {e:?}");
}

#[test]
fn w004_unclosed_element_on_end_doc() {
    let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let mut w = EventWriter::new("cx").unwrap();
    w.start_doc().unwrap();
    w.start_element("open", &[]).unwrap();
    let e = w.end_doc().expect_err("expected W004");
    assert!(e.starts_with("W004"), "got {e:?}");
}

#[test]
fn w005_end_element_mismatch() {
    let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let mut w = EventWriter::new("cx").unwrap();
    w.start_doc().unwrap();
    w.start_element("greet", &[]).unwrap();
    let e = w.end_element("farewell").expect_err("expected W005");
    assert!(e.starts_with("W005"), "got {e:?}");
}

#[test]
fn w006_orphan_end_element() {
    let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let mut w = EventWriter::new("cx").unwrap();
    w.start_doc().unwrap();
    let e = w.end_element("orphan").expect_err("expected W006");
    assert!(e.starts_with("W006"), "got {e:?}");
}

#[test]
fn w008_invalid_data_type() {
    let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let mut w = EventWriter::new("cx").unwrap();
    w.start_doc().unwrap();
    let e = w.scalar("42", "not_a_type").expect_err("expected W008");
    assert!(e.starts_with("W008"), "got {e:?}");
}

#[test]
fn w009_chunked_table_on_xml_target() {
    let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    // chunked-table on non-cx targets is W009 per §6.6.
    let mut w = EventWriter::new("xml").unwrap();
    w.start_doc().unwrap();
    // col_spec: 1 col, "x", i8 (0x78). Same hex as the conformance fixture.
    let col_spec = b"\x01\x00\x00\x00\x01\x00\x00\x00x\x12".to_vec();
    let e = w.start_table(&col_spec).expect_err("expected W009");
    assert!(e.starts_with("W009"), "got {e:?}");
}

#[test]
fn w012_orphan_row_group() {
    let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let mut w = EventWriter::new("cx").unwrap();
    w.start_doc().unwrap();
    let e = w.row_group(b"\x01").expect_err("expected W012");
    assert!(e.starts_with("W012"), "got {e:?}");
}

#[test]
fn w013_orphan_end_table() {
    let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let mut w = EventWriter::new("cx").unwrap();
    w.start_doc().unwrap();
    let e = w.end_table().expect_err("expected W013");
    assert!(e.starts_with("W013"), "got {e:?}");
}

#[test]
fn fail_closed_after_first_w_code() {
    let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let mut w = EventWriter::new("cx").unwrap();
    let first = w.text("premature").expect_err("first W002");
    assert!(first.starts_with("W002"), "got {first:?}");
    // Subsequent emits return the same diagnostic without effect.
    let second = w.text("again").expect_err("fail-closed");
    assert!(second.starts_with("W002"), "got {second:?}");
}

#[test]
fn chunked_table_cx_round_trip() {
    let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let mut w = EventWriter::new("cx").unwrap();
    w.start_doc().unwrap();
    w.start_element("points", &[]).unwrap();
    w.start_table(&col_spec_2()).unwrap();
    w.row_group(&row_group_2()).unwrap();
    w.end_table().unwrap();
    w.end_element("points").unwrap();
    w.end_doc().unwrap();
    let s = String::from_utf8(w.close_get_bytes().unwrap()).unwrap();
    for want in ["[table[", "alice", "91"] {
        assert!(s.contains(want), "missing {want:?} in cx emit: {s}");
    }
}

#[test]
fn fd_writer_path() {
    let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    use std::os::unix::io::AsRawFd;
    let tmpdir = std::env::temp_dir();
    let path = tmpdir.join(format!("cx_event_writer_rust_{}.cx", std::process::id()));
    {
        let f = std::fs::OpenOptions::new()
            .create(true).write(true).truncate(true).open(&path).expect("open");
        let mut w = EventWriter::with_fd("cx", f.as_raw_fd()).expect("fd writer");
        w.start_doc().unwrap();
        w.start_element("greet", &[]).unwrap();
        w.text("hello").unwrap();
        w.end_element("greet").unwrap();
        w.end_doc().unwrap();
        let bytes = w.close_get_bytes().expect("close_get_bytes");
        assert!(bytes.is_empty(), "fd writer should return empty bytes");
    }
    let written = std::fs::read_to_string(&path).expect("read back");
    assert!(written.contains("[greet"), "fd output missing element: {written:?}");
    assert!(written.contains("hello"),  "fd output missing text: {written:?}");
    let _ = std::fs::remove_file(&path);
}

#[test]
fn start_element_opts_anchor_and_data_type() {
    let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let mut w = EventWriter::new("cx").unwrap();
    w.start_doc().unwrap();
    let opts = StartElementOpts {
        anchor: Some("a1"),
        data_type: None,
        merge: None,
        attrs: &[],
    };
    w.start_element_opts("node", &opts).unwrap();
    w.end_element("node").unwrap();
    w.end_doc().unwrap();
    let s = String::from_utf8(w.close_get_bytes().unwrap()).unwrap();
    assert!(s.contains("&a1"), "missing anchor in {s:?}");
}
