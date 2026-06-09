// v0_8_0_surface_test.go — coverage of the v0.8.0 Layer-1 surface
// for the Go binding (spec/bindings.md §2.1).
//
// One test per Layer-1 method (10 Doc methods + 6 Node methods = 16
// methods total), plus:
//
//   * 3 atom free-function tests (re-asserting the Phase 3.7 catchup
//     landed in lang/go/cxlib/atom_test.go — repeated here so the
//     v0.8.0 surface test is self-contained).
// * 2 helper tests (CxCodeDiagram + CxCodeTree).
//   * 1 CxCodeEval alias parity check.
//   * 4 Layer-2 idiom tests covering the builder filter chain +
//     Explain desugaring.
//
// All tests bind through the existing `cxlib` libcx handle; no
// additional library loading is required.

package cxlib

import (
	"strings"
	"testing"
)

const v08TestDoc = `[doc [user name='Alice' active=true] [user name='Bob' active=false]]`

// ── Layer-1 method 1: parse(bytes) -> Doc ─────────────────────────────────

func TestV08_ParseDoc(t *testing.T) {
	doc, err := ParseDoc([]byte(v08TestDoc))
	if err != nil {
		t.Fatalf("ParseDoc: %v", err)
	}
	if doc.Document() == nil {
		t.Fatal("ParseDoc returned Doc with nil Document")
	}
	root := doc.Root()
	if root == nil {
		t.Fatal("ParseDoc: empty document root")
	}
	if root.Name() != "doc" {
		t.Fatalf("root name = %q, want %q", root.Name(), "doc")
	}
}

// ── Layer-1 method 2: Doc.Bytes() -> bytes ────────────────────────────────

func TestV08_DocBytes(t *testing.T) {
	doc, err := ParseDoc([]byte(v08TestDoc))
	if err != nil {
		t.Fatalf("ParseDoc: %v", err)
	}
	b := doc.Bytes()
	if len(b) == 0 {
		t.Fatal("Doc.Bytes() returned empty")
	}
	// Round-trip: re-parse the emitted bytes and confirm root name.
	doc2, err := ParseDoc(b)
	if err != nil {
		t.Fatalf("re-parse of Doc.Bytes: %v", err)
	}
	if doc2.Root().Name() != "doc" {
		t.Fatalf("round-trip lost root name")
	}
}

// ── Layer-1 method 3: Doc.Hash() -> string ────────────────────────────────

func TestV08_DocHash(t *testing.T) {
	doc, err := ParseDoc([]byte(v08TestDoc))
	if err != nil {
		t.Fatalf("ParseDoc: %v", err)
	}
	h, err := doc.Hash()
	if err != nil {
		t.Fatalf("Doc.Hash: %v", err)
	}
	if len(h) != 64 {
		t.Fatalf("expected 64-char SHA-256 hex, got %d chars: %q", len(h), h)
	}
	for _, c := range h {
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) {
			t.Fatalf("non-lowercase-hex char in hash: %q", h)
		}
	}
}

// ── Layer-1 method 4: Doc.Equals(other) -> bool ───────────────────────────

func TestV08_DocEquals(t *testing.T) {
	a, err := ParseDoc([]byte(v08TestDoc))
	if err != nil {
		t.Fatalf("ParseDoc a: %v", err)
	}
	b, err := ParseDoc([]byte(v08TestDoc))
	if err != nil {
		t.Fatalf("ParseDoc b: %v", err)
	}
	eq, err := a.Equals(b)
	if err != nil {
		t.Fatalf("Doc.Equals: %v", err)
	}
	if !eq {
		t.Fatalf("identical docs reported unequal")
	}
	// Different content should compare unequal.
	c, err := ParseDoc([]byte(`[other]`))
	if err != nil {
		t.Fatalf("ParseDoc c: %v", err)
	}
	eq2, err := a.Equals(c)
	if err != nil {
		t.Fatalf("Doc.Equals: %v", err)
	}
	if eq2 {
		t.Fatalf("different docs reported equal")
	}
}

// ── Layer-1 method 5: Doc.Eval(code) -> Value ─────────────────────────────

func TestV08_DocEval(t *testing.T) {
	doc, err := ParseDoc([]byte(v08TestDoc))
	if err != nil {
		t.Fatalf("ParseDoc: %v", err)
	}
	out, err := doc.Eval(`[?for [in $i (1, 2, 3)] [yield $i]]`, "text")
	if err != nil {
		t.Fatalf("Doc.Eval: %v", err)
	}
	if out != "1\n2\n3" {
		t.Fatalf("Doc.Eval got %q, want %q", out, "1\n2\n3")
	}
}

// ── Layer-1 method 6: Doc.SelectAll(cxpath) -> [Node] ─────────────────────

func TestV08_DocSelectAll(t *testing.T) {
	doc, err := ParseDoc([]byte(v08TestDoc))
	if err != nil {
		t.Fatalf("ParseDoc: %v", err)
	}
	users, err := doc.SelectAll("//user")
	if err != nil {
		t.Fatalf("SelectAll: %v", err)
	}
	if len(users) != 2 {
		t.Fatalf("expected 2 users, got %d", len(users))
	}
	for i, u := range users {
		if u.Name() != "user" {
			t.Fatalf("user[%d] name = %q, want %q", i, u.Name(), "user")
		}
	}
}

// ── Layer-1 method 7: Doc.Select(cxpath) -> Node? ─────────────────────────

func TestV08_DocSelect(t *testing.T) {
	doc, err := ParseDoc([]byte(v08TestDoc))
	if err != nil {
		t.Fatalf("ParseDoc: %v", err)
	}
	first, err := doc.Select("//user")
	if err != nil {
		t.Fatalf("Select: %v", err)
	}
	if first == nil {
		t.Fatal("Select: nil for non-empty match")
	}
	if first.Name() != "user" {
		t.Fatalf("Select: name = %q", first.Name())
	}
	// Non-matching path returns nil, no error.
	none, err := doc.Select("//nonexistent")
	if err != nil {
		t.Fatalf("Select empty: %v", err)
	}
	if none != nil {
		t.Fatalf("Select: expected nil for no match, got %v", none)
	}
}

// ── Layer-1 method 8: Doc.Modify(focus, action) -> Doc ────────────────────

func TestV08_DocModify(t *testing.T) {
	doc, err := ParseDoc([]byte(`[doc [user name='Alice'] [user name='Bob']]`))
	if err != nil {
		t.Fatalf("ParseDoc: %v", err)
	}
	newDoc, err := doc.Modify("//user", "[delete]")
	if err != nil {
		t.Fatalf("Modify: %v", err)
	}
	// Pure-functional contract: original unchanged.
	if len(doc.FindAll("user")) != 2 {
		t.Fatalf("Modify mutated receiver")
	}
	if len(newDoc.FindAll("user")) != 0 {
		t.Fatalf("Modify result still has users: %s", string(newDoc.Bytes()))
	}
}

// ── Layer-1 method 9: Doc.FindAll(name) -> [Node] ─────────────────────────

func TestV08_DocFindAll(t *testing.T) {
	doc, err := ParseDoc([]byte(v08TestDoc))
	if err != nil {
		t.Fatalf("ParseDoc: %v", err)
	}
	users := doc.FindAll("user")
	if len(users) != 2 {
		t.Fatalf("FindAll user: got %d, want 2", len(users))
	}
	none := doc.FindAll("nonexistent")
	if len(none) != 0 {
		t.Fatalf("FindAll nonexistent: got %d", len(none))
	}
}

// ── Layer-1 method 10: Doc.Root() -> Node ─────────────────────────────────

func TestV08_DocRoot(t *testing.T) {
	doc, err := ParseDoc([]byte(v08TestDoc))
	if err != nil {
		t.Fatalf("ParseDoc: %v", err)
	}
	root := doc.Root()
	if root == nil {
		t.Fatal("Root: nil")
	}
	if root.Name() != "doc" {
		t.Fatalf("Root name = %q", root.Name())
	}
}

// ── Layer-1 method 11: Node.Name() -> string ──────────────────────────────

func TestV08_NodeName(t *testing.T) {
	doc, _ := ParseDoc([]byte(v08TestDoc))
	users := doc.FindAll("user")
	if len(users) == 0 {
		t.Fatal("no users")
	}
	if users[0].Name() != "user" {
		t.Fatalf("Node.Name = %q", users[0].Name())
	}
}

// ── Layer-1 method 12: Node.Attr(name) -> Value? ──────────────────────────

func TestV08_NodeAttr(t *testing.T) {
	doc, _ := ParseDoc([]byte(v08TestDoc))
	users := doc.FindAll("user")
	if users[0].Attr("name") != "Alice" {
		t.Fatalf("Attr name = %v", users[0].Attr("name"))
	}
	if users[0].Attr("nonexistent") != nil {
		t.Fatalf("Attr nonexistent should be nil")
	}
}

// ── Layer-1 method 13: Node.Attrs() -> Map ────────────────────────────────

func TestV08_NodeAttrs(t *testing.T) {
	doc, _ := ParseDoc([]byte(v08TestDoc))
	users := doc.FindAll("user")
	attrs := users[0].Attrs()
	if len(attrs) != 2 {
		t.Fatalf("expected 2 attrs (name + active), got %d: %v", len(attrs), attrs)
	}
	if attrs["name"] != "Alice" {
		t.Fatalf("attrs[name] = %v", attrs["name"])
	}
	if attrs["active"] != true {
		t.Fatalf("attrs[active] = %v", attrs["active"])
	}
}

// ── Layer-1 method 14: Node.Children() -> [Node] ──────────────────────────

func TestV08_NodeChildren(t *testing.T) {
	doc, _ := ParseDoc([]byte(v08TestDoc))
	root := doc.Root()
	kids := root.Children()
	if len(kids) != 2 {
		t.Fatalf("Children: got %d, want 2", len(kids))
	}
	for i, k := range kids {
		if k.Name() != "user" {
			t.Fatalf("child[%d] = %q", i, k.Name())
		}
	}
}

// ── Layer-1 method 15: Node.Body() -> Value ───────────────────────────────

func TestV08_NodeBody(t *testing.T) {
	doc, _ := ParseDoc([]byte(`[doc [greeting "hello"] [empty] [count :i 42]]`))
	greeting := doc.FindAll("greeting")
	body := greeting[0].Body()
	// Body for a text-only element returns the scalar / text content.
	if body == nil {
		t.Fatal("greeting body is nil")
	}
	// Could be string "hello" via scalar/text path.
	if s, ok := body.(string); !ok || !strings.Contains(s, "hello") {
		t.Fatalf("greeting body = %v (%T), want 'hello'-like", body, body)
	}
}

// ── Layer-1 method 16: Node.Kind() -> string ──────────────────────────────

func TestV08_NodeKind(t *testing.T) {
	doc, _ := ParseDoc([]byte(v08TestDoc))
	users := doc.FindAll("user")
	if users[0].Kind() != "element" {
		t.Fatalf("Node.Kind = %q, want %q", users[0].Kind(), "element")
	}
}

// ── atom Tier-1 surface (re-assertion) ─────────────────────────

func TestV08_Atom(t *testing.T) {
	a, err := Atom("ok")
	if err != nil {
		t.Fatalf("Atom(ok): %v", err)
	}
	if a.Name != "ok" {
		t.Fatalf("Atom.Name = %q", a.Name)
	}
	if a.String() != ":ok" {
		t.Fatalf("Atom.String = %q, want %q", a.String(), ":ok")
	}
}

func TestV08_IsAtom(t *testing.T) {
	a, _ := Atom("ok")
	if !IsAtom(a) {
		t.Fatal("IsAtom(AtomValue) returned false")
	}
	// Type-strict equality: a string with the same content is NOT an atom.
	if IsAtom("ok") {
		t.Fatal("IsAtom(string) returned true — violates type-strict equality")
	}
	if IsAtom(42) {
		t.Fatal("IsAtom(int) returned true")
	}
}

func TestV08_AtomName(t *testing.T) {
	a, _ := Atom("ok")
	name, ok := AtomName(a)
	if !ok {
		t.Fatal("AtomName(AtomValue) returned ok=false")
	}
	if name != "ok" {
		t.Fatalf("AtomName = %q, want %q", name, "ok")
	}
	_, ok = AtomName("string")
	if ok {
		t.Fatal("AtomName(string) returned ok=true")
	}
}

// ── CxCodeDiagram (cap bit 31) ─────────────────────────

func TestV08_CxCodeDiagram(t *testing.T) {
	out, err := CxCodeDiagram("[hello]", "mermaid")
	if err != nil {
		t.Fatalf("CxCodeDiagram: %v", err)
	}
	if out == "" {
		t.Fatal("CxCodeDiagram returned empty string")
	}
}

// ── CxCodeTree (cap bit 32) ─────────────────────────────────

func TestV08_CxCodeTree(t *testing.T) {
	tree, err := CxCodeTree("[hello]")
	if err != nil {
		t.Fatalf("CxCodeTree: %v", err)
	}
	// Per every node has {kind, loc}.
	if _, ok := tree["kind"]; !ok {
		t.Fatalf("CxCodeTree result missing 'kind': %v", tree)
	}
	if _, ok := tree["loc"]; !ok {
		t.Fatalf("CxCodeTree result missing 'loc': %v", tree)
	}
	loc, ok := tree["loc"].(map[string]any)
	if !ok {
		t.Fatalf("loc is not a map: %T", tree["loc"])
	}
	if _, ok := loc["start"]; !ok {
		t.Fatalf("loc missing 'start': %v", loc)
	}
	if _, ok := loc["end"]; !ok {
		t.Fatalf("loc missing 'end': %v", loc)
	}
}

func TestV08_CxCodeTreeEmpty(t *testing.T) {
	tree, err := CxCodeTree("")
	if err != nil {
		t.Fatalf("CxCodeTree(empty): %v", err)
	}
	if tree["kind"] == nil {
		t.Fatalf("empty CxCodeTree missing kind: %v", tree)
	}
}

// ── CxCodeEval alias parity ─────────────────────────────────────────────

func TestV08_CxCodeEvalAlias(t *testing.T) {
	a, err := CxCodeEval("", `[?for [in $i (1, 2)] [yield $i]]`, "text")
	if err != nil {
		t.Fatalf("CxCodeEval: %v", err)
	}
	b, err := EvalCode("", `[?for [in $i (1, 2)] [yield $i]]`, "text")
	if err != nil {
		t.Fatalf("EvalCode: %v", err)
	}
	if a != b {
		t.Fatalf("CxCodeEval != EvalCode: %q vs %q", a, b)
	}
}

// ── Doc.Diagram / Doc.Tree convenience ──────────────────────────────────

func TestV08_DocDiagram(t *testing.T) {
	doc, _ := ParseDoc([]byte(`[hello]`))
	out, err := doc.Diagram()
	if err != nil {
		t.Fatalf("Doc.Diagram: %v", err)
	}
	if out == "" {
		t.Fatal("Doc.Diagram returned empty")
	}
}

func TestV08_DocTree(t *testing.T) {
	doc, _ := ParseDoc([]byte(`[hello]`))
	tree, err := doc.Tree()
	if err != nil {
		t.Fatalf("Doc.Tree: %v", err)
	}
	if tree["kind"] == nil {
		t.Fatalf("Doc.Tree missing kind: %v", tree)
	}
}

// ── Layer-2 idioms — builder filter chain + Explain ─────────────────────

func TestV08_Layer2_Filter(t *testing.T) {
	doc, _ := ParseDoc([]byte(v08TestDoc))
	users, err := doc.Filter("user").All()
	if err != nil {
		t.Fatalf("Filter.All: %v", err)
	}
	if len(users) != 2 {
		t.Fatalf("Filter user .All: got %d users, want 2", len(users))
	}
}

func TestV08_Layer2_FilterWhereGet(t *testing.T) {
	doc, _ := ParseDoc([]byte(v08TestDoc))
	got, err := doc.Filter("user").Where("@active=true").All()
	if err != nil {
		t.Fatalf("Filter.Where.All: %v", err)
	}
	if len(got) != 1 {
		t.Fatalf("Filter user [@active=true]: got %d, want 1", len(got))
	}
	if got[0].Attr("name") != "Alice" {
		t.Fatalf("filter returned wrong user: %v", got[0].Attr("name"))
	}
}

func TestV08_Layer2_Explain(t *testing.T) {
	cases := []struct {
		op   string
		args []string
		want string
	}{
		{"filter", []string{"user"}, `doc.SelectAll("//user")`},
		{"filter+where", []string{"user", "@active=true"}, `doc.SelectAll("//user[@active=true]")`},
		{"filter+where+get", []string{"user", "@active=true", "/@email"}, `doc.SelectAll("//user[@active=true]/@email")`},
		{"filter+first", []string{"user"}, `doc.Select("//user")`},
		{"must_select_all", []string{"//user"}, `doc.SelectAll("//user")`},
		{"must_select", []string{"//user"}, `doc.Select("//user")`},
	}
	for _, c := range cases {
		got, err := Explain(c.op, c.args...)
		if err != nil {
			t.Errorf("Explain(%q, %v): %v", c.op, c.args, err)
			continue
		}
		if got != c.want {
			t.Errorf("Explain(%q, %v) = %q, want %q", c.op, c.args, got, c.want)
		}
	}
}

func TestV08_Layer2_SetBuilder(t *testing.T) {
	cases := []struct {
		in   any
		want string
	}{
		{nil, "[set null]"},
		{true, "[set true]"},
		{false, "[set false]"},
		{42, "[set 42]"},
		{int64(99), "[set 99]"},
		{"hello", `[set "hello"]`},
		{`with "quote"`, `[set "with \"quote\""]`},
	}
	for _, c := range cases {
		got, err := Set(c.in)
		if err != nil {
			t.Errorf("Set(%v): %v", c.in, err)
			continue
		}
		if got != c.want {
			t.Errorf("Set(%v) = %q, want %q", c.in, got, c.want)
		}
	}
	// Unsupported type returns an error.
	if _, err := Set([]int{1, 2}); err == nil {
		t.Error("Set([]int): expected error for unsupported type")
	}
}
