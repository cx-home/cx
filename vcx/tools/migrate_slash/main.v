module main
import cx

// One-off cutover tool: rewrite std-lib conformance fixture `in-code` payloads
// from the RETIRED slash module-call surface `[prefix/local …]` to the canonical
// QName head-dispatch `[$prefix:local …]` (code.md §12.1.1; `/` is data-path
// navigation, never a module ref).
//
// Parser-driven, NOT regex: each `in-code` payload is tokenized by the real CX
// code lexer (`cx.tokenize`), so slashes inside string/comment tokens (path,
// regex, email data) are never mistaken for a call head. Only a head-position
// triple `lbrack · ident · slash · ident` (with no `$` — that would be a
// path-nav ref) is rewritten, by splicing the exact source span.
//
// Usage:  v run tools/migrate_slash/   [--apply]   <file.cxd> [more.cxd …]
//   (no --apply = dry run: report only, write nothing)

import os
import code

struct Splice {
	start int
	end   int
	text  string
}

// migrate_payload rewrites slash module-call heads inside one in-code payload.
// Returns (new_payload, rewrites, warnings).
fn migrate_payload(payload string) (string, int, []string) {
	mut warns := []string{}
	toks := cx.tokenize(payload) or {
		return payload, 0, ['LEX-FAIL: ${err.msg()}']
	}
	mut splices := []Splice{}
	mut i := 0
	for i < toks.len {
		if toks[i].kind == .lbrack && i + 3 < toks.len
			&& toks[i + 1].kind == .ident
			&& toks[i + 2].kind == .slash
			&& toks[i + 3].kind == .ident {
			// Multi-segment `[a/b/c …]` is not a module member call — flag, skip.
			if i + 4 < toks.len && toks[i + 4].kind == .slash {
				warns << 'multi-segment slash head `${toks[i + 1].text}/${toks[i + 3].text}/…` at offset ${toks[i + 1].pos.offset} — SKIPPED (manual review)'
				i += 1
				continue
			}
			prefix := toks[i + 1].text
			local := toks[i + 3].text
			start := toks[i + 1].pos.offset
			end := toks[i + 3].pos.offset + toks[i + 3].text.len
			splices << Splice{
				start: start
				end:   end
				text:  '\$${prefix}:${local}'
			}
			i += 4
			continue
		}
		i += 1
	}
	if splices.len == 0 {
		return payload, 0, warns
	}
	mut out := payload
	for j := splices.len - 1; j >= 0; j-- {
		s := splices[j]
		out = out[..s.start] + s.text + out[s.end..]
	}
	return out, splices.len, warns
}

// process_file locates every `[in-code [# … #]]` payload and migrates it.
// Returns (new_file_text, rewrites, warnings).
fn process_file(src string, fname string) (string, int, []string) {
	mut warns := []string{}
	mut rewrites := 0
	// Collect (payload_start, payload_end, new_payload) right-to-left.
	mut edits := [][3]int{} // start, end, edit-index into new_payloads
	mut new_payloads := []string{}
	mut search := 0
	for {
		marker := src.index_after('[in-code', search) or { break }
		// Opening RawText fence `[#` after the element head.
		open := src.index_after('[#', marker) or {
			warns << 'in-code at ${marker} has no `[#` fence — skipped'
			search = marker + 8
			continue
		}
		payload_start := open + 2
		close := src.index_after('#]', payload_start) or {
			warns << 'in-code at ${marker} has no `#]` close — skipped'
			search = marker + 8
			continue
		}
		// Detect split-payload (literal `#]` carried as adjacent RawText sibling):
		// after the close, whitespace then another `[#` rather than the `]` that
		// ends the in-code element.
		mut k := close + 2
		for k < src.len && (src[k] == ` ` || src[k] == `\t` || src[k] == `\n` || src[k] == `\r`) {
			k++
		}
		if k + 1 < src.len && src[k] == `[` && src[k + 1] == `#` {
			warns << 'in-code at ${marker} is a SPLIT payload (adjacent `[#…#]`) — skipped (manual review)'
			search = close + 2
			continue
		}
		payload := src[payload_start..close]
		new_payload, n, w := migrate_payload(payload)
		for ww in w {
			warns << '${fname}: ${ww}'
		}
		if n > 0 {
			edits << [payload_start, close, new_payloads.len]!
			new_payloads << new_payload
			rewrites += n
		}
		search = close + 2
	}
	if edits.len == 0 {
		return src, 0, warns
	}
	mut out := src
	for j := edits.len - 1; j >= 0; j-- {
		e := edits[j]
		out = out[..e[0]] + new_payloads[e[2]] + out[e[1]..]
	}
	return out, rewrites, warns
}

fn main() {
	mut args := os.args[1..].clone()
	mut apply := false
	mut files := []string{}
	for a in args {
		if a == '--apply' {
			apply = true
		} else {
			files << a
		}
	}
	if files.len == 0 {
		eprintln('usage: v run tools/migrate_slash/ [--apply] <file.cxd> …')
		exit(2)
	}
	mut total := 0
	mut changed := 0
	mut all_warns := []string{}
	for f in files {
		src := os.read_file(f) or {
			eprintln('cannot read ${f}: ${err}')
			continue
		}
		new_src, n, warns := process_file(src, os.base(f))
		all_warns << warns
		if n > 0 {
			changed++
			total += n
			if apply {
				os.write_file(f, new_src) or { eprintln('write ${f}: ${err}') }
			}
			println('${os.base(f)}: ${n} rewrite(s)${if apply { ' [written]' } else { ' [dry-run]' }}')
		}
	}
	println('---')
	println('files changed: ${changed}/${files.len}   total rewrites: ${total}   ${if apply { 'APPLIED' } else { 'DRY-RUN' }}')
	if all_warns.len > 0 {
		println('WARNINGS (${all_warns.len}):')
		for w in all_warns {
			println('  ${w}')
		}
	}
}
