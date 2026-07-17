package cxlib

// store.go — ergonomic CSRP client for the cx-store service tier (#105).
//
// StoreClient is a thin façade over the audited cx-store:// client in the CX
// core: each method builds a one-shot CX program and evaluates it through the
// capability-aware ABI (EvalCodeCaps) with only `net` granted (scoped to the
// server host). The CSRP wire protocol is NOT re-implemented here — the core is
// the single source of protocol truth, so hashes and CXER error codes match
// every other binding by construction (spec §6.1).

import (
	"fmt"
	"regexp"
	"strings"
)

var (
	storeHashRe    = regexp.MustCompile(`[0-9a-f]{64}`)
	storeErrCodeRe = regexp.MustCompile(`code="?([A-Za-z0-9:\-]+)"?`)
	storeErrMsgRe  = regexp.MustCompile(`message=(?:"([^"]*)"|'([^']*)')`)
	// the content hash on each query `[result hash=H …]` / iter `[entry hash=H …]`
	// (bareword or quoted) — the matching / enumerated document's address.
	storeResultHashRe = regexp.MustCompile(`\[result hash='?([0-9a-f]{64})'?`)
	storeEntryHashRe  = regexp.MustCompile(`\[entry hash='?([0-9a-f]{64})'?`)
)

// StoreClient is a connection-less client for one cx-store:// URL. The remote
// backend is stateless per request (each op is one HTTP exchange carrying the
// URL + bearer), so a StoreClient holds no socket and is safe to reuse. The
// bearer token is carried only inside the open-URL and is never logged.
type StoreClient struct {
	url   string
	token string
	caps  string
}

// NewStoreClient constructs a client for a cx-store:// / cx-store+http(s):// URL.
// `token`, if non-empty, is the Bearer credential.
func NewStoreClient(url, token string) (*StoreClient, error) {
	if !strings.HasPrefix(url, "cx-store://") &&
		!strings.HasPrefix(url, "cx-store+http://") &&
		!strings.HasPrefix(url, "cx-store+https://") {
		return nil, fmt.Errorf("StoreClient url must be a cx-store:// URL, got: %s", url)
	}
	return &StoreClient{url: url, token: token, caps: "net:" + storeHostPort(url)}, nil
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
	return storeSubmatchHashes(storeResultHashRe, out), nil
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

// ── internals ───────────────────────────────────────────────────────────────

func (c *StoreClient) openURL() string {
	if c.token == "" {
		return c.url
	}
	i := strings.Index(c.url, "://") + 3
	return c.url[:i] + c.token + "@" + c.url[i:]
}

func (c *StoreClient) run(opExpr, outputTarget string) (string, error) {
	prog := "[?lib 'cx-stdlib/store' :as store]\n" +
		fmt.Sprintf(`[?let [= $c [$store:open "%s"]] %s]`, c.openURL(), opExpr)
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

func storeHostPort(url string) string {
	rest := url[strings.Index(url, "://")+3:]
	authority := rest
	if i := strings.Index(authority, "/"); i >= 0 {
		authority = authority[:i]
	}
	if i := strings.Index(authority, "@"); i >= 0 {
		authority = authority[i+1:]
	}
	if strings.Contains(authority, ":") {
		return authority
	}
	if strings.HasPrefix(url, "cx-store+http://") {
		return authority + ":80"
	}
	return authority + ":443"
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
