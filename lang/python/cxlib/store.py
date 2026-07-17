"""cxlib.store — ergonomic CSRP client for the cx-store service tier (#105).

A thin façade over the **audited cx-store:// client in the CX core**: each method
builds a one-shot CX program and evaluates it through the capability-aware ABI
(``cx_code_eval_caps``) with only ``net`` granted (deny-by-default for everything
else). The CSRP wire protocol is **not** re-implemented here — the core is the
single source of protocol truth, so hashes and CXER error codes match every other
binding by construction (spec/02-working/cxstore_service_tier_phase2.md §6.1).

    from cxlib import StoreClient
    c = StoreClient("cx-store+http://127.0.0.1:7800/mydocs/", token="…")
    h = c.put_doc_text('[note [body "hi"]]')
    assert c.exists(h)
    print(c.get_doc_text(h))
"""
from __future__ import annotations

import re
from typing import List, Optional

from .cx import eval_code_caps
from .code import CxError

_HASH_RE = re.compile(r"[0-9a-f]{64}")
# the content hash on each query `[result hash=H …]` / iter `[entry hash=H …]`
# (bareword or quoted) — the matching / enumerated document's address.
_RESULT_HASH_RE = re.compile(r"\[result hash='?([0-9a-f]{64})'?")
_ENTRY_HASH_RE = re.compile(r"\[entry hash='?([0-9a-f]{64})'?")
_ERR_CODE_RE = re.compile(r'code="?([A-Za-z0-9:\-]+)"?')
_ERR_MSG_RE = re.compile(r"message=(?:\"([^\"]*)\"|'([^']*)')")


def _cx_str(s: str) -> str:
    """Escape a Python string as the body of a CX double-quoted string literal."""
    return s.replace("\\", "\\\\").replace('"', '\\"')


def _unwrap(s: str) -> str:
    """Strip one layer of surrounding matching quotes from a rendered scalar."""
    if len(s) >= 2 and s[0] == s[-1] and s[0] in ("'", '"'):
        return s[1:-1]
    return s


class StoreClient:
    """A connection-less client for one ``cx-store://`` URL.

    The remote backend is stateless per request (each op is one HTTP exchange
    carrying the URL + bearer), so a single ``StoreClient`` is safe to reuse and
    holds no socket. The bearer token is carried only inside the open-URL and is
    never logged.
    """

    def __init__(self, url: str, token: Optional[str] = None) -> None:
        if not url.startswith(("cx-store://", "cx-store+http://", "cx-store+https://")):
            raise ValueError(
                "StoreClient url must be a cx-store://, cx-store+http:// or "
                "cx-store+https:// URL, got: " + url
            )
        self._url = url
        self._token = token
        self._caps = "net:" + _host_port(url)

    # ── public surface (spec §6.1) ───────────────────────────────────────────

    def put_doc_text(self, text: str) -> str:
        """Store a document's canonical text; return its content hash."""
        return _unwrap(self._run('[$store:put-doc-text $c "{}"]'.format(_cx_str(text))))

    def get_doc_text(self, doc_hash: str) -> str:
        """Fetch a document's canonical text by hash (raises CxError if absent)."""
        out = self._run('[$store:get-doc-text $c "{}"]'.format(doc_hash))
        if out == "()":  # the absence channel (empty sequence) — not stored
            raise CxError(
                "cx-err:CXER1721",
                "E_CSRP_NOT_FOUND: no document for hash " + doc_hash,
            )
        return _unwrap(out)

    def exists(self, doc_hash: str) -> bool:
        return self._run('[$store:exists $c "{}"]'.format(doc_hash)).strip("'\"") == "true"

    def delete_doc(self, doc_hash: str) -> bool:
        return self._run('[$store:delete-doc $c "{}"]'.format(doc_hash)).strip("'\"") == "true"

    def list_docs(self) -> List[str]:
        """Return all document hashes in the store (order unspecified)."""
        out = self._run("[$store:list-docs $c]", output_target="cx")
        return _HASH_RE.findall(out)

    def query(self, cxpath: str) -> List[str]:
        """Server-side CXPath query (§6.1): the evaluation is pushed down to the
        daemon (not a client-side scan), returning the content hashes of the
        documents that matched, in server order. A backend with no query surface
        raises CxError(CXER1709) so the caller can fall back to list+get — never a
        silent empty result."""
        out = self._run('[$store:query $c "{}"]'.format(_cx_str(cxpath)), output_target="cx")
        # query-result: ([result hash=H (matches)] …) — the hash= on each result is
        # the matching document's content address.
        return _RESULT_HASH_RE.findall(out)

    def iter_docs(self) -> List[str]:
        """Server-side iteration (§6.1): enumerate every document through the
        daemon's iter op (server-authoritative order), returning their content
        hashes. Distinct from list_docs (which reads the catalog) — iter streams
        the doc entries. A backend with no iter surface raises CxError(CXER1709)."""
        out = self._run("[$store:iter-docs $c]", output_target="cx")
        # iter-result: ([entry hash=H <doc>] …) — the hash= on each entry.
        return _ENTRY_HASH_RE.findall(out)

    # ── internals ────────────────────────────────────────────────────────────

    def _open_url(self) -> str:
        if not self._token:
            return self._url
        idx = self._url.find("://") + 3
        return self._url[:idx] + self._token + "@" + self._url[idx:]

    # The store namespace must be imported into each one-shot program; the
    # remote backend opens statelessly (URL parse only — the HTTP happens at the
    # op), so a fresh open per call is correct and cheap.
    _PROG = (
        "[?lib 'cx-stdlib/store' :as store]\n"
        '[?let [= $c [$store:open "{url}"]] {op}]'
    )

    def _run(self, op_expr: str, output_target: str = "text") -> str:
        prog = self._PROG.format(url=self._open_url(), op=op_expr)
        out = eval_code_caps("", prog, self._caps, output_target).strip()
        if out.startswith("[err"):
            raise _to_cx_error(out)
        return out


def _host_port(url: str) -> str:
    rest = url.split("://", 1)[1]
    if "@" in rest.split("/", 1)[0]:
        rest = rest.split("@", 1)[1]
    authority = rest.split("/", 1)[0]
    if ":" in authority:
        return authority
    # default ports per scheme
    default = "80" if url.startswith("cx-store+http://") else "443"
    return authority + ":" + default


def _to_cx_error(err_text: str) -> CxError:
    code_m = _ERR_CODE_RE.search(err_text)
    msg_m = _ERR_MSG_RE.search(err_text)
    code = code_m.group(1) if code_m else "cx-err:CXER1707"
    message = ""
    if msg_m:
        message = msg_m.group(1) if msg_m.group(1) is not None else msg_m.group(2)
    return CxError(code, message or err_text)
