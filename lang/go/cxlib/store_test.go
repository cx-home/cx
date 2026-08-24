package cxlib

// Go store-client parity (StoreClient) over THE store wire.
//
// BEHAVIORAL test: spawns a real `cx store-serve` daemon over loopback (a
// mem:// store served over the XSP store profile, floor policy) and drives the
// full Layer-1 CRUD surface through StoreClient, proving the ergonomic wrapper
// drives the audited store client in the CX CORE end-to-end (put → get →
// exists → list → query → iter → delete → exists) — the same round trip the
// Python client (test_store_client.py) covers. Stream-4 S3 retired the CSRP
// transport — the wire here is cx-store+xsp:// and authority is XSP-AUTH
// (grants deny/admit lane included).
//
// No Docker; the daemon is granted only loopback net. Skips when the cx binary
// is absent (run `make build-vcx`).

import (
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// RFC 8032 TEST-vector identities (throwaway — never real keys).
const (
	goHostDID        = "did:key:z6MkiaMbhXHNA4eJVCCj8dbzKzTgYDKf6crKgHVHid1F1WCT"
	goHostSeedHex    = "4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb"
	goClientDID      = "did:key:z6MktwupdmLXVVqTzCw4i46r4uGyosGXRnR3XjN4Zq7oMMsw"
	goClientSeedHex  = "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
	goHostSeedEnv    = "CX_GO_STORE_TEST_SEED"
	goClientSeedEnv  = "CX_GO_STORE_CLIENT_SEED"
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

// spawnDaemon starts `cx store-serve` with the [xsp] profile listener and
// returns the xsp port. `policy` is the profile policy block; `grants` an
// optional [grants …] block.
func spawnDaemon(t *testing.T, storeURL, policy, grants string) int {
	t.Helper()
	bin := cxBinPath()
	if _, err := os.Stat(bin); err != nil {
		t.Skipf("cx binary not found at %s — run `make build-vcx`", bin)
	}
	bport := freePort(t)
	xport := freePort(t)
	cfg := filepath.Join(t.TempDir(), "cxstore.service.cx")
	body := fmt.Sprintf(
		"[cxstore-service\n  [bind addr=\"127.0.0.1:%d\"]\n  [stores\n    [store name=\"t\" url=\"%s\"]]\n  [xsp enabled=true addr=\"127.0.0.1:%d\"\n    [identity did=\"%s\" seed-env=\"%s\"]%s%s]]\n",
		bport, storeURL, xport, goHostDID, goHostSeedEnv, policy, grants)
	if err := os.WriteFile(cfg, []byte(body), 0o644); err != nil {
		t.Fatalf("write config: %v", err)
	}
	cmd := exec.Command(bin, "store-serve", "--config", cfg, "--allow-env",
		fmt.Sprintf("--allow-net=127.0.0.1:%d", bport),
		fmt.Sprintf("--allow-net=127.0.0.1:%d", xport))
	cmd.Env = append(os.Environ(), goHostSeedEnv+"="+goHostSeedHex)
	cmd.Stdout, cmd.Stderr = os.Stderr, os.Stderr
	if err := cmd.Start(); err != nil {
		t.Fatalf("start daemon: %v", err)
	}
	t.Cleanup(func() {
		_ = cmd.Process.Kill()
		_, _ = cmd.Process.Wait()
	})
	return xport
}

// waitReady polls ListDocs on the given client until the daemon answers.
func waitReady(t *testing.T, c *StoreClient) {
	t.Helper()
	deadline := time.Now().Add(8 * time.Second)
	var last error
	for time.Now().Before(deadline) {
		if _, err := c.ListDocs(); err == nil {
			return
		} else {
			last = err
		}
		time.Sleep(100 * time.Millisecond)
	}
	t.Fatalf("daemon never became ready: %v", last)
}

func TestStoreClientRoundTrip(t *testing.T) {
	xport := spawnDaemon(t, "mem://go-client", "\n    [policy mode=floor floor=\"guest\"]", "")
	c, err := NewStoreClient(fmt.Sprintf("cx-store+xsp://127.0.0.1:%d/t/", xport))
	if err != nil {
		t.Fatalf("new client: %v", err)
	}
	waitReady(t, c)

	doc := `[note [body "go-client-roundtrip"]]`
	h, err := c.PutDocText(doc)
	if err != nil {
		t.Fatalf("put: %v", err)
	}
	// I1: addresses are TAGGED — `sha2-256:` + 64 lowercase hex.
	const addrTag = "sha2-256:"
	if !strings.HasPrefix(h, addrTag) || len(h) != len(addrTag)+64 {
		t.Fatalf("put returned non-tagged address (want %s + 64 hex): %q", addrTag, h)
	}
	for _, ch := range h[len(addrTag):] {
		if !((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f')) {
			t.Fatalf("non-lowercase-hex char in address: %q", h)
		}
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
	xport := spawnDaemon(t, "mem://go-client-missing", "\n    [policy mode=floor floor=\"guest\"]", "")
	c, err := NewStoreClient(fmt.Sprintf("cx-store+xsp://127.0.0.1:%d/t/", xport))
	if err != nil {
		t.Fatalf("new client: %v", err)
	}
	waitReady(t, c)
	// I1 tagged-address form — a well-formed but absent address, so the
	// error exercises MISSING (not malformed-address rejection).
	missing := "sha2-256:0000000000000000000000000000000000000000000000000000000000000000"
	if _, err := c.GetDocText(missing); err == nil {
		t.Fatal("get of a missing hash must error, not return empty")
	}
}

// TestStoreClientRetiredSchemeRejected — stream-4 S3: the CSRP scheme tokens
// are retired; the façade refuses them with the pointer to the live wire.
func TestStoreClientRetiredSchemeRejected(t *testing.T) {
	if _, err := NewStoreClient("cx-store+http://127.0.0.1:1/t/"); err == nil {
		t.Fatal("the retired cx-store+http scheme must be refused")
	}
}

// TestStoreClientAuthority — XSP-AUTH parity: with [grants …] configured
// (mutual policy) an anonymous client is refused, and the granted DID
// (identity via open-opts did/seed-env) round-trips.
func TestStoreClientAuthority(t *testing.T) {
	grants := fmt.Sprintf("\n    [grants [grant did=%q caps=\"read write delete\"]]", goClientDID)
	xport := spawnDaemon(t, "mem://go-authz", "", grants)
	os.Setenv(goClientSeedEnv, goClientSeedHex)
	t.Cleanup(func() { os.Unsetenv(goClientSeedEnv) })
	good, err := NewStoreClientWithIdentity(
		fmt.Sprintf("cx-store+xsp://127.0.0.1:%d/t/", xport), goClientDID, goClientSeedEnv)
	if err != nil {
		t.Fatalf("new identity client: %v", err)
	}
	waitReady(t, good)
	h, err := good.PutDocText(`[note [body "authz-ok"]]`)
	if err != nil {
		t.Fatalf("granted put: %v", err)
	}
	if got, err := good.GetDocText(h); err != nil || !strings.Contains(got, "authz-ok") {
		t.Fatalf("granted get: %q err=%v", got, err)
	}
	// anonymous against the mutual daemon: refused, surfaced as *CxError.
	anon, err := NewStoreClient(fmt.Sprintf("cx-store+xsp://127.0.0.1:%d/t/", xport))
	if err != nil {
		t.Fatalf("new anon client: %v", err)
	}
	if _, err := anon.ListDocs(); err == nil {
		t.Fatal("an anonymous client against a mutual daemon must be refused")
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
