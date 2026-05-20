// v0.7.0 evaluator-surface smoke tests through the Go binding.
// Per spec/v0_7_0_status.md H3. Cross-binding parity sanity check;
// the V conformance runner against conformance/eval.txt is the
// authoritative per-feature gate.

package cxlib

import "testing"

func eval(t *testing.T, doc, prog string) string {
	t.Helper()
	out, err := EvalCXL(doc, prog, "")
	if err != nil {
		t.Fatalf("EvalCXL: %v", err)
	}
	return out
}

func TestEvalV070LetPositional(t *testing.T) {
	got := eval(t, "[product price=12]", "[?let [v, @price, [?=v]]]")
	if got != "12" {
		t.Fatalf("got %q want %q", got, "12")
	}
}

func TestEvalV070LetLabeled(t *testing.T) {
	got := eval(t, "[product name=Pocket]", "[?let g :be @name :return [?=g]]")
	if got != "Pocket" {
		t.Fatalf("got %q want %q", got, "Pocket")
	}
}

func TestEvalV070FlworWhere(t *testing.T) {
	got := eval(t, "[p [v s=A in=1] [v s=B in=0] [v s=C in=2]]",
		"[?for x :in //v :where x/@in > 0 :return [?=x/@s];]")
	if got != "A;C;" {
		t.Fatalf("got %q want %q", got, "A;C;")
	}
}

func TestEvalV070FlworOrderBy(t *testing.T) {
	got := eval(t, "[p [v s=C] [v s=A] [v s=B]]",
		"[?for x :in //v :order-by x/@s :return [?=x/@s];]")
	if got != "A;B;C;" {
		t.Fatalf("got %q want %q", got, "A;B;C;")
	}
}

func TestEvalV070FlworGroupBy(t *testing.T) {
	got := eval(t, "[p [v c=red n=1] [v c=blue n=2] [v c=red n=3]]",
		"[?for x :in //v :group-by [k, x/@c] :return [g [?=k]:[?for y :in x :return [?=y/@n];]] ]")
	if got != "[g red:1;3;][g blue:2;]" {
		t.Fatalf("got %q want %q", got, "[g red:1;3;][g blue:2;]")
	}
}

func TestEvalV070ForTumbling(t *testing.T) {
	got := eval(t, "[r [v n=1] [v n=2] [v n=3] [v n=4] [v n=5]]",
		"[?for-tumbling w :in //v :size 2 :return [?for x :in w :return [?=x/@n]];]")
	if got != "12;34;5;" {
		t.Fatalf("got %q want %q", got, "12;34;5;")
	}
}

func TestEvalV070FnAndApply(t *testing.T) {
	got := eval(t, "[p]",
		"[?let dbl :be [?fn :params [n] :body [?=n][?=n]] :return [?=[?apply [dbl, 'X']]]]")
	if got != "XX" {
		t.Fatalf("got %q want %q", got, "XX")
	}
}

func TestEvalV070PartialMiddlePlaceholder(t *testing.T) {
	got := eval(t, "[p]",
		"[?let f :be [?partial [[?fn-ref [concat, 2]], [?_], '!']] :return [?=[?apply [f, 'hi']]]]")
	if got != "hi!" {
		t.Fatalf("got %q want %q", got, "hi!")
	}
}

func TestEvalV070TryMultiCatch(t *testing.T) {
	got := eval(t, "[p]",
		"[?try [[?error ['FORG0006', 'wrong type']], [FOAR*, math], [FORG*, generic], [*, other]]]")
	if got != "generic" {
		t.Fatalf("got %q want %q", got, "generic")
	}
}

func TestEvalV070ParentAxis(t *testing.T) {
	got := eval(t, "[root [outer tag=O [inner n=42]]]",
		"[?for x :in //inner/parent::* :return [?=x/@tag];]")
	if got != "O;" {
		t.Fatalf("got %q want %q", got, "O;")
	}
}

func TestEvalV070FollowingSibling(t *testing.T) {
	got := eval(t, "[r [a n=1] [b n=2] [c n=3]]",
		"[?for x :in //a/following-sibling::* :return [?=x/@n];]")
	if got != "2;3;" {
		t.Fatalf("got %q want %q", got, "2;3;")
	}
}

func TestEvalV070OpPipeline(t *testing.T) {
	got := eval(t, "[p name=alice]", "[?=@name |> upper]")
	if got != "ALICE" {
		t.Fatalf("got %q want %q", got, "ALICE")
	}
}

func TestEvalV070OpToRange(t *testing.T) {
	got := eval(t, "[p]", "[?for x :in 1 to 4 :return [?=x];]")
	if got != "1;2;3;4;" {
		t.Fatalf("got %q want %q", got, "1;2;3;4;")
	}
}

func TestEvalV070OpStringConcat(t *testing.T) {
	got := eval(t, "[u first=Alice last=Smith]", "[?=@first || '-' || @last]")
	if got != "Alice-Smith" {
		t.Fatalf("got %q want %q", got, "Alice-Smith")
	}
}

func TestEvalV070AttrValueInterpolation(t *testing.T) {
	got := eval(t, "[p [c cid=42 name=Joe]]",
		"[?for c :in //c :return [a href=/u/[?=c/@cid]/p/[?=c/@name]]]")
	if got != "[a href=/u/42/p/Joe]" {
		t.Fatalf("got %q want %q", got, "[a href=/u/42/p/Joe]")
	}
}

func TestEvalV070FnMatchesRegex(t *testing.T) {
	got := eval(t, "[p s='hello42']", "[?=[?matches ['[a-z]+[0-9]+', @s]]]")
	if got != "true" {
		t.Fatalf("got %q want %q", got, "true")
	}
}

func TestEvalV070StreamingMatchesBuffered(t *testing.T) {
	doc := "[r [v n=1] [v n=2] [v n=3]]"
	prog := "[?for x :in //v :return [?=x/@n]]"
	buffered := eval(t, doc, prog)
	var chunks [][]byte
	if err := EvalCXLStreaming(doc, prog, "", func(chunk []byte) error {
		chunks = append(chunks, chunk)
		return nil
	}); err != nil {
		t.Fatalf("EvalCXLStreaming: %v", err)
	}
	streamed := ""
	for _, c := range chunks {
		streamed += string(c)
	}
	if buffered != streamed {
		t.Fatalf("buffered %q != streamed %q", buffered, streamed)
	}
}

// ── DD (cx: self-host module) cross-binding smoke tests ─────────────────

// DD3 cx:canonical wraps cx_text_canonical — idempotent
func TestEvalV070CxCanonical(t *testing.T) {
	got := eval(t, "[p]", "[?=[?cx:canonical [[?cx:parse ['[product name=A]']]]]]")
	if !strContains(got, "product") || !strContains(got, "name=A") {
		t.Fatalf("got %q", got)
	}
}

// DD4 cx:hash — SHA-256 hex of canonical form; same input → same hash
func TestEvalV070CxHashDeterministic(t *testing.T) {
	prog := "[?=[?cx:hash [[?cx:parse ['[r x=1]']]]]]"
	h1 := eval(t, "[p]", prog)
	h2 := eval(t, "[p]", prog)
	if h1 != h2 {
		t.Fatalf("hash not deterministic: %q vs %q", h1, h2)
	}
	if len(h1) != 64 {
		t.Fatalf("expected 64-char hex digest, got %d chars: %q", len(h1), h1)
	}
}

// DD7 cx:to-format json
func TestEvalV070CxToFormatJSON(t *testing.T) {
	got := eval(t, "[p]", "[?=[?cx:to-format [[?cx:parse ['[u name=alice]']], 'json']]]")
	if !strContains(got, "alice") || !strContains(got, `"`) {
		t.Fatalf("got %q", got)
	}
}

// DD9 cx:equal — identical inputs equal; distinct differ
func TestEvalV070CxEqualIdentical(t *testing.T) {
	got := eval(t, "[p]",
		"[?=[?cx:equal [[?cx:parse ['[r a=1]']], [?cx:parse ['[r a=1]']]]]]")
	if got != "true" {
		t.Fatalf("got %q want true", got)
	}
}

func TestEvalV070CxEqualDistinct(t *testing.T) {
	got := eval(t, "[p]",
		"[?=[?cx:equal [[?cx:parse ['[a]']], [?cx:parse ['[b]']]]]]")
	if got != "false" {
		t.Fatalf("got %q want false", got)
	}
}

// DD11 cx:eval — default off → CXER0041
func TestEvalV070CxEvalDefaultOff(t *testing.T) {
	_, err := EvalCXL("[p]", "[?cx:eval ['[?=1]', {}]]", "")
	if err == nil {
		t.Fatal("expected CXER0041 from cx:eval without allow-eval")
	}
	if !strContains(err.Error(), "CXER0041") {
		t.Fatalf("expected CXER0041, got: %v", err)
	}
}

// DD11 cx:eval — engine runs once allow-eval set
func TestEvalV070CxEvalWithAllowEval(t *testing.T) {
	got := eval(t, "[p]", "[?cx allow-eval=true][?cx:eval ['[?=1]', {}]]")
	if !strContains(got, "1") {
		t.Fatalf("got %q", got)
	}
}

// DD12 cx:render — engine runs returning rendered text
func TestEvalV070CxRender(t *testing.T) {
	got := eval(t, "[p]", "[?cx allow-eval=true][?cx:render ['[?=42]', {}]]")
	if !strContains(got, "42") {
		t.Fatalf("got %q", got)
	}
}

// ── FF (log: structured-logging) cross-binding smoke tests ──────────────

// FF3 log:info under [?cx pure-only] refused (EE4)
func TestEvalV070LogInfoUnderPureOnlyRefused(t *testing.T) {
	_, err := EvalCXL("[p]", "[?cx pure-only][?log:info ['hi', {}]]", "")
	if err == nil {
		t.Fatal("expected CXER0040 — log: is SideEffect under pure-only")
	}
	if !strContains(err.Error(), "CXER0040") {
		t.Fatalf("expected CXER0040, got: %v", err)
	}
}

// FF6 log:level — ReadOnly; returns current effective level
func TestEvalV070LogLevelReturnsString(t *testing.T) {
	got := eval(t, "[p]", "[?cx log-level=debug][?=[?log:level]]")
	if got != "debug" {
		t.Fatalf("got %q want debug", got)
	}
}

// helper — substring check kept tiny to avoid depending on strings
func strContains(s, sub string) bool {
	if len(sub) == 0 {
		return true
	}
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}
