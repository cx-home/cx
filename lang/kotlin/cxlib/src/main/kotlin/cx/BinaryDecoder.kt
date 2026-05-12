package cx

import java.nio.ByteBuffer
import java.nio.ByteOrder

// ── StreamEvent ───────────────────────────────────────────────────────────────

data class StreamEvent(
    val type: String,
    val name: String? = null,
    val anchor: String? = null,
    val dataType: String? = null,
    val merge: String? = null,
    val attrs: List<Attr> = emptyList(),
    val value: Any? = null,
    val target: String? = null,
    val data: String? = null,
)

// ── BufReader ─────────────────────────────────────────────────────────────────

private class BufReader(data: ByteArray) {
    private val buf: ByteBuffer = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN)

    fun u8(): Int = buf.get().toInt() and 0xFF

    fun u16(): Int = buf.short.toInt() and 0xFFFF

    fun u32(): Int = buf.int   // still LE; we treat as unsigned via toLong() where needed

    fun str(): String {
        val len = u32()
        val bytes = ByteArray(len)
        buf.get(bytes)
        return String(bytes, Charsets.UTF_8)
    }

    fun optStr(): String? {
        val flag = u8()
        return if (flag == 0) null else str()
    }
}

// ── scalar coercion ───────────────────────────────────────────────────────────

private fun coerce(typeStr: String, valueStr: String): Any? = when (typeStr) {
    "int"   -> valueStr.toLong()
    "float" -> valueStr.toDouble()
    "bool"  -> valueStr == "true"
    "null"  -> null
    else    -> valueStr
}

// ── BinaryDecoder ─────────────────────────────────────────────────────────────

object BinaryDecoder {

    // ── AST ───────────────────────────────────────────────────────────────────

    fun decodeAST(data: ByteArray): CXDocument {
        val buf = BufReader(data)
        val version = buf.u8()
        val prologCount = buf.u16()
        val prolog = (0 until prologCount).map { readNode(buf, version) }.toMutableList()
        val elemCount = buf.u16()
        val elements = (0 until elemCount).map { readNode(buf, version) }.toMutableList()
        return CXDocument(elements = elements, prolog = prolog)
    }

    private fun readAttr(buf: BufReader, version: Int): Attr {
        val name     = buf.str()
        val valueStr = buf.str()
        val typeStr  = buf.str()
        val dt = if (typeStr == "string") null else typeStr
        val isRef = version >= 2 && buf.u8() == 1
        // v3.5 (ADR 0016): BracketBody attribute body tail — format version 5.
        val body: List<Node>? = if (version >= 5) {
            val flag = buf.u8()
            when (flag) {
                0 -> null
                1 -> {
                    val count = buf.u16()
                    (0 until count).map { readNode(buf, version) }
                }
                else -> throw RuntimeException("ast_bin: invalid attr body_flag $flag")
            }
        } else null
        return Attr(name = name, value = coerce(typeStr, valueStr),
                    dataType = dt, isRef = isRef, body = body)
    }

    private fun readNode(buf: BufReader, version: Int): Node {
        return when (val tid = buf.u8()) {
            0x01 -> {
                val name      = buf.str()
                val anchor    = buf.optStr()
                val dataType  = buf.optStr()
                val merge     = buf.optStr()
                val idDecl    = if (version >= 2) buf.optStr() else null
                val bodyRef   = if (version >= 3) buf.optStr() else null
                val attrCount = buf.u16()
                val attrs     = (0 until attrCount).map { readAttr(buf, version) }.toMutableList()
                val childCount = buf.u16()
                val items     = (0 until childCount).map { readNode(buf, version) }.toMutableList()
                val el = Element(name = name, anchor = anchor, merge = merge, dataType = dataType,
                        attrs = attrs, items = items)
                el.id = idDecl
                el.bodyRef = bodyRef
                el
            }
            0x02 -> TextNode(buf.str())
            0x03 -> {
                val typeStr  = buf.str()
                val valueStr = buf.str()
                ScalarNode(dataType = typeStr, value = coerce(typeStr, valueStr))
            }
            0x04 -> CommentNode(buf.str())
            0x05 -> RawTextNode(buf.str())
            0x06 -> EntityRefNode(buf.str())
            0x07 -> AliasNode(buf.str())
            0x08 -> {
                val target = buf.str()
                val data   = buf.optStr()
                PINode(target = target, data = data)
            }
            0x09 -> {
                val declVersion = buf.str()
                val encoding    = buf.optStr()
                val standalone  = buf.optStr()
                XMLDeclNode(version = declVersion, encoding = encoding, standalone = standalone)
            }
            0x0A -> {
                val attrCount = buf.u16()
                val attrs = (0 until attrCount).map { readAttr(buf, version) }
                if (version >= 4) {
                    // v0.6.0 — directive `&anchor` + nested children.
                    val anchor = buf.optStr()
                    val itemCount = buf.u16()
                    val items = (0 until itemCount).map { readNode(buf, version) }
                    CXDirectiveNode(attrs = attrs, anchor = anchor, items = items)
                } else {
                    CXDirectiveNode(attrs = attrs)
                }
            }
            0x0C -> {
                val childCount = buf.u16()
                val items = (0 until childCount).map { readNode(buf, version) }
                BlockContentNode(items = items)
            }
            0x0D -> {
                // v3.5 (ADR 0016) [58] — `[?=EXPR]`.
                InterpolationNode(expr = buf.str())
            }
            0x0E -> {
                // v3.5 (ADR 0016) [59] — `[?Name attrs body]`.
                val name = buf.str()
                val attrCount = buf.u16()
                val attrs = (0 until attrCount).map { readAttr(buf, version) }
                val itemCount = buf.u16()
                val items = (0 until itemCount).map { readNode(buf, version) }
                EvalDirectiveNode(name = name, attrs = attrs, items = items)
            }
            0xFF -> TextNode("")   // skip marker — no payload
            else  -> TextNode("")  // unknown type — no payload assumed
        }
    }

    // ── Events ────────────────────────────────────────────────────────────────

    private fun readOneEvent(buf: BufReader): StreamEvent = when (val tid = buf.u8()) {
        0x01 -> StreamEvent(type = "StartDoc")
        0x02 -> StreamEvent(type = "EndDoc")
        0x03 -> {
            val name     = buf.str()
            val anchor   = buf.optStr()
            val dataType = buf.optStr()
            val merge    = buf.optStr()
            val attrCount = buf.u16()
            val attrs = (0 until attrCount).map {
                val n  = buf.str()
                val vs = buf.str()
                val t  = buf.str()
                val dt = if (t == "string") null else t
                val isRef = buf.u8() == 1  // v3.4 (ADR 0003): events buffer follows ast_bin v2.
                // v3.5 (ADR 0016): BracketBody attr body tail (events buffer
                // follows ast_bin v5 attr layout). Body items are skipped.
                val bodyFlag = buf.u8()
                if (bodyFlag == 1) {
                    val count = buf.u16()
                    for (k in 0 until count) readNode(buf, 5)
                } else if (bodyFlag != 0) {
                    throw RuntimeException("ast_bin: invalid attr body_flag $bodyFlag")
                }
                Attr(name = n, value = coerce(t, vs), dataType = dt, isRef = isRef)
            }
            StreamEvent(type = "StartElement", name = name, anchor = anchor,
                        dataType = dataType, merge = merge, attrs = attrs)
        }
        0x04 -> StreamEvent(type = "EndElement", name = buf.str())
        0x05 -> StreamEvent(type = "Text",       value = buf.str())
        0x06 -> {
            val typeStr  = buf.str()
            val valueStr = buf.str()
            StreamEvent(type = "Scalar", dataType = typeStr,
                        value = coerce(typeStr, valueStr))
        }
        0x07 -> StreamEvent(type = "Comment",   value = buf.str())
        0x08 -> {
            val target = buf.str()
            val data   = buf.optStr()
            StreamEvent(type = "PI", target = target, data = data)
        }
        0x09 -> StreamEvent(type = "EntityRef", value = buf.str())
        0x0A -> StreamEvent(type = "RawText",   value = buf.str())
        0x0B -> StreamEvent(type = "Alias",     value = buf.str())
        else  -> StreamEvent(type = "Unknown")
    }

    fun decodeEvents(data: ByteArray): List<StreamEvent> {
        val buf = BufReader(data)
        val count = buf.u32()
        return List(count) { readOneEvent(buf) }
    }

    /** Decode a single event from a payload (no [u32 count] prefix).
     *  Used by EventStream for per-event decoding (Phase 5 / CB-4). */
    fun decodeOneEvent(payload: ByteArray): StreamEvent =
        readOneEvent(BufReader(payload))

    // ── Binary AST encoder (Phase 5 / CB-1) ───────────────────────────────────
    // Inverse of decodeAST. Produces a FRAMED [u32 LE size][payload] buffer
    // matching V's emit_ast_bin output. Used by CXDocument.toAstBin().

    private class BufWriter {
        val buf = java.io.ByteArrayOutputStream(256)
        fun u8(v: Int)  { buf.write(v and 0xFF) }
        fun u16(v: Int) { buf.write(v and 0xFF); buf.write((v ushr 8) and 0xFF) }
        fun u32(v: Int) {
            buf.write(v and 0xFF)
            buf.write((v ushr 8)  and 0xFF)
            buf.write((v ushr 16) and 0xFF)
            buf.write((v ushr 24) and 0xFF)
        }
        fun str(s: String) {
            val enc = s.toByteArray(Charsets.UTF_8)
            u32(enc.size)
            buf.write(enc, 0, enc.size)
        }
        fun optStr(s: String?) { if (s == null) u8(0) else { u8(1); str(s) } }
        fun toBytes(): ByteArray = buf.toByteArray()
    }

    private fun scalarValueStr(dt: String, v: Any?): String = when {
        v == null || dt == "null" -> "null"
        v is Boolean -> if (v) "true" else "false"
        v is String  -> v
        else         -> v.toString()
    }

    private fun encAttr(w: BufWriter, a: Attr) {
        val dt: String = a.dataType?.takeIf { it.isNotEmpty() } ?: "string"
        w.str(a.name)
        w.str(scalarValueStr(dt, a.value))
        w.str(dt)
        // v3.4 (ADR 0003): is_ref flag — format version 2.
        w.u8(if (a.isRef) 1 else 0)
        // v3.5 (ADR 0016): BracketBody attribute body tail — format version 5.
        val body = a.body
        if (body == null) {
            w.u8(0)
        } else {
            w.u8(1)
            w.u16(body.size)
            for (n in body) encNode(w, n)
        }
    }

    private fun encNode(w: BufWriter, n: Node) {
        when (n) {
            is Element -> {
                w.u8(0x01)
                w.str(n.name)
                w.optStr(n.anchor)
                w.optStr(n.dataType)
                w.optStr(n.merge)
                // v3.4 (ADR 0003): syntactic ID declaration — format version 2.
                w.optStr(n.id)
                // ADR 0003 D1: body-position reference — format version 3 (Phase 7.70).
                w.optStr(n.bodyRef)
                w.u16(n.attrs.size)
                for (a in n.attrs) encAttr(w, a)
                w.u16(n.items.size)
                for (c in n.items) encNode(w, c)
            }
            is TextNode    -> { w.u8(0x02); w.str(n.value) }
            is ScalarNode  -> {
                w.u8(0x03); w.str(n.dataType); w.str(scalarValueStr(n.dataType, n.value))
            }
            is CommentNode -> { w.u8(0x04); w.str(n.value) }
            is RawTextNode -> { w.u8(0x05); w.str(n.value) }
            is EntityRefNode -> { w.u8(0x06); w.str(n.name) }
            is AliasNode     -> { w.u8(0x07); w.str(n.name) }
            is PINode -> {
                w.u8(0x08); w.str(n.target); w.optStr(n.data)
            }
            is XMLDeclNode -> {
                w.u8(0x09); w.str(n.version); w.optStr(n.encoding); w.optStr(n.standalone)
            }
            is CXDirectiveNode -> {
                w.u8(0x0A); w.u16(n.attrs.size)
                for (a in n.attrs) encAttr(w, a)
                // v0.6.0 (format version 4) — directive `&anchor` + nested children.
                w.optStr(n.anchor)
                w.u16(n.items.size)
                for (c in n.items) encNode(w, c)
            }
            is BlockContentNode -> {
                w.u8(0x0C); w.u16(n.items.size)
                for (it in n.items) encNode(w, it)
            }
            is InterpolationNode -> {
                // v3.5 (ADR 0016) [58] — `[?=EXPR]`.
                w.u8(0x0D); w.str(n.expr)
            }
            is EvalDirectiveNode -> {
                // v3.5 (ADR 0016) [59] — `[?Name attrs body]`.
                w.u8(0x0E); w.str(n.name)
                w.u16(n.attrs.size)
                for (a in n.attrs) encAttr(w, a)
                w.u16(n.items.size)
                for (it in n.items) encNode(w, it)
            }
            else -> w.u8(0xFF) // DTD / unknown — skip marker
        }
    }

    /** Encode a CXDocument to a FRAMED [u32 LE size][payload] AST bin
     *  ByteArray suitable for direct hand-off to cx_ast_bin_to_<format>. */
    fun encodeAST(doc: CXDocument): ByteArray {
        val w = BufWriter()
        w.u8(0x05) // version — v0.6.0 (ADR 0016 grammar v3.5):
                   //   * CXDirective &anchor + items (format v4)
                   //   * Interpolation (0x0D) + EvalDirective (0x0E) tags
                   //   * BracketBody attribute body tail (format v5)
        w.u16(doc.prolog.size)
        for (n in doc.prolog) encNode(w, n)
        w.u16(doc.elements.size)
        for (n in doc.elements) encNode(w, n)
        val payload = w.toBytes()
        val framed = ByteBuffer.allocate(4 + payload.size).order(ByteOrder.LITTLE_ENDIAN)
        framed.putInt(payload.size)
        framed.put(payload)
        return framed.array()
    }
}
