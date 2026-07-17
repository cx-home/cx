module cxstore

import cx

// Index-aware CXPath query planner (issue #87). Today a store query scans every
// document then collects element matches. The planner uses the #85 secondary
// index to prune the candidate set first: for a simple element-name step
// (`//name` or `/name`), only documents the index says contain `name` are
// scanned. Anything else (predicates, multi-step paths, attribute axes) falls
// back to a full scan — never wrong, just unaccelerated.
//
// Soundness: the secondary index records every element at every depth, so its
// docs_with_element(name) is a SUPERSET of the documents a name-step could
// match → pruning to candidates can never drop a real match.

pub struct QueryPlan {
pub:
	target     string
	descendant bool
	indexable  bool
	candidates []string // store keys to scan (== all keys when !indexable)
}

// plan_query parses a CXPath name-step and resolves candidate documents via the
// index, or falls back to all_keys for non-indexable queries.
pub fn plan_query(ix &SecondaryIndex, all_keys []string, cxpath string) QueryPlan {
	mut target := cxpath.trim_space()
	mut descendant := false
	if target.starts_with('//') {
		descendant = true
		target = target[2..]
	} else if target.starts_with('/') {
		target = target[1..]
	}
	// indexable only for a single bare element-name step
	if target == '' || target.contains('/') || target.contains('[') || target.contains('@')
		|| target.contains(' ') {
		return QueryPlan{
			target:     target
			descendant: descendant
			indexable:  false
			candidates: all_keys.clone()
		}
	}
	return QueryPlan{
		target:     target
		descendant: descendant
		indexable:  true
		candidates: ix.docs_with_element(target)
	}
}

// collect_by_name mirrors the store's element-name match: children of a node
// named `target` (and, when descendant, at any depth below).
fn collect_by_name(n cx.Node, target string, descendant bool, mut out []cx.Node) {
	if n is cx.Element {
		for child in n.items {
			if child is cx.Element {
				if child.name == target {
					out << child
				}
			}
			if descendant {
				collect_by_name(child, target, descendant, mut out)
			}
		}
	}
}

fn (r &Repo) run_query(keys []string, target string, descendant bool) []string {
	mut hits := []string{}
	for key in keys {
		doc := r.get_doc(key) or { continue }
		mut matches := []cx.Node{}
		for el in doc.elements {
			collect_by_name(el, target, descendant, mut matches)
		}
		if matches.len > 0 {
			hits << key
		}
	}
	return hits
}

// query evaluates a CXPath name-step using the index to prune candidates.
pub fn (r &Repo) query(ix &SecondaryIndex, cxpath string) []string {
	plan := plan_query(ix, r.list(), cxpath)
	return r.run_query(plan.candidates, plan.target, plan.descendant)
}

// query_full evaluates over every document (no pruning) — the parity baseline.
pub fn (r &Repo) query_full(cxpath string) []string {
	mut target := cxpath.trim_space()
	mut descendant := false
	if target.starts_with('//') {
		descendant = true
		target = target[2..]
	} else if target.starts_with('/') {
		target = target[1..]
	}
	return r.run_query(r.list(), target, descendant)
}
