// cfg_proto.v — prototype CFG builder over V's REAL parsed AST (P1 build step 9).
// Uses v.parser.parse_text to get an ast.File, finds a FnDecl, and lowers its
// body to a control-flow graph (structured subset: Block / ExprStmt / AssignStmt
// / Return / Branch / For{,In,C} / IfExpr / MatchExpr). Dumps blocks + edges.
// This validates the P1-CFG-LOWERING.md catalog against the real AST and is the
// substrate the backward last-use pass will run on. Analysis only — no codegen.
import v.ast
import v.parser
import v.pref

struct BB {
mut:
	id       int
	label    string
	steps    []Step // ordered stmt/expr steps with per-step def/use
	succ     []int  // successor block ids
	use      []string // variables read before any def in this block (upward-exposed)
	def      []string // variables assigned in this block
	live_in  []string // liveness fixpoint result
	live_out []string
}

struct Step {
mut:
	desc string
	def  []string
	use  []string
}

fn uniq_push(mut list []string, name string) {
	if name != '' && name !in list {
		list << name
	}
}

// collect_idents extracts variable names read in an expression (the use set).
fn collect_idents(e ast.Expr, mut out []string) {
	match e {
		ast.Ident {
			uniq_push(mut out, e.name)
		}
		ast.InfixExpr {
			collect_idents(e.left, mut out)
			collect_idents(e.right, mut out)
		}
		ast.PrefixExpr {
			collect_idents(e.right, mut out)
		}
		ast.PostfixExpr {
			collect_idents(e.expr, mut out)
		}
		ast.ParExpr {
			collect_idents(e.expr, mut out)
		}
		ast.IndexExpr {
			collect_idents(e.left, mut out)
			collect_idents(e.index, mut out)
		}
		ast.SelectorExpr {
			collect_idents(e.expr, mut out)
		}
		ast.CallExpr {
			collect_idents(e.left, mut out)
			for a in e.args {
				collect_idents(a.expr, mut out)
			}
		}
		else {}
	}
}

// record uses in block b (only if not already defined earlier in the block).
fn (mut c Cfg) use_in(b int, names []string) {
	for n in names {
		if n !in c.blocks[b].def {
			uniq_push(mut c.blocks[b].use, n)
		}
	}
}

fn (mut c Cfg) def_in(b int, name string) {
	uniq_push(mut c.blocks[b].def, name)
}

struct Cfg {
mut:
	blocks      []BB
	exit_id     int
	loop_stack  [][2]int // [header_id, exit_id] for break/continue
	shared_vars []string // possibly-shared (NOT uniquely owned) -> drop falls to GC residual
	returned    []string // values returned from the fn -> ownership transfers to caller, never drop
}

fn (mut c Cfg) mark_shared(name string) {
	uniq_push(mut c.shared_vars, name)
}

// scan_escapes marks variables that stop being uniquely owned: address taken
// (&x), captured by a closure ([x] inherited), or passed into a spawned thread.
// Conservative: when unsure, mark shared (sound — only costs precision).
fn (mut c Cfg) scan_escapes(ex ast.Expr) {
	match ex {
		ast.PrefixExpr {
			if ex.op == .amp && ex.right is ast.Ident {
				c.mark_shared((ex.right as ast.Ident).name) // &x -> x escapes
			}
			c.scan_escapes(ex.right)
		}
		ast.AnonFn {
			for v in ex.inherited_vars {
				c.mark_shared(v.name) // closure capture [x]
			}
		}
		ast.SpawnExpr {
			for a in ex.call_expr.args {
				mut ids := []string{}
				collect_idents(a.expr, mut ids)
				for id in ids {
					c.mark_shared(id) // value handed to another thread
				}
			}
		}
		ast.InfixExpr {
			c.scan_escapes(ex.left)
			c.scan_escapes(ex.right)
		}
		ast.CallExpr {
			for a in ex.args {
				c.scan_escapes(a.expr)
			}
		}
		ast.ParExpr {
			c.scan_escapes(ex.expr)
		}
		ast.IndexExpr {
			c.scan_escapes(ex.left)
			c.scan_escapes(ex.index)
		}
		else {}
	}
}

fn (mut c Cfg) new_block(label string) int {
	id := c.blocks.len
	c.blocks << BB{
		id:    id
		label: label
	}
	return id
}

fn (mut c Cfg) add_edge(from int, to int) {
	if from < 0 || from >= c.blocks.len {
		return
	}
	c.blocks[from].succ << to
}

// emit records one ordered step (with its def/use) AND folds it into the
// block-level use/def sets used by the liveness fixpoint. use_in is called
// before def_in so a compound `s += i` counts s as upward-exposed unless an
// earlier step in the block already defined it.
fn (mut c Cfg) emit(b int, desc string, def []string, use []string) {
	if b < 0 || b >= c.blocks.len {
		return
	}
	c.use_in(b, use)
	for d in def {
		c.def_in(b, d)
	}
	c.blocks[b].steps << Step{
		desc: desc
		def:  def.clone()
		use:  use.clone()
	}
}

// lower a list of statements starting in block `entry`; return the block the
// straight-line flow ends in (may be a dead block after a return/branch).
fn (mut c Cfg) lower_stmts(stmts []ast.Stmt, entry int) int {
	mut cur := entry
	for st in stmts {
		cur = c.lower_stmt(st, cur)
	}
	return cur
}

fn (mut c Cfg) lower_stmt(st ast.Stmt, entry int) int {
	mut cur := entry
	match st {
		ast.Block {
			cur = c.lower_stmts(st.stmts, cur)
		}
		ast.BranchStmt {
			kw := st.kind.str()
			c.emit(cur, kw, [], [])
			if c.loop_stack.len > 0 {
				top := c.loop_stack[c.loop_stack.len - 1]
				// break -> loop exit ; continue -> loop header
				c.add_edge(cur, if kw.contains('break') { top[1] } else { top[0] })
			}
			cur = c.new_block('after-branch(dead)')
		}
		ast.ForStmt {
			header := c.new_block('for.header')
			c.add_edge(cur, header)
			body := c.new_block('for.body')
			exit := c.new_block('for.exit')
			c.add_edge(header, body) // cond true
			c.add_edge(header, exit) // cond false
			c.loop_stack << [header, exit]!
			body_end := c.lower_stmts(st.stmts, body)
			c.add_edge(body_end, header) // back-edge
			c.loop_stack.pop()
			cur = exit
		}
		ast.ForInStmt {
			header := c.new_block('forin.header')
			c.add_edge(cur, header)
			body := c.new_block('forin.body')
			exit := c.new_block('forin.exit')
			c.add_edge(header, body)
			c.add_edge(header, exit)
			c.loop_stack << [header, exit]!
			body_end := c.lower_stmts(st.stmts, body)
			c.add_edge(body_end, header)
			c.loop_stack.pop()
			cur = exit
		}
		ast.ForCStmt {
			if st.has_init {
				cur = c.lower_stmt(st.init, cur) // e.g. `i := 0` (def i, pre-header)
			}
			header := c.new_block('forc.header')
			c.add_edge(cur, header)
			if st.has_cond {
				mut cu := []string{}
				collect_idents(st.cond, mut cu) // `i < n` (use i, n)
				c.emit(header, 'cond', [], cu)
			}
			body := c.new_block('forc.body')
			exit := c.new_block('forc.exit')
			c.add_edge(header, body)
			c.add_edge(header, exit)
			c.loop_stack << [header, exit]!
			mut body_end := c.lower_stmts(st.stmts, body)
			if st.has_inc {
				body_end = c.lower_stmt(st.inc, body_end) // `i++` (use/def i)
			}
			c.add_edge(body_end, header) // back-edge
			c.loop_stack.pop()
			cur = exit
		}
		ast.ExprStmt {
			mut uses := []string{}
			collect_idents(st.expr, mut uses) // e.g. `i++`
			c.emit(cur, st.expr.type_name(), [], uses)
			cur = c.lower_expr(st.expr, cur)
		}
		ast.AssignStmt {
			mut uses := []string{}
			for r in st.right {
				collect_idents(r, mut uses)
			}
			// compound ops (+=, -=, ...) READ the LHS as well as write it
			if st.op != .decl_assign && st.op != .assign {
				for l in st.left {
					collect_idents(l, mut uses)
				}
			}
			mut defs := []string{}
			for l in st.left {
				if l is ast.Ident {
					defs << l.name
				}
			}
			c.emit(cur, 'assign', defs, uses)
			for r in st.right {
				cur = c.lower_expr(r, cur)
			}
		}
		ast.Return {
			mut uses := []string{}
			for e in st.exprs {
				collect_idents(e, mut uses)
				c.scan_escapes(e)
			}
			for u in uses {
				uniq_push(mut c.returned, u) // returned -> ownership transfers, never drop
			}
			c.emit(cur, 'return', [], uses)
			c.add_edge(cur, c.exit_id)
			cur = c.new_block('after-return(dead)')
		}
		else {
			c.emit(cur, st.type_name(), [], [])
		}
	}
	return cur
}

// lower control-flow-bearing expressions; straight-line exprs just annotate.
fn (mut c Cfg) lower_expr(ex ast.Expr, entry int) int {
	mut cur := entry
	c.scan_escapes(ex) // detect &x / closure-capture / spawn escapes
	match ex {
		ast.IfExpr {
			mut cu := []string{}
			for br in ex.branches {
				collect_idents(br.cond, mut cu) // `i % 2 == 0` (use i)
			}
			c.emit(cur, 'if (${ex.branches.len} arms)', [], cu)
			join := c.new_block('if.join')
			for i, br in ex.branches {
				arm := c.new_block('if.arm${i}')
				c.add_edge(cur, arm)
				arm_end := c.lower_stmts(br.stmts, arm)
				c.add_edge(arm_end, join)
			}
			if !ex.has_else {
				c.add_edge(cur, join) // implicit fall-through when no else
			}
			cur = join
		}
		ast.MatchExpr {
			mut cu := []string{}
			collect_idents(ex.cond, mut cu)
			c.emit(cur, 'match (${ex.branches.len} arms)', [], cu)
			join := c.new_block('match.join')
			for i, br in ex.branches {
				arm := c.new_block('match.arm${i}')
				c.add_edge(cur, arm)
				arm_end := c.lower_stmts(br.stmts, arm)
				c.add_edge(arm_end, join)
			}
			cur = join
		}
		else {
			// straight-line expr: already recorded at the statement level
		}
	}
	return cur
}

fn (c &Cfg) dump() {
	println('CFG: ${c.blocks.len} blocks, exit=B${c.exit_id}')
	for b in c.blocks {
		mut succ := []string{}
		for s in b.succ {
			succ << 'B${s}'
		}
		mut descs := []string{}
		for s in b.steps {
			descs << s.desc
		}
		steps := if descs.len > 0 { descs.join('; ') } else { '(empty)' }
		println('  B${b.id} ${b.label:-18} [${steps}] -> ${succ.join(", ")}')
	}
}

fn set_eq(a []string, b []string) bool {
	if a.len != b.len {
		return false
	}
	for v in a {
		if v !in b {
			return false
		}
	}
	return true
}

// Backward liveness to a fixpoint (handles loop back-edges): for each block,
// live_out = U live_in[succ]; live_in = use U (live_out - def). Iterate until
// stable. This is the dataflow the Perceus last-use placement reads.
fn (mut c Cfg) compute_liveness() {
	for _ in 0 .. 10000 {
		mut changed := false
		for i := c.blocks.len - 1; i >= 0; i-- {
			mut new_out := []string{}
			for s in c.blocks[i].succ {
				for v in c.blocks[s].live_in {
					uniq_push(mut new_out, v)
				}
			}
			mut new_in := []string{}
			for v in c.blocks[i].use {
				uniq_push(mut new_in, v)
			}
			for v in new_out {
				if v !in c.blocks[i].def {
					uniq_push(mut new_in, v)
				}
			}
			if !set_eq(new_out, c.blocks[i].live_out) || !set_eq(new_in, c.blocks[i].live_in) {
				changed = true
				c.blocks[i].live_out = new_out
				c.blocks[i].live_in = new_in
			}
		}
		if !changed {
			break
		}
	}
}

// Report last-use / drop sites: a var read in a block but NOT live-out of it
// dies there (its drop goes after the last read). A var that is always live-out
// where it's used is loop-carried -> its drop belongs after the loop exit.
fn (c &Cfg) report_last_use() {
	mut vars := []string{}
	for b in c.blocks {
		for v in b.def {
			uniq_push(mut vars, v)
		}
		for v in b.use {
			uniq_push(mut vars, v)
		}
	}
	println('last-use / drop points (backward liveness):')
	for v in vars {
		mut sites := []string{}
		for b in c.blocks {
			if v in b.use && v !in b.live_out {
				sites << 'B${b.id}(${b.label})'
			}
		}
		if sites.len > 0 {
			println('  ${v:-4}: last read (drop after) at ${sites.join(", ")}')
		} else {
			// No cross-block last-use site. Either loop-carried (live across a
			// back-edge) or defined+last-used within one block (block-granularity
			// liveness can't pinpoint intra-block last-use -> needs a per-stmt
			// pass, the next refinement).
			println('  ${v:-4}: no cross-block last-use (loop-carried OR intra-block; per-stmt pass to pinpoint)')
		}
	}
}

// report_uniqueness: a value is drop-eligible only if it is provably uniquely
// owned. Anything escaped/captured/shared falls to the GC residual (sound).
fn (c &Cfg) report_uniqueness() {
	mut vars := []string{}
	for b in c.blocks {
		for v in b.def {
			uniq_push(mut vars, v)
		}
		for v in b.use {
			uniq_push(mut vars, v)
		}
	}
	println('uniqueness (drop-eligibility):')
	for v in vars {
		if v in c.shared_vars {
			println('  ${v:-4}: SHARED -> GC residual (no deterministic drop)')
		} else if v in c.returned {
			println('  ${v:-4}: returned -> ownership transfers to caller (no drop)')
		} else {
			println('  ${v:-4}: unique -> drop-eligible')
		}
	}
}

// report_drop_placement: per-statement backward walk pinpointing the EXACT step
// after which a `drop` goes (a use that is dead afterward), for values that are
// uniquely owned and not returned. dup would go before a non-last consuming use.
fn (c &Cfg) report_drop_placement() {
	println('dup/drop placement (per-statement; unique & non-returned only):')
	mut any := false
	for b in c.blocks {
		mut live := b.live_out.clone()
		for i := b.steps.len - 1; i >= 0; i-- {
			st := b.steps[i]
			for u in st.use {
				if u !in live {
					// dead after this step => this is u's last read
					if u in c.shared_vars || u in c.returned {
						// no deterministic drop (GC residual / transferred out)
					} else {
						println('  drop ${u} after B${b.id}.step${i} "${st.desc}" (last read)')
						any = true
					}
				}
			}
			// a value defined then never read (and dead after) drops right after def
			for d in st.def {
				if d !in st.use && d !in live && d !in c.shared_vars && d !in c.returned {
					println('  drop ${d} after B${b.id}.step${i} "${st.desc}" (dead store)')
					any = true
				}
			}
			// backward transfer: live_before = (live - def) + use
			mut nl := []string{}
			for v in live {
				if v !in st.def {
					nl << v
				}
			}
			for u in st.use {
				uniq_push(mut nl, u)
			}
			live = nl.clone()
		}
	}
	if !any {
		println('  (no deterministic drops on these samples — all unique values are returned/value-typed)')
	}
}

const sample_src = 'module m
fn sample(n int) int {
	mut s := 0
	for i := 0; i < n; i++ {
		if i % 2 == 0 {
			s += i
		} else {
			s -= 1
		}
	}
	return s
}'

// second sample: exercises every escape kind so the classifier is visible.
const esc_src = 'module m
fn esc(n int) int {
	mut uniq := 0
	uniq = uniq + 1
	mut a := 0
	pa := &a
	mut cap := 5
	f := fn [cap] () int { return cap }
	spawn sink(n)
	return uniq
}'

fn analyze(src string, fnsubstr string) bool {
	mut p := &pref.Preferences{}
	mut tbl := ast.new_table()
	file := parser.parse_text(src, 'sample.v', mut tbl, .skip_comments, p)
	mut found := false
	for stmt in file.stmts {
		if stmt is ast.FnDecl {
			if stmt.name.contains(fnsubstr) {
				found = true
				mut c := Cfg{}
				entry := c.new_block('entry')
				c.exit_id = c.new_block('EXIT')
				last := c.lower_stmts(stmt.stmts, entry)
				c.add_edge(last, c.exit_id)
				c.compute_liveness()
				println('=== fn ${stmt.name} ===')
				c.dump()
				c.report_last_use()
				c.report_uniqueness()
				c.report_drop_placement()
				println('')
			}
		}
	}
	return found
}

// third sample: a unique heap value used then dropped (not returned).
const drop_src = 'module m
fn use_then_drop(n int) int {
	buf := [1, 2, 3]
	x := buf[0] + buf[1]
	return x + n
}'

fn main() {
	ok1 := analyze(sample_src, 'sample')
	ok2 := analyze(esc_src, 'esc')
	ok3 := analyze(drop_src, 'use_then_drop')
	if !ok1 || !ok2 || !ok3 {
		eprintln('FAIL: a sample fn was not found in the parsed AST')
		exit(1)
	}
}
