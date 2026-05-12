/**
 * Streaming Table API tests for the TypeScript binding (Phase 7.74b-cont).
 *
 * Mirrors lang/python/test_streaming_table.py:
 *   1. cx_to_data_bin_chunked one-shot round-trip.
 *   2. bytes-mode round-trip: chunked emit → reader → writer → re-decode.
 *   3. fd-mode round-trip via temp file.
 *   4. invalid framed buffer raises an error.
 *
 * Run: tsx lang/typescript/test_streaming_table.ts
 */
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import * as cxlib from './cxlib/src';

const SIX_ROW_INPUT =
  '[points :table[name:string score:i32]\n' +
  '  alice 91\n' +
  '  bob 88\n' +
  '  carol 73\n' +
  '  dave 95\n' +
  '  eve 84\n' +
  '  frank 60\n' +
  ']';

let passed = 0;
let failed = 0;

function run(name: string, fn: () => void): void {
  try {
    fn();
    passed++;
  } catch (e: any) {
    failed++;
    console.error(`  FAIL  ${name}: ${e?.message ?? e}`);
    if (e?.stack) console.error(e.stack);
  }
}

function assert(cond: any, msg: string): asserts cond {
  if (!cond) throw new Error(msg);
}

run('test_to_data_bin_chunked_round_trip', () => {
  const framed = cxlib.toDataBinChunked(SIX_ROW_INPUT);
  assert(Buffer.isBuffer(framed) && framed.length > 4, 'framed should be a non-empty Buffer');
  const cxText = cxlib.fromDataBin(framed);
  assert(cxText.includes('alice') && cxText.includes('frank'), `round-trip lost rows: ${cxText}`);
});

run('test_streaming_table_bytes_round_trip', () => {
  const framed = cxlib.toDataBinChunked(SIX_ROW_INPUT);
  const r = new cxlib.TableReader(framed);
  let schema: Buffer;
  const groups: Buffer[] = [];
  try {
    schema = r.schema();
    for (let g = r.next(); g !== null; g = r.next()) groups.push(g);
  } finally { r.close(); }
  assert(groups.length >= 1, `no row groups; got ${groups.length}`);
  const w = new cxlib.TableWriter(schema!);
  let out: Buffer;
  try {
    for (const g of groups) w.emit(g);
    out = w.closeGetBytes();
  } catch (e) { w.close(); throw e; }
  assert(Buffer.isBuffer(out!) && out!.length > 4, 'closeGetBytes returned empty');
  const cxText = cxlib.fromDataBin(out!);
  assert(cxText.includes('alice'), `lost first row: ${cxText}`);
  assert(cxText.includes('frank'), `lost last row: ${cxText}`);
});

run('test_streaming_table_fd_round_trip', () => {
  const framed = cxlib.toDataBinChunked(SIX_ROW_INPUT);
  let schema: Buffer;
  const groups: Buffer[] = [];
  {
    const r = new cxlib.TableReader(framed);
    try {
      schema = r.schema();
      for (let g = r.next(); g !== null; g = r.next()) groups.push(g);
    } finally { r.close(); }
  }

  const fdPath = path.join(os.tmpdir(),
    `cx_streaming_table_ts_${process.pid}_${Date.now()}.cxdb`);
  const wfd = fs.openSync(fdPath, 'w');
  try {
    const w = new cxlib.TableWriter(schema!, { fd: wfd });
    try {
      for (const g of groups) w.emit(g);
    } finally { w.close(); }   // flushes end-of-table
  } finally { fs.closeSync(wfd); }

  const rfd = fs.openSync(fdPath, 'r');
  let roundtripSchema: Buffer;
  const roundtripGroups: Buffer[] = [];
  try {
    const r = new cxlib.TableReader({ fd: rfd });
    try {
      roundtripSchema = r.schema();
      for (let g = r.next(); g !== null; g = r.next()) roundtripGroups.push(g);
    } finally { r.close(); }
  } finally {
    fs.closeSync(rfd);
    fs.unlinkSync(fdPath);
  }

  assert(roundtripSchema!.equals(schema!), 'fd schema drift');
  assert(roundtripGroups.length === groups.length,
    `fd group count drift: ${roundtripGroups.length} vs ${groups.length}`);
});

run('test_reader_invalid_input_errors', () => {
  // [u32 LE size=4][garb] is well-framed but not a valid CXDB chunked-table.
  const bad = Buffer.from([0x04, 0x00, 0x00, 0x00, 0x67, 0x61, 0x72, 0x62]);
  let threw = false;
  try {
    const r = new cxlib.TableReader(bad);
    r.close();
  } catch (e) {
    threw = true;
  }
  assert(threw, 'expected an error opening an invalid framed buffer');
});

console.log(`Streaming Table tests (Phase 7.74b-cont, TypeScript)`);
console.log(`  ${passed} passed, ${failed} failed`);
process.exit(failed === 0 ? 0 : 1);
