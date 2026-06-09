//! Streaming Table API tests for the Rust binding (Phase 7.74b).
//! Mirrors lang/python/test_streaming_table.py and the V core test.
//!
//! NOTE: a serialized mutex around the test bodies guards against a
//! thread-safety quirk observed when multiple TableReader/TableWriter
//! handles instantiate concurrently in the same process. Per
//! spec/abi.md §1.5.1 class H, distinct handles on distinct threads
//! should be safe — surface as a follow-up if it persists in CI.

use std::sync::Mutex;
static TEST_LOCK: Mutex<()> = Mutex::new(());

use cxlib::data_bin::from_data_bin;
use cxlib::streaming_table::{to_data_bin_chunked, TableReader, TableWriter};

const SIX_ROW_INPUT: &str = "[points [table[name::string score::i32]]
  alice 91
  bob 88
  carol 73
  dave 95
  eve 84
  frank 60
]";

fn reframe(payload: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(4 + payload.len());
    out.extend_from_slice(&(payload.len() as u32).to_le_bytes());
    out.extend_from_slice(payload);
    out
}

#[test]
fn test_to_data_bin_chunked_round_trip() {
    let _g = TEST_LOCK.lock().unwrap();
    let payload = to_data_bin_chunked(SIX_ROW_INPUT).expect("to_data_bin_chunked");
    assert!(payload.len() > 5 && &payload[..5] == b"CXCol",
            "expected CXCol magic; got {} bytes", payload.len());
    let cx_text = from_data_bin(&reframe(&payload)).expect("from_data_bin");
    assert!(cx_text.contains("alice") && cx_text.contains("frank"),
            "missing alice/frank in chunked round-trip: {}", cx_text);
}

#[test]
fn test_streaming_table_bytes_round_trip() {
    let _g = TEST_LOCK.lock().unwrap();
    let payload = to_data_bin_chunked(SIX_ROW_INPUT).expect("to_data_bin_chunked");
    let mut reader = TableReader::open(&payload).expect("TableReader::open");
    let schema = reader.schema().expect("schema");
    assert!(!schema.is_empty(), "empty schema bytes");
    let groups: Vec<Vec<u8>> = std::iter::from_fn(|| reader.next_row_group().transpose())
        .collect::<Result<Vec<_>, _>>().expect("collect row groups");
    drop(reader);
    assert!(!groups.is_empty(), "expected at least one row group");

    let mut writer = TableWriter::open(&schema).expect("TableWriter::open");
    for g in &groups { writer.emit(g).expect("emit"); }
    let out = writer.close_get_bytes().expect("close_get_bytes");
    let cx_out = from_data_bin(&reframe(&out)).expect("from_data_bin(out)");
    assert!(cx_out.contains("alice") && cx_out.contains("frank"),
            "missing alice/frank in streamed round-trip: {}", cx_out);
}

#[test]
fn test_streaming_table_fd_round_trip() {
    let _g = TEST_LOCK.lock().unwrap();
    use std::os::unix::io::AsRawFd;

    let payload = to_data_bin_chunked(SIX_ROW_INPUT).expect("to_data_bin_chunked");
    let mut reader = TableReader::open(&payload).expect("reader open");
    let schema = reader.schema().expect("schema");
    let groups: Vec<Vec<u8>> = std::iter::from_fn(|| reader.next_row_group().transpose())
        .collect::<Result<Vec<_>, _>>().expect("groups");
    drop(reader);

    let tmpdir = std::env::temp_dir();
    let path = tmpdir.join(format!("cx_streaming_table_rust_{}.cxcol", std::process::id()));

    let f_write = std::fs::OpenOptions::new()
        .create(true).write(true).truncate(true).open(&path).expect("open write");
    {
        let mut writer = TableWriter::open_fd(&schema, f_write.as_raw_fd()).expect("open_fd writer");
        for g in &groups { writer.emit(g).expect("fd emit"); }
        // Drop closes; flushes end-of-table.
    }
    drop(f_write);

    let f_read = std::fs::File::open(&path).expect("open read");
    let mut reader2 = TableReader::open_fd(f_read.as_raw_fd()).expect("open_fd reader");
    let rt_schema = reader2.schema().expect("rt schema");
    assert_eq!(rt_schema, schema, "fd schema drift");
    let rt_groups: Vec<Vec<u8>> = std::iter::from_fn(|| reader2.next_row_group().transpose())
        .collect::<Result<Vec<_>, _>>().expect("rt groups");
    drop(reader2);
    drop(f_read);
    let _ = std::fs::remove_file(&path);
    assert_eq!(rt_groups.len(), groups.len(), "group count drift");
}

#[test]
fn test_open_invalid_input() {
    let _g = TEST_LOCK.lock().unwrap();
    let r = TableReader::open(b"garb");
    assert!(r.is_err(), "expected error on invalid CXCol input");
}
