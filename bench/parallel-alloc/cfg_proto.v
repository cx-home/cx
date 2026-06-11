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
	id    int
	label string
	steps []string // human-readable stmt/expr descriptions
	succ  []int     // successor block ids
}

struct Cfg {
mut:
	blocks     []BB
	exit_id    int
	loop_stack [][2]int // [header_id, exit_id] for break/continue
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

fn (mut c Cfg) step(b int, s string) {
	if b >= 0 && b < c.blocks.len {
		c.blocks[b].steps << s
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
		ast.Return {
			c.step(cur, 'return')
			c.add_edge(cur, c.exit_id)
			cur = c.new_block('after-return(dead)')
		}
		ast.BranchStmt {
			kw := st.kind.str()
			c.step(cur, kw)
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
			header := c.new_block('forc.header')
			c.add_edge(cur, header)
			body := c.new_block('forc.body')
			exit := c.new_block('forc.exit')
			c.add_edge(header, body)
			c.add_edge(header, exit)
			c.loop_stack << [header, exit]!
			body_end := c.lower_stmts(st.stmts, body)
			c.add_edge(body_end, header)
			c.loop_stack.pop()
			cur = exit
		}
		ast.ExprStmt {
			cur = c.lower_expr(st.expr, cur)
		}
		ast.AssignStmt {
			c.step(cur, 'assign')
			// RHS may embed branch exprs
			for r in st.right {
				cur = c.lower_expr(r, cur)
			}
		}
		else {
			c.step(cur, st.type_name())
		}
	}
	return cur
}

// lower control-flow-bearing expressions; straight-line exprs just annotate.
fn (mut c Cfg) lower_expr(ex ast.Expr, entry int) int {
	mut cur := entry
	match ex {
		ast.IfExpr {
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
			c.step(cur, 'if (${ex.branches.len} arms)')
			cur = join
		}
		ast.MatchExpr {
			join := c.new_block('match.join')
			for i, br in ex.branches {
				arm := c.new_block('match.arm${i}')
				c.add_edge(cur, arm)
				arm_end := c.lower_stmts(br.stmts, arm)
				c.add_edge(arm_end, join)
			}
			c.step(cur, 'match (${ex.branches.len} arms)')
			cur = join
		}
		else {
			c.step(cur, ex.type_name())
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
		steps := if b.steps.len > 0 { b.steps.join('; ') } else { '(empty)' }
		println('  B${b.id} ${b.label:-18} [${steps}] -> ${succ.join(", ")}')
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

fn main() {
	mut p := &pref.Preferences{}
	mut tbl := ast.new_table()
	file := parser.parse_text(sample_src, 'sample.v', mut tbl, .skip_comments, p)
	mut found := false
	for stmt in file.stmts {
		if stmt is ast.FnDecl {
			fnd := stmt as ast.FnDecl
			if fnd.name.contains('sample') {
				found = true
				mut c := Cfg{}
				entry := c.new_block('entry')
				c.exit_id = c.new_block('EXIT')
				last := c.lower_stmts(fnd.stmts, entry)
				c.add_edge(last, c.exit_id) // fall-through to exit
				println('built CFG for fn ${fnd.name}:')
				c.dump()
			}
		}
	}
	if !found {
		eprintln('FAIL: sample fn not found in parsed AST')
		exit(1)
	}
}
