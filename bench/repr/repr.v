// bench/repr/repr.v — the #1119 live-memory measurement instrument (RULED: RP-5).
//
// One CXDM corpus per lane is generated deterministically, parsed through that
// lane's parser, walked (so nothing is optimised away and the census is real),
// and then a collection is FORCED with the tree still reachable. vgc rebases
// `heap_live` to the bytes it actually marked, so `gc_heap_usage().total_bytes`
// read straight after the collect IS the live set — exact bytes, not the
// MB-rounded VGC_GCTRACE line.
//
// The reported quantity is a RATIO:
//
//     live_ratio = (live_after_parse - live_before_parse) / input_bytes
//
// The baseline collect happens with the corpus string already read, so both the
// input string and the runtime's own live set are subtracted rather than
// charged to the representation. Ratios, never absolute times or absolute
// bytes: the guard has to hold on a loaded machine and on other hardware
// (RP-5(a)(ii); (c) — an RSS-shaped bound — was rejected for exactly that).
//
// Usage:  repr gen <json|xml|cx|cxel> <corpus-path> [records]   — write the corpus
//         repr <json|xml|cx|cxel> <corpus-path> [records]       — measure it
//
// The two are SEPARATE PROCESSES on purpose; main() says why. Build, bounds and
// verdict live in run.sh — this driver only measures.
module main

import cx
import os
import strings

// default_records — 32,000 four-field records puts every lane at ~2 MB, which
// is what #700's dead-ends register buys: the whole lane runs in well under a
// second. The RP ledger's headline numbers came off the same record SHAPE at
// 300k (19-20 MB); see README.md for the two instruments side by side.
const default_records = 32000

// ── corpora ─────────────────────────────────────────────────────────────────
//
// The same logical data in three surfaces, so the three ratios are comparable
// to each other: flat records of `id` (int), `name` (string), `active` (bool),
// `score` (float) — the RP ledger's shape. Field values are a pure function of
// the record index, so the corpus is byte-identical on every machine and every
// run; nothing here reads the clock, the environment, or a random source.

// score_int is 100..999, so the float is always `<3 digits>.5` — one width in
// every lane, and a canonical CX form (`d.dd5e2`) that needs no float printer.
@[inline]
fn score_int(i int) int {
	return 100 + i % 900
}

fn gen_json(n int) string {
	mut b := strings.new_builder(n * 64)
	b.write_string('[')
	for i in 0 .. n {
		if i > 0 {
			b.write_string(',')
		}
		id := 100000 + i
		s := score_int(i)
		b.write_string('{"id":${id},"name":"user-${id}","active":${i % 2 == 0},"score":${s}.5}')
	}
	b.write_string(']')
	return b.str()
}

fn gen_xml(n int) string {
	mut b := strings.new_builder(n * 68)
	b.write_string('<recs>\n')
	for i in 0 .. n {
		id := 100000 + i
		s := score_int(i)
		b.write_string('<rec id="${id}" name="user-${id}" active="${i % 2 == 0}" score="${s}.5"/>\n')
	}
	b.write_string('</recs>\n')
	return b.str()
}

// gen_cx emits exactly what `cx --from=json --to=cx` produces for gen_json's
// output — an array of map literals, the MapNode carrier lane. The float is
// spelled in CX's canonical scientific form: 100.5 -> 1.005e2.
fn gen_cx(n int) string {
	mut b := strings.new_builder(n * 64)
	b.write_string('[')
	for i in 0 .. n {
		if i > 0 {
			b.write_string(', ')
		}
		id := 100000 + i
		s := score_int(i).str()
		b.write_string('{id: ${id}, name: user-${id}, active: ${i % 2 == 0}, score: ${s[0..1]}.${s[1..3]}5e2}')
	}
	b.write_string(']\n') // the cx emitter's trailing newline — see README.md
	return b.str()
}

// gen_cxel is the ELEMENT lane with string-carried scalar columns (#1247):
// every record carries an atom column of four distinct values, a date
// column of 365 distinct images and a duration column of twelve — the
// shapes RP-4's name interning did not reach, each occurrence its own heap
// copy until the per-parse scalar pool. Attribute values ride the parser's
// attribute autotype; the body item rides the body autotype.
fn two(n int) string {
	return if n < 10 { '0${n}' } else { '${n}' }
}

fn gen_cxel(n int) string {
	statuses := ['active', 'paused', 'closed', 'trial']
	mut b := strings.new_builder(n * 80)
	b.write_string('[records\n')
	for i in 0 .. n {
		id := 100000 + i
		day := i % 365
		b.write_string('  [rec id=${id} status=:${statuses[i % 4]} since=2026-${two((day / 31) % 12 + 1)}-${two(day % 28 + 1)} ttl=${(i % 12) + 1}h :${statuses[(i + 1) % 4]}]\n')
	}
	b.write_string(']\n')
	return b.str()
}


fn generate(lane string, n int) string {
	return match lane {
		'json' { gen_json(n) }
		'xml' { gen_xml(n) }
		'cx' { gen_cx(n) }
		'cxel' { gen_cxel(n) }
		else { panic('unknown lane `${lane}` (want json|xml|cx|cxel)') }
	}
}

// ── census ──────────────────────────────────────────────────────────────────
//
// Counts by node kind. Two jobs: it keeps the walk honest (an unwalked tree is
// a tree the optimiser may drop), and it is the per-node accounting every later
// wave reads to see WHICH allocation it removed. Not asserted on — the ratio is
// the guard.

struct Counts {
mut:
	elements     int
	attrs        int
	attr_meta    int
	elem_meta    int
	scalar_int   int
	scalar_float int
	scalar_bool  int
	scalar_null  int
	scalar_str   int
	scalar_other int
	text         int
	map_nodes    int
	map_entries  int
	array_nodes  int
	seq_nodes    int
	other        int
	name_bytes   i64 // element + attribute + map-key name bytes, per OCCURRENCE
	value_bytes  i64 // string payload bytes (scalar strings, text)
	empty_attrs  int // elements with zero attrs — each still owns an array block
	empty_items  int
}

fn (mut c Counts) scalar(v cx.ScalarValue, dt cx.ScalarType) {
	match v.kind() {
		.int_kind { c.scalar_int++ }
		.float_kind { c.scalar_float++ }
		.bool_kind { c.scalar_bool++ }
		.null_kind { c.scalar_null++ }
		.string_kind {
			if dt == .string_type {
				c.scalar_str++
			} else {
				c.scalar_other++
			}
			c.value_bytes += v.string_value().len
		}
	}
}

fn (mut c Counts) walk(n cx.Node) {
	match n.kind() {
		.element {
			e := n.element()
			c.elements++
			c.name_bytes += e.name.len
			if !isnil(e.meta) {
				c.elem_meta++
			}
			if e.attrs.len == 0 {
				c.empty_attrs++
			}
			if e.items.len == 0 {
				c.empty_items++
			}
			for a in e.attrs {
				c.attrs++
				c.name_bytes += a.name.len
				if !isnil(a.meta) {
					c.attr_meta++
				}
				c.scalar(a.value, .string_type)
			}
			for it in e.items {
				c.walk(it)
			}
		}
		.scalar_node {
			c.scalar(n.scalar_value(), n.scalar_kind())
		}
		.text_node {
			c.text++
			c.value_bytes += n.text_node().value.len
		}
		.map_node {
			m := n.map_node()
			c.map_nodes++
			for e in m.entries {
				c.map_entries++
				kv := e.key_value
				if kv.is_string() {
					c.name_bytes += kv.string_value().len
				}
				c.walk(e.value)
			}
		}
		.array_node {
			a := n.array_node()
			c.array_nodes++
			for it in a.items {
				c.walk(it)
			}
		}
		.sequence_node {
			s := n.sequence_node()
			c.seq_nodes++
			for it in s.items {
				c.walk(it)
			}
		}
		.document_node {
			d := n.document_node()
			for it in d.elements {
				c.walk(it)
			}
		}
		else {
			c.other++
		}
	}
}

fn parse_lane(lane string, src string) []cx.Node {
	match lane {
		'json' {
			return [cx.json_parse_strict(src, cx.JsonParseOpts{}) or { panic(err) }]
		}
		'xml' {
			doc := cx.parse_xml(src) or { panic(err) }
			return doc.elements
		}
		'cx', 'cxel' {
			doc := cx.parse(src) or { panic(err) }
			return doc.elements
		}
		else {
			panic('unknown lane `${lane}` (want json|xml|cx|cxel)')
		}
	}
}

// live_bytes — the bytes vgc marked in the cycle it just ran. `gc_collect()`
// is a full collection; both collector paths rebase `heap_live` to
// `vgc_count_marked()` at mark termination, so this read is the live set and
// not a committed-arena figure (`gc_memory_use()` would be the latter).
@[inline]
// scrub_stack overwrites the stack region the parse and census frames used, so
// a stale pointer to a dead buffer cannot survive as a conservative root into
// the measuring collect. @[noinline] so the frame really exists.
@[noinline]
fn scrub_stack() {
	mut pad := [262144]u8{}
	unsafe { C.memset(&pad[0], 0, 262144) }
	if pad[131072] != 0 {
		println('')
	}
}

fn live_bytes() u64 {
	return u64(gc_heap_usage().total_bytes)
}

fn main() {
	if os.args.len < 3 {
		eprintln('usage: repr gen <json|xml|cx|cxel> <corpus-path> [records]   # write the corpus')
		eprintln('       repr <json|xml|cx|cxel> <corpus-path> [records]       # measure it')
		exit(2)
	}

	// GENERATION IS A SEPARATE PROCESS, deliberately. vgc scans stacks and
	// registers conservatively, so what a run retains depends on the heap and
	// frame history that preceded the measurement — and generating a 2 MB
	// corpus in-process is a large slice of history. Measured: the identical
	// binary on the identical corpus reported 18.779x for the JSON lane when it
	// read an existing file and 17.771x when it had just generated it, a
	// difference of exactly one input-sized transient. Splitting the two modes
	// gives every measurement the SAME process shape, which is what makes the
	// readings all but exact run to run (README.md, "what the instrument can and
	// cannot see"). The residual one input copy is the ratchet's headroom.
	if os.args[1] == 'gen' {
		if os.args.len < 4 {
			eprintln('usage: repr gen <json|xml|cx|cxel> <corpus-path> [records]')
			exit(2)
		}
		lane := os.args[2]
		path := os.args[3]
		records := if os.args.len > 4 { os.args[4].int() } else { default_records }
		os.mkdir_all(os.dir(path)) or { panic(err) }
		os.write_file(path, generate(lane, records)) or { panic(err) }
		return
	}

	lane := os.args[1]
	path := os.args[2]
	records := if os.args.len > 3 { os.args[3].int() } else { default_records }

	if !os.exists(path) {
		eprintln('repr: no corpus at ${path} — generate it first: repr gen ${lane} ${path} ${records}')
		exit(2)
	}
	src := os.read_file(path) or { panic(err) }

	// Baseline WITH the corpus string already resident: the input bytes and the
	// runtime's own live set are subtracted, not charged to the representation.
	gc_collect()
	before := live_bytes()

	roots := parse_lane(lane, src)
	mut c := Counts{}
	for r in roots {
		c.walk(r)
	}
	// The collector is conservative about the stack: a dead pointer left in a
	// spilled register or a stale frame slot by parse_lane keeps whatever it
	// points at marked — measured as exactly one retained input copy (+1.0 on
	// the ratio, 7.941 → 8.941 on xml) in three post-merge runs whose process
	// environment differed from a shell's (make -j, the jobserver fds), and
	// never in a shell. Scrubbing the stack region those frames used, then
	// collecting twice, leaves only what the tree really reaches.
	scrub_stack()
	gc_collect()

	// The tree is still reachable through `roots` below this point — that is
	// the whole measurement: what a feature navigating this document PAYS.

	gc_collect()
	after := live_bytes()

	// THE KEEP-ALIVE, and why it is a second full walk rather than an opaque
	// branch: under `-prod` the Perceus front line drops a value after its LAST
	// REAL USE, and reading `roots.len` is not a use of the ELEMENTS. An earlier
	// version of this driver guarded the tree with `if roots.len > 1e9 { … }`
	// and the JSON lane measured 0.000x under `-prod` — the whole tree had been
	// released before the collect, i.e. the instrument was reporting the cost of
	// a document nobody was holding. Re-walking AFTER the read is a use the
	// compiler cannot move or elide, and it is self-checking: a census that
	// disagrees with the first walk means the tree was not intact across the
	// collection, which is a measurement to throw away (and, if it ever happens
	// without the optimiser's help, a vgc-soundness red — the #57/#58/#63/#973
	// lineage).
	mut c2 := Counts{}
	for r in roots {
		c2.walk(r)
	}
	if c2 != c {
		eprintln('repr: FATAL — the post-collect census differs from the pre-collect census.')
		eprintln('repr: the tree was not intact across gc_collect(); the ratio above is meaningless.')
		eprintln('repr: before=${c}')
		eprintln('repr: after =${c2}')
		exit(3)
	}

	repr_bytes := if after > before { after - before } else { u64(0) }
	ratio := f64(repr_bytes) / f64(src.len)

	println('lane=${lane} records=${records} input_bytes=${src.len} live_before=${before} live_after=${after} repr_bytes=${repr_bytes} ratio=${ratio:.3f}')
	println('census elements=${c.elements} attrs=${c.attrs} elem_meta=${c.elem_meta} attr_meta=${c.attr_meta} empty_attrs=${c.empty_attrs} empty_items=${c.empty_items}')
	println('census scalar_int=${c.scalar_int} scalar_float=${c.scalar_float} scalar_bool=${c.scalar_bool} scalar_null=${c.scalar_null} scalar_str=${c.scalar_str} scalar_other=${c.scalar_other} text=${c.text}')
	println('census map_nodes=${c.map_nodes} map_entries=${c.map_entries} array_nodes=${c.array_nodes} seq_nodes=${c.seq_nodes} other=${c.other}')
	println('census name_bytes=${c.name_bytes} value_bytes=${c.value_bytes} roots=${roots.len}')
	println('sizeof Node=${sizeof(cx.Node)} Element=${sizeof(cx.Element)} Attribute=${sizeof(cx.Attribute)} ScalarNode=${sizeof(cx.ScalarNode)} ScalarValue=${sizeof(cx.ScalarValue)} MapEntry=${sizeof(cx.MapEntry)}')
}
