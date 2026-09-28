// `cx flow serve` — the STANDALONE RUNNER of cx-platform/flow (flow.md §4.23;
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
//                     with no UX face of its own — or an OPERATOR ACT on
//                     the run, `[cancel|pause|resume|skip|retry-now|resolve
//                     run= actor= authority= …]` (§4.21), the module verb of
//                     that name under the act's own basis. The path is
//                     RESERVED: an `[on …]` row claiming it refuses
//                     CXER4965 (§8).
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
// the `as=` binder's identity unless the row names a `cap:` basis (RULED:
// SEED-1); the runner contributes none (§4.5).

module main

import os
import cx

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
	binder   string // `as=` — the actor of the start, and its authority basis unless the row names one
	authority string // the run's recorded basis: `authority=cap:…` when the row names one, else the binder (RULED: SEED-1)
	path     string // webhook
	glob     string // file — the source pattern, kept for the refusal text
	dir      string // file — the literal directory the glob names
	pat      string // file — the basename pattern as a regex
	intent   string // intent — the committed intent's journal stream
	act      string // intent — `act=`, the qualified intent name the row selects (RULED: AA-2); '' selects every entry
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
	store      string // `[store url=…]` — the projected verbs' store slot (RULED: #728 CK-3)
	authz      string // `[authz principal=…]` — the runner's own acting chain (RULED: HOST-4)
	authz_caps []string // `[authz capabilities=…]` — the capabilities seeded beside the root grant (RULED: SEED-1)
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

// flow_serve_act_name_ok is the `act=` spelling (flow.md §4.24, RULED: AA-2):
// a qualified intent name `ns/verb`, each side a lower-case name — the rule
// `fill` holds an `act` slot's answer to (composition.md §3.10), so a row the
// studio or the scaffold writes is one this runner reads.
fn flow_serve_act_name_ok(s string) bool {
	parts := s.split('/')
	if parts.len != 2 {
		return false
	}
	for p in parts {
		if p == '' || p[0] < `a` || p[0] > `z` {
			return false
		}
		for c in p {
			if !((c >= `a` && c <= `z`) || (c >= `0` && c <= `9`) || c == `-` || c == `_`) {
				return false
			}
		}
	}
	return true
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
	// RULED: SEED-1 — a row may name the run's recorded basis as the `cap:`
	// address of a delegation (`authority=cap:…`, flow.md §4.24), which the
	// flow PEP then decides a `[requires]` step against — the delegation the
	// `[authz principal=… capabilities=…]` row seeds, typically. Absent, the
	// basis is the `as=` binder, as before; `cap:` is the ONE spelling of a
	// trust input (core/commands_effects.md §6), so anything else refuses.
	mut authority := e.attr('authority')
	if authority == '' {
		authority = binder
	} else if !authority.starts_with('cap:') {
		flow_serve_refuse('an [on kind=${kind} …] row carries authority=`${authority}`; authority= names the run\'s recorded basis by the `cap:` address of a delegation — `authority=cap:…` (flow.md §4.24, RULED: SEED-1) — and is left off when the binder\'s own basis is meant')
	}
	mut b := FlowBinding{
		kind:      kind
		start:     start
		binder:    binder
		authority: authority
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
			// RULED: AA-2 — `act=` SELECTS which committed acts start a run: the
			// entry's qualified intent name, the do-form's string (KIT-2). A value
			// that is no `ns/verb` would select nothing and never fire, so it
			// refuses here rather than parse and stay inert (WF-35's rule).
			b.act = e.attr('act')
			if e.has_attr('act') && !flow_serve_act_name_ok(b.act) {
				flow_serve_refuse('kind `intent` carries act=`${b.act}`; act= is the qualified intent name a committed entry carries — `act=\'ns/verb\'` (flow.md §4.24, RULED: AA-2) — and a selection naming no act would start nothing')
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
	// `store` is OPTIONAL, and REQUIRED when `[env …]` loads a feature package
	// (flow.md §4.23, RULED: #728 CK-3). A feature package loaded as a module
	// projects one command def per grammar verb (the distribution engine's
	// `pkg:` arm, the projection the XAP host loads the same package through),
	// and each projected def calls the feature's `apply` with the store SLOT
	// this row fills — so the row is read here, and the refusal of a runner
	// whose `[env …]` carries a feature package and no `[store]` is taken in
	// flow_cli_serve, once the module tree is scanned (it names the package).
	known := ['journal', 'docs', 'env', 'store', 'ingress', 'on', 'courier', 'authz']
	for n in r.items {
		if !n.is_element() {
			continue
		}
		k := n.element()
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
	if sr := flow_serve_child(r, 'store') {
		out.store = sr.attr('url')
		if out.store == '' {
			flow_serve_refuse('[store …] carries no url=')
		}
	}
	// RULED: HOST-4 — the runner-document `[authz principal=…]` row names the
	// chain the standalone runner acts under; both faces then decide a
	// feature verb the same way (the host already passes its runtime's
	// authority store). A `[runner]` with no row behaves exactly as before —
	// `opts.authz` stays unset and only a command that DECLARES [requires]
	// is affected (flag 3 of the XAP-1 draft, closed here for this class).
	if ar := flow_serve_child(r, 'authz') {
		out.authz = ar.attr('principal')
		if out.authz == '' {
			flow_serve_refuse('[authz …] carries no principal=')
		}
		// RULED: SEED-1 — the capabilities the runner acts with, seeded
		// beside the root grant (flow_serve_program); space-separated, the
		// names a `[requires cap:…]` clause asks for.
		out.authz_caps = ar.attr('capabilities').fields()
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

// flow_serve_docs_rest answers the verbatim bytes of every OTHER document the
// `[docs …]` store holds — every `.cx` file that parses to a `[flow …]` or a
// `[business-calendar …]`, in file-name order, skipping the addresses a binding
// already fetched. They are the documents a `flow=` step may reference
// (flow.md §4.20, RULED: WF-22) and the calendars a `calendar=` may name
// (flow.md §4.22, RULED: WF-24): both resolve through the executing
// environment's ONE resolver (§4.1), and this runner's documents live in its
// `[docs …]` store (RULED: 789-WF-30), so the store is where the resolver's
// document rows come from. No address is claimed here: a document row's
// address IS its content address, computed by the module from the bytes, so
// nothing can be named for an address it does not have. A file that does not
// parse, or is neither, is not a document of this store and is passed over,
// exactly as the `start=` scan passes it over.
fn flow_serve_docs_rest(dir string, have []string) []string {
	if !os.is_dir(dir) {
		return []string{}
	}
	mut names := os.ls(dir) or { return []string{} }
	names.sort()
	mut out := []string{}
	for name in names {
		if !name.ends_with('.cx') {
			continue
		}
		p := os.join_path(dir, name)
		if !os.is_file(p) {
			continue
		}
		src := os.read_file(p) or { continue }
		addr := cx.cx_text_hash(src) or { continue }
		if addr in have {
			continue
		}
		doc := cx.parse(src) or { continue }
		mut is_doc := false
		for n in doc.elements {
			if n.is_element() {
				is_doc = n.element().name in ['flow', 'business-calendar']
				break
			}
		}
		if is_doc {
			out << src
		}
	}
	return out
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
		mut row := '  [b kind=${x.kind} addr="${flow_cli_quote(x.start)}" as="${flow_cli_quote(x.binder)}" authority="${flow_cli_quote(x.authority)}"'
		match x.kind {
			// MILLISECONDS: `$mod` reduces through f64 and an ns epoch instant is
			// past 2^53, so a ns bucket is not exact — see fs--tick-schedule.
			'schedule' { row += ' every="${x.every_ns / 1_000_000}" at="${x.at_ns / 1_000_000}"' }
			'intent' { row += ' stream="${flow_cli_quote(x.intent)}"' + if x.act != '' { ' act="${flow_cli_quote(x.act)}"' } else { '' } }
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

[; ── THE INSTANT a calendar document is driven from (flow.md §4.22, RULED:
   WF-24, 1358-e). flow keeps no clock of its own, so its open-time durations
   are measured from the instant the RUNNER states — and this process is the
   runner: every start, courier tick and delivered act of a document that
   names a `calendar=` carries this clock's instant (`opts.at` on a start, the
   event's `at=` on an advance). A document with no calendar is driven exactly
   as before, which is what keeps its transitions byte-identical under
   `cx flow run` and `cx flow serve` (RULED: WF-28b). ]
[?def fs--has-cal scope=private pure [returns bool] (\$fl)
  [\$exists [\$cx:select \$fl \"//*[@calendar]\"]]]

[?def fs--now scope=private impure [effects [clock]] [returns string] ()
  [\$string [\$time-now]]]

[?def fs--at-opts scope=private impure [effects [clock]] [returns map] (\$fl \$o::map)
  [?if [fs--has-cal \$fl] [then [\$map-put \$o \"at\" [fs--now]]] [else \$o]]]

[?def fs--tick-for scope=private impure [effects [clock]] [returns any] (\$fl)
  [?if [fs--has-cal \$fl] [then [tick at=[fs--now]]] [else ()]]]

[; a delivered act of a calendar document that states no instant is given
   this runner's — rebuilt through its canonical text, the one form that
   carries every attribute and child it arrived with. ]
[?def fs--act-at scope=private impure [effects [clock]] [returns any] (\$fl \$a)
  [?if [or [not [fs--has-cal \$fl]] [\$exists \$a@at]] [then \$a]
    [else [?let [= \$s [\$str-trim [\$cx:serialize \$a]]]
      [\$cx:parse [\$concat \"[act at=\\\"\" [fs--now] \"\\\"\" [\$str-slice \$s 5 [\$str-length \$s]]]]]]]]

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

[; a committed intent's PAYLOAD (RULED: XAP-1a, flow.md §4.24) — the same
   reading on both runners, so an intent binding moves between this runner
   and a deployment with no edit: an entry that carries a committed act,
   [do 'ns/verb' [f v]…], starts the run with [args [f v]…] — its fields, a
   fixed reading and no mapping language (§4.25) — and an entry that carries
   an [args …] record starts it with that record. ]
[?def fs--entry-args scope=private pure [returns any] (\$en)
  [?let [= \$ds [\$cx:select \$en \"//do\"]]
    [?if [not [\$empty \$ds]]
      [then [?let [= \$d [\$first \$ds]] [?element \"args\" [?splice \$d/*]]]]
      [else [?let [= \$as [\$cx:select \$en \"//args\"]]
        [?if [\$empty \$as]
          [then [err code='cx-err:CXER4965'
                  message=\"E_COORD_ARG_INVALID: a committed intent's payload is its act's fields - [do 'ns/verb' [f v]…] - or its [args …] record (flow.md §4.24), and this entry carries neither\"]]
          [else [\$first \$as]]]]]]]]

[; the runner's BASE opts under a call's own: \$o carries what only the
   runner can hand the law — the `[store url=]` row's store slot, which a
   feature package's projected command defs call `apply` with (RULED: CK-3)
   — and the call's map (env, flow, basis, nonce) is laid over it. ]
[?def fs--with scope=private pure [returns map] (\$o::map \$m::map)
  [?reduce [\$map-keys \$m] [using [?fn (\$acc \$k) [\$map-put \$acc \$k [\$map-get \$m \$k]]]] [init \$o]]]

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
   verbatim into the :started transition is fixed by §4.25: the actor is the
   as= binder and the authority basis the authority= of the row - the binder unless
   the row names a cap: basis (RULED: SEED-1; the runner contributes none, §4.5), the
   nonce is the event content address, and `stream` defaults to the run id
   (1265-PB-3) — which is what makes this face transitions comparable with
   `cx flow run` byte for byte. ]
[?def fs--start scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$o \$fs \$b \$nonce::string \$args)
  [?let [= \$ds [fs--doc-by \$fs [\$string \$b@addr]]]
    [?if [\$empty \$ds]
      [then [fs--no-doc [\$string \$b@addr]]]
      [else [?let [= \$fl [\$first \$ds]]
        [; a bad delivery arrives here as an [err …] \$args and short-circuits
           this call to itself — the refusal surfaces without a guard. ]
        [\$cxflow:start \$j \$fl \$args
          [fs--at-opts \$fl [fs--with \$o {env: \$e flow: \$fl actor: [\$string \$b@as] authority: [\$string \$b@authority] nonce: \$nonce}]]]]]]]]

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
[?def fs--tick-schedule scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$o \$fs \$b)
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
    [fs--start \$j \$e \$o \$fs \$b [\$string \$occ] \$none]]]

[; file — the nonce is the FILE CONTENT ADDRESS, so the same bytes reappearing
   start nothing and changed bytes are a new event. ]
[?def fs--tick-file-one scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$o \$fs \$b \$path::string)
  [?let [= \$t [\$cxio:read-file \$path]]
    [fs--start \$j \$e \$o \$fs \$b [\$cx:hash \$t] [fs--args-of \$t]]]]

[; the count is READ, into the answer this returns, and that is what FORCES the
   comprehension: a bound-but-unread sequence is never walked, so a tick whose
   whole purpose is its effects has to be counted to happen at all. ]
[?def fs--tick-file scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$o \$fs \$b)
  [?let [= \$d [\$string \$b@dir]]
    [= \$rx [\$cxre:compile [\$string \$b@pat]]]
    [?if [not [\$cxio:is-directory \$d]]
      [then [ticked kind=file n=0]]
      [else [ticked kind=file n=[\$count [?to-sequence [?for [in \$n [\$cxio:list-dir \$d]]
        [where [\$cxre:matches \$rx [\$string \$n]]]
        [yield [\$name [fs--tick-file-one \$j \$e \$o \$fs \$b [\$concat \$d \"/\" [\$string \$n]]]]]]]]]]]]]

[; intent — the nonce is the committed intent stream + seq, so a replay starts
   no second run. The intent is served as a JOURNAL CONSUMER over the runner own
   journal (§4.9 offers a fabric subscription OR a journal consumer, and the
   consumer needs no [fabric …] row this document carries). ]
[?def fs--tick-intent-one scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$o \$fs \$b \$stream::string \$en)
  [fs--start \$j \$e \$o \$fs \$b
    [\$concat \$stream \":\" [\$string \$en@seq]]
    [fs--entry-args \$en]]]

[; act= — a SELECTION, not a mapping (flow.md §4.24, RULED: AA-2): a row
   naming act= starts a run only for a committed entry whose do-form names
   that act — the entry's qualified intent name, the do-form's string (KIT-2)
   — and every other entry on the stream starts none; a row without act= is
   unchanged. The payload, the nonce and the when= value test are §4.25's. ]
[?def fs--entry-act scope=private pure [returns string] (\$en)
  [?let [= \$ds [\$cx:select \$en \"//do\"]]
    [?if [\$empty \$ds] [then \"\"] [else [\$string [\$first [\$first \$ds]/node()]]]]]]

[?def fs--selects scope=private pure [returns bool] (\$b \$en)
  [?if [\$present \$b@act] [then [= [fs--entry-act \$en] [\$string \$b@act]]] [else true]]]

[?def fs--tick-intent scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$o \$fs \$b)
  [?let [= \$s [\$string \$b@stream]]
    [ticked kind=intent n=[\$count [?to-sequence [?for [in \$en [\$cxjournal:since \$j 1 \$s]]
      [where [fs--selects \$b \$en]]
      [yield [\$name [fs--tick-intent-one \$j \$e \$o \$fs \$b \$s \$en]]]]]]]]]

[?def fs--tick-one scope=private impure [effects [read] [write] [clock]] [returns any] (\$j \$e \$o \$fs \$b)
  [?match [\$string \$b@kind]
    [case \"schedule\" [fs--tick-schedule \$j \$e \$o \$fs \$b]]
    [case \"file\" [fs--tick-file \$j \$e \$o \$fs \$b]]
    [case \"intent\" [fs--tick-intent \$j \$e \$o \$fs \$b]]
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
   wrong one.

   AND WITH ITS OWN BASIS. The basis comes off the RECORD (`$rec@actor`,
   `$rec@authority`), never off a binding row, which is the law this verb's
   own `--allow-*` help text already states: every step is admitted against
   the RUN's recorded basis, never the runner's. The courier reaches every
   pending run in the journal regardless of which binding started it, so
   taking the basis from a binding row admits a webhook run under the
   SCHEDULE binder's identity — a real authority defect, not a cosmetic one.
   A run records the basis it was admitted against precisely so a courier
   contributes none of its own (§4.15, RULED: 1265-PB-1). ]
[?def fs--advance-run scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$o \$fs \$id::string)
  [?match [\$cxflow:status \$j \$id {}]
    [case [err @code=\$c] [skipped run=\$id reason=[\$string \$c]]]
    [else [?let [= \$rec [\$cxflow:status \$j \$id {}]]
      [= \$ds [fs--doc-by \$fs [\$string \$rec@flow]]]
      [?if [\$empty \$ds]
        [then [skipped run=\$id reason=\"unbound-document\"]]
        [else [?match [\$cxflow:advance \$j \$id [fs--tick-for [\$first \$ds]]
                [fs--with \$o {env: \$e flow: [\$first \$ds] actor: [\$string \$rec@actor] authority: [\$string \$rec@authority]}]]
          [case [err @code=\$c] [skipped run=\$id reason=[\$string \$c]]]
          [else [ticked run=\$id]]]]]]]]]

[?def fs--courier scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$o \$fs)
  [couriered n=[\$count [?to-sequence [?for [in \$id [fs--courier-runs \$j]]
    [where [not [= \$id \"\"]]]
    [yield [\$name [fs--advance-run \$j \$e \$o \$fs \$id]]]]]]]]

[; ── the ingress (§4.23): two inputs and no third, told apart BY PATH ────── ]
[?def fs--reply scope=private pure [returns element] (\$code::int \$body::string)
  [response status=\$code [content-type \"application/cx\"] [body \$body]]]

[?def fs--refuse scope=private pure [returns element] (\$code::int \$cxer::string \$msg::string)
  [fs--reply \$code [\$concat \"[err code=cx-err:\" \$cxer \" message=\" \$msg \"]\"]]]

[?def fs--webhook-row scope=private pure [returns any] (\$bs \$path::string)
  [?to-sequence [?for [in \$b \$bs/*]
    [where [and [= [\$string \$b@kind] \"webhook\"] [= [\$string \$b@path] \$path]]]
    [yield \$b]]]]

[; after the act, the run is DRIVEN ON (flow.md §4.6, §4.23; RULED: FW-1). One
   `advance` is one effect (RULED: 1265-PB-6): an act that completes an OFFERED
   step performs that step's own effect and stops, and the steps after it are
   the law's NEXT effects — while the courier below ticks only the runs that
   hold a pending timer, so a run whose offer carried no deadline would wait
   for a turn nothing schedules. The ingress therefore advances the run with
   courier ticks until it parks or terminates (the record stops changing), the
   same drive `cx flow run` makes after `start`, and under the run's OWN
   recorded basis — never the act's, whose authority was the performer's for
   that one act (§4.5) — so the two faces append byte-identical transitions
   (RULED: WF-28b). The bound is a safety net, not a stop condition. ]
[?def fs--drive-on scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$o \$doc \$id::string \$rec \$n::int)
  [?if [< \$n 1] [then \$rec]
    [else [?let [= \$next [\$cxflow:advance \$j \$id [fs--tick-for \$doc]
                   [fs--with \$o {env: \$e flow: \$doc actor: [\$string \$rec@actor] authority: [\$string \$rec@authority]}]]]
      [?match \$next
        [case [err] \$rec]
        [else [?if [= [\$cx:hash \$next] [\$cx:hash \$rec]] [then \$next]
                [else [fs--drive-on \$j \$e \$o \$doc \$id \$next [- \$n 1]]]]]]]]]]

[; a CORRELATED ACT — the [act run= step= …] shape `advance` already takes. The
   run own pinned document is the one it advances against, which is why this
   path needs no binding row and works for a run of ANY document the runner
   holds. ]
[; an OPERATOR ACT (flow.md §4.21, §4.8; RULED: WF-19, WF-25, 1265-PB-8) —
   `[cancel …]`, `[pause …]`, `[resume …]`, `[skip … step=]`, `[retry-now …]`,
   `[resolve … [resolution …]]`, each carrying `run=`, `actor=`, `authority=`
   and, where the verb takes one, its `[reason …]` — is the other thing the
   reserved path carries: an act on the RUN, which a runner with no UX face
   of its own must take exactly as it takes a correlated act on a step. It is
   ONE call to the module verb of the same name, under the ACT's actor and
   authority (the operator's, never the run's, never a binding row's), with
   the run's own pinned document; the verb admits it, records it, and drives
   the run on — so the record answered here is the one `cx flow <verb>`
   answers for the same act (RULED: WF-28b). `pause` measures each armed
   timer's remainder from the act's instant, which is this runner's clock
   when the act arrives (the verb itself reads none). ]
[?def fs--op-word scope=private pure [returns bool] (\$w::string)
  [\$str-contains \" cancel pause resume skip retry-now resolve \" [\$concat \" \" \$w \" \"]]]

[; the body IS the act: `\$cx:parse` answers the one element a body carries,
   and an operator act is told apart by that element's own head — never by a
   descendant, so a correlated act whose [result …] happens to hold a child
   named like a verb is still the correlated act it is. ]
[?def fs--op-of scope=private pure [returns any] (\$text::string)
  [?match [\$cx:parse \$text]
    [case [err] ()]
    [else [?let [= \$d [\$cx:parse \$text]]
      [?if [not [\$str-starts-with [\$str-trim [\$cx:serialize \$d]] \"[\"]] [then ()]
        [else [?if [fs--op-word [\$name \$d]] [then (\$d)] [else ()]]]]]]]]

[?def fs--kid-of scope=private pure [returns any] (\$a \$n::string \$none)
  [?let [= \$ks [?to-sequence [?for [in \$k \$a/*] [where [= [\$name \$k] \$n]] [yield \$k]]]]
    [?if [\$empty \$ks] [then \$none] [else [\$first \$ks]]]]]

[?def fs--ingress-op scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$o \$fs \$a)
  [?let [= \$id [\$string \$a@run]]
    [?match [\$cxflow:status \$j \$id {}]
      [case [err @code=\$c @message=\$m] [fs--reply 400 [fs--err-text \$c \$m]]]
      [else [?let [= \$rec [\$cxflow:status \$j \$id {}]]
        [= \$ds [fs--doc-by \$fs [\$string \$rec@flow]]]
        [?if [\$empty \$ds]
          [then [fs--refuse 400 \"CXER4956\"
                  \"E_COORD_RUN_NOT_FOUND: this runner holds no bound document at the address this run pins\"]]
          [else [?let [= \$ro [fs--with \$o {env: \$e flow: [\$first \$ds] actor: [\$string \$a@actor] authority: [\$string \$a@authority] at: [\$time-now]}]]
            [= \$why [\$fs--kid-of \$a \"reason\" {}]]
            [= \$r [?match [\$name \$a]
                     [case \"cancel\"    [\$cxflow:cancel \$j \$id \$why \$ro]]
                     [case \"pause\"     [\$cxflow:pause \$j \$id \$why \$ro]]
                     [case \"resume\"    [\$cxflow:resume \$j \$id \$ro]]
                     [case \"skip\"      [\$cxflow:skip \$j \$id [\$string \$a@step] \$why \$ro]]
                     [case \"retry-now\" [\$cxflow:retry-now \$j \$id \$ro]]
                     [else              [\$cxflow:resolve \$j \$id [\$fs--kid-of \$a \"resolution\" [resolution]] \$ro]]]]
            [?match \$r
              [case [err @code=\$c @message=\$m] [fs--reply 400 [fs--err-text \$c \$m]]]
              [else [fs--reply 200 [\$cx:emit \$r]]]]]]]]]]]]

[?def fs--ingress-act scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$o \$fs \$text::string)
  [?let [= \$ops [fs--op-of \$text]]
    [?if [\$empty \$ops] [then [fs--ingress-step-act \$j \$e \$o \$fs \$text]]
      [else [fs--ingress-op \$j \$e \$o \$fs [\$first \$ops]]]]]]

[?def fs--ingress-step-act scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$o \$fs \$text::string)
  [?let [= \$acts [\$cx:select [\$cx:parse \$text] \"//act\"]]
    [?if [\$empty \$acts]
      [then [fs--refuse 400 \"CXER4965\"
              \"E_COORD_ARG_INVALID: the reserved ingress path carries a correlated act - [act run= step= …], the shape advance already takes - or an operator act on the run - [cancel|pause|resume|skip|retry-now|resolve run= actor= authority= …]\"]]
      [else [?let [= \$a [\$first \$acts]]
        [= \$id [\$string \$a@run]]
        [?match [\$cxflow:status \$j \$id {}]
          [case [err @code=\$c @message=\$m] [fs--reply 400 [fs--err-text \$c \$m]]]
          [else [?let [= \$rec [\$cxflow:status \$j \$id {}]]
            [= \$ds [fs--doc-by \$fs [\$string \$rec@flow]]]
            [?if [\$empty \$ds]
              [then [fs--refuse 400 \"CXER4956\"
                      \"E_COORD_RUN_NOT_FOUND: this runner holds no bound document at the address this run pins\"]]
              [else [?let [= \$adv [\$cxflow:advance \$j \$id [fs--act-at [\$first \$ds] \$a]
                      [fs--with \$o {env: \$e flow: [\$first \$ds] actor: [\$string \$a@actor] authority: [\$string \$a@authority]}]]]
                [?match \$adv
                  [case [err @code=\$c @message=\$m] [fs--reply 400 [fs--err-text \$c \$m]]]
                  [else [fs--reply 200 [\$cx:emit [fs--drive-on \$j \$e \$o [\$first \$ds] \$id \$adv 256]]]]]]]]]]]]]]]]

[?def fs--ingress scope=private impure [effects [read] [write] [clock]] [returns element] (\$j \$e \$o \$fs \$bs \$act-path::string \$req)
  [?let [= \$p [\$string \$req@path]]
    [= \$text [\$cxhttpc:body-text \$req]]
    [?if [= \$p \$act-path]
      [then [fs--ingress-act \$j \$e \$o \$fs \$text]]
      [else [?let [= \$hits [fs--webhook-row \$bs \$p]]
        [?if [\$empty \$hits]
          [then [fs--refuse 404 \"CXER4965\"
                  \"E_COORD_ARG_INVALID: this runner declares no binding at that path, and the reserved act path is the only other input its ingress takes\"]]
          [else [?let [= \$r [fs--start \$j \$e \$o \$fs [\$first \$hits] [\$cx:hash \$text] [fs--args-of \$text]]]
            [?match \$r
              [case [err @code=\$c @message=\$m] [fs--reply 400 [fs--err-text \$c \$m]]]
              [else [fs--reply 200 [\$cx:emit \$r]]]]]]]]]]]]
"

// flow_serve_program renders the driver. `flow_cli_resolver` builds the resolver
// element from ENV.cx's module tree — the SAME one `cx flow run` uses, so an act
// resolves here exactly as it resolves there.
fn flow_serve_program(r FlowRunner, directives []string, acts []FlowCliAct, ticks i64, tick_ms i64) string {
	mut b := []string{}
	b << "[?lib 'cx-platform/flow' :as cxflow]"
	b << "[?lib 'cx-platform/store' :as cxstore]"
	b << "[?lib 'cx-platform/journal' :as cxjournal]"
	b << "[?lib 'cx-platform/authz-store' :as cxauthzstore]"
	// BOTH halves of http, because this driver is both (RULED: 1427-e). It
	// SERVES — `cxhttp:serve` below — and it READS A MESSAGE, `body-text`,
	// which is a pure codec verb and went to the Ring-1 `http-client` module
	// when the split happened. The migration tool writes exactly this pair for
	// a CX program, but this program is assembled by CONCATENATING V string
	// constants and the tool's V pass sees one literal at a time, so it could
	// only ever pick one namespace for the whole driver: it picked the serve
	// half, `body-text` stopped resolving, and every delivery answered 400
	// with E_NO_CALLABLE (the post-merge red on 100989e09). The pair is
	// written here by hand, in the shape the tool would have produced.
	b << "[?lib 'cx-platform/http' :as cxhttp]"
	b << "[?lib 'cx-stdlib/http-client' :as cxhttpc]"
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
	b << '[?def fs--loop scope=private impure [effects [read] [write] [clock]] [returns int] (\$j \$e \$o \$fs \$bs \$n::int \$done::int)
  [?if [= \$n 0]
    [then \$done]
    [else [?let
      [; \$count FORCES the comprehension: a bound-but-unread sequence is never
         walked, so a tick whose only purpose is its EFFECTS has to be counted
         to happen at all (measured — the first loop that bound it and did not
         read it started no run). ]
      [= \$w [\$count [?to-sequence [?for [in \$b \$bs/*] [yield [fs--tick-one \$j \$e \$o \$fs \$b]]]]]]
      [= \$c [\$string [fs--courier \$j \$e \$o \$fs]@n]]
      [= \$s [?sleep ${tick_ms}ms]]
      [fs--loop \$j \$e \$o \$fs \$bs [?if [< \$n 0] [then -1] [else [- \$n 1]]] [+ \$done 1]]]]]]'
	// THE RESOLVER CARRIES THE DOCUMENTS (flow.md §4.20, RULED: WF-22): a `flow=`
	// step's reference resolves through the ONE resolver (§4.1), so beside the
	// act rows the `--env` scan built it carries every flow document this runner
	// holds. The data document is ONE element, `[runner-docs [bound …] [sub-flows
	// …]]`: the bound documents, then the rest of the `[docs …]` store, so `$fs`
	// — the bound set every binding, the ingress and the boot report read — is
	// exactly the set it was, and the resolver carries both. A document row's address
	// is its content address, computed by the module; nothing here names one. The
	// store's `[business-calendar …]` documents join it the same way, for the
	// `calendar=` addresses a document names (flow.md §4.22, RULED: WF-24).
	b << '[?let [= \$e0 ${flow_cli_resolver(acts)}]'
	b << '[= \$e [?element "resolver" [?splice \$e0/*] [?splice [\$cx:select \$doc "//runner-docs/*/flow"]] [?splice [\$cx:select \$doc "//runner-docs/*/business-calendar"]]]]'
	b << '[= \$j [\$cxjournal:open "${flow_cli_quote(r.journal)}" "${flow_cli_tenant}"]]'
	b << '[= \$fs [\$cx:select \$doc "//runner-docs/bound/flow"]]'
	b << '[= \$bs ${flow_serve_bindings_element(r)}]'
	// THE BASE OPTS every call of the law is laid over (fs--with). With a
	// `[store url=]` row they carry the store SLOT a feature package's
	// projected command defs hand `apply` (RULED: #728 CK-3, XAP-1a): the
	// deployment-context shape the XAP host hands the same defs —
	// `[host tenant= [store …] [journal …]]` — built from this runner's own
	// store and journal, so a projected verb resolves to ONE function on both
	// faces. With none they are empty, and nothing about a hand-authored
	// `[env …]` moves.
	if r.store != '' {
		b << '[= \$st [\$cxstore:open "${flow_cli_quote(r.store)}"]]'
		b << '[= \$o0 {store: [host tenant="${flow_cli_quote(r.name)}" [store \$st] [journal \$j]]}]'
	} else {
		b << '[= \$o0 {}]'
	}
	// RULED: HOST-4 — a `[runner]` document naming `[authz principal=…]`
	// opens the standalone runner's own authority store and hands it in as
	// `opts.authz`, exactly as the deployment host hands `flow-perform` its
	// runtime's (X2, RULED: 1265-WF-40b): both faces then decide a feature
	// verb the SAME way — a principal actor is the root of its own chain
	// either way, and an agent binder with no grant in the store is refused
	// either way. A `[runner]` with no `[authz]` row hands in none, and
	// `opts.authz` stays absent — today's behaviour, byte-identical.
	//
	// RULED: HOST-4's Letter 33 note — the row SEEDS the freshly opened store
	// with the named principal as an explicit root grant, self-issued (`from`
	// and `to` both `principal=`, which `authz.md`'s attenuation rule reads as
	// principal-rooted with no parent to check): the document's OWN statement
	// of who the runner acts as becomes the store's first recorded delegation,
	// exactly as a host's deployment granting the same root would record one,
	// rather than leaving the store silently empty of the one fact the
	// document already states. The root carries no `[capabilities]` of its
	// own — this driver is generic over every feature a `[runner]` might load,
	// so it names no feature's verbs.
	//
	// RULED: SEED-1 (Letter 48 = (a)) — BESIDE the root, the row's
	// `capabilities=` are seeded as a second self-issued delegation,
	// `runner-caps`, the same principal to itself over exactly those names.
	// Its Tier-1 address is what a binding row names as the run's basis
	// (`authority=cap:…`, flow.md §4.24), so a `[requires cap:…]` step by the
	// root resolves against the seeded store; the deployment host seeds the
	// SAME two values from the same row (xap_flow_seed_src), so the address
	// agrees across faces. A row naming no capability seeds the root alone —
	// byte-identical with the store before SEED-1.
	b << if r.authz != '' {
		t := flow_cli_quote(r.name)
		p := flow_cli_quote(r.authz)
		mut seed := '[= \$az [\$cxauthzstore:store {tenant: "${t}"}]]' +
			'\n[= \$az-root [\$cxauthzstore:delegate \$az [delegation runner-root [tenant "${t}"] [from [principal "${p}"]] [to [principal "${p}"]] [capabilities] [over "/"] [assurance :t1] [signature "runner-authz"]]]]'
		if r.authz_caps.len > 0 {
			cs := r.authz_caps.map('"${flow_cli_quote(it)}"').join(' ')
			seed += '\n[= \$az-caps [\$cxauthzstore:delegate \$az [delegation runner-caps [tenant "${t}"] [from [principal "${p}"]] [to [principal "${p}"]] [capabilities ${cs}] [over "/"] [assurance :t1] [signature "runner-authz"]]]]'
		}
		seed + '\n[= \$o [\$map-put \$o0 "authz" \$az]]'
	} else {
		'[= \$o \$o0]'
	}
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
		b << '[= \$${v} [\$cxflow:rearm \$j [fs--with \$o {env: \$e flow: [\$first [fs--doc-by \$fs "${flow_cli_quote(x.start)}"]] actor: "${flow_cli_quote(x.binder)}" authority: "${flow_cli_quote(x.binder)}"}]]]'
		rearm_parts << '[rearm flow="${flow_cli_quote(x.start)}" rearmed=\$${v}@rearmed skipped=\$${v}@skipped orphaned=\$${v}@orphaned]'
	}
	// RULED: 1411-a — the ingress is SERIAL with the courier: its handler runs
	// only while it holds the program's evaluator turn, which this loop gives
	// up inside its `[?sleep]` and nowhere else. Before this, the handler ran
	// on an executor thread concurrently with a tick, over the per-process
	// capability set (an act admitted with `[effects [write]]` narrowed it
	// under the ingress's journal append → CXER0271) and the journal's store
	// bookkeeping (→ CXER1140) — a valid delivery answered 400 about once in
	// forty under load (#1411, measured).
	b << '[= \$srv [\$cxhttp:serve "tcp://${flow_cli_quote(r.bind)}"' +
		' [?fn (\$req) [fs--ingress \$j \$e \$o \$fs \$bs "${flow_serve_act_path}" \$req]] {serial: true}]]'
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
	// `ticks=` is the BUDGET (`--for` over `every=`) and it carries NO
	// wall-time information: the courier is `:fixed-delay` (RULED: WF-28a),
	// so a turn takes `work + every`. `elapsed-ms=` beside it is the
	// MEASUREMENT, taken on the same clock the occurrence buckets are
	// computed on — `[$time-to-unix-ms [$time-now]]`, exact integer ms,
	// because `[/ …]` is exact-or-CXER3002 and would answer a float here.
	// Every claim about the runner's PERIOD is written against this field;
	// two assertions written against `ticks=` were vacuous, which is what
	// WF-28b retired.
	b << '[= \$w0 [\$time-to-unix-ms [\$time-now]]]'
	b << '[= \$ran [fs--loop \$j \$e \$o \$fs \$bs ${ticks} 0]]'
	b << '[= \$w1 [\$time-to-unix-ms [\$time-now]]]'
	b << '  [runner-stopped ticks=\$ran elapsed-ms=[- \$w1 \$w0] \$rep]]'
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
	// the rest of the store: the documents a `flow=` reference may name (§4.20),
	// carried as data after the bound ones and never as program text — ONE
	// root element, so the driver's selections read the same whatever the
	// store holds (a multi-root data document and a single-root one answer a
	// top-level path differently).
	rest := flow_serve_docs_rest(docs_dir, have)
	mut data := ['[runner-docs [bound']
	data << input
	data << '] [sub-flows'
	data << rest
	data << ']]'
	// The invocation's grants are installed BEFORE the module tree is scanned,
	// as `cx flow validate` and `cx flow run` install them: the scan RESOLVES
	// every `[?lib]` — a `pkg:` package read from its registry, a sibling
	// file — and a deny-by-default process refuses those reads, so a scan run
	// first found no act in an imported module and every step refused CXER4953
	// (cx-home/cx-private#1671).
	flow_cli_install_caps(o)
	directives, acts := flow_cli_env_scan(r.env)
	// RULED: #728 CK-3 — a feature package's projected command defs call its
	// `apply` with the `[store url=]` row's store, so a module tree that loads
	// one and a runner that names no store is refused at boot, naming the
	// package, rather than refusing every projected step at its first act.
	if r.store == '' {
		feats := flow_cli_env_feature_pkgs(r.env)
		if feats.len > 0 {
			flow_serve_refuse('the [runner …] document\'s [env …] loads the feature package ${feats.map('`' + it + '`').join(', ')} and names no [store url=…] — a feature\'s projected command defs call its apply with a store, the slot the XAP host fills with the deployment store (flow.md §4.23, RULED: #728 CK-3)')
		}
	}
	tick_ms := r.courier_ns / 1_000_000
	ticks := if for_ns <= 0 { i64(-1) } else { for_ns / r.courier_ns }
	program := flow_serve_program(r, directives, acts, ticks, if tick_ms < 1 { i64(1) } else { tick_ms })
	println(flow_cli_eval(data.join('\n'), program).trim_space())
	exit(0)
}
