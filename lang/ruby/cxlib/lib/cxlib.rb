# frozen_string_literal: true
#
# CX Ruby binding — thin FFI wrapper around libcx.
# Locates libcx.dylib / libcx.so relative to the repo root.
#
require 'ffi'
require_relative 'cxlib/data_bin'

module CXLib
  extend FFI::Library

  def self._find_lib
    lib_name = FFI::Platform.mac? ? 'libcx.dylib' : 'libcx.so'

    # 1. Explicit path override
    return ENV['LIBCX_PATH'] if ENV['LIBCX_PATH']

    candidates = []

    # 2. Directory override
    candidates << File.join(ENV['LIBCX_LIB_DIR'], lib_name) if ENV['LIBCX_LIB_DIR']

    # 3. System paths
    %w[/usr/local/lib /opt/homebrew/lib /usr/lib
       /usr/lib/x86_64-linux-gnu /usr/lib/aarch64-linux-gnu].each do |dir|
      candidates << File.join(dir, lib_name)
    end

    # 4. Repo-relative fallback (development)
    repo_root = File.expand_path('../../../../../', __FILE__)
    candidates << File.join(repo_root, 'vcx', 'target', lib_name)
    candidates << File.join(repo_root, 'dist', 'lib',   lib_name)

    found = candidates.find { |p| File.exist?(p) }
    raise RuntimeError, "libcx not found. Install with 'sudo make install' or set LIBCX_PATH.\nLooked in: #{candidates.inspect}" unless found
    found
  end

  ffi_lib _find_lib

  # Thread-init handshake (spec/abi.md §1.5.5, capability bit 26).
  # Mandatory-for-all-bindings; called once at module-load time.
  attach_function :cx_init,    [],                  :int

  # memory
  attach_function :cx_free,    [:pointer],          :void
  attach_function :cx_version, [],                  :pointer

  # Run cx_init at module load. Ruby's GVL serialises calls into
  # libcx but cx_init is part of the spec contract (§1.5.5), so we
  # wire it for parity even though the bug Rust hit (Boehm GC
  # trampoline pages) doesn't yet manifest under MRI Ruby.
  cx_init

  # CX input
  attach_function :cx_to_cx,          [:string, :pointer], :pointer
  attach_function :cx_to_cx_compact,  [:string, :pointer], :pointer
  attach_function :cx_ast_to_cx,      [:string, :pointer], :pointer
  attach_function :cx_to_xml,        [:string, :pointer], :pointer
  attach_function :cx_to_ast,        [:string, :pointer], :pointer
  attach_function :cx_to_json,       [:string, :pointer], :pointer
  attach_function :cx_to_yaml,       [:string, :pointer], :pointer
  attach_function :cx_to_toml,       [:string, :pointer], :pointer
  attach_function :cx_to_md,         [:string, :pointer], :pointer
  # CXL evaluator (capability bit 28; spec/eval.md)
  attach_function :cx_eval_cxl,      [:string, :string, :string, :pointer], :pointer
  attach_function :cx_to_ast_bin,    [:string, :pointer], :pointer
  attach_function :cx_to_events_bin, [:string, :pointer], :pointer
  attach_function :cx_to_data_bin,   [:string, :pointer], :pointer
  # cx_from_data_bin takes binary input (framed CXDB bytes), not a C string
  # — declare as :buffer_in so FFI passes the byte content as a pointer
  # without strlen-style interpretation.
  attach_function :cx_from_data_bin, [:buffer_in, :pointer], :pointer

  # data_bin one-shot loaders/dumpers (Phase 7.28; spec/abi.md §2.4–§2.5).
  attach_function :cx_xml_to_data_bin,  [:string, :pointer], :pointer
  attach_function :cx_json_to_data_bin, [:string, :pointer], :pointer
  attach_function :cx_yaml_to_data_bin, [:string, :pointer], :pointer
  attach_function :cx_toml_to_data_bin, [:string, :pointer], :pointer
  attach_function :cx_md_to_data_bin,   [:string, :pointer], :pointer

  attach_function :cx_data_bin_to_xml,  [:buffer_in, :pointer], :pointer
  attach_function :cx_data_bin_to_json, [:buffer_in, :pointer], :pointer
  attach_function :cx_data_bin_to_yaml, [:buffer_in, :pointer], :pointer
  attach_function :cx_data_bin_to_toml, [:buffer_in, :pointer], :pointer
  attach_function :cx_data_bin_to_md,   [:buffer_in, :pointer], :pointer
  # CXPath path-tracking C ABI (Phase 4 / CB-5).
  attach_function :cx_select_all_paths, [:string, :string, :pointer], :pointer

  # Phase 5 / CB-1 — ast_bin → text format. Input is binary; declared
  # as :buffer_in so FFI passes the bytes through without strlen-trim.
  attach_function :cx_ast_bin_to_cx,   [:buffer_in, :pointer], :pointer
  attach_function :cx_ast_bin_to_xml,  [:buffer_in, :pointer], :pointer
  attach_function :cx_ast_bin_to_json, [:buffer_in, :pointer], :pointer
  attach_function :cx_ast_bin_to_yaml, [:buffer_in, :pointer], :pointer
  attach_function :cx_ast_bin_to_toml, [:buffer_in, :pointer], :pointer
  attach_function :cx_ast_bin_to_md,   [:buffer_in, :pointer], :pointer

  # Phase 5 / CB-2 — text → ast_bin (returns framed binary).
  attach_function :cx_xml_to_ast_bin,  [:string, :pointer], :pointer
  attach_function :cx_json_to_ast_bin, [:string, :pointer], :pointer
  attach_function :cx_yaml_to_ast_bin, [:string, :pointer], :pointer
  attach_function :cx_toml_to_ast_bin, [:string, :pointer], :pointer
  attach_function :cx_md_to_ast_bin,   [:string, :pointer], :pointer

  # Phase 5 / CB-4 — events handle API.
  attach_function :cx_events_open,  [:string, :pointer], :pointer
  attach_function :cx_events_next,  [:pointer, :pointer], :pointer
  attach_function :cx_events_close, [:pointer], :void

  # Phase 6 — canonical-form tooling (spec/abi.md §2.6).
  attach_function :cx_fmt,       [:string, :pointer], :pointer
  attach_function :cx_canonical, [:string, :pointer], :pointer
  attach_function :cx_hash,      [:string, :pointer], :pointer
  attach_function :cx_eq,        [:string, :string, :pointer], :pointer

  # Phase 7.47 — cx diff (ADR 0012). format = "unified" | "json" | "summary".
  attach_function :cx_diff,      [:string, :string, :string, :pointer], :pointer

  # Phase 7.49 — cx lint (ADR 0013). format = "text" | "json" | "summary".
  attach_function :cx_lint,      [:string, :string, :string, :pointer], :pointer

  # Phase 7.65 — ID/IDREF C ABI (ADR 0003). All three take 2 strings + err.
  attach_function :cx_id_lookup,   [:string, :string, :pointer], :pointer
  attach_function :cx_resolve_ref, [:string, :string, :pointer], :pointer
  attach_function :cx_node_id,     [:string, :string, :pointer], :pointer

  # Phase 7.68 — delimited (CSV/TSV/PSV/arbitrary) C ABI (ADR 0001 / spec/conversions.md §8).
  # cx_to_delimited / cx_from_delimited take a single-byte delimiter; the
  # cx_to_csv / cx_to_tsv / cx_to_psv aliases hard-code `,` / `\t` / `|`.
  # Text-text (8): the two delim-bearing entry points + 6 aliases.
  attach_function :cx_to_delimited,   [:string, :char, :pointer], :pointer
  attach_function :cx_from_delimited, [:string, :char, :pointer], :pointer
  attach_function :cx_to_csv,         [:string, :pointer], :pointer
  attach_function :cx_from_csv,       [:string, :pointer], :pointer
  attach_function :cx_to_tsv,         [:string, :pointer], :pointer
  attach_function :cx_from_tsv,       [:string, :pointer], :pointer
  attach_function :cx_to_psv,         [:string, :pointer], :pointer
  attach_function :cx_from_psv,       [:string, :pointer], :pointer
  # Binary one-shots (6): csv/tsv/psv ↔ data_bin. Loaders return UNFRAMED
  # CXDB v1 payload bytes; dumpers expect FRAMED [u32 LE size][CXDB ...] input.
  attach_function :cx_csv_to_data_bin, [:string, :pointer], :pointer
  attach_function :cx_tsv_to_data_bin, [:string, :pointer], :pointer
  attach_function :cx_psv_to_data_bin, [:string, :pointer], :pointer
  attach_function :cx_data_bin_to_csv, [:buffer_in, :pointer], :pointer
  attach_function :cx_data_bin_to_tsv, [:buffer_in, :pointer], :pointer
  attach_function :cx_data_bin_to_psv, [:buffer_in, :pointer], :pointer

  # XML input
  attach_function :cx_xml_to_cx,   [:string, :pointer], :pointer
  attach_function :cx_xml_to_xml,  [:string, :pointer], :pointer
  attach_function :cx_xml_to_ast,  [:string, :pointer], :pointer
  attach_function :cx_xml_to_json, [:string, :pointer], :pointer
  attach_function :cx_xml_to_yaml, [:string, :pointer], :pointer
  attach_function :cx_xml_to_toml, [:string, :pointer], :pointer
  attach_function :cx_xml_to_md,   [:string, :pointer], :pointer

  # JSON input
  attach_function :cx_json_to_cx,   [:string, :pointer], :pointer
  attach_function :cx_json_to_xml,  [:string, :pointer], :pointer
  attach_function :cx_json_to_ast,  [:string, :pointer], :pointer
  attach_function :cx_json_to_json, [:string, :pointer], :pointer
  attach_function :cx_json_to_yaml, [:string, :pointer], :pointer
  attach_function :cx_json_to_toml, [:string, :pointer], :pointer
  attach_function :cx_json_to_md,   [:string, :pointer], :pointer

  # YAML input
  attach_function :cx_yaml_to_cx,   [:string, :pointer], :pointer
  attach_function :cx_yaml_to_xml,  [:string, :pointer], :pointer
  attach_function :cx_yaml_to_ast,  [:string, :pointer], :pointer
  attach_function :cx_yaml_to_json, [:string, :pointer], :pointer
  attach_function :cx_yaml_to_yaml, [:string, :pointer], :pointer
  attach_function :cx_yaml_to_toml, [:string, :pointer], :pointer
  attach_function :cx_yaml_to_md,   [:string, :pointer], :pointer

  # TOML input
  attach_function :cx_toml_to_cx,   [:string, :pointer], :pointer
  attach_function :cx_toml_to_xml,  [:string, :pointer], :pointer
  attach_function :cx_toml_to_ast,  [:string, :pointer], :pointer
  attach_function :cx_toml_to_json, [:string, :pointer], :pointer
  attach_function :cx_toml_to_yaml, [:string, :pointer], :pointer
  attach_function :cx_toml_to_toml, [:string, :pointer], :pointer
  attach_function :cx_toml_to_md,   [:string, :pointer], :pointer

  # MD input
  attach_function :cx_md_to_cx,   [:string, :pointer], :pointer
  attach_function :cx_md_to_xml,  [:string, :pointer], :pointer
  attach_function :cx_md_to_ast,  [:string, :pointer], :pointer
  attach_function :cx_md_to_json, [:string, :pointer], :pointer
  attach_function :cx_md_to_yaml, [:string, :pointer], :pointer
  attach_function :cx_md_to_toml, [:string, :pointer], :pointer
  attach_function :cx_md_to_md,   [:string, :pointer], :pointer

  # ── helpers ─────────────────────────────────────────────────────────────────

  def self._call(fn_sym, input)
    err_ptr = FFI::MemoryPointer.new(:pointer)
    out = send(fn_sym, input, err_ptr)
    if out.null?
      ep = err_ptr.read_pointer
      msg = ep.null? ? 'unknown error' : ep.read_string.force_encoding('UTF-8')
      cx_free(ep) unless ep.null?
      raise RuntimeError, msg
    end
    s = out.read_string.force_encoding('UTF-8')
    cx_free(out)
    s
  end

  def self._call_bin(fn_sym, input)
    err_ptr = FFI::MemoryPointer.new(:pointer)
    out = send(fn_sym, input, err_ptr)
    if out.null?
      ep = err_ptr.read_pointer
      msg = ep.null? ? 'unknown error' : ep.read_string.force_encoding('UTF-8')
      cx_free(ep) unless ep.null?
      raise RuntimeError, msg
    end
    size = out.read_bytes(4).unpack1('V')
    payload = out.get_bytes(4, size)
    cx_free(out)
    payload
  end

  def self.ast_bin(cx_str)
    _call_bin(:cx_to_ast_bin, cx_str)
  end

  def self.events_bin(cx_str)
    _call_bin(:cx_to_events_bin, cx_str)
  end

  # Call cx_to_data_bin and return the CXDB v1 PAYLOAD (the [u32 LE size]
  # frame is stripped by _call_bin). Pass the result to DataBin.decode.
  # ── Phase 6 / canonical-form tooling (spec/abi.md §2.6) ───────────────────

  # Lossless canonical text CX. Idempotent.
  def self.fmt(src)       = _call(:cx_fmt,       src)

  # Strict canonical text CX.
  def self.canonical(src) = _call(:cx_canonical, src)

  # SHA-256 hex (64 lowercase hex chars) of the strict canonical bytes.
  def self.hash(src)      = _call(:cx_hash,      src)

  # True iff strict-canonical(a) == strict-canonical(b).
  def self.eq(a, b)
    err_ptr = FFI::MemoryPointer.new(:pointer)
    out = cx_eq(a, b, err_ptr)
    if out.null?
      ep = err_ptr.read_pointer
      msg = ep.null? ? 'unknown error' : ep.read_string.force_encoding('UTF-8')
      cx_free(ep) unless ep.null?
      raise RuntimeError, msg
    end
    s = out.read_string.force_encoding('UTF-8')
    s == '1'
  end

  # Semantic diff between two CX inputs, walking the strict-canonical
  # forms. format is 'unified', 'json', or 'summary'. Empty result
  # means data-equivalent. Per spec/decisions/0012-cx-diff.md.
  def self.diff(a, b, format = 'unified')
    err_ptr = FFI::MemoryPointer.new(:pointer)
    out = cx_diff(a, b, format, err_ptr)
    if out.null?
      ep = err_ptr.read_pointer
      msg = ep.null? ? 'unknown error' : ep.read_string.force_encoding('UTF-8')
      cx_free(ep) unless ep.null?
      raise RuntimeError, msg
    end
    out.read_string.force_encoding('UTF-8')
  end

  # Style + correctness warnings. format is 'text', 'json', or
  # 'summary'. disabled is a comma-separated list of check IDs to
  # suppress ('' runs all). Empty result means no findings.
  # Per spec/decisions/0013-cx-lint.md.
  def self.lint(input, format = 'text', disabled = '')
    err_ptr = FFI::MemoryPointer.new(:pointer)
    out = cx_lint(input, format, disabled, err_ptr)
    if out.null?
      ep = err_ptr.read_pointer
      msg = ep.null? ? 'unknown error' : ep.read_string.force_encoding('UTF-8')
      cx_free(ep) unless ep.null?
      raise RuntimeError, msg
    end
    out.read_string.force_encoding('UTF-8')
  end

  # ── Phase 7.65 / ID/IDREF C ABI (ADR 0003) ────────────────────────────────
  #
  # All three return the empty string for "not found" (matching the
  # `lint`/`diff` empty-string convention) and raise RuntimeError on
  # parse / cxpath error.

  # Find the element declaring `#id` in `input` and return its
  # AST-JSON encoding. Empty string means no such ID.
  def self.id_lookup(input, id)
    err_ptr = FFI::MemoryPointer.new(:pointer)
    out = cx_id_lookup(input, id, err_ptr)
    if out.null?
      ep = err_ptr.read_pointer
      msg = ep.null? ? 'unknown error' : ep.read_string.force_encoding('UTF-8')
      cx_free(ep) unless ep.null?
      raise RuntimeError, msg
    end
    s = out.read_string.force_encoding('UTF-8')
    cx_free(out)
    s
  end

  # Resolve a reference to its declaring element's AST-JSON encoding.
  # Observationally equivalent to id_lookup; refs and IDs share a
  # namespace.
  def self.resolve_ref(input, ref)
    err_ptr = FFI::MemoryPointer.new(:pointer)
    out = cx_resolve_ref(input, ref, err_ptr)
    if out.null?
      ep = err_ptr.read_pointer
      msg = ep.null? ? 'unknown error' : ep.read_string.force_encoding('UTF-8')
      cx_free(ep) unless ep.null?
      raise RuntimeError, msg
    end
    s = out.read_string.force_encoding('UTF-8')
    cx_free(out)
    s
  end

  # Run CXPath `cxpath` on `input` and return the syntactic ID of the
  # matched element. Empty string when no match or matched element has
  # no ID.
  def self.node_id(input, cxpath)
    err_ptr = FFI::MemoryPointer.new(:pointer)
    out = cx_node_id(input, cxpath, err_ptr)
    if out.null?
      ep = err_ptr.read_pointer
      msg = ep.null? ? 'unknown error' : ep.read_string.force_encoding('UTF-8')
      cx_free(ep) unless ep.null?
      raise RuntimeError, msg
    end
    s = out.read_string.force_encoding('UTF-8')
    cx_free(out)
    s
  end

  def self.to_data_bin(cx_str)
    _call_bin(:cx_to_data_bin, cx_str)
  end

  # Call cx_select_all_paths and decode the framed [u32 size][u32 n_paths][...]
  # blob into an array of structural paths. Each path is an array of
  # 0-based indices: first into Document.elements, subsequent into
  # Element.items. Match order is preorder (same as cx_select_all).
  # See spec/abi.md §2.7. Raises ArgumentError on parse error.
  def self.select_all_paths(cx_text, expr)
    err_ptr = FFI::MemoryPointer.new(:pointer)
    out = cx_select_all_paths(cx_text, expr, err_ptr)
    if out.null?
      ep = err_ptr.read_pointer
      msg = ep.null? ? 'unknown error' : ep.read_string.force_encoding('UTF-8')
      cx_free(ep) unless ep.null?
      # Bad CXPath expression or bad CX input — both are caller bugs.
      raise ArgumentError, msg
    end
    size = out.read_bytes(4).unpack1('V')
    payload = out.get_bytes(4, size)
    cx_free(out)
    n_paths = payload.byteslice(0, 4).unpack1('V')
    off = 4
    paths = Array.new(n_paths)
    n_paths.times do |i|
      depth = payload.byteslice(off, 4).unpack1('V')
      off += 4
      path = Array.new(depth)
      depth.times do |k|
        path[k] = payload.byteslice(off, 4).unpack1('V')
        off += 4
      end
      paths[i] = path
    end
    paths
  end

  # Shared helper: framed binary input, text output. Used by from_data_bin
  # and the data_bin_to_<fmt> dumpers (Phase 7.28).
  def self._call_bin_to_text(fn_sym, framed)
    raise "#{fn_sym}: empty input" if framed.nil? || framed.bytesize == 0
    err_ptr = FFI::MemoryPointer.new(:pointer)
    out = send(fn_sym, framed, err_ptr)
    if out.null?
      ep = err_ptr.read_pointer
      msg = ep.null? ? 'unknown error' : ep.read_string.force_encoding('UTF-8')
      cx_free(ep) unless ep.null?
      raise RuntimeError, msg
    end
    s = out.read_string.force_encoding('UTF-8')
    cx_free(out)
    s
  end

  # Call cx_from_data_bin with FRAMED CXDB v1 bytes (as returned by
  # DataBin.encode) and return the canonical CX text.
  def self.from_data_bin(framed)
    _call_bin_to_text(:cx_from_data_bin, framed)
  end

  # ── data_bin one-shot loaders/dumpers (Phase 7.28; spec/abi.md §2.4–§2.5) ──

  # Encode XML text to CXDB v1 PAYLOAD bytes (frame stripped).
  def self.xml_to_data_bin(input)  = _call_bin(:cx_xml_to_data_bin,  input)
  # Encode JSON text to CXDB v1 PAYLOAD bytes (frame stripped).
  def self.json_to_data_bin(input) = _call_bin(:cx_json_to_data_bin, input)
  # Encode YAML text to CXDB v1 PAYLOAD bytes (frame stripped).
  def self.yaml_to_data_bin(input) = _call_bin(:cx_yaml_to_data_bin, input)
  # Encode TOML text to CXDB v1 PAYLOAD bytes (frame stripped).
  def self.toml_to_data_bin(input) = _call_bin(:cx_toml_to_data_bin, input)
  # Encode Markdown text to CXDB v1 PAYLOAD bytes (frame stripped).
  def self.md_to_data_bin(input)   = _call_bin(:cx_md_to_data_bin,   input)

  # Decode FRAMED CXDB v1 bytes to XML text.
  def self.data_bin_to_xml(framed)  = _call_bin_to_text(:cx_data_bin_to_xml,  framed)
  # Decode FRAMED CXDB v1 bytes to JSON text.
  def self.data_bin_to_json(framed) = _call_bin_to_text(:cx_data_bin_to_json, framed)
  # Decode FRAMED CXDB v1 bytes to YAML text.
  def self.data_bin_to_yaml(framed) = _call_bin_to_text(:cx_data_bin_to_yaml, framed)
  # Decode FRAMED CXDB v1 bytes to TOML text.
  def self.data_bin_to_toml(framed) = _call_bin_to_text(:cx_data_bin_to_toml, framed)
  # Decode FRAMED CXDB v1 bytes to Markdown text.
  def self.data_bin_to_md(framed)   = _call_bin_to_text(:cx_data_bin_to_md,   framed)

  # ── delimited (CSV/TSV/PSV/arbitrary) wrappers (Phase 7.68; ADR 0001) ────────

  # Shared helper for delim-bearing text-text entry points (cx_to_delimited /
  # cx_from_delimited). delim must be a 1-character String; passed to FFI as
  # a single byte via delim.ord.
  def self._call_delim(fn_sym, input, delim)
    raise ArgumentError, 'delim must be a single character' unless delim.is_a?(String) && delim.bytesize == 1
    err_ptr = FFI::MemoryPointer.new(:pointer)
    out = send(fn_sym, input, delim.ord, err_ptr)
    if out.null?
      ep = err_ptr.read_pointer
      msg = ep.null? ? 'unknown error' : ep.read_string.force_encoding('UTF-8')
      cx_free(ep) unless ep.null?
      raise RuntimeError, msg
    end
    s = out.read_string.force_encoding('UTF-8')
    cx_free(out)
    s
  end

  # Emit CX text as delimited text using an arbitrary single-byte delimiter.
  def self.to_delimited(input, delim)   = _call_delim(:cx_to_delimited,   input, delim)
  # Parse delimited text using an arbitrary single-byte delimiter into CX text.
  def self.from_delimited(input, delim) = _call_delim(:cx_from_delimited, input, delim)

  # Text-text aliases (hard-coded delimiters: , / \t / |).
  def self.to_csv(input)   = _call(:cx_to_csv,   input)
  def self.from_csv(input) = _call(:cx_from_csv, input)
  def self.to_tsv(input)   = _call(:cx_to_tsv,   input)
  def self.from_tsv(input) = _call(:cx_from_tsv, input)
  def self.to_psv(input)   = _call(:cx_to_psv,   input)
  def self.from_psv(input) = _call(:cx_from_psv, input)

  # Binary one-shot loaders: text -> UNFRAMED CXDB v1 PAYLOAD bytes.
  def self.csv_to_data_bin(input) = _call_bin(:cx_csv_to_data_bin, input)
  def self.tsv_to_data_bin(input) = _call_bin(:cx_tsv_to_data_bin, input)
  def self.psv_to_data_bin(input) = _call_bin(:cx_psv_to_data_bin, input)

  # Binary one-shot dumpers: FRAMED CXDB v1 bytes -> delimited text.
  def self.data_bin_to_csv(framed) = _call_bin_to_text(:cx_data_bin_to_csv, framed)
  def self.data_bin_to_tsv(framed) = _call_bin_to_text(:cx_data_bin_to_tsv, framed)
  def self.data_bin_to_psv(framed) = _call_bin_to_text(:cx_data_bin_to_psv, framed)

  # ── public API ───────────────────────────────────────────────────────────────

  def self.version
    ptr = cx_version()
    s = ptr.read_string.force_encoding('UTF-8')
    cx_free(ptr)
    s
  end

  # CX input
  def self.to_cx        (src) = _call(:cx_to_cx,         src)
  def self.to_cx_compact(src) = _call(:cx_to_cx_compact, src)
  def self.ast_to_cx    (src) = _call(:cx_ast_to_cx,     src)
  def self.to_xml(src)  = _call(:cx_to_xml,  src)
  def self.to_ast(src)  = _call(:cx_to_ast,  src)
  def self.to_json(src) = _call(:cx_to_json, src)
  def self.to_yaml(src) = _call(:cx_to_yaml, src)
  def self.to_toml(src) = _call(:cx_to_toml, src)
  def self.to_md(src)   = _call(:cx_to_md,   src)

  # CXL evaluator. output_target may be '' (honour the program's
  # `[?cx output-target=…]` directive, default 'text'), or one of
  # 'text' / 'cx' / 'html' at CXL 1.0 (v0.6.0).
  def self.eval_cxl(input_cx, program_cxl, output_target = '')
    err = FFI::MemoryPointer.new(:pointer)
    out = cx_eval_cxl(input_cx, program_cxl, output_target, err)
    if out.null?
      ep = err.read_pointer
      msg = ep.null? ? 'unknown error' : ep.read_string
      cx_free(ep) unless ep.null?
      raise msg
    end
    s = out.read_string
    cx_free(out)
    s
  end

  # XML input
  def self.xml_to_cx(src)   = _call(:cx_xml_to_cx,   src)
  def self.xml_to_xml(src)  = _call(:cx_xml_to_xml,  src)
  def self.xml_to_ast(src)  = _call(:cx_xml_to_ast,  src)
  def self.xml_to_json(src) = _call(:cx_xml_to_json, src)
  def self.xml_to_yaml(src) = _call(:cx_xml_to_yaml, src)
  def self.xml_to_toml(src) = _call(:cx_xml_to_toml, src)
  def self.xml_to_md(src)   = _call(:cx_xml_to_md,   src)

  # JSON input
  def self.json_to_cx(src)   = _call(:cx_json_to_cx,   src)
  def self.json_to_xml(src)  = _call(:cx_json_to_xml,  src)
  def self.json_to_ast(src)  = _call(:cx_json_to_ast,  src)
  def self.json_to_json(src) = _call(:cx_json_to_json, src)
  def self.json_to_yaml(src) = _call(:cx_json_to_yaml, src)
  def self.json_to_toml(src) = _call(:cx_json_to_toml, src)
  def self.json_to_md(src)   = _call(:cx_json_to_md,   src)

  # YAML input
  def self.yaml_to_cx(src)   = _call(:cx_yaml_to_cx,   src)
  def self.yaml_to_xml(src)  = _call(:cx_yaml_to_xml,  src)
  def self.yaml_to_ast(src)  = _call(:cx_yaml_to_ast,  src)
  def self.yaml_to_json(src) = _call(:cx_yaml_to_json, src)
  def self.yaml_to_yaml(src) = _call(:cx_yaml_to_yaml, src)
  def self.yaml_to_toml(src) = _call(:cx_yaml_to_toml, src)
  def self.yaml_to_md(src)   = _call(:cx_yaml_to_md,   src)

  # TOML input
  def self.toml_to_cx(src)   = _call(:cx_toml_to_cx,   src)
  def self.toml_to_xml(src)  = _call(:cx_toml_to_xml,  src)
  def self.toml_to_ast(src)  = _call(:cx_toml_to_ast,  src)
  def self.toml_to_json(src) = _call(:cx_toml_to_json, src)
  def self.toml_to_yaml(src) = _call(:cx_toml_to_yaml, src)
  def self.toml_to_toml(src) = _call(:cx_toml_to_toml, src)
  def self.toml_to_md(src)   = _call(:cx_toml_to_md,   src)

  # MD input
  def self.md_to_cx(src)   = _call(:cx_md_to_cx,   src)
  def self.md_to_xml(src)  = _call(:cx_md_to_xml,  src)
  def self.md_to_ast(src)  = _call(:cx_md_to_ast,  src)
  def self.md_to_json(src) = _call(:cx_md_to_json, src)
  def self.md_to_yaml(src) = _call(:cx_md_to_yaml, src)
  def self.md_to_toml(src) = _call(:cx_md_to_toml, src)
  def self.md_to_md(src)   = _call(:cx_md_to_md,   src)


  # ── Transform helpers ───────────────────────────────────────────────────────

  def self._elem_detached(e)
    Element.new(e.name,
      attrs:     e.attrs.map { |a| Attr.new(a.name, a.value, a.data_type) },
      items:     e.items.dup,
      anchor:    e.anchor,
      merge:     e.merge,
      data_type: e.data_type)
  end

  def self._doc_replace_at(d, idx, el)
    new_elems = d.elements.dup
    new_elems[idx] = el
    Document.new(elements: new_elems, prolog: d.prolog.dup, doctype: d.doctype)
  end

  def self._elem_replace_item_at(e, idx, child)
    new_items = e.items.dup
    new_items[idx] = child
    Element.new(e.name,
      attrs:     e.attrs,
      items:     new_items,
      anchor:    e.anchor,
      merge:     e.merge,
      data_type: e.data_type)
  end

  def self._path_copy_element(e, parts, &f)
    e.items.each_with_index do |item, i|
      next unless item.is_a?(Element) && item.name == parts[0]
      if parts.size == 1
        return _elem_replace_item_at(e, i, f.call(_elem_detached(item)))
      end
      updated = _path_copy_element(item, parts[1..], &f)
      return updated ? _elem_replace_item_at(e, i, updated) : nil
    end
    nil
  end

  # ── Path-based navigation (CB-5 / Phase 4) ────────────────────────────────

  # Walk `path` (indices into Document.elements then Element.items) and
  # return the live element reference at that position. Returns nil if
  # any step is out-of-bounds or hits a non-Element item.
  def self._navigate_doc_path(d, path)
    return nil if path.empty? || path[0] < 0 || path[0] >= d.elements.size
    node = d.elements[path[0]]
    path[1..].each do |k|
      return nil unless node.is_a?(Element)
      return nil if k < 0 || k >= node.items.size
      node = node.items[k]
    end
    node.is_a?(Element) ? node : nil
  end

  # Return a new Document with the element at `path` replaced by
  # `new_elem`. Only the spine along `path` is rebuilt; the original
  # document is unchanged.
  def self._replace_at_doc_path(d, path, new_elem)
    return d if path.empty?
    new_elements = d.elements.dup
    if path.size == 1
      new_elements[path[0]] = new_elem if path[0] >= 0 && path[0] < new_elements.size
    else
      top = new_elements[path[0]]
      if top.is_a?(Element)
        new_elements[path[0]] = _replace_in_element(top, path[1..], new_elem)
      end
    end
    Document.new(elements: new_elements, prolog: d.prolog.dup, doctype: d.doctype)
  end

  def self._replace_in_element(el, path, new_elem)
    return new_elem if path.empty?
    new_items = el.items.dup
    if path.size == 1
      new_items[path[0]] = new_elem if path[0] >= 0 && path[0] < new_items.size
    else
      child = new_items[path[0]]
      if child.is_a?(Element)
        new_items[path[0]] = _replace_in_element(child, path[1..], new_elem)
      end
    end
    Element.new(el.name,
      attrs:     el.attrs,
      items:     new_items,
      anchor:    el.anchor,
      merge:     el.merge,
      data_type: el.data_type)
  end
  private_class_method :_replace_in_element

  # ── Binary wire protocol ─────────────────────────────────────────────────────

  class BufReader
    def initialize(data)
      @data = data.b
      @pos  = 0
    end

    def u8
      v = @data.getbyte(@pos)
      @pos += 1
      v
    end

    def u16
      v = @data[@pos, 2].unpack1('v')
      @pos += 2
      v
    end

    def u32
      v = @data[@pos, 4].unpack1('V')
      @pos += 4
      v
    end

    def str_
      n = u32
      s = @data[@pos, n].force_encoding('UTF-8')
      @pos += n
      s
    end

    def optstr
      u8 == 1 ? str_ : nil
    end
  end

  def self._bin_coerce(type_str, value_str)
    case type_str
    when 'int'   then value_str.to_i
    when 'float' then value_str.to_f
    when 'bool'  then value_str.start_with?('t')
    when 'null'  then nil
    else              value_str
    end
  end

  def self._bin_read_attr(b, version)
    name      = b.str_
    value_str = b.str_
    t         = b.str_
    dt        = (t == 'string') ? nil : t
    a = Attr.new(name, _bin_coerce(t, value_str), dt)
    a.is_ref = version >= 2 && b.u8 == 1
    if version >= 5
      # v3.5 (ADR 0016): BracketBody attribute body tail.
      flag = b.u8
      if flag == 1
        count = b.u16
        a.body = Array.new(count) { _bin_read_node(b, version) }
      elsif flag != 0
        raise "ast_bin: invalid attr body_flag #{flag}"
      end
    end
    a
  end

  def self._bin_read_node(b, version)
    tid = b.u8
    case tid
    when 0x01
      name   = b.str_
      anchor = b.optstr
      dt     = b.optstr
      merge  = b.optstr
      id_decl = version >= 2 ? b.optstr : nil
      body_ref = version >= 3 ? b.optstr : nil
      attrs  = Array.new(b.u16) { _bin_read_attr(b, version) }
      items  = Array.new(b.u16) { _bin_read_node(b, version) }
      Element.new(name, attrs: attrs, items: items, anchor: anchor, merge: merge, data_type: dt, id: id_decl, body_ref: body_ref)
    when 0x02
      TextNode.new(b.str_)
    when 0x03
      t = b.str_; ScalarNode.new(t, _bin_coerce(t, b.str_))
    when 0x04
      Comment.new(b.str_)
    when 0x05
      RawText.new(b.str_)
    when 0x06
      EntityRef.new(b.str_)
    when 0x07
      Alias.new(b.str_)
    when 0x08
      PI.new(b.str_, b.optstr)
    when 0x09
      XMLDecl.new(version: b.str_, encoding: b.optstr, standalone: b.optstr)
    when 0x0A
      attrs = Array.new(b.u16) { _bin_read_attr(b, version) }
      if version >= 4
        # v0.6.0 — directive `&anchor` + nested children.
        anchor = b.optstr
        items  = Array.new(b.u16) { _bin_read_node(b, version) }
        CXDirective.new(attrs: attrs, anchor: anchor, items: items)
      else
        CXDirective.new(attrs: attrs)
      end
    when 0x0C
      BlockContent.new(items: Array.new(b.u16) { _bin_read_node(b, version) })
    when 0x0D
      # v3.5 (ADR 0016) [58] — `[?=EXPR]`.
      Interpolation.new(b.str_)
    when 0x0E
      # v3.5 (ADR 0016) [59] — `[?Name attrs body]`.
      ed_name  = b.str_
      ed_attrs = Array.new(b.u16) { _bin_read_attr(b, version) }
      ed_items = Array.new(b.u16) { _bin_read_node(b, version) }
      EvalDirective.new(ed_name, attrs: ed_attrs, items: ed_items)
    else
      TextNode.new('')
    end
  end

  def self.decode_ast(data)
    b = BufReader.new(data)
    version  = b.u8
    prolog   = Array.new(b.u16) { _bin_read_node(b, version) }
    elements = Array.new(b.u16) { _bin_read_node(b, version) }
    Document.new(prolog: prolog, elements: elements)
  end

  # ── StreamEvent ───────────────────────────────────────────────────────────────

  class StreamEvent
    attr_accessor :type, :name, :attrs, :data_type, :anchor, :merge,
                  :value, :target, :data

    def initialize(type:)
      @type      = type
      @name      = nil
      @attrs     = []
      @data_type = nil
      @anchor    = nil
      @merge     = nil
      @value     = nil
      @target    = nil
      @data      = nil
    end

    def start_element?(name = nil)
      @type == 'StartElement' && (name.nil? || @name == name)
    end

    def end_element?(name = nil)
      @type == 'EndElement' && (name.nil? || @name == name)
    end
  end

  EVT_TYPES_ = {
    0x01 => 'StartDoc', 0x02 => 'EndDoc', 0x03 => 'StartElement',
    0x04 => 'EndElement', 0x05 => 'Text', 0x06 => 'Scalar',
    0x07 => 'Comment', 0x08 => 'PI', 0x09 => 'EntityRef',
    0x0A => 'RawText', 0x0B => 'Alias',
  }.freeze

  def self._read_one_event(b)
    tid = b.u8
    t   = EVT_TYPES_.fetch(tid, 'Unknown')
    e   = StreamEvent.new(type: t)
    case tid
    when 0x03
      e.name      = b.str_
      e.anchor    = b.optstr
      e.data_type = b.optstr
      e.merge     = b.optstr
      e.attrs     = Array.new(b.u16) do
        nm      = b.str_
        val_str = b.str_
        typ     = b.str_
        is_ref  = b.u8 == 1   # v3.4 (ADR 0003): events buffer follows ast_bin v2.
        # v3.5 (ADR 0016): BracketBody attr body tail (events buffer
        # follows ast_bin v5 attr layout). Body items are skipped here.
        body_flag = b.u8
        if body_flag == 1
          count = b.u16
          count.times { _bin_read_node(b, 5) }
        elsif body_flag != 0
          raise "ast_bin: invalid attr body_flag #{body_flag}"
        end
        a = Attr.new(nm, _bin_coerce(typ, val_str), typ == 'string' ? nil : typ)
        a.is_ref = is_ref
        a
      end
    when 0x04
      e.name  = b.str_
    when 0x05, 0x07, 0x0A
      e.value = b.str_
    when 0x06
      dt = b.str_; e.data_type = dt; e.value = _bin_coerce(dt, b.str_)
    when 0x08
      e.target = b.str_; e.data = b.optstr
    when 0x09, 0x0B
      e.value = b.str_
    end
    e
  end

  def self.decode_events(data)
    b = BufReader.new(data)
    count = b.u32
    Array.new(count) { _read_one_event(b) }
  end

  # Decode a single event from a payload (no [u32 count] prefix). Used
  # by the handle-based EventStream (Phase 5 / CB-4).
  def self.decode_one_event(payload)
    _read_one_event(BufReader.new(payload))
  end

  # ── Binary AST encoder (Phase 5 / CB-1) ──────────────────────────────────────
  # Inverse of decode_ast. Produces a FRAMED [u32 LE size][payload] String
  # (binary-encoded) matching V's emit_ast_bin output. Used by
  # Document#to_ast_bin and Element#to_ast_bin.

  class BufWriter
    attr_reader :buf
    def initialize
      @buf = String.new(capacity: 256, encoding: Encoding::BINARY)
    end
    def u8(v)  ; @buf << [v].pack('C')  ; end
    def u16(v) ; @buf << [v].pack('v')  ; end
    def u32(v) ; @buf << [v].pack('V')  ; end
    def str_(s)
      enc = s.to_s.encode(Encoding::UTF_8).b
      u32(enc.bytesize)
      @buf << enc
    end
    def optstr(s) ; if s.nil? then u8(0) else u8(1); str_(s) end ; end
  end

  # ── ID/IDREF helpers (ADR 0003) ───────────────────────────────────────────

  def self._find_element_by_id(nodes, id)
    nodes.each do |n|
      next unless n.is_a?(Element)
      return n if n.id == id
      found = _find_element_by_id(n.items, id)
      return found if found
    end
    nil
  end

  def self._collect_elements_by_id(nodes, out)
    nodes.each do |n|
      next unless n.is_a?(Element)
      out[n.id] = n if n.id
      _collect_elements_by_id(n.items, out)
    end
  end

  def self._scalar_value_str_bin(dt, v)
    return 'null' if v.nil? || dt == 'null'
    return (v ? 'true' : 'false') if v.is_a?(TrueClass) || v.is_a?(FalseClass)
    return v if v.is_a?(String)
    v.to_s
  end

  def self._enc_attr(w, a)
    dt = (a.data_type.nil? || a.data_type.empty?) ? 'string' : a.data_type
    w.str_(a.name)
    w.str_(_scalar_value_str_bin(dt, a.value))
    w.str_(dt)
    # v3.4 (ADR 0003): is_ref flag — format version 2.
    w.u8(a.is_ref ? 1 : 0)
    # v3.5 (ADR 0016): BracketBody attribute body tail — format version 5.
    body = a.respond_to?(:body) ? a.body : nil
    if body.nil?
      w.u8(0)
    else
      w.u8(1)
      w.u16(body.size)
      body.each { |n| _enc_node(w, n) }
    end
  end

  def self._enc_node(w, n)
    case n
    when Element
      w.u8(0x01)
      w.str_(n.name)
      w.optstr(n.anchor)
      w.optstr(n.data_type)
      w.optstr(n.merge)
      # v3.4 (ADR 0003): syntactic ID declaration — format version 2.
      w.optstr(n.id)
      # Phase 7.70: body-position reference — format version 3.
      w.optstr(n.body_ref)
      w.u16(n.attrs.size)
      n.attrs.each { |a| _enc_attr(w, a) }
      w.u16(n.items.size)
      n.items.each { |c| _enc_node(w, c) }
    when TextNode    then w.u8(0x02); w.str_(n.value)
    when ScalarNode  then
      w.u8(0x03); w.str_(n.data_type); w.str_(_scalar_value_str_bin(n.data_type, n.value))
    when Comment     then w.u8(0x04); w.str_(n.value)
    when RawText     then w.u8(0x05); w.str_(n.value)
    when EntityRef   then w.u8(0x06); w.str_(n.name)
    when Alias       then w.u8(0x07); w.str_(n.name)
    when PI          then w.u8(0x08); w.str_(n.target); w.optstr(n.data)
    when XMLDecl     then w.u8(0x09); w.str_(n.version); w.optstr(n.encoding); w.optstr(n.standalone)
    when CXDirective then
      w.u8(0x0A); w.u16(n.attrs.size)
      n.attrs.each { |a| _enc_attr(w, a) }
      # v0.6.0 (format version 4) — directive `&anchor` + nested children.
      w.optstr(n.anchor)
      items = n.items || []
      w.u16(items.size)
      items.each { |c| _enc_node(w, c) }
    when BlockContent then
      w.u8(0x0C); w.u16(n.items.size)
      n.items.each { |it| _enc_node(w, it) }
    when Interpolation then
      # v3.5 (ADR 0016) [58] — `[?=EXPR]`.
      w.u8(0x0D); w.str_(n.expr)
    when EvalDirective then
      # v3.5 (ADR 0016) [59] — `[?Name attrs body]`.
      w.u8(0x0E); w.str_(n.name)
      w.u16(n.attrs.size)
      n.attrs.each { |a| _enc_attr(w, a) }
      w.u16(n.items.size)
      n.items.each { |it| _enc_node(w, it) }
    else
      # DTD / unknown — emit 0xFF skip marker.
      w.u8(0xFF)
    end
  end

  # Encode a Document to a FRAMED [u32 LE size][payload] AST bin String
  # (binary-encoded) suitable for direct hand-off to cx_ast_bin_to_<format>.
  def self.encode_ast(doc)
    w = BufWriter.new
    w.u8(0x05) # version — v0.6.0 (ADR 0016 grammar v3.5):
               #   * CXDirective &anchor + items (format v4)
               #   * Interpolation (0x0D) + EvalDirective (0x0E) tags
               #   * BracketBody attribute body tail (format v5)
    w.u16(doc.prolog.size)
    doc.prolog.each { |n| _enc_node(w, n) }
    w.u16(doc.elements.size)
    doc.elements.each { |n| _enc_node(w, n) }
    payload = w.buf
    framed = String.new(capacity: 4 + payload.bytesize, encoding: Encoding::BINARY)
    framed << [payload.bytesize].pack('V')
    framed << payload
    framed
  end

  # ── Phase 5 / CB-1 helpers — ast_bin → text ─────────────────────────────────

  def self._ast_bin_to_text(fn_sym, framed)
    raise 'ast_bin_to_*: empty input' if framed.nil? || framed.bytesize == 0
    err_ptr = FFI::MemoryPointer.new(:pointer)
    out = send(fn_sym, framed, err_ptr)
    if out.null?
      ep = err_ptr.read_pointer
      msg = ep.null? ? 'unknown error' : ep.read_string.force_encoding('UTF-8')
      cx_free(ep) unless ep.null?
      raise RuntimeError, msg
    end
    s = out.read_string.force_encoding('UTF-8')
    cx_free(out)
    s
  end

  def self.ast_bin_to_cx  (framed) = _ast_bin_to_text(:cx_ast_bin_to_cx,   framed)
  def self.ast_bin_to_xml (framed) = _ast_bin_to_text(:cx_ast_bin_to_xml,  framed)
  def self.ast_bin_to_json(framed) = _ast_bin_to_text(:cx_ast_bin_to_json, framed)
  def self.ast_bin_to_yaml(framed) = _ast_bin_to_text(:cx_ast_bin_to_yaml, framed)
  def self.ast_bin_to_toml(framed) = _ast_bin_to_text(:cx_ast_bin_to_toml, framed)
  def self.ast_bin_to_md  (framed) = _ast_bin_to_text(:cx_ast_bin_to_md,   framed)

  # ── Phase 5 / CB-2 helpers — text → ast_bin (frame stripped) ────────────────

  def self.xml_to_ast_bin (src) = _call_bin(:cx_xml_to_ast_bin,  src)
  def self.json_to_ast_bin(src) = _call_bin(:cx_json_to_ast_bin, src)
  def self.yaml_to_ast_bin(src) = _call_bin(:cx_yaml_to_ast_bin, src)
  def self.toml_to_ast_bin(src) = _call_bin(:cx_toml_to_ast_bin, src)
  def self.md_to_ast_bin  (src) = _call_bin(:cx_md_to_ast_bin,   src)

  # ── Phase 5 / CB-4 — events handle API (used by EventStream) ────────────────

  # Pull-based iterator over CX streaming events backed by the
  # cx_events_open / cx_events_next / cx_events_close handle API.
  # Replaces the prior eager-buffered cx_to_events_bin path.
  #
  # Usage:
  #   CXLib::EventStream.new(cx_str).each do |ev|
  #     puts ev.type
  #   end
  class EventStream
    include Enumerable

    def self.open(cx_str) = new(cx_str)

    def initialize(cx_str)
      err_ptr = FFI::MemoryPointer.new(:pointer)
      h = CXLib.cx_events_open(cx_str, err_ptr)
      if h.null?
        ep = err_ptr.read_pointer
        msg = ep.null? ? 'cx_events_open: unknown error' : ep.read_string.force_encoding('UTF-8')
        CXLib.cx_free(ep) unless ep.null?
        raise RuntimeError, msg
      end
      @handle = h
      @closed = false
    end

    # Pull the next event, or nil on EOF.
    def next_event
      return nil if @closed || @handle.nil? || @handle.null?
      err_ptr = FFI::MemoryPointer.new(:pointer)
      raw = CXLib.cx_events_next(@handle, err_ptr)
      if raw.null?
        # NULL with err = error; NULL with no err = EOF.
        ep = err_ptr.read_pointer
        if !ep.null?
          msg = ep.read_string.force_encoding('UTF-8')
          CXLib.cx_free(ep)
          close
          raise RuntimeError, msg
        end
        close
        return nil
      end
      size = raw.read_bytes(4).unpack1('V')
      payload = raw.get_bytes(4, size)
      CXLib.cx_free(raw)
      CXLib.decode_one_event(payload)
    end

    # Release the underlying handle. Idempotent.
    def close
      return if @closed
      @closed = true
      CXLib.cx_events_close(@handle) unless @handle.nil? || @handle.null?
      @handle = nil
    end

    def each
      return enum_for(:each) unless block_given?
      while (ev = next_event)
        yield ev
      end
    end
  end

  # ── Document API ─────────────────────────────────────────────────────────────

  require 'json'

  # ── Node types ─────────────────────────────────────────────────────────────

  class Attr
    attr_accessor :name, :value, :data_type, :local, :ns_uri, :is_ref, :body
    def initialize(name, value, data_type = nil)
      @name, @value, @data_type = name, value, data_type
      # v3.4 (ADR 0002): expanded-name fields populated by
      # CxLib.resolve_namespaces. local is the part after the first ':'
      # in name (or the whole name); ns_uri is the resolved URI, nil
      # when no binding is in scope. Per XML Namespaces 1.0 §6.2 the
      # default ns does not apply to unprefixed attributes.
      @local  = ''
      @ns_uri = nil
      # v3.4 (ADR 0003): true when the source attribute value was a
      # bare `@id` reference token. Quoted strings starting with '@'
      # have is_ref = false. Round-trip preserves the bare form.
      @is_ref = false
      # v3.5 (ADR 0016): BracketBody attribute value — `name=[BodyItem*]`.
      # When non-nil, `value` is unused and the attribute's content is
      # the parsed body sequence. Used by CXL evaluation directives like
      # `[?if cond :then=[BODY] :else=[BODY]]`. Inert outside CXL evaluation;
      # round-trips as opaque structure (ADR 0016 R5). ast_bin v5+.
      @body = nil
    end

    # Local part of the attribute name (post-colon, or whole name).
    def local_name = @local
    # Resolved namespace URI; nil for unprefixed or unbound prefixes.
    def namespace_uri = @ns_uri
  end

  class TextNode
    attr_accessor :value
    def initialize(v); @value = v; end
  end

  class ScalarNode
    attr_accessor :data_type, :value
    def initialize(dt, v); @data_type, @value = dt, v; end
  end

  class Comment
    attr_accessor :value
    def initialize(v); @value = v; end
  end

  class RawText
    attr_accessor :value
    def initialize(v); @value = v; end
  end

  class EntityRef
    attr_accessor :name
    def initialize(n); @name = n; end
  end

  class Alias
    attr_accessor :name
    def initialize(n); @name = n; end
  end

  class PI
    attr_accessor :target, :data
    def initialize(target, data = nil); @target, @data = target, data; end
  end

  class XMLDecl
    attr_accessor :version, :encoding, :standalone
    def initialize(version: '1.0', encoding: nil, standalone: nil)
      @version, @encoding, @standalone = version, encoding, standalone
    end
  end

  class CXDirective
    attr_accessor :attrs, :anchor, :items
    # v0.6.0 — directives may carry an `&anchor` and/or nested elements.
    # Used by the standalone-fragment form `[?cx frag &name [body :TYPE :flags]]`
    # (spec/schema.md §8). ast_bin format version 4 carries them.
    def initialize(attrs: [], anchor: nil, items: [])
      @attrs  = attrs
      @anchor = anchor
      @items  = items
    end
  end

  # v3.5 (ADR 0016) [58] — `[?=EXPR]`. EXPR is opaque text at v0.6.0;
  # the CXL evaluator at v0.7.0+ parses it as CXPath at evaluation time.
  # ast_bin tag 0x0D (format v5+).
  class Interpolation
    attr_accessor :expr
    def initialize(expr); @expr = expr; end
  end

  # v3.5 (ADR 0016) [59] — `[?Name attrs body]`. Reserved EvalNames
  # (if/for/with/cond/include/def/use/let/fn/match/try) parse into this
  # node. Inert at v0.6.0; the CXL evaluator dispatches on `name`.
  # ast_bin tag 0x0E (format v5+).
  class EvalDirective
    attr_accessor :name, :attrs, :items
    def initialize(name, attrs: [], items: [])
      @name  = name
      @attrs = attrs
      @items = items
    end
  end

  class DoctypeDecl
    attr_accessor :name, :external_id, :int_subset
    def initialize(name, external_id: nil, int_subset: [])
      @name, @external_id, @int_subset = name, external_id, int_subset
    end
  end

  class BlockContent
    attr_accessor :items
    def initialize(items: []); @items = items; end
  end

  class Element
    attr_accessor :name, :anchor, :merge, :data_type, :attrs, :items, :local, :ns_uri, :id, :body_ref

    def initialize(name, attrs: [], items: [], anchor: nil, merge: nil, data_type: nil, id: nil, body_ref: nil)
      @name       = name
      @attrs      = attrs
      @items      = items
      @anchor     = anchor
      @merge      = merge
      @data_type  = data_type
      # v3.4 (ADR 0002): expanded-name fields populated by
      # CxLib.resolve_namespaces. See Attr.
      @local      = ''
      @ns_uri     = nil
      # v3.4 (ADR 0003): syntactic ID declaration ("#name" token); nil
      # when the element has no ID. Distinct from anchor.
      @id         = id
      # Phase 7.70 (ADR 0003 D1): body-position reference. When set, the
      # element is the body-position [name @target] shape carrying an
      # IDREF target (no other meta or items). Carried over the ast_bin
      # wire format at v3+ (Phase 7.70 bumped 2 → 3).
      @body_ref   = body_ref
    end

    # Local part of the element name (post-colon, or whole name).
    def local_name = @local
    # Resolved namespace URI; nil when no binding is in scope and the
    # prefix is not reserved.
    def namespace_uri = @ns_uri

    # Returns attribute value by name, or nil
    def attr(name)
      a = @attrs.find { |x| x.name == name }
      a&.value
    end

    # Returns concatenated text and scalar child content
    def text
      parts = []
      @items.each do |item|
        case item
        when TextNode   then parts << item.value
        when ScalarNode then parts << (item.value.nil? ? 'null' : item.value.to_s)
        end
      end
      parts.join(' ')
    end

    # Returns value of first Scalar child, or nil
    def scalar
      s = @items.find { |i| i.is_a?(ScalarNode) }
      s&.value
    end

    # Returns all child Elements
    def children
      @items.select { |i| i.is_a?(Element) }
    end

    # First child Element with given name
    def get(name)
      @items.find { |i| i.is_a?(Element) && i.name == name }
    end

    # All child Elements with given name
    def get_all(name)
      @items.select { |i| i.is_a?(Element) && i.name == name }
    end

    # All descendant Elements with given name (depth-first)
    def find_all(name)
      result = []
      @items.each do |item|
        next unless item.is_a?(Element)
        result << item if item.name == name
        result.concat(item.find_all(name))
      end
      result
    end

    # First descendant Element with given name (depth-first)
    def find_first(name)
      @items.each do |item|
        next unless item.is_a?(Element)
        return item if item.name == name
        found = item.find_first(name)
        return found unless found.nil?
      end
      nil
    end

    # Navigate by slash-separated path
    def at(path)
      parts = path.split('/').reject(&:empty?)
      cur = self
      parts.each do |part|
        return nil if cur.nil?
        cur = cur.get(part)
      end
      cur
    end

    # Mutation
    def set_attr(name, value, data_type = nil)
      existing = @attrs.find { |a| a.name == name }
      if existing
        existing.value     = value
        existing.data_type = data_type
      else
        @attrs << Attr.new(name, value, data_type)
      end
    end

    def remove_attr(name)
      @attrs.reject! { |a| a.name == name }
    end

    def append(node)
      @items << node
    end

    def prepend(node)
      @items.unshift(node)
    end

    def insert(index, node)
      @items.insert(index, node)
    end

    def remove(node)
      @items.reject! { |i| i.equal?(node) }
    end

    # Remove all direct child Elements with the given name (mutating)
    def remove_child(name)
      @items.reject! { |i| i.is_a?(Element) && i.name == name }
    end

    # Remove child node at index (no-op if out of bounds) (mutating)
    def remove_at(index)
      return unless index >= 0 && index < @items.size
      @items.delete_at(index)
    end

    # First Element matching a CXPath expression (searches subtree of self)
    def select(expr)
      select_all(expr).first
    end

    # All Elements matching a CXPath expression (searches subtree of self).
    #
    # v3.4: thunks to libcx via cx_select_all_paths (CB-5). Returned
    # Elements are *live references* into self's tree — mutations
    # propagate, preserving prior behavior. Semantics match V's
    # Element.select_all: this element's items become the top-level
    # candidate set.
    def select_all(expr)
      # Emit each Element child as top-level so V's
      # Document.select_all_paths walks the same candidate set V's
      # Element.select_all would. Track a doc-index → orig-index
      # mapping (non-Element items don't affect CXPath matches but
      # shift item indices).
      parts_str = String.new(encoding: Encoding::UTF_8)
      doc_to_orig = []
      @items.each_with_index do |item, i|
        if item.is_a?(Element)
          parts_str << CXLib._emit_element(item, 0)
          doc_to_orig << i
        end
      end
      doc_str = parts_str.rstrip
      paths = CXLib.select_all_paths(doc_str, expr)
      out = []
      paths.each do |p|
        next if p.empty?
        top = p[0]
        next if top < 0 || top >= doc_to_orig.size
        node = @items[doc_to_orig[top]]
        ok = true
        p[1..].each do |k|
          unless node.is_a?(Element) && k >= 0 && k < node.items.size
            ok = false
            break
          end
          node = node.items[k]
        end
        out << node if ok && node.is_a?(Element)
      end
      out
    end

    def to_cx
      CXLib._emit_element(self, 0).rstrip("\n")
    end
  end

  class Document
    attr_accessor :elements, :prolog, :doctype

    def initialize(elements: [], prolog: [], doctype: nil)
      @elements = elements
      @prolog   = prolog
      @doctype  = doctype
    end

    # First top-level Element
    def root
      @elements.find { |e| e.is_a?(Element) }
    end

    # First top-level Element with given name
    def get(name)
      @elements.find { |e| e.is_a?(Element) && e.name == name }
    end

    # Navigate by slash-separated path from root
    def at(path)
      parts = path.split('/').reject(&:empty?)
      return root if parts.empty?
      cur = get(parts[0])
      return cur if parts.size == 1 || cur.nil?
      cur.at(parts[1..].join('/'))
    end

    # All descendant Elements with given name
    def find_all(name)
      result = []
      @elements.each do |e|
        next unless e.is_a?(Element)
        result << e if e.name == name
        result.concat(e.find_all(name))
      end
      result
    end

    # First descendant Element with given name
    def find_first(name)
      @elements.each do |e|
        next unless e.is_a?(Element)
        return e if e.name == name
        found = e.find_first(name)
        return found unless found.nil?
      end
      nil
    end

    # Return the Element declaring `#id`, or nil. v3.4 (ADR 0003).
    def resolve_id(id)
      CXLib._find_element_by_id(@elements, id) ||
        CXLib._find_element_by_id(@prolog, id)
    end

    # {id => Element} map for the whole document. v3.4 (ADR 0003).
    def elements_by_id
      out = {}
      CXLib._collect_elements_by_id(@elements, out)
      CXLib._collect_elements_by_id(@prolog, out)
      out
    end

    def append(node)
      @elements << node
    end

    def prepend(node)
      @elements.unshift(node)
    end

    # First Element matching a CXPath expression
    def select(expr)
      select_all(expr).first
    end

    # All Elements matching a CXPath expression.
    #
    # v3.4: thunks to libcx via cx_select_all_paths (CB-5). Returned
    # Elements are live references into this Document's tree —
    # mutations propagate.
    def select_all(expr)
      paths = CXLib.select_all_paths(to_cx, expr)
      paths.filter_map { |p| CXLib._navigate_doc_path(self, p) }
    end

    # Return new Document with element at path replaced by f(element) (immutable)
    def transform(path, &f)
      parts = path.split('/').reject(&:empty?)
      return self if parts.empty?
      @elements.each_with_index do |node, i|
        next unless node.is_a?(Element) && node.name == parts[0]
        if parts.size == 1
          return CXLib._doc_replace_at(self, i, f.call(CXLib._elem_detached(node)))
        end
        updated = CXLib._path_copy_element(node, parts[1..], &f)
        return updated ? CXLib._doc_replace_at(self, i, updated) : self
      end
      self
    end

    # Return new Document with all matching elements replaced by f(element)
    # (immutable).
    #
    # v3.4: thunks to libcx via cx_select_all_paths (CB-5). Paths are
    # applied bottom-up (longest first) so when a parent is rewritten
    # its f-input already contains the f-results of descendant
    # matches — matching the prior post-order semantics.
    def transform_all(expr, &f)
      paths = CXLib.select_all_paths(to_cx, expr)
      return self if paths.empty?
      sorted = paths.sort_by { |p| -p.size }
      new_doc = self
      sorted.each do |p|
        target = CXLib._navigate_doc_path(new_doc, p)
        next if target.nil?
        new_doc = CXLib._replace_at_doc_path(new_doc, p, f.call(CXLib._elem_detached(target)))
      end
      new_doc
    end

    def to_cx
      CXLib._emit_doc(self)
    end

    # Serialize this Document to a FRAMED [u32 LE size][payload] AST
    # bin String (binary-encoded). Used internally by to_xml / to_json /
    # etc. (Phase 5 / CB-1).
    def to_ast_bin
      CXLib.encode_ast(self)
    end

    # v3.4 (Phase 5 / CB-1): format methods now go through
    # cx_ast_bin_to_<fmt>(to_ast_bin) directly, avoiding the prior
    # emit-CX-and-reparse detour.
    def to_xml  = CXLib.ast_bin_to_xml (to_ast_bin)
    def to_json = CXLib.ast_bin_to_json(to_ast_bin)
    def to_yaml = CXLib.ast_bin_to_yaml(to_ast_bin)
    def to_toml = CXLib.ast_bin_to_toml(to_ast_bin)
    def to_md   = CXLib.ast_bin_to_md  (to_ast_bin)
  end

  # ── Deserialization: AST JSON → native types ───────────────────────────────

  def self.node_from_hash(h)
    case h['type']
    when 'Element'
      Element.new(
        h['name'],
        attrs:     (h['attrs'] || []).map { |a| Attr.new(a['name'], a['value'], a['dataType']) },
        items:     (h['items'] || []).map { |n| node_from_hash(n) },
        anchor:    h['anchor'],
        merge:     h['merge'],
        data_type: h['dataType'],
      )
    when 'Text'       then TextNode.new(h['value'])
    when 'Scalar'     then ScalarNode.new(h['dataType'], h['value'])
    when 'Comment'    then Comment.new(h['value'])
    when 'RawText'    then RawText.new(h['value'])
    when 'EntityRef'  then EntityRef.new(h['name'])
    when 'Alias'      then Alias.new(h['name'])
    when 'PI'         then PI.new(h['target'], h['data'])
    when 'XMLDecl'
      XMLDecl.new(version: h.fetch('version', '1.0'), encoding: h['encoding'], standalone: h['standalone'])
    when 'CXDirective'
      CXDirective.new(attrs: (h['attrs'] || []).map { |a| Attr.new(a['name'], a['value']) })
    when 'DoctypeDecl'
      DoctypeDecl.new(h['name'], external_id: h['externalID'], int_subset: h.fetch('intSubset', []))
    when 'BlockContent'
      BlockContent.new(items: (h['items'] || []).map { |n| node_from_hash(n) })
    else
      TextNode.new(h.to_s)
    end
  end

  def self.doc_from_hash(d)
    doctype = nil
    if d['doctype']
      dt = d['doctype']
      doctype = DoctypeDecl.new(dt['name'], external_id: dt['externalID'], int_subset: dt.fetch('intSubset', []))
    end
    Document.new(
      prolog:   (d['prolog']   || []).map { |n| node_from_hash(n) },
      doctype:  doctype,
      elements: (d['elements'] || []).map { |n| node_from_hash(n) },
    )
  end

  # ── Namespace resolution (ADR 0002 / spec/namespaces.md) ─────────────────
  #
  # Mirrors V core's vcx/cx/namespaces.v.

  XML_NAMESPACE_URI = 'http://www.w3.org/XML/1998/namespace'
  CX_NAMESPACE_URI  = 'https://cx-home.org/ns/cx'

  def self.split_ns_prefix(name)
    i = name.index(':')
    return ['', name] if i.nil?
    [name[0...i], name[(i + 1)..]]
  end

  def self.lookup_ns(prefix, scope)
    case prefix
    when 'xml'   then return XML_NAMESPACE_URI
    when 'cx'    then return CX_NAMESPACE_URI
    when 'xmlns' then return nil
    end
    scope.reverse_each do |frame|
      if frame.key?(prefix)
        uri = frame[prefix]
        return (uri.nil? || uri.empty?) ? nil : uri
      end
    end
    nil
  end

  def self.resolve_element(e, scope)
    frame = {}
    e.attrs.each do |a|
      v = a.value.nil? ? '' : a.value.to_s
      if a.name == 'xmlns'
        frame[''] = v
      elsif a.name.start_with?('xmlns:') && a.name.length > 6
        frame[a.name[6..]] = v
      end
    end
    pushed = !frame.empty?
    scope.push(frame) if pushed

    prefix, local = split_ns_prefix(e.name)
    e.local  = local
    e.ns_uri = lookup_ns(prefix, scope)

    e.attrs.each do |a|
      ap, al = split_ns_prefix(a.name)
      a.local = al
      if a.name == 'xmlns' || ap == 'xmlns'
        a.ns_uri = nil
        next
      end
      if ap.empty?
        # Default ns does not apply to unprefixed attributes.
        a.ns_uri = nil
        next
      end
      a.ns_uri = lookup_ns(ap, scope)
    end

    e.items.each do |item|
      resolve_element(item, scope) if item.is_a?(Element)
    end

    scope.pop if pushed
  end

  # Populate Element.{local, ns_uri} and Attr.{local, ns_uri} on every
  # node in +doc+ per ADR 0002. Idempotent. Called automatically by
  # +parse+, +parse_xml+, +parse_json+, +parse_yaml+, +parse_toml+,
  # +parse_md+.
  def self.resolve_namespaces(doc)
    scope = []
    doc.elements.each do |n|
      resolve_element(n, scope) if n.is_a?(Element)
    end
  end

  # ── Parse functions ────────────────────────────────────────────────────────

  def self.parse(cx_str)
    doc = decode_ast(ast_bin(cx_str))
    resolve_namespaces(doc)
    doc
  end

  # v3.4 (Phase 5 / CB-2): parse_<format> goes through
  # cx_<format>_to_ast_bin directly, avoiding the prior cx_<fmt>_to_ast
  # → JSON.parse → walk-hash pipeline.

  def self.parse_xml(xml_str)
    doc = decode_ast(xml_to_ast_bin(xml_str))
    resolve_namespaces(doc); doc
  end

  def self.parse_json(json_str)
    doc = decode_ast(json_to_ast_bin(json_str))
    resolve_namespaces(doc); doc
  end

  def self.parse_yaml(yaml_str)
    doc = decode_ast(yaml_to_ast_bin(yaml_str))
    resolve_namespaces(doc); doc
  end

  def self.parse_toml(toml_str)
    doc = decode_ast(toml_to_ast_bin(toml_str))
    resolve_namespaces(doc); doc
  end

  def self.parse_md(md_str)
    doc = decode_ast(md_to_ast_bin(md_str))
    resolve_namespaces(doc); doc
  end

  # Stream a CX string as an array of StreamEvents.
  #
  # v3.4 (Phase 5 / CB-4): pulls events one-by-one via the
  # cx_events_open / cx_events_next / cx_events_close handle API.
  # Replaces the prior eager-buffered cx_to_events_bin path. For true
  # pull-based streaming with caller-controlled cancellation, use
  # CXLib::EventStream directly.
  def self.stream(cx_str)
    s = EventStream.new(cx_str)
    begin
      s.to_a
    ensure
      s.close
    end
  end

  # ── Data binding ──────────────────────────────────────────────────────────

  # Deserialize a CX data string into native Ruby types
  # (Hash/Array/scalar).
  #
  # v3.4: parses through CXDB v1 (cx_to_data_bin) directly into Ruby
  # types — no JSON-string detour. Type fidelity preserved (integers
  # stay Integer, floats stay Float, booleans stay TrueClass/FalseClass,
  # dates round-trip as Date, datetimes as Time, byte strings as
  # ASCII-8BIT String). Closes audit finding CB-3.
  def self.loads(cx_str)
    DataBin.decode(to_data_bin(cx_str))
  end

  def self.loads_xml(xml_str)
    JSON.parse(xml_to_json(xml_str))
  end

  def self.loads_json(json_str)
    JSON.parse(json_to_json(json_str))
  end

  def self.loads_yaml(yaml_str)
    JSON.parse(yaml_to_json(yaml_str))
  end

  def self.loads_toml(toml_str)
    JSON.parse(toml_to_json(toml_str))
  end

  def self.loads_md(md_str)
    JSON.parse(md_to_json(md_str))
  end

  # Serialize native Ruby types (Hash/Array/scalar) to a CX string.
  #
  # v3.4: encodes the Ruby value as CXDB v1 bytes directly, then calls
  # cx_from_data_bin to produce canonical CX. No JSON-string detour;
  # type fidelity preserved on round-trip with #loads. Closes audit
  # finding CB-3.
  def self.dumps(data)
    from_data_bin(DataBin.encode(data))
  end

  # ── CX emitter ────────────────────────────────────────────────────────────

  DATE_RE_     = /^\d{4}-\d{2}-\d{2}$/
  DATETIME_RE_ = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/
  HEX_RE_      = /^0[xX][0-9a-fA-F]+$/

  def self._would_autotype(s)
    return false if s.include?(' ')
    return true  if HEX_RE_.match?(s)
    begin
      Integer(s, 10)
      return true
    rescue ArgumentError, TypeError
      # not an integer
    end
    if s.include?('.') || s.downcase.include?('e')
      begin
        Float(s)
        return true
      rescue ArgumentError, TypeError
        # not a float
      end
    end
    return true if %w[true false null].include?(s)
    return true if DATETIME_RE_.match?(s)
    return true if DATE_RE_.match?(s)
    false
  end

  def self._cx_choose_quote(s)
    return "'#{s}'"   unless s.include?("'")
    return "\"#{s}\"" unless s.include?('"')
    return "'''#{s}'''" unless s.include?("'''")
    "\"#{s}\""
  end

  def self._cx_quote_text(s)
    needs = s.start_with?(' ') || s.end_with?(' ') ||
            s.include?('  ')   || s.include?("\n") || s.include?("\t") ||
            s.include?('[')    || s.include?(']')  || s.include?('&') ||
            s.start_with?(':') || s.start_with?("'") || s.start_with?('"') ||
            _would_autotype(s)
    needs ? _cx_choose_quote(s) : s
  end

  def self._cx_quote_attr(s)
    return "'#{s}'" if s.empty? || s.include?(' ') || s.include?("'") || s.include?('"')
    s
  end

  def self._emit_scalar(s)
    v = s.value
    return 'null'  if v.nil?
    return (v ? 'true' : 'false') if v == true || v == false
    if v.is_a?(Integer)
      return v.to_s
    end
    if v.is_a?(Float)
      f = v.to_s
      return (f.include?('.') || f.downcase.include?('e')) ? f : "#{f}.0"
    end
    v.to_s
  end

  def self._emit_attr(a)
    if a.is_ref
      # ADR 0003 D1: bare `@id` round-trips verbatim.
      return "#{a.name}=@#{a.value}"
    end
    dt = a.data_type
    if dt == 'int'
      return "#{a.name}=#{a.value.to_i}"
    end
    if dt == 'float'
      f = a.value.to_f.to_s
      v = (f.include?('.') || f.downcase.include?('e')) ? f : "#{f}.0"
      return "#{a.name}=#{v}"
    end
    if dt == 'bool'
      return "#{a.name}=#{a.value ? 'true' : 'false'}"
    end
    if dt == 'null'
      return "#{a.name}=null"
    end
    # string attr — quote if would autotype OR starts with '@' (else
    # would mis-parse as is_ref reference per ADR 0003).
    s = a.value.to_s
    starts_at = !s.empty? && s[0] == '@'
    v = (_would_autotype(s) || starts_at) ? _cx_choose_quote(s) : _cx_quote_attr(s)
    "#{a.name}=#{v}"
  end

  def self._emit_inline(node)
    case node
    when TextNode
      node.value.strip.empty? ? '' : _cx_quote_text(node.value)
    when ScalarNode
      _emit_scalar(node)
    when EntityRef
      "&#{node.name};"
    when RawText
      "[##{node.value}#]"
    when Element
      _emit_element(node, 0).rstrip("\n")
    when BlockContent
      inner = node.items.map do |n|
        n.is_a?(TextNode) ? n.value : _emit_element(n, 0).rstrip("\n")
      end.join
      "[|#{inner}|]"
    else
      ''
    end
  end

  def self._emit_element(e, depth)
    ind = '  ' * depth
    # Phase 7.70 (ADR 0003 D1): body-position reference shape.
    if e.body_ref
      return "#{ind}[#{e.name} @#{e.body_ref}]\n"
    end
    has_child_elems = e.items.any? { |i| i.is_a?(Element) }
    has_text        = e.items.any? { |i| i.is_a?(TextNode) || i.is_a?(ScalarNode) ||
                                         i.is_a?(EntityRef) || i.is_a?(RawText) }
    is_multiline    = has_child_elems && !has_text

    meta_parts = []
    meta_parts << "&#{e.anchor}" if e.anchor
    meta_parts << "*#{e.merge}"  if e.merge
    meta_parts << "##{e.id}"     if e.id
    meta_parts << ":#{e.data_type}" if e.data_type
    e.attrs.each { |a| meta_parts << _emit_attr(a) }
    meta = meta_parts.empty? ? '' : ' ' + meta_parts.join(' ')

    if is_multiline
      lines = ["#{ind}[#{e.name}#{meta}\n"]
      e.items.each { |item| lines << _emit_node(item, depth + 1) }
      lines << "#{ind}]\n"
      return lines.join
    end

    if e.items.empty? && meta.empty?
      return "#{ind}[#{e.name}]\n"
    end

    body_parts = e.items.map { |i| _emit_inline(i) }.reject(&:empty?)
    body = body_parts.join(' ')
    sep  = body.empty? ? '' : ' '
    "#{ind}[#{e.name}#{meta}#{sep}#{body}]\n"
  end

  def self._emit_node(node, depth)
    ind = '  ' * depth
    case node
    when Element
      _emit_element(node, depth)
    when TextNode
      _cx_quote_text(node.value)
    when ScalarNode
      _emit_scalar(node)
    when Comment
      "#{ind}[-#{node.value}]\n"
    when RawText
      "#{ind}[##{node.value}#]\n"
    when EntityRef
      "&#{node.name};"
    when Alias
      "#{ind}[*#{node.name}]\n"
    when BlockContent
      inner = node.items.map { |i| _emit_node(i, 0) }.join
      "#{ind}[|#{inner}|]\n"
    when PI
      data = node.data ? " #{node.data}" : ''
      "#{ind}[?#{node.target}#{data}]\n"
    when XMLDecl
      parts = ["version=#{node.version}"]
      parts << "encoding=#{node.encoding}"   if node.encoding
      parts << "standalone=#{node.standalone}" if node.standalone
      "[?xml #{parts.join(' ')}]\n"
    when CXDirective
      attrs = node.attrs.map { |a| "#{a.name}=#{_cx_quote_attr(a.value.to_s)}" }.join(' ')
      "[?cx #{attrs}]\n"
    when DoctypeDecl
      ext = ''
      if node.external_id
        if node.external_id['public']
          pub = node.external_id['public']
          sys = node.external_id.fetch('system', '')
          ext = " PUBLIC '#{pub}' '#{sys}'"
        elsif node.external_id['system']
          ext = " SYSTEM '#{node.external_id['system']}'"
        end
      end
      "[!DOCTYPE #{node.name}#{ext}]\n"
    else
      ''
    end
  end

  def self._emit_doc(doc)
    parts = []
    doc.prolog.each   { |node| parts << _emit_node(node, 0) }
    parts << _emit_node(doc.doctype, 0) if doc.doctype
    doc.elements.each { |node| parts << _emit_node(node, 0) }
    parts.join.rstrip("\n")
  end

  # Internal helpers (indicated by _ prefix convention; not made private so
  # they remain accessible from nested class instance methods like Document#to_cx)
end

# Streaming Table reader / writer + schema-driven CXDB encoding +
# chunked-table one-shot (Phase 7.74b-cont-3). Requires `ffi_lib` to
# already have run, since it adds 21 more `attach_function` decls.
require_relative 'cxlib/streaming_table'

# Public Table API per ADR 0018 D1.
require_relative 'cxlib/table'
