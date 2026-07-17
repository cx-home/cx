// cx_arrow_shim.cc — Parquet + Arrow IPC (Feather v2) file I/O bridged to the
// Arrow C-Data ABI, for libcx_arrow "Phase C".
//
// The cx side already converts CX columnar data_bin <-> the Arrow C-Data ABI
// (ArrowArrayStream) via cx_arrow_export_open / cx_arrow_import_to_data_bin.
// This shim plugs Apache Arrow C++ file readers/writers onto that same
// ArrowArrayStream, so a file round-trips through the existing bridge with no
// duplicated columnar logic:
//
//   write:  data_bin --(cx export)--> ArrowArrayStream --(this shim)--> file
//   read:   file --(this shim)--> ArrowArrayStream --(cx import)--> data_bin
//
// Each function returns 0 on success, non-zero on failure with *err set to a
// malloc'd message the caller frees (cx_arrow_free / libc free). Linked only
// into the optional libcx_arrow; core libcx never pulls libarrow/libparquet.

#include <cstdlib>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

#include <arrow/c/bridge.h>
#include <arrow/io/file.h>
#include <arrow/ipc/reader.h>
#include <arrow/ipc/writer.h>
#include <arrow/record_batch.h>
#include <arrow/result.h>
#include <arrow/status.h>
#include <arrow/table.h>
#include <parquet/arrow/reader.h>
#include <parquet/arrow/writer.h>

extern "C" {

static char* dup_err(const std::string& s) {
  char* p = static_cast<char*>(malloc(s.size() + 1));
  if (p) memcpy(p, s.c_str(), s.size() + 1);
  return p;
}

static void set_err(char** err, const std::string& s) {
  if (err) *err = dup_err(s);
}

// Import an ArrowArrayStream (ownership transferred) into one in-memory Table.
static arrow::Result<std::shared_ptr<arrow::Table>>
stream_to_table(struct ArrowArrayStream* in) {
  ARROW_ASSIGN_OR_RAISE(auto reader, arrow::ImportRecordBatchReader(in));
  return reader->ToTable();
}

// Export a Table to a fresh ArrowArrayStream that owns the Table (kept alive by
// the reader the stream wraps, so it survives until the caller's release()).
static arrow::Status table_to_stream(std::shared_ptr<arrow::Table> table,
                                     struct ArrowArrayStream* out) {
  auto reader = std::make_shared<arrow::TableBatchReader>(table);
  return arrow::ExportRecordBatchReader(reader, out);
}

// ── Parquet ──────────────────────────────────────────────────────────

int cx_pq_write_stream(struct ArrowArrayStream* in, const char* path, char** err) {
  auto table = stream_to_table(in);
  if (!table.ok()) { set_err(err, table.status().ToString()); return 1; }

  auto outfile = arrow::io::FileOutputStream::Open(std::string(path));
  if (!outfile.ok()) { set_err(err, outfile.status().ToString()); return 1; }

  auto st = parquet::arrow::WriteTable(**table, arrow::default_memory_pool(),
                                       *outfile, 65536);
  if (!st.ok()) { set_err(err, st.ToString()); return 1; }

  auto cst = (*outfile)->Close();
  if (!cst.ok()) { set_err(err, cst.ToString()); return 1; }
  return 0;
}

int cx_pq_read_stream(const char* path, struct ArrowArrayStream* out, char** err) {
  auto infile = arrow::io::ReadableFile::Open(std::string(path));
  if (!infile.ok()) { set_err(err, infile.status().ToString()); return 1; }

  auto reader_res = parquet::arrow::OpenFile(*infile, arrow::default_memory_pool());
  if (!reader_res.ok()) { set_err(err, reader_res.status().ToString()); return 1; }
  auto reader = std::move(*reader_res);

  auto table = reader->ReadTable();
  if (!table.ok()) { set_err(err, table.status().ToString()); return 1; }

  auto est = table_to_stream(*table, out);
  if (!est.ok()) { set_err(err, est.ToString()); return 1; }
  return 0;
}

// ── Arrow IPC (Feather v2 / .arrow file format) ──────────────────────

int cx_ipc_write_stream(struct ArrowArrayStream* in, const char* path, char** err) {
  auto reader_res = arrow::ImportRecordBatchReader(in);
  if (!reader_res.ok()) { set_err(err, reader_res.status().ToString()); return 1; }
  auto reader = *reader_res;

  auto outfile = arrow::io::FileOutputStream::Open(std::string(path));
  if (!outfile.ok()) { set_err(err, outfile.status().ToString()); return 1; }

  auto writer_res = arrow::ipc::MakeFileWriter(*outfile, reader->schema());
  if (!writer_res.ok()) { set_err(err, writer_res.status().ToString()); return 1; }
  auto writer = *writer_res;

  while (true) {
    std::shared_ptr<arrow::RecordBatch> batch;
    auto st = reader->ReadNext(&batch);
    if (!st.ok()) { set_err(err, st.ToString()); return 1; }
    if (!batch) break;
    auto wst = writer->WriteRecordBatch(*batch);
    if (!wst.ok()) { set_err(err, wst.ToString()); return 1; }
  }

  auto wcst = writer->Close();
  if (!wcst.ok()) { set_err(err, wcst.ToString()); return 1; }
  auto cst = (*outfile)->Close();
  if (!cst.ok()) { set_err(err, cst.ToString()); return 1; }
  return 0;
}

int cx_ipc_read_stream(const char* path, struct ArrowArrayStream* out, char** err) {
  auto infile = arrow::io::ReadableFile::Open(std::string(path));
  if (!infile.ok()) { set_err(err, infile.status().ToString()); return 1; }

  auto reader_res = arrow::ipc::RecordBatchFileReader::Open(*infile);
  if (!reader_res.ok()) { set_err(err, reader_res.status().ToString()); return 1; }
  auto file_reader = *reader_res;

  std::vector<std::shared_ptr<arrow::RecordBatch>> batches;
  for (int i = 0; i < file_reader->num_record_batches(); i++) {
    auto b = file_reader->ReadRecordBatch(i);
    if (!b.ok()) { set_err(err, b.status().ToString()); return 1; }
    batches.push_back(*b);
  }

  auto table_res = arrow::Table::FromRecordBatches(file_reader->schema(), batches);
  if (!table_res.ok()) { set_err(err, table_res.status().ToString()); return 1; }

  auto est = table_to_stream(*table_res, out);
  if (!est.ok()) { set_err(err, est.ToString()); return 1; }
  return 0;
}

}  // extern "C"
