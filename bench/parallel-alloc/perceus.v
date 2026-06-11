// perceus.v — compiler-resident Perceus drop-placement analysis (P1).
// Ported from the validated prototype (cx-private bench/parallel-alloc/cfg_proto.v):
// builds a per-function CFG over V's AST, runs backward liveness to a fixpoint,
// classifies uniqueness (escape/capture/spawn), and returns a DROP MAP keyed by
// statement position: stmt.pos -> the unique, non-returned values whose last
// read is at/within that statement (so a `drop` goes right after it).
//
// Analysis-only: it computes WHERE drops would go; emission is wired separately,
// behind `-d perceus`, gated by G-DIFF/G-LEAK. All symbols are `pcs_`/`Pcs`
// prefixed to avoid collisions in the large `c` (cgen) module. Coverage is the
// structured subset (Block/Assign/If/Match/For{,In,C}/Return/Branch/ExprStmt);
// unhandled nodes fall back to the GC residual (sound).
module c

import v.ast

struct PcsStep {
mut:
	pos int      // originating stmt.pos.pos (drop insertion key)
	def []string
	use []string
}

struct PcsBB {
mut:
	succ     []int
	steps    []PcsStep
	use      []string
	def      []string
	live_in  []string
	live_out []string
}

struct PcsCfg {
mut:
	blocks      []PcsBB
	exit_id     int
	loop_stack  [][2]int
	shared_vars []string
	returned    []string
	heap_vars   []string // locally-defined, heap-owning (array/map/string/has free()) -> the only drop candidates
	table       &ast.Table = unsafe { nil }
}

// heap-owning predicate, mirroring autofree_variable's dispatch: only these
// kinds carry a heap allocation worth a deterministic drop. Params (never
// assigned) and value types (int/bool/struct-without-free) are excluded.
fn (c &PcsCfg) pcs_is_heap_owning(typ ast.Type) bool {
	if c.table == unsafe { nil } || typ == 0 {
		return false
	}
	sym := c.table.sym(typ)
	if sym.kind in [ast.Kind.array, .map, .string] {
		return true
	}
	return sym.has_method('free')
}

fn pcs_uniq_push(mut list []string, name string) {
	if name != '' && name !in list {
		list << name
	}
}

fn pcs_set_eq(a []string, b []string) bool {
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

fn pcs_collect(e ast.Expr, mut out []string) {
	match e {
		ast.Ident { pcs_uniq_push(mut out, e.name) }
		ast.InfixExpr {
			pcs_collect(e.left, mut out)
			pcs_collect(e.right, mut out)
		}
		ast.PrefixExpr { pcs_collect(e.right, mut out) }
		ast.PostfixExpr { pcs_collect(e.expr, mut out) }
		ast.ParExpr { pcs_collect(e.expr, mut out) }
		ast.IndexExpr {
			pcs_collect(e.left, mut out)
			pcs_collect(e.index, mut out)
		}
		ast.SelectorExpr { pcs_collect(e.expr, mut out) }
		ast.CallExpr {
			pcs_collect(e.left, mut out)
			for a in e.args {
				pcs_collect(a.expr, mut out)
			}
		}
		else {}
	}
}

fn (mut c PcsCfg) pcs_nb() int {
	id := c.blocks.len
	c.blocks << PcsBB{}
	return id
}

fn (mut c PcsCfg) pcs_edge(from int, to int) {
	if from >= 0 && from < c.blocks.len {
		c.blocks[from].succ << to
	}
}

fn (mut c PcsCfg) pcs_emit(b int, pos int, def []string, use []string) {
	if b < 0 || b >= c.blocks.len {
		return
	}
	for u in use {
		if u !in c.blocks[b].def {
			pcs_uniq_push(mut c.blocks[b].use, u)
		}
	}
	for d in def {
		pcs_uniq_push(mut c.blocks[b].def, d)
	}
	c.blocks[b].steps << PcsStep{
		pos: pos
		def: def.clone()
		use: use.clone()
	}
}

fn (mut c PcsCfg) pcs_mark_shared(name string) {
	pcs_uniq_push(mut c.shared_vars, name)
}

fn (mut c PcsCfg) pcs_escapes(e ast.Expr) {
	match e {
		ast.PrefixExpr {
			if e.op == .amp && e.right is ast.Ident {
				c.pcs_mark_shared((e.right as ast.Ident).name)
			}
			c.pcs_escapes(e.right)
		}
		ast.AnonFn {
			for v in e.inherited_vars {
				c.pcs_mark_shared(v.name)
			}
		}
		ast.SpawnExpr {
			for a in e.call_expr.args {
				mut ids := []string{}
				pcs_collect(a.expr, mut ids)
				for id in ids {
					c.pcs_mark_shared(id)
				}
			}
		}
		ast.InfixExpr {
			c.pcs_escapes(e.left)
			c.pcs_escapes(e.right)
		}
		ast.CallExpr {
			for a in e.args {
				c.pcs_escapes(a.expr)
			}
		}
		ast.ParExpr { c.pcs_escapes(e.expr) }
		ast.IndexExpr {
			c.pcs_escapes(e.left)
			c.pcs_escapes(e.index)
		}
		else {}
	}
}

fn (mut c PcsCfg) pcs_lower_stmts(stmts []ast.Stmt, entry int) int {
	mut cur := entry
	for st in stmts {
		cur = c.pcs_lower_stmt(st, cur)
	}
	return cur
}

fn (mut c PcsCfg) pcs_lower_stmt(st ast.Stmt, entry int) int {
	mut cur := entry
	match st {
		ast.Block {
			cur = c.pcs_lower_stmts(st.stmts, cur)
		}
		ast.BranchStmt {
			if c.loop_stack.len > 0 {
				top := c.loop_stack[c.loop_stack.len - 1]
				c.pcs_edge(cur, if st.kind.str().contains('break') { top[1] } else { top[0] })
			}
			cur = c.pcs_nb()
		}
		ast.ForStmt {
			header := c.pcs_nb()
			c.pcs_edge(cur, header)
			body := c.pcs_nb()
			exit := c.pcs_nb()
			c.pcs_edge(header, body)
			c.pcs_edge(header, exit)
			c.loop_stack << [header, exit]!
			be := c.pcs_lower_stmts(st.stmts, body)
			c.pcs_edge(be, header)
			c.loop_stack.pop()
			cur = exit
		}
		ast.ForInStmt {
			header := c.pcs_nb()
			c.pcs_edge(cur, header)
			body := c.pcs_nb()
			exit := c.pcs_nb()
			c.pcs_edge(header, body)
			c.pcs_edge(header, exit)
			c.loop_stack << [header, exit]!
			be := c.pcs_lower_stmts(st.stmts, body)
			c.pcs_edge(be, header)
			c.loop_stack.pop()
			cur = exit
		}
		ast.ForCStmt {
			if st.has_init {
				cur = c.pcs_lower_stmt(st.init, cur)
			}
			header := c.pcs_nb()
			c.pcs_edge(cur, header)
			if st.has_cond {
				mut cu := []string{}
				pcs_collect(st.cond, mut cu)
				c.pcs_emit(header, st.pos.pos, [], cu)
			}
			body := c.pcs_nb()
			exit := c.pcs_nb()
			c.pcs_edge(header, body)
			c.pcs_edge(header, exit)
			c.loop_stack << [header, exit]!
			mut be := c.pcs_lower_stmts(st.stmts, body)
			if st.has_inc {
				be = c.pcs_lower_stmt(st.inc, be)
			}
			c.pcs_edge(be, header)
			c.loop_stack.pop()
			cur = exit
		}
		ast.ExprStmt {
			mut uses := []string{}
			pcs_collect(st.expr, mut uses)
			c.pcs_emit(cur, st.pos.pos, [], uses)
			cur = c.pcs_lower_expr(st.expr, cur)
		}
		ast.AssignStmt {
			mut uses := []string{}
			for r in st.right {
				pcs_collect(r, mut uses)
			}
			if st.op != .decl_assign && st.op != .assign {
				for l in st.left {
					pcs_collect(l, mut uses)
				}
			}
			mut defs := []string{}
			for i, l in st.left {
				if l is ast.Ident {
					defs << l.name
					// record heap-owning locals (the only drop candidates)
					if i < st.left_types.len && c.pcs_is_heap_owning(st.left_types[i]) {
						pcs_uniq_push(mut c.heap_vars, l.name)
					}
				}
			}
			c.pcs_emit(cur, st.pos.pos, defs, uses)
			for r in st.right {
				cur = c.pcs_lower_expr(r, cur)
			}
		}
		ast.Return {
			mut uses := []string{}
			for e in st.exprs {
				pcs_collect(e, mut uses)
				c.pcs_escapes(e)
			}
			for u in uses {
				pcs_uniq_push(mut c.returned, u)
			}
			c.pcs_emit(cur, st.pos.pos, [], uses)
			c.pcs_edge(cur, c.exit_id)
			cur = c.pcs_nb()
		}
		else {}
	}
	return cur
}

fn (mut c PcsCfg) pcs_lower_expr(ex ast.Expr, entry int) int {
	mut cur := entry
	c.pcs_escapes(ex)
	match ex {
		ast.IfExpr {
			mut cu := []string{}
			for br in ex.branches {
				pcs_collect(br.cond, mut cu)
			}
			c.pcs_emit(cur, ex.pos.pos, [], cu)
			join := c.pcs_nb()
			for br in ex.branches {
				arm := c.pcs_nb()
				c.pcs_edge(cur, arm)
				ae := c.pcs_lower_stmts(br.stmts, arm)
				c.pcs_edge(ae, join)
			}
			if !ex.has_else {
				c.pcs_edge(cur, join)
			}
			cur = join
		}
		ast.MatchExpr {
			mut cu := []string{}
			pcs_collect(ex.cond, mut cu)
			c.pcs_emit(cur, ex.pos.pos, [], cu)
			join := c.pcs_nb()
			for br in ex.branches {
				arm := c.pcs_nb()
				c.pcs_edge(cur, arm)
				ae := c.pcs_lower_stmts(br.stmts, arm)
				c.pcs_edge(ae, join)
			}
			cur = join
		}
		else {}
	}
	return cur
}

fn (mut c PcsCfg) pcs_liveness() {
	for _ in 0 .. 10000 {
		mut changed := false
		for i := c.blocks.len - 1; i >= 0; i-- {
			mut new_out := []string{}
			for s in c.blocks[i].succ {
				for v in c.blocks[s].live_in {
					pcs_uniq_push(mut new_out, v)
				}
			}
			mut new_in := []string{}
			for v in c.blocks[i].use {
				pcs_uniq_push(mut new_in, v)
			}
			for v in new_out {
				if v !in c.blocks[i].def {
					pcs_uniq_push(mut new_in, v)
				}
			}
			if !pcs_set_eq(new_out, c.blocks[i].live_out)
				|| !pcs_set_eq(new_in, c.blocks[i].live_in) {
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

// pcs_drop_map: per-statement backward walk -> stmt.pos -> drop-eligible vars
// (unique, non-returned) whose last read is at that step.
fn (c &PcsCfg) pcs_drop_map() map[int][]string {
	mut dm := map[int][]string{}
	for b in c.blocks {
		mut live := b.live_out.clone()
		for i := b.steps.len - 1; i >= 0; i-- {
			st := b.steps[i]
			for u in st.use {
				if u in c.heap_vars && u !in live && u !in c.shared_vars && u !in c.returned {
					dm[st.pos] << u
				}
			}
			for d in st.def {
				if d in c.heap_vars && d !in st.use && d !in live && d !in c.shared_vars
					&& d !in c.returned {
					dm[st.pos] << d
				}
			}
			mut nl := []string{}
			for v in live {
				if v !in st.def {
					nl << v
				}
			}
			for u in st.use {
				pcs_uniq_push(mut nl, u)
			}
			live = nl.clone()
		}
	}
	return dm
}

// compute_drop_map is the public entry used by cgen under `-d perceus`.
pub fn compute_drop_map(fnd ast.FnDecl, mut table ast.Table) map[int][]string {
	mut c := PcsCfg{
		table: table
	}
	entry := c.pcs_nb()
	c.exit_id = c.pcs_nb()
	last := c.pcs_lower_stmts(fnd.stmts, entry)
	c.pcs_edge(last, c.exit_id)
	c.pcs_liveness()
	return c.pcs_drop_map()
}
