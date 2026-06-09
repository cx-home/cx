//go:build arrow

// Parquet read/write bridge for cxlib (X-row / v0.7.0).
//
// Per, Parquet lives at the binding layer (not inside
// libcx). This file composes the existing cxlib.Arrow* path with
// arrow-go/v18's parquet/pqarrow package to provide one-call CX <->
// Parquet round-trips without adding a Parquet C++ dependency to
// libcx.

package cxlib

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"

	"github.com/apache/arrow/go/v18/arrow"
	"github.com/apache/arrow/go/v18/arrow/array"
	"github.com/apache/arrow/go/v18/arrow/memory"
	"github.com/apache/arrow/go/v18/parquet"
	"github.com/apache/arrow/go/v18/parquet/compress"
	"github.com/apache/arrow/go/v18/parquet/pqarrow"
)

// ParquetWriteOptions configures Parquet writes. Zero value = defaults
// (snappy compression, pqarrow's default row group size).
type ParquetWriteOptions struct {
	// Compression: "snappy" (default), "gzip", "zstd", "brotli", "lz4",
	// "uncompressed", or "" to use pqarrow's default.
	Compression string
	// Row group size in rows. 0 = pqarrow default.
	RowGroupSize int64
}

// ParquetWriteFile writes a framed CXCol chunked-table to a Parquet file.
// Composes ArrowExport (cx -> Arrow) with pqarrow.NewFileWriter.
func ParquetWriteFile(cxDataBin []byte, path string, opts ParquetWriteOptions) error {
	reader, err := ArrowExport(cxDataBin)
	if err != nil {
		return fmt.Errorf("cxlib.ParquetWriteFile: ArrowExport: %w", err)
	}
	defer reader.Release()

	f, err := os.Create(path)
	if err != nil {
		return fmt.Errorf("cxlib.ParquetWriteFile: create %s: %w", path, err)
	}
	defer f.Close()

	codec, err := parquetCompressionFromString(opts.Compression)
	if err != nil {
		return err
	}
	props := parquet.NewWriterProperties(
		parquet.WithCompression(codec),
	)
	arrProps := pqarrow.DefaultWriterProps()
	w, err := pqarrow.NewFileWriter(reader.Schema(), f, props, arrProps)
	if err != nil {
		return fmt.Errorf("cxlib.ParquetWriteFile: pqarrow.NewFileWriter: %w", err)
	}
	defer w.Close()

	for reader.Next() {
		rec := reader.Record()
		if err := w.WriteBuffered(rec); err != nil {
			return fmt.Errorf("cxlib.ParquetWriteFile: write batch: %w", err)
		}
	}
	if err := reader.Err(); err != nil {
		return fmt.Errorf("cxlib.ParquetWriteFile: reader: %w", err)
	}
	return nil
}

// ParquetReadFile reads a Parquet file and returns UNFRAMED CXCol
// chunked-table payload bytes (matches ArrowImportToDataBin's
// convention; see lang/go/cxlib/arrow.go). Callers passing the
// result to FromDataBin must wrap it with a 4-byte LE size prefix
// first — FromDataBin expects FRAMED input. The TableReader /
// streaming API consumes unframed payload directly.
func ParquetReadFile(path string) ([]byte, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("cxlib.ParquetReadFile: open %s: %w", path, err)
	}
	defer f.Close()

	rdr, err := pqarrow.ReadTable(context.Background(), f, parquet.NewReaderProperties(nil),
		pqarrow.ArrowReadProperties{}, memory.DefaultAllocator)
	if err != nil {
		return nil, fmt.Errorf("cxlib.ParquetReadFile: pqarrow.ReadTable: %w", err)
	}
	defer rdr.Release()

	// Bridge: convert pqarrow Table -> RecordReader -> ArrowImportToDataBin.
	reader, err := tableToReader(rdr)
	if err != nil {
		return nil, err
	}
	defer reader.Release()
	return ArrowImportToDataBin(reader)
}

func parquetCompressionFromString(s string) (compress.Compression, error) {
	switch s {
	case "", "snappy":
		return compress.Codecs.Snappy, nil
	case "gzip":
		return compress.Codecs.Gzip, nil
	case "zstd":
		return compress.Codecs.Zstd, nil
	case "brotli":
		return compress.Codecs.Brotli, nil
	case "lz4":
		return compress.Codecs.Lz4, nil
	case "uncompressed":
		return compress.Codecs.Uncompressed, nil
	default:
		return 0, fmt.Errorf("cxlib.ParquetWriteFile: unsupported compression %q "+
			"(want snappy / gzip / zstd / brotli / lz4 / uncompressed)", s)
	}
}

func tableToReader(t arrow.Table) (array.RecordReader, error) {
	// pqarrow returns arrow.Table; convert to a chunked RecordReader
	// by iterating its column chunks. The arrow-go API offers
	// array.NewTableReader for exactly this purpose.
	if t == nil {
		return nil, errors.New("cxlib: tableToReader: nil table")
	}
	return array.NewTableReader(t, 0), nil
}

var _ io.Closer = (*os.File)(nil) // documentation pin
