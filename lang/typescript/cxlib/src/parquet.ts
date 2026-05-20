/**
 * Apache Parquet interop for cxlib TypeScript binding (X6 v0.7.0).
 *
 * Composes with the cxlib/arrow module: Parquet bytes round-trip
 * through apache-arrow JS via parquet-wasm or parquetjs (caller
 * chooses the runtime). The cxlib TS side exposes only the
 * high-level read/write entry points; the underlying codec is
 * handled by the chosen Parquet package.
 *
 * Two backends supported (one must be installed by the caller):
 *
 *   parquet-wasm  — WASM-based, no native deps, faster on modern Node
 *   parquetjs     — Pure-JS, broader compatibility
 *
 * Install whichever fits the target runtime:
 *   npm install parquet-wasm
 *   npm install parquetjs
 *
 * Usage:
 *   import * as cxParquet from '@cx-home/cx/parquet';
 *   const table = await cxParquet.tableFromParquetFile('data.parquet');
 *   await cxParquet.tableToParquetFile(table, 'out.parquet');
 *
 * The X-row contract (spec/v0_7_0_status.md §X) is that bindings
 * achieve byte-identical Parquet output when given the same input;
 * the TS binding inherits this via apache-arrow JS's deterministic
 * RecordBatch shape.
 */

import { tableFromIpc, tableToIpc } from './arrow';

type ParquetWasmModule = {
  readParquet: (bytes: Uint8Array) => Uint8Array;
  writeParquet: (ipcBytes: Uint8Array, writerProps?: unknown) => Uint8Array;
};

let _parquetWasm: ParquetWasmModule | null = null;
function getParquetWasm(): ParquetWasmModule {
  if (_parquetWasm) return _parquetWasm;
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    _parquetWasm = require('parquet-wasm') as ParquetWasmModule;
    return _parquetWasm;
  } catch (e) {
    throw new Error(
      "@cx-home/cx/parquet requires parquet-wasm; install via " +
      "'npm install parquet-wasm'"
    );
  }
}

/** Returns true when parquet-wasm is loadable. */
export function available(): boolean {
  try { getParquetWasm(); return true; } catch { return false; }
}

/**
 * Decode Parquet bytes to an apache-arrow JS Table. Routes through
 * parquet-wasm's readParquet (Parquet → Arrow IPC) and then through
 * cxlib/arrow's tableFromIpc (IPC → JS Table).
 */
export function tableFromParquet(parquetBytes: Uint8Array): unknown {
  const pq = getParquetWasm();
  const ipcBytes = pq.readParquet(parquetBytes);
  return tableFromIpc(ipcBytes);
}

/**
 * Encode an apache-arrow JS Table to Parquet bytes. Routes through
 * cxlib/arrow's tableToIpc (Table → IPC) and parquet-wasm's
 * writeParquet (IPC → Parquet).
 */
export function tableToParquet(table: unknown, writerProps?: unknown): Uint8Array {
  const ipcBytes = tableToIpc(table);
  const pq = getParquetWasm();
  return pq.writeParquet(ipcBytes, writerProps);
}

/**
 * Read a `.parquet` file from disk (Node) and return the parsed
 * apache-arrow Table.
 */
export async function tableFromParquetFile(path: string): Promise<unknown> {
  const fs = await import('fs/promises');
  const bytes = await fs.readFile(path);
  return tableFromParquet(new Uint8Array(bytes));
}

/**
 * Write an apache-arrow Table to a `.parquet` file at `path` (Node).
 */
export async function tableToParquetFile(
  table: unknown,
  path: string,
  writerProps?: unknown,
): Promise<void> {
  const fs = await import('fs/promises');
  const bytes = tableToParquet(table, writerProps);
  await fs.writeFile(path, bytes);
}
