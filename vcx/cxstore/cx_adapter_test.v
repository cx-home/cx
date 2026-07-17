module cxstore

import cx

// Build a CX document with `n` records; record `edit_at` gets a changed value.
fn build_doc_src(n int, edit_at int) string {
	mut sb := []string{}
	sb << '[db'
	for i in 0 .. n {
		v := if i == edit_at { '999999' } else { i.str() }
		sb << '  [rec [id ${i}] [name "n${i}"] [val ${v}]]'
	}
	sb << ']'
	return sb.join('\n')
}

fn store_src(src string, fanout int) !(ObjectSink, []u8) {
	doc := cx.parse(src)!
	mut sink := ObjectSink{}
	root := store_document(mut sink, doc, fanout)
	return sink, root
}

// The adapter applies #80's property to a real CX document: a single deep edit
// rehashes only the root→node path, and the two versions share everything else.
fn test_cx_doc_edit_is_local_and_dedups() {
	fanout := 16
	n := 500
	edit_idx := 250

	mut s1, root1 := store_src(build_doc_src(n, -1), fanout) or {
		assert false, 'store v1: ${err}'
		return
	}
	mut s2, root2 := store_src(build_doc_src(n, edit_idx), fanout) or {
		assert false, 'store v2: ${err}'
		return
	}

	assert root1 != root2 // the edit changed the document root

	// new objects = only the path from the edited scalar up to the doc root
	mut new_objs := 0
	for k, _ in s2.objects {
		if k !in s1.objects {
			new_objs++
		}
	}
	// path: scalar leaf + (val,rec,db,doc) node objects + their seqtree paths.
	// Comfortably bounded and << total object count.
	assert new_objs > 0
	assert new_objs < 50, 'edit not local: ${new_objs} new objects'

	// dedup: the overwhelming majority of v1's objects are shared with v2
	mut shared_cnt := 0
	for k, _ in s1.objects {
		if k in s2.objects {
			shared_cnt++
		}
	}
	assert shared_cnt > s1.objects.len / 2
	assert s1.objects.len - shared_cnt < 50 // few objects dropped
}

// Determinism (P2/P5): the same document content addresses to the same root.
fn test_cx_doc_deterministic() {
	src := build_doc_src(200, -1)
	mut a, ra := store_src(src, 16) or {
		assert false, 'store a: ${err}'
		return
	}
	mut b, rb := store_src(src, 16) or {
		assert false, 'store b: ${err}'
		return
	}
	assert ra == rb
	assert a.objects.len == b.objects.len
}

// Distinct documents address to distinct roots.
fn test_cx_distinct_docs_distinct_roots() {
	_, r1 := store_src('[a [x 1]]', 16) or {
		assert false, 'store 1: ${err}'
		return
	}
	_, r2 := store_src('[a [x 2]]', 16) or {
		assert false, 'store 2: ${err}'
		return
	}
	assert r1 != r2
}

// A leaf-level shared subtree dedups across two otherwise-different documents.
fn test_cx_cross_doc_subtree_dedup() {
	// both docs contain an identical [shared [k "same"]] subtree
	mut s1, _ := store_src('[doc [shared [k "same"]] [only1 1]]', 16) or {
		assert false, 'store d1: ${err}'
		return
	}
	mut s2, _ := store_src('[doc [shared [k "same"]] [only2 2]]', 16) or {
		assert false, 'store d2: ${err}'
		return
	}
	// at least one object hash is common to both stores (the shared subtree)
	mut common := 0
	for k, _ in s1.objects {
		if k in s2.objects {
			common++
		}
	}
	assert common > 0, 'expected shared subtree objects across documents'
}
