// Binding-API parity driver — Go.
//
// Reads one JSON fixture object on stdin (see
// scripts/compile_binding_api_fixtures.cx) and executes it through the
// Layer-1 surface in lang/go/cxlib.
//
// Output protocol matches lang/python/cmd/binding_api_driver.py.
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"regexp"
	"strconv"
	"strings"

	cxlib "github.com/cx-home/cx/lang/go"
)

// ── op-tree types ────────────────────────────────────────────────────────────

type op struct {
	Kind     string    `json:"kind"`
	Value    any       `json:"value,omitempty"`
	Name     string    `json:"name,omitempty"`
	Method   string    `json:"method,omitempty"`
	Target   *op       `json:"target,omitempty"`
	Args     []op      `json:"args,omitempty"`
	Source   string    `json:"source,omitempty"`
	Left     *op       `json:"left,omitempty"`
	Right    *op       `json:"right,omitempty"`
	Body     *op       `json:"body,omitempty"`
	Bindings []binding `json:"bindings,omitempty"`
	Result   string    `json:"result,omitempty"`
}

type binding struct {
	Name string `json:"name"`
	Op   op     `json:"op"`
}

type lambdaCx struct{ src string }

type fixture struct {
	ID          string  `json:"id"`
	InCx        string  `json:"in_cx"`
	Ops         *op     `json:"ops"`
	Unsupported *string `json:"unsupported"`
}

// ── result tagging ───────────────────────────────────────────────────────────

type raw struct{ s string }
type action struct {
	name string
	args []any
}
type evalErr struct{ code string }

func (e evalErr) Error() string { return e.code }

var cxerRe = regexp.MustCompile(`CXER\d{4}`)

func extractCode(msg string) string {
	if m := cxerRe.FindString(msg); m != "" {
		return m
	}
	return "UNKNOWN-ERROR"
}

// ── rendering ────────────────────────────────────────────────────────────────

func renderString(s string) string {
	s = strings.ReplaceAll(s, `\`, `\\`)
	s = strings.ReplaceAll(s, `"`, `\"`)
	return `"` + s + `"`
}

func renderValue(v any) string {
	switch x := v.(type) {
	case nil:
		return "()"
	case raw:
		return x.s
	case bool:
		if x {
			return "true"
		}
		return "false"
	case int:
		return strconv.Itoa(x)
	case int64:
		return strconv.FormatInt(x, 10)
	case float64:
		if x == float64(int64(x)) {
			return strconv.FormatInt(int64(x), 10)
		}
		return strconv.FormatFloat(x, 'g', -1, 64)
	case string:
		return renderString(x)
	case cxlib.CodeNode:
		return renderNode(x)
	case *cxlib.CodeNode:
		if x == nil {
			return "()"
		}
		return renderNode(*x)
	case cxlib.Doc:
		return strings.TrimRight(string(x.Bytes()), "\n")
	case []cxlib.CodeNode:
		parts := make([]string, len(x))
		for i, n := range x {
			parts[i] = renderNode(n)
		}
		return strings.Join(parts, "\n")
	case map[string]any:
		keys := make([]string, 0, len(x))
		for k := range x {
			keys = append(keys, k)
		}
		sortStrings(keys)
		parts := make([]string, 0, len(keys))
		for _, k := range keys {
			parts = append(parts, fmt.Sprintf("%s: %s", k, renderValue(x[k])))
		}
		return "{" + strings.Join(parts, ", ") + "}"
	case []any:
		parts := make([]string, len(x))
		for i, v := range x {
			parts[i] = renderValue(v)
		}
		return strings.Join(parts, "\n")
	}
	return fmt.Sprintf("%v", v)
}

func sortStrings(s []string) {
	for i := 1; i < len(s); i++ {
		j := i
		for j > 0 && s[j-1] > s[j] {
			s[j-1], s[j] = s[j], s[j-1]
			j--
		}
	}
}

func renderNode(n cxlib.CodeNode) string {
	el := n.Element()
	if el == nil {
		return "()"
	}
	doc := &cxlib.Document{Elements: []cxlib.Node{el}}
	return strings.TrimRight(doc.ToCx(), "\n")
}

var actionKw = map[string]string{
	"Set":          "set",
	"Delete":       "delete",
	"Rename":       "rename",
	"SetAttr":      "set-attr",
	"DeleteAttr":   "delete-attr",
	"Append":       "append",
	"Prepend":      "prepend",
	"InsertBefore": "insert-before",
	"InsertAfter":  "insert-after",
	"Replace":      "replace",
	"Using":        "using",
}

func isIdent(s string) bool {
	if s == "" {
		return false
	}
	for _, r := range s {
		if !(r == '_' || (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9')) {
			return false
		}
	}
	return true
}

func renderAction(act action) string {
	kw, ok := actionKw[act.name]
	if !ok {
		kw = strings.ToLower(act.name)
	}
	parts := []string{"[" + kw}
	for _, a := range act.args {
		switch x := a.(type) {
		case lambdaCx:
			parts = append(parts, x.src)
		case string:
			if kw == "rename" && isIdent(x) {
				parts = append(parts, x)
			} else if (kw == "append" || kw == "prepend" || kw == "insert-before" || kw == "insert-after" || kw == "replace") && strings.HasPrefix(x, "[") {
				parts = append(parts, x)
			} else {
				parts = append(parts, renderString(x))
			}
		case bool:
			if x {
				parts = append(parts, "true")
			} else {
				parts = append(parts, "false")
			}
		case int:
			parts = append(parts, strconv.Itoa(x))
		case int64:
			parts = append(parts, strconv.FormatInt(x, 10))
		case float64:
			if x == float64(int64(x)) {
				parts = append(parts, strconv.FormatInt(int64(x), 10))
			} else {
				parts = append(parts, strconv.FormatFloat(x, 'g', -1, 64))
			}
		default:
			parts = append(parts, fmt.Sprintf("%v", x))
		}
	}
	return strings.Join(parts, " ") + "]"
}

func evaluate(o *op, doc *cxlib.Doc, env map[string]any) (any, error) {
	switch o.Kind {
	case "doc_ref":
		if doc == nil {
			return nil, evalErr{"CXER0100"}
		}
		return *doc, nil
	case "str":
		return o.Value.(string), nil
	case "num":
		s := o.Value.(string)
		if strings.Contains(s, ".") {
			f, err := strconv.ParseFloat(s, 64)
			if err != nil {
				return nil, evalErr{"CXER0100"}
			}
			return f, nil
		}
		i, err := strconv.ParseInt(s, 10, 64)
		if err != nil {
			return nil, evalErr{"CXER0100"}
		}
		return i, nil
	case "bool":
		return o.Value.(bool), nil
	case "action":
		args := make([]any, 0, len(o.Args))
		for i := range o.Args {
			v, err := evaluate(&o.Args[i], doc, env)
			if err != nil {
				return nil, err
			}
			args = append(args, v)
		}
		return action{name: o.Name, args: args}, nil
	case "lambda_cx":
		return lambdaCx{src: o.Source}, nil
	case "method":
		t, err := evaluate(o.Target, doc, env)
		if err != nil {
			return nil, err
		}
		args := make([]any, 0, len(o.Args))
		for i := range o.Args {
			v, err := evaluate(&o.Args[i], doc, env)
			if err != nil {
				return nil, err
			}
			args = append(args, v)
		}
		return dispatch(t, o.Method, args)
	case "var":
		if env == nil {
			return nil, evalErr{"UNDEFINED-VAR"}
		}
		v, ok := env[o.Name]
		if !ok {
			return nil, evalErr{"UNDEFINED-VAR-" + o.Name}
		}
		return v, nil
	case "eq":
		lhs, err := evaluate(o.Left, doc, env)
		if err != nil {
			return nil, err
		}
		rhs, err := evaluate(o.Right, doc, env)
		if err != nil {
			return nil, err
		}
		return eqValues(lhs, rhs), nil
	case "block":
		blockEnv := make(map[string]any, len(o.Bindings))
		for k, v := range env {
			blockEnv[k] = v
		}
		for i := range o.Bindings {
			b := &o.Bindings[i]
			v, err := evaluate(&b.Op, doc, blockEnv)
			if err != nil {
				return nil, err
			}
			blockEnv[b.Name] = v
		}
		return blockEnv[o.Result], nil
	case "spawn":
		// Run body in fresh goroutine; channel back the result.
		type res struct {
			v any
			e error
		}
		ch := make(chan res, 1)
		go func() {
			defer func() {
				if r := recover(); r != nil {
					ch <- res{nil, evalErr{"UNKNOWN-ERROR"}}
				}
			}()
			v, e := evaluate(o.Body, doc, env)
			ch <- res{v, e}
		}()
		r := <-ch
		return r.v, r.e
	}
	return nil, evalErr{"UNKNOWN-OP"}
}

func eqValues(a, b any) bool {
	// Unwrap raw-tagged scalars so bytes()/hash() comparisons work.
	unwrap := func(v any) any {
		if r, ok := v.(raw); ok {
			return r.s
		}
		return v
	}
	return fmt.Sprintf("%v", unwrap(a)) == fmt.Sprintf("%v", unwrap(b))
}

func dispatch(target any, method string, args []any) (out any, err error) {
	defer func() {
		if r := recover(); r != nil {
			err = evalErr{"UNKNOWN-ERROR"}
		}
	}()
	switch tgt := target.(type) {
	case cxlib.Doc:
		switch method {
		case "bytes":
			return raw{strings.TrimRight(string(tgt.Bytes()), "\n")}, nil
		case "hash":
			s, e := tgt.Hash()
			if e != nil {
				return nil, evalErr{extractCode(e.Error())}
			}
			return raw{s}, nil
		case "equals":
			other, ok := args[0].(cxlib.Doc)
			if !ok {
				return nil, evalErr{"CXER0100"}
			}
			b, e := tgt.Equals(other)
			if e != nil {
				return nil, evalErr{extractCode(e.Error())}
			}
			return b, nil
		case "eval":
			code, _ := args[0].(string)
			s, e := tgt.Eval(code)
			if e != nil {
				return nil, evalErr{extractCode(e.Error())}
			}
			return raw{strings.TrimRight(s, "\n")}, nil
		case "select_all":
			cxpath, _ := args[0].(string)
			ns, e := tgt.SelectAll(cxpath)
			if e != nil {
				return nil, evalErr{extractCode(e.Error())}
			}
			return ns, nil
		case "select":
			cxpath, _ := args[0].(string)
			n, e := tgt.Select(cxpath)
			if e != nil {
				return nil, evalErr{extractCode(e.Error())}
			}
			return n, nil
		case "modify":
			focus, _ := args[0].(string)
			var actStr string
			switch a := args[1].(type) {
			case action:
				actStr = renderAction(a)
			case string:
				actStr = a
			default:
				actStr = fmt.Sprintf("%v", a)
			}
			nd, e := tgt.Modify(focus, actStr)
			if e != nil {
				return nil, evalErr{extractCode(e.Error())}
			}
			return nd, nil
		case "find_all":
			name, _ := args[0].(string)
			return tgt.FindAll(name), nil
		case "root":
			return tgt.Root(), nil
		case "parse":
			src := args[0]
			var srcBytes []byte
			switch s := src.(type) {
			case string:
				srcBytes = []byte(s)
			case raw:
				srcBytes = []byte(s.s)
			default:
				srcBytes = []byte(fmt.Sprintf("%v", s))
			}
			nd, e := cxlib.ParseDoc(srcBytes)
			if e != nil {
				return nil, evalErr{extractCode(e.Error())}
			}
			return nd, nil
		case "diagram":
			fmtArg := "mermaid"
			if len(args) > 0 {
				if s, ok := args[0].(string); ok {
					fmtArg = s
				}
			}
			s, e := tgt.Diagram(fmtArg)
			if e != nil {
				return nil, evalErr{extractCode(e.Error())}
			}
			return raw{s}, nil
		}
		return nil, evalErr{"UNKNOWN-DOC-METHOD-" + method}
	case cxlib.CodeNode:
		return dispatchNode(&tgt, method, args)
	case *cxlib.CodeNode:
		if tgt == nil {
			return nil, evalErr{"CXER0100"}
		}
		return dispatchNode(tgt, method, args)
	case []cxlib.CodeNode:
		if method == "count" {
			return int64(len(tgt)), nil
		}
		return nil, evalErr{"UNKNOWN-LIST-METHOD-" + method}
	}
	return nil, evalErr{"UNKNOWN-TARGET-" + method}
}

func dispatchNode(n *cxlib.CodeNode, method string, args []any) (any, error) {
	switch method {
	case "name":
		return n.Name(), nil
	case "attr":
		name, _ := args[0].(string)
		return n.Attr(name), nil
	case "attrs":
		return n.Attrs(), nil
	case "children":
		return n.Children(), nil
	case "body":
		return n.Body(), nil
	case "kind":
		return n.Kind(), nil
	}
	return nil, evalErr{"UNKNOWN-NODE-METHOD-" + method}
}

func renderTop(v any) string {
	if v == nil {
		return "()"
	}
	if d, ok := v.(cxlib.Doc); ok {
		return strings.TrimRight(string(d.Bytes()), "\n")
	}
	return renderValue(v)
}

func main() {
	rawIn, err := io.ReadAll(os.Stdin)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERR:NO-INPUT\n")
		os.Exit(2)
	}
	if len(strings.TrimSpace(string(rawIn))) == 0 {
		fmt.Fprintf(os.Stderr, "ERR:NO-INPUT\n")
		os.Exit(2)
	}
	var fx fixture
	if err := json.Unmarshal(rawIn, &fx); err != nil {
		fmt.Fprintf(os.Stderr, "DRIVER-CRASH:%v\n", err)
		os.Exit(2)
	}
	if fx.Ops == nil {
		fmt.Println("UNSUPPORTED")
		return
	}
	var doc *cxlib.Doc
	if fx.InCx != "" {
		d, perr := cxlib.ParseDoc([]byte(fx.InCx))
		if perr != nil {
			fmt.Printf("ERR:%s\n", extractCode(perr.Error()))
			return
		}
		doc = &d
	}
	v, eerr := evaluate(fx.Ops, doc, nil)
	if eerr != nil {
		if ee, ok := eerr.(evalErr); ok {
			fmt.Printf("ERR:%s\n", ee.code)
			return
		}
		fmt.Printf("ERR:%s\n", extractCode(eerr.Error()))
		return
	}
	fmt.Println(renderTop(v))
}
