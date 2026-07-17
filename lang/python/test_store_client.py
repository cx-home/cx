"""Phase 2 (#105) — Python CSRP client parity (cxlib.StoreClient).

BEHAVIORAL test: spawns a real `cx store-serve` daemon over loopback (a mem://
store, auth open) and drives the full Layer-1 CRUD surface through
cxlib.StoreClient — proving the ergonomic wrapper drives the audited cx-store://
core client end-to-end (put → get → exists → list → delete → exists), the same
round trip vcx/tests/store_csrp_test.v exercises from a CX program.

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


def _free_port() -> int:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


class StoreClientTest(unittest.TestCase):
    def _spawn(self, store_url: str):
        if not os.path.isfile(_CX_BIN):
            self.skipTest("cx binary not found at %s — run `make build-vcx`" % _CX_BIN)
        port = _free_port()
        config = (
            '[cxstore-service\n'
            '  [bind addr="127.0.0.1:%d"]\n'
            '  [stores\n'
            '    [store name="teststore" url="%s"]]]\n' % (port, store_url)
        )
        cfg = tempfile.NamedTemporaryFile(
            mode="w", suffix=".cx", prefix="cx_store_cfg_", delete=False
        )
        cfg.write(config)
        cfg.close()
        proc = subprocess.Popen(
            [_CX_BIN, "store-serve", "--config", cfg.name,
             "--allow-net=127.0.0.1:%d" % port],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        self.addCleanup(self._kill, proc, cfg.name)
        client = StoreClient("cx-store+http://127.0.0.1:%d/teststore/" % port)
        self._wait_ready(client, proc)
        return client

    def _spawn_auth(self, store_url: str, good_token: str):
        """Spawn an auth-ENFORCING daemon (one static bearer token → reader+writer)
        and return (port). Used by the wrong-token parity case (§6.1)."""
        import hashlib
        if not os.path.isfile(_CX_BIN):
            self.skipTest("cx binary not found at %s — run `make build-vcx`" % _CX_BIN)
        port = _free_port()
        secret_hash = hashlib.sha256(good_token.encode()).hexdigest()
        config = (
            '[cxstore-service\n'
            '  [bind addr="127.0.0.1:%d"]\n'
            '  [auth\n'
            '    [static\n'
            '      [token id="t1" secret-hash="sha256:%s" roles="reader writer" tenant="teststore"]]]\n'
            '  [stores\n'
            '    [store name="teststore" url="%s"]]]\n' % (port, secret_hash, store_url)
        )
        cfg = tempfile.NamedTemporaryFile(
            mode="w", suffix=".cx", prefix="cx_store_authcfg_", delete=False
        )
        cfg.write(config)
        cfg.close()
        proc = subprocess.Popen(
            [_CX_BIN, "store-serve", "--config", cfg.name,
             "--allow-net=127.0.0.1:%d" % port],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        self.addCleanup(self._kill, proc, cfg.name)
        # a client with the RIGHT token confirms the daemon is up + auth works.
        good = StoreClient("cx-store+http://127.0.0.1:%d/teststore/" % port, token=good_token)
        self._wait_ready(good, proc)
        return port

    def _wait_ready(self, client: StoreClient, proc, timeout_s: float = 6.0) -> None:
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
        c = self._spawn("mem://py-client-test")
        doc = '[note [body "py-client-roundtrip"]]'
        h = c.put_doc_text(doc)
        self.assertTrue(h and len(h) == 64, "put returns 64-hex hash, got %r" % h)

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
        c = self._spawn("mem://py-client-missing")
        with self.assertRaises(CxError):
            c.get_doc_text("0" * 64)

    def test_wrong_token_auth_error(self):
        """§6.1 parity: a wrong bearer token → an auth CxError, not a silent
        success. Proves the binding surfaces the CSRP auth failure structurally."""
        port = self._spawn_auth("mem://py-auth", "s3cr3t-good")
        bad = StoreClient(
            "cx-store+http://127.0.0.1:%d/teststore/" % port, token="wrong-token"
        )
        with self.assertRaises(CxError) as ctx:
            bad.list_docs()
        # 401 (unauthenticated) maps to the store auth-failed code in the client.
        self.assertIn(
            ctx.exception.code,
            ("cx-err:CXER1131", "cx-err:CXER1702"),
            "wrong token must raise an auth error, got %r" % ctx.exception.code,
        )

    # NOTE: the former test_grpc_enabled_fails_fast was removed — the temporary
    # fail-fast guard it checked is gone now that the gRPC listener is
    # implemented. gRPC serving is covered by the V tests
    # (store_grpc_live_test.v / store_grpc_e2e_test.v / store_grpc_parity_test.v).


if __name__ == "__main__":
    unittest.main()
