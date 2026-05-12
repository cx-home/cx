using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace CX;

/// <summary>
/// Decoder for the compact binary wire format produced by cx_to_ast_bin and
/// cx_to_events_bin.  All integers are little-endian.
/// </summary>
public static class BinaryDecoder
{
    // ── public entry points ───────────────────────────────────────────────────

    /// <summary>Decode a binary AST payload (the bytes AFTER the 4-byte length prefix)
    /// into a <see cref="CXDocument"/>.</summary>
    public static CXDocument DecodeAST(byte[] data)
    {
        var r = new BufReader(data);
        byte version = r.U8();

        int prologCount = r.U16();
        var prolog = new List<Node>(prologCount);
        for (int i = 0; i < prologCount; i++)
            prolog.Add(ReadNode(r, version));

        int elemCount = r.U16();
        var elements = new List<Node>(elemCount);
        for (int i = 0; i < elemCount; i++)
            elements.Add(ReadNode(r, version));

        return new CXDocument { Prolog = prolog, Elements = elements };
    }

    private static StreamEvent ReadOneEvent(BufReader r)
    {
        byte tid = r.U8();
        var ev = new StreamEvent { Type = EventTypeName(tid) };
        switch (tid)
        {
            case 0x01: case 0x02: break;
            case 0x03:
                ev.Name     = r.Str();
                ev.Anchor   = r.OptStr();
                ev.DataType = r.OptStr();
                ev.Merge    = r.OptStr();
                // Events buffer follows the current ast_bin attr layout (v5).
                ev.Attrs    = ReadAttrs(r, r.U16(), version: 5);
                break;
            case 0x04: ev.Name = r.Str(); break;
            case 0x05: case 0x07: case 0x0A: ev.Value = r.Str(); break;
            case 0x06:
            {
                string dt = r.Str();
                ev.DataType = dt;
                ev.Value = Coerce(dt, r.Str());
                break;
            }
            case 0x08:
                ev.Target = r.Str();
                ev.Data   = r.OptStr();
                break;
            case 0x09: case 0x0B: ev.Value = r.Str(); break;
        }
        return ev;
    }

    /// <summary>Decode a binary events payload (the bytes AFTER the 4-byte length prefix)
    /// into a list of <see cref="StreamEvent"/>.</summary>
    public static List<StreamEvent> DecodeEvents(byte[] data)
    {
        var r = new BufReader(data);
        uint count = r.U32();
        var events = new List<StreamEvent>((int)count);
        for (uint i = 0; i < count; i++) events.Add(ReadOneEvent(r));
        return events;
    }

    /// <summary>Decode a single event from a payload (no [u32 count] prefix).
    /// Used by the handle-based EventStream (Phase 5 / CB-4).</summary>
    public static StreamEvent DecodeOneEvent(byte[] payload)
    {
        return ReadOneEvent(new BufReader(payload));
    }

    // ── Binary AST encoder (Phase 5 / CB-1) ──────────────────────────────────
    // Inverse of DecodeAST. Produces a FRAMED [u32 LE size][payload] buffer
    // matching V's emit_ast_bin output. Used by CXDocument.ToAstBin.

    private sealed class BufWriter
    {
        private readonly System.IO.MemoryStream _buf = new(256);
        public void U8(int v) => _buf.WriteByte((byte)(v & 0xFF));
        public void U16(int v) { U8(v & 0xFF); U8((v >> 8) & 0xFF); }
        public void U32(uint v)
        {
            U8((int)(v & 0xFF));
            U8((int)((v >> 8)  & 0xFF));
            U8((int)((v >> 16) & 0xFF));
            U8((int)((v >> 24) & 0xFF));
        }
        public void Str(string s)
        {
            byte[] enc = Encoding.UTF8.GetBytes(s);
            U32((uint)enc.Length);
            _buf.Write(enc, 0, enc.Length);
        }
        public void OptStr(string? s) { if (s is null) U8(0); else { U8(1); Str(s); } }
        public byte[] ToBytes() => _buf.ToArray();
    }

    private static string ScalarValueStr(string dt, object? v)
    {
        if (v is null || dt == "null") return "null";
        if (v is bool b) return b ? "true" : "false";
        if (v is string s) return s;
        return System.Convert.ToString(v, System.Globalization.CultureInfo.InvariantCulture) ?? "";
    }

    private static void EncAttr(BufWriter w, Attr a)
    {
        string dt = string.IsNullOrEmpty(a.DataType) ? "string" : a.DataType!;
        w.Str(a.Name);
        w.Str(ScalarValueStr(dt, a.Value));
        w.Str(dt);
        // v3.4 (ADR 0003): is_ref flag — format version 2.
        w.U8(a.IsRef ? 1 : 0);
        // v3.5 (ADR 0016): BracketBody attribute body tail — format version 5.
        if (a.Body is null)
        {
            w.U8(0);
        }
        else
        {
            w.U8(1);
            w.U16(a.Body.Count);
            foreach (var n in a.Body) EncNode(w, n);
        }
    }

    private static void EncNode(BufWriter w, Node n)
    {
        switch (n)
        {
            case Element e:
                w.U8(0x01);
                w.Str(e.Name);
                w.OptStr(e.Anchor);
                w.OptStr(e.DataType);
                w.OptStr(e.Merge);
                // v3.4 (ADR 0003): syntactic ID declaration — format version 2.
                w.OptStr(e.Id);
                // v3.4 (ADR 0003 D1): body-position reference — format version 3.
                w.OptStr(e.BodyRef);
                w.U16(e.Attrs.Count);
                foreach (var a in e.Attrs) EncAttr(w, a);
                w.U16(e.Items.Count);
                foreach (var c in e.Items) EncNode(w, c);
                break;
            case TextNode t:    w.U8(0x02); w.Str(t.Value); break;
            case ScalarNode s:
                w.U8(0x03);
                w.Str(s.DataType);
                w.Str(ScalarValueStr(s.DataType, s.Value));
                break;
            case CommentNode c: w.U8(0x04); w.Str(c.Value); break;
            case RawTextNode r: w.U8(0x05); w.Str(r.Value); break;
            case EntityRefNode er: w.U8(0x06); w.Str(er.Name); break;
            case AliasNode al:     w.U8(0x07); w.Str(al.Name); break;
            case PINode pi:
                w.U8(0x08); w.Str(pi.Target); w.OptStr(pi.Data);
                break;
            case XMLDeclNode xd:
                w.U8(0x09);
                w.Str(xd.Version);
                w.OptStr(xd.Encoding);
                w.OptStr(xd.Standalone);
                break;
            case CXDirectiveNode cd:
                w.U8(0x0A);
                w.U16(cd.Attrs.Count);
                foreach (var a in cd.Attrs) EncAttr(w, a);
                // v0.6.0 (format version 4) — directive `&anchor` + nested children.
                w.OptStr(cd.Anchor);
                w.U16(cd.Items.Count);
                foreach (var it in cd.Items) EncNode(w, it);
                break;
            case BlockContentNode bc:
                w.U8(0x0C); w.U16(bc.Items.Count);
                foreach (var it in bc.Items) EncNode(w, it);
                break;
            case InterpolationNode inp:
                // v3.5 (ADR 0016) [58] — `[?=EXPR]`.
                w.U8(0x0D); w.Str(inp.Expr);
                break;
            case EvalDirectiveNode ed:
                // v3.5 (ADR 0016) [59] — `[?Name attrs body]`.
                w.U8(0x0E); w.Str(ed.Name);
                w.U16(ed.Attrs.Count);
                foreach (var a in ed.Attrs) EncAttr(w, a);
                w.U16(ed.Items.Count);
                foreach (var it in ed.Items) EncNode(w, it);
                break;
            default:
                // DTD / unknown — emit 0xFF skip marker.
                w.U8(0xFF);
                break;
        }
    }

    /// <summary>Encode a CXDocument to a FRAMED [u32 LE size][payload] AST
    /// bin byte[] suitable for direct hand-off to cx_ast_bin_to_&lt;format&gt;.</summary>
    public static byte[] EncodeAST(CXDocument doc)
    {
        var w = new BufWriter();
        w.U8(0x05); // version — bumped 4 → 5 for v0.6.0 grammar v3.5
                    //           (Interpolation/EvalDirective tags +
                    //            BracketBody attr body tail, ADR 0016)
        w.U16(doc.Prolog.Count);
        foreach (var n in doc.Prolog) EncNode(w, n);
        w.U16(doc.Elements.Count);
        foreach (var n in doc.Elements) EncNode(w, n);
        byte[] payload = w.ToBytes();
        var framed = new byte[4 + payload.Length];
        uint sz = (uint)payload.Length;
        framed[0] = (byte)(sz & 0xFF);
        framed[1] = (byte)((sz >> 8)  & 0xFF);
        framed[2] = (byte)((sz >> 16) & 0xFF);
        framed[3] = (byte)((sz >> 24) & 0xFF);
        Array.Copy(payload, 0, framed, 4, payload.Length);
        return framed;
    }

    // ── AST node reader ───────────────────────────────────────────────────────

    private static Node ReadNode(BufReader r, byte version)
    {
        byte tid = r.U8();

        switch (tid)
        {
            case 0x01: // Element
            {
                string name   = r.Str();
                string? anchor = r.OptStr();
                string? dt    = r.OptStr();
                string? merge = r.OptStr();
                string? idDecl = (version >= 2) ? r.OptStr() : null;
                // v3.4 (ADR 0003 D1): body-position reference — format version 3.
                string? bodyRef = (version >= 3) ? r.OptStr() : null;
                var attrs     = ReadAttrs(r, r.U16(), version);
                int childCount = r.U16();
                var items = new List<Node>(childCount);
                for (int i = 0; i < childCount; i++)
                    items.Add(ReadNode(r, version));
                return new Element(name)
                {
                    Anchor   = anchor,
                    DataType = dt,
                    Merge    = merge,
                    Id       = idDecl,
                    BodyRef  = bodyRef,
                    Attrs    = attrs,
                    Items    = items,
                };
            }

            case 0x02: // Text
                return new TextNode(r.Str());

            case 0x03: // Scalar
            {
                string dt = r.Str();
                return new ScalarNode(dt, Coerce(dt, r.Str()));
            }

            case 0x04: // Comment
                return new CommentNode(r.Str());

            case 0x05: // RawText
                return new RawTextNode(r.Str());

            case 0x06: // EntityRef
                return new EntityRefNode(r.Str());

            case 0x07: // Alias
                return new AliasNode(r.Str());

            case 0x08: // PI
            {
                string target = r.Str();
                string? data  = r.OptStr();
                return new PINode(target, data);
            }

            case 0x09: // XMLDecl
            {
                string ver       = r.Str();
                string? encoding = r.OptStr();
                string? sa       = r.OptStr();
                return new XMLDeclNode(ver, encoding, sa);
            }

            case 0x0A: // CXDirective
            {
                var attrs = ReadAttrs(r, r.U16(), version);
                // v0.6.0 (format version 4) — directive `&anchor` + nested
                // children (spec/schema.md §8 standalone fragment form).
                // v1-v3 buffers stop after attrs[].
                if (version >= 4)
                {
                    string? anchor = r.OptStr();
                    int childCount = r.U16();
                    var items = new List<Node>(childCount);
                    for (int i = 0; i < childCount; i++)
                        items.Add(ReadNode(r, version));
                    return new CXDirectiveNode(attrs, anchor, items);
                }
                return new CXDirectiveNode(attrs);
            }

            case 0x0C: // BlockContent
            {
                int childCount = r.U16();
                var items = new List<Node>(childCount);
                for (int i = 0; i < childCount; i++)
                    items.Add(ReadNode(r, version));
                return new BlockContentNode(items);
            }

            case 0x0D: // Interpolation — v3.5 (ADR 0016) [58]
                return new InterpolationNode(r.Str());

            case 0x0E: // EvalDirective — v3.5 (ADR 0016) [59]
            {
                string name = r.Str();
                var attrs = ReadAttrs(r, r.U16(), version);
                int childCount = r.U16();
                var items = new List<Node>(childCount);
                for (int i = 0; i < childCount; i++) items.Add(ReadNode(r, version));
                return new EvalDirectiveNode(name, attrs, items);
            }

            case 0xFF: // skip / DTD placeholder — no payload
                return new TextNode("");

            default:
                // Unknown type: we cannot safely skip without knowing payload size.
                // Return an empty text node as a best-effort fallback.
                return new TextNode("");
        }
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    private static List<Attr> ReadAttrs(BufReader r, int count, byte version)
    {
        var attrs = new List<Attr>(count);
        for (int i = 0; i < count; i++)
        {
            string name     = r.Str();
            string valueStr = r.Str();
            string typeStr  = r.Str();
            string? dt = typeStr == "string" ? null : typeStr;
            // v3.4 (ADR 0003): is_ref byte (events buffer follows ast_bin v2).
            bool isRef = (version >= 2) && r.U8() == 1;
            List<Node>? body = null;
            if (version >= 5)
            {
                // v3.5 (ADR 0016): BracketBody attribute body tail.
                byte flag = r.U8();
                if (flag == 1)
                {
                    int bcount = r.U16();
                    body = new List<Node>(bcount);
                    for (int k = 0; k < bcount; k++) body.Add(ReadNode(r, version));
                }
                else if (flag != 0)
                {
                    throw new InvalidOperationException($"ast_bin: invalid attr body_flag {flag}");
                }
            }
            attrs.Add(new Attr(name, Coerce(typeStr, valueStr), dt) { IsRef = isRef, Body = body });
        }
        return attrs;
    }

    private static object? Coerce(string typeStr, string valueStr) => typeStr switch
    {
        "int"   => (object?)long.Parse(valueStr,
                        System.Globalization.NumberStyles.Integer,
                        System.Globalization.CultureInfo.InvariantCulture),
        "float" => double.Parse(valueStr,
                        System.Globalization.NumberStyles.Float,
                        System.Globalization.CultureInfo.InvariantCulture),
        "bool"  => valueStr == "true",
        "null"  => null,
        _       => valueStr,
    };

    private static string EventTypeName(byte tid) => tid switch
    {
        0x01 => "StartDoc",
        0x02 => "EndDoc",
        0x03 => "StartElement",
        0x04 => "EndElement",
        0x05 => "Text",
        0x06 => "Scalar",
        0x07 => "Comment",
        0x08 => "PI",
        0x09 => "EntityRef",
        0x0A => "RawText",
        0x0B => "Alias",
        _    => "Unknown",
    };

    // ── BufReader ─────────────────────────────────────────────────────────────

    /// <summary>Cursor-based little-endian reader over a byte array.</summary>
    private sealed class BufReader
    {
        private readonly byte[] _data;
        private int _pos;

        public BufReader(byte[] data) { _data = data; _pos = 0; }

        public byte U8() => _data[_pos++];

        public ushort U16()
        {
            // Use explicit LE decoding to be safe on all platforms.
            ushort v = (ushort)(_data[_pos] | (_data[_pos + 1] << 8));
            _pos += 2;
            return v;
        }

        public uint U32()
        {
            uint v = (uint)(_data[_pos]
                | (_data[_pos + 1] << 8)
                | (_data[_pos + 2] << 16)
                | (_data[_pos + 3] << 24));
            _pos += 4;
            return v;
        }

        public string Str()
        {
            int len = (int)U32();
            string s = Encoding.UTF8.GetString(_data, _pos, len);
            _pos += len;
            return s;
        }

        public string? OptStr()
        {
            byte flag = U8();
            if (flag == 0) return null;
            return Str();
        }
    }
}
