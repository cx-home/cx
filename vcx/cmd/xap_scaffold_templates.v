module main

import cx

// The scaffold bodies for `cx xap scaffold <pattern>` (#1487, RULED: COMP-1)
// and the automation skeletons for `cx xap scaffold <skeleton>` (#1498,
// RULED: AA-1, AA-2, AA-3).
//
// THE BODIES ARE DATA (composition.md §3.9). The seven patterns' bodies and
// the four skeletons are CX documents shipped in cx-platform-flow —
// data/patterns/<slug>.cxd and data/skeletons/<name>.cxd (+ its reference
// <name>.answers.cxd) — and the scaffold, the generated primer chapter and the
// studio read those same documents. This file carries NO copy of a body: each
// document is `$embed_file`-d from the pinned checkout at compile time (the
// stdlib_bundle.v idiom), so a scaffold still never depends on the
// toolchain's source tree being present at run time, and a body changes in
// exactly one place.
//
// A pattern document is `[pattern slug= section= title= [need] [modules]
// [seams] [graded] [todo]… [file name=]…]`, every payload RAW TEXT (`[# … #]`),
// whose bytes the reader never touches — which is what keeps the emitted
// files byte-identical to the V literals they replaced. What §3 states is a
// declaration in those files; what it does not state is an authoring TODO,
// never a guess (connector.md §6.3, RULED: 1430-g).
//
// The sets are CLOSED (composition.md §3, §3.10): seven patterns and four
// skeletons, and a composition an adopter needs that is not one of them is a
// decision for the owner, not a variation to improvise.

struct XapScaffoldPattern {
	slug    string            // the name on the command line
	section string            // the composition.md section it is drawn from
	title   string            // that section's title
	need    string            // the enterprise need, in one sentence
	modules string            // the modules the pattern uses
	seams   string            // the §2 rows it crosses
	graded  string            // the reference example that grades it
	todos   []string          // what the pattern does NOT fix
	files   map[string]string // emitted name -> body
}

// An automation skeleton (composition.md §3.10): the document itself, its
// reference answers, and the slots its templates mark, in first-use order.
struct XapScaffoldSkeleton {
	name    string // the name on the command line
	trigger string // the binding kind its [on …] row carries
	shape   string // what the flow does, in a few words
	source  string // data/skeletons/<name>.cxd, verbatim
	answers string // data/skeletons/<name>.answers.cxd, verbatim
	slots   []string // `name (kind)`, first-use order
}

const xap_scaffold_pattern_docs = [
	$embed_file('../../../../deps/cx-platform-flow/data/patterns/poll-transform-sink.cxd').to_string(),
	$embed_file('../../../../deps/cx-platform-flow/data/patterns/approval-with-pivot.cxd').to_string(),
	$embed_file('../../../../deps/cx-platform-flow/data/patterns/async-bulk-export.cxd').to_string(),
	$embed_file('../../../../deps/cx-platform-flow/data/patterns/inbound-webhook.cxd').to_string(),
	$embed_file('../../../../deps/cx-platform-flow/data/patterns/fan-out-over-a-bus.cxd').to_string(),
	$embed_file('../../../../deps/cx-platform-flow/data/patterns/incremental-sync.cxd').to_string(),
	$embed_file('../../../../deps/cx-platform-flow/data/patterns/agent-surface.cxd').to_string(),
]

const xap_scaffold_skeleton_docs = [
	[
		$embed_file('../../../../deps/cx-platform-flow/data/skeletons/on-change-act.cxd').to_string(),
		$embed_file('../../../../deps/cx-platform-flow/data/skeletons/on-change-act.answers.cxd').to_string(),
	],
	[
		$embed_file('../../../../deps/cx-platform-flow/data/skeletons/on-change-approve.cxd').to_string(),
		$embed_file('../../../../deps/cx-platform-flow/data/skeletons/on-change-approve.answers.cxd').to_string(),
	],
	[
		$embed_file('../../../../deps/cx-platform-flow/data/skeletons/on-change-check.cxd').to_string(),
		$embed_file('../../../../deps/cx-platform-flow/data/skeletons/on-change-check.answers.cxd').to_string(),
	],
	[
		$embed_file('../../../../deps/cx-platform-flow/data/skeletons/on-schedule-act.cxd').to_string(),
		$embed_file('../../../../deps/cx-platform-flow/data/skeletons/on-schedule-act.answers.cxd').to_string(),
	],
]

// The embedded documents are part of the binary, so one that does not read as
// its shape is a build defect, not a user error: it panics naming the
// document rather than emitting a partial scaffold.
fn xap_scaffold_root(src string, head string) cx.Element {
	doc := cx.parse(src) or { panic('cx xap scaffold: an embedded ${head} document does not parse: ${err}') }
	for n in doc.elements {
		if n.is_element() && n.element().name == head {
			return *n.element()
		}
	}
	panic('cx xap scaffold: an embedded document carries no [${head} …] element')
}

// The payload of a child element: its raw text (byte-exact) or its text.
fn xap_scaffold_payload(e cx.Element) string {
	mut b := []string{}
	for it in e.items {
		if it.is_raw_text_node() {
			b << it.raw_text_node().value
		} else if it.is_text_node() {
			b << it.text_node().value
		} else if it.is_string() {
			b << it.string_value()
		}
	}
	return b.join('')
}

fn xap_scaffold_patterns() []XapScaffoldPattern {
	mut out := []XapScaffoldPattern{}
	for src in xap_scaffold_pattern_docs {
		p := xap_scaffold_root(src, 'pattern')
		mut need, mut modules, mut seams, mut graded := '', '', '', ''
		mut todos := []string{}
		mut files := map[string]string{}
		for it in p.items {
			if !it.is_element() {
				continue
			}
			c := it.element()
			match c.name {
				'need' { need = xap_scaffold_payload(c) }
				'modules' { modules = xap_scaffold_payload(c) }
				'seams' { seams = xap_scaffold_payload(c) }
				'graded' { graded = xap_scaffold_payload(c) }
				'todo' { todos << xap_scaffold_payload(c) }
				'file' { files[c.attr('name')] = xap_scaffold_payload(c) }
				else {}
			}
		}
		out << XapScaffoldPattern{
			slug:    p.attr('slug')
			section: p.attr('section')
			title:   p.attr('title')
			need:    need
			modules: modules
			seams:   seams
			graded:  graded
			todos:   todos
			files:   files
		}
	}
	return out
}

// The slots a template text marks, `[slot name=N kind=K]`, in first-use
// order — the same reading `fill` makes (cx-platform/flow).
fn xap_scaffold_slots(text string, mut seen []string, mut out []string) {
	for piece in text.split('[slot ')[1..] {
		body := piece.all_before(']')
		d := cx.parse('[slot ${body}]') or { continue }
		for n in d.elements {
			if n.is_element() && n.element().name == 'slot' {
				nm := n.element().attr('name')
				if nm !in seen {
					seen << nm
					out << '${nm} (${n.element().attr('kind')})'
				}
			}
		}
	}
}

fn xap_scaffold_skeletons() []XapScaffoldSkeleton {
	mut out := []XapScaffoldSkeleton{}
	for pair in xap_scaffold_skeleton_docs {
		s := xap_scaffold_root(pair[0], 'skeleton')
		mut seen := []string{}
		mut slots := []string{}
		for it in s.items {
			if it.is_element() && it.element().name in ['flow', 'on'] {
				xap_scaffold_slots(xap_scaffold_payload(it.element()), mut seen, mut slots)
			}
		}
		out << XapScaffoldSkeleton{
			name:    s.attr('name')
			trigger: s.attr('trigger')
			shape:   s.attr('shape')
			source:  pair[0]
			answers: pair[1]
			slots:   slots
		}
	}
	return out
}
