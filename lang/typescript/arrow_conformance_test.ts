/**
 * Cross-binding Arrow conformance runner — TypeScript binding (W3 / v0.7.0).
 *
 * Reads conformance/data_bin_arrow.txt — the canonical Arrow C-Data
 * round-trip fixture corpus — and verifies the TS binding (lang/typescript/
 * cxlib/src/arrow.ts) round-trips each fixture's schema through
 * apache-arrow JS's IPC stream format.
 *
 * Pipeline (per W7 design):
 *   in_cx          → cxlib.to_data_bin           (CX → CXDB, TS side)
 *   schema         ← arrow_children_formats      (canonical Arrow C-Data formats)
 *   table          ← apache-arrow JS Table built from schema + sample data
 *   ipc bytes      ← cxArrow.tableToIpc(table)   (W7 emit path)
 *   table_back     ← cxArrow.tableFromIpc(bytes) (W7 consume path)
 *   verify schema(table_back) === schema(table)
 *
 * The TS binding consumes Arrow IPC bytes via apache-arrow JS rather than
 * libcx_arrow's C-Data Interface directly (per W7's IPC-bytes ABI variant).
 * This runner verifies the IPC round-trip preserves schema for every type
 * in the canonical corpus. Cross-binding byte-identity at the IPC layer
 * (W9) is verified by the producer-side bindings (Python/Go/Rust); the TS
 * side's job here is to prove it consumes IPC bytes losslessly.
 *
 * Run: tsx lang/typescript/arrow_conformance_test.ts
 */

import * as fs from 'fs';
import * as path from 'path';
import * as cx from './cxlib/src/index';
import * as cxArrow from './cxlib/src/arrow';

// apache-arrow types — peer dep. Loaded via require to avoid module-system
// issues with the cxlib build target. Resolve via the cxlib subdir's
// node_modules since apache-arrow is a peer dep of cxlib, not of this
// test runner.
const cxlibDir = path.resolve(__dirname, 'cxlib');
const require_from_cxlib = require('module').createRequire(
  path.join(cxlibDir, 'package.json'),
);
const arrow = require_from_cxlib('apache-arrow') as typeof import('apache-arrow');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const FIXTURE_PATH = path.join(REPO_ROOT, 'conformance', 'data_bin_arrow.txt');

// ── Fixture parser ──────────────────────────────────────────────────

interface Fixture {
  name: string;
  headers: Record<string, string>;
  sections: Record<string, string>;
}

function parseFixtures(filePath: string): Fixture[] {
  const tests: Fixture[] = [];
  let cur: Fixture | null = null;
  let section: string | null = null;
  let buf: string[] = [];

  const flush = () => {
    if (cur && section !== null) cur.sections[section] = buf.join('\n');
    buf = [];
  };

  for (const raw of fs.readFileSync(filePath, 'utf-8').split('\n')) {
    const line = raw.replace(/\n$/, '');
    if (line.startsWith('# ')) continue;
    let m: RegExpMatchArray | null;
    if ((m = line.match(/^===\s+test:\s+(\S+)\s*$/))) {
      flush();
      if (cur) tests.push(cur);
      cur = { name: m[1], headers: {}, sections: {} };
      section = null;
      continue;
    }
    if ((m = line.match(/^---\s+([\w-]+)\s*$/))) {
      flush();
      section = m[1];
      continue;
    }
    if (section !== null) { buf.push(line); continue; }
    if ((m = line.match(/^(\w+):\s*(.+?)\s*$/)) && cur) {
      cur.headers[m[1]] = m[2];
    }
  }
  flush();
  if (cur) tests.push(cur);
  return tests;
}

// ── Arrow type construction from cx-convention format strings ──────

// Build a DataType + sample values per the cx-convention Arrow C-Data
// format string. apache-arrow JS's runtime classes don't always survive
// IPC round-trip with instanceof checks (subclassing varies by version),
// so we use the typeId enum on the way back.

interface TypeSpec {
  type: arrow.DataType;
  samples: (n: number) => unknown[];
  fmt: string;
}

function specForFormat(fmt: string): TypeSpec {
  switch (fmt) {
    case 'l':
      return { fmt, type: new arrow.Int64(),
        samples: (n) => Array.from({ length: n }, (_, i) => BigInt(i + 1)) };
    case 'c':
      return { fmt, type: new arrow.Int8(),
        samples: (n) => Array.from({ length: n }, (_, i) => i + 1) };
    case 's':
      return { fmt, type: new arrow.Int16(),
        samples: (n) => Array.from({ length: n }, (_, i) => i + 1) };
    case 'i':
      return { fmt, type: new arrow.Int32(),
        samples: (n) => Array.from({ length: n }, (_, i) => i + 1) };
    case 'g':
      return { fmt, type: new arrow.Float64(),
        samples: (n) => Array.from({ length: n }, (_, i) => (i + 1) * 1.5) };
    case 'b':
      return { fmt, type: new arrow.Bool(),
        samples: (n) => Array.from({ length: n }, (_, i) => i % 2 === 0) };
    case 'u':
      return { fmt, type: new arrow.Utf8(),
        samples: (n) => Array.from({ length: n }, (_, i) => `s${i}`) };
    case 'tdD':
      return { fmt, type: new arrow.DateDay(),
        samples: (n) => Array.from({ length: n }, (_, i) => new Date(2024, 0, 1 + i)) };
    case 'tsn:UTC':
      // apache-arrow's TimestampNanosecond builder multiplies the value
      // by 1_000_000 internally (treats input as ms-since-epoch). Pass a
      // plain Number, not BigInt — the builder doesn't accept BigInt
      // values directly in v17+.
      return { fmt, type: new arrow.TimestampNanosecond('UTC'),
        samples: (n) => Array.from({ length: n },
          (_, i) => 1700000000000 + i * 1000) };
    case 'z':
      return { fmt, type: new arrow.Binary(),
        samples: (n) => Array.from({ length: n },
          (_, i) => new Uint8Array([i, i + 1, i + 2])) };
    default:
      throw new Error(`unsupported Arrow format string: ${fmt}`);
  }
}

// Reverse mapping using apache-arrow's typeId enum (stable across versions).
function arrowFormatFromType(t: arrow.DataType): string {
  // Type IDs from apache-arrow (Type enum).
  const Type = arrow.Type;
  switch (t.typeId) {
    case Type.Int:
      if ((t as arrow.Int).bitWidth === 8)  return 'c';
      if ((t as arrow.Int).bitWidth === 16) return 's';
      if ((t as arrow.Int).bitWidth === 32) return 'i';
      if ((t as arrow.Int).bitWidth === 64) return 'l';
      return `int${(t as arrow.Int).bitWidth}`;
    case Type.Float:
      return 'g';
    case Type.Bool:
      return 'b';
    case Type.Utf8:
      return 'u';
    case Type.Date:
      return 'tdD';
    case Type.Timestamp:
      return 'tsn:UTC';
    case Type.Binary:
      return 'z';
    default:
      return `unknown(typeId=${t.typeId})`;
  }
}

// ── Test execution ──────────────────────────────────────────────────

interface TestResult { name: string; ok: boolean; msg?: string }

function runFixture(fx: Fixture): TestResult {
  const formats = (fx.sections['arrow_children_formats'] ?? '').trim();
  const expectedErr = (fx.sections['expected_export_error'] ?? '').trim();

  // Negative tests don't apply to the TS IPC consumer path —
  // libcx_arrow's export errors don't reach the TS side. Skip them
  // honestly rather than fake-pass.
  if (expectedErr) {
    return { name: fx.name, ok: true, msg: `skipped (negative — libcx_arrow export error)` };
  }
  if (!formats) {
    return { name: fx.name, ok: true, msg: 'skipped (no arrow_children_formats — non-schema fixture)' };
  }

  const fmts = formats.split('\n').filter(l => l.length > 0);
  const specs = fmts.map(specForFormat);

  // Build a synthetic Table with the expected schema + 3 rows.
  const nRows = 3;
  const colNames = specs.map((_, i) => `c${i}`);
  const data: Record<string, arrow.Vector> = {};
  for (let i = 0; i < specs.length; i++) {
    data[colNames[i]] = arrow.vectorFromArray(specs[i].samples(nRows), specs[i].type);
  }
  const tableBefore = new arrow.Table(data);

  // Round-trip through the W7 IPC path.
  const ipcBytes = cxArrow.tableToIpc(tableBefore);
  const tableAfter = cxArrow.tableFromIpc(ipcBytes) as arrow.Table;

  // Verify schema preserved.
  const beforeFmts = tableBefore.schema.fields.map(f => arrowFormatFromType(f.type));
  const afterFmts  = tableAfter.schema.fields.map(f => arrowFormatFromType(f.type));
  if (beforeFmts.join(',') !== afterFmts.join(',')) {
    return { name: fx.name, ok: false,
      msg: `schema drift: before=${beforeFmts.join(',')} after=${afterFmts.join(',')}` };
  }
  if (beforeFmts.join(',') !== fmts.join(',')) {
    return { name: fx.name, ok: false,
      msg: `expected schema=${fmts.join(',')} actual=${beforeFmts.join(',')}` };
  }

  // Verify row count preserved.
  if (tableAfter.numRows !== tableBefore.numRows) {
    return { name: fx.name, ok: false,
      msg: `row-count drift: before=${tableBefore.numRows} after=${tableAfter.numRows}` };
  }

  // Bonus: verify the cxlib TS side still parses the fixture's CX (proves
  // the data path is alive end-to-end, even though we don't carry it
  // through Arrow IPC on the TS side).
  const inCx = (fx.sections['in_cx'] ?? '').trim();
  if (inCx) {
    try {
      cx.toDataBin(inCx);
    } catch (e) {
      return { name: fx.name, ok: false, msg: `cxlib.toDataBin failed: ${e}` };
    }
  }

  return { name: fx.name, ok: true };
}

// ── Main ────────────────────────────────────────────────────────────

function main(): number {
  if (!cxArrow.available()) {
    console.error('SKIP: apache-arrow JS not loadable (peer dependency missing)');
    return 0;
  }
  if (!fs.existsSync(FIXTURE_PATH)) {
    console.error(`FAIL: fixture corpus not found at ${FIXTURE_PATH}`);
    return 1;
  }
  const fixtures = parseFixtures(FIXTURE_PATH);
  let pass = 0;
  let fail = 0;
  let skip = 0;
  console.log(`Arrow conformance (TS binding): ${fixtures.length} fixtures`);
  for (const fx of fixtures) {
    const res = runFixture(fx);
    if (res.ok && res.msg) {
      console.log(`  SKIP ${res.name}: ${res.msg}`);
      skip++;
    } else if (res.ok) {
      console.log(`  PASS ${res.name}`);
      pass++;
    } else {
      console.log(`  FAIL ${res.name}: ${res.msg}`);
      fail++;
    }
  }
  console.log(`\n${pass} passed, ${fail} failed, ${skip} skipped (of ${fixtures.length})`);
  return fail === 0 ? 0 : 1;
}

process.exit(main());
