"""cxlib.store — ergonomic client for the cx-store service tier.

A thin façade over the **audited store client in the CX core**: each method
builds a one-shot CX program and evaluates it through the capability-aware ABI
(``cx_code_eval_caps``) with only ``net`` granted (deny-by-default for everything
else). No wire protocol is re-implemented here — the core is the single source
of protocol truth, so hashes and CXER error codes match every other binding by
construction.

The wire is the XSP store profile — THE CX-to-CX store wire (store.md §6.4):
``cx-store://host:port/name/`` (TLS) or ``cx-store+xsp://host:port/name/``
(cleartext dev). Client identity is XSP-AUTH: pass ``did`` + ``seed_env`` (the
name of an environment variable holding the 32-byte Ed25519 seed hex — the
seed itself never rides a URL or a literal). Anonymous under a floor-policy
daemon needs neither.

    from cxlib import StoreClient
    c = StoreClient("cx-store+xsp://127.0.0.1:7800/mydocs/")
    h = c.put_doc_text('[note [body "hi"]]')
    assert c.exists(h)
    print(c.get_doc_text(h))
"""
from __future__ import annotations

import re
from typing import List, Optional

from .cx import eval_code_caps
from .code import CxError

# I1 identity epoch: content addresses are TAGGED (`sha2-256:<64hex>`) —
# the tag is part of the address, so the full tagged string is the handle
# every method accepts and returns.
_HASH_RE = re.compile(r"sha2-256:[0-9a-f]{64}")
# the content address on each query tuple `[result doc=H source=…]` (the L97
# flat relation — one tuple per MATCH, so query() dedups to per-doc hashes) /
# iter `[entry hash=H …]` (bareword or quoted).
_RESULT_HASH_RE = re.compile(r"\[result doc='?(sha2-256:[0-9a-f]{64})'?")
_ENTRY_HASH_RE = re.compile(r"\[entry hash='?(sha2-256:[0-9a-f]{64})'?")
_ERR_CODE_RE = re.compile(r'code="?([A-Za-z0-9:\-]+)"?')
_ERR_MSG_RE = re.compile(r"message=(?:\"([^\"]*)\"|'([^']*)')")

_LIVE_SCHEMES = ("cx-store://", "cx-store+xsp://")


def _cx_str(s: str) -> str:
    """Escape a Python string as the body of a CX double-quoted string literal."""
    return s.replace("\\", "\\\\").replace('"', '\\"')


def _unwrap(s: str) -> str:
    """Strip one layer of surrounding matching quotes from a rendered scalar."""
    if len(s) >= 2 and s[0] == s[-1] and s[0] in ("'", '"'):
        return s[1:-1]
    return s


class StoreClient:
    """A connection-less client for one store-profile URL.

    Each op evaluates a one-shot program (open → op); the core client dials the
    profile session lazily per op, so a ``StoreClient`` holds no socket and is
    safe to reuse. Identity (``did`` + ``seed_env``) maps onto the core's
    open-opts ``xsp-did`` / ``xsp-seed-env`` — the seed stays in the process
    environment, named but never read here.
    """

    def __init__(self, url: str, did: Optional[str] = None,
                 seed_env: Optional[str] = None) -> None:
        if not url.startswith(_LIVE_SCHEMES):
            raise ValueError(
                "StoreClient url must be a cx-store:// (TLS) or cx-store+xsp:// "
                "(cleartext dev) URL — the XSP store profile is THE store wire; "
                "got: " + url
            )
        if (did is None) != (seed_env is None):
            raise ValueError("client identity needs BOTH did and seed_env (got one)")
        self._url = url
        self._did = did
        self._seed_env = seed_env
        self._caps = "net=" + _host_port(url)

    # ── public surface (spec §6.1) ───────────────────────────────────────────

    def put_doc_text(self, text: str) -> str:
        """Store a document's canonical text; return its content address
        (tagged — `sha2-256:<64hex>`)."""
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
        # L97 flat relation: ([result doc=H source=… MATCH] …) — one tuple per
        # MATCH; dedup to the documented per-document hash list
        # (first-appearance order preserved).
        return list(dict.fromkeys(_RESULT_HASH_RE.findall(out)))

    def iter_docs(self) -> List[str]:
        """Server-side iteration (§6.1): enumerate every document through the
        daemon's iter op (server-authoritative order), returning their content
        hashes. Distinct from list_docs (which reads the catalog) — iter streams
        the doc entries. A backend with no iter surface raises CxError(CXER1709)."""
        out = self._run("[$store:iter-docs $c]", output_target="cx")
        # iter-result: ([entry hash=H <doc>] …) — the hash= on each entry.
        return _ENTRY_HASH_RE.findall(out)

    # ── internals ────────────────────────────────────────────────────────────

    # The store namespace must be imported into each one-shot program. With
    # identity, the open carries the core's own open-opts (xsp-did +
    # xsp-seed-env — validated by the core exactly as the CLI validates them).
    _PROG_ANON = (
        "[?lib 'cx-stdlib/store' :as store]\n"
        '[?let [= $c [$store:open "{url}"]] {op}]'
    )
    _PROG_IDENT = (
        "[?lib 'cx-stdlib/store' :as store]\n"
        '[?let [= $c [$store:open-opts "{url}" '
        '[map xsp-did="{did}" xsp-seed-env="{seed_env}"]]] {op}]'
    )

    def _run(self, op_expr: str, output_target: str = "text") -> str:
        if self._did is not None:
            prog = self._PROG_IDENT.format(
                url=self._url, did=self._did, seed_env=self._seed_env, op=op_expr
            )
        else:
            prog = self._PROG_ANON.format(url=self._url, op=op_expr)
        out = eval_code_caps("", prog, self._caps, output_target).strip()
        if out.startswith("[err"):
            raise _to_cx_error(out)
        return out


def _host_port(url: str) -> str:
    rest = url.split("://", 1)[1]
    authority = rest.split("/", 1)[0]
    if ":" not in authority:
        # the profile refuses a missing port at open ('[xsp] listener address');
        # fail here with the same demand so the caps grant is always exact.
        raise ValueError(
            "StoreClient url needs an explicit host:port (the [xsp] listener "
            "address), got: " + url
        )
    return authority


def _to_cx_error(err_text: str) -> CxError:
    code_m = _ERR_CODE_RE.search(err_text)
    msg_m = _ERR_MSG_RE.search(err_text)
    code = code_m.group(1) if code_m else "cx-err:CXER1707"
    message = ""
    if msg_m:
        message = msg_m.group(1) if msg_m.group(1) is not None else msg_m.group(2)
    return CxError(code, message or err_text)
