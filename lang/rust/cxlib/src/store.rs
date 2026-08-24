//! Ergonomic client for the cx-store service tier.
//!
//! [`StoreClient`] is a thin façade over the audited store client in the CX
//! core: each method builds a one-shot CX program and evaluates it through the
//! capability-aware ABI ([`crate::eval_code_caps`]) with only `net` granted
//! (scoped to the server host). No wire protocol is re-implemented here — the
//! core is the single source of protocol truth, so hashes and CXER error codes
//! match every other binding by construction.
//!
//! The wire is the XSP store profile — THE CX-to-CX store wire (store.md
//! §6.4): `cx-store://host:port/name/` (TLS) or `cx-store+xsp://host:port/name/`
//! (cleartext dev). Client identity is XSP-AUTH: pass `did` + `seed_env` (the
//! name of an environment variable holding the 32-byte Ed25519 seed hex — the
//! seed itself never rides a URL or a literal). Anonymous under a floor-policy
//! daemon needs neither.
//!
//! ```no_run
//! use cxlib::store::StoreClient;
//! let c = StoreClient::new("cx-store+xsp://127.0.0.1:7800/mydocs/", None).unwrap();
//! let h = c.put_doc_text("[note [body \"hi\"]]").unwrap();
//! assert!(c.exists(&h).unwrap());
//! ```

use crate::eval_code_caps;

/// A structured CX error — the Rust peer of Python's `cxlib.code.CxError` and
/// Go's `cxlib.CxError` (#197). CSRP / store faults map onto this native type so
/// callers can branch on the stable `cx-err:CXERnnnn` `code` rather than parse a
/// formatted string. The error-code set is identical across all bindings.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CxError {
    /// The `cx-err:CXERnnnn` code (stable across bindings).
    pub code: String,
    /// Human-readable message (text may vary by build).
    pub message: String,
}

impl std::fmt::Display for CxError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}: {}", self.code, self.message)
    }
}

impl std::error::Error for CxError {}

/// A connection-less client for one `cx-store://` URL. The remote backend is
/// stateless per op (each op evaluates a one-shot program; the core client
/// dials the profile session lazily per op), so a `StoreClient` holds no
/// socket and is cheap to reuse. Identity maps onto the core's open-opts
/// `xsp-did` / `xsp-seed-env` — the seed stays in the process environment,
/// named but never read here.
pub struct StoreClient {
    url: String,
    identity: Option<(String, String)>, // (did, seed_env)
    caps: String,
}

impl StoreClient {
    /// Construct an anonymous client for a `cx-store://` (TLS) or
    /// `cx-store+xsp://` (cleartext dev) URL — the XSP store profile, THE
    /// store wire. `identity` is `Some((did, seed_env))` to present an
    /// XSP-AUTH identity: the client's did:key plus the NAME of the
    /// environment variable holding its 32-byte Ed25519 seed hex.
    pub fn new(url: &str, identity: Option<(&str, &str)>) -> Result<Self, String> {
        if !(url.starts_with("cx-store://") || url.starts_with("cx-store+xsp://")) {
            return Err(format!(
                "StoreClient url must be a cx-store:// (TLS) or cx-store+xsp:// (cleartext dev) URL — the XSP store profile is THE store wire; got: {url}"
            ));
        }
        Ok(StoreClient {
            url: url.to_owned(),
            identity: identity.map(|(d, e)| (d.to_owned(), e.to_owned())),
            caps: format!("net={}", host_port(url)?),
        })
    }

    /// Store a document's canonical text; return its content hash.
    pub fn put_doc_text(&self, text: &str) -> Result<String, CxError> {
        let out = self.run(&format!("[$store:put-doc-text $c \"{}\"]", cx_escape(text)), "text")?;
        Ok(unwrap_scalar(&out))
    }

    /// Fetch a document's canonical text by hash (error if absent).
    pub fn get_doc_text(&self, hash: &str) -> Result<String, CxError> {
        let out = self.run(&format!("[$store:get-doc-text $c \"{hash}\"]"), "text")?;
        if out == "()" {
            // the absence channel (empty sequence) — not stored
            return Err(CxError {
                code: "cx-err:CXER1721".to_owned(),
                message: format!("E_CSRP_NOT_FOUND: no document for hash {hash}"),
            });
        }
        Ok(unwrap_scalar(&out))
    }

    /// Report whether a document with the given hash is present.
    pub fn exists(&self, hash: &str) -> Result<bool, CxError> {
        let out = self.run(&format!("[$store:exists $c \"{hash}\"]"), "text")?;
        Ok(out.trim_matches(|c| c == '\'' || c == '"') == "true")
    }

    /// Remove a document by hash; report whether it was present.
    pub fn delete_doc(&self, hash: &str) -> Result<bool, CxError> {
        let out = self.run(&format!("[$store:delete-doc $c \"{hash}\"]"), "text")?;
        Ok(out.trim_matches(|c| c == '\'' || c == '"') == "true")
    }

    /// Return all document hashes in the store (order unspecified).
    pub fn list_docs(&self) -> Result<Vec<String>, CxError> {
        let out = self.run("[$store:list-docs $c]", "cx")?;
        Ok(find_hashes(&out))
    }

    /// Server-side CXPath query (§6.1): the evaluation is pushed down to the
    /// daemon (not a client-side scan), returning the content hashes of the
    /// documents that matched, in server order. A backend with no query surface
    /// returns `CxError(CXER1709)` so the caller can fall back to list+get — never
    /// a silent empty result.
    pub fn query(&self, cxpath: &str) -> Result<Vec<String>, CxError> {
        let out = self.run(&format!("[$store:query $c \"{}\"]", cx_escape(cxpath)), "cx")?;
        // L97 flat relation: one [result doc= source= MATCH] tuple per MATCH —
        // dedup to the documented per-document hash list (first-appearance
        // order preserved).
        let mut seen = std::collections::HashSet::new();
        Ok(find_marked_hashes(&out, "[result doc=")
            .into_iter()
            .filter(|h| seen.insert(h.clone()))
            .collect())
    }

    /// Server-side iteration (§6.1): enumerate every document through the
    /// daemon's iter op (server-authoritative order), returning their content
    /// hashes. Distinct from [`list_docs`] (which reads the catalog) — iter streams
    /// the doc entries. A backend with no iter surface returns `CxError(CXER1709)`.
    pub fn iter_docs(&self) -> Result<Vec<String>, CxError> {
        let out = self.run("[$store:iter-docs $c]", "cx")?;
        Ok(find_marked_hashes(&out, "[entry hash="))
    }

    fn run(&self, op_expr: &str, output_target: &str) -> Result<String, CxError> {
        let open = match &self.identity {
            None => format!("[$store:open \"{}\"]", self.url),
            Some((did, seed_env)) => format!(
                "[$store:open-opts \"{}\" [map xsp-did=\"{}\" xsp-seed-env=\"{}\"]]",
                self.url, did, seed_env
            ),
        };
        let prog = format!(
            "[?lib 'cx-stdlib/store' :as store]\n[?let [= $c {}] {}]",
            open, op_expr
        );
        // an ABI-level failure is also a cx-err string → map it onto CxError.
        let out = eval_code_caps("", &prog, &self.caps, output_target).map_err(|e| to_cx_error(&e))?;
        let out = out.trim();
        if out.starts_with("[err") {
            return Err(to_cx_error(out));
        }
        Ok(out.to_owned())
    }
}

fn cx_escape(s: &str) -> String {
    s.replace('\\', "\\\\").replace('"', "\\\"")
}

fn unwrap_scalar(s: &str) -> String {
    let b = s.as_bytes();
    if b.len() >= 2 && (b[0] == b'\'' || b[0] == b'"') && b[0] == b[b.len() - 1] {
        return s[1..s.len() - 1].to_owned();
    }
    s.to_owned()
}

fn host_port(url: &str) -> Result<String, String> {
    let rest = &url[url.find("://").map(|p| p + 3).unwrap_or(0)..];
    let authority = rest.split('/').next().unwrap_or("");
    if authority.contains(':') {
        return Ok(authority.to_owned());
    }
    // the profile needs the explicit [xsp] listener address; demand it here so
    // the net grant is always exact.
    Err(format!(
        "StoreClient url needs an explicit host:port (the [xsp] listener address), got: {url}"
    ))
}

/// I1 identity epoch: content addresses are TAGGED — `sha2-256:<64hex>`.
/// Bare 64-hex addresses no longer exist on the protocol (cutover, no
/// dual-accept); extractors return the full tagged form.
const ADDR_TAG: &str = "sha2-256:";

/// Extract all tagged content addresses from a rendered list value.
fn find_hashes(s: &str) -> Vec<String> {
    let bytes = s.as_bytes();
    let mut out = Vec::new();
    let mut from = 0usize;
    while let Some(rel) = s[from..].find(ADDR_TAG) {
        let start = from + rel;
        let i = start + ADDR_TAG.len();
        let run_end = (i..bytes.len()).find(|&j| !is_hex(bytes[j])).unwrap_or(bytes.len());
        if run_end - i == 64 {
            out.push(s[start..run_end].to_owned());
        }
        from = i;
    }
    out
}

fn is_hex(b: u8) -> bool {
    b.is_ascii_digit() || (b'a'..=b'f').contains(&b)
}

fn to_cx_error(err_text: &str) -> CxError {
    // [err code="cx-err:CXERnnnn" message="…"] → CxError{code, message}
    let code = extract(err_text, "code=").unwrap_or_else(|| "cx-err:CXER1707".to_owned());
    let message = extract(err_text, "message=").unwrap_or_else(|| err_text.to_owned());
    CxError { code, message }
}

/// Collect the tagged content address (`sha2-256:<64hex>`, I1) following
/// each `marker` (`[result doc=` — the L97 flat-relation tuple — / `[entry
/// hash=`) in a rendered query / iter value. The address may be bareword or
/// quoted; a single leading quote is skipped before the tagged run.
fn find_marked_hashes(s: &str, marker: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut from = 0usize;
    while let Some(rel) = s[from..].find(marker) {
        let mut i = from + rel + marker.len();
        let bytes = s.as_bytes();
        if i < bytes.len() && (bytes[i] == b'\'' || bytes[i] == b'"') {
            i += 1;
        }
        if s[i..].starts_with(ADDR_TAG) {
            let start = i;
            let j = i + ADDR_TAG.len();
            let run_end = (j..bytes.len()).find(|&k| !is_hex(bytes[k])).unwrap_or(bytes.len());
            if run_end - j == 64 {
                out.push(s[start..run_end].to_owned());
            }
        }
        from = i.max(from + rel + marker.len());
    }
    out
}

/// Pull a `key="value"` or `key='value'` attribute value out of an err element.
fn extract(s: &str, key: &str) -> Option<String> {
    let start = s.find(key)? + key.len();
    let rest = &s[start..];
    let bytes = rest.as_bytes();
    if bytes.is_empty() {
        return None;
    }
    let (quote, body) = if bytes[0] == b'"' || bytes[0] == b'\'' {
        (Some(bytes[0]), &rest[1..])
    } else {
        (None, rest)
    };
    let end = match quote {
        Some(q) => body.find(q as char)?,
        None => body.find(|c: char| c == ' ' || c == ']').unwrap_or(body.len()),
    };
    Some(body[..end].to_owned())
}
