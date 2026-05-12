package cx;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/**
 * Decoder for the compact binary wire format produced by cx_to_ast_bin and
 * cx_to_events_bin.
 *
 * All integers are little-endian.
 *
 * String encoding:   u32(byte_len) + raw UTF-8 bytes (no null terminator)
 * OptStr encoding:   u8(0=absent | 1=present) + str if present
 * Attr encoding:     str:name + str:value_str + str:inferred_type
 */
public class BinaryDecoder {

    // ── Buffer reader ─────────────────────────────────────────────────────────

    static final class BufReader {
        private final ByteBuffer buf;

        BufReader(byte[] data) {
            this.buf = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN);
        }

        int u8() {
            return buf.get() & 0xFF;
        }

        int u16() {
            return buf.getShort() & 0xFFFF;
        }

        long u32() {
            return buf.getInt() & 0xFFFFFFFFL;
        }

        String str() {
            int len = (int) u32();
            byte[] bytes = new byte[len];
            buf.get(bytes);
            return new String(bytes, StandardCharsets.UTF_8);
        }

        String optStr() {
            int flag = u8();
            if (flag == 0) return null;
            return str();
        }
    }

    // ── Scalar coercion ───────────────────────────────────────────────────────

    static Object coerce(String inferredType, String valueStr) {
        return switch (inferredType) {
            case "int"    -> Long.parseLong(valueStr);
            case "float"  -> Double.parseDouble(valueStr);
            case "bool"   -> "true".equals(valueStr);
            case "null"   -> null;
            default       -> valueStr;  // string / date / datetime / bytes
        };
    }

    // ── Attr reader ───────────────────────────────────────────────────────────

    static Attr readAttr(BufReader b, int version) {
        String name      = b.str();
        String valueStr  = b.str();
        String inferType = b.str();
        Object value     = coerce(inferType, valueStr);
        // Only carry dataType forward when it's not plain "string"
        String dataType  = "string".equals(inferType) ? null : inferType;
        boolean isRef    = (version >= 2) && (b.u8() == 1);
        Attr a = new Attr(name, value, dataType);
        a.isRef = isRef;
        if (version >= 5) {
            // v3.5 (ADR 0016): BracketBody attribute body tail.
            int flag = b.u8();
            if (flag == 1) {
                int count = b.u16();
                List<Node> body = new ArrayList<>(count);
                for (int i = 0; i < count; i++) body.add(readNode(b, version));
                a.body = body;
            } else if (flag != 0) {
                throw new RuntimeException("ast_bin: invalid attr body_flag " + flag);
            }
        }
        return a;
    }

    // ── AST node reader ───────────────────────────────────────────────────────

    static Node readNode(BufReader b, int version) {
        int tid = b.u8();
        return switch (tid) {
            case 0x01 -> {
                String     name     = b.str();
                String     anchor   = b.optStr();
                String     dataType = b.optStr();
                String     merge    = b.optStr();
                String     idDecl   = (version >= 2) ? b.optStr() : null;
                String     bodyRef  = (version >= 3) ? b.optStr() : null;
                int        nAttrs   = b.u16();
                List<Attr> attrs = new ArrayList<>(nAttrs);
                for (int i = 0; i < nAttrs; i++) attrs.add(readAttr(b, version));
                int        nItems   = b.u16();
                List<Node> items    = new ArrayList<>(nItems);
                for (int i = 0; i < nItems; i++) items.add(readNode(b, version));
                Element e = new Element(name);
                e.anchor   = anchor;
                e.dataType = dataType;
                e.merge    = merge;
                e.id       = idDecl;
                e.bodyRef  = bodyRef;
                e.attrs    = attrs;
                e.items    = items;
                yield e;
            }
            case 0x02 -> new TextNode(b.str());
            case 0x03 -> {
                String dt  = b.str();
                String val = b.str();
                yield new ScalarNode(dt, coerce(dt, val));
            }
            case 0x04 -> new CommentNode(b.str());
            case 0x05 -> new RawTextNode(b.str());
            case 0x06 -> new EntityRefNode(b.str());
            case 0x07 -> new AliasNode(b.str());
            case 0x08 -> {
                String target = b.str();
                String data   = b.optStr();
                yield new PINode(target, data);
            }
            case 0x09 -> {
                String declVersion = b.str();
                String encoding    = b.optStr();
                String standalone  = b.optStr();
                yield new XMLDeclNode(declVersion, encoding, standalone);
            }
            case 0x0A -> {
                int nAttrs = b.u16();
                List<Attr> attrs = new ArrayList<>(nAttrs);
                for (int i = 0; i < nAttrs; i++) attrs.add(readAttr(b, version));
                // v0.6.0 (format version 4) — directive `&anchor` + nested
                // children (spec/schema.md §8 standalone fragment form).
                // v1-v3 buffers stop after attrs[].
                if (version >= 4) {
                    String anchor = b.optStr();
                    int nItems = b.u16();
                    List<Node> items = new ArrayList<>(nItems);
                    for (int i = 0; i < nItems; i++) items.add(readNode(b, version));
                    yield new CXDirectiveNode(attrs, anchor, items);
                }
                yield new CXDirectiveNode(attrs);
            }
            case 0x0C -> {
                int        nItems = b.u16();
                List<Node> items  = new ArrayList<>(nItems);
                for (int i = 0; i < nItems; i++) items.add(readNode(b, version));
                yield new BlockContentNode(items);
            }
            case 0x0D -> {
                // v3.5 (ADR 0016) [58] — `[?=EXPR]`.
                yield new InterpolationNode(b.str());
            }
            case 0x0E -> {
                // v3.5 (ADR 0016) [59] — `[?Name attrs body]`.
                String     name   = b.str();
                int        nAttrs = b.u16();
                List<Attr> attrs  = new ArrayList<>(nAttrs);
                for (int i = 0; i < nAttrs; i++) attrs.add(readAttr(b, version));
                int        nItems = b.u16();
                List<Node> items  = new ArrayList<>(nItems);
                for (int i = 0; i < nItems; i++) items.add(readNode(b, version));
                yield new EvalDirectiveNode(name, attrs, items);
            }
            // 0xFF = skip/DTD, no payload
            default -> new TextNode("");
        };
    }

    // ── Public: decode AST ────────────────────────────────────────────────────

    /**
     * Decode a binary AST payload (the bytes after the 4-byte length prefix)
     * into a {@link CXDocument}.
     *
     * Format:
     *   u8:  version (=1)
     *   u16: prolog_count  + prolog nodes
     *   u16: element_count + element nodes
     */
    public static CXDocument decodeAST(byte[] data) {
        BufReader b = new BufReader(data);
        int version = b.u8();

        int nProlog = b.u16();
        List<Node> prolog = new ArrayList<>(nProlog);
        for (int i = 0; i < nProlog; i++) prolog.add(readNode(b, version));

        int nElements = b.u16();
        List<Node> elements = new ArrayList<>(nElements);
        for (int i = 0; i < nElements; i++) elements.add(readNode(b, version));

        CXDocument doc = new CXDocument();
        doc.prolog   = prolog;
        doc.elements = elements;
        return doc;
    }

    // ── Public: decode Events ─────────────────────────────────────────────────

    /**
     * Decode a binary events payload (the bytes after the 4-byte length prefix)
     * into a list of {@link StreamEvent}s.
     *
     * Format:
     *   u32: event_count
     *   For each event:
     *     u8: type_id  (see binary.py / task spec for mapping)
     */
    static StreamEvent readOneEvent(BufReader b) {
        int tid = b.u8();
        return switch (tid) {
            case 0x01 -> new StreamEvent("StartDoc");
            case 0x02 -> new StreamEvent("EndDoc");
            case 0x03 -> {
                StreamEvent se = new StreamEvent("StartElement");
                se.name     = b.str();
                se.anchor   = b.optStr();
                se.dataType = b.optStr();
                se.merge    = b.optStr();
                int nAttrs  = b.u16();
                se.attrs    = new ArrayList<>(nAttrs);
                for (int j = 0; j < nAttrs; j++) {
                    String aName   = b.str();
                    String aValStr = b.str();
                    String aType   = b.str();
                    Object aVal    = coerce(aType, aValStr);
                    String aDt     = "string".equals(aType) ? null : aType;
                    int    aRefFlag = b.u8();  // v3.4 (ADR 0003): events buffer follows ast_bin v2.
                    // v3.5 (ADR 0016): BracketBody attr body tail (events buffer
                    // follows ast_bin v5 attr layout). Body items are skipped.
                    int bodyFlag = b.u8();
                    if (bodyFlag == 1) {
                        int count = b.u16();
                        for (int k = 0; k < count; k++) readNode(b, 5);
                    } else if (bodyFlag != 0) {
                        throw new RuntimeException("ast_bin: invalid attr body_flag " + bodyFlag);
                    }
                    Attr attr = new Attr(aName, aVal, aDt);
                    attr.isRef = (aRefFlag == 1);
                    se.attrs.add(attr);
                }
                yield se;
            }
            case 0x04 -> {
                StreamEvent se = new StreamEvent("EndElement");
                se.name = b.str();
                yield se;
            }
            case 0x05 -> { StreamEvent se = new StreamEvent("Text");    se.value = b.str(); yield se; }
            case 0x06 -> {
                StreamEvent se = new StreamEvent("Scalar");
                String dt = b.str();
                se.dataType = dt;
                se.value    = coerce(dt, b.str());
                yield se;
            }
            case 0x07 -> { StreamEvent se = new StreamEvent("Comment"); se.value = b.str(); yield se; }
            case 0x08 -> {
                StreamEvent se = new StreamEvent("PI");
                se.target = b.str();
                se.data   = b.optStr();
                yield se;
            }
            case 0x09 -> { StreamEvent se = new StreamEvent("EntityRef"); se.value = b.str(); yield se; }
            case 0x0A -> { StreamEvent se = new StreamEvent("RawText");   se.value = b.str(); yield se; }
            case 0x0B -> { StreamEvent se = new StreamEvent("Alias");     se.value = b.str(); yield se; }
            default   -> new StreamEvent("Unknown");
        };
    }

    public static List<StreamEvent> decodeEvents(byte[] data) {
        BufReader b = new BufReader(data);
        long n = b.u32();
        List<StreamEvent> events = new ArrayList<>((int) n);
        for (long i = 0; i < n; i++) events.add(readOneEvent(b));
        return events;
    }

    /** Decode a single event from a payload (no [u32 count] prefix).
     *  Used by the handle-based stream (Phase 5 / CB-4). */
    public static StreamEvent decodeOneEvent(byte[] payload) {
        return readOneEvent(new BufReader(payload));
    }

    // ── Binary AST encoder (Phase 5 / CB-1) ──────────────────────────────────
    // Inverse of decodeAST. Produces a FRAMED [u32 LE size][payload] buffer
    // that matches V's emit_ast_bin output. Used by CXDocument.toAstBin.

    private static final class BufWriter {
        private final java.io.ByteArrayOutputStream buf = new java.io.ByteArrayOutputStream(256);
        void u8(int v)  { buf.write(v & 0xFF); }
        void u16(int v) { buf.write(v & 0xFF); buf.write((v >>> 8) & 0xFF); }
        void u32(int v) {
            buf.write(v & 0xFF);
            buf.write((v >>> 8)  & 0xFF);
            buf.write((v >>> 16) & 0xFF);
            buf.write((v >>> 24) & 0xFF);
        }
        void str(String s) {
            byte[] enc = s.getBytes(StandardCharsets.UTF_8);
            u32(enc.length);
            buf.write(enc, 0, enc.length);
        }
        void optStr(String s) { if (s == null) u8(0); else { u8(1); str(s); } }
        byte[] toBytes() { return buf.toByteArray(); }
    }

    private static String scalarValueStr(String dt, Object v) {
        if (v == null || "null".equals(dt)) return "null";
        if (v instanceof Boolean b) return b ? "true" : "false";
        if (v instanceof String s) return s;
        return String.valueOf(v);
    }

    private static void encAttr(BufWriter w, Attr a) {
        String dt = (a.dataType == null || a.dataType.isEmpty()) ? "string" : a.dataType;
        w.str(a.name);
        w.str(scalarValueStr(dt, a.value));
        w.str(dt);
        // v3.4 (ADR 0003): is_ref flag — format version 2.
        w.u8(a.isRef ? 1 : 0);
        // v3.5 (ADR 0016): BracketBody attribute body tail — format version 5.
        if (a.body == null) {
            w.u8(0);
        } else {
            w.u8(1);
            w.u16(a.body.size());
            for (Node n : a.body) encNode(w, n);
        }
    }

    private static void encNode(BufWriter w, Node n) {
        if (n instanceof Element e) {
            w.u8(0x01);
            w.str(e.name);
            w.optStr(e.anchor);
            w.optStr(e.dataType);
            w.optStr(e.merge);
            // v3.4 (ADR 0003): syntactic ID declaration — format version 2.
            w.optStr(e.id);
            // v3.4 (ADR 0003 D1): body-position reference — format version 3.
            w.optStr(e.bodyRef);
            w.u16(e.attrs.size());
            for (Attr a : e.attrs) encAttr(w, a);
            w.u16(e.items.size());
            for (Node c : e.items) encNode(w, c);
        } else if (n instanceof TextNode t) {
            w.u8(0x02); w.str(t.value);
        } else if (n instanceof ScalarNode s) {
            w.u8(0x03);
            w.str(s.dataType);
            w.str(scalarValueStr(s.dataType, s.value));
        } else if (n instanceof CommentNode c) {
            w.u8(0x04); w.str(c.value);
        } else if (n instanceof RawTextNode r) {
            w.u8(0x05); w.str(r.value);
        } else if (n instanceof EntityRefNode er) {
            w.u8(0x06); w.str(er.name);
        } else if (n instanceof AliasNode al) {
            w.u8(0x07); w.str(al.name);
        } else if (n instanceof PINode pi) {
            w.u8(0x08); w.str(pi.target); w.optStr(pi.data);
        } else if (n instanceof XMLDeclNode xd) {
            w.u8(0x09); w.str(xd.version); w.optStr(xd.encoding); w.optStr(xd.standalone);
        } else if (n instanceof CXDirectiveNode cd) {
            w.u8(0x0A);
            w.u16(cd.attrs.size());
            for (Attr a : cd.attrs) encAttr(w, a);
            // v0.6.0 (format version 4) — directive `&anchor` + nested children.
            w.optStr(cd.anchor);
            w.u16(cd.items.size());
            for (Node it : cd.items) encNode(w, it);
        } else if (n instanceof BlockContentNode bc) {
            w.u8(0x0C); w.u16(bc.items.size());
            for (Node it : bc.items) encNode(w, it);
        } else if (n instanceof InterpolationNode in) {
            // v3.5 (ADR 0016) [58] — `[?=EXPR]`.
            w.u8(0x0D); w.str(in.expr);
        } else if (n instanceof EvalDirectiveNode ed) {
            // v3.5 (ADR 0016) [59] — `[?Name attrs body]`.
            w.u8(0x0E); w.str(ed.name);
            w.u16(ed.attrs.size());
            for (Attr a : ed.attrs) encAttr(w, a);
            w.u16(ed.items.size());
            for (Node it : ed.items) encNode(w, it);
        } else {
            // DTD / unknown — emit 0xFF skip marker.
            w.u8(0xFF);
        }
    }

    /** Encode a CXDocument to a FRAMED [u32 LE size][payload] binary AST
     *  buffer suitable for direct hand-off to cx_ast_bin_to_<format>. */
    public static byte[] encodeAST(CXDocument doc) {
        BufWriter w = new BufWriter();
        w.u8(0x05); // version — bumped 4 → 5 for v0.6.0 grammar v3.5
                    //           (Interpolation/EvalDirective tags +
                    //            BracketBody attr body tail, ADR 0016)
        w.u16(doc.prolog.size());
        for (Node n : doc.prolog) encNode(w, n);
        w.u16(doc.elements.size());
        for (Node n : doc.elements) encNode(w, n);
        byte[] payload = w.toBytes();
        ByteBuffer bb = ByteBuffer.allocate(4 + payload.length).order(ByteOrder.LITTLE_ENDIAN);
        bb.putInt(payload.length);
        bb.put(payload);
        return bb.array();
    }
}
