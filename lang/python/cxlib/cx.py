"""
Thin ctypes wrapper around libcx (V implementation).

Locates libcx.dylib / libcx.so relative to this file. The primary library
is the V implementation in vcx/target/. All public functions return Python
str or raise RuntimeError on parse failure.
"""

from __future__ import annotations

import ctypes
import os
import pathlib

def _load_lib():
    lib_name = "libcx.dylib" if os.uname().sysname == "Darwin" else "libcx.so"

    # 1. Explicit path override
    if env := os.environ.get("LIBCX_PATH"):
        return ctypes.CDLL(env)

    candidates = []

    # 2. Directory override
    if env_dir := os.environ.get("LIBCX_LIB_DIR"):
        candidates.append(pathlib.Path(env_dir) / lib_name)

    # 3. System paths
    for sys_dir in ("/usr/local/lib", "/opt/homebrew/lib", "/usr/lib",
                    "/usr/lib/x86_64-linux-gnu", "/usr/lib/aarch64-linux-gnu"):
        candidates.append(pathlib.Path(sys_dir) / lib_name)

    # 4. Repo-relative fallback (development)
    base = pathlib.Path(__file__).resolve().parent.parent.parent.parent
    candidates += [
        base / "vcx" / "target" / lib_name,
        base / "dist" / "lib" / lib_name,
    ]

    for p in candidates:
        if p.exists():
            return ctypes.CDLL(str(p))
    raise RuntimeError(
        f"libcx not found. Install with 'sudo make install' or set LIBCX_PATH.\n"
        f"Looked in: {[str(c) for c in candidates]}"
    )

_lib = _load_lib()

_lib.cx_free.restype  = None
_lib.cx_free.argtypes = [ctypes.c_char_p]

_lib.cx_version.restype  = ctypes.c_char_p
_lib.cx_version.argtypes = []

def _setup(fn):
    fn.restype  = ctypes.c_char_p
    fn.argtypes = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]

_all_fns = (
    # Phase 6 / spec/abi.md §2.6 — canonical-form tooling
    "cx_fmt", "cx_canonical", "cx_hash",
    "cx_to_cx",   "cx_to_xml",   "cx_to_ast",   "cx_to_json",   "cx_to_yaml",   "cx_to_toml",
    "cx_xml_to_cx",  "cx_xml_to_xml",  "cx_xml_to_ast",  "cx_xml_to_json",  "cx_xml_to_yaml",  "cx_xml_to_toml",
    "cx_json_to_cx", "cx_json_to_xml", "cx_json_to_ast", "cx_json_to_json", "cx_json_to_yaml", "cx_json_to_toml",
    "cx_yaml_to_cx", "cx_yaml_to_xml", "cx_yaml_to_ast", "cx_yaml_to_json", "cx_yaml_to_yaml", "cx_yaml_to_toml",
    "cx_toml_to_cx", "cx_toml_to_xml", "cx_toml_to_ast", "cx_toml_to_json", "cx_toml_to_yaml", "cx_toml_to_toml",
    "cx_to_events",
    "cx_ast_to_cx", "cx_to_cx_compact",
)

# Binary protocol functions return length-prefixed raw buffers, not C strings.
# Use c_void_p so ctypes returns the raw integer address instead of auto-decoding.
_bin_fns = (
    "cx_to_events_bin", "cx_to_ast_bin",
    # ABI v2 — symmetric binary AST (Phase 2c) + data_bin (Phase 2b.6)
    "cx_to_data_bin",
    "cx_xml_to_ast_bin", "cx_json_to_ast_bin", "cx_yaml_to_ast_bin",
    "cx_toml_to_ast_bin",
    # data_bin one-shot loaders (Phase 7.28; spec/abi.md §2.4)
    "cx_xml_to_data_bin", "cx_json_to_data_bin", "cx_yaml_to_data_bin",
    "cx_toml_to_data_bin",
)
for _name in _bin_fns:
    _fn = getattr(_lib, _name)
    _fn.restype  = ctypes.c_void_p
    _fn.argtypes = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]

# v0.7.0 GG3 / GG4 — include-resolver C ABI variants.
_lib.cx_to_ast_bin_with_include_root.restype  = ctypes.c_void_p
_lib.cx_to_ast_bin_with_include_root.argtypes = [
    ctypes.c_char_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)
]
_lib.cx_to_data_bin_with_include_root.restype  = ctypes.c_void_p
_lib.cx_to_data_bin_with_include_root.argtypes = [
    ctypes.c_char_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)
]
_lib.cx_to_cx_with_include_root.restype  = ctypes.c_char_p
_lib.cx_to_cx_with_include_root.argtypes = [
    ctypes.c_char_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)
]

# ast_bin -> format symbols take a binary buffer in, return text out.
_ast_bin_to_fns = (
    "cx_ast_bin_to_cx", "cx_ast_bin_to_xml", "cx_ast_bin_to_json",
    "cx_ast_bin_to_yaml", "cx_ast_bin_to_toml",
)
for _name in _ast_bin_to_fns:
    _fn = getattr(_lib, _name)
    _fn.restype  = ctypes.c_char_p
    _fn.argtypes = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]

# cx_from_data_bin and the data_bin one-shot dumpers: binary input → text output.
_data_bin_to_fns = (
    "cx_from_data_bin",
    "cx_data_bin_to_xml", "cx_data_bin_to_json", "cx_data_bin_to_yaml",
    "cx_data_bin_to_toml",
)
for _name in _data_bin_to_fns:
    _fn = getattr(_lib, _name)
    _fn.restype  = ctypes.c_char_p
    _fn.argtypes = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]

# Streaming handle API (Phase 2e).
_lib.cx_events_open.restype  = ctypes.c_void_p
_lib.cx_events_open.argtypes = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_events_next.restype  = ctypes.c_void_p
_lib.cx_events_next.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_events_close.restype  = None
_lib.cx_events_close.argtypes = [ctypes.c_void_p]

# Chunked-table one-shot (Phase 7.72; spec/abi.md §2.10, capability bit 21).
_lib.cx_to_data_bin_chunked.restype  = ctypes.c_void_p
_lib.cx_to_data_bin_chunked.argtypes = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]

# Streaming Table reader / writer (Phase 7.74a; spec/abi.md §2.10, capability bit 21).
_lib.cx_table_reader_open.restype     = ctypes.c_void_p
_lib.cx_table_reader_open.argtypes    = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_table_reader_open_fd.restype  = ctypes.c_void_p
_lib.cx_table_reader_open_fd.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_table_reader_schema.restype   = ctypes.c_void_p
_lib.cx_table_reader_schema.argtypes  = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_table_reader_next.restype     = ctypes.c_void_p
_lib.cx_table_reader_next.argtypes    = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_table_reader_close.restype    = None
_lib.cx_table_reader_close.argtypes   = [ctypes.c_void_p]

_lib.cx_table_writer_open.restype            = ctypes.c_void_p
_lib.cx_table_writer_open.argtypes           = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_table_writer_open_fd.restype         = ctypes.c_void_p
_lib.cx_table_writer_open_fd.argtypes        = [ctypes.c_char_p, ctypes.c_int, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_table_writer_emit_row_group.restype  = ctypes.c_char_p
_lib.cx_table_writer_emit_row_group.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_table_writer_close_get_bytes.restype = ctypes.c_void_p
_lib.cx_table_writer_close_get_bytes.argtypes= [ctypes.c_void_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_table_writer_close.restype           = None
_lib.cx_table_writer_close.argtypes          = [ctypes.c_void_p]

# Schema-driven encoding (Phase 7.73; spec/abi.md §2.12, capability bit 24).
# Loaders: (input, schema, ref_form, name_hint, err_out). Dumper: (data_bin, schema_hint, err_out).
_schema_driven_loader_fns = (
    'cx_to_data_bin_schema_driven',     'cx_xml_to_data_bin_schema_driven',
    'cx_json_to_data_bin_schema_driven','cx_yaml_to_data_bin_schema_driven',
    'cx_toml_to_data_bin_schema_driven',
    'cx_csv_to_data_bin_schema_driven', 'cx_tsv_to_data_bin_schema_driven',
    'cx_psv_to_data_bin_schema_driven',
)
for _name in _schema_driven_loader_fns:
    _fn = getattr(_lib, _name)
    _fn.restype  = ctypes.c_void_p
    _fn.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int,
                    ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_from_data_bin_schema_driven.restype  = ctypes.c_char_p
_lib.cx_from_data_bin_schema_driven.argtypes = [ctypes.c_char_p, ctypes.c_char_p,
                                                ctypes.POINTER(ctypes.c_char_p)]

# ABI v2 metadata symbols (Phase 2g).
_lib.cx_abi_version.restype  = ctypes.c_char_p
_lib.cx_abi_version.argtypes = []
_lib.cx_features.restype  = ctypes.c_char_p
_lib.cx_features.argtypes = []

# Schema validator (Phase 7.74c+; spec/abi.md §2.13, capability bit 25).
# All four return a framed [u32 LE size][u32 count][diagnostic*] payload as
# a heap pointer; caller frees with cx_free. Implicit-length forms read
# NUL-terminated text; _with_len forms take explicit byte counts.
_lib.cx_validate.restype  = ctypes.c_void_p
_lib.cx_validate.argtypes = [ctypes.c_char_p, ctypes.c_char_p,
                             ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_validate_with_len.restype  = ctypes.c_void_p
_lib.cx_validate_with_len.argtypes = [ctypes.c_char_p, ctypes.c_size_t,
                                      ctypes.c_char_p, ctypes.c_size_t,
                                      ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_validate_apply_defaults.restype  = ctypes.c_void_p
_lib.cx_validate_apply_defaults.argtypes = [ctypes.c_char_p, ctypes.c_char_p,
                                            ctypes.POINTER(ctypes.c_char_p),
                                            ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_validate_apply_defaults_with_len.restype  = ctypes.c_void_p
_lib.cx_validate_apply_defaults_with_len.argtypes = [
    ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p, ctypes.c_size_t,
    ctypes.POINTER(ctypes.c_char_p), ctypes.POINTER(ctypes.c_char_p),
]

for _name in _all_fns:
    _setup(getattr(_lib, _name))

# Streaming-write API (Phase 7.74h; spec/abi.md §2.15, capability bit 27).
# Lifecycle returns a handle (c_void_p); emit functions return a diagnostic
# string (c_char_p, NULL on success) plus mirror it into err_out. close_get_bytes
# returns a framed [u32 LE size][payload] buffer (c_void_p) that the wrapper
# unwraps before returning bytes to the caller.
_lib.cx_events_writer_open.restype          = ctypes.c_void_p
_lib.cx_events_writer_open.argtypes         = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_events_writer_open_fd.restype       = ctypes.c_void_p
_lib.cx_events_writer_open_fd.argtypes      = [ctypes.c_char_p, ctypes.c_int, ctypes.POINTER(ctypes.c_char_p)]
# cx_events_writer_open_shaped removed 2026-05-10: superseded by
# CX code is the only output-shape mechanism (see cx_eval* below).
_lib.cx_events_writer_close_get_bytes.restype  = ctypes.c_void_p
_lib.cx_events_writer_close_get_bytes.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_events_writer_close.restype         = None
_lib.cx_events_writer_close.argtypes        = [ctypes.c_void_p]

_lib.cx_events_writer_start_doc.restype     = ctypes.c_char_p
_lib.cx_events_writer_start_doc.argtypes    = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_events_writer_end_doc.restype       = ctypes.c_char_p
_lib.cx_events_writer_end_doc.argtypes      = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_events_writer_start_element_with_len.restype  = ctypes.c_char_p
_lib.cx_events_writer_start_element_with_len.argtypes = [
    ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p,
    ctypes.c_char_p, ctypes.c_char_p, ctypes.c_size_t,
    ctypes.POINTER(ctypes.c_char_p),
]
_lib.cx_events_writer_end_element.restype   = ctypes.c_char_p
_lib.cx_events_writer_end_element.argtypes  = [ctypes.c_void_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_events_writer_text.restype          = ctypes.c_char_p
_lib.cx_events_writer_text.argtypes         = [ctypes.c_void_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_events_writer_scalar.restype        = ctypes.c_char_p
_lib.cx_events_writer_scalar.argtypes       = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_events_writer_comment.restype       = ctypes.c_char_p
_lib.cx_events_writer_comment.argtypes      = [ctypes.c_void_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_events_writer_pi.restype            = ctypes.c_char_p
_lib.cx_events_writer_pi.argtypes           = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_events_writer_entity_ref.restype    = ctypes.c_char_p
_lib.cx_events_writer_entity_ref.argtypes   = [ctypes.c_void_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_events_writer_raw_text.restype      = ctypes.c_char_p
_lib.cx_events_writer_raw_text.argtypes     = [ctypes.c_void_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_events_writer_alias.restype         = ctypes.c_char_p
_lib.cx_events_writer_alias.argtypes        = [ctypes.c_void_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_events_writer_start_table_with_len.restype  = ctypes.c_char_p
_lib.cx_events_writer_start_table_with_len.argtypes = [
    ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t,
    ctypes.POINTER(ctypes.c_char_p),
]
_lib.cx_events_writer_row_group_with_len.restype  = ctypes.c_char_p
_lib.cx_events_writer_row_group_with_len.argtypes = [
    ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t,
    ctypes.POINTER(ctypes.c_char_p),
]
_lib.cx_events_writer_end_table.restype     = ctypes.c_char_p
_lib.cx_events_writer_end_table.argtypes    = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_char_p)]

def _call(fn, text: str) -> str:
    err = ctypes.c_char_p(None)
    out = fn(text.encode(), ctypes.byref(err))
    if out is None:
        msg = err.value.decode() if err.value else "unknown error"
        raise RuntimeError(msg)
    return out.decode()

# ── CX code evaluator (v0.7.6, Phase 3.11) ────────────────────────────
#
# Per spec/audits/code_abi_v1.md. Three C ABI exports route through the
# v0.7.6 evaluator (vcx/code/) — the v0.7.0 cx_eval* family was retired
# alongside the cxl POC in Phase 7. Error wire format is `CXERnnnn:msg`
# (D3 of the design poll). The `cx-err:` namespace prefix is reserved for
# value-form errors inside programs; the binding raises RuntimeError on the
# wire shape as-is.

_lib.cx_code_eval.restype  = ctypes.c_char_p
_lib.cx_code_eval.argtypes = [
    ctypes.c_char_p,                  # input  (nullable when empty)
    ctypes.c_char_p,                  # program
    ctypes.c_char_p,                  # output_target (nullable; '' → 'text')
    ctypes.POINTER(ctypes.c_char_p),  # err_out
]

_lib.cx_code_eval_with_len.restype  = ctypes.c_char_p
_lib.cx_code_eval_with_len.argtypes = [
    ctypes.c_char_p, ctypes.c_size_t, # input,   input_len
    ctypes.c_char_p, ctypes.c_size_t, # program, program_len
    ctypes.c_char_p,                  # output_target
    ctypes.POINTER(ctypes.c_char_p),  # err_out
]

# cx_code_eval_caps (include/cx.h, capability bit 38): the capability-aware
# member of the eval family. ADDITIVE — the non-caps entry points run under the
# empty (pure-only) default; this one grants a host-supplied set, deny-by-default.
_lib.cx_code_eval_caps.restype  = ctypes.c_char_p
_lib.cx_code_eval_caps.argtypes = [
    ctypes.c_char_p,                  # input  (nullable when empty)
    ctypes.c_char_p,                  # program
    ctypes.c_char_p,                  # output_target (nullable; '' → 'text')
    ctypes.c_char_p,                  # caps  (nullable/'' → empty; 'all'/'*' → full)
    ctypes.POINTER(ctypes.c_char_p),  # err_out
]

# cx_code_write_cb (include/cx.h): int (*)(const char*, size_t, void*).
_CX_PROGRAM_WRITE_CB = ctypes.CFUNCTYPE(
    ctypes.c_int,                     # return: 0 ok, non-zero aborts
    ctypes.c_char_p,                  # bytes
    ctypes.c_size_t,                  # n
    ctypes.c_void_p,                  # user
)

_lib.cx_code_eval_streaming.restype  = ctypes.c_char_p
_lib.cx_code_eval_streaming.argtypes = [
    ctypes.c_char_p, ctypes.c_size_t, # input,   input_len
    ctypes.c_char_p, ctypes.c_size_t, # program, program_len
    ctypes.c_char_p,                  # output_target
    _CX_PROGRAM_WRITE_CB,             # write_cb
    ctypes.c_void_p,                  # user
    ctypes.POINTER(ctypes.c_char_p),  # err_out
]

_lib.cx_code_eval_streamable.restype  = ctypes.c_int
_lib.cx_code_eval_streamable.argtypes = [
    ctypes.c_char_p, ctypes.c_size_t, # program, program_len
    ctypes.c_char_p,                  # output_target
]


def eval_code_streamable(program: str, output_target: str = "") -> bool:
    """Report whether `eval_code_streaming` will actually deliver this
    (program, output_target) INCREMENTALLY, without evaluating anything.

    Streaming engages only for a top-level `[?for …]` comprehension (or
    a `[?map]` directive) rendered to the `text` / `cx` targets, and
    only when the comprehension carries no `order-by` / `group-by` —
    those must see the whole result set before emitting, so they can
    never stream.

    For every other shape `eval_code_streaming` silently falls back to
    one-shot evaluation: output is still byte-identical, but the WHOLE
    result is materialised in memory and delivered as a single chunk.
    Chunk count cannot tell you this apart (a small streamed result is
    also one chunk), so ask here first when the input is large enough
    for the difference to matter.

    Returns False for a program that does not parse — the streaming
    call would surface that parse error on the one-shot path.
    """
    prog_b = program.encode()
    return bool(_lib.cx_code_eval_streamable(
        prog_b, len(prog_b),
        output_target.encode() if output_target else None,
    ))


def eval_code(input_cx: str, program: str, output_target: str = "") -> str:
    """Evaluate a CX program against an optional CX input document.

    `input_cx` may be empty when the program does not consume an
    implicit `$doc` binding (e.g. `[?for $i :in (1,2,3) :yield $i]`).
    `output_target` selects the renderer: ''/'text' (default), 'cx',
    'json', 'yaml', 'xml', 'csv', 'tsv' (always available); 'html',
    'svg', 'mermaid' return CXER0001 until the Phase 4
    reference renderer lands.

    See spec/code.md for the CX code language reference and
    spec/audits/code_abi_v1.md for the ABI contract.
    """
    in_b = input_cx.encode() if input_cx else b""
    prog_b = program.encode()
    target_b = output_target.encode() if output_target else b""
    err = ctypes.c_char_p(None)
    out = _lib.cx_code_eval_with_len(
        in_b, len(in_b),
        prog_b, len(prog_b),
        target_b,
        ctypes.byref(err),
    )
    if out is None:
        msg = err.value.decode() if err.value else "unknown error"
        raise RuntimeError(msg)
    return out.decode()


def eval_code_caps(input_cx: str, program: str, caps: str,
                   output_target: str = "") -> str:
    """Evaluate a CX program under an explicit capability grant.

    `caps` is a deny-by-default grant spec (security.md): '' ⇒ pure-only
    (the spec default), 'all'/'*' ⇒ full grant, otherwise a comma/space
    separated list such as 'net', 'read,write', or the scoped form
    'net=host:443' (the one scope spelling — L114; `net` is enforced
    host-scoped, other per-resource scopes are a tracked follow-up). An
    unknown capability name is a typed CXER0274 error (#713). The grant is
    reset to empty after the call, so it never leaks into a later evaluation.

    Used by the CSRP client wrappers (cxlib.store) to run the cx-store://
    backend with `net` granted and nothing else.
    """
    in_b = input_cx.encode() if input_cx else b""
    prog_b = program.encode()
    caps_b = caps.encode() if caps else b""
    target_b = output_target.encode() if output_target else b""
    err = ctypes.c_char_p(None)
    out = _lib.cx_code_eval_caps(
        in_b,
        prog_b,
        target_b,
        caps_b,
        ctypes.byref(err),
    )
    if out is None:
        msg = err.value.decode() if err.value else "unknown error"
        raise RuntimeError(msg)
    return out.decode()


def eval_code_streaming(input_cx: str, program: str,
                            on_chunk, output_target: str = "") -> None:
    """Evaluate a CX program with pull-based incremental output.

    `on_chunk(data: bytes) -> None | int`: invoked with each output
    chunk. Return None or 0 to continue; any other int (or raising)
    aborts evaluation cleanly.

    Concatenating every chunk yields the same bytes that `eval_code`
    would return — per the §3.3 byte-equivalence contract.
    """
    pending_exc = []

    def _trampoline(buf, n, _user):
        try:
            data = ctypes.string_at(buf, n)
            rc = on_chunk(data)
            return 0 if rc in (None, 0) else int(rc)
        except BaseException as exc:        # pylint: disable=broad-except
            pending_exc.append(exc)
            return 1

    cb = _CX_PROGRAM_WRITE_CB(_trampoline)
    in_b = input_cx.encode() if input_cx else b""
    prog_b = program.encode()
    target_b = output_target.encode() if output_target else b""
    err = ctypes.c_char_p(None)
    _lib.cx_code_eval_streaming(
        in_b, len(in_b),
        prog_b, len(prog_b),
        target_b,
        cb,
        None,
        ctypes.byref(err),
    )
    if pending_exc:
        raise RuntimeError("cx_code_eval_streaming callback raised") from pending_exc[0]
    if err.value is not None:
        raise RuntimeError(err.value.decode())

def version() -> str: return _lib.cx_version().decode()
def abi_version() -> str: return _lib.cx_abi_version().decode()
def features() -> int:
    """Return the libcx capability bitmask as an int. See spec/abi.md §3."""
    s = _lib.cx_features().decode()
    return int(s, 16)


# ── Binary buffer helpers (framed [u32 LE size][payload]) ────────────────────

def _bytes_from_ptr(ptr) -> bytes | None:
    """Read a framed binary buffer from a c_void_p returned by libcx.
    Returns None if ptr is null."""
    if not ptr:
        return None
    addr = int(ptr)
    size = int.from_bytes(ctypes.string_at(addr, 4), 'little')
    return ctypes.string_at(addr, 4 + size)


def _call_bin(fn, text: str) -> bytes:
    """Call a function that returns framed binary; raise on error."""
    err = ctypes.c_char_p(None)
    raw = fn(text.encode(), ctypes.byref(err))
    out = _bytes_from_ptr(raw)
    if out is None:
        msg = err.value.decode() if err.value else "unknown error"
        raise RuntimeError(msg)
    _lib.cx_free(ctypes.c_char_p(raw))
    return out


def _call_bin_to_text(fn, framed: bytes) -> str:
    """Call a function that takes framed binary and returns text."""
    err = ctypes.c_char_p(None)
    out = fn(framed, ctypes.byref(err))
    if out is None:
        msg = err.value.decode() if err.value else "unknown error"
        raise RuntimeError(msg)
    return out.decode()


# ── data_bin entry points (Phase 2b.6) ───────────────────────────────────────

def to_data_bin(src: str) -> bytes:
    """Encode CX text to CXCol v1 framed bytes."""
    return _call_bin(_lib.cx_to_data_bin, src)

def from_data_bin(framed: bytes) -> str:
    """Decode CXCol v1 framed bytes to canonical CX text."""
    return _call_bin_to_text(_lib.cx_from_data_bin, framed)


# ── data_bin one-shot loaders/dumpers (Phase 7.28) ────────────────────────────
# Per spec/abi.md §2.4–§2.5. Each one-shot composes a per-format parser
# with emit_data_bin (loader) or parse_data_bin with a per-format
# emitter (dumper) without a CX-text intermediate, avoiding the
# string-roundtrip cost.

def xml_to_data_bin(src: str) -> bytes:
    """Encode XML text directly to CXCol v1 framed bytes."""
    return _call_bin(_lib.cx_xml_to_data_bin, src)

def json_to_data_bin(src: str) -> bytes:
    """Encode JSON text directly to CXCol v1 framed bytes."""
    return _call_bin(_lib.cx_json_to_data_bin, src)

def yaml_to_data_bin(src: str) -> bytes:
    """Encode YAML text directly to CXCol v1 framed bytes."""
    return _call_bin(_lib.cx_yaml_to_data_bin, src)

def toml_to_data_bin(src: str) -> bytes:
    """Encode TOML text directly to CXCol v1 framed bytes."""
    return _call_bin(_lib.cx_toml_to_data_bin, src)

def data_bin_to_xml(framed: bytes) -> str:
    """Decode CXCol v1 framed bytes directly to XML text."""
    return _call_bin_to_text(_lib.cx_data_bin_to_xml, framed)

def data_bin_to_json(framed: bytes) -> str:
    """Decode CXCol v1 framed bytes directly to JSON text."""
    return _call_bin_to_text(_lib.cx_data_bin_to_json, framed)

def data_bin_to_yaml(framed: bytes) -> str:
    """Decode CXCol v1 framed bytes directly to YAML text."""
    return _call_bin_to_text(_lib.cx_data_bin_to_yaml, framed)

def data_bin_to_toml(framed: bytes) -> str:
    """Decode CXCol v1 framed bytes directly to TOML text."""
    return _call_bin_to_text(_lib.cx_data_bin_to_toml, framed)

def to_events(cx_str: str) -> str:
    """Return all streaming events as a JSON array string."""
    return _call(_lib.cx_to_events, cx_str)


# ── Chunked-table one-shot (Phase 7.72; spec/abi.md §2.10) ───────────────────

def to_data_bin_chunked(src: str) -> bytes:
    """Encode a CX :table-bodied root element to CXCol chunked-table form
    (`0x63`, spec/core/data-bin.md §3.11). Default chunk policy: 2^20 rows per
    group with auto-zstd above 64 KiB body. Capability bit 21."""
    return _call_bin(_lib.cx_to_data_bin_chunked, src)


# ── Schema-driven encoding (Phase 7.73; spec/abi.md §2.12) ───────────────────
# ref_form: 0=hash-only, 1=inline, 2=hash+name. See spec/core/data-bin.md §3.13.1.

def _call_schema_driven_loader(fn, src: str, schema: str,
                               ref_form: int = 0, name_hint: str = '') -> bytes:
    err = ctypes.c_char_p(None)
    raw = fn(src.encode(), schema.encode(), ref_form, name_hint.encode(),
             ctypes.byref(err))
    out = _bytes_from_ptr(raw)
    if out is None:
        msg = err.value.decode() if err.value else 'unknown error'
        raise RuntimeError(msg)
    _lib.cx_free(ctypes.c_char_p(raw))
    return out

def to_data_bin_schema_driven(src: str, schema: str,
                              ref_form: int = 0, name_hint: str = '') -> bytes:
    return _call_schema_driven_loader(
        _lib.cx_to_data_bin_schema_driven, src, schema, ref_form, name_hint)
def xml_to_data_bin_schema_driven(src: str, schema: str,
                                  ref_form: int = 0, name_hint: str = '') -> bytes:
    return _call_schema_driven_loader(
        _lib.cx_xml_to_data_bin_schema_driven, src, schema, ref_form, name_hint)
def json_to_data_bin_schema_driven(src: str, schema: str,
                                   ref_form: int = 0, name_hint: str = '') -> bytes:
    return _call_schema_driven_loader(
        _lib.cx_json_to_data_bin_schema_driven, src, schema, ref_form, name_hint)
def yaml_to_data_bin_schema_driven(src: str, schema: str,
                                   ref_form: int = 0, name_hint: str = '') -> bytes:
    return _call_schema_driven_loader(
        _lib.cx_yaml_to_data_bin_schema_driven, src, schema, ref_form, name_hint)
def toml_to_data_bin_schema_driven(src: str, schema: str,
                                   ref_form: int = 0, name_hint: str = '') -> bytes:
    return _call_schema_driven_loader(
        _lib.cx_toml_to_data_bin_schema_driven, src, schema, ref_form, name_hint)
def csv_to_data_bin_schema_driven(src: str, schema: str,
                                  ref_form: int = 0, name_hint: str = '') -> bytes:
    return _call_schema_driven_loader(
        _lib.cx_csv_to_data_bin_schema_driven, src, schema, ref_form, name_hint)
def tsv_to_data_bin_schema_driven(src: str, schema: str,
                                  ref_form: int = 0, name_hint: str = '') -> bytes:
    return _call_schema_driven_loader(
        _lib.cx_tsv_to_data_bin_schema_driven, src, schema, ref_form, name_hint)
def psv_to_data_bin_schema_driven(src: str, schema: str,
                                  ref_form: int = 0, name_hint: str = '') -> bytes:
    return _call_schema_driven_loader(
        _lib.cx_psv_to_data_bin_schema_driven, src, schema, ref_form, name_hint)

def from_data_bin_schema_driven(framed: bytes, schema_hint: str = '') -> str:
    err = ctypes.c_char_p(None)
    out = _lib.cx_from_data_bin_schema_driven(framed, schema_hint.encode(),
                                              ctypes.byref(err))
    if out is None:
        msg = err.value.decode() if err.value else 'unknown error'
        raise RuntimeError(msg)
    return out.decode()


# ── Canonical-form tooling (Phase 6 / spec/abi.md §2.6) ──────────────────────

def fmt(cx_str: str) -> str:
    """Lossless canonical text CX. Preserves comments/anchors/etc.;
    normalizes presentation. Idempotent: fmt(fmt(x)) == fmt(x)."""
    return _call(_lib.cx_fmt, cx_str)

def canonical(cx_str: str) -> str:
    """Strict canonical text CX. Strips presentation (comments, etc.);
    output is byte-identical for any data-equivalent inputs."""
    return _call(_lib.cx_canonical, cx_str)

def hash(cx_str: str) -> str:
    """Tagged content address of the strict canonical bytes — I1 identity
    epoch form `sha2-256:<64 lowercase hex chars>` (the tag is part of the
    address)."""
    return _call(_lib.cx_hash, cx_str)

# cx_eq has a 2-input signature; use the dedicated DllImport entry.
_lib.cx_eq.restype  = ctypes.c_char_p
_lib.cx_eq.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]

def eq(a: str, b: str) -> bool:
    """True iff strict-canonical(a) == strict-canonical(b)."""
    err = ctypes.c_char_p(None)
    out = _lib.cx_eq(a.encode(), b.encode(), ctypes.byref(err))
    if out is None:
        msg = err.value.decode() if err.value else 'unknown error'
        raise RuntimeError(msg)
    return out.decode() == '1'

# cx_diff: 3-input signature (a, b, format).
_lib.cx_diff.restype  = ctypes.c_char_p
_lib.cx_diff.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]

def diff(a: str, b: str, format: str = 'unified') -> str:
    """Semantic diff between two CX inputs, walking the strict-canonical
    forms. format is 'unified', 'json', or 'summary'. Empty string
    means data-equivalent inputs.
    """
    err = ctypes.c_char_p(None)
    out = _lib.cx_diff(a.encode(), b.encode(), format.encode(), ctypes.byref(err))
    if out is None:
        msg = err.value.decode() if err.value else 'unknown error'
        raise RuntimeError(msg)
    return out.decode()

# cx_lint: 4-input signature (input, format, disabled, err).
_lib.cx_lint.restype  = ctypes.c_char_p
_lib.cx_lint.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]

def lint(input: str, format: str = 'text', disabled: str = '') -> str:
    """Style + correctness warnings. format is 'text', 'json', or
    'summary'. disabled is a comma-separated list of check IDs to
    suppress (empty string = run all). Empty result means no findings.
    """
    err = ctypes.c_char_p(None)
    out = _lib.cx_lint(input.encode(), format.encode(), disabled.encode(), ctypes.byref(err))
    if out is None:
        msg = err.value.decode() if err.value else 'unknown error'
        raise RuntimeError(msg)
    return out.decode()


# ── ID/IDREF C ABI (Phase 7.65) ───────────────────────────────────

_lib.cx_id_lookup.restype   = ctypes.c_char_p
_lib.cx_id_lookup.argtypes  = [ctypes.c_char_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_resolve_ref.restype = ctypes.c_char_p
_lib.cx_resolve_ref.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]
# cx_node_id was retired alongside cxpath.v at v0.7.6 (Phase 7). Equivalent
# behaviour: run a `//pattern` CXPath value (or `[?for [pattern $m] :yield $m]`)
# to locate the element, then read $m/@id from the result.


def id_lookup(input: str, id: str) -> str | None:
    """Find the element declaring `#id` in `input` and return its
    AST-JSON encoding. Returns None when no such ID exists.

    Stateless wrapper around cx_id_lookup; for repeated lookups against
    the same document, prefer Document.resolve_id() / elements_by_id()."""
    err = ctypes.c_char_p(None)
    out = _lib.cx_id_lookup(input.encode(), id.encode(), ctypes.byref(err))
    if out is None:
        msg = err.value.decode() if err.value else 'unknown error'
        raise RuntimeError(msg)
    s = out.decode()
    return s if s else None


def resolve_ref(input: str, ref: str) -> str | None:
    """Follow a bare `@ref` reference to its declaring element and
    return its AST-JSON encoding. Refs and IDs share a namespace, so
    this is observationally equivalent to id_lookup."""
    err = ctypes.c_char_p(None)
    out = _lib.cx_resolve_ref(input.encode(), ref.encode(), ctypes.byref(err))
    if out is None:
        msg = err.value.decode() if err.value else 'unknown error'
        raise RuntimeError(msg)
    s = out.decode()
    return s if s else None


# ── Delimited (CSV/TSV/PSV/arbitrary) C ABI (Phase 7.68) ──────────
# Per spec/conversions.md §8.
# cx_to_delimited / cx_from_delimited take a single-byte delimiter; the
# cx_to_csv / cx_to_tsv / cx_to_psv aliases hard-code `,` / `\t` / `|`.
# data_bin one-shots cover the three named-delimiter variants.

# Text-text (8): the two delim-bearing entry points + 6 aliases.
_lib.cx_to_delimited.restype    = ctypes.c_char_p
_lib.cx_to_delimited.argtypes   = [ctypes.c_char_p, ctypes.c_ubyte, ctypes.POINTER(ctypes.c_char_p)]
_lib.cx_from_delimited.restype  = ctypes.c_char_p
_lib.cx_from_delimited.argtypes = [ctypes.c_char_p, ctypes.c_ubyte, ctypes.POINTER(ctypes.c_char_p)]
for _name in ('cx_to_csv', 'cx_from_csv', 'cx_to_tsv', 'cx_from_tsv',
              'cx_to_psv', 'cx_from_psv'):
    _fn = getattr(_lib, _name)
    _fn.restype  = ctypes.c_char_p
    _fn.argtypes = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]

# Binary one-shots (6): csv/tsv/psv ↔ data_bin.
for _name in ('cx_csv_to_data_bin', 'cx_tsv_to_data_bin', 'cx_psv_to_data_bin'):
    _fn = getattr(_lib, _name)
    _fn.restype  = ctypes.c_void_p
    _fn.argtypes = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]
for _name in ('cx_data_bin_to_csv', 'cx_data_bin_to_tsv', 'cx_data_bin_to_psv'):
    _fn = getattr(_lib, _name)
    _fn.restype  = ctypes.c_char_p
    _fn.argtypes = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_char_p)]


def to_delimited(src: str, delim: str) -> str:
    """Encode CX text to delimited text using `delim` as the field
    separator (a single-character str). Valid
    delimiters are any byte except `\\r \\n " ' \\\\`."""
    if len(delim) != 1:
        raise ValueError('delim must be a single character')
    err = ctypes.c_char_p(None)
    out = _lib.cx_to_delimited(src.encode(), ord(delim), ctypes.byref(err))
    if out is None:
        msg = err.value.decode() if err.value else 'unknown error'
        raise RuntimeError(msg)
    return out.decode()


def from_delimited(src: str, delim: str) -> str:
    """Decode delimited text to canonical CX. Single-character `delim`
    selects the field separator. Auto-typing applies."""
    if len(delim) != 1:
        raise ValueError('delim must be a single character')
    err = ctypes.c_char_p(None)
    out = _lib.cx_from_delimited(src.encode(), ord(delim), ctypes.byref(err))
    if out is None:
        msg = err.value.decode() if err.value else 'unknown error'
        raise RuntimeError(msg)
    return out.decode()


def to_csv(src: str) -> str: return _call(_lib.cx_to_csv,  src)
def from_csv(src: str) -> str: return _call(_lib.cx_from_csv, src)
def to_tsv(src: str) -> str: return _call(_lib.cx_to_tsv,  src)
def from_tsv(src: str) -> str: return _call(_lib.cx_from_tsv, src)
def to_psv(src: str) -> str: return _call(_lib.cx_to_psv,  src)
def from_psv(src: str) -> str: return _call(_lib.cx_from_psv, src)


def csv_to_data_bin(src: str) -> bytes:
    """Encode CSV text directly to CXCol v1 framed bytes."""
    return _call_bin(_lib.cx_csv_to_data_bin, src)

def tsv_to_data_bin(src: str) -> bytes:
    """Encode TSV text directly to CXCol v1 framed bytes."""
    return _call_bin(_lib.cx_tsv_to_data_bin, src)

def psv_to_data_bin(src: str) -> bytes:
    """Encode PSV (pipe-separated) text directly to CXCol v1 framed bytes."""
    return _call_bin(_lib.cx_psv_to_data_bin, src)

def data_bin_to_csv(framed: bytes) -> str:
    """Decode CXCol v1 framed bytes directly to CSV text."""
    return _call_bin_to_text(_lib.cx_data_bin_to_csv, framed)

def data_bin_to_tsv(framed: bytes) -> str:
    """Decode CXCol v1 framed bytes directly to TSV text."""
    return _call_bin_to_text(_lib.cx_data_bin_to_tsv, framed)

def data_bin_to_psv(framed: bytes) -> str:
    """Decode CXCol v1 framed bytes directly to PSV text."""
    return _call_bin_to_text(_lib.cx_data_bin_to_psv, framed)


# ── CXPath path-tracking C ABI (RETIRED at v0.7.6, Phase 7) ───────────────
#
# select_all_paths thunked to the v0.7.0 cx_select_all_paths C symbol,
# which was removed alongside cxpath.v. Bindings that need element
# selection use `eval_code` with a CXPath `//path` value
# or a `[?for [pattern $m] :yield $m]` comprehension — see
# spec/code.md §5 + spec/audits/code_abi_v1.md.

# CX input
def to_cx        (src: str) -> str: return _call(_lib.cx_to_cx,          src)
def to_cx_compact(src: str) -> str: return _call(_lib.cx_to_cx_compact,  src)
def to_xml (src: str) -> str: return _call(_lib.cx_to_xml,  src)
def to_ast (src: str) -> str: return _call(_lib.cx_to_ast,  src)
def ast_to_cx    (src: str) -> str: return _call(_lib.cx_ast_to_cx,      src)
def to_json(src: str) -> str: return _call(_lib.cx_to_json, src)
def to_yaml(src: str) -> str: return _call(_lib.cx_to_yaml, src)
def to_toml(src: str) -> str: return _call(_lib.cx_to_toml, src)

# XML input
def xml_to_cx  (src: str) -> str: return _call(_lib.cx_xml_to_cx,   src)
def xml_to_xml (src: str) -> str: return _call(_lib.cx_xml_to_xml,  src)
def xml_to_ast (src: str) -> str: return _call(_lib.cx_xml_to_ast,  src)
def xml_to_json(src: str) -> str: return _call(_lib.cx_xml_to_json, src)
def xml_to_yaml(src: str) -> str: return _call(_lib.cx_xml_to_yaml, src)
def xml_to_toml(src: str) -> str: return _call(_lib.cx_xml_to_toml, src)

# JSON input
def json_to_cx  (src: str) -> str: return _call(_lib.cx_json_to_cx,   src)
def json_to_xml (src: str) -> str: return _call(_lib.cx_json_to_xml,  src)
def json_to_ast (src: str) -> str: return _call(_lib.cx_json_to_ast,  src)
def json_to_json(src: str) -> str: return _call(_lib.cx_json_to_json, src)
def json_to_yaml(src: str) -> str: return _call(_lib.cx_json_to_yaml, src)
def json_to_toml(src: str) -> str: return _call(_lib.cx_json_to_toml, src)

# YAML input
def yaml_to_cx  (src: str) -> str: return _call(_lib.cx_yaml_to_cx,   src)
def yaml_to_xml (src: str) -> str: return _call(_lib.cx_yaml_to_xml,  src)
def yaml_to_ast (src: str) -> str: return _call(_lib.cx_yaml_to_ast,  src)
def yaml_to_json(src: str) -> str: return _call(_lib.cx_yaml_to_json, src)
def yaml_to_yaml(src: str) -> str: return _call(_lib.cx_yaml_to_yaml, src)
def yaml_to_toml(src: str) -> str: return _call(_lib.cx_yaml_to_toml, src)

# TOML input
def toml_to_cx  (src: str) -> str: return _call(_lib.cx_toml_to_cx,   src)
def toml_to_xml (src: str) -> str: return _call(_lib.cx_toml_to_xml,  src)
def toml_to_ast (src: str) -> str: return _call(_lib.cx_toml_to_ast,  src)
def toml_to_json(src: str) -> str: return _call(_lib.cx_toml_to_json, src)
def toml_to_yaml(src: str) -> str: return _call(_lib.cx_toml_to_yaml, src)
def toml_to_toml(src: str) -> str: return _call(_lib.cx_toml_to_toml, src)
