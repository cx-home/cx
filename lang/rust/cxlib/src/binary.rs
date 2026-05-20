//! Binary wire protocol decoder for cx_to_ast_bin and cx_to_events_bin.
//!
//! Buffer layout: [u32 LE: payload_size][payload bytes]
//!
//! All integers little-endian.
//!   String:  u32(byte_len) + raw UTF-8 bytes
//!   OptStr:  u8(0=absent, 1=present) + str if present
//!   Attr:    str:name + str:value_str + str:inferred_type

use std::io::{Cursor, Read};
use serde_json::Value;

use crate::ast::{Attr, Document, Element, Node};
use crate::stream::{StreamEvent, StreamEventType};

// ── low-level reader ──────────────────────────────────────────────────────────

struct BufReader<'a> {
    cur: Cursor<&'a [u8]>,
}

impl<'a> BufReader<'a> {
    fn new(data: &'a [u8]) -> Self {
        BufReader { cur: Cursor::new(data) }
    }

    fn u8(&mut self) -> Result<u8, String> {
        let mut buf = [0u8; 1];
        self.cur.read_exact(&mut buf).map_err(|e| format!("binary read u8: {}", e))?;
        Ok(buf[0])
    }

    fn u16(&mut self) -> Result<u16, String> {
        let mut buf = [0u8; 2];
        self.cur.read_exact(&mut buf).map_err(|e| format!("binary read u16: {}", e))?;
        Ok(u16::from_le_bytes(buf))
    }

    fn u32(&mut self) -> Result<u32, String> {
        let mut buf = [0u8; 4];
        self.cur.read_exact(&mut buf).map_err(|e| format!("binary read u32: {}", e))?;
        Ok(u32::from_le_bytes(buf))
    }

    fn str_(&mut self) -> Result<String, String> {
        let len = self.u32()? as usize;
        let mut buf = vec![0u8; len];
        self.cur.read_exact(&mut buf).map_err(|e| format!("binary read str bytes: {}", e))?;
        String::from_utf8(buf).map_err(|e| format!("binary str utf8: {}", e))
    }

    fn optstr(&mut self) -> Result<Option<String>, String> {
        let flag = self.u8()?;
        if flag == 0 {
            Ok(None)
        } else {
            Ok(Some(self.str_()?))
        }
    }
}

// ── scalar coercion ───────────────────────────────────────────────────────────

fn coerce(type_str: &str, value_str: &str) -> Value {
    match type_str {
        "int"   => value_str.parse::<i64>()
                       .map(Value::from)
                       .unwrap_or_else(|_| Value::String(value_str.to_string())),
        "float" => value_str.parse::<f64>()
                       .ok()
                       .and_then(|f| serde_json::Number::from_f64(f))
                       .map(Value::Number)
                       .unwrap_or_else(|| Value::String(value_str.to_string())),
        "bool"  => Value::Bool(value_str == "true"),
        "null"  => Value::Null,
        _       => Value::String(value_str.to_string()),
    }
}

// ── AST decoder ───────────────────────────────────────────────────────────────

fn read_attr(b: &mut BufReader<'_>, version: u8) -> Result<Attr, String> {
    let name      = b.str_()?;
    let value_str = b.str_()?;
    let type_str  = b.str_()?;
    let value     = coerce(&type_str, &value_str);
    let data_type = if type_str == "string" { None } else { Some(type_str) };
    let is_ref    = if version >= 2 { b.u8()? == 1 } else { false };
    // v3.5 (ADR 0016): BracketBody attribute body tail — format version 5.
    let body = if version >= 5 {
        let flag = b.u8()?;
        match flag {
            0 => None,
            1 => {
                let count = b.u16()? as usize;
                let mut body = Vec::with_capacity(count);
                for _ in 0..count {
                    body.push(read_node(b, version)?);
                }
                Some(body)
            }
            other => return Err(format!("ast_bin: invalid attr body_flag {}", other)),
        }
    } else {
        None
    };
    Ok(Attr { name, value, data_type, local: String::new(), ns_uri: None, is_ref, body })
}

fn read_node(b: &mut BufReader<'_>, version: u8) -> Result<Node, String> {
    let tid = b.u8()?;
    match tid {
        0x01 => {
            let name      = b.str_()?;
            let anchor    = b.optstr()?;
            let data_type = b.optstr()?;
            let merge     = b.optstr()?;
            // v3.4 (ADR 0003): syntactic ID declaration — version 2+.
            let id        = if version >= 2 { b.optstr()? } else { None };
            // v3.4 (ADR 0003 D1): body-position reference — version 3+.
            let body_ref  = if version >= 3 { b.optstr()? } else { None };
            let attr_count = b.u16()? as usize;
            let mut attrs = Vec::with_capacity(attr_count);
            for _ in 0..attr_count {
                attrs.push(read_attr(b, version)?);
            }
            let child_count = b.u16()? as usize;
            let mut items = Vec::with_capacity(child_count);
            for _ in 0..child_count {
                items.push(read_node(b, version)?);
            }
            Ok(Node::Element(Element {
                name, anchor, data_type, merge, attrs, items,
                local: String::new(), ns_uri: None, id, body_ref,
                lang_resolved: None,
            }))
        }
        0x02 => Ok(Node::Text(b.str_()?)),
        0x03 => {
            let data_type = b.str_()?;
            let value_str = b.str_()?;
            let value     = coerce(&data_type, &value_str);
            Ok(Node::Scalar { data_type, value })
        }
        0x04 => Ok(Node::Comment(b.str_()?)),
        0x05 => Ok(Node::RawText(b.str_()?)),
        0x06 => Ok(Node::EntityRef(b.str_()?)),
        0x07 => Ok(Node::Alias(b.str_()?)),
        0x08 => {
            let target = b.str_()?;
            let data   = b.optstr()?;
            Ok(Node::PI { target, data })
        }
        0x09 => {
            let version    = b.str_()?;
            let encoding   = b.optstr()?;
            let standalone = b.optstr()?;
            Ok(Node::XMLDecl { version, encoding, standalone })
        }
        0x0A => {
            let count = b.u16()? as usize;
            let mut attrs = Vec::with_capacity(count);
            for _ in 0..count {
                attrs.push(read_attr(b, version)?);
            }
            // v0.6.0 (format version 4) — directive `&anchor` + nested
            // children (spec/schema.md §8 standalone fragment form).
            // v1-v3 buffers stop after attrs[].
            let (anchor, items) = if version >= 4 {
                let a = b.optstr()?;
                let child_count = b.u16()? as usize;
                let mut its = Vec::with_capacity(child_count);
                for _ in 0..child_count {
                    its.push(read_node(b, version)?);
                }
                (a, its)
            } else {
                (None, Vec::new())
            };
            Ok(Node::CXDirective { attrs, anchor, items })
        }
        0x0C => {
            let count = b.u16()? as usize;
            let mut items = Vec::with_capacity(count);
            for _ in 0..count {
                items.push(read_node(b, version)?);
            }
            Ok(Node::BlockContent(items))
        }
        0x0D => {
            // v3.5 (ADR 0016) [58] — `[?=EXPR]`.
            let expr = b.str_()?;
            Ok(Node::Interpolation { expr })
        }
        0x0E => {
            // v3.5 (ADR 0016) [59] — `[?Name attrs body]`.
            let name = b.str_()?;
            let attr_count = b.u16()? as usize;
            let mut attrs = Vec::with_capacity(attr_count);
            for _ in 0..attr_count {
                attrs.push(read_attr(b, version)?);
            }
            let item_count = b.u16()? as usize;
            let mut items = Vec::with_capacity(item_count);
            for _ in 0..item_count {
                items.push(read_node(b, version)?);
            }
            Ok(Node::EvalDirective { name, attrs, items })
        }
        0xFF => {
            // skip node — no payload, return empty text
            Ok(Node::Text(String::new()))
        }
        other => Err(format!("unknown AST node type: 0x{:02X}", other)),
    }
}

/// Decode a binary AST payload into a `Document`.
pub fn decode_ast(data: &[u8]) -> Result<Document, String> {
    let mut b = BufReader::new(data);
    let version      = b.u8()?;
    let prolog_count = b.u16()? as usize;
    let mut prolog   = Vec::with_capacity(prolog_count);
    for _ in 0..prolog_count {
        prolog.push(read_node(&mut b, version)?);
    }
    let elem_count = b.u16()? as usize;
    let mut elements = Vec::with_capacity(elem_count);
    for _ in 0..elem_count {
        elements.push(read_node(&mut b, version)?);
    }
    Ok(Document { prolog, elements })
}

// ── Events decoder ────────────────────────────────────────────────────────────

fn read_stream_attr(b: &mut BufReader<'_>) -> Result<Attr, String> {
    let name      = b.str_()?;
    let value_str = b.str_()?;
    let type_str  = b.str_()?;
    let value     = coerce(&type_str, &value_str);
    let data_type = if type_str == "string" { None } else { Some(type_str) };
    // v3.4 (ADR 0003): is_ref flag — events buffer follows ast_bin v2.
    let is_ref    = b.u8()? == 1;
    // v3.5 (ADR 0016): BracketBody attr body tail (events buffer
    // follows ast_bin v5 attr layout). Body items are read but
    // discarded — events are a flattened view of the AST.
    let body_flag = b.u8()?;
    if body_flag == 1 {
        let count = b.u16()? as usize;
        for _ in 0..count {
            let _ = read_node(b, 5)?;
        }
    } else if body_flag != 0 {
        return Err(format!("ast_bin: invalid attr body_flag {}", body_flag));
    }
    Ok(Attr { name, value, data_type, local: String::new(), ns_uri: None, is_ref, body: None })
}

fn read_one_event_type(b: &mut BufReader<'_>) -> Result<StreamEventType, String> {
    let tid = b.u8()?;
    Ok(match tid {
            0x01 => StreamEventType::StartDoc,
            0x02 => StreamEventType::EndDoc,
            0x03 => {
                let name      = b.str_()?;
                let anchor    = b.optstr()?;
                let data_type = b.optstr()?;
                let _merge    = b.optstr()?;
                let attr_count = b.u16()? as usize;
                let mut attrs = Vec::with_capacity(attr_count);
                for _ in 0..attr_count {
                    attrs.push(read_stream_attr(b)?);
                }
                StreamEventType::StartElement { name, anchor, data_type, merge: _merge, attrs }
            }
            0x04 => StreamEventType::EndElement { name: b.str_()? },
            0x05 => StreamEventType::Text(b.str_()?),
            0x06 => {
                let data_type = b.str_()?;
                let value_str = b.str_()?;
                let value     = coerce(&data_type, &value_str);
                StreamEventType::Scalar { data_type, value }
            }
            0x07 => StreamEventType::Comment(b.str_()?),
            0x08 => {
                let target = b.str_()?;
                let data   = b.optstr()?;
                StreamEventType::PI { target, data }
            }
            0x09 => StreamEventType::EntityRef(b.str_()?),
            0x0A => StreamEventType::RawText(b.str_()?),
            0x0B => StreamEventType::Alias(b.str_()?),
        other => return Err(format!("unknown event type: 0x{:02X}", other)),
    })
}

/// Decode a binary events payload (whole-buffer form, [u32 count][events...])
/// into a `Vec<StreamEvent>`.
pub fn decode_events(data: &[u8]) -> Result<Vec<StreamEvent>, String> {
    let mut b = BufReader::new(data);
    let count = b.u32()? as usize;
    let mut events = Vec::with_capacity(count);
    for _ in 0..count {
        let event_type = read_one_event_type(&mut b)?;
        events.push(StreamEvent { event_type });
    }
    Ok(events)
}

/// Decode a single event from a payload (no [u32 count] prefix). Used
/// by the handle-based EventStream for per-event decoding.
pub fn decode_one_event(data: &[u8]) -> Result<StreamEvent, String> {
    let mut b = BufReader::new(data);
    Ok(StreamEvent { event_type: read_one_event_type(&mut b)? })
}

// ── Binary AST encoder (Phase 5 / CB-1) ──────────────────────────────────────
// Inverse of decode_ast. Produces a FRAMED [u32 LE size][payload] buffer that
// matches V's emit_ast_bin output. Used by Document::to_ast_bin to feed
// cx_ast_bin_to_<format> directly without the to_cx round-trip.

fn enc_u16(out: &mut Vec<u8>, v: u16) { out.extend_from_slice(&v.to_le_bytes()); }
fn enc_u32(out: &mut Vec<u8>, v: u32) { out.extend_from_slice(&v.to_le_bytes()); }
fn enc_str(out: &mut Vec<u8>, s: &str) {
    enc_u32(out, s.len() as u32);
    out.extend_from_slice(s.as_bytes());
}
fn enc_optstr(out: &mut Vec<u8>, s: Option<&str>) {
    match s {
        None => out.push(0),
        Some(v) => { out.push(1); enc_str(out, v); }
    }
}

/// Serialize a Scalar/Attr value to its canonical CX string form
/// (matching V's scalar_value_str). For serde_json::Value:
///   Null         -> "null"
///   Bool(true)   -> "true"
///   Bool(false)  -> "false"
///   Number       -> Number::to_string
///   String       -> the inner string verbatim
///   Array/Object -> serde_json default repr (rare for scalar slots)
fn scalar_value_str(v: &Value) -> String {
    match v {
        Value::Null     => "null".to_string(),
        Value::Bool(b)  => if *b { "true".to_string() } else { "false".to_string() },
        Value::Number(n)=> n.to_string(),
        Value::String(s)=> s.clone(),
        other           => other.to_string(),
    }
}

fn enc_attr(out: &mut Vec<u8>, a: &Attr) {
    enc_str(out, &a.name);
    let dt = a.data_type.as_deref().unwrap_or("string");
    enc_str(out, &scalar_value_str(&a.value));
    enc_str(out, dt);
    // v3.4 (ADR 0003): is_ref flag — format version 2.
    out.push(if a.is_ref { 1 } else { 0 });
    // v3.5 (ADR 0016): BracketBody attribute body tail — format version 5.
    match &a.body {
        None => out.push(0),
        Some(body) => {
            out.push(1);
            enc_u16(out, body.len() as u16);
            for n in body { enc_node(out, n); }
        }
    }
}

fn enc_node(out: &mut Vec<u8>, n: &Node) {
    match n {
        Node::Element(e) => {
            out.push(0x01);
            enc_str(out, &e.name);
            enc_optstr(out, e.anchor.as_deref());
            enc_optstr(out, e.data_type.as_deref());
            enc_optstr(out, e.merge.as_deref());
            // v3.4 (ADR 0003): syntactic ID declaration — format version 2.
            enc_optstr(out, e.id.as_deref());
            // v3.4 (ADR 0003 D1): body-position reference — format version 3.
            enc_optstr(out, e.body_ref.as_deref());
            enc_u16(out, e.attrs.len() as u16);
            for a in &e.attrs { enc_attr(out, a); }
            enc_u16(out, e.items.len() as u16);
            for c in &e.items { enc_node(out, c); }
        }
        Node::Text(s)            => { out.push(0x02); enc_str(out, s); }
        Node::Scalar { data_type, value } => {
            out.push(0x03);
            enc_str(out, data_type);
            enc_str(out, &scalar_value_str(value));
        }
        Node::Comment(s)         => { out.push(0x04); enc_str(out, s); }
        Node::RawText(s)         => { out.push(0x05); enc_str(out, s); }
        Node::EntityRef(s)       => { out.push(0x06); enc_str(out, s); }
        Node::Alias(s)           => { out.push(0x07); enc_str(out, s); }
        Node::PI { target, data } => {
            out.push(0x08);
            enc_str(out, target);
            enc_optstr(out, data.as_deref());
        }
        Node::XMLDecl { version, encoding, standalone } => {
            out.push(0x09);
            enc_str(out, version);
            enc_optstr(out, encoding.as_deref());
            enc_optstr(out, standalone.as_deref());
        }
        Node::CXDirective { attrs, anchor, items } => {
            out.push(0x0A);
            enc_u16(out, attrs.len() as u16);
            for a in attrs { enc_attr(out, a); }
            // v0.6.0 (format version 4) — directive `&anchor` + nested
            // children (spec/schema.md §8 standalone fragment form).
            enc_optstr(out, anchor.as_deref());
            enc_u16(out, items.len() as u16);
            for it in items { enc_node(out, it); }
        }
        Node::BlockContent(items) => {
            out.push(0x0C);
            enc_u16(out, items.len() as u16);
            for it in items { enc_node(out, it); }
        }
        Node::Interpolation { expr } => {
            // v3.5 (ADR 0016) [58] — `[?=EXPR]`.
            out.push(0x0D);
            enc_str(out, expr);
        }
        Node::EvalDirective { name, attrs, items } => {
            // v3.5 (ADR 0016) [59] — `[?Name attrs body]`.
            out.push(0x0E);
            enc_str(out, name);
            enc_u16(out, attrs.len() as u16);
            for a in attrs { enc_attr(out, a); }
            enc_u16(out, items.len() as u16);
            for it in items { enc_node(out, it); }
        }
        Node::DoctypeDecl { .. } => {
            // DTD nodes aren't round-tripped by bindings; emit 0xFF skip.
            out.push(0xFF);
        }
    }
}

/// Encode a Document to a FRAMED [u32 LE size][payload] binary AST
/// buffer suitable for direct hand-off to cx_ast_bin_to_<format>.
pub fn encode_ast(doc: &Document) -> Vec<u8> {
    let mut payload = Vec::new();
    payload.push(0x05); // version — bumped 4 → 5 for v0.6.0 grammar v3.5
                        //           (Interpolation/EvalDirective tags +
                        //            BracketBody attr body tail, ADR 0016)
    enc_u16(&mut payload, doc.prolog.len() as u16);
    for n in &doc.prolog { enc_node(&mut payload, n); }
    enc_u16(&mut payload, doc.elements.len() as u16);
    for n in &doc.elements { enc_node(&mut payload, n); }
    let mut out = Vec::with_capacity(4 + payload.len());
    enc_u32(&mut out, payload.len() as u32);
    out.extend_from_slice(&payload);
    out
}
