// idioms.go — v0.8.0 Layer-2 Go idioms over the Layer-1 surface.
//
// Per `spec/bindings.md` §3.1-§3.2, Layer 2 wraps Layer 1 with
// host-idiomatic conveniences. Every Layer-2 expression has a
// **single, documented** Layer-1 desugaring; `Explain(op, args...)`
// returns it as a string for fixtures + LSP hovers.
//
// The Go idioms surfaced here mirror `spec/bindings.md §3.2`:
//
//   * **Builder filter chains** — `doc.Filter("user").Where("= $_@active true").Get("/@email")`
//     desugars to `doc.SelectAll("//user[= $_@active true]/@email")`.
//   * **Pythonic-like Doc methods** — `Doc.Eval` / `Doc.Diagram` /
//     `Doc.Tree` are already on Layer-1; Layer-2 adds the chainable
//     filter builder + a `Select(path)` convenience returning
//     `[]CodeNode`.
//
// Layer 2 is **opt-in sugar**; the conformance contract lives in
// Layer 1. Tests treat the desugaring as normative.

package cxlib

import (
	"fmt"
	"strings"
)

// ── Filter / builder chain ──────────────────────────────────────────────────

// Filter is a chainable CXPath builder rooted at a Doc. Every chain
// node holds the partial CXPath string built so far. The terminal
// `Get(rest)` / `All()` / `First()` calls fold the chain back into
// a Layer-1 `SelectAll` call.
//
// Desugaring rules (per `spec/bindings.md §3.2`):
//
//	doc.Filter("user")                          ⇒ doc.SelectAll("//user")
//	doc.Filter("user").Where("= $_@active true") ⇒ doc.SelectAll("//user[= $_@active true]")
//	doc.Filter("user").Where(...).Get("/@email") ⇒ doc.SelectAll("//user[= $_@active true]/@email")
//	doc.Filter("user").First()                  ⇒ doc.Select("//user")
//	doc.Filter("user").All()                    ⇒ doc.SelectAll("//user")
//
// The builder is value-typed (chain methods return Filter, not
// *Filter) so a fluent expression never accidentally mutates an
// intermediate.
type Filter struct {
	doc  Doc
	path string
}

// Filter starts a builder chain rooted at `//name`. Chain it with
// `Where`, `Get`, or `All` / `First` to resolve.
func (d Doc) Filter(name string) Filter {
	return Filter{doc: d, path: "//" + name}
}

// Where appends a predicate `[expr]` to the running path. The
// caller-supplied expression is embedded verbatim; quoting is the
// caller's responsibility (matches Layer-1 `SelectAll` which also
// passes the path through to libcx verbatim).
func (f Filter) Where(expr string) Filter {
	return Filter{doc: f.doc, path: f.path + "[" + expr + "]"}
}

// Get appends a relative path tail (typically `/@attr` or `/child`)
// and resolves to the matching nodes / scalar values.
func (f Filter) Get(rest string) ([]CodeNode, error) {
	return f.doc.SelectAll(f.path + rest)
}

// All resolves the chain via Layer-1 `SelectAll`.
func (f Filter) All() ([]CodeNode, error) {
	return f.doc.SelectAll(f.path)
}

// First resolves the chain via Layer-1 `Select` (first match or nil).
func (f Filter) First() (*CodeNode, error) {
	return f.doc.Select(f.path)
}

// Path returns the CXPath string the chain has accumulated. Useful
// for `Explain` / fixtures.
func (f Filter) Path() string { return f.path }

// ── Doc convenience — `Select` returning []CodeNode ─────────────────────────
//
// Layer 1 names `select_all` for the sequence form and `select` for
// the singular form. The brief asks for a Go-idiomatic
// `Select(path) []Node`-shaped helper; we already have `SelectAll`
// from Layer-1, so the Layer-2 add here is just a `MustSelectAll`
// panic-on-error variant suited to LINQ-style chains and tests.

// MustSelectAll is `SelectAll` that panics on error — convenient in
// tests and Go programs that treat CXPath errors as bugs. Layer-2
// only; Layer-1 always returns `(value, error)`.
func (d Doc) MustSelectAll(cxpath string) []CodeNode {
	out, err := d.SelectAll(cxpath)
	if err != nil {
		panic(fmt.Errorf("MustSelectAll(%q): %w", cxpath, err))
	}
	return out
}

// MustSelect is `Select` that panics on error.
func (d Doc) MustSelect(cxpath string) *CodeNode {
	out, err := d.Select(cxpath)
	if err != nil {
		panic(fmt.Errorf("MustSelect(%q): %w", cxpath, err))
	}
	return out
}

// ── Explain — read back the Layer-1 desugaring ──────────────────────────────
//
// Per `spec/bindings.md §3.1`: `Explain(op, args...)` returns the
// equivalent Layer-1 call for any Layer-2 expression. Used by
// fixtures + LSP hovers; the desugarings are normative.

// Explain returns the Layer-1 desugaring string for a Layer-2 op.
//
// Supported ops + arg shapes:
//
//	Explain("filter", "user")                          → doc.SelectAll("//user")
//	Explain("filter+where", "user", "= $_@active true") → doc.SelectAll("//user[= $_@active true]")
//	Explain("filter+where+get", "user", "= $_@active true", "/@email")
//	                                                    → doc.SelectAll("//user[= $_@active true]/@email")
//	Explain("filter+first", "user")                    → doc.Select("//user")
//	Explain("must_select_all", "//user")               → doc.SelectAll("//user")  (panics on err)
//	Explain("must_select", "//user")                   → doc.Select("//user")     (panics on err)
//
// Unknown ops raise a non-nil error rather than panic so callers
// (LSP / fixture runner) can degrade gracefully.
func Explain(op string, args ...string) (string, error) {
	switch op {
	case "filter":
		if len(args) != 1 {
			return "", fmt.Errorf("Explain(%q): want 1 arg (name), got %d", op, len(args))
		}
		return fmt.Sprintf("doc.SelectAll(%q)", "//"+args[0]), nil
	case "filter+where":
		if len(args) != 2 {
			return "", fmt.Errorf("Explain(%q): want 2 args (name, predicate), got %d", op, len(args))
		}
		return fmt.Sprintf("doc.SelectAll(%q)", "//"+args[0]+"["+args[1]+"]"), nil
	case "filter+where+get":
		if len(args) != 3 {
			return "", fmt.Errorf("Explain(%q): want 3 args (name, predicate, rest), got %d", op, len(args))
		}
		return fmt.Sprintf("doc.SelectAll(%q)", "//"+args[0]+"["+args[1]+"]"+args[2]), nil
	case "filter+first":
		if len(args) != 1 {
			return "", fmt.Errorf("Explain(%q): want 1 arg (name), got %d", op, len(args))
		}
		return fmt.Sprintf("doc.Select(%q)", "//"+args[0]), nil
	case "must_select_all":
		if len(args) != 1 {
			return "", fmt.Errorf("Explain(%q): want 1 arg (cxpath), got %d", op, len(args))
		}
		return fmt.Sprintf("doc.SelectAll(%q)", args[0]), nil
	case "must_select":
		if len(args) != 1 {
			return "", fmt.Errorf("Explain(%q): want 1 arg (cxpath), got %d", op, len(args))
		}
		return fmt.Sprintf("doc.Select(%q)", args[0]), nil
	}
	return "", fmt.Errorf("Explain: unknown Layer-2 op %q", op)
}

// formatModifyValue renders a Go value as CX literal text for “:set V“
// actions in Layer-2 sugar. Mirrors the Python `_format_value` helper
// in `cxlib/idioms.py` — supports nil / bool / numeric / string;
// richer shapes drop down to Layer-1 `Doc.Modify(focus, action)`.
// Exported (lower-case f keeps it internal) intentionally — the
// Layer-2 idiom contract is in `Explain`; this helper is for the
// rare builder paths that need to embed a literal.
func formatModifyValue(value any) (string, error) {
	if value == nil {
		return "null", nil
	}
	switch v := value.(type) {
	case bool:
		if v {
			return "true", nil
		}
		return "false", nil
	case int:
		return fmt.Sprintf("%d", v), nil
	case int64:
		return fmt.Sprintf("%d", v), nil
	case float64:
		return fmt.Sprintf("%g", v), nil
	case string:
		escaped := strings.ReplaceAll(v, "\\", "\\\\")
		escaped = strings.ReplaceAll(escaped, `"`, `\"`)
		return `"` + escaped + `"`, nil
	}
	return "", fmt.Errorf(
		"cxlib.idioms: unsupported value type %T for '[set]' — "+
			"Layer-2 sugar supports nil/bool/int/float/string only. "+
			"Drop down to Layer-1 Doc.Modify(focus, action) for richer shapes",
		value)
}

// Set is a Layer-2 builder that produces a Layer-1 `[set V]` action
// clause from a Go value. Desugaring:
//
//	doc.Modify(focus, Set("Alice"))   ≡  doc.Modify(focus, `[set "Alice"]`)
//	doc.Modify(focus, Set(42))        ≡  doc.Modify(focus, `[set 42]`)
//
// Returns an error rather than panicking on unsupported types so
// callers can fall back to Layer-1 `Doc.Modify` with a hand-rolled
// action string.
func Set(value any) (string, error) {
	v, err := formatModifyValue(value)
	if err != nil {
		return "", err
	}
	return "[set " + v + "]", nil
}

// Delete is a Layer-2 constant for the `[delete]` action.
func Delete() string { return "[delete]" }

// Rename is a Layer-2 builder for the `[rename N]` action.
func Rename(name string) string { return "[rename " + name + "]" }
