#!/usr/bin/env tsx
/**
 * Round-trip tests for the TypeScript delimited (CSV/TSV/PSV) wrappers
 * (Phase 7.67 V core; Phase 7.68 TypeScript binding).
 *
 * Mirrors the 12-case shape of lang/python/test_delimited.py and
 * vcx/tests/v34_delimited_test.v.
 */
import {
  toCsv, toTsv, toPsv, fromCsv, toDelimited,
  csvToDataBin, tsvToDataBin, psvToDataBin,
  dataBinToCsv, dataBinToTsv, dataBinToPsv,
} from './cxlib/src/index';

function reframe(payload: Buffer): Buffer {
  const out = Buffer.alloc(4 + payload.length);
  out.writeUInt32LE(payload.length, 0);
  payload.copy(out, 4);
  return out;
}

let _passed = 0;
let _failed = 0;

function _run(name: string, fn: () => void): void {
  try {
    fn();
    _passed++;
  } catch (e: any) {
    _failed++;
    console.log(`  FAIL ${name}: ${e.message}`);
  }
}

function eq(actual: string, expected: string, label: string): void {
  if (actual !== expected) {
    throw new Error(`${label}\n  expected: ${JSON.stringify(expected)}\n  actual:   ${JSON.stringify(actual)}`);
  }
}

// ── Emit ─────────────────────────────────────────────────────────────────────

_run('emit_table_direct', () => {
  const src = '[users :table[name:string age:int active:bool]\n  alice 30 true\n  bob 25 false\n]';
  eq(toCsv(src), 'name,age,active\r\nalice,30,true\r\nbob,25,false\r\n', 'to_csv table direct');
});

_run('emit_repeated_row', () => {
  const src = '[users\n  [user id=1 name=alice +admin]\n  [user id=2 name=bob]\n  [user id=3 name=carol +admin]\n]';
  eq(toCsv(src), 'id,name,admin\r\n1,alice,true\r\n2,bob,\r\n3,carol,true\r\n', 'to_csv repeated row');
});

_run('emit_dotted_path', () => {
  const src = '[config\n  [server host=localhost port=8080 +tls]\n  [logging level=info format=json]\n]';
  const expected = 'server.host,server.port,server.tls,logging.level,logging.format\r\nlocalhost,8080,true,info,json\r\n';
  eq(toCsv(src), expected, 'to_csv dotted path');
});

_run('emit_tsv', () => {
  const src = '[t :table[a b c]\n  x y z\n]';
  eq(toTsv(src), 'a\tb\tc\r\nx\ty\tz\r\n', 'to_tsv');
});

_run('emit_psv', () => {
  const src = '[t :table[a b]\n  x y\n]';
  eq(toPsv(src), 'a|b\r\nx|y\r\n', 'to_psv');
});

// ── Parse ────────────────────────────────────────────────────────────────────

_run('parse_csv_basic_autotypes', () => {
  const csvIn = 'name,age,active\nalice,30,true\nbob,25,false\n';
  const expected = '[table :table[name age:int active:bool]\n  alice 30 true\n  bob 25 false\n]';
  eq(fromCsv(csvIn), expected, 'from_csv auto-types');
});

_run('parse_quoted_stays_string', () => {
  const csvIn = 'name,age\nalice,"30"\nbob,"25"\n';
  const expected = '[table :table[name age]\n  alice 30\n  bob 25\n]';
  eq(fromCsv(csvIn), expected, 'from_csv quoted stays string');
});

_run('parse_empty_cell_is_null', () => {
  const csvIn = 'name,age\nalice,30\nbob,\n';
  const expected = '[table :table[name age:int]\n  alice 30\n  bob null\n]';
  eq(fromCsv(csvIn), expected, 'from_csv empty cell is null');
});

// ── Arbitrary delimiter + data_bin one-shots ────────────────────────────────

_run('to_delimited_arbitrary', () => {
  const src = '[t :table[a b]\n  x y\n]';
  eq(toDelimited(src, ';'), 'a;b\r\nx;y\r\n', 'to_delimited semicolon');
});

_run('csv_to_data_bin_round_trip', () => {
  const payload = csvToDataBin('name,age\nalice,30\nbob,25\n');
  if (!Buffer.isBuffer(payload)) throw new Error('expected Buffer');
  const magic = payload.subarray(0, 4).toString('ascii');
  if (magic !== 'CXDB') throw new Error(`expected CXDB magic, got ${magic}`);
  const out = dataBinToCsv(reframe(payload));
  eq(out, 'name,age\r\nalice,30\r\nbob,25\r\n', 'csv round-trip');
});

_run('tsv_to_data_bin_round_trip', () => {
  const payload = tsvToDataBin('a\tb\nx\ty\n');
  const out = dataBinToTsv(reframe(payload));
  eq(out, 'a\tb\r\nx\ty\r\n', 'tsv round-trip');
});

_run('psv_to_data_bin_round_trip', () => {
  const payload = psvToDataBin('a|b\nx|y\n');
  const out = dataBinToPsv(reframe(payload));
  eq(out, 'a|b\r\nx|y\r\n', 'psv round-trip');
});

// ── main ──────────────────────────────────────────────────────────────────────

const status = _failed === 0 ? 'OK' : 'FAILED';
console.log(`typescript/delimited_test.ts: ${_passed} passed, ${_failed} failed  [${status}]`);
process.exit(_failed === 0 ? 0 : 1);
