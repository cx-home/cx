/**
 * Binary wire protocol decoder for cx_to_ast_bin and cx_to_events_bin.
 *
 * Buffer layout: [u32 LE: payload_size][payload bytes]
 * All integers little-endian.
 * String:  u32(byte_len) + raw UTF-8 bytes (no null terminator)
 * OptStr:  u8(0=absent, 1=present) + str if present
 * Attr:    str:name + str:value_str + str:inferred_type
 */

import {
  Attr,
  Document,
  Element,
  TextNode,
  ScalarNode,
  CommentNode,
  RawTextNode,
  EntityRefNode,
  AliasNode,
  PINode,
  XMLDeclNode,
  CXDirectiveNode,
  BlockContentNode,
  InterpolationNode,
  EvalDirectiveNode,
  Node,
} from './ast';

// ── StreamEvent type ──────────────────────────────────────────────────────────

export interface StreamEvent {
  type: string;
  name?: string;
  anchor?: string | null;
  dataType?: string | null;
  merge?: string | null;
  attrs?: Attr[];
  value?: any;
  target?: string;
  data?: string | null;
}

// ── scalar coercion ───────────────────────────────────────────────────────────

function coerce(typeStr: string, valueStr: string): any {
  if (typeStr === 'int') return parseInt(valueStr, 10);
  if (typeStr === 'float') return parseFloat(valueStr);
  if (typeStr === 'bool') return valueStr === 'true';
  if (typeStr === 'null') return null;
  return valueStr;  // string / date / datetime / bytes
}

// ── buffer reader ─────────────────────────────────────────────────────────────

class BufReader {
  private pos: number = 0;

  constructor(private readonly buf: Buffer) {}

  u8(): number {
    return this.buf.readUInt8(this.pos++);
  }

  u16(): number {
    const v = this.buf.readUInt16LE(this.pos);
    this.pos += 2;
    return v;
  }

  u32(): number {
    const v = this.buf.readUInt32LE(this.pos);
    this.pos += 4;
    return v;
  }

  str(): string {
    const len = this.buf.readUInt32LE(this.pos);
    this.pos += 4;
    const s = this.buf.toString('utf8', this.pos, this.pos + len);
    this.pos += len;
    return s;
  }

  optstr(): string | null {
    const flag = this.buf.readUInt8(this.pos++);
    if (!flag) return null;
    const len = this.buf.readUInt32LE(this.pos);
    this.pos += 4;
    const s = this.buf.toString('utf8', this.pos, this.pos + len);
    this.pos += len;
    return s;
  }
}

// ── AST decoder ───────────────────────────────────────────────────────────────

function readAttr(b: BufReader, version: number): Attr {
  const name = b.str();
  const valueStr = b.str();
  const typeStr = b.str();
  const dt = typeStr !== 'string' ? typeStr : null;
  const isRef = version >= 2 ? b.u8() === 1 : false;
  const attr: Attr = { name, value: coerce(typeStr, valueStr), dataType: dt, isRef };
  // v3.5 (ADR 0016): BracketBody attribute body tail — format version 5.
  if (version >= 5) {
    const flag = b.u8();
    if (flag === 1) {
      const count = b.u16();
      const body: Node[] = [];
      for (let i = 0; i < count; i++) body.push(readNode(b, version));
      attr.body = body;
    } else if (flag !== 0) {
      throw new Error(`ast_bin: invalid attr body_flag ${flag}`);
    }
  }
  return attr;
}

function readNode(b: BufReader, version: number): Node {
  const tid = b.u8();

  if (tid === 0x01) {
    const name = b.str();
    const anchor = b.optstr();
    const dataType = b.optstr();
    const merge = b.optstr();
    const id = version >= 2 ? b.optstr() : null;
    const bodyRef = version >= 3 ? b.optstr() : null;
    const attrCount = b.u16();
    const attrs: Attr[] = [];
    for (let i = 0; i < attrCount; i++) attrs.push(readAttr(b, version));
    const childCount = b.u16();
    const items: Node[] = [];
    for (let i = 0; i < childCount; i++) items.push(readNode(b, version));
    return new Element({ name, anchor, dataType, merge, attrs, items, id, bodyRef });
  }
  if (tid === 0x02) return new TextNode(b.str());
  if (tid === 0x03) {
    const dt = b.str();
    return new ScalarNode(dt, coerce(dt, b.str()));
  }
  if (tid === 0x04) return new CommentNode(b.str());
  if (tid === 0x05) return new RawTextNode(b.str());
  if (tid === 0x06) return new EntityRefNode(b.str());
  if (tid === 0x07) return new AliasNode(b.str());
  if (tid === 0x08) {
    const target = b.str();
    const data = b.optstr();
    return new PINode(target, data);
  }
  if (tid === 0x09) {
    const version = b.str();
    const encoding = b.optstr();
    const standalone = b.optstr();
    return new XMLDeclNode(version, encoding, standalone);
  }
  if (tid === 0x0A) {
    const count = b.u16();
    const attrs: Attr[] = [];
    for (let i = 0; i < count; i++) attrs.push(readAttr(b, version));
    let anchor: string | null = null;
    const items: Node[] = [];
    if (version >= 4) {
      // v0.6.0 — directive `&anchor` + nested children.
      anchor = b.optstr();
      const itemCount = b.u16();
      for (let i = 0; i < itemCount; i++) items.push(readNode(b, version));
    }
    return new CXDirectiveNode(attrs, anchor, items);
  }
  if (tid === 0x0C) {
    const count = b.u16();
    const items: Node[] = [];
    for (let i = 0; i < count; i++) items.push(readNode(b, version));
    return new BlockContentNode(items);
  }
  if (tid === 0x0D) {
    // v3.5 (ADR 0016) [58] — `[?=EXPR]`.
    return new InterpolationNode(b.str());
  }
  if (tid === 0x0E) {
    // v3.5 (ADR 0016) [59] — `[?Name attrs body]`.
    const name = b.str();
    const attrCount = b.u16();
    const attrs: Attr[] = [];
    for (let i = 0; i < attrCount; i++) attrs.push(readAttr(b, version));
    const itemCount = b.u16();
    const items: Node[] = [];
    for (let i = 0; i < itemCount; i++) items.push(readNode(b, version));
    return new EvalDirectiveNode(name, attrs, items);
  }
  // 0xFF = skip / unknown (no payload)
  return new TextNode('');
}

export function decodeAST(data: Buffer): Document {
  const b = new BufReader(data);
  const version = b.u8(); // version byte
  const prologCount = b.u16();
  const prolog: Node[] = [];
  for (let i = 0; i < prologCount; i++) prolog.push(readNode(b, version));
  const elemCount = b.u16();
  const elements: Node[] = [];
  for (let i = 0; i < elemCount; i++) elements.push(readNode(b, version));
  return new Document({ prolog, elements });
}

// ── Events decoder ────────────────────────────────────────────────────────────

const EVT_NAMES: Record<number, string> = {
  0x01: 'StartDoc',
  0x02: 'EndDoc',
  0x03: 'StartElement',
  0x04: 'EndElement',
  0x05: 'Text',
  0x06: 'Scalar',
  0x07: 'Comment',
  0x08: 'PI',
  0x09: 'EntityRef',
  0x0A: 'RawText',
  0x0B: 'Alias',
};

function readOneEvent(b: BufReader): StreamEvent {
  const tid = b.u8();
  const type = EVT_NAMES[tid] ?? 'Unknown';
  const e: StreamEvent = { type };

  if (tid === 0x03) {
    // StartElement
    e.name = b.str();
    e.anchor = b.optstr();
    e.dataType = b.optstr();
    e.merge = b.optstr();
    const nAttrs = b.u16();
    const attrs: Attr[] = [];
    for (let j = 0; j < nAttrs; j++) {
      const aName = b.str();
      const aValStr = b.str();
      const aType = b.str();
      const dt = aType !== 'string' ? aType : null;
      const isRef = b.u8() === 1;  // v3.4 (ADR 0003): events buffer follows ast_bin v2.
      // v3.5 (ADR 0016): BracketBody attr body tail (events buffer follows
      // ast_bin v5 attr layout). Body items are skipped — events are a
      // flattened view.
      const bodyFlag = b.u8();
      if (bodyFlag === 1) {
        const count = b.u16();
        for (let k = 0; k < count; k++) readNode(b, 5);
      } else if (bodyFlag !== 0) {
        throw new Error(`ast_bin: invalid attr body_flag ${bodyFlag}`);
      }
      attrs.push({ name: aName, value: coerce(aType, aValStr), dataType: dt, isRef });
    }
    e.attrs = attrs;
  } else if (tid === 0x04) {
    e.name = b.str();
  } else if (tid === 0x05 || tid === 0x07 || tid === 0x0A) {
    e.value = b.str();
  } else if (tid === 0x06) {
    const dt = b.str();
    e.dataType = dt;
    e.value = coerce(dt, b.str());
  } else if (tid === 0x08) {
    e.target = b.str();
    e.data = b.optstr();
  } else if (tid === 0x09 || tid === 0x0B) {
    e.value = b.str();
  }
  // 0x01 StartDoc, 0x02 EndDoc: no payload
  return e;
}

export function decodeEvents(data: Buffer): StreamEvent[] {
  const b = new BufReader(data);
  const n = b.u32();
  const events: StreamEvent[] = [];
  for (let i = 0; i < n; i++) events.push(readOneEvent(b));
  return events;
}

/** Decode a single event from a payload (no [u32 count] prefix).
 *  Used by the handle-based stream for per-event decoding. */
export function decodeOneEvent(payload: Buffer): StreamEvent {
  return readOneEvent(new BufReader(payload));
}

// ── Binary AST encoder (Phase 5 / CB-1) ──────────────────────────────────────
// Inverse of decodeAST. Produces a FRAMED [u32 LE size][payload] Buffer that
// matches V's emit_ast_bin output. Used by Document.toAstBin to feed
// cx_ast_bin_to_<format> directly without the to_cx round-trip.

class BufWriter {
  private parts: Buffer[] = [];
  private len = 0;
  push(b: Buffer): void { this.parts.push(b); this.len += b.length; }
  u8(v: number): void { const b = Buffer.allocUnsafe(1); b[0] = v & 0xFF; this.push(b); }
  u16(v: number): void { const b = Buffer.allocUnsafe(2); b.writeUInt16LE(v, 0); this.push(b); }
  u32(v: number): void { const b = Buffer.allocUnsafe(4); b.writeUInt32LE(v, 0); this.push(b); }
  str(s: string): void { const enc = Buffer.from(s, 'utf8'); this.u32(enc.length); this.push(enc); }
  optstr(s: string | null | undefined): void {
    if (s === null || s === undefined) { this.u8(0); }
    else { this.u8(1); this.str(s); }
  }
  toBuffer(): Buffer { return Buffer.concat(this.parts, this.len); }
}

function scalarValueStr(dt: string, v: any): string {
  if (v === null || v === undefined || dt === 'null') return 'null';
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  if (typeof v === 'string') return v;
  return String(v);
}

function encAttr(w: BufWriter, a: Attr): void {
  const dt = (a.dataType && a.dataType.length > 0) ? a.dataType : 'string';
  w.str(a.name);
  w.str(scalarValueStr(dt, a.value));
  w.str(dt);
  // v3.4 (ADR 0003): is_ref flag — format version 2.
  w.u8(a.isRef ? 1 : 0);
  // v3.5 (ADR 0016): BracketBody attribute body tail — format version 5.
  if (a.body === undefined || a.body === null) {
    w.u8(0);
  } else {
    w.u8(1);
    w.u16(a.body.length);
    for (const n of a.body) encNode(w, n);
  }
}

function encNode(w: BufWriter, n: Node): void {
  if (n instanceof Element) {
    w.u8(0x01);
    w.str(n.name);
    w.optstr(n.anchor);
    w.optstr(n.dataType);
    w.optstr(n.merge);
    // v3.4 (ADR 0003): syntactic ID declaration — format version 2.
    w.optstr(n.id);
    // v3.4 (ADR 0003 D1): body-position reference — format version 3.
    w.optstr(n.bodyRef);
    w.u16(n.attrs.length);
    for (const a of n.attrs) encAttr(w, a);
    w.u16(n.items.length);
    for (const c of n.items) encNode(w, c);
  } else if (n instanceof TextNode) {
    w.u8(0x02); w.str(n.value);
  } else if (n instanceof ScalarNode) {
    w.u8(0x03); w.str(n.dataType); w.str(scalarValueStr(n.dataType, n.value));
  } else if (n instanceof CommentNode) {
    w.u8(0x04); w.str(n.value);
  } else if (n instanceof RawTextNode) {
    w.u8(0x05); w.str(n.value);
  } else if (n instanceof EntityRefNode) {
    w.u8(0x06); w.str(n.name);
  } else if (n instanceof AliasNode) {
    w.u8(0x07); w.str(n.name);
  } else if (n instanceof PINode) {
    w.u8(0x08); w.str(n.target); w.optstr(n.data);
  } else if (n instanceof XMLDeclNode) {
    w.u8(0x09); w.str(n.version); w.optstr(n.encoding); w.optstr(n.standalone);
  } else if (n instanceof CXDirectiveNode) {
    w.u8(0x0A); w.u16(n.attrs.length);
    for (const a of n.attrs) encAttr(w, a);
    // v0.6.0 (format version 4) — directive `&anchor` + nested children.
    w.optstr(n.anchor);
    w.u16(n.items.length);
    for (const c of n.items) encNode(w, c);
  } else if (n instanceof BlockContentNode) {
    w.u8(0x0C); w.u16(n.items.length);
    for (const it of n.items) encNode(w, it);
  } else if (n instanceof InterpolationNode) {
    // v3.5 (ADR 0016) [58] — `[?=EXPR]`.
    w.u8(0x0D); w.str(n.expr);
  } else if (n instanceof EvalDirectiveNode) {
    // v3.5 (ADR 0016) [59] — `[?Name attrs body]`.
    w.u8(0x0E); w.str(n.name);
    w.u16(n.attrs.length);
    for (const a of n.attrs) encAttr(w, a);
    w.u16(n.items.length);
    for (const it of n.items) encNode(w, it);
  } else {
    // DTD / unknown — emit 0xFF skip marker.
    w.u8(0xFF);
  }
}

/** Encode a Document to a FRAMED [u32 LE size][payload] AST bin Buffer
 *  suitable for direct hand-off to cx_ast_bin_to_<format>. */
export function encodeAST(doc: Document): Buffer {
  const w = new BufWriter();
  w.u8(0x05); // version — v0.6.0 (ADR 0016 grammar v3.5):
              //   * CXDirective &anchor + items (format v4)
              //   * Interpolation (0x0D) + EvalDirective (0x0E) tags
              //   * BracketBody attribute body tail (format v5)
  w.u16(doc.prolog.length);
  for (const n of doc.prolog) encNode(w, n);
  w.u16(doc.elements.length);
  for (const n of doc.elements) encNode(w, n);
  const payload = w.toBuffer();
  const framed = Buffer.allocUnsafe(4 + payload.length);
  framed.writeUInt32LE(payload.length, 0);
  payload.copy(framed, 4);
  return framed;
}
