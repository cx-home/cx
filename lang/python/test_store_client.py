"""Python store-client parity (cxlib.StoreClient) over THE store wire.

BEHAVIORAL test: spawns a real `cx store-serve` daemon over loopback (a mem://
store served over the XSP store profile, floor policy) and drives the full
Layer-1 CRUD surface through cxlib.StoreClient — proving the ergonomic wrapper
drives the audited store client in the CX CORE end-to-end (put → get → exists →
list → query → iter → delete → exists). No wire protocol is re-implemented in
Python; the façade generates CX programs and evaluates them through the
capability-aware ABI. Stream-4 S3 retired the CSRP transport — the wire here is
cx-store+xsp:// and authority is XSP-AUTH (grants deny lane included).

No Docker; the daemon is granted only loopback net. Skips cleanly when the cx
binary is absent (run `make build-vcx` first).
"""
from __future__ import annotations

import os
import socket
import subprocess
import tempfile
import time
import unittest

from cxlib import StoreClient
from cxlib.code import CxError

_REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
_CX_BIN = os.path.join(_REPO_ROOT, "vcx", "target", "cx")

# RFC 8032 TEST-vector identities (throwaway — never real keys).
_HOST_DID = "did:key:z6MkiaMbhXHNA4eJVCCj8dbzKzTgYDKf6crKgHVHid1F1WCT"
_HOST_SEED_HEX = "4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb"
_CLIENT_DID = "did:key:z6MktwupdmLXVVqTzCw4i46r4uGyosGXRnR3XjN4Zq7oMMsw"  # RFC 8032 TEST 1
_CLIENT_SEED_HEX = "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"


def _free_port() -> int:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


class StoreClientTest(unittest.TestCase):
    def _spawn(self, store_url: str, grants: str = "") -> int:
        """Spawn `cx store-serve` with the [xsp] profile listener; return its
        xsp port. `grants` is an optional [grants …] block (deny-by-default
        authority when present; floor/open posture when absent)."""
        if not os.path.isfile(_CX_BIN):
            self.skipTest("cx binary not found at %s — run `make build-vcx`" % _CX_BIN)
        bport = _free_port()
        xport = _free_port()
        config = (
            '[cxstore-service\n'
            '  [bind addr="127.0.0.1:%d"]\n'
            '  [stores\n'
            '    [store name="teststore" url="%s"]]\n'
            '  [xsp enabled=true addr="127.0.0.1:%d"\n'
            '    [identity did="%s" seed-env="CX_PY_STORE_TEST_SEED"]\n'
            '    [policy mode=floor floor="guest"]%s]]\n'
            % (bport, store_url, xport, _HOST_DID, grants)
        )
        cfg = tempfile.NamedTemporaryFile(
            mode="w", suffix=".cx", prefix="cx_store_cfg_", delete=False
        )
        cfg.write(config)
        cfg.close()
        env = dict(os.environ)
        env["CX_PY_STORE_TEST_SEED"] = _HOST_SEED_HEX
        env["CX_PY_STORE_CLIENT_SEED"] = _CLIENT_SEED_HEX
        proc = subprocess.Popen(
            [_CX_BIN, "store-serve", "--config", cfg.name, "--allow-env",
             "--allow-net=127.0.0.1:%d" % bport,
             "--allow-net=127.0.0.1:%d" % xport],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            env=env,
        )
        self.addCleanup(self._kill, proc, cfg.name)
        # the binding process needs the client seed visible under the name the
        # identity opts pass (read by the CORE, never by python).
        os.environ["CX_PY_STORE_CLIENT_SEED"] = _CLIENT_SEED_HEX
        probe = StoreClient("cx-store+xsp://127.0.0.1:%d/teststore/" % xport)
        self._wait_ready(probe, proc)
        return xport

    def _wait_ready(self, client: StoreClient, proc, timeout_s: float = 8.0) -> None:
        deadline = time.time() + timeout_s
        last = None
        while time.time() < deadline:
            if proc.poll() is not None:
                out = proc.stdout.read().decode(errors="replace") if proc.stdout else ""
                self.fail("daemon exited early (%s):\n%s" % (proc.returncode, out))
            try:
                client.list_docs()
                return
            except Exception as exc:  # noqa: BLE001 — refused while binding
                last = exc
                time.sleep(0.1)
        self.fail("daemon never became ready: %s" % last)

    @staticmethod
    def _kill(proc, cfg_path: str) -> None:
        try:
            proc.terminate()
            proc.wait(timeout=3)
        except Exception:  # noqa: BLE001
            proc.kill()
        try:
            os.unlink(cfg_path)
        except OSError:
            pass

    def test_full_round_trip(self):
        xport = self._spawn("mem://py-client-test")
        c = StoreClient("cx-store+xsp://127.0.0.1:%d/teststore/" % xport)
        doc = '[note [body "py-client-roundtrip"]]'
        h = c.put_doc_text(doc)
        # I1 identity epoch: content addresses are TAGGED — sha2-256:<64hex>.
        import re
        self.assertTrue(
            h and re.fullmatch(r"sha2-256:[0-9a-f]{64}", h),
            "put returns tagged sha2-256:<64hex> address, got %r" % h,
        )

        got = c.get_doc_text(h)
        self.assertIn("py-client-roundtrip", got, "doc body must round-trip: %r" % got)

        self.assertIs(c.exists(h), True, "exists true before delete")
        self.assertIn(h, c.list_docs(), "list_docs includes the stored hash")

        # §6.1 query / iter — server-side pushdown, not a client-side scan.
        h2 = c.put_doc_text('[note [title "q"] [body "second"]]')
        self.assertIn(h2, c.query("//title"), "query //title matches the titled doc server-side")
        iterated = c.iter_docs()
        self.assertIn(h, iterated, "iter_docs enumerates the first doc")
        self.assertIn(h2, iterated, "iter_docs enumerates the second doc")
        c.delete_doc(h2)

        self.assertIs(c.delete_doc(h), True, "delete reports success")
        self.assertIs(c.exists(h), False, "exists false after delete")

    def test_missing_hash_raises(self):
        xport = self._spawn("mem://py-client-missing")
        c = StoreClient("cx-store+xsp://127.0.0.1:%d/teststore/" % xport)
        with self.assertRaises(CxError):
            c.get_doc_text("sha2-256:" + "0" * 64)

    def test_retired_scheme_rejected(self):
        """Stream-4 S3: the CSRP scheme tokens are retired — the façade refuses
        them up front with the pointer to the live wire."""
        with self.assertRaises(ValueError):
            StoreClient("cx-store+http://127.0.0.1:1/teststore/")

    def test_grants_deny_anonymous_and_admit_granted_identity(self):
        """XSP-AUTH parity: with [grants …] configured the daemon is
        deny-by-default — an anonymous client is refused (mutual policy), and
        the granted DID (identity via open-opts did/seed-env) round-trips."""
        grants = (
            '\n    [grants [grant did="%s" caps="read write delete"]]' % _CLIENT_DID
        )
        # mutual policy: no floor — anonymous cannot even attach.
        if not os.path.isfile(_CX_BIN):
            self.skipTest("cx binary not found")
        bport = _free_port()
        xport = _free_port()
        config = (
            '[cxstore-service\n'
            '  [bind addr="127.0.0.1:%d"]\n'
            '  [stores [store name="teststore" url="mem://py-authz"]]\n'
            '  [xsp enabled=true addr="127.0.0.1:%d"\n'
            '    [identity did="%s" seed-env="CX_PY_STORE_TEST_SEED"]%s]]\n'
            % (bport, xport, _HOST_DID, grants)
        )
        cfg = tempfile.NamedTemporaryFile(
            mode="w", suffix=".cx", prefix="cx_store_authz_", delete=False
        )
        cfg.write(config)
        cfg.close()
        env = dict(os.environ)
        env["CX_PY_STORE_TEST_SEED"] = _HOST_SEED_HEX
        proc = subprocess.Popen(
            [_CX_BIN, "store-serve", "--config", cfg.name, "--allow-env",
             "--allow-net=127.0.0.1:%d" % bport,
             "--allow-net=127.0.0.1:%d" % xport],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env,
        )
        self.addCleanup(self._kill, proc, cfg.name)
        os.environ["CX_PY_STORE_CLIENT_SEED"] = _CLIENT_SEED_HEX
        good = StoreClient(
            "cx-store+xsp://127.0.0.1:%d/teststore/" % xport,
            did=_CLIENT_DID, seed_env="CX_PY_STORE_CLIENT_SEED",
        )
        self._wait_ready(good, proc)
        h = good.put_doc_text('[note [body "authz-ok"]]')
        self.assertIn("authz-ok", good.get_doc_text(h))
        # anonymous against the mutual daemon: refused, surfaced as CxError.
        anon = StoreClient("cx-store+xsp://127.0.0.1:%d/teststore/" % xport)
        with self.assertRaises(CxError):
            anon.list_docs()


if __name__ == "__main__":
    unittest.main()
