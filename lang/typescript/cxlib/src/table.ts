/**
 * CX TypeScript binding — Public Table API per ADR 0018 D1.
 *
 * Implements the 17-member canonical Table API against the V core's
 * :table blocks via the C ABI. Per ADR 0018 §D2: TS uses camelCase
 * methods matching the canonical surface.
 */

import { toDataBin as _toDataBin } from "./index";
import * as data_bin from "./data_bin";

type CellValue =
  | null
  | boolean
  | number
  | string
  | CellValue[]
  | { [key: string]: CellValue };

/** Immutable handle over a single :table block. */
export class Table {
  private readonly _cols: string[];
  private readonly _types: string[];
  private readonly _rows: CellValue[][];

  private constructor(
    cols: string[],
    types: string[],
    rows: CellValue[][],
  ) {
    this._cols = [...cols];
    this._types = [...types];
    this._rows = rows.map((r) => [...r]);
  }

  // ── Construction ─────────────────────────────────────────────────────────

  /** Parse CX source and return the first :table block. */
  static fromCx(src: string): Table {
    const tables = Table.fromCxAll(src);
    if (tables.length === 0) {
      throw new Error("cxlib: no :table block found in source");
    }
    return tables[0];
  }

  /** Return every :table block in the source. */
  static fromCxAll(src: string): Table[] {
    const payload = _toDataBin(src);
    const decoded = data_bin.decode(payload);
    const out: Table[] = [];
    collectTables(decoded, out);
    return out;
  }

  /** Direct construction with 4-invariant validation per ADR 0018 §D7. */
  static create(
    cols: string[],
    types: string[],
    rows: CellValue[][],
  ): Table {
    if (cols.length !== types.length) {
      throw new Error(
        `cxlib: len(cols)=${cols.length} != len(types)=${types.length}`,
      );
    }
    const seen = new Set<string>();
    for (const c of cols) {
      if (seen.has(c)) {
        throw new Error(`cxlib: duplicate column name "${c}"`);
      }
      seen.add(c);
    }
    for (let i = 0; i < rows.length; i++) {
      if (rows[i].length !== cols.length) {
        throw new Error(
          `cxlib: row ${i} has ${rows[i].length} cells; expected ${cols.length}`,
        );
      }
    }
    return new Table(cols, types, rows);
  }

  // ── Properties (4) — exposed as getters ──────────────────────────────────

  get cols(): string[] { return [...this._cols]; }
  get types(): string[] { return [...this._types]; }
  get rowCount(): number { return this._rows.length; }
  get colCount(): number { return this._cols.length; }

  // ── Access (9) ───────────────────────────────────────────────────────────

  row(i: number): { [key: string]: CellValue } {
    if (i < 0 || i >= this._rows.length) {
      throw new Error(
        `cxlib: row index ${i} out of bounds [0, ${this._rows.length})`,
      );
    }
    const out: { [key: string]: CellValue } = {};
    this._cols.forEach((name, c) => {
      out[name] = this._rows[i][c];
    });
    return out;
  }

  column(name: string): CellValue[] {
    const idx = this._cols.indexOf(name);
    if (idx < 0) throw new Error(`cxlib: unknown column "${name}"`);
    return this.colAt(idx);
  }

  colAt(i: number): CellValue[] {
    if (i < 0 || i >= this._cols.length) {
      throw new Error(
        `cxlib: column index ${i} out of bounds [0, ${this._cols.length})`,
      );
    }
    return this._rows.map((row) => row[i]);
  }

  cell(r: number, c: number): CellValue {
    if (r < 0 || r >= this._rows.length) {
      throw new Error(
        `cxlib: row index ${r} out of bounds [0, ${this._rows.length})`,
      );
    }
    if (c < 0 || c >= this._cols.length) {
      throw new Error(
        `cxlib: column index ${c} out of bounds [0, ${this._cols.length})`,
      );
    }
    return this._rows[r][c];
  }

  cellByName(r: number, name: string): CellValue {
    const idx = this._cols.indexOf(name);
    if (idx < 0) throw new Error(`cxlib: unknown column "${name}"`);
    return this.cell(r, idx);
  }

  slice(start: number, end: number): Table {
    if (start < 0 || start > this._rows.length) {
      throw new Error(`cxlib: slice start ${start} out of bounds`);
    }
    if (end < start || end > this._rows.length) {
      throw new Error(`cxlib: slice end ${end} out of bounds (start=${start})`);
    }
    return new Table(this._cols, this._types, this._rows.slice(start, end));
  }

  head(n: number): Table {
    return this.slice(0, Math.min(Math.max(n, 0), this._rows.length));
  }

  tail(n: number): Table {
    const start = Math.max(0, this._rows.length - n);
    return this.slice(start, this._rows.length);
  }

  /**
   * `selectCols` — renamed from canonical `select` to mirror the
   * other bindings' rename pattern (Rust/V/Python use select_cols).
   * TS doesn't have a stdlib `select` conflict, but consistency wins.
   */
  selectCols(names: string[]): Table {
    const indices: number[] = [];
    const newCols: string[] = [];
    const newTypes: string[] = [];
    for (const name of names) {
      const idx = this._cols.indexOf(name);
      if (idx < 0) throw new Error(`cxlib: unknown column "${name}"`);
      indices.push(idx);
      newCols.push(this._cols[idx]);
      newTypes.push(this._types[idx]);
    }
    const newRows = this._rows.map((row) => indices.map((i) => row[i]));
    return new Table(newCols, newTypes, newRows);
  }

  // ── Iteration (2) ────────────────────────────────────────────────────────

  /** `for (const row of t)` yields ordered objects in row order. */
  *[Symbol.iterator](): IterableIterator<{ [key: string]: CellValue }> {
    for (let i = 0; i < this._rows.length; i++) {
      yield this.row(i);
    }
  }

  *iterCols(): IterableIterator<ColumnView> {
    for (let i = 0; i < this._cols.length; i++) {
      yield {
        name: this._cols[i],
        typeName: this._types[i],
        values: this.colAt(i),
      };
    }
  }

  // ── Conversion (5) ───────────────────────────────────────────────────────

  toCx(): string {
    const header = this._cols
      .map((name, i) =>
        this._types[i] === "" ? name : `${name}:${this._types[i]}`
      )
      .join(" ");
    const lines = [`[_ :table[${header}]`];
    for (const row of this._rows) {
      const cells = row.map(formatCxCell).join(" ");
      lines.push(`  ${cells}`);
    }
    lines.push("]");
    return lines.join("\n") + "\n";
  }

  toCsv(delim: string = ","): string {
    if (delim.length !== 1) {
      throw new Error(`cxlib: toCsv delim must be 1 char; got ${delim.length}`);
    }
    const lines = [this._cols.join(delim)];
    for (const row of this._rows) {
      lines.push(row.map((v) => formatCsvCell(v, delim)).join(delim));
    }
    return lines.join("\r\n") + "\r\n";
  }

  toJson(): string {
    return JSON.stringify(this.toDictList());
  }

  toDataBin(): Buffer {
    return _toDataBin(this.toCx());
  }

  toDictList(): { [key: string]: CellValue }[] {
    return this._rows.map((_, i) => this.row(i));
  }

  // ── Equality ─────────────────────────────────────────────────────────────

  equals(other: Table): boolean {
    if (!other || !(other instanceof Table)) return false;
    if (this._cols.length !== other._cols.length) return false;
    if (this._rows.length !== other._rows.length) return false;
    for (let i = 0; i < this._cols.length; i++) {
      if (this._cols[i] !== other._cols[i]) return false;
      if (this._types[i] !== other._types[i]) return false;
    }
    return JSON.stringify(this._rows) === JSON.stringify(other._rows);
  }
}

/** Column iterator view. */
export interface ColumnView {
  name: string;
  typeName: string;
  values: CellValue[];
}

// ── Internal: walk a decoded data_bin value to find tables ───────────────────

function collectTables(value: any, out: Table[]): void {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    for (const child of Object.values(value)) {
      collectTables(child, out);
    }
  } else if (Array.isArray(value)) {
    if (looksLikeTable(value)) {
      const first = value[0] as { [key: string]: any };
      const cols = Object.keys(first).sort();
      const types = cols.map(() => "");
      const rows = value.map((item) =>
        cols.map((c) => (item as any)[c])
      );
      out.push((Table as any).create(cols, types, rows));
    } else {
      for (const child of value) {
        collectTables(child, out);
      }
    }
  }
}

function looksLikeTable(value: any[]): boolean {
  if (value.length === 0) return false;
  const first = value[0];
  if (!first || typeof first !== "object" || Array.isArray(first)) {
    return false;
  }
  const keys = new Set(Object.keys(first));
  if (keys.size === 0) return false;
  return value.every((item) => {
    if (!item || typeof item !== "object" || Array.isArray(item)) return false;
    const itemKeys = Object.keys(item);
    if (itemKeys.length !== keys.size) return false;
    return itemKeys.every((k) => keys.has(k));
  });
}

// ── Internal: cell formatters ────────────────────────────────────────────────

function formatCxCell(v: CellValue): string {
  if (v === null) return "null";
  if (typeof v === "boolean") return v ? "true" : "false";
  if (typeof v === "number") return String(v);
  if (Array.isArray(v)) {
    return "[" + v.map(formatCxCell).join(", ") + "]";
  }
  if (typeof v === "object") {
    const keys = Object.keys(v).sort();
    return (
      "{" +
      keys.map((k) => `${formatCxKey(k)}: ${formatCxCell(v[k])}`).join(", ") +
      "}"
    );
  }
  // String
  const s = String(v);
  if (s === "" || /[\s'\[\](){},]/.test(s)) {
    return "'" + s.replace(/'/g, "''") + "'";
  }
  return s;
}

function formatCxKey(k: string): string {
  if (/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(k)) return k;
  return "'" + k.replace(/'/g, "''") + "'";
}

function formatCsvCell(v: CellValue, delim: string): string {
  if (v === null) return "";
  if (typeof v === "object") {
    const json = JSON.stringify(v);
    return '"' + json.replace(/"/g, '""') + '"';
  }
  if (typeof v === "boolean") return v ? "true" : "false";
  const s = String(v);
  if (s.includes(delim) || s.includes('"') || s.includes("\n") || s.includes("\r")) {
    return '"' + s.replace(/"/g, '""') + '"';
  }
  return s;
}
