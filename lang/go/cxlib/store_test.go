package cxlib

// Phase 2 (#105) — Go CSRP client parity (StoreClient).
//
// BEHAVIORAL test: spawns a real `cx store-serve` daemon over loopback (a mem://
// store, auth open) and drives the full Layer-1 CRUD surface through StoreClient,
// proving the ergonomic wrapper drives the audited cx-store:// core client
// end-to-end (put → get → exists → list → delete → exists) — the same round trip
// the Python client (test_store_client.py) and vcx/tests/store_csrp_test.v cover.
//
// No Docker; the daemon is granted only loopback net. Skips when the cx binary
// is absent (run `make build-vcx`).

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func cxBinPath() string {
	wd, _ := os.Getwd() // lang/go/cxlib
	return filepath.Clean(filepath.Join(wd, "..", "..", "..", "vcx", "target", "cx"))
}

func freePort(t *testing.T) int {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("free port: %v", err)
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port
}

// spawnDaemon starts `cx store-serve` on a free loopback port and returns a ready
// client. It registers cleanup (kill + temp-config removal) on t.
func spawnDaemon(t *testing.T, storeURL string) *StoreClient {
	t.Helper()
	bin := cxBinPath()
	if _, err := os.Stat(bin); err != nil {
		t.Skipf("cx binary not found at %s — run `make build-vcx`", bin)
	}
	port := freePort(t)
	cfg := filepath.Join(t.TempDir(), "cxstore.service.cx")
	body := fmt.Sprintf("[cxstore-service\n  [bind addr=\"127.0.0.1:%d\"]\n  [stores\n    [store name=\"t\" url=\"%s\"]]]\n", port, storeURL)
	if err := os.WriteFile(cfg, []byte(body), 0o644); err != nil {
		t.Fatalf("write config: %v", err)
	}
	cmd := exec.Command(bin, "store-serve", "--config", cfg,
		fmt.Sprintf("--allow-net=127.0.0.1:%d", port))
	cmd.Stdout, cmd.Stderr = os.Stderr, os.Stderr
	if err := cmd.Start(); err != nil {
		t.Fatalf("start daemon: %v", err)
	}
	t.Cleanup(func() {
		_ = cmd.Process.Kill()
		_, _ = cmd.Process.Wait()
	})
	c, err := NewStoreClient(fmt.Sprintf("cx-store+http://127.0.0.1:%d/t/", port), "")
	if err != nil {
		t.Fatalf("new client: %v", err)
	}
	// wait-ready: poll ListDocs until the daemon answers.
	deadline := time.Now().Add(6 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := c.ListDocs(); err == nil {
			return c
		}
		time.Sleep(100 * time.Millisecond)
	}
	t.Fatal("daemon never became ready")
	return nil
}

func TestStoreClientRoundTrip(t *testing.T) {
	c := spawnDaemon(t, "mem://go-client")

	doc := `[note [body "go-client-roundtrip"]]`
	h, err := c.PutDocText(doc)
	if err != nil {
		t.Fatalf("put: %v", err)
	}
	if len(h) != 64 {
		t.Fatalf("put returned non-64-hex hash: %q", h)
	}

	got, err := c.GetDocText(h)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if !strings.Contains(got, "go-client-roundtrip") {
		t.Fatalf("doc body did not round-trip: %q", got)
	}

	if ok, err := c.Exists(h); err != nil || !ok {
		t.Fatalf("exists before delete: ok=%v err=%v", ok, err)
	}

	list, err := c.ListDocs()
	if err != nil || !storeSliceHas(list, h) {
		t.Fatalf("list_docs must include hash: %v err=%v", list, err)
	}

	// §6.1 query / iter — server-side pushdown, not a client-side scan.
	h2, err := c.PutDocText(`[note [title "q"] [body "second"]]`)
	if err != nil {
		t.Fatalf("put2: %v", err)
	}
	matched, err := c.Query("//title")
	if err != nil || !storeSliceHas(matched, h2) {
		t.Fatalf("query //title must match the titled doc server-side: %v err=%v", matched, err)
	}
	iterated, err := c.IterDocs()
	if err != nil || !storeSliceHas(iterated, h) || !storeSliceHas(iterated, h2) {
		t.Fatalf("iter_docs must enumerate both docs: %v err=%v", iterated, err)
	}
	_, _ = c.DeleteDoc(h2)

	if ok, err := c.DeleteDoc(h); err != nil || !ok {
		t.Fatalf("delete: ok=%v err=%v", ok, err)
	}
	if ok, err := c.Exists(h); err != nil || ok {
		t.Fatalf("exists after delete should be false: ok=%v err=%v", ok, err)
	}
}

func TestStoreClientMissingHashErrors(t *testing.T) {
	c := spawnDaemon(t, "mem://go-client-missing")
	missing := "0000000000000000000000000000000000000000000000000000000000000000"
	if _, err := c.GetDocText(missing); err == nil {
		t.Fatal("get of a missing hash must error, not return empty")
	}
}

// spawnAuthDaemon spawns an auth-ENFORCING daemon (one static bearer token →
// reader+writer on the "t" store) and returns its port. Used by the wrong-token
// parity case (§6.1).
func spawnAuthDaemon(t *testing.T, storeURL, goodToken string) int {
	t.Helper()
	bin := cxBinPath()
	if _, err := os.Stat(bin); err != nil {
		t.Skipf("cx binary not found at %s — run `make build-vcx`", bin)
	}
	port := freePort(t)
	sum := sha256.Sum256([]byte(goodToken))
	secretHash := hex.EncodeToString(sum[:])
	cfg := filepath.Join(t.TempDir(), "cxstore.auth.cx")
	body := fmt.Sprintf("[cxstore-service\n  [bind addr=\"127.0.0.1:%d\"]\n  [auth\n    [static\n      [token id=\"t1\" secret-hash=\"sha256:%s\" roles=\"reader writer\" tenant=\"t\"]]]\n  [stores\n    [store name=\"t\" url=\"%s\"]]]\n", port, secretHash, storeURL)
	if err := os.WriteFile(cfg, []byte(body), 0o644); err != nil {
		t.Fatalf("write auth config: %v", err)
	}
	cmd := exec.Command(bin, "store-serve", "--config", cfg,
		fmt.Sprintf("--allow-net=127.0.0.1:%d", port))
	cmd.Stdout, cmd.Stderr = os.Stderr, os.Stderr
	if err := cmd.Start(); err != nil {
		t.Fatalf("start auth daemon: %v", err)
	}
	t.Cleanup(func() {
		_ = cmd.Process.Kill()
		_, _ = cmd.Process.Wait()
	})
	// the RIGHT token confirms the daemon is up + auth works.
	good, err := NewStoreClient(fmt.Sprintf("cx-store+http://127.0.0.1:%d/t/", port), goodToken)
	if err != nil {
		t.Fatalf("new good client: %v", err)
	}
	deadline := time.Now().Add(6 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := good.ListDocs(); err == nil {
			return port
		}
		time.Sleep(100 * time.Millisecond)
	}
	t.Fatal("auth daemon never became ready with the good token")
	return 0
}

// TestStoreClientWrongTokenAuthError — §6.1 parity: a wrong bearer token must
// surface an auth CxError, not a silent success.
func TestStoreClientWrongTokenAuthError(t *testing.T) {
	port := spawnAuthDaemon(t, "mem://go-auth", "s3cr3t-good")
	bad, err := NewStoreClient(fmt.Sprintf("cx-store+http://127.0.0.1:%d/t/", port), "wrong-token")
	if err != nil {
		t.Fatalf("new bad client: %v", err)
	}
	_, err = bad.ListDocs()
	if err == nil {
		t.Fatal("a wrong token must raise an auth error, not succeed")
	}
	ce, ok := err.(*CxError)
	if !ok {
		t.Fatalf("expected a *CxError, got %T: %v", err, err)
	}
	if ce.Code != "cx-err:CXER1131" && ce.Code != "cx-err:CXER1702" {
		t.Fatalf("wrong token must map to an auth code, got %q", ce.Code)
	}
}

func storeSliceHas(xs []string, x string) bool {
	for _, v := range xs {
		if v == x {
			return true
		}
	}
	return false
}
