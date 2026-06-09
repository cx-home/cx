"""
CX schema validator binding — `cx_validate` + `cx_validate_apply_defaults`.

Per spec/schema.md §10 + spec/abi.md §2.13. The C ABI returns
a framed binary diagnostics payload (spec/abi.md §2.13.2):

    [u32 LE total_size]
    [u32 LE diag_count]
    diagnostic* {
      [u32 LE line] [u32 LE col] [u32 LE error_code]
      [u8 severity]                # 0=info, 1=warn, 2=error
      [u32 LE message_len] [message_utf8]
    }

The wire format encodes only the numeric portion of the rule code; for
v0.6.0 the schema validator emits S001-S020, so this binding reconstructs
the public `code` string with an `S` prefix. When the data validator
lands and emits D-codes alongside, the wire format will gain a prefix
marker and this module will route on it.
"""
from __future__ import annotations
import ctypes
from dataclasses import dataclass, field
from enum import IntEnum
from typing import List, Optional, Tuple

from . import cx as _cx


class Severity(IntEnum):
    INFO = 0
    WARN = 1
    ERROR = 2


@dataclass(frozen=True)
class Diagnostic:
    """One validation finding. `code` is the spec rule id (e.g. 'S002')."""
    code: str
    severity: Severity
    message: str
    line: int = 0
    col: int = 0


@dataclass
class ValidationReport:
    diagnostics: List[Diagnostic] = field(default_factory=list)
    modified_doc: Optional[str] = None  # populated only by validate_with_defaults

    def is_valid(self) -> bool:
        return not any(d.severity == Severity.ERROR for d in self.diagnostics)

    def error_count(self) -> int:
        return sum(1 for d in self.diagnostics if d.severity == Severity.ERROR)

    def warn_count(self) -> int:
        return sum(1 for d in self.diagnostics if d.severity == Severity.WARN)

    def info_count(self) -> int:
        return sum(1 for d in self.diagnostics if d.severity == Severity.INFO)

    def codes(self) -> List[str]:
        return [d.code for d in self.diagnostics]

    def error_codes(self) -> List[str]:
        return [d.code for d in self.diagnostics if d.severity == Severity.ERROR]


def _format_code(prefix: int, numeric: int) -> str:
    # The prefix byte is the ASCII rule-code namespace ('S' = schema,
    # 'W' = streaming-write, 'D' = data validator). 0x00 means
    # "namespace unspecified" — render numeric only.
    # See spec/schema.md §10.2 / spec/abi.md §2.13.
    if prefix == 0:
        return f'{numeric:03d}'
    return f'{chr(prefix)}{numeric:03d}'


def _parse_payload(framed: bytes) -> List[Diagnostic]:
    """Parse a framed [u32 size][u32 count][diagnostic*] buffer."""
    # framed[0:4] = u32 size of the payload that follows
    size = int.from_bytes(framed[0:4], 'little')
    payload = framed[4:4 + size]
    if size < 4:
        return []
    count = int.from_bytes(payload[0:4], 'little')
    out: List[Diagnostic] = []
    off = 4
    for _ in range(count):
        line   = int.from_bytes(payload[off:off + 4], 'little');   off += 4
        col    = int.from_bytes(payload[off:off + 4], 'little');   off += 4
        prefix = payload[off];                                     off += 1
        code   = int.from_bytes(payload[off:off + 4], 'little');   off += 4
        sev    = payload[off];                                     off += 1
        mlen   = int.from_bytes(payload[off:off + 4], 'little');   off += 4
        msg    = payload[off:off + mlen].decode('utf-8');          off += mlen
        out.append(Diagnostic(
            code=_format_code(prefix, code),
            severity=Severity(sev),
            message=msg,
            line=line,
            col=col,
        ))
    return out


def _read_framed(addr: int) -> bytes:
    size = int.from_bytes(ctypes.string_at(addr, 4), 'little')
    return ctypes.string_at(addr, 4 + size)


def validate(doc: str, schema: str) -> ValidationReport:
    """Validate `doc` against `schema` (both CX text). Returns a
    ValidationReport with one Diagnostic per finding in document order.

    Raises RuntimeError on parse failure (malformed CX in either input).
    Schema-load errors (missing schema-of, unknown anchor, etc.) surface
    as a single error-severity Diagnostic, not as an exception."""
    err = ctypes.c_char_p(None)
    doc_b = doc.encode()
    schema_b = schema.encode()
    raw = _cx._lib.cx_validate_with_len(
        doc_b, len(doc_b), schema_b, len(schema_b), ctypes.byref(err)
    )
    if not raw:
        msg = err.value.decode() if err.value else 'unknown validate error'
        raise RuntimeError(msg)
    framed = _read_framed(int(raw))
    _cx._lib.cx_free(ctypes.c_char_p(raw))
    return ValidationReport(diagnostics=_parse_payload(framed))


def validate_with_defaults(doc: str, schema: str) -> ValidationReport:
    """Like validate(), but additionally returns the default-applied
    document via `report.modified_doc`. The modified doc is None when
    the schema declares no defaults."""
    err = ctypes.c_char_p(None)
    modified = ctypes.c_char_p(None)
    doc_b = doc.encode()
    schema_b = schema.encode()
    raw = _cx._lib.cx_validate_apply_defaults_with_len(
        doc_b, len(doc_b), schema_b, len(schema_b),
        ctypes.byref(modified), ctypes.byref(err),
    )
    if not raw:
        msg = err.value.decode() if err.value else 'unknown validate error'
        raise RuntimeError(msg)
    framed = _read_framed(int(raw))
    _cx._lib.cx_free(ctypes.c_char_p(raw))
    diags = _parse_payload(framed)
    mod_doc: Optional[str] = None
    if modified.value:
        mod_doc = modified.value.decode()
        _cx._lib.cx_free(modified)
    return ValidationReport(diagnostics=diags, modified_doc=mod_doc)
