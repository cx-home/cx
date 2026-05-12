# frozen_string_literal: true
#
# Streaming Table reader / writer + schema-driven CXDB encoding +
# chunked-table one-shot for the CX Ruby binding.
#
# Per spec/abi.md §§2.10 / 2.12 (capability bits 21 / 24) and
# ADR 0015 D3 / D8. Phase 7.74b-cont-3.
#
# Wire conventions (mirroring the C ABI):
#   - `to_data_bin_chunked` returns UNFRAMED CXDB payload bytes,
#     matching the existing `xxx_to_data_bin` shape in cxlib.rb.
#   - `xxx_to_data_bin_schema_driven` returns UNFRAMED payload too.
#   - `from_data_bin_schema_driven` takes a FRAMED buffer.
#   - The streaming `TableReader` / `TableWriter` exchange FRAMED
#     bytes end-to-end (col-spec, row groups, output buffer) — this
#     matches the C ABI's pull/push shape and avoids re-framing on
#     every step.
#   - fd variants of the streaming API operate on bare CXDB bytes.

require 'ffi'

module CXLib
  # ── 21 attach_function decls (analytics-bridge surface) ──────────────────────

  # Chunked-table one-shot.
  attach_function :cx_to_data_bin_chunked, [:string, :pointer], :pointer

  # Streaming Table reader / writer (handle-based pull / push).
  attach_function :cx_table_reader_open,     [:buffer_in, :pointer], :pointer
  attach_function :cx_table_reader_open_fd,  [:int,       :pointer], :pointer
  attach_function :cx_table_reader_schema,   [:pointer,   :pointer], :pointer
  attach_function :cx_table_reader_next,     [:pointer,   :pointer], :pointer
  attach_function :cx_table_reader_close,    [:pointer],             :void

  attach_function :cx_table_writer_open,            [:buffer_in, :pointer], :pointer
  attach_function :cx_table_writer_open_fd,         [:buffer_in, :int, :pointer], :pointer
  attach_function :cx_table_writer_emit_row_group,  [:pointer, :buffer_in, :pointer], :pointer
  attach_function :cx_table_writer_close_get_bytes, [:pointer, :pointer], :pointer
  attach_function :cx_table_writer_close,           [:pointer], :void

  # Schema-driven loaders / dumper.
  attach_function :cx_to_data_bin_schema_driven,
                  [:string, :string, :int, :string, :pointer], :pointer
  attach_function :cx_xml_to_data_bin_schema_driven,
                  [:string, :string, :int, :string, :pointer], :pointer
  attach_function :cx_json_to_data_bin_schema_driven,
                  [:string, :string, :int, :string, :pointer], :pointer
  attach_function :cx_yaml_to_data_bin_schema_driven,
                  [:string, :string, :int, :string, :pointer], :pointer
  attach_function :cx_toml_to_data_bin_schema_driven,
                  [:string, :string, :int, :string, :pointer], :pointer
  attach_function :cx_md_to_data_bin_schema_driven,
                  [:string, :string, :int, :string, :pointer], :pointer
  attach_function :cx_csv_to_data_bin_schema_driven,
                  [:string, :string, :int, :string, :pointer], :pointer
  attach_function :cx_tsv_to_data_bin_schema_driven,
                  [:string, :string, :int, :string, :pointer], :pointer
  attach_function :cx_psv_to_data_bin_schema_driven,
                  [:string, :string, :int, :string, :pointer], :pointer
  attach_function :cx_from_data_bin_schema_driven,
                  [:buffer_in, :string, :pointer], :pointer

  # ── helpers ──────────────────────────────────────────────────────────────────

  # Read a libcx-owned [u32 LE size][payload] buffer at `ptr` and return
  # the FRAMED bytes verbatim (frame preserved). Caller must `cx_free(ptr)`.
  def self._read_framed_at(ptr)
    size = ptr.read_bytes(4).unpack1('V')
    ptr.read_bytes(4 + size)
  end

  # Read err pointer and raise. err_ptr is the FFI::MemoryPointer
  # passed to the libcx call; `fallback` is used when no message is set.
  def self._raise_err(err_ptr, fallback)
    ep = err_ptr.read_pointer
    msg = ep.null? ? fallback : ep.read_string.force_encoding('UTF-8')
    cx_free(ep) unless ep.null?
    raise RuntimeError, msg
  end

  # ── one-shot: chunked-table encoder ──────────────────────────────────────────

  # Encode CX text whose root is a single :table-bodied element to CXDB
  # chunked-table form (`0x63`). Returns UNFRAMED CXDB PAYLOAD bytes
  # (matches the existing `xxx_to_data_bin` shape; frame stripped).
  def self.to_data_bin_chunked(input)
    _call_bin(:cx_to_data_bin_chunked, input)
  end

  # ── schema-driven loaders / dumper ───────────────────────────────────────────

  # Schema reference embedding form for the schema-driven loaders.
  module SchemaRefForm
    CONTENT_HASH        = 0  # default (§3.13.1 tag 0x10)
    INLINE              = 1  # inline schema bytes (tag 0x11)
    HASH_WITH_NAME_HINT = 2  # hash + name hint (tag 0x12)
  end

  # Internal: shared loader path. Returns UNFRAMED payload bytes.
  def self._call_schema_driven_loader(fn_sym, input, schema, ref_form, name_hint)
    err_ptr = FFI::MemoryPointer.new(:pointer)
    out = send(fn_sym, input, schema, ref_form, (name_hint || ''), err_ptr)
    _raise_err(err_ptr, "#{fn_sym}: unknown error") if out.null?
    size = out.read_bytes(4).unpack1('V')
    payload = out.get_bytes(4, size)
    cx_free(out)
    payload
  end

  def self.to_data_bin_schema_driven(input, schema,
                                      ref_form: SchemaRefForm::CONTENT_HASH,
                                      name_hint: nil)
    _call_schema_driven_loader(:cx_to_data_bin_schema_driven,
                                input, schema, ref_form, name_hint)
  end

  def self.xml_to_data_bin_schema_driven(input, schema,
                                          ref_form: SchemaRefForm::CONTENT_HASH,
                                          name_hint: nil)
    _call_schema_driven_loader(:cx_xml_to_data_bin_schema_driven,
                                input, schema, ref_form, name_hint)
  end

  def self.json_to_data_bin_schema_driven(input, schema,
                                           ref_form: SchemaRefForm::CONTENT_HASH,
                                           name_hint: nil)
    _call_schema_driven_loader(:cx_json_to_data_bin_schema_driven,
                                input, schema, ref_form, name_hint)
  end

  def self.yaml_to_data_bin_schema_driven(input, schema,
                                           ref_form: SchemaRefForm::CONTENT_HASH,
                                           name_hint: nil)
    _call_schema_driven_loader(:cx_yaml_to_data_bin_schema_driven,
                                input, schema, ref_form, name_hint)
  end

  def self.toml_to_data_bin_schema_driven(input, schema,
                                           ref_form: SchemaRefForm::CONTENT_HASH,
                                           name_hint: nil)
    _call_schema_driven_loader(:cx_toml_to_data_bin_schema_driven,
                                input, schema, ref_form, name_hint)
  end

  def self.md_to_data_bin_schema_driven(input, schema,
                                         ref_form: SchemaRefForm::CONTENT_HASH,
                                         name_hint: nil)
    _call_schema_driven_loader(:cx_md_to_data_bin_schema_driven,
                                input, schema, ref_form, name_hint)
  end

  def self.csv_to_data_bin_schema_driven(input, schema,
                                          ref_form: SchemaRefForm::CONTENT_HASH,
                                          name_hint: nil)
    _call_schema_driven_loader(:cx_csv_to_data_bin_schema_driven,
                                input, schema, ref_form, name_hint)
  end

  def self.tsv_to_data_bin_schema_driven(input, schema,
                                          ref_form: SchemaRefForm::CONTENT_HASH,
                                          name_hint: nil)
    _call_schema_driven_loader(:cx_tsv_to_data_bin_schema_driven,
                                input, schema, ref_form, name_hint)
  end

  def self.psv_to_data_bin_schema_driven(input, schema,
                                          ref_form: SchemaRefForm::CONTENT_HASH,
                                          name_hint: nil)
    _call_schema_driven_loader(:cx_psv_to_data_bin_schema_driven,
                                input, schema, ref_form, name_hint)
  end

  # Decode a FRAMED schema-driven CXDB buffer to canonical CX text.
  # `schema_hint` is consulted when the embedded reference is
  # content-hash-only and not resolvable from a content-addressable
  # store; pass `nil` or `''` to rely on embedded resolution alone.
  def self.from_data_bin_schema_driven(framed, schema_hint: nil)
    raise 'cx_from_data_bin_schema_driven: empty input' if framed.nil? || framed.bytesize == 0
    err_ptr = FFI::MemoryPointer.new(:pointer)
    out = cx_from_data_bin_schema_driven(framed, (schema_hint || ''), err_ptr)
    _raise_err(err_ptr, 'cx_from_data_bin_schema_driven: unknown error') if out.null?
    s = out.read_string.force_encoding('UTF-8')
    cx_free(out)
    s
  end

  # ── TableReader ──────────────────────────────────────────────────────────────

  # Streaming reader over a chunked-table CXDB buffer or fd. Iterating
  # yields each row group as FRAMED `[u32 LE size][plain body]` bytes
  # (compressed groups are decompressed by the V core before return).
  class TableReader
    include Enumerable

    # Open over an in-memory FRAMED chunked-table buffer or a POSIX fd.
    # Pass exactly one of `data_bin:` or `fd:`.
    def initialize(data_bin: nil, fd: nil)
      raise ArgumentError, 'TableReader: pass exactly one of data_bin / fd' \
        unless (data_bin.nil?) ^ (fd.nil?)
      err_ptr = FFI::MemoryPointer.new(:pointer)
      handle = if fd.nil?
                 CXLib.cx_table_reader_open(data_bin, err_ptr)
               else
                 CXLib.cx_table_reader_open_fd(fd, err_ptr)
               end
      if handle.null?
        ep = err_ptr.read_pointer
        msg = ep.null? ? 'cx_table_reader_open: unknown error' : ep.read_string
        CXLib.cx_free(ep) unless ep.null?
        raise RuntimeError, msg
      end
      @handle = handle
      @closed = false
    end

    # Return the table's column spec as FRAMED ast_bin (root Element
    # 'table' with one Attribute per column: name → type-name).
    def schema
      raise RuntimeError, 'TableReader: handle closed' if @closed || @handle.nil?
      err_ptr = FFI::MemoryPointer.new(:pointer)
      ptr = CXLib.cx_table_reader_schema(@handle, err_ptr)
      if ptr.null?
        ep = err_ptr.read_pointer
        msg = ep.null? ? 'cx_table_reader_schema: unknown error' : ep.read_string
        CXLib.cx_free(ep) unless ep.null?
        raise RuntimeError, msg
      end
      out = CXLib._read_framed_at(ptr)
      CXLib.cx_free(ptr)
      out
    end

    # Pull the next row group as FRAMED bytes, or nil at end-of-table.
    def next_row_group
      return nil if @closed || @handle.nil?
      err_ptr = FFI::MemoryPointer.new(:pointer)
      ptr = CXLib.cx_table_reader_next(@handle, err_ptr)
      if ptr.null?
        ep = err_ptr.read_pointer
        if ep.null?
          return nil  # EOF
        end
        msg = ep.read_string
        CXLib.cx_free(ep)
        close
        raise RuntimeError, msg
      end
      out = CXLib._read_framed_at(ptr)
      CXLib.cx_free(ptr)
      out
    end

    # Yield each row group's FRAMED bytes.
    def each
      return enum_for(:each) unless block_given?
      while (g = next_row_group)
        yield g
      end
    end

    def close
      return if @closed
      @closed = true
      if @handle && !@handle.null?
        CXLib.cx_table_reader_close(@handle)
        @handle = nil
      end
    end

    def closed? = @closed
  end

  # ── TableWriter ──────────────────────────────────────────────────────────────

  # Streaming writer for the chunked-table CXDB format.
  class TableWriter
    # Open an in-memory writer (returns the framed buffer via
    # `close_get_bytes`) or an fd writer (streams bytes to the fd; close
    # with `close`). `col_spec_payload` is the FRAMED ast_bin shape
    # returned by `TableReader#schema`.
    def initialize(col_spec_payload, fd: nil)
      err_ptr = FFI::MemoryPointer.new(:pointer)
      handle = if fd.nil?
                 CXLib.cx_table_writer_open(col_spec_payload, err_ptr)
               else
                 CXLib.cx_table_writer_open_fd(col_spec_payload, fd, err_ptr)
               end
      if handle.null?
        ep = err_ptr.read_pointer
        msg = ep.null? ? 'cx_table_writer_open: unknown error' : ep.read_string
        CXLib.cx_free(ep) unless ep.null?
        raise RuntimeError, msg
      end
      @handle = handle
      @closed = false
      @fd = fd
    end

    # Append one row group. `row_group_payload` is the FRAMED bytes
    # yielded by `TableReader#next_row_group` / iteration.
    def emit(row_group_payload)
      raise RuntimeError, 'TableWriter: handle closed' if @closed || @handle.nil?
      err_ptr = FFI::MemoryPointer.new(:pointer)
      CXLib.cx_table_writer_emit_row_group(@handle, row_group_payload, err_ptr)
      ep = err_ptr.read_pointer
      unless ep.null?
        msg = ep.read_string
        CXLib.cx_free(ep)
        raise RuntimeError, msg
      end
    end

    # In-memory writers only: emit end-of-table and return the FRAMED
    # chunked-table buffer. The handle is consumed by this call.
    def close_get_bytes
      raise RuntimeError, 'close_get_bytes is for in-memory writers; use close() for fd writers' \
        unless @fd.nil?
      raise RuntimeError, 'TableWriter: handle closed' if @closed || @handle.nil?
      err_ptr = FFI::MemoryPointer.new(:pointer)
      ptr = CXLib.cx_table_writer_close_get_bytes(@handle, err_ptr)
      # V core releases the handle inside close_get_bytes; mark closed.
      @handle = nil
      @closed = true
      if ptr.null?
        ep = err_ptr.read_pointer
        msg = ep.null? ? 'cx_table_writer_close_get_bytes: unknown error' : ep.read_string
        CXLib.cx_free(ep) unless ep.null?
        raise RuntimeError, msg
      end
      out = CXLib._read_framed_at(ptr)
      CXLib.cx_free(ptr)
      out
    end

    # Release the handle. For fd writers, flushes the end-of-table marker.
    def close
      return if @closed
      @closed = true
      if @handle && !@handle.null?
        CXLib.cx_table_writer_close(@handle)
        @handle = nil
      end
    end

    def closed? = @closed
  end
end
