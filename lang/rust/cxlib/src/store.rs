//! Ergonomic CSRP client for the cx-store service tier (#105).
//!
//! [`StoreClient`] is a thin façade over the audited `cx-store://` client in the
//! CX core: each method builds a one-shot CX program and evaluates it through the
//! capability-aware ABI ([`crate::eval_code_caps`]) with only `net` granted
//! (scoped to the server host). The CSRP wire protocol is **not** re-implemented
//! here — the core is the single source of protocol truth, so hashes and CXER
//! error codes match every other binding by construction (spec §6.1).
//!
//! ```no_run
//! use cxlib::store::StoreClient;
//! let c = StoreClient::new("cx-store+http://127.0.0.1:7800/mydocs/", None).unwrap();
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
/// stateless per request (each op is one HTTP exchange carrying the URL +
/// bearer), so a `StoreClient` holds no socket and is cheap to reuse. The bearer
/// token is carried only inside the open-URL and is never logged.
pub struct StoreClient {
    url: String,
    token: Option<String>,
    caps: String,
}

impl StoreClient {
    /// Construct a client for a `cx-store://` / `cx-store+http(s)://` URL.
    pub fn new(url: &str, token: Option<&str>) -> Result<Self, String> {
        if !(url.starts_with("cx-store://")
            || url.starts_with("cx-store+http://")
            || url.starts_with("cx-store+https://"))
        {
            return Err(format!("StoreClient url must be a cx-store:// URL, got: {url}"));
        }
        Ok(StoreClient {
            url: url.to_owned(),
            token: token.map(|t| t.to_owned()),
            caps: format!("net:{}", host_port(url)),
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
        Ok(find_marked_hashes(&out, "[result hash="))
    }

    /// Server-side iteration (§6.1): enumerate every document through the
    /// daemon's iter op (server-authoritative order), returning their content
    /// hashes. Distinct from [`list_docs`] (which reads the catalog) — iter streams
    /// the doc entries. A backend with no iter surface returns `CxError(CXER1709)`.
    pub fn iter_docs(&self) -> Result<Vec<String>, CxError> {
        let out = self.run("[$store:iter-docs $c]", "cx")?;
        Ok(find_marked_hashes(&out, "[entry hash="))
    }

    fn open_url(&self) -> String {
        match &self.token {
            None => self.url.clone(),
            Some(tok) => {
                let i = self.url.find("://").map(|p| p + 3).unwrap_or(0);
                format!("{}{}@{}", &self.url[..i], tok, &self.url[i..])
            }
        }
    }

    fn run(&self, op_expr: &str, output_target: &str) -> Result<String, CxError> {
        let prog = format!(
            "[?lib 'cx-stdlib/store' :as store]\n[?let [= $c [$store:open \"{}\"]] {}]",
            self.open_url(),
            op_expr
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

fn host_port(url: &str) -> String {
    let rest = &url[url.find("://").map(|p| p + 3).unwrap_or(0)..];
    let mut authority = rest.split('/').next().unwrap_or("");
    if let Some(at) = authority.find('@') {
        authority = &authority[at + 1..];
    }
    if authority.contains(':') {
        return authority.to_owned();
    }
    let default = if url.starts_with("cx-store+http://") { "80" } else { "443" };
    format!("{authority}:{default}")
}

/// Extract all 64-hex content hashes from a rendered list value.
fn find_hashes(s: &str) -> Vec<String> {
    let bytes = s.as_bytes();
    let mut out = Vec::new();
    let mut i = 0usize;
    while i + 64 <= bytes.len() {
        if is_hex(bytes[i]) {
            let run_end = (i..bytes.len()).find(|&j| !is_hex(bytes[j])).unwrap_or(bytes.len());
            if run_end - i == 64 {
                out.push(s[i..run_end].to_owned());
            }
            i = run_end;
        } else {
            i += 1;
        }
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

/// Collect the 64-hex content hash following each `marker` (`[result hash=` /
/// `[entry hash=`) in a rendered query / iter value. The hash may be bareword or
/// quoted; a single leading quote is skipped before the 64-hex run.
fn find_marked_hashes(s: &str, marker: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut from = 0usize;
    while let Some(rel) = s[from..].find(marker) {
        let mut i = from + rel + marker.len();
        let bytes = s.as_bytes();
        if i < bytes.len() && (bytes[i] == b'\'' || bytes[i] == b'"') {
            i += 1;
        }
        let run_end = (i..bytes.len()).find(|&j| !is_hex(bytes[j])).unwrap_or(bytes.len());
        if run_end - i == 64 {
            out.push(s[i..run_end].to_owned());
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
