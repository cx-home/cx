//! CX native AST types — parse, emit, and query.

use serde_json::Value;

// ── Node types ────────────────────────────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct Attr {
    pub name: String,
    pub value: Value,
    pub data_type: Option<String>,
    /// v3.4: expanded-name fields populated by
    /// `resolve_namespaces`. `local` is the part after the first ':'
    /// in `name` (or the whole name); `ns_uri` is the resolved URI.
    /// Per XML Namespaces 1.0 §6.2 the default namespace does not
    /// apply to unprefixed attributes — `ns_uri` stays `None` for them.
    pub local: String,
    pub ns_uri: Option<String>,
    /// v3.4: true when the source attribute value was a
    /// bare `@id` reference token. Quoted strings starting with '@'
    /// have `is_ref = false`. Round-trip preserves the bare form.
    pub is_ref: bool,
    /// BracketBody attribute value — `name=[BodyItem*]`.
    /// When `Some`, `value` is unused and the attribute's content is
    /// the parsed body sequence. Used by code-evaluation directives
    /// like `[?if [cond, then-body, else-body]]`. Round-trips as
    /// opaque structure (R5).
    pub body: Option<Vec<Node>>,
}

#[derive(Debug, Clone)]
pub struct Element {
    pub name: String,
    pub anchor: Option<String>,
    pub merge: Option<String>,
    pub data_type: Option<String>,
    pub attrs: Vec<Attr>,
    pub items: Vec<Node>,
    /// v3.4: expanded-name fields. See `Attr`.
    pub local: String,
    pub ns_uri: Option<String>,
    /// v3.4: syntactic ID declaration ("#name" token).
    /// `None` when the element has no ID. Distinct from anchors.
    pub id: Option<String>,
    /// v3.4: body-position reference shape `[name @id]`.
    /// `Some("id")` when the element body is a bare `@id` reference,
    /// `None` for ordinary elements. Carried over the ast_bin wire
    /// format at v3+ (Phase 7.70 bumped 2 → 3).
    pub body_ref: Option<String>,
    /// v0.7.0 Z2 (spec/i18n.md §1.3): in-scope BCP 47 language tag.
    /// Populated by `resolve_namespaces`. `None` means no cx:lang in
    /// scope; `Some("")` is an explicit cx:lang="" shadow; otherwise
    /// the locally-declared or inherited tag. Use `Element::lang()`
    /// for the flattened common-case accessor.
    pub lang_resolved: Option<String>,
}

#[derive(Debug, Clone)]
pub enum Node {
    Element(Element),
    Text(String),
    Scalar { data_type: String, value: Value },
    Comment(String),
    RawText(String),
    EntityRef(String),
    Alias(String),
    PI { target: String, data: Option<String> },
    XMLDecl { version: String, encoding: Option<String>, standalone: Option<String> },
    /// `[?cx ...]` — directives may carry an `&anchor` and nested
    /// elements; used by the standalone-fragment form
    /// `[?cx frag &name [body :TYPE :flags]]` (spec/schema.md §8).
    CXDirective {
        attrs:  Vec<Attr>,
        anchor: Option<String>,
        items:  Vec<Node>,
    },
    DoctypeDecl { name: String, external_id: Option<Value>, int_subset: Vec<Value> },
    BlockContent(Vec<Node>),
    /// `[?=EXPR]`. EXPR is parsed as cxpath at
    /// evaluation time. ast_bin tag 0x0D.
    Interpolation { expr: String },
    /// `[?Name attrs body]`. Reserved EvalNames
    /// (if/for/with/cond/include/def/use/let/fn/match/try) parse into
    /// this variant; the evaluator dispatches on `name`. ast_bin
    /// tag 0x0E.
    EvalDirective { name: String, attrs: Vec<Attr>, items: Vec<Node> },
    /// v0.8.0 collection value-kinds (ast_bin §4.3). Surface forms per
    /// CXDM §1.2 / canonical.md: `(a, b, c)` flat sequence (tag 0x0F),
    /// `[a, b, c]` nested-preserving array (tag 0x10), `{k: v, …}` map
    /// (tag 0x11). Emitted by the V encoder (vcx/cx/binary.v).
    SequenceNode(Vec<Node>),
    ArrayNode(Vec<Node>),
    MapNode(Vec<MapEntry>),
}

/// One `k: v` entry of a [`Node::MapNode`]. Keys are carried as a scalar
/// type tag + canonical string per ast_bin §4.3.
#[derive(Debug, Clone)]
pub struct MapEntry {
    pub key_type: String,
    pub key_value: Value,
    pub value: Node,
}

#[derive(Debug, Clone)]
pub struct Document {
    pub elements: Vec<Node>,
    pub prolog: Vec<Node>,
}

// ── Attr methods ──────────────────────────────────────────────────────────────

impl Attr {
    /// Local part of the attribute name (after the first ':' in `name`,
    /// or the whole name if no colon is present).
    pub fn local_name(&self) -> &str { &self.local }

    /// Resolved namespace URI for prefixed attributes; `None` for
    /// unprefixed attributes (default ns does not apply per XML
    /// Namespaces 1.0 §6.2) and for unbound prefixes.
    pub fn namespace_uri(&self) -> Option<&str> { self.ns_uri.as_deref() }
}

// ── Element methods ───────────────────────────────────────────────────────────

impl Element {
    /// Create a new empty element with the given name.
    pub fn new(name: impl Into<String>) -> Self {
        Element {
            name: name.into(),
            anchor: None,
            merge: None,
            data_type: None,
            attrs: Vec::new(),
            items: Vec::new(),
            local: String::new(),
            ns_uri: None,
            id: None,
            body_ref: None,
            lang_resolved: None,
        }
    }

    /// BCP 47 language tag in scope at this Element per spec/i18n.md
    /// §1.3. Returns `""` when no cx:lang is in scope or when an
    /// ancestor's declaration was shadowed by an explicit `cx:lang=""`.
    pub fn lang(&self) -> &str {
        self.lang_resolved.as_deref().unwrap_or("")
    }

    /// Local part of the element name (after the first ':' in `name`,
    /// or the whole name if no colon is present). Populated by
    /// `resolve_namespaces` during parse.
    pub fn local_name(&self) -> &str { &self.local }

    /// Resolved namespace URI for this element; `None` when no binding
    /// is in scope and the prefix is not reserved. Populated by
    /// `resolve_namespaces` during parse.
    pub fn namespace_uri(&self) -> Option<&str> { self.ns_uri.as_deref() }

    /// Attribute value by name, or None.
    pub fn attr(&self, name: &str) -> Option<&Value> {
        self.attrs.iter().find(|a| a.name == name).map(|a| &a.value)
    }

    /// Concatenated Text and Scalar child content.
    pub fn text(&self) -> String {
        let parts: Vec<String> = self.items.iter().filter_map(|item| match item {
            Node::Text(s) => Some(s.clone()),
            Node::Scalar { value, .. } => Some(match value {
                Value::Null => "null".to_string(),
                _ => json_value_to_display(value),
            }),
            _ => None,
        }).collect();
        parts.join(" ")
    }

    /// Value of first Scalar child, or None.
    pub fn scalar(&self) -> Option<&Value> {
        self.items.iter().find_map(|item| {
            if let Node::Scalar { value, .. } = item { Some(value) } else { None }
        })
    }

    /// All child Elements (excludes Text, Scalar, and other nodes).
    pub fn children(&self) -> Vec<&Element> {
        self.items.iter().filter_map(|item| {
            if let Node::Element(e) = item { Some(e) } else { None }
        }).collect()
    }

    /// First child Element with this name.
    pub fn get(&self, name: &str) -> Option<&Element> {
        self.items.iter().find_map(|item| {
            if let Node::Element(e) = item {
                if e.name == name { Some(e) } else { None }
            } else {
                None
            }
        })
    }

    /// All child Elements with this name.
    pub fn get_all(&self, name: &str) -> Vec<&Element> {
        self.items.iter().filter_map(|item| {
            if let Node::Element(e) = item {
                if e.name == name { Some(e) } else { None }
            } else {
                None
            }
        }).collect()
    }

    /// All descendant Elements with this name (depth-first).
    pub fn find_all(&self, name: &str) -> Vec<&Element> {
        let mut result = Vec::new();
        for item in &self.items {
            if let Node::Element(e) = item {
                if e.name == name {
                    result.push(e);
                }
                result.extend(e.find_all(name));
            }
        }
        result
    }

    /// First descendant Element with this name (depth-first).
    pub fn find_first(&self, name: &str) -> Option<&Element> {
        for item in &self.items {
            if let Node::Element(e) = item {
                if e.name == name {
                    return Some(e);
                }
                if let Some(found) = e.find_first(name) {
                    return Some(found);
                }
            }
        }
        None
    }

    /// Navigate by slash-separated path: `el.at("server/host")`.
    pub fn at(&self, path: &str) -> Option<&Element> {
        let mut cur: Option<&Element> = Some(self);
        for part in path.split('/').filter(|p| !p.is_empty()) {
            cur = cur.and_then(|e| e.get(part));
        }
        cur
    }

    /// Set an attribute value, updating if it already exists.
    pub fn set_attr(&mut self, name: &str, value: Value, data_type: Option<String>) {
        if let Some(a) = self.attrs.iter_mut().find(|a| a.name == name) {
            a.value = value;
            a.data_type = data_type;
        } else {
            self.attrs.push(Attr {
                name: name.to_string(), value, data_type,
                local: String::new(), ns_uri: None, is_ref: false, body: None,
            });
        }
    }

    /// Remove an attribute by name.
    pub fn remove_attr(&mut self, name: &str) {
        self.attrs.retain(|a| a.name != name);
    }

    /// Append a child node.
    pub fn append(&mut self, node: Node) {
        self.items.push(node);
    }

    /// Prepend a child node.
    pub fn prepend(&mut self, node: Node) {
        self.items.insert(0, node);
    }

    /// Remove a child node by index.
    pub fn remove_child_at(&mut self, index: usize) {
        if index < self.items.len() {
            self.items.remove(index);
        }
    }

    /// Remove the first child Element with a given name.
    pub fn remove_named(&mut self, name: &str) {
        if let Some(pos) = self.items.iter().position(|item| {
            matches!(item, Node::Element(e) if e.name == name)
        }) {
            self.items.remove(pos);
        }
    }

    /// Remove all direct child Elements with the given name.
    pub fn remove_child(&mut self, name: &str) {
        self.items.retain(|item| {
            !matches!(item, Node::Element(e) if e.name == name)
        });
    }

    /// Remove child node at index (no-op if out of bounds). Alias for remove_child_at.
    pub fn remove_at(&mut self, index: usize) {
        self.remove_child_at(index);
    }

    // Element::select / Element::select_all were CXPath thunks retired
    // at v0.7.6 Phase 7. Equivalent: eval a `//pattern` CXPath value
    // via cxlib::eval_code. See vcx/README.md migration table.
}

// ── Document methods ──────────────────────────────────────────────────────────

impl Document {
    /// Create an empty document.
    pub fn new() -> Self {
        Document { elements: Vec::new(), prolog: Vec::new() }
    }

    /// First top-level Element.
    pub fn root(&self) -> Option<&Element> {
        self.elements.iter().find_map(|n| {
            if let Node::Element(e) = n { Some(e) } else { None }
        })
    }

    /// First top-level Element with this name.
    pub fn get(&self, name: &str) -> Option<&Element> {
        self.elements.iter().find_map(|n| {
            if let Node::Element(e) = n {
                if e.name == name { Some(e) } else { None }
            } else {
                None
            }
        })
    }

    /// Navigate by slash-separated path from root: `doc.at("article/body/p")`.
    pub fn at(&self, path: &str) -> Option<&Element> {
        let parts: Vec<&str> = path.split('/').filter(|p| !p.is_empty()).collect();
        if parts.is_empty() {
            return self.root();
        }
        let first = self.get(parts[0])?;
        if parts.len() == 1 {
            return Some(first);
        }
        first.at(&parts[1..].join("/"))
    }

    /// All descendant Elements with this name (depth-first through entire document).
    pub fn find_all(&self, name: &str) -> Vec<&Element> {
        let mut result = Vec::new();
        for node in &self.elements {
            if let Node::Element(e) = node {
                if e.name == name {
                    result.push(e);
                }
                result.extend(e.find_all(name));
            }
        }
        result
    }

    /// First descendant Element with this name (depth-first through entire document).
    pub fn find_first(&self, name: &str) -> Option<&Element> {
        for node in &self.elements {
            if let Node::Element(e) = node {
                if e.name == name {
                    return Some(e);
                }
                if let Some(found) = e.find_first(name) {
                    return Some(found);
                }
            }
        }
        None
    }

    /// Return the Element declaring `#id`, or `None`. v3.4.
    pub fn resolve_id(&self, id: &str) -> Option<&Element> {
        find_element_by_id(&self.elements, id).or_else(|| find_element_by_id(&self.prolog, id))
    }

    /// Return the Element targeted by `e.body_ref` in this document,
    /// or `None` when `body_ref` is unset or the target ID is
    /// undeclared. v0.7.0 (second bullet).
    pub fn resolve_body_ref(&self, e: &Element) -> Option<&Element> {
        e.body_ref.as_deref().and_then(|id| self.resolve_id(id))
    }

    /// Build a {id: &Element} map for the whole document. v3.4.
    pub fn elements_by_id(&self) -> std::collections::HashMap<String, &Element> {
        let mut out = std::collections::HashMap::new();
        collect_elements_by_id(&self.elements, &mut out);
        collect_elements_by_id(&self.prolog, &mut out);
        out
    }

    /// Append a top-level node.
    pub fn append(&mut self, node: Node) {
        self.elements.push(node);
    }

    /// Prepend a top-level node.
    pub fn prepend(&mut self, node: Node) {
        self.elements.insert(0, node);
    }

    /// Emit this document as a CX string (native emitter, no C library call).
    pub fn to_cx(&self) -> String {
        emit_doc(self)
    }

    /// Convert to XML via the CX library.
    /// Serialize this Document to a FRAMED [u32 LE size][payload]
    /// binary AST buffer. Used internally by `to_xml` / `to_json` /
    /// etc. (Phase 5 / CB-1) and exported for callers that want to
    /// pass the document directly to libcx without round-tripping
    /// through CX text.
    pub fn to_ast_bin(&self) -> Vec<u8> {
        crate::binary::encode_ast(self)
    }

    // v3.4 (Phase 5 / CB-1): format methods now go through
    // cx_ast_bin_to_<fmt>(self.to_ast_bin()) directly, avoiding the
    // prior emit-CX-and-reparse detour.

    /// Convert to XML via the CX library.
    pub fn to_xml(&self) -> Result<String, String> {
        crate::call_ast_bin_to_text(&self.to_ast_bin(), "cx_ast_bin_to_xml")
    }

    /// Convert to JSON via the CX library.
    pub fn to_json(&self) -> Result<String, String> {
        crate::call_ast_bin_to_text(&self.to_ast_bin(), "cx_ast_bin_to_json")
    }

    /// Convert to YAML via the CX library.
    pub fn to_yaml(&self) -> Result<String, String> {
        crate::call_ast_bin_to_text(&self.to_ast_bin(), "cx_ast_bin_to_yaml")
    }

    /// Convert to TOML via the CX library.
    pub fn to_toml(&self) -> Result<String, String> {
        crate::call_ast_bin_to_text(&self.to_ast_bin(), "cx_ast_bin_to_toml")
    }

    // Document::select / select_all / transform / transform_all were
    // CXPath thunks retired at v0.7.6 Phase 7. Equivalents (v0.8.0):
    //   selection      → cxlib::eval_code with a `//pattern` CXPath value
    //   transformation → cxlib::eval_code with
    //                    `[?for $m :in //pattern :yield (update $m ...)]`
    // See vcx/README.md migration table.
}

impl Default for Document {
    fn default() -> Self {
        Self::new()
    }
}

// ── JSON deserialization ──────────────────────────────────────────────────────

fn node_from_value(v: &Value) -> Node {
    let t = v["type"].as_str().unwrap_or("");
    match t {
        "Element" => Node::Element(element_from_value(v)),
        "Text" => Node::Text(v["value"].as_str().unwrap_or("").to_string()),
        "Scalar" => Node::Scalar {
            data_type: v["dataType"].as_str().unwrap_or("string").to_string(),
            value: v["value"].clone(),
        },
        "Comment" => Node::Comment(v["value"].as_str().unwrap_or("").to_string()),
        "RawText" => Node::RawText(v["value"].as_str().unwrap_or("").to_string()),
        "EntityRef" => Node::EntityRef(v["name"].as_str().unwrap_or("").to_string()),
        "Alias" => Node::Alias(v["name"].as_str().unwrap_or("").to_string()),
        "PI" => Node::PI {
            target: v["target"].as_str().unwrap_or("").to_string(),
            data: v["data"].as_str().map(|s| s.to_string()),
        },
        "XMLDecl" => Node::XMLDecl {
            version: v["version"].as_str().unwrap_or("1.0").to_string(),
            encoding: v["encoding"].as_str().map(|s| s.to_string()),
            standalone: v["standalone"].as_str().map(|s| s.to_string()),
        },
        "CXDirective" => {
            let attrs = v["attrs"].as_array()
                .map(|arr| arr.iter().map(attr_from_value).collect())
                .unwrap_or_default();
            // JSON form is the attrs-only shape (cx_to_json doesn't yet
            // surface anchor/items for directives); decoders that need
            // those fields read the binary AST instead.
            Node::CXDirective { attrs, anchor: None, items: Vec::new() }
        }
        "DoctypeDecl" => {
            let int_subset = v["intSubset"].as_array()
                .map(|arr| arr.iter().cloned().collect())
                .unwrap_or_default();
            let external_id = v.get("externalID")
                .filter(|v| !v.is_null())
                .cloned();
            Node::DoctypeDecl {
                name: v["name"].as_str().unwrap_or("").to_string(),
                external_id,
                int_subset,
            }
        }
        "BlockContent" => {
            let items = v["items"].as_array()
                .map(|arr| arr.iter().map(node_from_value).collect())
                .unwrap_or_default();
            Node::BlockContent(items)
        }
        _ => Node::Text(v.to_string()),
    }
}

fn attr_from_value(a: &Value) -> Attr {
    Attr {
        name: a["name"].as_str().unwrap_or("").to_string(),
        value: a["value"].clone(),
        data_type: a["dataType"].as_str().map(|s| s.to_string()),
        local: String::new(),
        ns_uri: None,
        is_ref: false,
        body: None,
    }
}

fn element_from_value(v: &Value) -> Element {
    let attrs = v["attrs"].as_array()
        .map(|arr| arr.iter().map(attr_from_value).collect())
        .unwrap_or_default();
    let items = v["items"].as_array()
        .map(|arr| arr.iter().map(node_from_value).collect())
        .unwrap_or_default();
    Element {
        name: v["name"].as_str().unwrap_or("").to_string(),
        anchor: v["anchor"].as_str().map(|s| s.to_string()),
        merge: v["merge"].as_str().map(|s| s.to_string()),
        data_type: v["dataType"].as_str().map(|s| s.to_string()),
        attrs,
        items,
        local: String::new(),
        ns_uri: None,
        id: None,
        body_ref: None,
        lang_resolved: None,
    }
}

fn doc_from_value(v: &Value) -> Document {
    let prolog = v["prolog"].as_array()
        .map(|arr| arr.iter().map(node_from_value).collect())
        .unwrap_or_default();
    let elements = v["elements"].as_array()
        .map(|arr| arr.iter().map(node_from_value).collect())
        .unwrap_or_default();
    Document { prolog, elements }
}

// ── Namespace resolution (spec/namespaces.md) ──────────────────────
//
// Mirrors V core's vcx/cx/namespaces.v. Walks a parsed Document,
// populating Element.{local, ns_uri} and Attr.{local, ns_uri} based on
// in-scope xmlns / xmlns: declarations. Called at the tail of every
// parse entry point so consumers see a uniform expanded-name view.
//
// Reserved prefixes:
//   - `xml`   → http://www.w3.org/XML/1998/namespace
//   - `cx`    → https://cx-home.org/ns/cx
//   - `xmlns` → declaration-only; never resolves as a name prefix

pub const XML_NAMESPACE_URI: &str = "http://www.w3.org/XML/1998/namespace";
pub const CX_NAMESPACE_URI:  &str = "https://cx-home.org/ns/cx";

fn split_ns_prefix(name: &str) -> (&str, &str) {
    match name.find(':') {
        Some(i) => (&name[..i], &name[i + 1..]),
        None    => ("", name),
    }
}

fn lookup_ns(prefix: &str, scope: &[std::collections::HashMap<String, String>]) -> Option<String> {
    match prefix {
        "xml"   => return Some(XML_NAMESPACE_URI.to_string()),
        "cx"    => return Some(CX_NAMESPACE_URI.to_string()),
        "xmlns" => return None,
        _ => {}
    }
    for frame in scope.iter().rev() {
        if let Some(uri) = frame.get(prefix) {
            if uri.is_empty() { return None; }
            return Some(uri.clone());
        }
    }
    None
}

fn attr_value_str(v: &Value) -> String {
    match v {
        Value::String(s) => s.clone(),
        Value::Null      => String::new(),
        other            => other.to_string(),
    }
}

fn resolve_element(e: &mut Element, scope: &mut Vec<std::collections::HashMap<String, String>>) {
    let mut frame = std::collections::HashMap::new();
    for a in &e.attrs {
        if a.name == "xmlns" {
            frame.insert(String::new(), attr_value_str(&a.value));
        } else if let Some(rest) = a.name.strip_prefix("xmlns:") {
            if !rest.is_empty() {
                frame.insert(rest.to_string(), attr_value_str(&a.value));
            }
        }
    }
    let pushed = !frame.is_empty();
    if pushed { scope.push(frame); }

    let (prefix, local) = split_ns_prefix(&e.name);
    e.local = local.to_string();
    e.ns_uri = lookup_ns(prefix, scope);

    for a in e.attrs.iter_mut() {
        let (ap, al) = split_ns_prefix(&a.name);
        a.local = al.to_string();
        if a.name == "xmlns" || ap == "xmlns" {
            a.ns_uri = None;
            continue;
        }
        if ap.is_empty() {
            // Default ns does not apply to unprefixed attrs.
            a.ns_uri = None;
            continue;
        }
        a.ns_uri = lookup_ns(ap, scope);
    }

    for item in e.items.iter_mut() {
        if let Node::Element(child) = item {
            resolve_element(child, scope);
        }
    }

    if pushed { scope.pop(); }
}

/// Populate `Element.{local, ns_uri}` and `Attr.{local, ns_uri}` on
/// every node in `doc` per spec/namespaces.md. Also
/// propagates cx:lang inherited scope per spec/i18n.md §1.3 — sets
/// `Element.lang_resolved` on every Element. Idempotent. Called
/// automatically by `parse`, `parse_xml`, `parse_json`, `parse_yaml`,
/// `parse_toml`.
pub fn resolve_namespaces(doc: &mut Document) {
    let mut scope: Vec<std::collections::HashMap<String, String>> = Vec::new();
    for n in doc.elements.iter_mut() {
        if let Node::Element(e) = n {
            resolve_element(e, &mut scope);
        }
    }
    let mut lang_stack: Vec<Option<String>> = Vec::new();
    for n in doc.elements.iter_mut() {
        if let Node::Element(e) = n {
            resolve_element_lang(e, &mut lang_stack);
        }
    }
}

/// Propagate cx:lang per spec/i18n.md §1.3. Mirrors V's
/// `vcx/cx/namespaces.v::resolve_element_lang`.
fn resolve_element_lang(e: &mut Element, stack: &mut Vec<Option<String>>) {
    let mut own_lang: Option<String> = None;
    let mut declared = false;
    for a in e.attrs.iter() {
        if a.name == "cx:lang" {
            own_lang = Some(match &a.value {
                Value::String(s) => s.clone(),
                Value::Null => String::new(),
                other => format!("{other:?}"),
            });
            declared = true;
            break;
        }
    }
    let resolved = if declared {
        own_lang
    } else {
        stack.last().cloned().unwrap_or(None)
    };
    e.lang_resolved = resolved.clone();
    stack.push(resolved);
    for item in e.items.iter_mut() {
        if let Node::Element(child) = item {
            resolve_element_lang(child, stack);
        }
    }
    stack.pop();
}

// ── Public parse/loads/dumps functions ────────────────────────────────────────

/// Parse a CX string into a Document (uses binary wire protocol).
pub fn parse(cx_str: &str) -> Result<Document, String> {
    let data = crate::call_bin(cx_str, "cx_to_ast_bin")?;
    decode_namespaces_and_lang(data)
}

/// parse_with_include_root opts into the spec/include.md §1-§8
/// resolver (v0.7.0 GG4). Empty include_root preserves directives in
/// the AST.
pub fn parse_with_include_root(cx_str: &str, include_root: &str) -> Result<Document, String> {
    let data = if include_root.is_empty() {
        crate::call_bin(cx_str, "cx_to_ast_bin")?
    } else {
        crate::call_bin_with_include_root(cx_str, include_root)?
    };
    decode_namespaces_and_lang(data)
}

fn decode_namespaces_and_lang(data: Vec<u8>) -> Result<Document, String> {
    let mut doc = crate::binary::decode_ast(&data)?;
    resolve_namespaces(&mut doc);
    Ok(doc)
}

// v3.4 (Phase 5 / CB-2): parse_<format> goes through
// cx_<format>_to_ast_bin directly, avoiding the prior cx_<fmt>_to_ast
// → JSON → walk-Value pipeline.

/// Parse an XML string into a Document.
pub fn parse_xml(xml_str: &str) -> Result<Document, String> {
    let data = crate::call_text_to_ast_bin(xml_str, "cx_xml_to_ast_bin")?;
    let mut doc = crate::binary::decode_ast(&data)?;
    resolve_namespaces(&mut doc);
    Ok(doc)
}

/// Parse a JSON string into a Document.
pub fn parse_json(json_str: &str) -> Result<Document, String> {
    let data = crate::call_text_to_ast_bin(json_str, "cx_json_to_ast_bin")?;
    let mut doc = crate::binary::decode_ast(&data)?;
    resolve_namespaces(&mut doc);
    Ok(doc)
}

/// Parse a YAML string into a Document.
pub fn parse_yaml(yaml_str: &str) -> Result<Document, String> {
    let data = crate::call_text_to_ast_bin(yaml_str, "cx_yaml_to_ast_bin")?;
    let mut doc = crate::binary::decode_ast(&data)?;
    resolve_namespaces(&mut doc);
    Ok(doc)
}

/// Parse a TOML string into a Document.
pub fn parse_toml(toml_str: &str) -> Result<Document, String> {
    let data = crate::call_text_to_ast_bin(toml_str, "cx_toml_to_ast_bin")?;
    let mut doc = crate::binary::decode_ast(&data)?;
    resolve_namespaces(&mut doc);
    Ok(doc)
}

/// Deserialize a CX string into a JSON Value (dict/list/scalar).
///
/// v3.4: parses through CXCol v1 (cx_to_data_bin) directly into a
/// serde_json::Value — no JSON-string detour. Type fidelity preserved
/// (int stays Number(i64), not coerced to f64). Closes audit finding
/// CB-3.
pub fn loads(cx_str: &str) -> Result<Value, String> {
    let payload = crate::data_bin::to_data_bin(cx_str)?;
    crate::data_bin::decode_payload(&payload)
}

/// Deserialize an XML string into a JSON Value.
pub fn loads_xml(xml_str: &str) -> Result<Value, String> {
    let json_str = crate::xml_to_json(xml_str)?;
    serde_json::from_str(&json_str).map_err(|e| e.to_string())
}

/// Deserialize a JSON string via the CX semantic bridge.
pub fn loads_json(json_str: &str) -> Result<Value, String> {
    let out = crate::json_to_json(json_str)?;
    serde_json::from_str(&out).map_err(|e| e.to_string())
}

/// Deserialize a YAML string into a JSON Value.
pub fn loads_yaml(yaml_str: &str) -> Result<Value, String> {
    let json_str = crate::yaml_to_json(yaml_str)?;
    serde_json::from_str(&json_str).map_err(|e| e.to_string())
}

/// Deserialize a TOML string into a JSON Value.
pub fn loads_toml(toml_str: &str) -> Result<Value, String> {
    let json_str = crate::toml_to_json(toml_str)?;
    serde_json::from_str(&json_str).map_err(|e| e.to_string())
}

/// Serialize a JSON Value into a CX string.
///
/// v3.4: encodes the Value as CXCol v1 bytes directly, then calls
/// cx_from_data_bin to produce canonical CX. No JSON-string detour.
/// Closes audit finding CB-3.
pub fn dumps(data: &Value) -> Result<String, String> {
    let framed = crate::data_bin::encode(data)?;
    crate::data_bin::from_data_bin(&framed)
}

// ── ID/IDREF helpers ───────────────────────────────────────────────

fn find_element_by_id<'a>(nodes: &'a [Node], id: &str) -> Option<&'a Element> {
    for n in nodes {
        if let Node::Element(e) = n {
            if e.id.as_deref() == Some(id) {
                return Some(e);
            }
            if let Some(found) = find_element_by_id(&e.items, id) {
                return Some(found);
            }
        }
    }
    None
}

fn collect_elements_by_id<'a>(
    nodes: &'a [Node],
    out: &mut std::collections::HashMap<String, &'a Element>,
) {
    for n in nodes {
        if let Node::Element(e) = n {
            if let Some(ref id) = e.id {
                out.insert(id.clone(), e);
            }
            collect_elements_by_id(&e.items, out);
        }
    }
}

// ── CX emitter helpers ────────────────────────────────────────────────────────

fn json_value_to_display(v: &Value) -> String {
    match v {
        Value::Null => "null".to_string(),
        Value::Bool(b) => if *b { "true".to_string() } else { "false".to_string() },
        Value::Number(n) => n.to_string(),
        Value::String(s) => s.clone(),
        _ => v.to_string(),
    }
}

/// Returns true if the string would be auto-typed by the CX parser (i.e. needs quoting).
fn would_autotype(s: &str) -> bool {
    if s.is_empty() || s.contains(' ') {
        return false;
    }
    // hex literal: 0x... or 0X...
    if s.len() > 2 {
        let bytes = s.as_bytes();
        if bytes[0] == b'0' && (bytes[1] == b'x' || bytes[1] == b'X') {
            if s[2..].chars().all(|c| c.is_ascii_hexdigit()) {
                return true;
            }
        }
    }
    // integer
    if s.parse::<i64>().is_ok() {
        return true;
    }
    // float — only if it contains '.' or 'e'/'E'
    let sl = s.to_ascii_lowercase();
    if sl.contains('.') || sl.contains('e') {
        if s.parse::<f64>().is_ok() {
            return true;
        }
    }
    // boolean / null keywords
    if matches!(s, "true" | "false" | "null") {
        return true;
    }
    // date: YYYY-MM-DD
    if is_date(s) {
        return true;
    }
    // datetime: YYYY-MM-DDTHH:MM:SS...
    if is_datetime(s) {
        return true;
    }
    false
}

fn is_date(s: &str) -> bool {
    // YYYY-MM-DD  (exactly 10 chars, pattern \d{4}-\d{2}-\d{2})
    if s.len() != 10 { return false; }
    let b = s.as_bytes();
    b[4] == b'-' && b[7] == b'-'
        && b[0..4].iter().all(|c| c.is_ascii_digit())
        && b[5..7].iter().all(|c| c.is_ascii_digit())
        && b[8..10].iter().all(|c| c.is_ascii_digit())
}

fn is_datetime(s: &str) -> bool {
    // YYYY-MM-DDTHH:MM:SS... (at least 19 chars)
    if s.len() < 19 { return false; }
    let b = s.as_bytes();
    b[4] == b'-' && b[7] == b'-' && (b[10] == b'T' || b[10] == b't')
        && b[13] == b':' && b[16] == b':'
        && b[0..4].iter().all(|c| c.is_ascii_digit())
        && b[5..7].iter().all(|c| c.is_ascii_digit())
        && b[8..10].iter().all(|c| c.is_ascii_digit())
        && b[11..13].iter().all(|c| c.is_ascii_digit())
        && b[14..16].iter().all(|c| c.is_ascii_digit())
        && b[17..19].iter().all(|c| c.is_ascii_digit())
}

fn cx_choose_quote(s: &str) -> String {
    if !s.contains('\'') {
        return format!("'{}'", s);
    }
    if !s.contains('"') {
        return format!("\"{}\"", s);
    }
    if !s.contains("'''") {
        return format!("'''{}'''", s);
    }
    format!("\"{}\"", s)
}

fn cx_quote_text(s: &str) -> String {
    let needs = s.starts_with(' ')
        || s.ends_with(' ')
        || s.contains("  ")
        || s.contains('\n')
        || s.contains('\t')
        || s.contains('[')
        || s.contains(']')
        || s.contains('&')
        || s.starts_with(':')
        || s.starts_with('\'')
        || s.starts_with('"')
        || would_autotype(s);
    if needs { cx_choose_quote(s) } else { s.to_string() }
}

fn cx_quote_attr(s: &str) -> String {
    if s.is_empty() || s.contains(' ') || s.contains('\'') || s.contains('"') {
        return format!("'{}'", s);
    }
    s.to_string()
}

fn emit_scalar_value(data_type: &str, value: &Value) -> String {
    // atoms render as `:NAME` regardless of source. The
    // data_type tag is the source of truth; the wire-level Value is
    // a plain serde_json::String holding the unprefixed name.
    if data_type == "atom" {
        if let Value::String(s) = value {
            return format!(":{}", s);
        }
        return format!(":{}", value);
    }
    match value {
        Value::Null => "null".to_string(),
        Value::Bool(b) => if *b { "true".to_string() } else { "false".to_string() },
        Value::Number(n) => {
            if data_type == "float" {
                let f = n.as_f64().unwrap_or(0.0);
                let s = format!("{}", f);
                if s.contains('.') || s.to_ascii_lowercase().contains('e') {
                    s
                } else {
                    format!("{}.0", s)
                }
            } else {
                n.to_string()
            }
        }
        Value::String(s) => s.clone(),
        _ => value.to_string(),
    }
}

fn emit_attr(a: &Attr) -> String {
    if a.is_ref {
        // bare `@id` round-trips verbatim.
        let id = json_value_to_display(&a.value);
        return format!("{}=@{}", a.name, id);
    }
    let dt = a.data_type.as_deref();
    match dt {
        Some("int") => {
            let n = match &a.value {
                Value::Number(n) => n.to_string(),
                Value::String(s) => s.clone(),
                _ => a.value.to_string(),
            };
            format!("{}={}", a.name, n)
        }
        Some("float") => {
            let f = match &a.value {
                Value::Number(n) => n.as_f64().unwrap_or(0.0),
                Value::String(s) => s.parse::<f64>().unwrap_or(0.0),
                _ => 0.0,
            };
            let s = format!("{}", f);
            let v = if s.contains('.') || s.to_ascii_lowercase().contains('e') { s } else { format!("{}.0", s) };
            format!("{}={}", a.name, v)
        }
        Some("bool") => {
            let b = matches!(&a.value, Value::Bool(true));
            format!("{}={}", a.name, if b { "true" } else { "false" })
        }
        Some("null") => format!("{}=null", a.name),
        Some("atom") => {
            // atom attribute renders as `name=:NAME` (no quoting).
            // The wire-level value is a serde_json::String with the unprefixed
            // name; reapply the colon at emit time.
            let s = match &a.value {
                Value::String(s) => s.clone(),
                _ => json_value_to_display(&a.value),
            };
            format!("{}=:{}", a.name, s)
        }
        _ => {
            // string attr — quote if would autotype OR starts with '@'
            // (else would mis-parse as is_ref reference).
            let s = json_value_to_display(&a.value);
            let v = if would_autotype(&s) || s.starts_with('@') {
                cx_choose_quote(&s)
            } else {
                cx_quote_attr(&s)
            };
            format!("{}={}", a.name, v)
        }
    }
}

// emit_collection renders the v0.8.0 collection value-kinds in their inline
// surface form: SequenceNode `(a, b, c)`, ArrayNode `[a, b, c]`, MapNode
// `{k: v, …}`. Returns "" for any other node.
fn emit_collection(node: &Node) -> String {
    match node {
        Node::SequenceNode(items) => {
            let parts: Vec<String> = items.iter().map(emit_inline).collect();
            format!("({})", parts.join(", "))
        }
        Node::ArrayNode(items) => {
            let parts: Vec<String> = items.iter().map(emit_inline).collect();
            format!("[{}]", parts.join(", "))
        }
        Node::MapNode(entries) => {
            let parts: Vec<String> = entries.iter()
                .map(|e| format!("{}: {}", emit_scalar_value(&e.key_type, &e.key_value), emit_inline(&e.value)))
                .collect();
            format!("{{{}}}", parts.join(", "))
        }
        _ => String::new(),
    }
}

fn emit_inline(node: &Node) -> String {
    match node {
        Node::Text(s) => {
            if s.trim().is_empty() { String::new() } else { cx_quote_text(s) }
        }
        Node::Scalar { data_type, value } => emit_scalar_value(data_type, value),
        Node::EntityRef(name) => format!("&{};", name),
        Node::RawText(s) => format!("[#{}#]", s),
        Node::SequenceNode(_) | Node::ArrayNode(_) | Node::MapNode(_) => emit_collection(node),
        Node::Element(e) => {
            let emitted = emit_element(e, 0);
            emitted.trim_end_matches('\n').to_string()
        }
        Node::BlockContent(items) => {
            let inner: String = items.iter().map(|n| match n {
                Node::Text(s) => s.clone(),
                Node::Element(e) => emit_element(e, 0).trim_end_matches('\n').to_string(),
                _ => emit_inline(n),
            }).collect();
            format!("[|{}|]", inner)
        }
        _ => String::new(),
    }
}

fn emit_element(e: &Element, depth: usize) -> String {
    let ind = "  ".repeat(depth);
    // body-position `[name @id]` shape — emit before
    // computing meta/items so a bare `@id` body round-trips verbatim.
    if let Some(ref br) = e.body_ref {
        return format!("{}[{} @{}]\n", ind, e.name, br);
    }
    let has_child_elems = e.items.iter().any(|i| matches!(i, Node::Element(_)));
    let has_text = e.items.iter().any(|i| matches!(i,
        Node::Text(_) | Node::Scalar { .. } | Node::EntityRef(_) | Node::RawText(_)
    ));
    let is_multiline = has_child_elems && !has_text;

    let mut meta_parts: Vec<String> = Vec::new();
    if let Some(ref anchor) = e.anchor {
        meta_parts.push(format!("&{}", anchor));
    }
    if let Some(ref merge) = e.merge {
        meta_parts.push(format!("*{}", merge));
    }
    if let Some(ref id) = e.id {
        meta_parts.push(format!("#{}", id));
    }
    if let Some(ref dt) = e.data_type {
        meta_parts.push(format!(":{}", dt));
    }
    for a in &e.attrs {
        meta_parts.push(emit_attr(a));
    }
    let meta = if meta_parts.is_empty() {
        String::new()
    } else {
        format!(" {}", meta_parts.join(" "))
    };

    if is_multiline {
        let mut out = format!("{}[{}{}\n", ind, e.name, meta);
        for item in &e.items {
            out.push_str(&emit_node(item, depth + 1));
        }
        out.push_str(&format!("{}]\n", ind));
        return out;
    }

    if e.items.is_empty() && meta.is_empty() {
        return format!("{}[{}]\n", ind, e.name);
    }

    let body_parts: Vec<String> = e.items.iter()
        .map(emit_inline)
        .filter(|s| !s.is_empty())
        .collect();
    let body = body_parts.join(" ");
    let sep = if body.is_empty() { "" } else { " " };
    format!("{}[{}{}{}{}]\n", ind, e.name, meta, sep, body)
}

fn emit_node(node: &Node, depth: usize) -> String {
    let ind = "  ".repeat(depth);
    match node {
        Node::Element(e) => emit_element(e, depth),
        Node::Text(s) => cx_quote_text(s),
        Node::Scalar { data_type, value } => emit_scalar_value(data_type, value),
        Node::Comment(s) => format!("{}[;{}]\n", ind, s),
        Node::RawText(s) => format!("{}[#{}#]\n", ind, s),
        Node::EntityRef(name) => format!("&{};", name),
        Node::Alias(name) => format!("{}[*{}]\n", ind, name),
        Node::BlockContent(items) => {
            let inner: String = items.iter().map(|n| emit_node(n, 0)).collect();
            format!("{}[|{}|]\n", ind, inner)
        }
        Node::PI { target, data } => {
            let d = data.as_ref().map(|s| format!(" {}", s)).unwrap_or_default();
            format!("{}[?{}{}]\n", ind, target, d)
        }
        Node::XMLDecl { version, encoding, standalone } => {
            let mut parts = vec![format!("version={}", version)];
            if let Some(enc) = encoding {
                parts.push(format!("encoding={}", enc));
            }
            if let Some(sa) = standalone {
                parts.push(format!("standalone={}", sa));
            }
            format!("[?xml {}]\n", parts.join(" "))
        }
        Node::CXDirective { attrs, .. } => {
            let attrs_str = attrs.iter().map(|a| {
                let v = match &a.value {
                    Value::String(s) => cx_quote_attr(s),
                    _ => a.value.to_string(),
                };
                format!("{}={}", a.name, v)
            }).collect::<Vec<_>>().join(" ");
            format!("[?cx {}]\n", attrs_str)
        }
        Node::Interpolation { expr } => {
            // v3.5 [58] — `[?=EXPR]`. EXPR is opaque text.
            format!("{}[?={}]\n", ind, expr)
        }
        Node::SequenceNode(_) | Node::ArrayNode(_) | Node::MapNode(_) => {
            format!("{}{}\n", ind, emit_collection(node))
        }
        Node::EvalDirective { name, attrs, items } => {
            // v3.5 [59] — `[?Name attrs body]`. Grammar-order
            // canonical emission: attrs first, then body items.
            let attrs_str = attrs.iter().map(|a| {
                let v = match &a.value {
                    Value::String(s) => cx_quote_attr(s),
                    _ => a.value.to_string(),
                };
                format!("{}={}", a.name, v)
            }).collect::<Vec<_>>().join(" ");
            let body_str: String = items.iter().map(|n| emit_node(n, 0)).collect();
            let sep_a = if attrs_str.is_empty() { "" } else { " " };
            let sep_b = if body_str.is_empty() { "" } else { " " };
            format!("{}[?{}{}{}{}{}]\n", ind, name, sep_a, attrs_str, sep_b, body_str.trim_end())
        }
        Node::DoctypeDecl { name, external_id, .. } => {
            let ext = match external_id {
                Some(Value::Object(map)) => {
                    if let Some(Value::String(pub_id)) = map.get("public") {
                        let sys = map.get("system")
                            .and_then(|v| v.as_str())
                            .unwrap_or("");
                        format!(" PUBLIC '{}' '{}'", pub_id, sys)
                    } else if let Some(Value::String(sys)) = map.get("system") {
                        format!(" SYSTEM '{}'", sys)
                    } else {
                        String::new()
                    }
                }
                _ => String::new(),
            };
            format!("[!DOCTYPE {}{}]\n", name, ext)
        }
    }
}

fn emit_doc(doc: &Document) -> String {
    let mut out = String::new();
    for node in &doc.prolog {
        out.push_str(&emit_node(node, 0));
    }
    for node in &doc.elements {
        out.push_str(&emit_node(node, 0));
    }
    // Strip trailing newlines like the Python implementation.
    let trimmed = out.trim_end_matches('\n');
    trimmed.to_string()
}
