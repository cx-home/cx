// `cx flow serve` — the STANDALONE RUNNER of cx-stdlib/flow (flow.md §4.23;
// RULED: 789-WF-28, WF-28b, WF-29, WF-30 … WF-37).
//
// `cx flow serve RUNNER.cx` is a long-running process holding ONE journal and
// running the SAME `advance` law as `cx flow run` and the XAP host. It exists
// so that nothing which needs liveness needs a XAP deployment: a make
// replacement and a CI/CD pipeline get timers, bindings and couriers without
// adopting the XAP model.
//
// NO SECOND ANYTHING. This subcommand adds no `flow` module verb, no second
// resolver and no second document reader: `flow_cli_env_scan`,
// `flow_cli_resolver` and `flow_cli_eval` are the ones `cx flow run` uses, so
// an act resolves here exactly as it resolves there — by construction, not by
// a second implementation. What is new is only the `[runner]` document, the
// four served binding kinds, and the loop that drives them.
//
// THE ONE-LAW GATE (RULED: WF-28b). The same flow and the same acts under
// `cx flow run` and under `cx flow serve` MUST produce byte-identical
// transitions. Two loops that can drift are two products. WF-37 is what makes
// the gate REACHABLE: both faces now derive the nonce as the CONTENT ADDRESS
// over the event, so a `file` delivery whose bytes are the `[args …]` record
// and a `cx flow run` of the same record land on the SAME run id.
//
// ── the four kinds served today (RULED: WF-36) ──────────────────────────────
//
// `schedule` · `intent` · `webhook` · `file`. A `fold` binding refuses
// CXER4965 NAMING its landing: `live:observe` needs a quoted planar
// comprehension and a `$bind` map of open source handles, there is no
// open-by-name, and the `[runner]` document carries no store handle. A refusal
// that names its landing is a complete surface; a `fold` row that parsed and
// silently never fired would be the partial one.
//
// ── the nonce is the event's content address (RULED: WF-31) ─────────────────
//
// One rule, four instantiations, and it is what makes this runner STATELESS —
// no delivery log, no watermark file, no dedup table:
//
//   schedule  the occurrence instant   a re-fire of one occurrence is not a
//                                      new event; a new period is
//   webhook   the delivery's address   a redelivered payload starts no second run
//   intent    the intent's stream+seq  a replay starts no second run
//   file      the file's address       the same bytes reappearing start nothing
//
// Every tick RE-ISSUES every binding's `start` with the nonce its own event
// derives. A terminal run answers `[deduped …]`, a live one RESUMES — so one
// expression is at once the event source, the dedup and the courier for the
// runs this process started, with nothing persisted between ticks. That is
// §2.2's own claim ("the record IS the durable step-dedup") used rather than
// re-implemented.
//
// ── the ingress ─────────────────────────────────────────────────────────────
//
// Two inputs and no third (§4.23), told apart BY PATH:
//
//   `/.cx/flow/act`   a CORRELATED ACT — the `[act run= step= …]` shape
//                     `advance` already takes, which is what lets a
//                     `:principal` or `:peer` step complete against a runner
//                     with no UX face of its own. The path is RESERVED: an
//                     `[on …]` row claiming it refuses CXER4965 (§8).
//   a declared `path=` a webhook DELIVERY for that row's binding.
//   anything else      404.
//
// DIVERGENCE FROM THE PACKET'S OWN DESIGN, and why. The design said
// `http:listen` / `accept-iter` / `respond`. Measured on the shipped binary,
// that low-level path CANNOT carry this runner: `net_accept_real` blocks on a
// listener whose accept timeout is V's `infinite_timeout`, there is no accept
// deadline anywhere on the `net`/`http` surface, and `[?async]` does not run
// the calling fiber concurrently (probed: a future holding a blocking serve
// never yielded to the main fiber). A runner whose accept blocks has no
// schedule, no file poll and no courier until someone happens to connect —
// which is not liveness. `[$http:serve URL HANDLER {}]` (block=false) binds the
// same net listener and runs the picoev accept loop on its OWN thread,
// returning the `[http-server]` immediately; the tick loop then runs on the
// main fiber. Measured: a request handled and two tick writes observed from one
// process. Same module, same capability, same `tcp://` bind — the difference is
// which of `http`'s two server forms is used, and only the blocking one is
// unusable here.
//
// ── liveness is the COURIER's, not `sched`'s (RULED: WF-32) ─────────────────
//
// `rearm` is called at boot, per §4.15, and its `[restore-report …]` is the
// runner's honest statement about what timers it recovered.
//
// CORRECTED 2026-09-08, and the correction matters because the original
// argument here is now FALSE. It read: the evaluator's `sched` wheel runs a
// `:manual` virtual clock, so a re-armed timer never fires on wall time, so
// the courier must supply the liveness. #1358 landed `:wall` as the process
// default and pumps the wheel at the blocking cancellation points — including
// the `[?sleep]` this runner's own tick loop waits on — so an armed timer in
// THIS process now does fire on wall time. The premise is gone.
//
// The COURIER stays, on the reason WF-32 actually gives (flow.md §4.23): a
// timer is IN-PROCESS state and the `[sched-intent …]` fold is the DURABLE
// record. A run whose deadline passed while no runner was up, or that was
// started by some other process, has no live timer here to fire — only a
// journaled intent. So each tick advances the runs named by the pending
// `[sched-intent …]` fold, plus the runs started in this process this boot
// (which the tick's own re-issued `start` calls already carry). That is
// exactly the set a tick can help: a run parked on an OFFERED step advances on
// a correlated act arriving at the ingress, never on a tick. It does NOT
// enumerate through `fleet` — that would put the `live` pack between a make
// replacement and its build.
//
// ── what the runner holds ───────────────────────────────────────────────────
//
// The `flow` capability to append transitions and NOTHING else. Every step is
// admitted at the PEP against the RUN's recorded basis, never the runner's, so
// a step whose act needs a capability this process was not granted is denied at
// the act's own effect point (CXER0271) naming the run's basis. `authority=` is
// the `as=` binder's identity; the runner contributes none (§4.5).

module main

import os
import cx
import code

// the RESERVED ingress path: correlated acts, never a binding's delivery. An
// `[on kind=webhook path=…]` row claiming it refuses CXER4965 (§8, WF-35).
const flow_serve_act_path = '/.cx/flow/act'

// §4.24's CLOSED set. `fold` is admitted vocabulary and REFUSED here naming its
// landing (RULED: WF-36) — the marking discipline, not a silent omission.
const flow_serve_kinds = ['schedule', 'intent', 'fold', 'webhook', 'file']

// The 1ms FLOOR, for both the courier's cadence and a schedule's. A tick loop
// cannot honor anything finer, and an occurrence instant is bucketed in
// MILLISECONDS because `$mod` reduces through f64 and an epoch instant in
// nanoseconds is past 2^53 (see the driver's own note on fs--tick-schedule).
const flow_serve_min_tick_ns = i64(1_000_000)

// FlowBinding is one `[on kind=<kind> …]` row, resolved: its per-kind
// attributes normalized, and its `start=` document FETCHED from `[docs …]` and
// verified against the address (RULED: WF-30).
struct FlowBinding {
mut:
	kind     string
	start    string // the flow's Tier-1 address — `start=`
	binder   string // `as=` — the actor of the start AND its authority basis
	path     string // webhook
	glob     string // file — the source pattern, kept for the refusal text
	dir      string // file — the literal directory the glob names
	pat      string // file — the basename pattern as a regex
	intent   string // intent — the committed intent's journal stream
	every_ns i64    // schedule
	at_ns    i64    // schedule — the phase offset inside the period
	doc_src  string // the resolved document's verbatim bytes
}

// FlowRunner is the `[runner]` document, validated. Every field is required:
// a runner that guessed a journal, a document source or a bind address would be
// a runner nobody could review.
struct FlowRunner {
mut:
	name       string
	journal    string
	docs       string
	env        string
	bind       string
	courier_ns i64
	bindings   []FlowBinding
}

// ── refusals ────────────────────────────────────────────────────────────────

// flow_serve_refuse is the `[runner]` document's own refusal channel: CXER4965,
// the CALLER's-fault code (§8, RULED: WF-33), as the `[err …]` VALUE on stderr
// with exit 1 — the same split every other `cx flow` verb makes.
fn flow_serve_refuse(msg string) {
	// the message rides a SINGLE-quoted CX string, so the escapes are `\` and
	// `'` — never `"`, which `flow_cli_quote` (the double-quoted quoter) would
	// have backslashed into the reader's face.
	q := msg.replace('\\', '\\\\').replace("'", "\\'")
	eprintln("[err code='cx-err:CXER4965' message='E_COORD_ARG_INVALID: ${q}']")
	exit(1)
}

// ── durations ───────────────────────────────────────────────────────────────

// flow_serve_duration_ns reads a `::duration` literal the way the surface
// spells one (`30s`, `1d`, `500ms`). None on anything else, so the caller
// refuses NAMING the attribute rather than defaulting a cadence.
fn flow_serve_duration_ns(s string) ?i64 {
	if s == '' {
		return none
	}
	// longest suffix first, so `ms` is never read as `s`.
	suffixes := ['ns', 'us', 'ms', 'd', 'h', 'm', 's']
	scales := [i64(1), i64(1_000), i64(1_000_000), i64(86_400_000_000_000),
		i64(3_600_000_000_000), i64(60_000_000_000), i64(1_000_000_000)]
	for i, suffix in suffixes {
		if !s.ends_with(suffix) {
			continue
		}
		head := s[..s.len - suffix.len]
		if head == '' {
			return none
		}
		for c in head {
			if c < `0` || c > `9` {
				return none
			}
		}
		return head.i64() * scales[i]
	}
	return none
}

// flow_serve_clock_ns reads an `at="HH:MM"` phase — the offset INSIDE the
// period at which a cadence lands (`every=1d at="02:00"` is 02:00 UTC daily).
fn flow_serve_clock_ns(s string) ?i64 {
	parts := s.split(':')
	if parts.len != 2 {
		return none
	}
	for p in parts {
		if p.len != 2 {
			return none
		}
		for c in p {
			if c < `0` || c > `9` {
				return none
			}
		}
	}
	h := parts[0].i64()
	m := parts[1].i64()
	if h > 23 || m > 59 {
		return none
	}
	return (h * 3600 + m * 60) * 1_000_000_000
}

// ── the `[runner]` document ─────────────────────────────────────────────────

// flow_serve_child answers the one child element with this name, or none. More
// than one is the caller's fault: a runner with two journals is not a runner.
fn flow_serve_child(e cx.Element, name string) ?cx.Element {
	mut hit := ?cx.Element(none)
	for n in e.items {
		if !n.is_element() {
			continue
		}
		k := n.element()
		if k.name != name {
			continue
		}
		if hit != none {
			flow_serve_refuse('the [runner] document carries more than one [${name} …] row; it names exactly one')
		}
		hit = k
	}
	return hit
}

// flow_serve_text answers an element's text content (`[env 'acts.cx']`).
fn flow_serve_text(e cx.Element) string {
	mut b := ''
	for n in e.items {
		if n.is_text_node() {
			b += n.text_node().value
		} else if n.is_string() {
			b += n.string_value()
		}
	}
	return b.trim_space()
}

// flow_serve_url_dir reads a `file://` URL as the local directory it names.
// Any other scheme is refused NAMING itself: `[docs …]` over a store or a
// remote is the connector-kit slice, not something to half-do here.
fn flow_serve_url_dir(url string, what string) string {
	if !url.starts_with('file://') {
		flow_serve_refuse('${what} is `${url}` — `cx flow serve` reads a `file://` document source today; a store:// or remote source is the connector kit\'s landing (#728), and a runner that pretended otherwise would fetch nothing')
	}
	mut p := url['file://'.len..]
	if p == '' {
		flow_serve_refuse('${what} names no path')
	}
	return p
}

// flow_serve_glob splits a `glob=` into its literal directory and a regex over
// the file name. ONE directory, no descent: a `*` in a directory component is
// REFUSED naming its landing rather than silently matching one level.
fn flow_serve_glob(pattern string) (string, string) {
	slash := pattern.last_index_u8(`/`)
	dir := if slash < 0 { '.' } else { pattern[..slash] }
	base := if slash < 0 { pattern } else { pattern[slash + 1..] }
	if dir.contains('*') || dir.contains('?') {
		flow_serve_refuse('glob=`${pattern}` puts a wildcard in a DIRECTORY component; `cx flow serve` watches the one directory a glob names and matches the file name against it — a recursive watch is a named landing, not a silent single-level match')
	}
	if base == '' {
		flow_serve_refuse('glob=`${pattern}` names a directory, not a file pattern')
	}
	mut re := '^'
	for c in base {
		match c {
			`*` { re += '[^/]*' }
			`?` { re += '[^/]' }
			`.`, `+`, `(`, `)`, `[`, `]`, `{`, `}`, `^`, `$`, `|`, `\\` { re += '\\' + c.ascii_str() }
			else { re += c.ascii_str() }
		}
	}
	return dir, re + '$'
}

// flow_serve_row reads one `[on kind=<kind> …]` row. `kind=` is checked against
// the CLOSED five FIRST and that kind's required attributes second (RULED:
// WF-35) — so a misspelled `glob=` answers "kind `file` requires glob=" rather
// than shrugging at a row it cannot classify.
fn flow_serve_row(e cx.Element) FlowBinding {
	kind := e.attr('kind')
	if kind == '' {
		flow_serve_refuse('an [on …] row carries no kind=; a binding row is all-attribute and its kind is one of ${flow_serve_kinds.join(', ')} (flow.md §4.24)')
	}
	if kind !in flow_serve_kinds {
		flow_serve_refuse('an [on …] row names kind=`${kind}`; the kinds are CLOSED: ${flow_serve_kinds.join(', ')} (flow.md §4.24). A queue delivery is `intent` over a fabric subscription, never a sixth kind')
	}
	if kind == 'fold' {
		// RULED: WF-36 — four kinds served, and the fifth refuses NAMING its
		// landing rather than parsing and never firing.
		flow_serve_refuse('an [on kind=fold …] row: `cx flow serve` serves schedule, intent, webhook and file. A fold binding is a NAMED LANDING (flow.md §4.24, RULED: 789-WF-36) — `live:observe` needs a quoted planar comprehension and a bind map of open source handles, `live:materialize` needs the same to re-attach, there is no open-by-name, and the [runner] document carries no store handle. Putting the comprehension in this document would be computation inside choreography, which §4.25 refuses for binding rows')
	}
	start := e.attr('start')
	if start == '' {
		flow_serve_refuse('an [on kind=${kind} …] row carries no start=; start= is the flow\'s Tier-1 address (flow.md §4.24)')
	}
	binder := e.attr('as')
	if binder == '' {
		flow_serve_refuse('an [on kind=${kind} …] row carries no as=; as= is the BINDER, whose own act the start is admitted as (flow.md §4.9, X2)')
	}
	mut b := FlowBinding{
		kind:   kind
		start:  start
		binder: binder
	}
	match kind {
		'schedule' {
			every := e.attr('every')
			if every == '' {
				flow_serve_refuse('kind `schedule` requires every= (flow.md §4.24)')
			}
			b.every_ns = flow_serve_duration_ns(every) or {
				flow_serve_refuse('kind `schedule` carries every=`${every}`, which is not a duration (30s, 5m, 1d)')
				i64(0)
			}
			if b.every_ns < flow_serve_min_tick_ns {
				flow_serve_refuse('kind `schedule` carries every=`${every}`; the floor is 1ms, because an occurrence instant is bucketed in MILLISECONDS — an epoch instant in nanoseconds is past f64\'s exact range and two ticks inside one period would compute two different occurrences and start two runs')
			}
			at := e.attr('at')
			if at != '' {
				b.at_ns = flow_serve_clock_ns(at) or {
					flow_serve_refuse('kind `schedule` carries at=`${at}`, which is not an HH:MM time of day')
					i64(0)
				}
				if b.at_ns >= b.every_ns {
					flow_serve_refuse('kind `schedule` carries at=`${at}` with every=`${every}` — the phase must fall INSIDE the period, and this one does not')
				}
			}
		}
		'intent' {
			b.intent = e.attr('intent')
			if b.intent == '' {
				flow_serve_refuse('kind `intent` requires intent= (flow.md §4.24) — the committed intent\'s journal stream')
			}
		}
		'webhook' {
			b.path = e.attr('path')
			if b.path == '' {
				flow_serve_refuse('kind `webhook` requires path= (flow.md §4.24)')
			}
			if !b.path.starts_with('/') {
				flow_serve_refuse('kind `webhook` carries path=`${b.path}`; an ingress path begins with `/`')
			}
			if b.path == flow_serve_act_path {
				// §8's own row: an [on …] row claiming the reserved path.
				flow_serve_refuse('an [on kind=webhook …] row claims `${flow_serve_act_path}`, the RESERVED ingress path: that path carries CORRELATED ACTS ([act run= step= …]), which is what lets a :principal or :peer step complete against a runner with no UX face of its own (flow.md §4.23, §8)')
			}
		}
		'file' {
			b.glob = e.attr('glob')
			if b.glob == '' {
				flow_serve_refuse('kind `file` requires glob= (flow.md §4.24)')
			}
			b.dir, b.pat = flow_serve_glob(b.glob)
		}
		else {}
	}
	return b
}

// flow_serve_parse reads and VALIDATES a `[runner]` document. Every refusal is
// CXER4965 (RULED: WF-33) — the document is the invocation's input, which is
// the class that code already names.
fn flow_serve_parse(src string, path string) FlowRunner {
	doc := cx.parse(src) or {
		flow_serve_refuse('${path} does not parse as CX: ${err.msg()}')
		return FlowRunner{}
	}
	mut root := ?cx.Element(none)
	for n in doc.elements {
		if !n.is_element() {
			continue
		}
		e := n.element()
		if e.name != 'runner' {
			flow_serve_refuse('${path} carries a top-level [${e.name} …]; a runner document is ONE [runner …] element (flow.md §4.23)')
		}
		if root != none {
			flow_serve_refuse('${path} carries more than one [runner …]; a runner document is one')
		}
		root = e
	}
	r := root or {
		flow_serve_refuse('${path} carries no [runner …] element (flow.md §4.23)')
		return FlowRunner{}
	}
	mut out := FlowRunner{}
	out.name = r.attr('name')
	if out.name == '' {
		flow_serve_refuse('the [runner …] element carries no name=')
	}
	// the CLOSED child vocabulary: an unknown row is a typo the operator must
	// see, never a row silently ignored.
	//
	// `store` is ADMITTED VOCABULARY and REFUSED here naming its landing, the
	// same shape `[on kind=fold …]` gets below. flow.md §4.23 (RULED: #728
	// CK-3) makes `[store url=…]` optional and REQUIRED when `[env …]` loads a
	// feature package, because a feature's projected command defs call its
	// `apply` with a store. That projection does not exist on the program face:
	// the `pkg:` arm of the module loader (vcx/code/module_loader.v) hands the
	// package's `<name>.cx` contract module to the ordinary `load_module`, so a
	// program gets `stripe/apply`, never a projected `stripe/create-charge`;
	// the verb's `idempotent=` / `compensates=` are dropped at compose time
	// (they have no field on `XapGVerb`); and `flow_cli_module_acts` builds a
	// resolver row only from a real `[?def]` carrying `[effects]`. So no runner
	// can carry a feature package today, and there is nothing for a store
	// handle to be passed TO. Admitting the row and threading an unread handle
	// would be a seam with no live consumer. The row lands with the projection
	// it exists to feed (#1334).
	known := ['journal', 'docs', 'env', 'ingress', 'on', 'courier']
	for n in r.items {
		if !n.is_element() {
			continue
		}
		k := n.element()
		if k.name == 'store' {
			flow_serve_refuse('the [runner …] document carries a [store …] row; it is admitted vocabulary (flow.md §4.23, RULED: #728 CK-3) and lands with the program-face feature projection it exists to feed (#1334) — a feature package projects no command def on the program face today, so there is nothing for a store handle to be passed to. A runner whose [env …] is hand-authored defs needs none')
		}
		if k.name !in known {
			flow_serve_refuse('the [runner …] document carries a [${k.name} …] row; its rows are ${known.join(', ')} (flow.md §4.23)')
		}
	}
	jr := flow_serve_child(r, 'journal') or {
		flow_serve_refuse('the [runner …] document names no [journal url=…]; a runner holds ONE journal (flow.md §4.23)')
		return FlowRunner{}
	}
	out.journal = jr.attr('url')
	if out.journal == '' {
		flow_serve_refuse('[journal …] carries no url=')
	}
	dr := flow_serve_child(r, 'docs') or {
		flow_serve_refuse('the [runner …] document names no [docs url=…]; start= is a Tier-1 address and [docs …] is where its bytes are fetched and verified against it (RULED: 789-WF-30)')
		return FlowRunner{}
	}
	out.docs = dr.attr('url')
	if out.docs == '' {
		flow_serve_refuse('[docs …] carries no url=')
	}
	er := flow_serve_child(r, 'env') or {
		flow_serve_refuse('the [runner …] document names no [env …]; a flow document names its acts and the runner must be TOLD where they live (flow.md §4.1, §4.23)')
		return FlowRunner{}
	}
	out.env = flow_serve_text(er)
	if out.env == '' {
		flow_serve_refuse('[env …] names no program')
	}
	ir := flow_serve_child(r, 'ingress') or {
		flow_serve_refuse('the [runner …] document names no [ingress bind=…]; the ingress is where a correlated act reaches a parked step, and a runner never listens more widely than it was told to (flow.md §4.23)')
		return FlowRunner{}
	}
	out.bind = ir.attr('bind')
	if out.bind == '' {
		flow_serve_refuse('[ingress …] carries no bind=')
	}
	if !out.bind.contains(':') {
		flow_serve_refuse('[ingress bind="${out.bind}"] is a bare port; a bind is HOST:PORT, so a runner never listens more widely than it was told to (flow.md §4.23)')
	}
	cr := flow_serve_child(r, 'courier') or {
		flow_serve_refuse('the [runner …] document names no [courier every=…]; how often the courier ticks is the runner\'s own statement about its liveness (flow.md §4.23)')
		return FlowRunner{}
	}
	cev := cr.attr('every')
	out.courier_ns = flow_serve_duration_ns(cev) or {
		flow_serve_refuse('[courier every="${cev}"] is not a duration (30s, 5m, 1d)')
		i64(0)
	}
	if out.courier_ns < flow_serve_min_tick_ns {
		flow_serve_refuse('[courier every="${cev}"] is below the 1ms floor a tick loop can honor')
	}
	for n in r.items {
		if !n.is_element() {
			continue
		}
		k := n.element()
		if k.name == 'on' {
			out.bindings << flow_serve_row(k)
		}
	}
	if out.bindings.len == 0 {
		flow_serve_refuse('the [runner …] document carries no [on …] row; a runner with no binding starts nothing')
	}
	return out
}

// ── `[docs …]` — fetch by address, verify the bytes (RULED: WF-30) ──────────

// flow_serve_fetch_doc answers the verbatim bytes of the document `start=`
// addresses. TWO lookup paths, and the fetched bytes are hashed on BOTH — an
// address-named file (`<docs>/<address>.cx`) and, failing that, a scan of the
// directory for the file whose own content address matches. A file named for an
// address whose bytes no longer hash to it is the mismatch refusal; a scan that
// finds nothing names the address and what the directory does hold.
fn flow_serve_fetch_doc(dir string, addr string) string {
	named := os.join_path(dir, addr + '.cx')
	if os.exists(named) {
		src := os.read_file(named) or {
			flow_serve_refuse('[docs …] holds `${named}` for start=`${addr}` but it could not be read: ${err}')
			return ''
		}
		got := cx.cx_text_hash(src) or {
			flow_serve_refuse('[docs …] holds `${named}` for start=`${addr}` but it does not parse as CX: ${err.msg()}')
			return ''
		}
		if got != addr {
			flow_serve_refuse('[docs …] holds `${named}` for start=`${addr}`, but those bytes hash to `${got}` — a Tier-1 address is VERIFIED against the bytes it fetches, never trusted because a file was named for it (RULED: 789-WF-30)')
		}
		return src
	}
	if !os.is_dir(dir) {
		flow_serve_refuse('[docs url=…] names `${dir}`, which is not a directory')
	}
	mut seen := []string{}
	entries := os.ls(dir) or {
		flow_serve_refuse('[docs url=…] names `${dir}`, which could not be read: ${err}')
		return ''
	}
	for name in entries {
		if !name.ends_with('.cx') {
			continue
		}
		p := os.join_path(dir, name)
		if !os.is_file(p) {
			continue
		}
		src := os.read_file(p) or { continue }
		got := cx.cx_text_hash(src) or { continue }
		if got == addr {
			return src
		}
		seen << '${name} → ${got}'
	}
	flow_serve_refuse('no document in [docs url=…] (`${dir}`) has the address start=`${addr}`; the directory holds ${if seen.len == 0 {
		'no .cx document'
	} else {
		seen.join('; ')
	}}. A start= is a Tier-1 address and this is where its bytes are fetched and verified against it (RULED: 789-WF-30)')
	return ''
}

// ── the driver program ──────────────────────────────────────────────────────

// flow_serve_bindings_element renders the resolved binding table as ONE CX
// element the driver reads as data. Nothing about a binding is generated as
// CODE: the tick loop and the ingress both iterate this table, so adding a kind
// is one row here and one `[case]` there, never a new program shape.
fn flow_serve_bindings_element(r FlowRunner) string {
	mut b := []string{}
	b << '[bindings'
	for x in r.bindings {
		mut row := '  [b kind=${x.kind} addr="${flow_cli_quote(x.start)}" as="${flow_cli_quote(x.binder)}"'
		match x.kind {
			// MILLISECONDS: `$mod` reduces through f64 and an ns epoch instant is
			// past 2^53, so a ns bucket is not exact — see fs--tick-schedule.
			'schedule' { row += ' every="${x.every_ns / 1_000_000}" at="${x.at_ns / 1_000_000}"' }
			'intent' { row += ' stream="${flow_cli_quote(x.intent)}"' }
			'webhook' { row += ' path="${flow_cli_quote(x.path)}"' }
			'file' { row += ' dir="${flow_cli_quote(x.dir)}" pat="${flow_cli_quote(x.pat)}"' }
			else {}
		}
		b << row + ']'
	}
	b << ']'
	return b.join('\n')
}

// flow_serve_helpers is the driver's own vocabulary — the part that is the SAME
// whatever the `[runner]` document says. It is written once, here, rather than
// generated per binding, so the loop a reader audits is the loop that runs.
const flow_serve_helpers = "

[; the document set arrives as the DATA document — the [docs …]-verified bytes
   of every binding start= address, concatenated — so no document text is ever
   embedded in program source and nothing needs escaping. A binding finds ITS
   document by the address it already carries; the answer is a 0-or-1 SEQUENCE,
   so absence is [\$empty] and never a shape test on a value. ]
[?def fs--doc-by scope=private pure [returns any] (\$fs \$addr::string)
  [?to-sequence [?for [in \$f \$fs] [where [= [\$cx:hash \$f] \$addr]] [yield \$f]]]]

[?def fs--no-doc scope=private pure [returns element] (\$addr::string)
  [err code='cx-err:CXER4965'
    message=[\$concat \"E_COORD_ARG_INVALID: this runner holds no bound document at the address \" \$addr]]]

[; A DELIVERY BYTES ARE THE [args …] RECORD (RULED: WF-31 — [args …] is the
   EVENT payload, and there is NO mapping language in a binding row: a payload
   that needs reshaping is reshaped by a :runner step calling a pure transform).
   So a webhook body, a watched file and a committed intent payload are read the
   same way, and a delivery that is not an [args …] record is the caller fault,
   named as such. ]
[?def fs--args-of scope=private pure [returns any] (\$text::string)
  [?let [= \$as [\$cx:select [\$cx:parse \$text] \"//args\"]]
    [?if [\$empty \$as]
      [then [err code='cx-err:CXER4965'
              message=\"E_COORD_ARG_INVALID: a delivery IS the [args …] record (flow.md §4.25) and this one carries none\"]]
      [else [\$first \$as]]]]]

[; An [err …] VALUE is OPERAND-CONSUMING (code.md §9.2/#853): passing one to a
   call or into an element construction makes the WHOLE construction that err,
   and [?if <err>] runs NEITHER branch. So a refusal is never handed to a
   helper here — it is dispatched at a [?match], which takes its subject as a
   MATCH VALUE rather than an operand, and rendered back to TEXT there. That is
   what lets the ingress answer 400/404 with the refusal in the body instead of
   the http serve loop seeing a poisoned [response] and synthesizing a 500. ]
[?def fs--err-text scope=private pure [returns string] (\$c \$m)
  [\$concat \"[err code=\" [\$string \$c] \" message=\" [\$string \$m] \"]\"]]

[; one start, with the nonce its own event derives. Every input `start` puts
   verbatim into the :started transition is fixed by §4.25: the actor and the
   authority basis are the as= binder (the runner contributes none, §4.5), the
   nonce is the event content address, and `stream` defaults to the run id
   (1265-PB-3) — which is what makes this face transitions comparable with
   `cx flow run` byte for byte. ]
[?def fs--start scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$fs \$b \$nonce::string \$args)
  [?let [= \$ds [fs--doc-by \$fs [\$string \$b@addr]]]
    [?if [\$empty \$ds]
      [then [fs--no-doc [\$string \$b@addr]]]
      [else [?let [= \$fl [\$first \$ds]]
        [; a bad delivery arrives here as an [err …] \$args and short-circuits
           this call to itself — the refusal surfaces without a guard. ]
        [\$cxflow:start \$j \$fl \$args
          {env: \$e flow: \$fl actor: [\$string \$b@as] authority: [\$string \$b@as] nonce: \$nonce}]]]]]]

[; ── the four served kinds (RULED: WF-36) ────────────────────────────────── ]

[; schedule — the nonce is the OCCURRENCE INSTANT, so a new period is a new
   event and a re-fire of one occurrence is not. at= is the phase inside the
   period. A schedule event carries no payload beyond its occurrence, so its
   [args …] is empty; a flow bound to a schedule that declares required args
   refuses CXER4965 at `start`, which is the honest answer. ]
[; MILLISECONDS, not nanoseconds. `\$mod` reduces through f64, and an epoch
   instant in ns (~1.8e18) is far past 2^53, so the low ~8 bits of a ns bucket
   are noise: measured, two ticks 150ms apart inside one 300ms period computed
   two DIFFERENT occurrence instants and started two runs. In ms (~1.8e12) the
   arithmetic is exact, which is what makes one occurrence one run. A schedule
   `every=` below 1ms is refused by the [runner] reader for the same reason. ]
[?def fs--tick-schedule scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$fs \$b)
  [?let [= \$ev [\$str-to-int [\$string \$b@every]]]
    [= \$at [\$str-to-int [\$string \$b@at]]]
    [= \$now [\$time-to-unix-ms [\$time-now]]]
    [= \$occ [- \$now [\$mod [- \$now \$at] \$ev]]]
    [; the empty payload is BOUND before it is passed: a bareword-headed call
       whose operand list carries a LITERAL element is read as element
       CONSTRUCTION, not a call, so `[fs--start … [args]]` would build an
       [fs--start …] element rather than start a run (measured). A bound name
       is unambiguous. ]
    [= \$none [args]]
    [fs--start \$j \$e \$fs \$b [\$string \$occ] \$none]]]

[; file — the nonce is the FILE CONTENT ADDRESS, so the same bytes reappearing
   start nothing and changed bytes are a new event. ]
[?def fs--tick-file-one scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$fs \$b \$path::string)
  [?let [= \$t [\$cxio:read-file \$path]]
    [fs--start \$j \$e \$fs \$b [\$cx:hash \$t] [fs--args-of \$t]]]]

[; the count is READ, into the answer this returns, and that is what FORCES the
   comprehension: a bound-but-unread sequence is never walked, so a tick whose
   whole purpose is its effects has to be counted to happen at all. ]
[?def fs--tick-file scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$fs \$b)
  [?let [= \$d [\$string \$b@dir]]
    [= \$rx [\$cxre:compile [\$string \$b@pat]]]
    [?if [not [\$cxio:is-directory \$d]]
      [then [ticked kind=file n=0]]
      [else [ticked kind=file n=[\$count [?to-sequence [?for [in \$n [\$cxio:list-dir \$d]]
        [where [\$cxre:matches \$rx [\$string \$n]]]
        [yield [\$name [fs--tick-file-one \$j \$e \$fs \$b [\$concat \$d \"/\" [\$string \$n]]]]]]]]]]]]]

[; intent — the nonce is the committed intent stream + seq, so a replay starts
   no second run. The intent is served as a JOURNAL CONSUMER over the runner own
   journal (§4.9 offers a fabric subscription OR a journal consumer, and the
   consumer needs no [fabric …] row this document carries). ]
[?def fs--tick-intent-one scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$fs \$b \$stream::string \$en)
  [fs--start \$j \$e \$fs \$b
    [\$concat \$stream \":\" [\$string \$en@seq]]
    [fs--args-of [\$cx:emit \$en]]]]

[?def fs--tick-intent scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$fs \$b)
  [?let [= \$s [\$string \$b@stream]]
    [ticked kind=intent n=[\$count [?to-sequence [?for [in \$en [\$cxjournal:since \$j 1 \$s]]
      [yield [\$name [fs--tick-intent-one \$j \$e \$fs \$b \$s \$en]]]]]]]]]

[?def fs--tick-one scope=private impure [effects [read] [write] [clock]] [returns any] (\$j \$e \$fs \$b)
  [?match [\$string \$b@kind]
    [case \"schedule\" [fs--tick-schedule \$j \$e \$fs \$b]]
    [case \"file\" [fs--tick-file \$j \$e \$fs \$b]]
    [case \"intent\" [fs--tick-intent \$j \$e \$fs \$b]]
    [else ()]]]

[; ── the courier (RULED: WF-32) ──────────────────────────────────────────── ]
[; Exactly the `rearm` pending [sched-intent …] fold — which is exactly the set
   a tick can help, because a run parked on an OFFERED step advances on a
   correlated act arriving at the ingress, never on a tick. The runs this
   process started this boot are carried by the tick own re-issued `start` calls
   above (a live run RESUMES, a terminal one answers [deduped …]), so both
   halves of the WF-32 set are ticked and neither is enumerated through `fleet`
   — which would put the `live` pack between a make replacement and its build
   (§4.12a refuses CXER4964 without it). ]
[?def fs--pending-fold scope=private pure [returns map] (\$acc::map \$xs)
  [?if [\$empty \$xs]
    [then \$acc]
    [else [?let [= \$x [\$first \$xs]]
      [= \$nm [\$string \$x/name]]
      [fs--pending-fold
        [?if [= [\$string \$x/status] \"pending\"]
          [then [\$map-put \$acc \$nm \$nm]]
          [else [\$map-remove \$acc \$nm]]]
        [\$tail \$xs]]]]]]

[; `<run id>:<step>`, read back. The run id is itself flow:<address> and an
   address carries its own colon, so the split is on the LAST separator. ]
[?def fs--run-of scope=private pure [returns string] (\$nm::string)
  [?let [= \$i [\$str-rfind \$nm \":\"]]
    [?if [< \$i 2] [then \"\"] [else [\$str-slice \$nm 1 [- \$i 1]]]]]]

[?def fs--courier-runs scope=private impure [returns any] (\$j)
  [?let [= \$ints [\$cx:select [\$cxjournal:since \$j 1 \"\"] \"//sched-intent\"]]
    [= \$pending [fs--pending-fold {} \$ints]]
    [?to-sequence [?for [in \$nm [\$map-keys \$pending]]
      [where [\$str-starts-with [\$string \$nm] \"flow:\"]]
      [yield [fs--run-of [\$string \$nm]]]]]]]

[; a run is advanced with ITS OWN pinned document — the record carries the
   address, and this runner knows its documents by address. A run whose document
   this runner does not hold is left alone rather than advanced against the
   wrong one. ]
[?def fs--advance-run scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$fs \$b \$id::string)
  [?match [\$cxflow:status \$j \$id {}]
    [case [err @code=\$c] [skipped run=\$id reason=[\$string \$c]]]
    [else [?let [= \$rec [\$cxflow:status \$j \$id {}]]
      [= \$ds [fs--doc-by \$fs [\$string \$rec@flow]]]
      [?if [\$empty \$ds]
        [then [skipped run=\$id reason=\"unbound-document\"]]
        [else [?match [\$cxflow:advance \$j \$id ()
                {env: \$e flow: [\$first \$ds] actor: [\$string \$b@as] authority: [\$string \$b@as]}]
          [case [err @code=\$c] [skipped run=\$id reason=[\$string \$c]]]
          [else [ticked run=\$id]]]]]]]]]

[?def fs--courier scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$fs \$bs)
  [?let [= \$b [\$first \$bs/*]]
    [couriered n=[\$count [?to-sequence [?for [in \$id [fs--courier-runs \$j]]
      [where [not [= \$id \"\"]]]
      [yield [\$name [fs--advance-run \$j \$e \$fs \$b \$id]]]]]]]]]

[; ── the ingress (§4.23): two inputs and no third, told apart BY PATH ────── ]
[?def fs--reply scope=private pure [returns element] (\$code::int \$body::string)
  [response status=\$code [content-type \"application/cx\"] [body \$body]]]

[?def fs--refuse scope=private pure [returns element] (\$code::int \$cxer::string \$msg::string)
  [fs--reply \$code [\$concat \"[err code=cx-err:\" \$cxer \" message=\" \$msg \"]\"]]]

[?def fs--webhook-row scope=private pure [returns any] (\$bs \$path::string)
  [?to-sequence [?for [in \$b \$bs/*]
    [where [and [= [\$string \$b@kind] \"webhook\"] [= [\$string \$b@path] \$path]]]
    [yield \$b]]]]

[; a CORRELATED ACT — the [act run= step= …] shape `advance` already takes. The
   run own pinned document is the one it advances against, which is why this
   path needs no binding row and works for a run of ANY document the runner
   holds. ]
[?def fs--ingress-act scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$fs \$text::string)
  [?let [= \$acts [\$cx:select [\$cx:parse \$text] \"//act\"]]
    [?if [\$empty \$acts]
      [then [fs--refuse 400 \"CXER4965\"
              \"E_COORD_ARG_INVALID: the reserved ingress path carries a correlated act - [act run= step= …], the shape advance already takes\"]]
      [else [?let [= \$a [\$first \$acts]]
        [= \$id [\$string \$a@run]]
        [?match [\$cxflow:status \$j \$id {}]
          [case [err @code=\$c @message=\$m] [fs--reply 400 [fs--err-text \$c \$m]]]
          [else [?let [= \$rec [\$cxflow:status \$j \$id {}]]
            [= \$ds [fs--doc-by \$fs [\$string \$rec@flow]]]
            [?if [\$empty \$ds]
              [then [fs--refuse 400 \"CXER4956\"
                      \"E_COORD_RUN_NOT_FOUND: this runner holds no bound document at the address this run pins\"]]
              [else [?let [= \$adv [\$cxflow:advance \$j \$id \$a
                      {env: \$e flow: [\$first \$ds] actor: [\$string \$a@actor] authority: [\$string \$a@authority]}]]
                [?match \$adv
                  [case [err @code=\$c @message=\$m] [fs--reply 400 [fs--err-text \$c \$m]]]
                  [else [fs--reply 200 [\$cx:emit \$adv]]]]]]]]]]]]]]]

[?def fs--ingress scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$fs \$bs \$act-path::string \$req)
  [?let [= \$p [\$string \$req@path]]
    [= \$text [\$cxhttp:body-text \$req]]
    [?if [= \$p \$act-path]
      [then [fs--ingress-act \$j \$e \$fs \$text]]
      [else [?let [= \$hits [fs--webhook-row \$bs \$p]]
        [?if [\$empty \$hits]
          [then [fs--refuse 404 \"CXER4965\"
                  \"E_COORD_ARG_INVALID: this runner declares no binding at that path, and the reserved act path is the only other input its ingress takes\"]]
          [else [?let [= \$r [fs--start \$j \$e \$fs [\$first \$hits] [\$cx:hash \$text] [fs--args-of \$text]]]
            [?match \$r
              [case [err @code=\$c @message=\$m] [fs--reply 400 [fs--err-text \$c \$m]]]
              [else [fs--reply 200 [\$cx:emit \$r]]]]]]]]]]]]
"

// flow_serve_program renders the driver. `flow_cli_resolver` builds the resolver
// element from ENV.cx's module tree — the SAME one `cx flow run` uses, so an act
// resolves here exactly as it resolves there.
fn flow_serve_program(r FlowRunner, directives []string, acts []FlowCliAct, ticks i64, tick_ms i64) string {
	mut b := []string{}
	b << "[?lib 'cx-stdlib/flow' :as cxflow]"
	b << "[?lib 'cx-stdlib/store' :as cxstore]"
	b << "[?lib 'cx-stdlib/journal' :as cxjournal]"
	b << "[?lib 'cx-stdlib/http' :as cxhttp]"
	b << "[?lib 'cx-stdlib/io' :as cxio]"
	b << "[?lib 'cx-stdlib/re' :as cxre]"
	b << "[?lib 'cx-stdlib/log' :as cxlog]"
	b << directives.join('\n')
	b << flow_serve_helpers
	// THE LOOP is the one def that must be GENERATED rather than written once:
	// `[?sleep]` takes a DURATION LITERAL, never a bound value (measured —
	// CXER0100), so the courier's cadence is spliced in as the literal the
	// `[runner]` document spelled. `$n` < 0 runs until the process is stopped;
	// `$n` >= 0 is `--for`'s tick budget, which is what lets a fixture assert a
	// runner's own exit rather than kill it.
	b << '[?def fs--loop scope=private impure [effects [read] [write] [clock]] [returns int] (\$j \$e \$fs \$bs \$n::int \$done::int)
  [?if [= \$n 0]
    [then \$done]
    [else [?let
      [; \$count FORCES the comprehension: a bound-but-unread sequence is never
         walked, so a tick whose only purpose is its EFFECTS has to be counted
         to happen at all (measured — the first loop that bound it and did not
         read it started no run). ]
      [= \$w [\$count [?to-sequence [?for [in \$b \$bs/*] [yield [fs--tick-one \$j \$e \$fs \$b]]]]]]
      [= \$c [\$string [fs--courier \$j \$e \$fs \$bs]@n]]
      [= \$s [?sleep ${tick_ms}ms]]
      [fs--loop \$j \$e \$fs \$bs [?if [< \$n 0] [then -1] [else [- \$n 1]]] [+ \$done 1]]]]]]'
	b << '[?let [= \$e ${flow_cli_resolver(acts)}]'
	b << '[= \$j [\$cxjournal:open "${flow_cli_quote(r.journal)}" "${flow_cli_tenant}"]]'
	b << '[= \$fs [\$cx:select \$doc "//flow"]]'
	b << '[= \$bs ${flow_serve_bindings_element(r)}]'
	// §4.15's restore half, at BOOT, once per distinct bound document: `rearm`
	// takes ONE `opts.flow` because every registry entry it builds is a call to
	// `advance`, and `advance` is a function of ONE document. The report is the
	// observable §11 asks for; the COURIER, not the sched registry, is this
	// runner's liveness (see the header).
	mut seen := []string{}
	mut rearm_parts := []string{}
	for i, x in r.bindings {
		if x.start in seen {
			continue
		}
		seen << x.start
		v := 'r${i}'
		b << '[= \$${v} [\$cxflow:rearm \$j {env: \$e flow: [\$first [fs--doc-by \$fs "${flow_cli_quote(x.start)}"]] actor: "${flow_cli_quote(x.binder)}" authority: "${flow_cli_quote(x.binder)}"}]]'
		rearm_parts << '[rearm flow="${flow_cli_quote(x.start)}" rearmed=\$${v}@rearmed skipped=\$${v}@skipped orphaned=\$${v}@orphaned]'
	}
	b << '[= \$srv [\$cxhttp:serve "tcp://${flow_cli_quote(r.bind)}"' +
		' [?fn (\$req) [fs--ingress \$j \$e \$fs \$bs "${flow_serve_act_path}" \$req]] {}]]'
	// The BOOT REPORT, twice over, because the two readers are different and
	// CX has no stdout write. An operator watching a runner that has not
	// stopped needs it NOW, so it goes to the log sink (stderr by default);
	// a caller that gave `--for` reads the same element back, with the tick
	// count beside it, as the process's own answer on stdout.
	b << '[= \$rep [runner name="${flow_cli_quote(r.name)}"' +
		' journal="${flow_cli_quote(r.journal)}" bind="${flow_cli_quote(r.bind)}"' +
		' act-path="${flow_serve_act_path}" bindings=${r.bindings.len}' +
		' documents=[\$count \$fs] ingress=[\$string \$srv@state] ' + rearm_parts.join(' ') + ']]'
	b << '[= \$lg [\$cxlog:info [\$cx:emit \$rep]]]'
	b << '[= \$ran [fs--loop \$j \$e \$fs \$bs ${ticks} 0]]'
	b << '  [runner-stopped ticks=\$ran \$rep]]'
	return b.join('\n')
}

// ── the verb ────────────────────────────────────────────────────────────────

// flow_cli_serve is `cx flow serve RUNNER.cx`. It reads and validates the
// `[runner]` document, fetches and VERIFIES each binding's document from
// `[docs …]`, scans `[env …]` for the module tree, and evaluates ONE driver
// program that boots (`rearm`), binds the ingress and ticks until `--for`
// elapses or the process is stopped.
fn flow_cli_serve(o FlowCliOpts, for_ns i64) {
	if o.positional.len != 1 {
		flow_cli_die('serve takes exactly one RUNNER.cx')
	}
	if o.env != '' {
		flow_cli_die('serve reads its module tree from the [runner] document\'s own [env …] row, not --env')
	}
	if o.journal != '' || o.ephemeral {
		flow_cli_die('serve reads its journal from the [runner] document\'s own [journal url=…] row')
	}
	if o.args.len > 0 {
		flow_cli_die('serve takes no [args …] fields: a run\'s args are its EVENT\'s payload (flow.md §4.25), never the command line\'s')
	}
	path := o.positional[0]
	src := flow_cli_read(path, 'the runner document')
	mut r := flow_serve_parse(src, path)
	docs_dir := flow_serve_url_dir(r.docs, '[docs url=…]')
	// the DATA document: every binding's `[docs …]`-verified flow, concatenated
	// in binding order and deduplicated by address, so no document text is ever
	// embedded in program source.
	mut input := []string{}
	mut have := []string{}
	for mut x in r.bindings {
		x.doc_src = flow_serve_fetch_doc(docs_dir, x.start)
		if x.start in have {
			continue
		}
		have << x.start
		input << x.doc_src
	}
	directives, acts := flow_cli_env_scan(r.env)
	tick_ms := r.courier_ns / 1_000_000
	ticks := if for_ns <= 0 { i64(-1) } else { for_ns / r.courier_ns }
	flow_cli_install_caps(o)
	program := flow_serve_program(r, directives, acts, ticks, if tick_ms < 1 { i64(1) } else { tick_ms })
	println(flow_cli_eval(input.join('\n'), program).trim_space())
	exit(0)
}
