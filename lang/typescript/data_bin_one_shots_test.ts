#!/usr/bin/env tsx
/**
 * Round-trip tests for the TypeScript data_bin one-shot wrappers
 * (Phase 7.28 V core; Phase 7.33 TypeScript binding).
 *
 * Loaders return UNFRAMED payload Buffers (matching toDataBin's
 * convention; callBinFn strips the [u32 LE size] frame). Dumpers
 * expect FRAMED Buffer input (matching fromDataBin's convention).
 * Tests use a `reframe()` helper to bridge.
 */
import {
  xmlToDataBin, jsonToDataBin, yamlToDataBin, tomlToDataBin, mdToDataBin,
  dataBinToXml, dataBinToJson, dataBinToYaml, dataBinToToml, dataBinToMd,
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

// ── XML one-shot ─────────────────────────────────────────────────────────────

_run('xmlToDataBin returns CXDB payload', () => {
  const payload = xmlToDataBin('<server><host>localhost</host><port>8080</port></server>');
  if (payload.length < 4) throw new Error(`expected non-empty payload, got ${payload.length}`);
  // Magic check
  const magic = payload.subarray(0, 4).toString('ascii');
  if (magic !== 'CXDB') throw new Error(`expected CXDB magic, got ${magic}`);
});

_run('xml round-trip through data_bin', () => {
  const payload = xmlToDataBin('<server><host>localhost</host><port>8080</port></server>');
  const out = dataBinToXml(reframe(payload));
  if (!out.includes('server')) throw new Error(`expected server: ${out}`);
  if (!out.includes('localhost')) throw new Error(`expected localhost: ${out}`);
  if (!out.includes('8080')) throw new Error(`expected 8080: ${out}`);
});

// ── JSON one-shot ────────────────────────────────────────────────────────────

_run('json round-trip through data_bin', () => {
  const payload = jsonToDataBin('{"name": "alice", "id": 1}');
  const out = dataBinToJson(reframe(payload));
  if (!out.includes('alice')) throw new Error(`expected alice: ${out}`);
  if (!out.includes('1')) throw new Error(`expected 1: ${out}`);
});

// ── YAML one-shot ────────────────────────────────────────────────────────────

_run('yaml round-trip through data_bin', () => {
  const payload = yamlToDataBin('name: alice\nid: 1\n');
  const out = dataBinToYaml(reframe(payload));
  if (!out.includes('alice')) throw new Error(`expected alice: ${out}`);
});

// ── TOML one-shot ────────────────────────────────────────────────────────────

_run('toml round-trip through data_bin', () => {
  const payload = tomlToDataBin('name = "alice"\nid = 1\n');
  const out = dataBinToToml(reframe(payload));
  if (!out.includes('alice')) throw new Error(`expected alice: ${out}`);
});

// ── Markdown one-shot ────────────────────────────────────────────────────────

_run('md round-trip through data_bin', () => {
  const payload = mdToDataBin('# Title\n\nA paragraph.\n');
  const out = dataBinToMd(reframe(payload));
  if (!out.includes('Title')) throw new Error(`expected Title: ${out}`);
});

// ── Cross-format compositions ────────────────────────────────────────────────

_run('xml → data_bin → json', () => {
  const payload = xmlToDataBin('<user id="1" name="alice"/>');
  const out = dataBinToJson(reframe(payload));
  if (!out.includes('alice')) throw new Error(`expected alice: ${out}`);
  if (!out.includes('1')) throw new Error(`expected 1: ${out}`);
});

_run('json → data_bin → yaml', () => {
  const payload = jsonToDataBin('{"name": "alice", "active": true}');
  const out = dataBinToYaml(reframe(payload));
  if (!out.includes('alice')) throw new Error(`expected alice: ${out}`);
});

_run('toml → data_bin → xml', () => {
  const payload = tomlToDataBin('host = "localhost"\nport = 8080\n');
  const out = dataBinToXml(reframe(payload));
  if (!out.includes('localhost')) throw new Error(`expected localhost: ${out}`);
  if (!out.includes('8080')) throw new Error(`expected 8080: ${out}`);
});

// ── main ──────────────────────────────────────────────────────────────────────

const status = _failed === 0 ? 'OK' : 'FAILED';
console.log(`typescript/data_bin_one_shots_test.ts: ${_passed} passed, ${_failed} failed  [${status}]`);
process.exit(_failed === 0 ? 0 : 1);
