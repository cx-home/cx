module fixtures

import os
import cx

// CX-native conformance fixture loader — corpus tooling, NOT Ring-0 runtime.
//
// Lives in its own test-support module (I2 cleanup rider, partition spec
// §10 phase 2): it used to be `module cx`, which compiled it into every
// shipped libcx despite having zero production consumers. Only test lanes
// and conformance runners import it.
//
// The canonical fixture format is the CX document (`conformance/*.cxd`,
// schema `conformance/fixtures.cxs`). This loader reads a suite via the CX
// parser itself — dogfooding the parser on every test run — and reconstructs
// each `[case …]` into the legacy-shaped fields the test consumers expect,
// replacing the per-consumer hand-rolled `=== test:` / `--- key` text parsers.
//
// Section keys are returned in their LEGACY snake_case form (`in_cx`,
// `out_ast`, `sv_expected_codes`, …) so consumers key into `sections` exactly
// as they did against the old `.txt`. Typed sections (atom arrays / bools) are
// rendered back to their legacy textual form.

pub struct FixtureCase {
pub mut:
	name     string            // legacy test name: id, plus ' ' + title when titled
	level    string            // '' when the case carried no level
	gate     string            // gate toggle: enforced|advisory|pending|skip ('' = unset → enforced)
	grant    string            // Effort B least-privilege grant: space-separated capability list (e.g. 'read write'); 'none' = the EMPTY set (deny-all — pins ungated surfaces, PYE-3); '' = host default
	argv     string            // program argv the runner installs before eval (#926, PYE-2): space-separated, argv[0] included (e.g. 'prog.cx alpha'); '' = none installed
	ring     string            // per-case ring override ('' = inherit the suite header's ring=)
	eval_ring string           // per-case EVAL-lane ring override (I4; '' = inherit — see case_eval_ring)
	packs    []string          // declared local-effect pack dependencies (I4; profile gate skips when excluded)
	tol      f64               // relative float tolerance for out-text match (0 = exact, as today)
	rule     string            // normative evaluation-rule id this case witnesses (stream 22 §8: 'EV-…'; '' = none) — the rule→witness map is a corpus query
	tags     []string
	meta     map[string]string // extra header lines: view/kind/note/chunk_at/pending/…
	sections map[string]string // legacy section key -> normalized body
	order    []string          // section keys, document order
}

// FixtureSuite carries the suite-header metadata the ring-lane consumers
// (the I2 extraction gate, per-ring runners) resolve against: `ring=` with
// the per-case → per-suite resolution order (partition corpus audit §2 Q2)
// and the `eval-ring=` lane discriminator (code.cxd).
pub struct FixtureSuite {
pub mut:
	name      string
	ring      string // suite-header ring= ('' = untagged)
	eval_ring string // suite-header eval-ring= ('' = no split eval lane)
	cases     []FixtureCase
}

// load_suite parses a `.cxd` conformance suite and returns its cases along
// with the suite-header ring metadata. `case_ring(c)` resolves per-case.
pub fn load_suite(path string) FixtureSuite {
	src := os.read_file(path) or { panic('load_suite: cannot read ${path}: ${err}') }
	return parse_fixture_suite_meta(src, path)
}

// case_ring resolves the effective ring of a case within this suite
// (per-case override wins over the suite header).
pub fn (s FixtureSuite) case_ring(c FixtureCase) string {
	return if c.ring != '' { c.ring } else { s.ring }
}

// case_eval_ring resolves the EVAL-lane ring of a case (I4, fixtures.cxs):
// per-case eval-ring > per-case ring > suite eval-ring > suite ring. The
// doc/parse lane keeps case_ring — one case, two lane memberships (the
// code.cxd svc family: inert-data doc at ring 0, platform-substrate eval
// at ring 2).
pub fn (s FixtureSuite) case_eval_ring(c FixtureCase) string {
	if c.eval_ring != '' {
		return c.eval_ring
	}
	if c.ring != '' {
		return c.ring
	}
	if s.eval_ring != '' {
		return s.eval_ring
	}
	return s.ring
}

// load_fixtures parses a `.cxd` conformance suite and returns its cases.
pub fn load_fixtures(path string) []FixtureCase {
	src := os.read_file(path) or { panic('load_fixtures: cannot read ${path}: ${err}') }
	return parse_fixture_suite(src, path)
}

// parse_fixture_suite parses suite text already in memory (path is for errors).
//
// Uses parse_cx (not parse): a suite payload may contain a `---` line inside a
// RawText block (CX multi-doc *examples* under test). parse_cx routes through
// the lexer-driven parse_stream, which consumes `---` inside RawText correctly
// and only treats a top-level `---` as a separator — so such a suite parses to
// a single intact document.
pub fn parse_fixture_suite(src string, path string) []FixtureCase {
	return parse_fixture_suite_meta(src, path).cases
}

// parse_fixture_suite_meta is parse_fixture_suite plus the suite-header
// attributes (name / ring / eval-ring).
pub fn parse_fixture_suite_meta(src string, path string) FixtureSuite {
	res := cx.parse_cx(src) or { panic('load_fixtures: parse error in ${path}: ${err}') }
	mut docs := []cx.Document{}
	if m := res.multi {
		for d in m {
			docs << d
		}
	} else if d := res.single {
		docs << d
	}
	mut suite := FixtureSuite{}
	for doc in docs {
		for node in doc.elements {
			if node is cx.Element {
				if node.name == 'test-suite' {
					for a in node.attrs {
						match a.name {
							'name' { suite.name = cx.scalar_value_str_public(a.value) }
							'ring' { suite.ring = cx.scalar_value_str_public(a.value) }
							'eval-ring' { suite.eval_ring = cx.scalar_value_str_public(a.value) }
							else {}
						}
					}
					for child in node.items {
						if child is cx.Element {
							if child.name == 'case' {
								suite.cases << fixture_case_from(child)
							}
						}
					}
				}
			}
		}
	}
	return suite
}

fn fixture_case_from(c cx.Element) FixtureCase {
	mut fc := FixtureCase{
		sections: map[string]string{}
		meta:     map[string]string{}
	}
	mut id := ''
	for a in c.attrs {
		match a.name {
			'id' { id = cx.scalar_value_str_public(a.value) }
			'level' { fc.level = cx.scalar_value_str_public(a.value) }
			'gate' { fc.gate = cx.scalar_value_str_public(a.value) }
			'grant' { fc.grant = cx.scalar_value_str_public(a.value) }
			'argv' { fc.argv = cx.scalar_value_str_public(a.value) }
			'ring' { fc.ring = cx.scalar_value_str_public(a.value) }
			'eval-ring' { fc.eval_ring = cx.scalar_value_str_public(a.value) }
			'packs' { fc.packs = cx.scalar_value_str_public(a.value).split_any(' \t').filter(it != '') }
			'tol' { fc.tol = cx.scalar_value_str_public(a.value).f64() }
			'rule' { fc.rule = cx.scalar_value_str_public(a.value) }
			else {}
		}
	}
	mut title := ''
	for child in c.items {
		if child !is cx.Element {
			continue
		}
		el := child as cx.Element
		match el.name {
			'title' {
				title = fixture_rawtext(el) // inline [#…#] — exact, no normalize
			}
			'tags' {
				fc.tags = fixture_text(el).split_any(' \t').filter(it != '')
			}
			'meta' {
				body := fixture_normalize(fixture_rawtext(el))
				for line in body.split('\n') {
					idx := line.index(':') or { continue }
					fc.meta[line[..idx].trim_space()] = line[idx + 1..].trim_space()
				}
			}
			'expect-valid' {
				fc.sections['sv_assert_valid'] = if fixture_bool(el) { '1' } else { '0' }
				fc.order << 'sv_assert_valid'
			}
			'expect-codes' {
				fc.sections['sv_expected_codes'] = fixture_atom_csv(el)
				fc.order << 'sv_expected_codes'
			}
			'expect-warn-codes' {
				fc.sections['sv_expected_warn_codes'] = fixture_atom_csv(el)
				fc.order << 'sv_expected_warn_codes'
			}
			else {
				key := el.name.replace('-', '_')
				fc.sections[key] = fixture_normalize(fixture_rawtext(el))
				fc.order << key
			}
		}
	}
	fc.name = if title != '' { '${id} ${title}' } else { id }
	return fc
}

// fixture_rawtext concatenates the RawText payload(s) of a section element.
// (A literal `#]` in the payload is carried as adjacent RawText siblings;
// concatenation rejoins them.)
fn fixture_rawtext(e cx.Element) string {
	mut s := ''
	for it in e.items {
		if it is cx.RawTextNode {
			s += it.value
		}
	}
	return s
}

// fixture_text joins text/scalar body (used for the tags line).
fn fixture_text(e cx.Element) string {
	mut s := ''
	for it in e.items {
		match it {
			cx.TextNode { s += it.value }
			cx.ScalarNode { s += cx.scalar_value_str_public(it.value) }
			else {}
		}
	}
	return s
}

// fixture_normalize is the loader rule: strip one leading and one trailing
// newline (the ones introduced by the `[#` ⏎ … ⏎ `#]` layout).
fn fixture_normalize(raw string) string {
	mut s := raw
	if s.starts_with('\n') {
		s = s[1..]
	}
	if s.ends_with('\n') {
		s = s[..s.len - 1]
	}
	return s
}

fn fixture_bool(e cx.Element) bool {
	for it in e.items {
		if it is cx.ScalarNode {
			v := it.value
			if v is bool {
				return v
			}
		}
	}
	return false
}

fn fixture_atom_csv(e cx.Element) string {
	mut names := []string{}
	for it in e.items {
		if it is cx.ArrayNode {
			for item in it.items {
				if item is cx.ScalarNode {
					v := item.value
					if v is string {
						names << v
					}
				}
			}
		}
	}
	return names.join(',')
}
