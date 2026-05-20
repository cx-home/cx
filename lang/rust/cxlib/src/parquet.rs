//! Parquet read/write bridge for cxlib (X-row / v0.7.0).
//!
//! Per ADR 0015 D11, Parquet lives at the binding layer. This module
//! composes the existing `cxlib::arrow` surface with the `parquet`
//! crate's arrow-bridge writers/readers so a Rust user can do one
//! call CX <-> Parquet without pulling Parquet C++ into libcx.
//!
//! Gated behind the `parquet` Cargo feature (which implies `arrow`).
//!
//! ```ignore
//! cxlib::parquet::write_file(&framed, "out.parquet",
//!     cxlib::parquet::WriteOptions::default())?;
//! let framed_back = cxlib::parquet::read_file("out.parquet")?;
//! ```

use std::fs::File;
use std::path::Path;

use arrow::array::RecordBatchReader;
use parquet::arrow::arrow_reader::ParquetRecordBatchReaderBuilder;
use parquet::arrow::ArrowWriter;
use parquet::basic::Compression;
use parquet::file::properties::WriterProperties;

/// Options for `write_file`. `Default` selects snappy compression.
#[derive(Debug, Clone)]
pub struct WriteOptions {
    /// Parquet compression codec.
    pub compression: Compression,
}

impl Default for WriteOptions {
    fn default() -> Self {
        Self {
            compression: Compression::SNAPPY,
        }
    }
}

/// Write framed CXDB chunked-table bytes to a Parquet file.
///
/// Composes `cxlib::arrow::export` -> RecordReader -> Parquet via the
/// `parquet` crate's `ArrowWriter`.
pub fn write_file<P: AsRef<Path>>(
    cx_data_bin: &[u8],
    path: P,
    opts: WriteOptions,
) -> Result<(), String> {
    let mut reader = crate::arrow::export(cx_data_bin)?;
    let schema = reader.schema();
    let file = File::create(path.as_ref())
        .map_err(|e| format!("cxlib::parquet::write_file: create: {e}"))?;
    let props = WriterProperties::builder()
        .set_compression(opts.compression)
        .build();
    let mut writer = ArrowWriter::try_new(file, schema, Some(props))
        .map_err(|e| format!("cxlib::parquet::write_file: ArrowWriter: {e}"))?;
    while let Some(batch) = reader.next() {
        let batch = batch
            .map_err(|e| format!("cxlib::parquet::write_file: reader: {e}"))?;
        writer
            .write(&batch)
            .map_err(|e| format!("cxlib::parquet::write_file: write: {e}"))?;
    }
    writer
        .close()
        .map_err(|e| format!("cxlib::parquet::write_file: close: {e}"))?;
    Ok(())
}

/// Read a Parquet file and return the framed CXDB chunked-table bytes.
///
/// Composes `parquet`'s `ParquetRecordBatchReaderBuilder` with
/// `cxlib::arrow::import_to_data_bin`. The returned bytes are framed
/// (`[u32 LE size][CXDB payload]`) and feed directly into
/// `cxlib::from_data_bin` or the streaming-table reader.
pub fn read_file<P: AsRef<Path>>(path: P) -> Result<Vec<u8>, String> {
    let file = File::open(path.as_ref())
        .map_err(|e| format!("cxlib::parquet::read_file: open: {e}"))?;
    let builder = ParquetRecordBatchReaderBuilder::try_new(file)
        .map_err(|e| format!("cxlib::parquet::read_file: builder: {e}"))?;
    let reader = builder
        .build()
        .map_err(|e| format!("cxlib::parquet::read_file: build: {e}"))?;
    crate::arrow::import_to_data_bin(reader)
}
