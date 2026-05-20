/**
 * Apache Arrow interop for cxlib TypeScript binding.
 *
 * W7 v0.7.0 — landing path per the IPC-bytes ABI variant plan
 * (spec/v0_7_0_status.md §W7). The TypeScript binding consumes
 * Arrow IPC stream bytes via apache-arrow JS rather than the
 * C-Data Interface (which is awkward to bridge through node-ffi /
 * koffi). The IPC byte stream is the canonical interchange
 * format for cross-binding Arrow round-trip.
 *
 * Pipeline:
 *   CX → Python/Go/Rust binding → Arrow IPC bytes → TS apache-arrow → JS Table
 *   JS Table → Arrow IPC bytes → Python/Go/Rust binding → CX
 *
 * The TS-side toIpc / fromIpc helpers expect callers to obtain IPC
 * bytes externally (via another binding, a file, or a network
 * payload). Direct CX → IPC encoding from the TS binding requires
 * libcx_arrow IPC encoder support (dependent on either V-side
 * flatbuffer encoding or Apache Arrow C++ library linkage in
 * libcx_arrow); both options are tracked v0.7.x follow-ups gated
 * on the C++/V build-infra decision.
 *
 * Install apache-arrow (peer dependency):
 *   npm install apache-arrow
 *
 * Then:
 *   import * as cxArrow from '@cx-home/cx/arrow';
 *   const table = await cxArrow.tableFromIpc(ipcBytes);
 */

// apache-arrow is a peer dependency — declared optional so cxlib
// builds without it. Consumers who use this module must install it.
type ApacheArrowModule = typeof import('apache-arrow');

let _arrow: ApacheArrowModule | null = null;
function getArrow(): ApacheArrowModule {
  if (_arrow) return _arrow;
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    _arrow = require('apache-arrow') as ApacheArrowModule;
    return _arrow;
  } catch (e) {
    throw new Error(
      "@cx-home/cx/arrow requires apache-arrow; install via " +
      "'npm install apache-arrow' (peer dependency)"
    );
  }
}

/**
 * Returns true when apache-arrow is loadable. Mirrors the
 * cxlib.arrow.available() pattern across bindings.
 */
export function available(): boolean {
  try { getArrow(); return true; } catch { return false; }
}

/**
 * Parse Arrow IPC stream bytes (the byte form of an `.arrow` file)
 * into a JS apache-arrow Table.
 */
export function tableFromIpc(ipcBytes: Uint8Array): unknown {
  const arrow = getArrow();
  return arrow.tableFromIPC(ipcBytes);
}

/**
 * Serialize an apache-arrow Table to Arrow IPC stream bytes
 * suitable for piping into another Arrow consumer (file, network,
 * or another cxlib binding's `from_ipc` import).
 */
export function tableToIpc(table: unknown): Uint8Array {
  const arrow = getArrow();
  // apache-arrow JS uses RecordBatchStreamWriter.writeAll under the
  // hood. tableToIPC is the convenience wrapper.
  return arrow.tableToIPC(table as never, 'stream');
}

/**
 * Read a `.arrow` IPC file from disk (Node) and return the parsed
 * apache-arrow Table.
 */
export async function readIpcFile(path: string): Promise<unknown> {
  // Defer fs to avoid breaking browser builds.
  const fs = await import('fs/promises');
  const bytes = await fs.readFile(path);
  return tableFromIpc(new Uint8Array(bytes));
}

/**
 * Write an apache-arrow Table to a `.arrow` IPC file at `path`
 * (Node).
 */
export async function writeIpcFile(table: unknown, path: string): Promise<void> {
  const fs = await import('fs/promises');
  const bytes = tableToIpc(table);
  await fs.writeFile(path, bytes);
}
