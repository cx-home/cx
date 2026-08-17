module main

import os
import testenv
import time

// xap_render_test.v — the SINGLE render path (xap.md §2.5/§13.2): the served
// web (text/html) and /surface (application/cx) materializations BOTH derive from
// the one component view [?fn], not hand-built strings. Boots a real [$xap:serve]
// and asserts both media reflect the view over the live fold.

fn cx_binary() string {
	return testenv.cx_bin()
}

fn curl(args string) string {
	r := os.execute('curl -s --max-time 3 ${args}')
	return r.output
}

// xap_port: disjoint PID + nanosecond-salted ports so the concurrent
// `v test vcx/tests/` gate processes don't collide. A prior cross-test collision
// sent the signer's POST to a different server (which answered 200), leaving this
// server's surface empty — the "sign not reflected" flake. xap-render owns the
// 24000-24949 band: four 200-wide slots (one per test fn; the #567/#570 pair
// shares slot 3 with a +7 offset), each salted so two processes started in the
// same nanosecond still differ.
fn xap_port(slot int) int {
	salt := (u64(os.getpid()) * u64(2654435761) + u64(time.now().unix_nano())) % 200
	return 24000 + slot * 250 + int(salt)
}

fn test_xap_single_render_path() {
	if os.execute('which curl').exit_code != 0 {
		eprintln('SKIP: curl not available')
		return
	}
	port := xap_port(0)
	dir := os.temp_dir()
	prog := os.join_path(dir, 'cx_xap_render.cx')
	os.write_file(prog, '[?lib \'cx-xap\' :as xap]\n' +
		'[\$xap:component guestbook\n' +
		'  {bind: "/guestbook"\n' +
		'   emits: ([do :sign [name :string]])\n' +
		'   view: [?fn (\$gs)\n' +
		'           [panel\n' +
		'             [list [?for [in \$g \$gs] [yield [item \$g/name]]]]\n' +
		'             [control :sign [label "Sign"] [input :name]]]]\n' +
		'   working-panel: :none}]\n' +
		'[?let [= \$rt [\$xap:run {tenant: "demo" components: (guestbook)}]]\n' +
		'[?let [= \$a [\$xap:emit \$rt [do :sign [name "Ada"]]]]\n' +
		'[?let [= \$b [\$xap:emit \$rt [do :sign [name "Lin"]]]]\n' +
		'  [\$xap:serve "http://127.0.0.1:${port}" {runtime: \$rt}]]]]\n') or { panic(err) }

	pid_s := os.execute('${cx_binary()} --allow-net ${prog} >/tmp/cx-xap-render.${port}.out 2>&1 & echo \$!')
	pid := pid_s.output.trim_space().int()
	defer {
		os.execute('kill ${pid} 2>/dev/null')
	}
	// wait for bind
	mut up := false
	for _ in 0 .. 30 {
		if curl('-o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/surface') == '200' {
			up = true
			break
		}
		time.sleep(100 * time.millisecond)
	}
	assert up, 'xap serve never bound on ${port}'

	// application/cx leg: canonical view-tree from comp.view over the live fold.
	surface := curl('http://127.0.0.1:${port}/surface').trim_space()
	expected := "[surface name=guestbook [panel [list ([item 'Ada'], [item 'Lin'])] [control :sign [label 'Sign'] [input :name]]]]"
	assert surface == expected, 'application/cx render not derived from the view; got: ${surface}'

	// text/html leg: the SAME view-tree → HTML (names from the view, not hand-built).
	page := curl('http://127.0.0.1:${port}/')
	assert page.contains('<li>Ada</li><li>Lin</li>'), 'text/html render did not derive the list from the view; got: ${page}'
	assert page.contains('<button type="submit">Sign</button>'), 'text/html control not derived from the view; got: ${page}'
}

// the 3-process topology (xap.md §16): a SEPARATE cx client process signs the
// control over the real http client (POST), and another read of the live surface
// reflects it — client → server → client over the wire, no shared in-process state.
fn test_xap_three_process_sign() {
	if os.execute('which curl').exit_code != 0 {
		eprintln('SKIP: curl not available')
		return
	}
	port := xap_port(1)
	dir := os.temp_dir()
	srv := os.join_path(dir, 'cx_xap_3p_server.cx')
	os.write_file(srv, '[?lib \'cx-xap\' :as xap]\n' +
		'[\$xap:component guestbook\n' +
		'  {bind: "/guestbook"\n' +
		'   emits: ([do :sign [name :string]])\n' +
		'   view: [?fn (\$gs)\n' +
		'           [panel [list [?for [in \$g \$gs] [yield [item \$g/name]]]]\n' +
		'                  [control :sign [label "Sign"] [input :name]]]]\n' +
		'   working-panel: :none}]\n' +
		'[?let [= \$rt [\$xap:run {tenant: "demo" components: (guestbook)}]]\n' +
		'  [\$xap:serve "http://127.0.0.1:${port}" {runtime: \$rt}]]\n') or { panic(err) }
	// process 2: a separate cx client that POSTs the sign control over HTTP.
	signer := os.join_path(dir, 'cx_xap_3p_sign.cx')
	os.write_file(signer, '[?lib \'cx-stdlib/http\' :as http]\n' +
		'[\$http:post "http://127.0.0.1:${port}/intent/sign" "name=Zoe" {content-type: "application/x-www-form-urlencoded"}]\n') or {
		panic(err)
	}

	pid_s := os.execute('${cx_binary()} --allow-net ${srv} >/tmp/cx-xap-3p.${port}.out 2>&1 & echo \$!')
	pid := pid_s.output.trim_space().int()
	defer {
		os.execute('kill ${pid} 2>/dev/null')
	}
	mut up := false
	for _ in 0 .. 30 {
		if curl('-o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/surface') == '200' {
			up = true
			break
		}
		time.sleep(100 * time.millisecond)
	}
	assert up, 'xap serve never bound on ${port}'

	// process 2 signs over the wire (a real separate cx process, real http client)
	sign_res := os.execute('${cx_binary()} --allow-net=127.0.0.1:${port} ${signer}')
	assert sign_res.exit_code == 0, 'signer process failed: ${sign_res.output}'

	// the signed name is now in the server-authoritative fold — visible to any
	// client reading the surface (process 3's read). Retry the read briefly to
	// absorb any fold-propagation lag under a loaded parallel gate.
	mut surface := ''
	for _ in 0 .. 10 {
		surface = curl('http://127.0.0.1:${port}/surface')
		if surface.contains("[item 'Zoe']") {
			break
		}
		time.sleep(100 * time.millisecond)
	}
	assert surface.contains("[item 'Zoe']"), 'cross-process sign not reflected in the live surface; got: ${surface}'
}

// §24: the /events SSE feed holds the connection open and PUSHES a surface frame
// on each state change (event-driven, non-blocking — not polling). A held SSE
// reader sees the initial surface, then a live frame when another process signs.
fn test_xap_sse_push() {
	if os.execute('which curl').exit_code != 0 {
		eprintln('SKIP: curl not available')
		return
	}
	port := xap_port(2)
	dir := os.temp_dir()
	srv := os.join_path(dir, 'cx_xap_sse_server.cx')
	os.write_file(srv, '[?lib \'cx-xap\' :as xap]\n' +
		'[\$xap:component guestbook\n' +
		'  {bind: "/guestbook"\n' +
		'   emits: ([do :sign [name :string]])\n' +
		'   view: [?fn (\$gs)\n' +
		'           [panel [list [?for [in \$g \$gs] [yield [item \$g/name]]]]\n' +
		'                  [control :sign [label "Sign"] [input :name]]]]\n' +
		'   working-panel: :none}]\n' +
		'[?let [= \$rt [\$xap:run {tenant: "demo" components: (guestbook)}]]\n' +
		'  [\$xap:serve "http://127.0.0.1:${port}" {runtime: \$rt}]]\n') or { panic(err) }

	pid_s := os.execute('${cx_binary()} --allow-net ${srv} >/tmp/cx-xap-sse.${port}.out 2>&1 & echo \$!')
	pid := pid_s.output.trim_space().int()
	defer {
		os.execute('kill ${pid} 2>/dev/null')
	}
	mut up := false
	for _ in 0 .. 30 {
		if curl('-o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/surface') == '200' {
			up = true
			break
		}
		time.sleep(100 * time.millisecond)
	}
	assert up, 'xap serve never bound on ${port}'

	// Hold an SSE reader open for ~2s (background) while a separate process signs
	// mid-stream; the feed must push the post-sign surface to the reader.
	cap_file := os.join_path(dir, 'cx_xap_sse_${port}.cap')
	os.rm(cap_file) or {}
	os.execute('curl -sN --max-time 2 http://127.0.0.1:${port}/events >${cap_file} 2>&1 & echo \$!')
	time.sleep(500 * time.millisecond) // let the reader connect + get the initial frame
	sign := os.execute('curl -s -X POST http://127.0.0.1:${port}/intent/sign -d "name=Vera"')
	assert sign.exit_code == 0, 'sign POST failed'
	time.sleep(1500 * time.millisecond) // let the push reach the held reader, then curl --max-time fires
	cap := os.read_file(cap_file) or { '' }
	assert cap.contains("[item 'Vera']"), 'SSE feed did not push the post-sign surface to the held reader; got: ${cap}'
}

// #567 + #570: the serve web leg is generalized past the D3 guestbook demo
// shape. The shell splice resolves {{surface:NAME}} for ANY declared surface —
// any mount element/id — and POST /intent/<verb> routes for every verb the
// component's `emits:` declares (via the one xap_emit cascade), while an
// undeclared verb is refused (403), never a silent missing route.
fn test_xap_shell_any_mount_and_declared_verbs() {
	if os.execute('which curl').exit_code != 0 {
		eprintln('SKIP: curl not available')
		return
	}
	port := xap_port(3)
	dir := os.temp_dir()
	shell := os.join_path(dir, 'cx_xap_review_queue_shell_${port}')
	os.mkdir_all(shell) or { panic(err) }
	os.write_file(os.join_path(shell, 'layout.html'), '<!doctype html>\n<html><body>\n' +
		'<section id="review-queue-panel">{{surface:review-queue}}</section>\n</body></html>\n') or {
		panic(err)
	}
	prog := os.join_path(dir, 'cx_xap_review_queue_server.cx')
	os.write_file(prog, '[?lib \'cx-xap\' :as xap]\n' +
		'[\$xap:component review-queue\n' +
		'  {bind: "/review-queue"\n' +
		'   emits: ([do :approve [note :string]])\n' +
		'   view: [?fn (\$rs)\n' +
		'           [panel [list [?for [in \$r \$rs] [yield [item \$r/note]]]]\n' +
		'                  [control :approve [label "Approve"] [input :note]]]]\n' +
		'   working-panel: :none}]\n' +
		'[?let [= \$rt [\$xap:run {tenant: "demo" components: (review-queue)}]]\n' +
		'  [\$xap:serve "http://127.0.0.1:${port}" {runtime: \$rt shell: "${shell}"}]]\n') or {
		panic(err)
	}

	pid_s := os.execute('${cx_binary()} --allow-net ${prog} >/tmp/cx-xap-review-queue.${port}.out 2>&1 & echo \$!')
	pid := pid_s.output.trim_space().int()
	defer {
		os.execute('kill ${pid} 2>/dev/null')
	}
	mut up := false
	for _ in 0 .. 30 {
		if curl('-o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/surface') == '200' {
			up = true
			break
		}
		time.sleep(100 * time.millisecond)
	}
	assert up, 'xap serve never bound on ${port}'

	// #567: the shell's own mount (section#review-queue-panel) is resolved — the whole
	// mount element is replaced, controls target the SHELL's id, and no
	// placeholder text leaks to the browser.
	page := curl('http://127.0.0.1:${port}/')
	assert !page.contains('{{surface:'), 'shell placeholder leaked to the browser; got: ${page}'
	assert page.contains('<section id="review-queue-panel">'), 'shell mount element/id not preserved by the splice; got: ${page}'
	assert page.contains('hx-target="#review-queue-panel"'), 'control does not target the shell mount id; got: ${page}'
	assert page.contains('hx-post="/intent/approve"'), 'control endpoint not derived from the view; got: ${page}'

	// #570: POST /intent/approve (a declared, non-demo verb) commits through the
	// cascade; the response fragment swaps against the shell mount.
	frag := curl('-X POST http://127.0.0.1:${port}/intent/approve -d "note=ok-to-send"')
	assert frag.contains('<section id="review-queue-panel">'), 'intent fragment not wrapped in the shell mount; got: ${frag}'
	assert frag.contains('<li>ok-to-send</li>'), 'declared verb did not commit through the cascade; got: ${frag}'
	surface := curl('http://127.0.0.1:${port}/surface')
	assert surface.contains("[item 'ok-to-send']"), 'committed intent not in the live fold; got: ${surface}'

	// #570: an UNDECLARED verb is refused as policy (403), not a missing route.
	code := curl('-o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:${port}/intent/nope -d "note=x"')
	assert code == '403', 'undeclared verb must 403; got: ${code}'
}

// #567: a shell mount naming an unknown surface refuses the page loudly (500
// naming the mount) — the placeholder is never served to the browser.
fn test_xap_shell_unknown_surface_refuses() {
	if os.execute('which curl').exit_code != 0 {
		eprintln('SKIP: curl not available')
		return
	}
	port := xap_port(3) + 7
	dir := os.temp_dir()
	shell := os.join_path(dir, 'cx_xap_ghost_shell_${port}')
	os.mkdir_all(shell) or { panic(err) }
	os.write_file(os.join_path(shell, 'layout.html'), '<main id="x">{{surface:ghost}}</main>\n') or {
		panic(err)
	}
	prog := os.join_path(dir, 'cx_xap_ghost_server.cx')
	os.write_file(prog, '[?lib \'cx-xap\' :as xap]\n' +
		'[\$xap:component review-queue\n' +
		'  {bind: "/review-queue"\n' +
		'   emits: ([do :approve [note :string]])\n' +
		'   view: [?fn (\$rs) [panel [list]]]\n' +
		'   working-panel: :none}]\n' +
		'[?let [= \$rt [\$xap:run {tenant: "demo" components: (review-queue)}]]\n' +
		'  [\$xap:serve "http://127.0.0.1:${port}" {runtime: \$rt shell: "${shell}"}]]\n') or {
		panic(err)
	}

	pid_s := os.execute('${cx_binary()} --allow-net ${prog} >/tmp/cx-xap-ghost.${port}.out 2>&1 & echo \$!')
	pid := pid_s.output.trim_space().int()
	defer {
		os.execute('kill ${pid} 2>/dev/null')
	}
	mut up := false
	for _ in 0 .. 30 {
		if curl('-o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/surface') == '200' {
			up = true
			break
		}
		time.sleep(100 * time.millisecond)
	}
	assert up, 'xap serve never bound on ${port}'

	code := curl('-o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/')
	assert code == '500', 'unknown shell surface must refuse the page; got: ${code}'
	body := curl('http://127.0.0.1:${port}/')
	assert body.contains('E_XAP_SHELL_SURFACE_UNKNOWN'), 'refusal must name the mount; got: ${body}'
	assert body.contains('ghost'), 'refusal must name the surface; got: ${body}'
}

// #578: parameterized detail routes. GET /<bind>/<key> renders the bound
// component's view over the id=<key> record slice (the xap.md §5 keyed-slice
// convention); the application/cx twin rides GET /surface/<bind>/<key>
// (agent parity); an unmatched key or unknown bind is a 404 (a detail route
// names a record resource); and an intent committed FROM a detail page
// (the reserved _detail form field) answers with the re-rendered detail
// panel, keeping the drill-down on its page.
fn test_xap_detail_routes() {
	if os.execute('which curl').exit_code != 0 {
		eprintln('SKIP: curl not available')
		return
	}
	port := xap_port(3) + 14
	dir := os.temp_dir()
	prog := os.join_path(dir, 'cx_xap_detail_server.cx')
	os.write_file(prog, '[?lib \'cx-xap\' :as xap]\n' +
		'[\$xap:component queue\n' +
		'  {bind: "/queue"\n' +
		'   emits: ([do :approve [id :string] [note :string]])\n' +
		'   view: [?fn (\$rs)\n' +
		'           [panel [list [?for [in \$r \$rs] [yield [item [\$concat \$r/id ":" \$r/note]]]]]\n' +
		'                  [control :approve [label "Approve"] [input :note]]]]\n' +
		'   working-panel: :none}]\n' +
		'[?let [= \$rt [\$xap:run {tenant: "demo" components: (queue)}]]\n' +
		'[?let [= \$a [\$xap:emit \$rt [do :approve [id "opp-0001"] [note "alpha"]]]]\n' +
		'[?let [= \$b [\$xap:emit \$rt [do :approve [id "opp-0002"] [note "bravo"]]]]\n' +
		'  [\$xap:serve "http://127.0.0.1:${port}" {runtime: \$rt}]]]]\n') or {
		panic(err)
	}

	pid_s := os.execute('${cx_binary()} --allow-net ${prog} >/tmp/cx-xap-detail.${port}.out 2>&1 & echo \$!')
	pid := pid_s.output.trim_space().int()
	defer {
		os.execute('kill ${pid} 2>/dev/null')
	}
	mut up := false
	for _ in 0 .. 30 {
		if curl('-o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/surface') == '200' {
			up = true
			break
		}
		time.sleep(100 * time.millisecond)
	}
	assert up, 'xap serve never bound on ${port}'

	// the detail page: only the keyed record, the detail mount id, the
	// return-context field, and controls targeting the detail mount.
	page := curl('http://127.0.0.1:${port}/queue/opp-0002')
	assert page.contains('<main id="queue-detail">'), 'detail mount missing: ${page}'
	assert page.contains('<li>opp-0002:bravo</li>'), 'keyed record not rendered: ${page}'
	assert !page.contains('opp-0001'), 'detail page leaked other records: ${page}'
	assert page.contains('name="_detail" value="opp-0002"'), 'return-context field missing: ${page}'
	assert page.contains('hx-target="#queue-detail"'), 'detail control targets wrong mount: ${page}'

	// agent parity: the application/cx twin carries the keyed view-tree.
	sfc := curl('http://127.0.0.1:${port}/surface/queue/opp-0002')
	assert sfc.contains('surface name=queue') && sfc.contains('opp-0002:bravo'), 'cx detail twin wrong: ${sfc}'
	assert !sfc.contains('opp-0001'), 'cx detail twin leaked other records: ${sfc}'

	// a missing record and an unknown bind are 404s, never empty pages.
	miss := curl('-o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/queue/nope')
	assert miss == '404', 'unmatched key must 404: ${miss}'
	nobind := curl('-o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/nope/x')
	assert nobind == '404', 'unknown bind must 404: ${nobind}'

	// an intent FROM the detail page re-renders the DETAIL panel (the new
	// record shares the key, so both keyed records render; other keys never).
	frag := curl('-X POST http://127.0.0.1:${port}/intent/approve -d "id=opp-0002&note=charlie&_detail=opp-0002"')
	assert frag.contains('<main id="queue-detail">'), 'detail intent answered with the wrong mount: ${frag}'
	assert frag.contains('<li>opp-0002:bravo</li>') && frag.contains('<li>opp-0002:charlie</li>'), 'detail fragment not re-rendered: ${frag}'
	assert !frag.contains('opp-0001'), 'detail fragment leaked other records: ${frag}'

	// the list page is untouched by the detail machinery.
	root := curl('http://127.0.0.1:${port}/')
	assert root.contains('opp-0001:alpha') && root.contains('opp-0002:charlie'), 'list page regressed: ${root}'
	assert !root.contains('_detail'), 'list controls must not carry a detail context: ${root}'
}

// #585: a registered view that FAILS at render time surfaces its own error
// (CXER4863 E_XAP_VIEW_FAILED naming the component + carrying the view's
// error), never the unknown-surface refusal and never a silently absent
// panel. Covers both failure shapes: a view that raises (undefined callee)
// and a view that returns an [err] value. The application/cx leg (/surface)
// returns the [err] value itself under the transport's failure mapping.
fn test_xap_view_failure_is_loud() {
	if os.execute('which curl').exit_code != 0 {
		eprintln('SKIP: curl not available')
		return
	}
	port := xap_port(2) + 23
	dir := os.temp_dir()
	shell := os.join_path(dir, 'cx_xap_viewfail_shell_${port}')
	os.mkdir_all(shell) or { panic(err) }
	os.write_file(os.join_path(shell, 'layout.html'), '<!doctype html>\n<html><body>\n' +
		'<section id="ok-panel">{{surface:okc}}</section>\n' +
		'<section id="boom-panel">{{surface:boomc}}</section>\n</body></html>\n') or {
		panic(err)
	}
	prog := os.join_path(dir, 'cx_xap_viewfail_server.cx')
	os.write_file(prog, '[?lib \'cx-xap\' :as xap]\n' +
		'[\$xap:component okc\n' +
		'  {bind: "/okc" emits: ([do :a [x :string]])\n' +
		'   view: [?fn (\$rs) [panel [list [item \'ok\']]]] working-panel: :none}]\n' +
		'[\$xap:component boomc\n' +
		'  {bind: "/boomc" emits: ([do :b [x :string]])\n' +
		'   view: [?fn (\$rs) [panel [list [item [\$no-such-fn 1]]]]] working-panel: :none}]\n' +
		'[?let [= \$rt [\$xap:run {tenant: "vf" components: (okc, boomc)}]]\n' +
		'  [\$xap:serve "http://127.0.0.1:${port}" {runtime: \$rt shell: "${shell}"}]]\n') or {
		panic(err)
	}

	pid_s := os.execute('${cx_binary()} --allow-net ${prog} >/tmp/cx-xap-viewfail.${port}.out 2>&1 & echo \$!')
	pid := pid_s.output.trim_space().int()
	defer {
		os.execute('kill ${pid} 2>/dev/null')
	}
	mut up := false
	for _ in 0 .. 30 {
		if curl('-o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/surface') == '200'
			|| curl('-o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/surface') == '500' {
			up = true
			break
		}
		time.sleep(100 * time.millisecond)
	}
	assert up, 'xap serve never bound on ${port}'

	// the shell page refuses with the VIEW's failure, naming the component and
	// the underlying error — never the unknown-surface refusal, never a 200
	// with the panel silently absent.
	code := curl('-o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/')
	assert code == '500', 'failing view must refuse the page; got: ${code}'
	body := curl('http://127.0.0.1:${port}/')
	assert body.contains('E_XAP_VIEW_FAILED'), 'refusal must be the view failure; got: ${body}'
	assert body.contains('boomc'), 'refusal must name the component; got: ${body}'
	assert body.contains('no-such-fn'), 'refusal must carry the view error; got: ${body}'
	assert !body.contains('E_XAP_SHELL_SURFACE_UNKNOWN'), 'view failure misreported as unknown surface: ${body}'
}

// #585 (err-value shape + agent leg): a view that RETURNS an [err] value is
// the same loud failure; /surface (application/cx) serves the [err] under a
// 500 instead of an empty surface.
fn test_xap_view_err_value_and_cx_leg() {
	if os.execute('which curl').exit_code != 0 {
		eprintln('SKIP: curl not available')
		return
	}
	port := xap_port(2) + 41
	dir := os.temp_dir()
	prog := os.join_path(dir, 'cx_xap_viewerr_server.cx')
	os.write_file(prog, '[?lib \'cx-xap\' :as xap]\n' +
		'[\$xap:component errc\n' +
		'  {bind: "/errc" emits: ([do :c [x :string]])\n' +
		'   view: [?fn (\$rs) [err code=cx-err:CXER0001 [message \'view says no\']]] working-panel: :none}]\n' +
		'[?let [= \$rt [\$xap:run {tenant: "ve" components: (errc)}]]\n' +
		'  [\$xap:serve "http://127.0.0.1:${port}" {runtime: \$rt}]]\n') or {
		panic(err)
	}

	pid_s := os.execute('${cx_binary()} --allow-net ${prog} >/tmp/cx-xap-viewerr.${port}.out 2>&1 & echo \$!')
	pid := pid_s.output.trim_space().int()
	defer {
		os.execute('kill ${pid} 2>/dev/null')
	}
	mut up := false
	for _ in 0 .. 30 {
		c := curl('-o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/surface')
		if c == '200' || c == '500' {
			up = true
			break
		}
		time.sleep(100 * time.millisecond)
	}
	assert up, 'xap serve never bound on ${port}'

	// the html page: loud 500 carrying the component + the view's own err.
	code := curl('-o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/')
	assert code == '500', 'err-value view must refuse the page; got: ${code}'
	body := curl('http://127.0.0.1:${port}/')
	assert body.contains('E_XAP_VIEW_FAILED') && body.contains('errc'), 'err-value refusal wrong: ${body}'
	assert body.contains('view says no'), 'view err not carried: ${body}'

	// the agent leg: /surface answers 500 and the body IS the err value.
	scode := curl('-o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/surface')
	assert scode == '500', '/surface over a failing view must 500; got: ${scode}'
	sbody := curl('http://127.0.0.1:${port}/surface')
	assert sbody.contains('[err') && sbody.contains('E_XAP_VIEW_FAILED'), '/surface must carry the err value: ${sbody}'
}

// #585 regression pin: served view closures resolve the FULL program env
// chain at render time — the builtin [$cast], stdlib lib aliases
// ([$str:slice] via [?lib 'cx-stdlib/strings']), and user [?def]s calling
// through aliases — on the shell-mounted page, the fallback page's first
// surface, and the application/cx leg. This is the issue's distilled repro
// verbatim (plus a shell, since the fallback page renders only the first
// registered component's surface by design). A resolution regression here
// now fails LOUDLY (E_XAP_VIEW_FAILED, #586) instead of rendering an
// empty panel — this test pins that it doesn't fail at all.
fn test_xap_view_stdlib_resolution() {
	if os.execute('which curl').exit_code != 0 {
		eprintln('SKIP: curl not available')
		return
	}
	port := xap_port(1) + 31
	dir := os.temp_dir()
	shell := os.join_path(dir, 'cx_xap_resolve_shell_${port}')
	os.mkdir_all(shell) or { panic(err) }
	os.write_file(os.join_path(shell, 'layout.html'), '<!doctype html>\n<html><body>\n' +
		'<section id="q1p">{{surface:q1}}</section>\n' +
		'<section id="q2p">{{surface:q2}}</section>\n' +
		'<section id="q3p">{{surface:q3}}</section>\n' +
		'<section id="q4p">{{surface:q4}}</section>\n</body></html>\n') or {
		panic(err)
	}
	prog := os.join_path(dir, 'cx_xap_resolve_server.cx')
	os.write_file(prog, '[?lib \'cx-xap\' :as xap]\n' +
		'[?lib \'cx-stdlib/strings\' :as str]\n' +
		'[?def year-of scope=public pure [returns string] (\$d::string) [\$str:slice \$d 0 4]]\n' +
		'[\$xap:component q1 {bind: "/q1" emits: ([do :a [x :string]])\n' +
		'  view: [?fn (\$rs) [panel [list [item \'plain-ok\']]]] working-panel: :none}]\n' +
		'[\$xap:component q2 {bind: "/q2" emits: ([do :b [x :string]])\n' +
		'  view: [?fn (\$rs) [panel [list [item [?str \'slice-{[\$str:slice "2026-05-01" 0 4]}\']]]]] working-panel: :none}]\n' +
		'[\$xap:component q3 {bind: "/q3" emits: ([do :c [x :string]])\n' +
		'  view: [?fn (\$rs) [panel [list [item [?str \'cast-{[\$cast "42" :int]}\']]]]] working-panel: :none}]\n' +
		'[\$xap:component q4 {bind: "/q4" emits: ([do :d [x :string]])\n' +
		'  view: [?fn (\$rs) [panel [list [item [?str \'def-{[\$year-of "2026-05-01"]}\']]]]] working-panel: :none}]\n' +
		'[?let [= \$rt [\$xap:run {tenant: "res"}]]\n' +
		'  [\$xap:serve "http://127.0.0.1:${port}" {runtime: \$rt shell: "${shell}"}]]\n') or {
		panic(err)
	}

	pid_s := os.execute('${cx_binary()} --allow-net ${prog} >/tmp/cx-xap-resolve.${port}.out 2>&1 & echo \$!')
	pid := pid_s.output.trim_space().int()
	defer {
		os.execute('kill ${pid} 2>/dev/null')
	}
	mut up := false
	for _ in 0 .. 30 {
		if curl('-o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/surface') == '200' {
			up = true
			break
		}
		time.sleep(100 * time.millisecond)
	}
	assert up, 'xap serve never bound on ${port}'

	// shell page: every view rendered its computed content — nothing absent,
	// no view failure, no SURFACE_UNKNOWN.
	code := curl('-o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/')
	assert code == '200', 'resolution repro page must render; got: ${code}'
	page := curl('http://127.0.0.1:${port}/')
	assert page.contains('plain-ok'), 'q1 plain view absent: ${page}'
	assert page.contains('slice-2026'), 'q2 [\$str:slice] did not resolve in the view: ${page}'
	assert page.contains('cast-42'), 'q3 [\$cast] did not resolve in the view: ${page}'
	assert page.contains('def-2026'), 'q4 user [?def]→alias chain did not resolve in the view: ${page}'
	assert !page.contains('E_XAP_VIEW_FAILED') && !page.contains('E_XAP_SHELL_SURFACE_UNKNOWN'), 'view failure leaked: ${page}'

	// the application/cx leg renders the first surface from the same views.
	sfc := curl('http://127.0.0.1:${port}/surface')
	assert sfc.contains('plain-ok'), '/surface leg regressed: ${sfc}'
}

// #609: GET /events?delta=1 — the initial frame is the full surface (the
// resync baseline); subsequent frames are [surface-delta …] carrying ONLY
// the panels whose binds changed past the subscriber's watermark. A plain
// /events reader keeps receiving full frames (pinned by test_xap_sse_push).
fn test_xap_sse_delta_frames() {
	if os.execute('which curl').exit_code != 0 {
		eprintln('SKIP: curl not available')
		return
	}
	port := xap_port(2) + 61
	dir := os.temp_dir()
	srv := os.join_path(dir, 'cx_xap_delta_server.cx')
	os.write_file(srv, '[?lib \'cx-xap\' :as xap]\n' +
		'[\$xap:component alpha\n' +
		'  {bind: "/alpha" emits: ([do :hit [name :string]])\n' +
		'   view: [?fn (\$rs) [panel [list [?for [in \$r \$rs] [yield [item \$r/name]]]]]]\n' +
		'   working-panel: :none}]\n' +
		'[\$xap:component beta\n' +
		'  {bind: "/beta" emits: ([do :poke [name :string]])\n' +
		'   view: [?fn (\$rs) [panel [list [item \'beta-static\']]]] working-panel: :none}]\n' +
		'[?let [= \$rt [\$xap:run {tenant: "delta"}]]\n' +
		'  [\$xap:serve "http://127.0.0.1:${port}" {runtime: \$rt}]]\n') or { panic(err) }

	pid_s := os.execute('${cx_binary()} --allow-net ${srv} >/tmp/cx-xap-delta.${port}.out 2>&1 & echo \$!')
	pid := pid_s.output.trim_space().int()
	defer {
		os.execute('kill ${pid} 2>/dev/null')
	}
	mut up := false
	for _ in 0 .. 30 {
		if curl('-o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/surface') == '200' {
			up = true
			break
		}
		time.sleep(100 * time.millisecond)
	}
	assert up, 'xap serve never bound on ${port}'

	// hold a DELTA reader open; commit to alpha's bind only.
	cap_file := os.join_path(dir, 'cx_xap_delta_${port}.cap')
	os.rm(cap_file) or {}
	os.execute('curl -sN --max-time 4 "http://127.0.0.1:${port}/events?delta=1" >${cap_file} 2>&1 & echo \$!')
	time.sleep(500 * time.millisecond)
	sign := os.execute('curl -s -X POST http://127.0.0.1:${port}/intent/hit -d "name=Vera"')
	assert sign.exit_code == 0, 'hit POST failed'
	time.sleep(3800 * time.millisecond)
	cap := os.read_file(cap_file) or { '' }

	// initial frame: the full surface (resync baseline).
	assert cap.contains('[surface'), 'delta subscriber must get the full initial frame: ${cap}'
	// the commit's frame: a surface-delta carrying alpha's panel only.
	assert cap.contains('surface-delta'), 'commit must push a delta frame: ${cap}'
	assert cap.contains('panel-frame name=alpha'), 'changed panel missing from the delta: ${cap}'
	assert cap.contains("'Vera'") || cap.contains('Vera'), 'delta panel must carry the committed record: ${cap}'
	// beta's bind never changed after the baseline — no beta panel-frame.
	assert !cap.contains('panel-frame name=beta'), 'unchanged panel leaked into the delta: ${cap}'
}
