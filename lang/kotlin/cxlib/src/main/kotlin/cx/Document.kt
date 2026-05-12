package cx

import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonNull
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.google.gson.JsonPrimitive

// ── Node hierarchy ─────────────────────────────────────────────────────────────

sealed class Node

data class Attr(
    val name: String,
    var value: Any?,
    var dataType: String? = null,
    /** v3.4 (ADR 0002): expanded-name fields populated by
     *  [CXDocument.resolveNamespaces]. `local` is the part after the
     *  first ':' in `name` (or the whole name); `nsUri` is the resolved
     *  URI, null when no binding is in scope. Per XML Namespaces 1.0
     *  §6.2 the default ns does not apply to unprefixed attributes. */
    var local: String = "",
    var nsUri: String? = null,
    /** v3.4 (ADR 0003): true when the source attribute value was a bare
     *  `@id` reference token. Quoted strings starting with '@' have
     *  isRef = false. Round-trip preserves the bare form on emit. */
    var isRef: Boolean = false,
    /** v3.5 (ADR 0016): BracketBody attribute value — `name=[BodyItem*]`.
     *  When non-null, `value` is unused and the attribute's content is
     *  the parsed body sequence. Used by CXL evaluation directives like
     *  `[?if cond :then=[BODY] :else=[BODY]]`. Inert outside CXL evaluation;
     *  round-trips as opaque structure (ADR 0016 R5). ast_bin v5+. */
    var body: List<Node>? = null,
) {
    /** Local part of the attribute name (post-colon, or whole name). */
    fun localName(): String = local
    /** Resolved namespace URI; null for unprefixed or unbound prefixes. */
    fun namespaceUri(): String? = nsUri
}

class Element(
    val name: String,
    var anchor: String? = null,
    var merge: String? = null,
    var dataType: String? = null,
    val attrs: MutableList<Attr> = mutableListOf(),
    val items: MutableList<Node> = mutableListOf(),
) : Node() {

    /** v3.4 (ADR 0002): expanded-name fields populated by
     *  [CXDocument.resolveNamespaces]. */
    var local: String = ""
    var nsUri: String? = null
    /** v3.4 (ADR 0003): syntactic ID declaration ("#name" token); null
     *  when the element has no ID. Distinct from anchor. */
    var id: String? = null
    /** v3.4 (ADR 0003 D1): body-position reference token. When set,
     *  the element was written as `[name @id]` — a bare-`@id` body
     *  reference with no other meta or items. Carried over the
     *  ast_bin wire format at v3+ (Phase 7.70 bumped 2 → 3). */
    var bodyRef: String? = null

    /** Local part of the element name (post-colon, or whole name). */
    fun localName(): String = local
    /** Resolved namespace URI; null when no binding is in scope and
     *  the prefix is not reserved. */
    fun namespaceUri(): String? = nsUri

    fun attr(name: String): Any? = attrs.find { it.name == name }?.value

    fun text(): String {
        val parts = mutableListOf<String>()
        for (item in items) {
            when (item) {
                is TextNode -> parts.add(item.value)
                is ScalarNode -> parts.add(if (item.value == null) "null" else item.value.toString())
                else -> {}
            }
        }
        return parts.joinToString(" ")
    }

    fun scalar(): Any? = items.filterIsInstance<ScalarNode>().firstOrNull()?.value

    fun children(): List<Element> = items.filterIsInstance<Element>()

    fun get(name: String): Element? =
        items.filterIsInstance<Element>().firstOrNull { it.name == name }

    fun getAll(name: String): List<Element> =
        items.filterIsInstance<Element>().filter { it.name == name }

    fun findAll(name: String): List<Element> {
        val result = mutableListOf<Element>()
        for (item in items) {
            if (item is Element) {
                if (item.name == name) result.add(item)
                result.addAll(item.findAll(name))
            }
        }
        return result
    }

    fun findFirst(name: String): Element? {
        for (item in items) {
            if (item is Element) {
                if (item.name == name) return item
                val found = item.findFirst(name)
                if (found != null) return found
            }
        }
        return null
    }

    fun at(path: String): Element? {
        val parts = path.split('/').filter { it.isNotEmpty() }
        var cur: Element? = this
        for (part in parts) {
            cur = cur?.get(part)
        }
        return cur
    }

    fun setAttr(name: String, value: Any?, dataType: String? = null) {
        val existing = attrs.find { it.name == name }
        if (existing != null) {
            existing.value = value
            existing.dataType = dataType
        } else {
            attrs.add(Attr(name, value, dataType))
        }
    }

    fun removeAttr(name: String) {
        attrs.removeIf { it.name == name }
    }

    fun append(node: Node) { items.add(node) }
    fun prepend(node: Node) { items.add(0, node) }
    fun insert(index: Int, node: Node) { items.add(index, node) }
    fun remove(node: Node) { items.removeIf { it === node } }

    fun toCx(): String = emitElement(this, 0)

    fun removeChild(name: String) {
        items.removeIf { it is Element && it.name == name }
    }

    fun removeAt(index: Int) {
        if (index in items.indices) items.removeAt(index)
    }

    fun select(expr: String): Element? = selectAll(expr).firstOrNull()

    /**
     * v3.4: thunks to libcx via cx_select_all_paths (CB-5). Returned
     * Elements are *live references* into this Element's tree —
     * mutations propagate, preserving prior behavior. Semantics match
     * V's Element.select_all: this element's items become the top-
     * level candidate set.
     */
    fun selectAll(expr: String): List<Element> {
        // Emit each Element child as top-level so V's
        // Document.select_all_paths walks the same candidate set V's
        // Element.select_all would. Track a doc-index → orig-index
        // mapping (non-Element items don't affect CXPath matches but
        // shift item indices).
        val sb = StringBuilder()
        val docToOrig = mutableListOf<Int>()
        for ((i, item) in items.withIndex()) {
            if (item is Element) {
                sb.append(emitElement(item, 0))
                docToOrig.add(i)
            }
        }
        val docStr = sb.toString().trimEnd()
        val paths = CxLib.selectAllPaths(docStr, expr)
        val out = mutableListOf<Element>()
        for (p in paths) {
            if (p.isEmpty()) continue
            val top = p[0]
            if (top !in docToOrig.indices) continue
            var node: Node = items[docToOrig[top]]
            var ok = true
            for (i in 1 until p.size) {
                val el = node as? Element
                if (el == null || p[i] !in el.items.indices) { ok = false; break }
                node = el.items[p[i]]
            }
            if (ok && node is Element) out.add(node)
        }
        return out
    }
}

data class TextNode(val value: String) : Node()
data class ScalarNode(val dataType: String, val value: Any?) : Node()
data class CommentNode(val value: String) : Node()
data class RawTextNode(val value: String) : Node()
data class EntityRefNode(val name: String) : Node()
data class AliasNode(val name: String) : Node()
data class PINode(val target: String, val data: String? = null) : Node()
data class XMLDeclNode(
    val version: String = "1.0",
    val encoding: String? = null,
    val standalone: String? = null,
) : Node()
data class CXDirectiveNode(
    val attrs: List<Attr>,
    /** v0.6.0 — directives may carry an `&anchor` and/or nested
     *  elements. Currently used by the standalone-fragment form
     *  `[?cx frag &name [body :TYPE :flags]]` (spec/schema.md §8).
     *  ast_bin format version 4 carries them; v1-3 buffers populate
     *  these as null/empty. */
    val anchor: String? = null,
    val items: List<Node> = emptyList(),
) : Node()

/** v3.5 (ADR 0016) [58] — `[?=EXPR]`. EXPR is opaque text at v0.6.0;
 *  the CXL evaluator at v0.7.0+ parses it as CXPath at evaluation time.
 *  ast_bin tag 0x0D (format v5+). */
data class InterpolationNode(val expr: String) : Node()

/** v3.5 (ADR 0016) [59] — `[?Name attrs body]`. Reserved EvalNames
 *  (if/for/with/cond/include/def/use/let/fn/match/try) parse into this
 *  node. Inert at v0.6.0; the CXL evaluator dispatches on `name`.
 *  ast_bin tag 0x0E (format v5+). */
data class EvalDirectiveNode(
    val name: String,
    val attrs: List<Attr> = emptyList(),
    val items: List<Node> = emptyList(),
) : Node()
data class DoctypeDeclNode(
    val name: String,
    val externalId: Any? = null,
    val intSubset: List<Any> = emptyList(),
) : Node()
data class BlockContentNode(val items: List<Node>) : Node()


// ── Document ───────────────────────────────────────────────────────────────────

class CXDocument(
    val elements: MutableList<Node> = mutableListOf(),
    val prolog: MutableList<Node> = mutableListOf(),
    var doctype: DoctypeDeclNode? = null,
) {
    fun root(): Element? = elements.filterIsInstance<Element>().firstOrNull()

    fun get(name: String): Element? =
        elements.filterIsInstance<Element>().firstOrNull { it.name == name }

    fun at(path: String): Element? {
        val parts = path.split('/').filter { it.isNotEmpty() }
        if (parts.isEmpty()) return root()
        val first = get(parts[0]) ?: return null
        if (parts.size == 1) return first
        return first.at(parts.drop(1).joinToString("/"))
    }

    fun findAll(name: String): List<Element> {
        val result = mutableListOf<Element>()
        for (e in elements) {
            if (e is Element) {
                if (e.name == name) result.add(e)
                result.addAll(e.findAll(name))
            }
        }
        return result
    }

    fun findFirst(name: String): Element? {
        for (e in elements) {
            if (e is Element) {
                if (e.name == name) return e
                val found = e.findFirst(name)
                if (found != null) return found
            }
        }
        return null
    }

    /** Return the Element declaring `#id`, or null. v3.4 (ADR 0003). */
    fun resolveId(id: String): Element? =
        findElementById(elements, id) ?: findElementById(prolog, id)

    /** {id: Element} map for the whole document. v3.4 (ADR 0003). */
    fun elementsById(): Map<String, Element> {
        val out = mutableMapOf<String, Element>()
        collectElementsById(elements, out)
        collectElementsById(prolog, out)
        return out
    }

    fun append(node: Node) { elements.add(node) }
    fun prepend(node: Node) { elements.add(0, node) }

    fun select(expr: String): Element? = selectAll(expr).firstOrNull()

    /**
     * v3.4: thunks to libcx via cx_select_all_paths (CB-5). Returned
     * Elements are live references into this Document's tree —
     * mutations propagate.
     */
    fun selectAll(expr: String): List<Element> {
        val paths = CxLib.selectAllPaths(toCx(), expr)
        return paths.mapNotNull { navigateDocPath(this, it) }
    }

    fun transform(path: String, f: (Element) -> Element): CXDocument {
        val parts = path.split("/").filter { it.isNotEmpty() }
        if (parts.isEmpty()) return this
        for ((i, node) in elements.withIndex()) {
            if (node is Element && node.name == parts[0]) {
                if (parts.size == 1) {
                    return docReplaceAt(this, i, f(elemDetached(node)))
                }
                val updated = pathCopyElement(node, parts.drop(1), f)
                if (updated != null) return docReplaceAt(this, i, updated)
                return this
            }
        }
        return this
    }

    /**
     * v3.4: thunks to libcx via cx_select_all_paths (CB-5). Paths are
     * applied bottom-up (longest first) so when a parent is rewritten
     * its f-input already contains the f-results of descendant
     * matches — matching the prior post-order semantics.
     */
    fun transformAll(expr: String, f: (Element) -> Element): CXDocument {
        val paths = CxLib.selectAllPaths(toCx(), expr)
        if (paths.isEmpty()) return this
        val sorted = paths.sortedByDescending { it.size }
        var newDoc = this
        for (p in sorted) {
            val target = navigateDocPath(newDoc, p) ?: continue
            newDoc = replaceAtDocPath(newDoc, p, f(elemDetached(target)))
        }
        return newDoc
    }

    fun toCx(): String = emitDoc(this)

    /**
     * Serialize this Document to a FRAMED [u32 LE size][payload] AST
     * bin ByteArray. Used internally by toXml / toJson / etc.
     * (Phase 5 / CB-1).
     */
    fun toAstBin(): ByteArray = BinaryDecoder.encodeAST(this)

    // v3.4 (Phase 5 / CB-1): format methods now go through
    // cx_ast_bin_to_<fmt>(toAstBin()) directly, avoiding the prior
    // emit-CX-and-reparse detour.
    fun toXml(): String  = CxLib.astBinToXml (toAstBin())
    fun toJson(): String = CxLib.astBinToJson(toAstBin())
    fun toYaml(): String = CxLib.astBinToYaml(toAstBin())
    fun toToml(): String = CxLib.astBinToToml(toAstBin())
    fun toMd(): String   = CxLib.astBinToMd  (toAstBin())

    companion object {
        // ── Namespace resolution (ADR 0002 / spec/namespaces.md) ──────────────
        //
        // Mirrors V core's vcx/cx/namespaces.v. Walks a parsed Document,
        // populating Element.{local, nsUri} and Attr.{local, nsUri} from
        // in-scope xmlns / xmlns: declarations. Called at the tail of
        // every parse entry point.

        const val XML_NAMESPACE_URI = "http://www.w3.org/XML/1998/namespace"
        const val CX_NAMESPACE_URI  = "https://cx-home.org/ns/cx"

        private fun splitNsPrefix(name: String): Pair<String, String> {
            val i = name.indexOf(':')
            return if (i < 0) "" to name else name.substring(0, i) to name.substring(i + 1)
        }

        private fun lookupNs(prefix: String, scope: List<MutableMap<String, String>>): String? {
            when (prefix) {
                "xml"   -> return XML_NAMESPACE_URI
                "cx"    -> return CX_NAMESPACE_URI
                "xmlns" -> return null
            }
            for (i in scope.indices.reversed()) {
                if (scope[i].containsKey(prefix)) {
                    val uri = scope[i][prefix]
                    return if (uri.isNullOrEmpty()) null else uri
                }
            }
            return null
        }

        private fun resolveElement(e: Element, scope: MutableList<MutableMap<String, String>>) {
            val frame = mutableMapOf<String, String>()
            for (a in e.attrs) {
                val v = a.value?.toString() ?: ""
                if (a.name == "xmlns") frame[""] = v
                else if (a.name.startsWith("xmlns:") && a.name.length > 6)
                    frame[a.name.substring(6)] = v
            }
            val pushed = frame.isNotEmpty()
            if (pushed) scope.add(frame)

            val (prefix, local) = splitNsPrefix(e.name)
            e.local = local
            e.nsUri = lookupNs(prefix, scope)

            for (a in e.attrs) {
                val (ap, al) = splitNsPrefix(a.name)
                a.local = al
                if (a.name == "xmlns" || ap == "xmlns") { a.nsUri = null; continue }
                if (ap.isEmpty()) { a.nsUri = null; continue }
                a.nsUri = lookupNs(ap, scope)
            }

            for (item in e.items) if (item is Element) resolveElement(item, scope)

            if (pushed) scope.removeAt(scope.size - 1)
        }

        /** Populate [Element.local], [Element.nsUri], [Attr.local], and
         *  [Attr.nsUri] on every node in [doc] per ADR 0002.
         *  Idempotent. Called automatically by [parse] / [parseXml] /
         *  [parseJson] / [parseYaml] / [parseToml] / [parseMd]. */
        fun resolveNamespaces(doc: CXDocument) {
            val scope = mutableListOf<MutableMap<String, String>>()
            for (n in doc.elements) if (n is Element) resolveElement(n, scope)
        }

        fun parse(cxStr: String): CXDocument {
            val data = CxLib.astBin(cxStr)
            val doc = BinaryDecoder.decodeAST(data)
            resolveNamespaces(doc)
            return doc
        }

        /**
         * Stream a CX string as a list of SAX-like StreamEvents.
         *
         * v3.4 (Phase 5 / CB-4): pulls events one-by-one via the handle
         * API. Replaces the prior eager-buffered cx_to_events_bin path.
         * For true pull-based streaming with caller-controlled
         * cancellation, use [EventStream.open] directly.
         */
        fun stream(cxStr: String): List<StreamEvent> {
            EventStream.open(cxStr).use { s ->
                val events = mutableListOf<StreamEvent>()
                for (ev in s) events.add(ev)
                return events
            }
        }

        // v3.4 (Phase 5 / CB-2): parse_<format> goes through
        // cx_<format>_to_ast_bin directly, avoiding the prior cx_<fmt>
        // _to_ast → JSON.parse → walk-dict pipeline.

        fun parseXml(s: String): CXDocument =
            BinaryDecoder.decodeAST(CxLib.xmlToAstBin(s)).also { resolveNamespaces(it) }

        fun parseJson(s: String): CXDocument =
            BinaryDecoder.decodeAST(CxLib.jsonToAstBin(s)).also { resolveNamespaces(it) }

        fun parseYaml(s: String): CXDocument =
            BinaryDecoder.decodeAST(CxLib.yamlToAstBin(s)).also { resolveNamespaces(it) }

        fun parseToml(s: String): CXDocument =
            BinaryDecoder.decodeAST(CxLib.tomlToAstBin(s)).also { resolveNamespaces(it) }

        fun parseMd(s: String): CXDocument =
            BinaryDecoder.decodeAST(CxLib.mdToAstBin(s)).also { resolveNamespaces(it) }

        /**
         * Deserialize a CX data string into native Kotlin types
         * (Map/List/scalar).
         *
         * v3.4: parses through CXDB v1 (cx_to_data_bin) directly into Kotlin
         * types — no JSON-string detour. Type fidelity preserved (integers
         * stay Long, floats stay Double, booleans stay Boolean, dates
         * round-trip as java.time.LocalDate, bytes as ByteArray). Closes
         * audit finding CB-3.
         */
        fun loads(cxStr: String): Any? = DataBin.decode(CxLib.toDataBin(cxStr))

        fun loadsXml(s: String): Any? {
            val jsonStr = CxLib.xmlToJson(s)
            return parseJsonValue(JsonParser.parseString(jsonStr))
        }

        fun loadsJson(s: String): Any? {
            val jsonStr = CxLib.jsonToJson(s)
            return parseJsonValue(JsonParser.parseString(jsonStr))
        }

        fun loadsYaml(s: String): Any? {
            val jsonStr = CxLib.yamlToJson(s)
            return parseJsonValue(JsonParser.parseString(jsonStr))
        }

        fun loadsToml(s: String): Any? {
            val jsonStr = CxLib.tomlToJson(s)
            return parseJsonValue(JsonParser.parseString(jsonStr))
        }

        fun loadsMd(s: String): Any? {
            val jsonStr = CxLib.mdToJson(s)
            return parseJsonValue(JsonParser.parseString(jsonStr))
        }

        /**
         * Serialize native Kotlin types (Map/List/scalar) to a CX string.
         *
         * v3.4: encodes the Kotlin value as CXDB v1 bytes directly, then
         * calls cx_from_data_bin to produce canonical CX. No JSON-string
         * detour; type fidelity preserved on round-trip with [loads].
         * Closes audit finding CB-3.
         */
        fun dumps(data: Any?): String = CxLib.fromDataBin(DataBin.encode(data))

        // ── JSON value parsing ─────────────────────────────────────────────────

        private fun parseJsonValue(el: JsonElement): Any? = when {
            el is JsonNull -> null
            el is JsonPrimitive && el.isBoolean -> el.asBoolean
            el is JsonPrimitive && el.isNumber -> {
                val n = el.asNumber
                val d = n.toDouble()
                val l = n.toLong()
                if (d == l.toDouble()) l else d
            }
            el is JsonPrimitive -> el.asString
            el is JsonObject -> {
                val map = mutableMapOf<String, Any?>()
                for ((k, v) in el.entrySet()) map[k] = parseJsonValue(v)
                map
            }
            el is JsonArray -> {
                el.map { parseJsonValue(it) }
            }
            else -> null
        }

        // ── Serialize native Kotlin values to JSON string ──────────────────────

        private fun nativeToJsonString(data: Any?): String = when (data) {
            null -> "null"
            is Boolean -> if (data) "true" else "false"
            is Int -> data.toString()
            is Long -> data.toString()
            is Double -> {
                val s = data.toString()
                if ('.' in s || 'e' in s.lowercase()) s else "$s.0"
            }
            is Float -> {
                val s = data.toDouble().toString()
                if ('.' in s || 'e' in s.lowercase()) s else "$s.0"
            }
            is Number -> data.toString()
            is String -> buildString {
                append('"')
                for (c in data) when (c) {
                    '"'  -> append("\\\"")
                    '\\' -> append("\\\\")
                    '\n' -> append("\\n")
                    '\r' -> append("\\r")
                    '\t' -> append("\\t")
                    else -> append(c)
                }
                append('"')
            }
            is Map<*, *> -> {
                data.entries.joinToString(",", "{", "}") { (k, v) ->
                    "${nativeToJsonString(k.toString())}:${nativeToJsonString(v)}"
                }
            }
            is List<*> -> data.joinToString(",", "[", "]") { nativeToJsonString(it) }
            is Array<*> -> data.joinToString(",", "[", "]") { nativeToJsonString(it) }
            else -> nativeToJsonString(data.toString())
        }

        // ── AST JSON → Document ────────────────────────────────────────────────

        internal fun docFromJson(d: JsonObject): CXDocument {
            val prolog = d.getAsJsonArray("prolog")
                ?.map { nodeFromJson(it.asJsonObject) }?.toMutableList()
                ?: mutableListOf()
            val elements = d.getAsJsonArray("elements")
                ?.map { nodeFromJson(it.asJsonObject) }?.toMutableList()
                ?: mutableListOf()
            val doctype: DoctypeDeclNode? = d.getAsJsonObject("doctype")?.let {
                DoctypeDeclNode(
                    name = it.get("name").asString,
                    externalId = it.get("externalID")?.takeUnless { e -> e is JsonNull },
                    intSubset = it.getAsJsonArray("intSubset")?.map { e -> e.toString() } ?: emptyList(),
                )
            }
            return CXDocument(elements = elements, prolog = prolog, doctype = doctype)
        }

        internal fun nodeFromJson(d: JsonObject): Node {
            return when (val t = d.get("type")?.asString ?: "") {
                "Element" -> Element(
                    name = d.get("name").asString,
                    anchor = d.get("anchor")?.takeUnless { it is JsonNull }?.asString,
                    merge = d.get("merge")?.takeUnless { it is JsonNull }?.asString,
                    dataType = d.get("dataType")?.takeUnless { it is JsonNull }?.asString,
                    attrs = d.getAsJsonArray("attrs")
                        ?.map { attrFromJson(it.asJsonObject) }?.toMutableList()
                        ?: mutableListOf(),
                    items = d.getAsJsonArray("items")
                        ?.map { nodeFromJson(it.asJsonObject) }?.toMutableList()
                        ?: mutableListOf(),
                )
                "Text" -> TextNode(d.get("value").asString)
                "Scalar" -> ScalarNode(
                    dataType = d.get("dataType").asString,
                    value = jsonScalarValue(d.get("value"), d.get("dataType").asString),
                )
                "Comment" -> CommentNode(d.get("value").asString)
                "RawText" -> RawTextNode(d.get("value").asString)
                "EntityRef" -> EntityRefNode(d.get("name").asString)
                "Alias" -> AliasNode(d.get("name").asString)
                "PI" -> PINode(
                    target = d.get("target").asString,
                    data = d.get("data")?.takeUnless { it is JsonNull }?.asString,
                )
                "XMLDecl" -> XMLDeclNode(
                    version = d.get("version")?.asString ?: "1.0",
                    encoding = d.get("encoding")?.takeUnless { it is JsonNull }?.asString,
                    standalone = d.get("standalone")?.takeUnless { it is JsonNull }?.asString,
                )
                "CXDirective" -> CXDirectiveNode(
                    attrs = d.getAsJsonArray("attrs")
                        ?.map { attrFromJson(it.asJsonObject) }
                        ?: emptyList(),
                )
                "DoctypeDecl" -> DoctypeDeclNode(
                    name = d.get("name").asString,
                    externalId = d.get("externalID")?.takeUnless { it is JsonNull },
                    intSubset = d.getAsJsonArray("intSubset")
                        ?.map { it.toString() } ?: emptyList(),
                )
                "BlockContent" -> BlockContentNode(
                    items = d.getAsJsonArray("items")
                        ?.map { nodeFromJson(it.asJsonObject) } ?: emptyList(),
                )
                else -> TextNode(d.toString())  // unknown — preserve as text
            }
        }

        private fun attrFromJson(a: JsonObject): Attr {
            val dt = a.get("dataType")?.takeUnless { it is JsonNull }?.asString
            val raw = a.get("value")
            val value = if (dt != null) jsonScalarValue(raw, dt) else {
                raw?.takeUnless { it is JsonNull }?.asString
            }
            return Attr(
                name = a.get("name").asString,
                value = value,
                dataType = dt,
            )
        }

        private fun jsonScalarValue(el: JsonElement?, dataType: String): Any? {
            if (el == null || el is JsonNull) return null
            if (el !is JsonPrimitive) return el.toString()
            return when (dataType) {
                "bool"     -> el.asBoolean
                "int"      -> el.asLong
                "float"    -> el.asDouble
                "null"     -> null
                else       -> el.asString
            }
        }
    }
}


// ── CX emitter ─────────────────────────────────────────────────────────────────

private val DATE_RE = Regex("""^\d{4}-\d{2}-\d{2}$""")
private val DATETIME_RE = Regex("""^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}""")
private val HEX_RE = Regex("""^0[xX][0-9a-fA-F]+$""")

private fun wouldAutotype(s: String): Boolean {
    if (' ' in s) return false
    if (HEX_RE.matches(s)) return true
    s.toLongOrNull()?.let { return true }
    if ('.' in s || 'e' in s.lowercase()) {
        s.toDoubleOrNull()?.let { return true }
    }
    if (s == "true" || s == "false" || s == "null") return true
    if (DATETIME_RE.containsMatchIn(s)) return true
    if (DATE_RE.matches(s)) return true
    return false
}

private fun cxChooseQuote(s: String): String = when {
    '\'' !in s -> "'$s'"
    '"' !in s  -> "\"$s\""
    "'''" !in s -> "'''$s'''"
    else -> "\"$s\""
}

private fun cxQuoteText(s: String): String {
    val needs = s.startsWith(' ') || s.endsWith(' ')
        || "  " in s || '\n' in s || '\t' in s
        || '[' in s || ']' in s || '&' in s
        || s.startsWith(':') || s.startsWith('\'') || s.startsWith('"')
        || wouldAutotype(s)
    return if (needs) cxChooseQuote(s) else s
}

private fun cxQuoteAttr(s: String): String {
    if (s.isEmpty() || ' ' in s || '\'' in s || '"' in s) return "'$s'"
    return s
}

private fun emitScalar(s: ScalarNode): String {
    val v = s.value ?: return "null"
    return when (v) {
        is Boolean -> if (v) "true" else "false"
        is Long    -> v.toString()
        is Int     -> v.toString()
        is Double  -> {
            val f = v.toString()
            if ('.' in f || 'e' in f.lowercase()) f else "$f.0"
        }
        is Float  -> {
            val f = v.toDouble().toString()
            if ('.' in f || 'e' in f.lowercase()) f else "$f.0"
        }
        else -> v.toString()
    }
}

// ── ID/IDREF helpers (ADR 0003) ───────────────────────────────────────────────

private fun findElementById(nodes: List<Node>, id: String): Element? {
    for (n in nodes) {
        if (n is Element) {
            if (n.id == id) return n
            val found = findElementById(n.items, id)
            if (found != null) return found
        }
    }
    return null
}

private fun collectElementsById(nodes: List<Node>, out: MutableMap<String, Element>) {
    for (n in nodes) {
        if (n is Element) {
            n.id?.let { out[it] = n }
            collectElementsById(n.items, out)
        }
    }
}

private fun emitAttr(a: Attr): String {
    if (a.isRef) {
        // ADR 0003 D1: bare `@id` round-trips verbatim.
        return "${a.name}=@${a.value ?: ""}"
    }
    return when (a.dataType) {
        "int"  -> "${a.name}=${(a.value as? Number)?.toLong() ?: a.value}"
        "float" -> {
            val d = (a.value as? Number)?.toDouble() ?: 0.0
            val f = d.toString()
            val v = if ('.' in f || 'e' in f.lowercase()) f else "$f.0"
            "${a.name}=$v"
        }
        "bool" -> "${a.name}=${if (a.value == true) "true" else "false"}"
        "null" -> "${a.name}=null"
        else -> {
            val s = a.value?.toString() ?: ""
            val startsAt = s.isNotEmpty() && s[0] == '@'
            val v = if (wouldAutotype(s) || startsAt) cxChooseQuote(s) else cxQuoteAttr(s)
            "${a.name}=$v"
        }
    }
}

private fun emitInline(node: Node): String = when (node) {
    is TextNode -> if (node.value.isNotBlank()) cxQuoteText(node.value) else ""
    is ScalarNode -> emitScalar(node)
    is EntityRefNode -> "&${node.name};"
    is RawTextNode -> "[#${node.value}#]"
    is Element -> emitElement(node, 0).trimEnd('\n')
    is BlockContentNode -> {
        val inner = node.items.joinToString("") { n ->
            when (n) {
                is TextNode -> n.value
                is Element -> emitElement(n, 0).trimEnd('\n')
                else -> ""
            }
        }
        "[|$inner|]"
    }
    else -> ""
}

internal fun emitElement(e: Element, depth: Int): String {
    val ind = "  ".repeat(depth)
    // ADR 0003 D1: body-position reference shape `[name @id]`.
    e.bodyRef?.let { return "$ind[${e.name} @$it]\n" }
    val hasChildElems = e.items.any { it is Element }
    val hasText = e.items.any { it is TextNode || it is ScalarNode || it is EntityRefNode || it is RawTextNode }
    val isMultiline = hasChildElems && !hasText

    val metaParts = mutableListOf<String>()
    e.anchor?.let { metaParts.add("&$it") }
    e.merge?.let { metaParts.add("*$it") }
    e.id?.let { metaParts.add("#$it") }
    e.dataType?.let { metaParts.add(":$it") }
    e.attrs.forEach { metaParts.add(emitAttr(it)) }
    val meta = if (metaParts.isNotEmpty()) " " + metaParts.joinToString(" ") else ""

    if (isMultiline) {
        val sb = StringBuilder()
        sb.append("$ind[${e.name}$meta\n")
        for (item in e.items) sb.append(emitNode(item, depth + 1))
        sb.append("$ind]\n")
        return sb.toString()
    }

    if (e.items.isEmpty() && meta.isEmpty()) {
        return "$ind[${e.name}]\n"
    }

    val bodyParts = e.items.map { emitInline(it) }.filter { it.isNotEmpty() }
    val body = bodyParts.joinToString(" ")
    val sep = if (body.isNotEmpty()) " " else ""
    return "$ind[${e.name}$meta$sep$body]\n"
}

internal fun emitNode(node: Node, depth: Int): String {
    val ind = "  ".repeat(depth)
    return when (node) {
        is Element -> emitElement(node, depth)
        is TextNode -> cxQuoteText(node.value)
        is ScalarNode -> emitScalar(node)
        is CommentNode -> "$ind[-${node.value}]\n"
        is RawTextNode -> "$ind[#${node.value}#]\n"
        is EntityRefNode -> "&${node.name};"
        is AliasNode -> "$ind[*${node.name}]\n"
        is BlockContentNode -> {
            val inner = node.items.joinToString("") { emitNode(it, 0) }
            "$ind[|$inner|]\n"
        }
        is PINode -> {
            val data = if (node.data != null) " ${node.data}" else ""
            "$ind[?${node.target}$data]\n"
        }
        is XMLDeclNode -> {
            val parts = mutableListOf("version=${node.version}")
            node.encoding?.let { parts.add("encoding=$it") }
            node.standalone?.let { parts.add("standalone=$it") }
            "[?xml ${parts.joinToString(" ")}]\n"
        }
        is CXDirectiveNode -> {
            val attrs = node.attrs.joinToString(" ") { "${it.name}=${cxQuoteAttr(it.value?.toString() ?: "")}" }
            "[?cx $attrs]\n"
        }
        is DoctypeDeclNode -> {
            val ext = buildString {
                val eid = node.externalId
                if (eid is Map<*, *>) {
                    val pub = eid["public"]
                    val sys = eid["system"]
                    if (pub != null) append(" PUBLIC '$pub' '${sys ?: ""}'")
                    else if (sys != null) append(" SYSTEM '$sys'")
                }
            }
            "[!DOCTYPE ${node.name}$ext]\n"
        }
        is InterpolationNode -> {
            // v3.5 (ADR 0016) [58] — `[?=EXPR]`.
            "$ind[?=${node.expr}]\n"
        }
        is EvalDirectiveNode -> {
            // v3.5 (ADR 0016) [59] — `[?Name attrs body]`. Grammar-order
            // canonical emission: attrs first, then body items.
            val attrsStr = node.attrs.joinToString(" ") {
                "${it.name}=${cxQuoteAttr(it.value?.toString() ?: "")}"
            }
            val bodyStr = node.items.joinToString("") { emitNode(it, 0) }.trimEnd('\n')
            val sepA = if (attrsStr.isEmpty()) "" else " "
            val sepB = if (bodyStr.isEmpty()) "" else " "
            "$ind[?${node.name}$sepA$attrsStr$sepB$bodyStr]\n"
        }
    }
}

internal fun emitDoc(doc: CXDocument): String {
    val sb = StringBuilder()
    for (node in doc.prolog) sb.append(emitNode(node, 0))
    doc.doctype?.let { sb.append(emitNode(it, 0)) }
    for (node in doc.elements) sb.append(emitNode(node, 0))
    return sb.toString().trimEnd('\n')
}
