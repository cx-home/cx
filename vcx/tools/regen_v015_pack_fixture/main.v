module main

import os
import cxstore

// regen_v015_pack_fixture — generates the committed v0.15-shaped pack fixture
// that pins store read-compat (RULED: CO-1, #974;
// ledger/rulings_2026_08_25_0170_closeout.md).
//
// Output: vcx/tests/testdata/v015_pack_compat/store-0000.cxpack
//
// Run from the repo root:
//   third_party/v/v run vcx/tools/regen_v015_pack_fixture/
//
// WHAT THE FIXTURE IS
//
// v0.15's pack writer emitted a literal `0` into the then-RESERVED u16 at
// entry offset 6. v0.16 (8fafb76fa) gave that slot a meaning — the hash
// multicodec — and made the reader fail closed on everything but sha2-256
// (0x0012), which retroactively made every v0.15 pack unreadable. CO-1 rules
// zero back in as sha2-256, since that is the only algorithm a v0.15 pack can
// possibly be named by.
//
// So the fixture is a pack written by the CURRENT engine with exactly ONE
// difference applied afterwards: every entry's multicodec slot zeroed. That
// isolates the single variable under test — no other v0.15/v0.17 format drift
// rides along to muddy what a green pin proves.
//
// HOW THE ZEROING IS VERIFIED
//
// The walk here deliberately does NOT reuse the footer index the reader uses.
// It walks the ENTRY CHAIN from offset 64 (header_size) by entry_length (u32
// LE at entry+0), reading the slot at entry+6, and REQUIRES each one to read
// 0x0012 before zeroing it. Two independent things fall out of that:
//
//   * the chain layout is confirmed against the writer, not assumed — a bad
//     entry_length walks off the rails and the length check at the end fails;
//   * EVERY entry is zeroed, not merely every indexed one, so the fixture
//     cannot accidentally pass by having an unreached entry left current.
//
// Zeroing changes no hash, CRC, or signature: the slot is covered by none of
// them (see stamp_pack_hash_slots in vcx/cxstore/pack.v for the itemized
// verification against all four integrity computations). The pack's bytes are
// otherwise untouched, so it is byte-for-byte a legal pack.
//
// Five entries — the five one-byte edits of the #974 zeroing witness (the
// high byte of the slot is already 0, so 0x0012 → 0x0000 is one byte each).
//
// The fixture is a FROZEN compatibility artifact: regenerating it is only
// meaningful if the pack format itself moves, and a format move that changes
// these bytes is a compatibility event needing its own ruling.

const fixture_payloads = [
	'cx-v015-compat: alpha',
	'cx-v015-compat: beta',
	'cx-v015-compat: gamma',
	'cx-v015-compat: delta',
	'cx-v015-compat: epsilon',
]

const header_size = 64 // pack header, ahead of the entry chain

fn read_u32_le(b []u8, off int) u32 {
	return u32(b[off]) | (u32(b[off + 1]) << 8) | (u32(b[off + 2]) << 16) | (u32(b[off + 3]) << 24)
}

fn read_u64_le(b []u8, off int) u64 {
	mut v := u64(0)
	for i in 0 .. 8 {
		v |= u64(b[off + i]) << (u64(i) * 8)
	}
	return v
}

fn read_u16_le(b []u8, off int) u16 {
	return u16(b[off]) | (u16(b[off + 1]) << 8)
}

fn die(msg string) {
	eprintln('regen_v015_pack_fixture: ${msg}')
	exit(1)
}

fn main() {
	out_dir := if os.args.len > 1 {
		os.args[1]
	} else {
		os.join_path('vcx', 'tests', 'testdata', 'v015_pack_compat')
	}
	os.mkdir_all(out_dir) or { die('mkdir ${out_dir}: ${err}') }

	// ── 1. write a small store with the CURRENT binary ──────────────────
	tmp := os.join_path(os.temp_dir(), 'regen_v015_pack_fixture.cxpack')
	os.rm(tmp) or {}
	payloads := fixture_payloads.map(it.bytes())
	cxstore.write_pack(tmp, payloads) or { die('write_pack: ${err}') }
	mut data := os.read_bytes(tmp) or {
		die('read ${tmp}: ${err}')
		return
	}
	os.rm(tmp) or {}

	// The entry chain ends where the footer begins: the last 8 bytes of the
	// file are the footer length, and the footer sits immediately before them.
	flen := read_u64_le(data, data.len - 8)
	chain_end := data.len - 8 - int(flen)
	if chain_end <= header_size {
		die('degenerate pack: entry chain is empty (chain_end=${chain_end})')
	}

	// ── 2. walk the chain, assert 0x0012, zero it ───────────────────────
	mut off := header_size
	mut zeroed := 0
	for off < chain_end {
		elen := int(read_u32_le(data, off))
		if elen < 44 || off + elen > chain_end {
			die('entry ${zeroed} at offset ${off}: implausible entry_length ${elen} (chain_end=${chain_end}) — the entry-chain layout moved')
		}
		code := read_u16_le(data, off + 6)
		if code != 0x0012 {
			die('entry ${zeroed} at offset ${off}: multicodec slot reads 0x${code:04x}, expected sha2-256 0x0012 — refusing to author a fixture from an unexpected pack')
		}
		data[off + 6] = 0
		data[off + 7] = 0
		zeroed++
		off += elen
	}
	if off != chain_end {
		die('entry chain overran the footer: ended at ${off}, footer starts at ${chain_end}')
	}
	if zeroed != fixture_payloads.len {
		die('walked ${zeroed} entries, expected ${fixture_payloads.len} — the writer deduplicated or the walk lost the chain')
	}

	// ── 3. commit the bytes ─────────────────────────────────────────────
	out := os.join_path(out_dir, 'store-0000.cxpack')
	os.write_file_array(out, data) or { die('write ${out}: ${err}') }
	println('regen_v015_pack_fixture: wrote ${out} (${data.len} bytes, ${zeroed} entry slots zeroed to the v0.15 shape)')
}
