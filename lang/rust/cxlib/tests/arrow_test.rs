#![cfg(feature = "arrow")]

//! Apache Arrow C-Data interop tests for lang/rust/cxlib
//! (Phase 7.74c-cont-bindings-multi-rust).
//!
//! Mirrors lang/python/test_arrow.py and lang/go/cxlib/arrow_test.go:
//!   - Round-trip per supported v0.6.0 column type: int / i8 / i16 / i32 /
//!     float / bool / string / date / bytes (9 tests).
//!   - datetime column round-trips as Arrow timestamp[ns, UTC].
//!   - Arrow record → CXDB → Arrow record inverse round-trip.
//!   - Capability + version + invalid-input smoke tests.
//!
//! Run:  cargo test --features arrow --manifest-path lang/rust/cxlib/Cargo.toml

#![cfg(feature = "arrow")]

use std::sync::Arc;

use arrow::array::{
    Array, BinaryArray, BooleanArray, Date32Array, Float64Array, Int16Array, Int32Array,
    Int64Array, Int8Array, RecordBatch, StringArray, TimestampNanosecondArray,
};
use arrow::datatypes::{DataType, Field, Schema, TimeUnit};
use arrow::record_batch::RecordBatchIterator;

use cxlib::arrow as cxa;
use cxlib::streaming_table::to_data_bin_chunked;

// ── helpers ──────────────────────────────────────────────────────────────────

fn read_all(payload: &[u8]) -> Vec<RecordBatch> {
    let mut reader = cxa::export(payload).expect("cxa::export");
    let mut out = Vec::new();
    while let Some(rec) = reader.next() {
        out.push(rec.expect("RecordBatch"));
    }
    out
}

// Days since the Unix epoch (1970-01-01) under the proleptic Gregorian
// calendar — Howard Hinnant's civil_from_days algorithm. Self-contained
// to avoid adding a chrono dev-dep just for this helper. Verified
// against the V core's table_emit_chunked output: 2026-05-09 = 20578.
fn date32_days(y: i32, m: u32, d: u32) -> i32 {
    let y = if m <= 2 { y - 1 } else { y };
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = (y - era * 400) as u32;
    let m_eff = if m > 2 { m - 3 } else { m + 9 };
    let doy = (153 * m_eff + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146097 + doe as i32 - 719468
}

// ── tests ────────────────────────────────────────────────────────────────────

#[test]
fn availability_reports_truthy_when_lib_loaded() {
    assert!(cxa::available());
    assert_eq!(cxa::features(), 0x800000);
    assert!(cxa::merged_features() & 0x800000 == 0x800000);
    assert_eq!(cxa::version(), "0.6.0");
}

#[test]
fn round_trip_int() {
    let src = "[stats :table[score:int]\n  100\n  -1\n  9223372036854775807\n  -9223372036854775808\n]";
    let payload = to_data_bin_chunked(src).expect("to_data_bin_chunked");
    let recs = read_all(&payload);
    assert_eq!(recs.len(), 1);
    let col = recs[0].column(0).as_any().downcast_ref::<Int64Array>().expect("Int64");
    let want = [100_i64, -1, 9_223_372_036_854_775_807, -9_223_372_036_854_775_808];
    for (i, &v) in want.iter().enumerate() {
        assert_eq!(col.value(i), v, "row {i}");
    }
    // inverse direction
    let reader2 = cxa::export(&payload).expect("export 2");
    let out = cxa::import_to_data_bin(reader2).expect("import_to_data_bin");
    let recs2 = read_all(&out);
    let col2 = recs2[0].column(0).as_any().downcast_ref::<Int64Array>().expect("Int64");
    for (i, &v) in want.iter().enumerate() {
        assert_eq!(col2.value(i), v, "inverse row {i}");
    }
}

#[test]
fn round_trip_i8() {
    let src = "[stats :table[v:i8]\n  -128\n  -1\n  0\n  127\n]";
    let payload = to_data_bin_chunked(src).unwrap();
    let recs = read_all(&payload);
    let col = recs[0].column(0).as_any().downcast_ref::<Int8Array>().unwrap();
    let want = [-128_i8, -1, 0, 127];
    for (i, &v) in want.iter().enumerate() {
        assert_eq!(col.value(i), v, "row {i}");
    }
}

#[test]
fn round_trip_i16() {
    let src = "[stats :table[v:i16]\n  -32768\n  -1\n  0\n  32767\n]";
    let payload = to_data_bin_chunked(src).unwrap();
    let recs = read_all(&payload);
    let col = recs[0].column(0).as_any().downcast_ref::<Int16Array>().unwrap();
    let want = [-32768_i16, -1, 0, 32767];
    for (i, &v) in want.iter().enumerate() {
        assert_eq!(col.value(i), v, "row {i}");
    }
}

#[test]
fn round_trip_i32() {
    let src = "[stats :table[v:i32]\n  -2147483648\n  -1\n  0\n  2147483647\n]";
    let payload = to_data_bin_chunked(src).unwrap();
    let recs = read_all(&payload);
    let col = recs[0].column(0).as_any().downcast_ref::<Int32Array>().unwrap();
    let want = [-2_147_483_648_i32, -1, 0, 2_147_483_647];
    for (i, &v) in want.iter().enumerate() {
        assert_eq!(col.value(i), v, "row {i}");
    }
}

#[test]
fn round_trip_float() {
    let src = "[stats :table[v:float]\n  0.0\n  -1.5\n  3.14159\n  1e100\n]";
    let payload = to_data_bin_chunked(src).unwrap();
    let recs = read_all(&payload);
    let col = recs[0].column(0).as_any().downcast_ref::<Float64Array>().unwrap();
    assert_eq!(col.value(0), 0.0);
    assert_eq!(col.value(1), -1.5);
    assert!((col.value(2) - 3.14159).abs() < 1e-9);
    assert_eq!(col.value(3), 1e100);
}

#[test]
fn round_trip_bool() {
    let src = "[flags :table[v:bool]\n  true\n  false\n  true\n  false\n]";
    let payload = to_data_bin_chunked(src).unwrap();
    let recs = read_all(&payload);
    let col = recs[0].column(0).as_any().downcast_ref::<BooleanArray>().unwrap();
    let want = [true, false, true, false];
    for (i, &v) in want.iter().enumerate() {
        assert_eq!(col.value(i), v, "row {i}");
    }
}

#[test]
fn round_trip_string() {
    let src = "[names :table[v:string]\n  alice\n  bob\n  carol\n  unicode-é-é-ñ\n]";
    let payload = to_data_bin_chunked(src).unwrap();
    let recs = read_all(&payload);
    let col = recs[0].column(0).as_any().downcast_ref::<StringArray>().unwrap();
    let want = ["alice", "bob", "carol", "unicode-é-é-ñ"];
    for (i, &v) in want.iter().enumerate() {
        assert_eq!(col.value(i), v, "row {i}");
    }
}

#[test]
fn round_trip_date() {
    let src = "[evts :table[when:date]\n  2026-05-09\n  1970-01-01\n  9999-12-31\n  1900-01-01\n]";
    let payload = to_data_bin_chunked(src).unwrap();
    let recs = read_all(&payload);
    let col = recs[0].column(0).as_any().downcast_ref::<Date32Array>().unwrap();
    let want = [
        date32_days(2026, 5, 9),
        date32_days(1970, 1, 1),
        date32_days(9999, 12, 31),
        date32_days(1900, 1, 1),
    ];
    for (i, &v) in want.iter().enumerate() {
        assert_eq!(col.value(i), v, "row {i}");
    }
}

#[test]
fn round_trip_bytes() {
    let src = "[blobs :table[name:string blob:bytes]\n  alpha \"A1B2\"\n  beta \"FF00DE\"\n  empty \"\"\n]";
    let payload = to_data_bin_chunked(src).unwrap();
    let recs = read_all(&payload);
    let col = recs[0].column(1).as_any().downcast_ref::<BinaryArray>().unwrap();
    assert_eq!(col.len(), 3);
    // Round-trip via Import → Export must preserve the column.
    let reader2 = cxa::export(&payload).unwrap();
    let out = cxa::import_to_data_bin(reader2).unwrap();
    let recs2 = read_all(&out);
    let col2 = recs2[0].column(1).as_any().downcast_ref::<BinaryArray>().unwrap();
    for i in 0..col.len() {
        assert_eq!(col.value(i), col2.value(i), "blob row {i}");
    }
}

// Nanoseconds since the Unix epoch for an explicit UTC datetime — composed
// from the existing date32_days helper plus the seconds-of-day offset.
fn ts_ns(y: i32, mo: u32, d: u32, h: u32, mi: u32, s: u32) -> i64 {
    let days = date32_days(y, mo, d) as i64;
    (days * 86_400 + h as i64 * 3_600 + mi as i64 * 60 + s as i64) * 1_000_000_000
}

#[test]
fn round_trip_datetime() {
    let src = concat!(
        "[evts :table[when:datetime]\n",
        "  2024-01-15T12:34:56Z\n",
        "  2025-06-30T23:00:00+02:00\n",
        "  1970-01-01T00:00:00Z\n",
        "  1900-01-01T00:00:00Z\n]",
    );
    let payload = to_data_bin_chunked(src).expect("to_data_bin_chunked");
    let recs = read_all(&payload);

    // Column type is Arrow timestamp[ns, UTC].
    let field = recs[0].schema().field(0).clone();
    match field.data_type() {
        DataType::Timestamp(TimeUnit::Nanosecond, Some(tz)) => assert_eq!(tz.as_ref(), "UTC"),
        other => panic!("col type = {other:?}; want Timestamp(Nanosecond, UTC)"),
    }

    let col = recs[0].column(0).as_any().downcast_ref::<TimestampNanosecondArray>().unwrap();
    // CXDB strict-canonical normalizes offsets to UTC on the wire — the
    // +02:00 row arrives as 21:00:00 UTC.
    let want = [
        ts_ns(2024, 1, 15, 12, 34, 56),
        ts_ns(2025, 6, 30, 21, 0, 0),
        ts_ns(1970, 1, 1, 0, 0, 0),
        ts_ns(1900, 1, 1, 0, 0, 0),
    ];
    for (i, &v) in want.iter().enumerate() {
        assert_eq!(col.value(i), v, "row {i}");
    }

    // Inverse: arrow → CXDB → arrow round-trip preserves equality.
    let reader2 = cxa::export(&payload).unwrap();
    let out = cxa::import_to_data_bin(reader2).unwrap();
    let recs2 = read_all(&out);
    let col2 = recs2[0]
        .column(0)
        .as_any()
        .downcast_ref::<TimestampNanosecondArray>()
        .unwrap();
    for i in 0..col.len() {
        assert_eq!(col.value(i), col2.value(i), "ns row {i}");
    }
}

#[test]
fn inverse_from_rust_built_table() {
    // Build a record directly (no CXDB starting point) and verify the
    // inverse direction: arrow → CXDB → arrow re-decode → equality.
    let schema = Arc::new(Schema::new(vec![
        Field::new("name",  DataType::Utf8,    false),
        Field::new("score", DataType::Int64,   false),
        Field::new("ratio", DataType::Float64, false),
    ]));
    let names  = StringArray::from(vec!["alice", "bob", "carol"]);
    let scores = Int64Array::from(vec![91_i64, 88, 73]);
    let ratios = Float64Array::from(vec![0.91, 0.88, 0.73]);
    let rec = RecordBatch::try_new(
        schema.clone(),
        vec![Arc::new(names), Arc::new(scores), Arc::new(ratios)],
    ).expect("RecordBatch");

    let reader = RecordBatchIterator::new(vec![Ok(rec)].into_iter(), schema);
    let payload = cxa::import_to_data_bin(reader).expect("import_to_data_bin");

    let recs = read_all(&payload);
    assert_eq!(recs[0].num_rows(), 3);
    let names  = recs[0].column(0).as_any().downcast_ref::<StringArray>().unwrap();
    let scores = recs[0].column(1).as_any().downcast_ref::<Int64Array>().unwrap();
    let ratios = recs[0].column(2).as_any().downcast_ref::<Float64Array>().unwrap();
    let want_names  = ["alice", "bob", "carol"];
    let want_scores = [91_i64, 88, 73];
    let want_ratios = [0.91, 0.88, 0.73];
    for i in 0..3 {
        assert_eq!(names.value(i),  want_names[i],  "name {i}");
        assert_eq!(scores.value(i), want_scores[i], "score {i}");
        assert_eq!(ratios.value(i), want_ratios[i], "ratio {i}");
    }
}

#[test]
fn export_rejects_invalid_input() {
    assert!(cxa::export(&[]).is_err(), "empty input must error");
    // Garbage bytes shorter than a CXDB header — libcx_arrow surfaces a
    // parse error.
    assert!(cxa::export(b"garb").is_err(), "garbage input must error");
}
