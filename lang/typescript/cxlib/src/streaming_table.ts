/**
 * Streaming Table reader / writer for the chunked-table CXDB format.
 *
 * Per spec/abi.md §2.10 (capability bit 21) and ADR 0015 D8. Pull / push
 * one row group at a time; memory is bounded by the largest single row
 * group plus a constant overhead.
 *
 * Wire conventions (mirroring the C ABI):
 *   - In-memory variants consume / produce framed `[u32 LE size][CXDB payload]`.
 *   - fd variants operate on bare CXDB bytes (no size prefix); the file's
 *     length is implicit and writers cannot prefix output with an
 *     end-of-table size unknown until close.
 *
 * Col-spec exchange: framed ast_bin with one root Element 'table' and
 * one Attribute per column (name = column name, value = type-name).
 *
 * Usage (in-memory round-trip):
 *
 *   const framed = cxlib.toDataBinChunked('[points :table[a:int b:int] 1 2]');
 *   const groups: Buffer[] = [];
 *   const r = new cxlib.TableReader(framed);
 *   try {
 *     const schema = r.schema();
 *     for (let g = r.next(); g !== null; g = r.next()) groups.push(g);
 *     const w = new cxlib.TableWriter(schema);
 *     try {
 *       for (const g of groups) w.emit(g);
 *       const out = w.closeGetBytes();
 *     } finally { w.close(); }
 *   } finally { r.close(); }
 */
import { _internal } from './index';

function readFramed(ptr: any): Buffer {
  const koffi = _internal.koffi;
  const payloadSize: number = Number(koffi.decode(ptr, 'uint32_t') as number);
  const ab: ArrayBuffer = koffi.view(ptr, 4 + payloadSize);
  return Buffer.from(Buffer.from(ab));
}

export class TableReader {
  private handle: any;
  private closed = false;

  /** Open from a framed CXDB chunked-table buffer (`[u32 LE size][payload]`). */
  constructor(dataBin: Buffer);
  /** Open from a file descriptor positioned at the start of a bare CXDB stream. */
  constructor(opts: { fd: number });
  constructor(arg: Buffer | { fd: number }) {
    const errArr: (string | null)[] = [null];
    let h: any;
    if (Buffer.isBuffer(arg)) {
      h = _internal.cx_table_reader_open(arg, errArr);
    } else {
      h = _internal.cx_table_reader_open_fd(arg.fd, errArr);
    }
    if (h === null || h === undefined) {
      throw new Error(errArr[0] ?? 'cx_table_reader_open: unknown error');
    }
    this.handle = h;
  }

  /** Returns the table's col-spec as framed ast_bin. */
  schema(): Buffer {
    if (this.closed || !this.handle) throw new Error('TableReader: handle closed');
    const errArr: (string | null)[] = [null];
    const ptr: any = _internal.cx_table_reader_schema(this.handle, errArr);
    if (ptr === null || ptr === undefined) {
      throw new Error(errArr[0] ?? 'cx_table_reader_schema: unknown error');
    }
    const out = readFramed(ptr);
    _internal.cx_free(ptr);
    return out;
  }

  /** Pull the next row group as framed `[u32 LE size][plain body]` bytes
   *  (compressed groups are decompressed by the V core). Returns null
   *  on EOF; throws on error. */
  next(): Buffer | null {
    if (this.closed || !this.handle) return null;
    const errArr: (string | null)[] = [null];
    const ptr: any = _internal.cx_table_reader_next(this.handle, errArr);
    if (ptr === null || ptr === undefined) {
      if (errArr[0]) {
        const msg = errArr[0];
        this.close();
        throw new Error(msg);
      }
      return null;
    }
    const out = readFramed(ptr);
    _internal.cx_free(ptr);
    return out;
  }

  close(): void {
    if (this.closed) return;
    this.closed = true;
    if (this.handle) {
      _internal.cx_table_reader_close(this.handle);
      this.handle = null;
    }
  }

  [Symbol.iterator](): Iterator<Buffer> {
    return {
      next: (): IteratorResult<Buffer> => {
        const g = this.next();
        return g === null ? { value: undefined as any, done: true } : { value: g, done: false };
      },
    };
  }
}

export class TableWriter {
  private handle: any;
  private closed = false;
  private fd: number | undefined;

  /** Open an in-memory writer; complete with `closeGetBytes()`. */
  constructor(colSpecPayload: Buffer);
  /** Open a streaming-fd writer; complete with `close()` to flush end-of-table. */
  constructor(colSpecPayload: Buffer, opts: { fd: number });
  constructor(colSpecPayload: Buffer, opts?: { fd: number }) {
    const errArr: (string | null)[] = [null];
    let h: any;
    if (opts === undefined) {
      h = _internal.cx_table_writer_open(colSpecPayload, errArr);
    } else {
      h = _internal.cx_table_writer_open_fd(colSpecPayload, opts.fd, errArr);
      this.fd = opts.fd;
    }
    if (h === null || h === undefined) {
      throw new Error(errArr[0] ?? 'cx_table_writer_open: unknown error');
    }
    this.handle = h;
  }

  /** Append one row group. `rowGroupPayload` is the framed
   *  `[u32 LE size][plain body]` shape yielded by TableReader.next(). */
  emit(rowGroupPayload: Buffer): void {
    if (this.closed || !this.handle) throw new Error('TableWriter: handle closed');
    const errArr: (string | null)[] = [null];
    const ret: string | null = _internal.cx_table_writer_emit_row_group(this.handle, rowGroupPayload, errArr);
    // Convention: char* return is unused on success; non-null err means failure.
    if (errArr[0]) {
      throw new Error(errArr[0]);
    }
    void ret;
  }

  /** In-memory writers only: emit end-of-table and return the complete
   *  framed chunked-table buffer. */
  closeGetBytes(): Buffer {
    if (this.fd !== undefined) {
      throw new Error('closeGetBytes is for in-memory writers; use close() for fd writers');
    }
    if (this.closed || !this.handle) throw new Error('TableWriter: handle closed');
    const errArr: (string | null)[] = [null];
    const ptr: any = _internal.cx_table_writer_close_get_bytes(this.handle, errArr);
    // V core releases the handle inside close_get_bytes; mark closed.
    this.handle = null;
    this.closed = true;
    if (ptr === null || ptr === undefined) {
      throw new Error(errArr[0] ?? 'cx_table_writer_close_get_bytes: unknown error');
    }
    const out = readFramed(ptr);
    _internal.cx_free(ptr);
    return out;
  }

  /** Release the handle. For fd writers, flushes the end-of-table marker. */
  close(): void {
    if (this.closed) return;
    this.closed = true;
    if (this.handle) {
      _internal.cx_table_writer_close(this.handle);
      this.handle = null;
    }
  }
}
