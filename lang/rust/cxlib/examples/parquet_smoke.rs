// Parquet round-trip smoke test (X5 / v0.7.0). Run via:
//
//   DYLD_LIBRARY_PATH=../../../vcx/target \
//     cargo run --features parquet --example parquet_smoke

use std::fs;

fn main() -> Result<(), String> {
    let src = "[points :table[id:int score:int]\n  1 91\n  2 88\n  3 73\n]";
    let framed = cxlib::streaming_table::to_data_bin_chunked(src)?;
    println!("framed: {} bytes", framed.len());

    let tmp = tempfile_path();
    cxlib::parquet::write_file(&framed, &tmp, cxlib::parquet::WriteOptions::default())?;
    let pq_size = fs::metadata(&tmp)
        .map(|m| m.len())
        .map_err(|e| format!("stat: {e}"))?;
    println!("parquet: {pq_size} bytes (snappy)");

    let payload = cxlib::parquet::read_file(&tmp)?;
    println!("payload back: {} bytes (unframed)", payload.len());

    // import_to_data_bin returns unframed payload; from_data_bin
    // expects framed bytes ([u32 LE size][payload]). Re-frame for
    // the round-trip print.
    let mut framed2 = Vec::with_capacity(4 + payload.len());
    framed2.extend_from_slice(&(payload.len() as u32).to_le_bytes());
    framed2.extend_from_slice(&payload);
    println!("framed: {} bytes", framed2.len());

    let cx_text = cxlib::data_bin::from_data_bin(&framed2)?;
    println!("round-trip CX:\n{cx_text}");

    let _ = fs::remove_file(&tmp);
    Ok(())
}

fn tempfile_path() -> String {
    let pid = std::process::id();
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    format!("/tmp/cxlib-parquet-smoke-{pid}-{nanos}.parquet")
}
