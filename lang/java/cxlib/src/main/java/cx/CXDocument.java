package cx;

import com.google.gson.*;
import java.util.*;
import java.util.function.Function;
import java.util.regex.*;

/**
 * CX Document API — types, parse, query, mutation, CX emitter, loads/dumps.
 *
 * Architecture:
 *   CXDocument.parse(cxStr)  → CxLib.toAst(cxStr) → JSON → native Java objects
 *   CXDocument.loads(cxStr)  → CxLib.toDataBin(cxStr) → DataBin.decode → Java Object
 *   CXDocument.dumps(data)   → DataBin.encode(data)   → CxLib.fromDataBin → CX
 *   doc.toCx()               → native CX emitter (StringBuilder)
 *   doc.toXml() etc.         → CxLib.toXml(doc.toCx())
 */

// ── Node marker interface ──────────────────────────────────────────────────────

/**
 * Marker interface for all AST node types.
 */
interface Node {}

// ── Concrete node types ────────────────────────────────────────────────────────

class Attr {
    public String name;
    public Object value;     // String | Long | Double | Boolean | null
    public String dataType;  // null means string (omitted in JSON)
    /** v3.4 (ADR 0002): expanded-name fields populated by
     *  CXDocument.resolveNamespaces(). `local` is the part after the
     *  first ':' in `name` (or the whole name); `nsUri` is the resolved
     *  URI, null when no binding is in scope. Per XML Namespaces 1.0
     *  §6.2 the default namespace does not apply to unprefixed attrs. */
    public String local = "";
    public String nsUri = null;
    /** v3.4 (ADR 0003): true when the source attribute value was a bare
     *  `@id` reference token. Quoted strings starting with '@' have
     *  isRef = false. Round-trip preserves the bare form on emit. */
    public boolean isRef = false;
    /** v3.5 (ADR 0016): BracketBody attribute value — `name=[BodyItem*]`.
     *  When non-null, `value` is unused and the attribute's content is the
     *  parsed body sequence. Used by CXL evaluation directives like
     *  `[?if cond :then=[BODY] :else=[BODY]]`. Inert outside CXL evaluation;
     *  round-trips as opaque structure (ADR 0016 R5). ast_bin v5+. */
    public List<Node> body = null;

    public Attr(String name, Object value, String dataType) {
        this.name     = name;
        this.value    = value;
        this.dataType = dataType;
    }

    public Attr(String name, Object value) {
        this(name, value, null);
    }

    /** Local part of the attribute name (post-colon, or whole name). */
    public String localName() { return local; }

    /** Resolved namespace URI; null for unprefixed or unbound prefixes. */
    public String namespaceUri() { return nsUri; }
}

class TextNode implements Node {
    public String value;
    public TextNode(String value) { this.value = value; }
}

class ScalarNode implements Node {
    public String dataType;  // int | float | bool | null | string | date | datetime | bytes
    public Object value;     // native Java value

    public ScalarNode(String dataType, Object value) {
        this.dataType = dataType;
        this.value    = value;
    }
}

class CommentNode implements Node {
    public String value;
    public CommentNode(String value) { this.value = value; }
}

class RawTextNode implements Node {
    public String value;
    public RawTextNode(String value) { this.value = value; }
}

class EntityRefNode implements Node {
    public String name;
    public EntityRefNode(String name) { this.name = name; }
}

class AliasNode implements Node {
    public String name;
    public AliasNode(String name) { this.name = name; }
}

class PINode implements Node {
    public String target;
    public String data;  // may be null
    public PINode(String target, String data) {
        this.target = target;
        this.data   = data;
    }
}

class XMLDeclNode implements Node {
    public String version;
    public String encoding;    // may be null
    public String standalone;  // may be null

    public XMLDeclNode(String version, String encoding, String standalone) {
        this.version    = version    != null ? version    : "1.0";
        this.encoding   = encoding;
        this.standalone = standalone;
    }
}

/**
 * `[?cx ...]`. v0.6.0 (ast_bin v4) — directives may carry an `&amp;anchor`
 * and nested elements; used by the standalone-fragment form
 * `[?cx frag &amp;name [body :TYPE :flags]]` (spec/schema.md §8). v1-v3
 * buffers populate anchor/items as null/empty.
 */
class CXDirectiveNode implements Node {
    public List<Attr> attrs;
    public String     anchor;
    public List<Node> items;
    public CXDirectiveNode(List<Attr> attrs) {
        this(attrs, null, new ArrayList<>());
    }
    public CXDirectiveNode(List<Attr> attrs, String anchor, List<Node> items) {
        this.attrs  = attrs;
        this.anchor = anchor;
        this.items  = items != null ? items : new ArrayList<>();
    }
}

class BlockContentNode implements Node {
    public List<Node> items;
    public BlockContentNode(List<Node> items) { this.items = items; }
}

/** v3.5 (ADR 0016) [58] — `[?=EXPR]`. EXPR is opaque text at v0.6.0;
 *  the CXL evaluator at v0.7.0+ parses it as CXPath at evaluation time.
 *  ast_bin tag 0x0D (format v5+). */
class InterpolationNode implements Node {
    public String expr;
    public InterpolationNode(String expr) { this.expr = expr; }
}

/** v3.5 (ADR 0016) [59] — `[?Name attrs body]`. Reserved EvalNames
 *  (if/for/with/cond/include/def/use/let/fn/match/try) parse into this
 *  node. Inert at v0.6.0; the CXL evaluator dispatches on `name`.
 *  ast_bin tag 0x0E (format v5+). */
class EvalDirectiveNode implements Node {
    public String     name;
    public List<Attr> attrs;
    public List<Node> items;
    public EvalDirectiveNode(String name, List<Attr> attrs, List<Node> items) {
        this.name  = name;
        this.attrs = attrs;
        this.items = items;
    }
}

class DoctypeDeclNode implements Node {
    public String name;
    public Map<String, Object> externalId;  // may be null
    public List<Object> intSubset;

    public DoctypeDeclNode(String name, Map<String, Object> externalId, List<Object> intSubset) {
        this.name       = name;
        this.externalId = externalId;
        this.intSubset  = intSubset != null ? intSubset : new ArrayList<>();
    }
}

// ── Element ────────────────────────────────────────────────────────────────────

class Element implements Node {
    public String     name;
    public String     anchor;    // may be null
    public String     merge;     // may be null
    public String     dataType;  // may be null — TypeAnnotation e.g. "int[]"
    public List<Attr> attrs;
    public List<Node> items;
    /** v3.4 (ADR 0002): expanded-name fields populated by
     *  CXDocument.resolveNamespaces(). See Attr. */
    public String local = "";
    public String nsUri = null;
    /** v3.4 (ADR 0003): syntactic ID declaration ("#name" token); null
     *  when the element has no ID. Distinct from anchor and from
     *  user-data attributes literally named "id". */
    public String id    = null;
    /** v3.4 (ADR 0003 D1): body-position reference ("[ref @id]" shape).
     *  Carried over the ast_bin wire format at v3+ (Phase 7.70 bumped
     *  2 → 3). Null when the element is not a body-position reference. */
    public String bodyRef = null;

    public Element(String name) {
        this.name     = name;
        this.anchor   = null;
        this.merge    = null;
        this.dataType = null;
        this.attrs    = new ArrayList<>();
        this.items    = new ArrayList<>();
    }

    /** Local part of the element name (post-colon, or whole name). */
    public String localName() { return local; }

    /** Resolved namespace URI; null when no binding is in scope and
     *  the prefix is not reserved. */
    public String namespaceUri() { return nsUri; }

    /** Attribute value by name, or null. */
    public Object attr(String attrName) {
        for (Attr a : attrs) {
            if (a.name.equals(attrName)) return a.value;
        }
        return null;
    }

    /** Concatenated Text and Scalar child content. */
    public String text() {
        List<String> parts = new ArrayList<>();
        for (Node item : items) {
            if (item instanceof TextNode t) {
                parts.add(t.value);
            } else if (item instanceof ScalarNode s) {
                parts.add(s.value == null ? "null" : String.valueOf(s.value));
            }
        }
        return String.join(" ", parts);
    }

    /** Value of first Scalar child, or null. */
    public Object scalar() {
        for (Node item : items) {
            if (item instanceof ScalarNode s) return s.value;
        }
        return null;
    }

    /** All child Elements (excludes Text, Scalar, and other node types). */
    public List<Element> children() {
        List<Element> result = new ArrayList<>();
        for (Node item : items) {
            if (item instanceof Element e) result.add(e);
        }
        return result;
    }

    /** First child Element with this name. */
    public Element get(String childName) {
        for (Node item : items) {
            if (item instanceof Element e && e.name.equals(childName)) return e;
        }
        return null;
    }

    /** All direct child Elements with this name. */
    public List<Element> getAll(String childName) {
        List<Element> result = new ArrayList<>();
        for (Node item : items) {
            if (item instanceof Element e && e.name.equals(childName)) result.add(e);
        }
        return result;
    }

    /** All descendant Elements with this name (depth-first). */
    public List<Element> findAll(String targetName) {
        List<Element> result = new ArrayList<>();
        for (Node item : items) {
            if (item instanceof Element e) {
                if (e.name.equals(targetName)) result.add(e);
                result.addAll(e.findAll(targetName));
            }
        }
        return result;
    }

    /** First descendant Element with this name (depth-first). */
    public Element findFirst(String targetName) {
        for (Node item : items) {
            if (item instanceof Element e) {
                if (e.name.equals(targetName)) return e;
                Element found = e.findFirst(targetName);
                if (found != null) return found;
            }
        }
        return null;
    }

    /** Navigate by slash-separated path: el.at("server/host"). */
    public Element at(String path) {
        String[] parts = Arrays.stream(path.split("/"))
                               .filter(p -> !p.isEmpty())
                               .toArray(String[]::new);
        Element cur = this;
        for (String part : parts) {
            if (cur == null) return null;
            cur = cur.get(part);
        }
        return cur;
    }

    /** Set an attribute value, updating if it already exists. */
    public void setAttr(String attrName, Object value, String attrDataType) {
        for (Attr a : attrs) {
            if (a.name.equals(attrName)) {
                a.value    = value;
                a.dataType = attrDataType;
                return;
            }
        }
        attrs.add(new Attr(attrName, value, attrDataType));
    }

    /** Set a string attribute value. */
    public void setAttr(String attrName, Object value) {
        setAttr(attrName, value, null);
    }

    /** Remove an attribute by name. */
    public void removeAttr(String attrName) {
        attrs.removeIf(a -> a.name.equals(attrName));
    }

    /** Append a child node. */
    public void append(Node node) {
        items.add(node);
    }

    /** Prepend a child node. */
    public void prepend(Node node) {
        items.add(0, node);
    }

    /** Insert a child node at index. */
    public void insert(int index, Node node) {
        items.add(index, node);
    }

    /** Remove a child node by identity. */
    public void remove(Node node) {
        items.removeIf(i -> i == node);
    }

    /** Remove all direct child Elements with the given name. */
    public void removeChild(String name) {
        items.removeIf(i -> i instanceof Element e && e.name.equals(name));
    }

    /** Remove child node at index (no-op if out of bounds). */
    public void removeAt(int index) {
        if (index >= 0 && index < items.size()) items.remove(index);
    }

    /** First Element matching a CXPath expression. */
    public Element select(String expr) {
        List<Element> results = selectAll(expr);
        return results.isEmpty() ? null : results.get(0);
    }

    /**
     * All Elements matching a CXPath expression (subtree of this element).
     *
     * <p>v3.4: thunks to libcx via cx_select_all_paths (CB-5). Returned
     * Elements are *live references* into this Element's tree —
     * mutations propagate, preserving prior behavior. Semantics match
     * V's Element.select_all: this element's items become the top-level
     * candidate set.
     */
    public List<Element> selectAll(String expr) {
        // Emit each Element child as a top-level node so V's
        // Document.select_all_paths walks the same candidate set V's
        // Element.select_all would. Track a doc-index → orig-index
        // mapping for non-Element items.
        StringBuilder sb = new StringBuilder();
        List<Integer> docToOrig = new ArrayList<>();
        for (int i = 0; i < items.size(); i++) {
            if (items.get(i) instanceof Element el) {
                sb.append(CxEmitter.emitElement(el, 0));
                docToOrig.add(i);
            }
        }
        String docStr = sb.toString().stripTrailing();
        List<int[]> paths = CxLib.selectAllPaths(docStr, expr);
        List<Element> out = new ArrayList<>();
        for (int[] p : paths) {
            if (p.length == 0) continue;
            int top = p[0];
            if (top < 0 || top >= docToOrig.size()) continue;
            Node node = items.get(docToOrig.get(top));
            boolean ok = true;
            for (int i = 1; i < p.length; i++) {
                if (!(node instanceof Element el2) || p[i] < 0 || p[i] >= el2.items.size()) {
                    ok = false; break;
                }
                node = el2.items.get(p[i]);
            }
            if (ok && node instanceof Element matched) out.add(matched);
        }
        return out;
    }

    /** Emit this element as a CX string (no trailing newline). */
    public String toCx() {
        return CxEmitter.emitElement(this, 0).stripTrailing();
    }
}

// ── CXDocument ─────────────────────────────────────────────────────────────────

/**
 * Top-level document object.
 */
public class CXDocument {
    public List<Node>        elements;
    public List<Node>        prolog;
    public DoctypeDeclNode   doctype;  // may be null

    public CXDocument() {
        this.elements = new ArrayList<>();
        this.prolog   = new ArrayList<>();
        this.doctype  = null;
    }

    /** First top-level Element. */
    public Element root() {
        for (Node e : elements) {
            if (e instanceof Element el) return el;
        }
        return null;
    }

    /** First top-level Element with this name. */
    public Element get(String name) {
        for (Node e : elements) {
            if (e instanceof Element el && el.name.equals(name)) return el;
        }
        return null;
    }

    /** Navigate by slash-separated path from root. */
    public Element at(String path) {
        String[] parts = Arrays.stream(path.split("/"))
                               .filter(p -> !p.isEmpty())
                               .toArray(String[]::new);
        if (parts.length == 0) return root();
        Element cur = get(parts[0]);
        if (cur == null || parts.length == 1) return cur;
        return cur.at(String.join("/", Arrays.copyOfRange(parts, 1, parts.length)));
    }

    /** All descendant Elements with this name (depth-first through entire document). */
    public List<Element> findAll(String name) {
        List<Element> result = new ArrayList<>();
        for (Node e : elements) {
            if (e instanceof Element el) {
                if (el.name.equals(name)) result.add(el);
                result.addAll(el.findAll(name));
            }
        }
        return result;
    }

    /** First descendant Element with this name (depth-first through entire document). */
    public Element findFirst(String name) {
        for (Node e : elements) {
            if (e instanceof Element el) {
                if (el.name.equals(name)) return el;
                Element found = el.findFirst(name);
                if (found != null) return found;
            }
        }
        return null;
    }

    /** Return the Element declaring `#id`, or null. v3.4 (ADR 0003). */
    public Element resolveId(String id) {
        Element found = findElementById(elements, id);
        if (found != null) return found;
        return findElementById(prolog, id);
    }

    /** {id: Element} map for the whole document. v3.4 (ADR 0003). */
    public Map<String, Element> elementsById() {
        Map<String, Element> out = new java.util.HashMap<>();
        collectElementsById(elements, out);
        collectElementsById(prolog, out);
        return out;
    }

    private static Element findElementById(List<Node> nodes, String id) {
        for (Node n : nodes) {
            if (n instanceof Element e) {
                if (id.equals(e.id)) return e;
                Element found = findElementById(e.items, id);
                if (found != null) return found;
            }
        }
        return null;
    }

    private static void collectElementsById(List<Node> nodes, Map<String, Element> out) {
        for (Node n : nodes) {
            if (n instanceof Element e) {
                if (e.id != null) out.put(e.id, e);
                collectElementsById(e.items, out);
            }
        }
    }

    /** Append a top-level node. */
    public void append(Node node) {
        elements.add(node);
    }

    /** Prepend a top-level node. */
    public void prepend(Node node) {
        elements.add(0, node);
    }

    /** First Element matching a CXPath expression. */
    public Element select(String expr) {
        List<Element> results = selectAll(expr);
        return results.isEmpty() ? null : results.get(0);
    }

    /**
     * All Elements matching a CXPath expression.
     *
     * <p>v3.4: thunks to libcx via cx_select_all_paths (CB-5). Returned
     * Elements are live references into this Document's tree —
     * mutations propagate.
     */
    public List<Element> selectAll(String expr) {
        List<int[]> paths = CxLib.selectAllPaths(toCx(), expr);
        List<Element> out = new ArrayList<>(paths.size());
        for (int[] p : paths) {
            Element el = CXPath.navigateDocPath(this, p);
            if (el != null) out.add(el);
        }
        return out;
    }

    /** Return new document with element at path replaced by f(element). */
    public CXDocument transform(String path, Function<Element, Element> f) {
        String[] parts = Arrays.stream(path.split("/"))
                               .filter(p -> !p.isEmpty())
                               .toArray(String[]::new);
        if (parts.length == 0) return this;
        for (int i = 0; i < elements.size(); i++) {
            if (elements.get(i) instanceof Element el && el.name.equals(parts[0])) {
                if (parts.length == 1) {
                    return CXPath.docReplaceAt(this, i, f.apply(CXPath.elemDetached(el)));
                }
                Element updated = CXPath.pathCopyElement(el, Arrays.copyOfRange(parts, 1, parts.length), f);
                if (updated != null) return CXPath.docReplaceAt(this, i, updated);
                return this;
            }
        }
        return this;
    }

    /**
     * Return new document with all matching elements replaced by f(element).
     *
     * <p>v3.4: thunks to libcx via cx_select_all_paths (CB-5). Paths are
     * applied bottom-up (longest first) so when a parent is rewritten
     * its f-input already contains the f-results of descendant matches —
     * matching the prior post-order semantics.
     */
    public CXDocument transformAll(String expr, Function<Element, Element> f) {
        List<int[]> paths = CxLib.selectAllPaths(toCx(), expr);
        if (paths.isEmpty()) return this;
        List<int[]> sorted = new ArrayList<>(paths);
        sorted.sort((a, b) -> Integer.compare(b.length, a.length));
        CXDocument newDoc = this;
        for (int[] p : sorted) {
            Element target = CXPath.navigateDocPath(newDoc, p);
            if (target == null) continue;
            newDoc = CXPath.replaceAtDocPath(newDoc, p, f.apply(CXPath.elemDetached(target)));
        }
        return newDoc;
    }

    /** Emit the document as a CX string using the native emitter. */
    public String toCx() {
        return CxEmitter.emitDoc(this);
    }

    /**
     * Serialize this Document to a FRAMED [u32 LE size][payload]
     * binary AST buffer. Used internally by toXml / toJson / etc.
     * (Phase 5 / CB-1).
     */
    public byte[] toAstBin() { return BinaryDecoder.encodeAST(this); }

    // v3.4 (Phase 5 / CB-1): format methods now go through
    // cx_ast_bin_to_<fmt>(toAstBin()) directly, avoiding the prior
    // emit-CX-and-reparse detour.
    public String toXml()  { return CxLib.astBinToXml (toAstBin()); }
    public String toJson() { return CxLib.astBinToJson(toAstBin()); }
    public String toYaml() { return CxLib.astBinToYaml(toAstBin()); }
    public String toToml() { return CxLib.astBinToToml(toAstBin()); }
    public String toMd()   { return CxLib.astBinToMd  (toAstBin()); }

    // ── Namespace resolution (ADR 0002 / spec/namespaces.md) ──────────────────
    //
    // Mirrors V core's vcx/cx/namespaces.v. Walks a parsed Document,
    // populating Element.{local, nsUri} and Attr.{local, nsUri} from
    // in-scope xmlns / xmlns: declarations. Called at the tail of every
    // parse entry point so consumers see a uniform expanded-name view.

    public static final String XML_NAMESPACE_URI = "http://www.w3.org/XML/1998/namespace";
    public static final String CX_NAMESPACE_URI  = "https://cx-home.org/ns/cx";

    private static String[] splitNsPrefix(String name) {
        int i = name.indexOf(':');
        if (i < 0) return new String[]{"", name};
        return new String[]{name.substring(0, i), name.substring(i + 1)};
    }

    private static String lookupNs(String prefix, List<Map<String, String>> scope) {
        if ("xml".equals(prefix))   return XML_NAMESPACE_URI;
        if ("cx".equals(prefix))    return CX_NAMESPACE_URI;
        if ("xmlns".equals(prefix)) return null;
        for (int i = scope.size() - 1; i >= 0; i--) {
            if (scope.get(i).containsKey(prefix)) {
                String uri = scope.get(i).get(prefix);
                return (uri == null || uri.isEmpty()) ? null : uri;
            }
        }
        return null;
    }

    private static void resolveElement(Element e, List<Map<String, String>> scope) {
        Map<String, String> frame = new LinkedHashMap<>();
        for (Attr a : e.attrs) {
            String v = a.value == null ? "" : String.valueOf(a.value);
            if ("xmlns".equals(a.name)) {
                frame.put("", v);
            } else if (a.name.startsWith("xmlns:") && a.name.length() > 6) {
                frame.put(a.name.substring(6), v);
            }
        }
        boolean pushed = !frame.isEmpty();
        if (pushed) scope.add(frame);

        String[] split = splitNsPrefix(e.name);
        e.local = split[1];
        e.nsUri = lookupNs(split[0], scope);

        for (Attr a : e.attrs) {
            String[] aSplit = splitNsPrefix(a.name);
            a.local = aSplit[1];
            if ("xmlns".equals(a.name) || "xmlns".equals(aSplit[0])) {
                a.nsUri = null;
                continue;
            }
            if (aSplit[0].isEmpty()) {
                // Default ns does not apply to unprefixed attributes.
                a.nsUri = null;
                continue;
            }
            a.nsUri = lookupNs(aSplit[0], scope);
        }

        for (Node item : e.items) {
            if (item instanceof Element child) resolveElement(child, scope);
        }

        if (pushed) scope.remove(scope.size() - 1);
    }

    /** Populate Element.{local, nsUri} and Attr.{local, nsUri} on every
     *  node in {@code doc} per ADR 0002 / spec/namespaces.md.
     *  Idempotent. Called automatically by parse / parseXml / parseJson /
     *  parseYaml / parseToml / parseMd. */
    public static void resolveNamespaces(CXDocument doc) {
        List<Map<String, String>> scope = new ArrayList<>();
        for (Node n : doc.elements) {
            if (n instanceof Element e) resolveElement(e, scope);
        }
    }

    // ── Static factory methods ─────────────────────────────────────────────────

    /** Parse a CX string into a CXDocument (uses binary wire protocol). */
    public static CXDocument parse(String cxStr) throws Exception {
        byte[] data = CxLib.astBin(cxStr);
        CXDocument doc = BinaryDecoder.decodeAST(data);
        resolveNamespaces(doc);
        return doc;
    }

    /**
     * Stream a CX string as a list of SAX-like {@link StreamEvent}s.
     *
     * <p>v3.4 (Phase 5 / CB-4): pulls events one-by-one via the
     * cx_events_open / cx_events_next / cx_events_close handle API.
     * Replaces the prior eager-buffered cx_to_events_bin path. For
     * true pull-based streaming with caller-controlled cancellation,
     * use {@link EventStream#open} directly.
     */
    public static List<StreamEvent> stream(String cxStr) throws Exception {
        try (EventStream s = EventStream.open(cxStr)) {
            List<StreamEvent> events = new ArrayList<>();
            for (StreamEvent ev : s) events.add(ev);
            return events;
        }
    }

    // v3.4 (Phase 5 / CB-2): parse_<format> goes through
    // cx_<format>_to_ast_bin directly, avoiding the prior cx_<fmt>_to_ast
    // → JSON.parse → walk dict pipeline.

    /** Parse an XML string into a CXDocument. */
    public static CXDocument parseXml(String s) {
        CXDocument doc = BinaryDecoder.decodeAST(CxLib.xmlToAstBin(s));
        resolveNamespaces(doc);
        return doc;
    }

    /** Parse a JSON string into a CXDocument. */
    public static CXDocument parseJson(String s) {
        CXDocument doc = BinaryDecoder.decodeAST(CxLib.jsonToAstBin(s));
        resolveNamespaces(doc);
        return doc;
    }

    /** Parse a YAML string into a CXDocument. */
    public static CXDocument parseYaml(String s) {
        CXDocument doc = BinaryDecoder.decodeAST(CxLib.yamlToAstBin(s));
        resolveNamespaces(doc);
        return doc;
    }

    /** Parse a TOML string into a CXDocument. */
    public static CXDocument parseToml(String s) {
        CXDocument doc = BinaryDecoder.decodeAST(CxLib.tomlToAstBin(s));
        resolveNamespaces(doc);
        return doc;
    }

    /** Parse a Markdown string into a CXDocument. */
    public static CXDocument parseMd(String s) {
        CXDocument doc = BinaryDecoder.decodeAST(CxLib.mdToAstBin(s));
        resolveNamespaces(doc);
        return doc;
    }

    // ── Data binding ───────────────────────────────────────────────────────────

    /**
     * Deserialize a CX data string into native Java types (Map/List/scalar).
     *
     * <p>v3.4: parses through CXDB v1 (cx_to_data_bin) directly into Java
     * types — no JSON-string detour. Type fidelity preserved (integers
     * stay {@link Long}, floats stay {@link Double}, booleans stay
     * {@link Boolean}, dates round-trip as {@link java.time.LocalDate},
     * bytes as {@code byte[]}). Closes audit finding CB-3.
     */
    public static Object loads(String cxStr) {
        return DataBin.decode(CxLib.toDataBin(cxStr));
    }

    /** Deserialize an XML string into native Java types. */
    public static Object loadsXml(String s) {
        return new Gson().fromJson(CxLib.xmlToJson(s), Object.class);
    }

    /** Deserialize a JSON string via the CX semantic bridge. */
    public static Object loadsJson(String s) {
        return new Gson().fromJson(CxLib.jsonToJson(s), Object.class);
    }

    /** Deserialize a YAML string into native Java types. */
    public static Object loadsYaml(String s) {
        return new Gson().fromJson(CxLib.yamlToJson(s), Object.class);
    }

    /** Deserialize a TOML string into native Java types. */
    public static Object loadsToml(String s) {
        return new Gson().fromJson(CxLib.tomlToJson(s), Object.class);
    }

    /** Deserialize a Markdown string into native Java types. */
    public static Object loadsMd(String s) {
        return new Gson().fromJson(CxLib.mdToJson(s), Object.class);
    }

    /**
     * Serialize native Java types (Map/List/scalar) to a CX string.
     *
     * <p>v3.4: encodes the Java value as CXDB v1 bytes directly, then calls
     * cx_from_data_bin to produce canonical CX. No JSON-string detour;
     * type fidelity preserved on round-trip with {@link #loads}. Closes
     * audit finding CB-3.
     */
    public static String dumps(Object data) {
        return CxLib.fromDataBin(DataBin.encode(data));
    }
}

// ── AST deserializer ────────────────────────────────────────────────────────────

class AstDeserializer {

    static CXDocument docFromJson(JsonObject d) {
        CXDocument doc = new CXDocument();
        if (d.has("prolog") && !d.get("prolog").isJsonNull()) {
            for (JsonElement n : d.getAsJsonArray("prolog")) {
                doc.prolog.add(nodeFromJson(n.getAsJsonObject()));
            }
        }
        if (d.has("doctype") && !d.get("doctype").isJsonNull()) {
            JsonObject dt = d.getAsJsonObject("doctype");
            doc.doctype = new DoctypeDeclNode(
                dt.get("name").getAsString(),
                null,
                new ArrayList<>()
            );
        }
        if (d.has("elements") && !d.get("elements").isJsonNull()) {
            for (JsonElement n : d.getAsJsonArray("elements")) {
                doc.elements.add(nodeFromJson(n.getAsJsonObject()));
            }
        }
        return doc;
    }

    static Node nodeFromJson(JsonObject o) {
        String type = o.get("type").getAsString();
        return switch (type) {
            case "Element"     -> elementFromJson(o);
            case "Text"        -> new TextNode(o.get("value").getAsString());
            case "Scalar"      -> new ScalarNode(
                                      o.get("dataType").getAsString(),
                                      scalarValue(o));
            case "Comment"     -> new CommentNode(o.get("value").getAsString());
            case "RawText"     -> new RawTextNode(o.get("value").getAsString());
            case "EntityRef"   -> new EntityRefNode(o.get("name").getAsString());
            case "Alias"       -> new AliasNode(o.get("name").getAsString());
            case "PI"          -> new PINode(
                                      o.get("target").getAsString(),
                                      o.has("data") && !o.get("data").isJsonNull()
                                          ? o.get("data").getAsString() : null);
            case "XMLDecl"     -> new XMLDeclNode(
                                      o.has("version")    ? o.get("version").getAsString()    : "1.0",
                                      o.has("encoding")   ? o.get("encoding").getAsString()   : null,
                                      o.has("standalone") ? o.get("standalone").getAsString() : null);
            case "CXDirective" -> {
                List<Attr> attrs = new ArrayList<>();
                if (o.has("attrs")) {
                    for (JsonElement a : o.getAsJsonArray("attrs")) {
                        JsonObject ao = a.getAsJsonObject();
                        attrs.add(new Attr(ao.get("name").getAsString(),
                                           ao.get("value").getAsString(), null));
                    }
                }
                yield new CXDirectiveNode(attrs);
            }
            case "DoctypeDecl" -> new DoctypeDeclNode(
                                      o.get("name").getAsString(), null, new ArrayList<>());
            case "BlockContent" -> {
                List<Node> items = new ArrayList<>();
                if (o.has("items")) {
                    for (JsonElement n : o.getAsJsonArray("items"))
                        items.add(nodeFromJson(n.getAsJsonObject()));
                }
                yield new BlockContentNode(items);
            }
            default -> new TextNode(o.toString());  // unknown — preserve as text
        };
    }

    static Element elementFromJson(JsonObject o) {
        Element e = new Element(o.get("name").getAsString());
        if (o.has("anchor")   && !o.get("anchor").isJsonNull())
            e.anchor   = o.get("anchor").getAsString();
        if (o.has("merge")    && !o.get("merge").isJsonNull())
            e.merge    = o.get("merge").getAsString();
        if (o.has("dataType") && !o.get("dataType").isJsonNull())
            e.dataType = o.get("dataType").getAsString();
        if (o.has("attrs") && !o.get("attrs").isJsonNull()) {
            for (JsonElement a : o.getAsJsonArray("attrs")) {
                JsonObject ao = a.getAsJsonObject();
                Object attrVal = attrValue(ao);
                String attrDt  = ao.has("dataType") && !ao.get("dataType").isJsonNull()
                                  ? ao.get("dataType").getAsString() : null;
                e.attrs.add(new Attr(ao.get("name").getAsString(), attrVal, attrDt));
            }
        }
        if (o.has("items") && !o.get("items").isJsonNull()) {
            for (JsonElement n : o.getAsJsonArray("items"))
                e.items.add(nodeFromJson(n.getAsJsonObject()));
        }
        return e;
    }

    /** Deserialize an attribute value from JSON, preserving native type. */
    static Object attrValue(JsonObject ao) {
        if (!ao.has("value") || ao.get("value").isJsonNull()) return null;
        JsonElement v = ao.get("value");
        String dt = ao.has("dataType") && !ao.get("dataType").isJsonNull()
                    ? ao.get("dataType").getAsString() : null;
        if (v.isJsonPrimitive()) {
            JsonPrimitive p = v.getAsJsonPrimitive();
            if (p.isBoolean()) return p.getAsBoolean();
            if (p.isNumber()) {
                // Use dataType to decide representation
                if ("int".equals(dt))   return p.getAsLong();
                if ("float".equals(dt)) return p.getAsDouble();
                // Infer from JSON number
                double d = p.getAsDouble();
                if (d == Math.floor(d) && !Double.isInfinite(d) && !"float".equals(dt))
                    return p.getAsLong();
                return d;
            }
            return p.getAsString();
        }
        return v.toString();
    }

    /** Deserialize a scalar value from a Scalar node JSON object. */
    static Object scalarValue(JsonObject o) {
        if (!o.has("value") || o.get("value").isJsonNull()) return null;
        JsonElement v  = o.get("value");
        String      dt = o.get("dataType").getAsString();
        if (v.isJsonPrimitive()) {
            JsonPrimitive p = v.getAsJsonPrimitive();
            if (p.isBoolean()) return p.getAsBoolean();
            if (p.isNumber()) {
                if ("int".equals(dt))   return p.getAsLong();
                if ("float".equals(dt)) return p.getAsDouble();
                double d = p.getAsDouble();
                if (d == Math.floor(d) && !Double.isInfinite(d)) return p.getAsLong();
                return d;
            }
            return p.getAsString();
        }
        return null;
    }
}

// ── CX emitter ─────────────────────────────────────────────────────────────────

class CxEmitter {

    private static final Pattern DATE_RE     = Pattern.compile("^\\d{4}-\\d{2}-\\d{2}$");
    private static final Pattern DATETIME_RE = Pattern.compile("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}");
    private static final Pattern HEX_RE      = Pattern.compile("^0[xX][0-9a-fA-F]+$");

    // ── quoting helpers ────────────────────────────────────────────────────────

    static boolean wouldAutotype(String s) {
        if (s.contains(" ")) return false;
        if (HEX_RE.matcher(s).matches()) return true;
        try { Long.parseLong(s); return true; } catch (NumberFormatException ignored) {}
        if (s.contains(".") || s.toLowerCase().contains("e")) {
            try { Double.parseDouble(s); return true; } catch (NumberFormatException ignored) {}
        }
        if (s.equals("true") || s.equals("false") || s.equals("null")) return true;
        if (DATETIME_RE.matcher(s).find()) return true;
        if (DATE_RE.matcher(s).matches())  return true;
        return false;
    }

    static String cxChooseQuote(String s) {
        if (!s.contains("'"))   return "'" + s + "'";
        if (!s.contains("\""))  return "\"" + s + "\"";
        if (!s.contains("'''")) return "'''" + s + "'''";
        return "\"" + s + "\"";  // best effort
    }

    static String cxQuoteText(String s) {
        boolean needs = s.startsWith(" ") || s.endsWith(" ")
                     || s.contains("  ") || s.contains("\n") || s.contains("\t")
                     || s.contains("[")  || s.contains("]")  || s.contains("&")
                     || s.startsWith(":") || s.startsWith("'") || s.startsWith("\"")
                     || wouldAutotype(s);
        return needs ? cxChooseQuote(s) : s;
    }

    static String cxQuoteAttr(String s) {
        if (s.isEmpty() || s.contains(" ") || s.contains("'") || s.contains("\""))
            return "'" + s + "'";
        return s;
    }

    // ── scalar formatting ──────────────────────────────────────────────────────

    static String emitScalarValue(ScalarNode s) {
        Object v = s.value;
        if (v == null)            return "null";
        if (v instanceof Boolean) return (Boolean) v ? "true" : "false";
        if (v instanceof Long   ) return v.toString();
        if (v instanceof Double d) {
            String f = String.valueOf(d);
            return (f.contains(".") || f.toLowerCase().contains("e")) ? f : f + ".0";
        }
        return v.toString();
    }

    // ── attribute formatting ───────────────────────────────────────────────────

    static String emitAttr(Attr a) {
        if (a.isRef) {
            // ADR 0003 D1: bare `@id` round-trips verbatim.
            return a.name + "=@" + (a.value == null ? "" : a.value.toString());
        }
        String dt = a.dataType;
        if ("int".equals(dt)) {
            return a.name + "=" + ((Number) a.value).longValue();
        }
        if ("float".equals(dt)) {
            double d = ((Number) a.value).doubleValue();
            String f = String.valueOf(d);
            String v = (f.contains(".") || f.toLowerCase().contains("e")) ? f : f + ".0";
            return a.name + "=" + v;
        }
        if ("bool".equals(dt)) {
            return a.name + "=" + ((Boolean) a.value ? "true" : "false");
        }
        if ("null".equals(dt)) {
            return a.name + "=null";
        }
        // string attr — quote if would autotype OR starts with '@' (else
        // would mis-parse as is_ref reference per ADR 0003).
        String s = a.value == null ? "null" : a.value.toString();
        boolean startsAt = !s.isEmpty() && s.charAt(0) == '@';
        String v = (wouldAutotype(s) || startsAt) ? cxChooseQuote(s) : cxQuoteAttr(s);
        return a.name + "=" + v;
    }

    // ── inline emission ────────────────────────────────────────────────────────

    static String emitInline(Node node) {
        if (node instanceof TextNode t) {
            return t.value.isBlank() ? "" : cxQuoteText(t.value);
        }
        if (node instanceof ScalarNode s) {
            return emitScalarValue(s);
        }
        if (node instanceof EntityRefNode er) {
            return "&" + er.name + ";";
        }
        if (node instanceof RawTextNode rt) {
            return "[#" + rt.value + "#]";
        }
        if (node instanceof Element e) {
            return emitElement(e, 0).stripTrailing();
        }
        if (node instanceof BlockContentNode bc) {
            StringBuilder sb = new StringBuilder("[|");
            for (Node n : bc.items) {
                if (n instanceof TextNode t) {
                    sb.append(t.value);
                } else if (n instanceof Element e) {
                    sb.append(emitElement(e, 0).stripTrailing());
                }
            }
            sb.append("|]");
            return sb.toString();
        }
        return "";
    }

    // ── element emission ───────────────────────────────────────────────────────

    static String emitElement(Element e, int depth) {
        String ind = "  ".repeat(depth);
        // ADR 0003 D1: body-position reference shape — early return.
        if (e.bodyRef != null) {
            return ind + "[" + e.name + " @" + e.bodyRef + "]\n";
        }
        boolean hasChildElems = e.items.stream().anyMatch(i -> i instanceof Element);
        boolean hasText       = e.items.stream().anyMatch(
            i -> i instanceof TextNode || i instanceof ScalarNode
              || i instanceof EntityRefNode || i instanceof RawTextNode);
        boolean isMultiline   = hasChildElems && !hasText;

        // Build meta string: &anchor *merge :dataType attr=val ...
        List<String> metaParts = new ArrayList<>();
        if (e.anchor   != null) metaParts.add("&" + e.anchor);
        if (e.merge    != null) metaParts.add("*" + e.merge);
        if (e.id       != null) metaParts.add("#" + e.id);
        if (e.dataType != null) metaParts.add(":" + e.dataType);
        for (Attr a : e.attrs) metaParts.add(emitAttr(a));
        String meta = metaParts.isEmpty() ? "" : " " + String.join(" ", metaParts);

        if (isMultiline) {
            StringBuilder sb = new StringBuilder();
            sb.append(ind).append("[").append(e.name).append(meta).append("\n");
            for (Node item : e.items) {
                sb.append(emitNode(item, depth + 1));
            }
            sb.append(ind).append("]\n");
            return sb.toString();
        }

        if (e.items.isEmpty() && meta.isEmpty()) {
            return ind + "[" + e.name + "]\n";
        }

        List<String> bodyParts = new ArrayList<>();
        for (Node item : e.items) {
            String p = emitInline(item);
            if (!p.isEmpty()) bodyParts.add(p);
        }
        String body = String.join(" ", bodyParts);
        String sep  = body.isEmpty() ? "" : " ";
        return ind + "[" + e.name + meta + sep + body + "]\n";
    }

    // ── node emission ──────────────────────────────────────────────────────────

    static String emitNode(Node node, int depth) {
        String ind = "  ".repeat(depth);
        if (node instanceof Element e)        return emitElement(e, depth);
        if (node instanceof TextNode t)       return cxQuoteText(t.value);
        if (node instanceof ScalarNode s)     return emitScalarValue(s);
        if (node instanceof CommentNode c)    return ind + "[-" + c.value + "]\n";
        if (node instanceof RawTextNode rt)   return ind + "[#" + rt.value + "#]\n";
        if (node instanceof EntityRefNode er) return "&" + er.name + ";";
        if (node instanceof AliasNode al)     return ind + "[*" + al.name + "]\n";
        if (node instanceof BlockContentNode bc) {
            StringBuilder sb = new StringBuilder();
            sb.append(ind).append("[|");
            for (Node n : bc.items) sb.append(emitNode(n, 0));
            sb.append("|]\n");
            return sb.toString();
        }
        if (node instanceof PINode pi) {
            String data = pi.data != null ? " " + pi.data : "";
            return ind + "[?" + pi.target + data + "]\n";
        }
        if (node instanceof XMLDeclNode xd) {
            List<String> parts = new ArrayList<>();
            parts.add("version=" + xd.version);
            if (xd.encoding   != null) parts.add("encoding="   + xd.encoding);
            if (xd.standalone != null) parts.add("standalone=" + xd.standalone);
            return "[?xml " + String.join(" ", parts) + "]\n";
        }
        if (node instanceof CXDirectiveNode cd) {
            List<String> parts = new ArrayList<>();
            for (Attr a : cd.attrs)
                parts.add(a.name + "=" + cxQuoteAttr(a.value != null ? a.value.toString() : ""));
            return "[?cx " + String.join(" ", parts) + "]\n";
        }
        if (node instanceof DoctypeDeclNode dt) {
            return "[!DOCTYPE " + dt.name + "]\n";
        }
        return "";
    }

    // ── document emission ──────────────────────────────────────────────────────

    static String emitDoc(CXDocument doc) {
        StringBuilder sb = new StringBuilder();
        for (Node node : doc.prolog)    sb.append(emitNode(node, 0));
        if (doc.doctype != null)        sb.append(emitNode(doc.doctype, 0));
        for (Node node : doc.elements)  sb.append(emitNode(node, 0));
        // Strip trailing newline as in Python
        String s = sb.toString();
        while (s.endsWith("\n")) s = s.substring(0, s.length() - 1);
        return s;
    }
}
