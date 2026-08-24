package cxlib

// store.go — ergonomic client for the cx-store service tier.
//
// StoreClient is a thin façade over the audited store client in the CX core:
// each method builds a one-shot CX program and evaluates it through the
// capability-aware ABI (EvalCodeCaps) with only `net` granted (scoped to the
// server host). No wire protocol is re-implemented here — the core is the
// single source of protocol truth, so hashes and CXER error codes match every
// other binding by construction.
//
// The wire is the XSP store profile — THE CX-to-CX store wire (store.md §6.4):
// cx-store://host:port/name/ (TLS) or cx-store+xsp://host:port/name/
// (cleartext dev). Client identity is XSP-AUTH: pass did + seedEnv (the name
// of an environment variable holding the 32-byte Ed25519 seed hex — the seed
// itself never rides a URL or a literal). Anonymous under a floor-policy
// daemon needs neither.

import (
	"fmt"
	"regexp"
	"strings"
)

var (
	// I1 identity epoch: content addresses are TAGGED (`sha2-256:<64hex>`) —
	// the tag is part of the address, never stripped.
	storeHashRe    = regexp.MustCompile(`sha2-256:[0-9a-f]{64}`)
	storeErrCodeRe = regexp.MustCompile(`code="?([A-Za-z0-9:\-]+)"?`)
	storeErrMsgRe  = regexp.MustCompile(`message=(?:"([^"]*)"|'([^']*)')`)
	// the content address on each query tuple `[result doc=H source=…]` (the L97
	// flat relation — one tuple per MATCH, so Query dedups to per-doc hashes) /
	// iter `[entry hash=H …]` (bareword or quoted).
	storeResultHashRe = regexp.MustCompile(`\[result doc='?(sha2-256:[0-9a-f]{64})'?`)
	storeEntryHashRe  = regexp.MustCompile(`\[entry hash='?(sha2-256:[0-9a-f]{64})'?`)
)

// StoreClient is a connection-less client for one store-profile URL. Each op
// evaluates a one-shot program (open → op); the core client dials the profile
// session lazily per op, so a StoreClient holds no socket and is safe to
// reuse. Identity (did + seedEnv) maps onto the core's open-opts xsp-did /
// xsp-seed-env — the seed stays in the process environment, named but never
// read here.
type StoreClient struct {
	url     string
	did     string
	seedEnv string
	caps    string
}

// NewStoreClient constructs an anonymous client for a cx-store:// (TLS) or
// cx-store+xsp:// (cleartext dev) URL — the XSP store profile, THE store wire.
func NewStoreClient(url string) (*StoreClient, error) {
	return NewStoreClientWithIdentity(url, "", "")
}

// NewStoreClientWithIdentity constructs a client presenting an XSP-AUTH
// identity: `did` is the client's did:key, `seedEnv` names the environment
// variable holding its 32-byte Ed25519 seed hex.
func NewStoreClientWithIdentity(url, did, seedEnv string) (*StoreClient, error) {
	if !strings.HasPrefix(url, "cx-store://") &&
		!strings.HasPrefix(url, "cx-store+xsp://") {
		return nil, fmt.Errorf("StoreClient url must be a cx-store:// (TLS) or cx-store+xsp:// (cleartext dev) URL — the XSP store profile is THE store wire; got: %s", url)
	}
	if (did == "") != (seedEnv == "") {
		return nil, fmt.Errorf("client identity needs BOTH did and seedEnv (got one)")
	}
	hp, err := storeHostPort(url)
	if err != nil {
		return nil, err
	}
	return &StoreClient{url: url, did: did, seedEnv: seedEnv, caps: "net=" + hp}, nil
}

// PutDocText stores a document's canonical text and returns its content hash.
func (c *StoreClient) PutDocText(text string) (string, error) {
	out, err := c.run(fmt.Sprintf(`[$store:put-doc-text $c "%s"]`, cxEscape(text)), "text")
	if err != nil {
		return "", err
	}
	return storeUnwrap(out), nil
}

// GetDocText fetches a document's canonical text by hash (error if absent).
func (c *StoreClient) GetDocText(hash string) (string, error) {
	out, err := c.run(fmt.Sprintf(`[$store:get-doc-text $c "%s"]`, hash), "text")
	if err != nil {
		return "", err
	}
	if out == "()" { // the absence channel (empty sequence) — not stored
		return "", &CxError{
			Code:    "cx-err:CXER1721",
			Message: "E_CSRP_NOT_FOUND: no document for hash " + hash,
		}
	}
	return storeUnwrap(out), nil
}

// Exists reports whether a document with the given hash is present.
func (c *StoreClient) Exists(hash string) (bool, error) {
	out, err := c.run(fmt.Sprintf(`[$store:exists $c "%s"]`, hash), "text")
	if err != nil {
		return false, err
	}
	return strings.Trim(out, "'\"") == "true", nil
}

// DeleteDoc removes a document by hash; reports whether it was present.
func (c *StoreClient) DeleteDoc(hash string) (bool, error) {
	out, err := c.run(fmt.Sprintf(`[$store:delete-doc $c "%s"]`, hash), "text")
	if err != nil {
		return false, err
	}
	return strings.Trim(out, "'\"") == "true", nil
}

// ListDocs returns all document hashes in the store (order unspecified).
func (c *StoreClient) ListDocs() ([]string, error) {
	out, err := c.run(`[$store:list-docs $c]`, "cx")
	if err != nil {
		return nil, err
	}
	return storeHashRe.FindAllString(out, -1), nil
}

// Query runs a server-side CXPath query (§6.1): the evaluation is pushed down to
// the daemon (not a client-side scan), returning the content hashes of the
// documents that matched, in server order. A backend with no query surface
// returns a CxError(CXER1709) so the caller can fall back to list+get — never a
// silent empty result.
func (c *StoreClient) Query(cxpath string) ([]string, error) {
	out, err := c.run(fmt.Sprintf(`[$store:query $c "%s"]`, cxEscape(cxpath)), "cx")
	if err != nil {
		return nil, err
	}
	// L97 flat relation: one tuple per MATCH — dedup to the documented
	// per-document hash list (first-appearance order preserved).
	return storeUniqueHashes(storeSubmatchHashes(storeResultHashRe, out)), nil
}

// IterDocs enumerates every document via the daemon's server-side iter op
// (server-authoritative order), returning their content hashes. Distinct from
// ListDocs (which reads the catalog) — iter streams the doc entries. A backend
// with no iter surface returns a CxError(CXER1709).
func (c *StoreClient) IterDocs() ([]string, error) {
	out, err := c.run(`[$store:iter-docs $c]`, "cx")
	if err != nil {
		return nil, err
	}
	return storeSubmatchHashes(storeEntryHashRe, out), nil
}

// storeSubmatchHashes collects capture-group 1 of every match of `re` in `out`.
func storeSubmatchHashes(re *regexp.Regexp, out string) []string {
	ms := re.FindAllStringSubmatch(out, -1)
	hashes := make([]string, 0, len(ms))
	for _, m := range ms {
		hashes = append(hashes, m[1])
	}
	return hashes
}

// storeUniqueHashes dedups while preserving first-appearance order.
func storeUniqueHashes(in []string) []string {
	seen := make(map[string]bool, len(in))
	out := make([]string, 0, len(in))
	for _, h := range in {
		if !seen[h] {
			seen[h] = true
			out = append(out, h)
		}
	}
	return out
}

// ── internals ───────────────────────────────────────────────────────────────

func (c *StoreClient) run(opExpr, outputTarget string) (string, error) {
	open := fmt.Sprintf(`[$store:open "%s"]`, c.url)
	if c.did != "" {
		open = fmt.Sprintf(`[$store:open-opts "%s" [map xsp-did="%s" xsp-seed-env="%s"]]`,
			c.url, c.did, c.seedEnv)
	}
	prog := "[?lib 'cx-stdlib/store' :as store]\n" +
		fmt.Sprintf(`[?let [= $c %s] %s]`, open, opExpr)
	out, err := EvalCodeCaps("", prog, c.caps, outputTarget)
	if err != nil {
		return "", err
	}
	out = strings.TrimSpace(out)
	if strings.HasPrefix(out, "[err") {
		return "", storeToCxError(out)
	}
	return out, nil
}

func cxEscape(s string) string {
	return strings.ReplaceAll(strings.ReplaceAll(s, `\`, `\\`), `"`, `\"`)
}

func storeUnwrap(s string) string {
	if len(s) >= 2 && s[0] == s[len(s)-1] && (s[0] == '\'' || s[0] == '"') {
		return s[1 : len(s)-1]
	}
	return s
}

func storeHostPort(url string) (string, error) {
	rest := url[strings.Index(url, "://")+3:]
	authority := rest
	if i := strings.Index(authority, "/"); i >= 0 {
		authority = authority[:i]
	}
	if !strings.Contains(authority, ":") {
		// the profile needs the explicit [xsp] listener address; demand it here
		// so the net grant is always exact.
		return "", fmt.Errorf("StoreClient url needs an explicit host:port (the [xsp] listener address), got: %s", url)
	}
	return authority, nil
}

func storeToCxError(errText string) *CxError {
	code := "cx-err:CXER1707"
	if m := storeErrCodeRe.FindStringSubmatch(errText); m != nil {
		code = m[1]
	}
	message := errText
	if m := storeErrMsgRe.FindStringSubmatch(errText); m != nil {
		if m[1] != "" {
			message = m[1]
		} else {
			message = m[2]
		}
	}
	return &CxError{Code: code, Message: message}
}
