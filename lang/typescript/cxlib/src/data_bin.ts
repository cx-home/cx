/**
 * CXDB v1 codec — strict canonical binary data format.
 *
 * Spec: spec/data_bin.md. Decoder consumes the 12-byte-header-prefixed
 * PAYLOAD returned by libcx.cx_to_data_bin (the [u32 LE size] frame is
 * stripped by callBinFn before this module sees it). Encoder produces a
 * FRAMED buffer suitable for direct hand-off to libcx.cx_from_data_bin.
 *
 * Replaces the JSON-string detour previously used by ast.loads / dumps
 * (audit finding CB-3). Type fidelity preserved: integers stay integers
 * (number when safe, bigint when wider than 2^53), floats stay number,
 * bytes stay Buffer, etc.
 *
 * Type mapping:
 *   null/undefined            <-> CXDB null
 *   boolean                   <-> CXDB false/true
 *   number (Number.isInteger) <-> CXDB int8/int16/int32/int64
 *   number (non-integer)      <-> CXDB float64
 *   bigint                    <-> CXDB int8/int16/int32/int64
 *   string                    <-> CXDB string
 *   Buffer / Uint8Array       <-> CXDB bytes
 *   Date                      <-> CXDB datetime (placeholder source string in v1)
 *   Array                     <-> CXDB array
 *   Map<string,*>             <-> CXDB map (insertion order preserved)
 *   plain object              <-> CXDB map (Object.keys insertion order)
 *
 * Tables decode as Array<Record<string, any>> (one object per row),
 * matching the Python and Go reference codecs.
 */

// ── Tag bytes (spec/data_bin.md §3.2) ─────────────────────────────────────────
const TAG_NULL          = 0x00;
const TAG_FALSE         = 0x01;
const TAG_TRUE          = 0x02;
const TAG_INT8          = 0x10;
const TAG_INT16         = 0x11;
const TAG_INT32         = 0x12;
const TAG_INT64         = 0x13;
const TAG_FLOAT64       = 0x20;
const TAG_STRING        = 0x30;
const TAG_DATE          = 0x31;
const TAG_DATETIME      = 0x32;
const TAG_BYTES         = 0x33;
const TAG_ARRAY         = 0x40;
const TAG_ARRAY_EMPTY   = 0x41;
const TAG_MAP           = 0x50;
const TAG_MAP_EMPTY     = 0x51;
const TAG_TABLE         = 0x60;
const TAG_TABLE_EMPTY   = 0x61;

const CXDB_MAGIC = Buffer.from('CXDB', 'ascii');
const CXDB_VERSION = 0x01;
const CXDB_FLAGS_LE = 0x01;
const CXDB_DEFAULT_DEPTH = 64;

const I64_MAX = 9223372036854775807n;
const I64_MIN = -9223372036854775808n;
const SAFE_INT_MAX = BigInt(Number.MAX_SAFE_INTEGER);
const SAFE_INT_MIN = BigInt(Number.MIN_SAFE_INTEGER);

// ── Decoder ───────────────────────────────────────────────────────────────────

class Reader {
  private pos = 0;
  private depth = 0;
  constructor(private readonly buf: Buffer, private readonly maxDepth: number) {}

  private take(n: number): Buffer {
    if (this.pos + n > this.buf.length) {
      throw new Error(`cxdb: ${n} bytes requested, ${this.buf.length - this.pos} remaining`);
    }
    const out = this.buf.subarray(this.pos, this.pos + n);
    this.pos += n;
    return out;
  }

  u8(): number {
    if (this.pos >= this.buf.length) throw new Error('cxdb: unexpected end of input');
    return this.buf[this.pos++];
  }

  u16(): number {
    const v = this.buf.readUInt16LE(this.pos);
    this.pos += 2;
    return v;
  }

  uvarint(): number {
    let x = 0;
    let shift = 0;
    for (let i = 0; i < 5; i++) {
      const b = this.u8();
      if (b < 0x80) {
        if (i === 4 && b > 0x0F) throw new Error('cxdb: varint overflow (>2^32-1)');
        if (i > 0 && b === 0) throw new Error('cxdb: non-canonical varint (extra zero byte)');
        return x | (b << shift);
      }
      x |= (b & 0x7F) << shift;
      shift += 7;
    }
    throw new Error('cxdb: varint exceeds 5 bytes');
  }

  stringPayload(): string {
    const n = this.uvarint();
    return this.take(n).toString('utf8');
  }

  value(): any {
    this.depth++;
    if (this.depth > this.maxDepth) {
      throw new Error(`cxdb: recursion depth exceeds limit (${this.maxDepth})`);
    }
    try {
      const tag = this.u8();
      switch (tag) {
        case TAG_NULL:    return null;
        case TAG_FALSE:   return false;
        case TAG_TRUE:    return true;
        case TAG_INT8:    return this.take(1).readInt8(0);
        case TAG_INT16:   return this.take(2).readInt16LE(0);
        case TAG_INT32:   return this.take(4).readInt32LE(0);
        case TAG_INT64: {
          const big = this.take(8).readBigInt64LE(0);
          return big >= SAFE_INT_MIN && big <= SAFE_INT_MAX ? Number(big) : big;
        }
        case TAG_FLOAT64: return this.take(8).readDoubleLE(0);
        case TAG_STRING:  return this.stringPayload();
        case TAG_BYTES: {
          const n = this.uvarint();
          return Buffer.from(this.take(n));
        }
        case TAG_DATE: {
          const bs = this.take(4);
          const year = bs.readInt16LE(0);
          // Date constructor with year 0..99 maps to 1900..1999; build via setFullYear.
          const d = new Date(Date.UTC(2000, bs[2] - 1, bs[3]));
          d.setUTCFullYear(year);
          return d;
        }
        case TAG_DATETIME: {
          this.take(10); // 10 reserved bytes (placeholder)
          const srcLen = this.u16();
          const src = this.take(srcLen).toString('utf8');
          const t = new Date(src);
          return isNaN(t.getTime()) ? src : t;
        }
        case TAG_ARRAY: {
          const count = this.uvarint();
          if (count === 0) {
            throw new Error('cxdb: array tag 0x40 with count=0; use 0x41 for empty');
          }
          const out: any[] = new Array(count);
          for (let i = 0; i < count; i++) out[i] = this.value();
          return out;
        }
        case TAG_ARRAY_EMPTY: return [];
        case TAG_MAP: {
          const count = this.uvarint();
          if (count === 0) {
            throw new Error('cxdb: map tag 0x50 with count=0; use 0x51 for empty');
          }
          const out: Record<string, any> = {};
          for (let i = 0; i < count; i++) {
            const keyTag = this.u8();
            if (keyTag !== TAG_STRING) {
              throw new Error(`cxdb: map key must be string; got 0x${keyTag.toString(16).padStart(2, '0')}`);
            }
            const key = this.stringPayload();
            out[key] = this.value();
          }
          return out;
        }
        case TAG_MAP_EMPTY: return {};
        case TAG_TABLE:
        case TAG_TABLE_EMPTY:
          return this.tablePayload(tag);
        default:
          throw new Error(`cxdb: unknown tag 0x${tag.toString(16).padStart(2, '0')} at offset ${this.pos - 1}`);
      }
    } finally {
      this.depth--;
    }
  }

  private tablePayload(tag: number): any {
    if (tag === TAG_TABLE_EMPTY) return [];
    const colCount = this.uvarint();
    const cols: string[] = new Array(colCount);
    for (let i = 0; i < colCount; i++) {
      const keyTag = this.u8();
      if (keyTag !== TAG_STRING) {
        throw new Error(`cxdb: table column name must be string; got 0x${keyTag.toString(16).padStart(2, '0')}`);
      }
      cols[i] = this.stringPayload();
      this.u8(); // column type code (informational; per-cell tags drive decode)
    }
    const rowCount = this.uvarint();
    const rows: Record<string, any>[] = new Array(rowCount);
    for (let i = 0; i < rowCount; i++) rows[i] = {};
    for (let c = 0; c < colCount; c++) {
      for (let r = 0; r < rowCount; r++) {
        rows[r][cols[c]] = this.value();
      }
    }
    return rows;
  }
}

/**
 * Decode a CXDB v1 PAYLOAD (12-byte header + value section). The
 * [u32 LE size] frame is expected to have already been stripped by
 * callBinFn; pass the raw payload buffer directly.
 */
export function decode(payload: Buffer, maxDepth: number = CXDB_DEFAULT_DEPTH): any {
  if (payload.length < 12) {
    throw new Error('cxdb: payload too short for 12-byte header');
  }
  if (payload.compare(CXDB_MAGIC, 0, 4, 0, 4) !== 0) {
    throw new Error("cxdb: bad magic (expected 'CXDB')");
  }
  if (payload[4] !== CXDB_VERSION) {
    throw new Error(`cxdb: unsupported version ${payload[4]}`);
  }
  const flags = payload[5];
  if ((flags & 0xFE) !== 0) {
    throw new Error('cxdb: reserved flag bits set in header');
  }
  if ((flags & 0x01) === 0) {
    throw new Error('cxdb: only little-endian payloads supported in v1');
  }
  if (payload[10] !== 0 || payload[11] !== 0) {
    throw new Error('cxdb: reserved header bytes must be zero');
  }
  const r = new Reader(payload.subarray(12), maxDepth);
  return r.value();
}

// ── Encoder ───────────────────────────────────────────────────────────────────

class Writer {
  private chunks: Buffer[] = [];
  private len = 0;

  private push(b: Buffer): void {
    this.chunks.push(b);
    this.len += b.length;
  }

  u8(v: number): void {
    const b = Buffer.allocUnsafe(1);
    b[0] = v & 0xFF;
    this.push(b);
  }

  u16(v: number): void {
    const b = Buffer.allocUnsafe(2);
    b.writeUInt16LE(v, 0);
    this.push(b);
  }

  u32(v: number): void {
    const b = Buffer.allocUnsafe(4);
    b.writeUInt32LE(v, 0);
    this.push(b);
  }

  raw(b: Buffer): void {
    this.push(b);
  }

  uvarint(v: number): void {
    while (v >= 0x80) {
      this.u8((v & 0x7F) | 0x80);
      v >>>= 7;
    }
    this.u8(v & 0x7F);
  }

  stringValue(s: string): void {
    this.u8(TAG_STRING);
    const enc = Buffer.from(s, 'utf8');
    this.uvarint(enc.length);
    this.push(enc);
  }

  intCanonicalBig(v: bigint): void {
    if (v < I64_MIN || v > I64_MAX) {
      throw new Error(`cxdb: integer ${v.toString()} exceeds i64 range`);
    }
    if (v >= -128n && v <= 127n) {
      this.u8(TAG_INT8);
      const b = Buffer.allocUnsafe(1);
      b.writeInt8(Number(v), 0);
      this.push(b);
      return;
    }
    if (v >= -32768n && v <= 32767n) {
      this.u8(TAG_INT16);
      const b = Buffer.allocUnsafe(2);
      b.writeInt16LE(Number(v), 0);
      this.push(b);
      return;
    }
    if (v >= -2147483648n && v <= 2147483647n) {
      this.u8(TAG_INT32);
      const b = Buffer.allocUnsafe(4);
      b.writeInt32LE(Number(v), 0);
      this.push(b);
      return;
    }
    this.u8(TAG_INT64);
    const b = Buffer.allocUnsafe(8);
    b.writeBigInt64LE(v, 0);
    this.push(b);
  }

  value(v: any): void {
    if (v === null || v === undefined) {
      this.u8(TAG_NULL); return;
    }
    if (v === true)  { this.u8(TAG_TRUE);  return; }
    if (v === false) { this.u8(TAG_FALSE); return; }
    if (typeof v === 'bigint') {
      this.intCanonicalBig(v);
      return;
    }
    if (typeof v === 'number') {
      if (Number.isFinite(v) && Number.isInteger(v) &&
          v >= Number.MIN_SAFE_INTEGER && v <= Number.MAX_SAFE_INTEGER) {
        this.intCanonicalBig(BigInt(v));
        return;
      }
      this.u8(TAG_FLOAT64);
      const b = Buffer.allocUnsafe(8);
      b.writeDoubleLE(v, 0);
      this.push(b);
      return;
    }
    if (typeof v === 'string') {
      this.stringValue(v);
      return;
    }
    if (Buffer.isBuffer(v) || v instanceof Uint8Array) {
      this.u8(TAG_BYTES);
      const b = Buffer.isBuffer(v) ? v : Buffer.from(v);
      this.uvarint(b.length);
      this.push(b);
      return;
    }
    if (v instanceof Date) {
      const iso = v.toISOString();
      this.u8(TAG_DATETIME);
      this.push(Buffer.alloc(10)); // 10 reserved placeholder bytes
      const enc = Buffer.from(iso, 'utf8');
      this.u16(enc.length);
      this.push(enc);
      return;
    }
    if (Array.isArray(v)) {
      if (v.length === 0) { this.u8(TAG_ARRAY_EMPTY); return; }
      this.u8(TAG_ARRAY);
      this.uvarint(v.length);
      for (const item of v) this.value(item);
      return;
    }
    if (v instanceof Map) {
      if (v.size === 0) { this.u8(TAG_MAP_EMPTY); return; }
      this.u8(TAG_MAP);
      this.uvarint(v.size);
      for (const [k, vv] of v.entries()) {
        if (typeof k !== 'string') {
          throw new Error(`cxdb: map keys must be string; got ${typeof k}`);
        }
        this.stringValue(k);
        this.value(vv);
      }
      return;
    }
    if (typeof v === 'object' && Object.getPrototypeOf(v) === Object.prototype) {
      const keys = Object.keys(v);
      if (keys.length === 0) { this.u8(TAG_MAP_EMPTY); return; }
      this.u8(TAG_MAP);
      this.uvarint(keys.length);
      for (const k of keys) {
        this.stringValue(k);
        this.value(v[k]);
      }
      return;
    }
    throw new Error(`cxdb: unsupported type ${Object.prototype.toString.call(v)}`);
  }

  toBuffer(): Buffer {
    return Buffer.concat(this.chunks, this.len);
  }
}

/**
 * Encode a JS value to a FRAMED CXDB v1 buffer suitable for passing
 * directly to cx_from_data_bin. Output layout:
 *   [u32 LE size][CXDB magic][version][flags][u32 max_depth][u16 reserved][value...]
 */
export function encode(value: any): Buffer {
  const w = new Writer();
  // Header (12 bytes)
  w.raw(CXDB_MAGIC);
  w.u8(CXDB_VERSION);
  w.u8(CXDB_FLAGS_LE);
  w.u32(CXDB_DEFAULT_DEPTH);
  w.u8(0); w.u8(0);
  // Root value
  w.value(value);
  const payload = w.toBuffer();
  const framed = Buffer.allocUnsafe(4 + payload.length);
  framed.writeUInt32LE(payload.length, 0);
  payload.copy(framed, 4);
  return framed;
}
