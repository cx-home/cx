module main

import code
import os
import platform_sources
import xap as _

// platform_sources_test — cx-core-code#72 step 3 (RULED: STREAM-1): `code`
// embeds no cx-platform/* source any more; the products register their own
// from their modules' init()s (xap, imported here, imports them) and this
// front door registers the package repositories' (vcx/platform_sources).
// Run by `make test-bundle-sources`.

fn fd_root() string {
	return os.real_path(os.join_path(@DIR, '..', '..'))
}

// Every source this front door registers answers byte-for-byte as the
// pinned checkout's file.
fn test_package_sources_answer_the_pinned_files() {
	assert platform_sources.names().len > 0
	for name in platform_sources.names() {
		rel := platform_sources.source_path(name)
		assert rel != '', '`${name}` has no source path'
		want := os.read_file(os.join_path(fd_root(), rel)) or { panic(err) }
		got := code.bundled_stdlib_source(name) or { '' }
		assert got == want, '`${name}` answers a source that is not ${rel}'
	}
}

// Every cx-platform/* module a deps.cxd row declares, whose pinned checkout
// carries its source (stdlib/<m>.cx or x/<m>.cx), is registered by someone —
// a product's init() or this front door — and answers that file.
fn test_every_declared_platform_module_with_a_source_is_registered() {
	text := os.read_file(os.join_path(fd_root(), 'deps.cxd')) or { panic(err) }
	have := code.bundled_stdlib_names()
	mut missing := []string{}
	mut graded := 0
	for line in text.split_into_lines() {
		if !line.contains('[dep ') || !line.contains('repo=') {
			continue
		}
		repo := line.all_after('repo=').all_before(' ').trim("']")
		for word in line.split_any(" '\t[]=") {
			if !word.starts_with('cx-platform/') {
				continue
			}
			m := word.all_after('/')
			mut src := ''
			for cand in ['stdlib/${m}.cx', 'x/${m}.cx'] {
				p := os.join_path(fd_root(), 'deps', repo, cand)
				if os.is_file(p) {
					src = p
					break
				}
			}
			if src == '' {
				continue
			}
			graded++
			if word !in have {
				missing << word
				continue
			}
			want := os.read_file(src) or { panic(err) }
			got := code.bundled_stdlib_source(word) or { '' }
			assert got == want, '`${word}` answers a source that is not ${src}'
		}
	}
	assert missing.len == 0, 'declared in deps.cxd, carried by its pin, registered by nobody: ${missing}'
	assert graded >= 33, 'only ${graded} cx-platform modules graded — deps.cxd unread?'
}
