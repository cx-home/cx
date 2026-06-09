// Phase 5.2 Tier-1 binding parity (Go) — cx_code_eval* surface.
//
// Covers the cx_code_eval* entry-point family exported from
// vcx/code/cabi.v + documented at spec/audits/code_abi_v1.md.
// Mirrors lang/python/test_code_eval.py case-for-case so the two
// Tier-1 bindings stay in lockstep on the same surface.

package cxlib

import (
	"errors"
	"fmt"
	"strings"
	"testing"
)

// ── One-shot ────────────────────────────────────────────────────────────────

func TestEvalCodeSimpleFind(t *testing.T) {
	input := `[doc [order id=1 status="open"] [order id=2 status="closed"] [order id=3 status="open"]]`
	prog := `[?for [order $m] [yield $m]]`
	out, err := EvalCode(input, prog, "text")
	if err != nil {
		t.Fatalf("eval failed: %v", err)
	}
	lines := strings.Split(out, "\n")
	if len(lines) != 3 {
		t.Fatalf("expected 3 matches, got %d: %q", len(lines), out)
	}
	for i, line := range lines {
		if !strings.HasPrefix(line, "[order") {
			t.Fatalf("line %d not an order: %q", i, line)
		}
	}
}

func TestEvalCodeForComprehension(t *testing.T) {
	prog := `[?for [in $i (1, 2, 3)] [yield [item n=$i]]]`
	out, err := EvalCode("", prog, "text")
	if err != nil {
		t.Fatalf("eval failed: %v", err)
	}
	want := "[item n=1]\n[item n=2]\n[item n=3]"
	if out != want {
		t.Fatalf("\n got:  %q\n want: %q", out, want)
	}
}

func TestEvalCodeEmptyInputOk(t *testing.T) {
	out, err := EvalCode("", `[?let [= $x 42] [ok value=$x]]`, "")
	if err != nil {
		t.Fatalf("eval failed: %v", err)
	}
	if out != "[ok value=42]" {
		t.Fatalf("got %q", out)
	}
}

func TestEvalCodeDefaultTargetIsText(t *testing.T) {
	a, _ := EvalCode("", "[ok value=1]", "")
	b, _ := EvalCode("", "[ok value=1]", "text")
	if a != b {
		t.Fatalf("default-target mismatch: %q vs %q", a, b)
	}
	if a != "[ok value=1]" {
		t.Fatalf("unexpected output: %q", a)
	}
}

func TestEvalCodeCxTarget(t *testing.T) {
	out, err := EvalCode("", `[ok value="x"]`, "cx")
	if err != nil {
		t.Fatalf("eval failed: %v", err)
	}
	if out != `[ok value=x]` {
		t.Fatalf("got %q", out)
	}
}

func TestEvalCodeUnknownTargetRejected(t *testing.T) {
	_, err := EvalCode("", "[ok]", "protobuf")
	if err == nil {
		t.Fatal("expected error for unknown target")
	}
	if !strings.Contains(err.Error(), "CXER0100") {
		t.Fatalf("expected CXER0100, got: %v", err)
	}
	if !strings.Contains(err.Error(), "protobuf") {
		t.Fatalf("expected target name in error: %v", err)
	}
}

func TestEvalCodeSvgTargetReturnsDiagram(t *testing.T) {
	// Phase 4.1 landed the diagram renderer — svg / mermaid / png
	// now return embedded-source diagrams. html remains
	// Phase-4-gated.
	out, err := EvalCode("", "[?for [user $u] [yield $u]]", "svg")
	if err != nil {
		t.Fatalf("expected svg success after Phase 4: %v", err)
	}
	if !strings.Contains(out, "cx:source") {
		t.Fatalf("expected cx:source metadata in svg output, got: %q", out)
	}
}

func TestEvalCodeHtmlTargetStillPhase4Gated(t *testing.T) {
	_, err := EvalCode("", "[ok]", "html")
	if err == nil {
		t.Fatal("expected Phase-4-gated error for html target")
	}
	if !strings.Contains(err.Error(), "CXER0001") {
		t.Fatalf("expected CXER0001, got: %v", err)
	}
}

func TestEvalCodeParseErrorRoutesCXER0100(t *testing.T) {
	_, err := EvalCode("", "[?for", "text")
	if err == nil {
		t.Fatal("expected parse error for unterminated bracket")
	}
	if !strings.Contains(err.Error(), "CXER0100") {
		t.Fatalf("expected CXER0100, got: %v", err)
	}
	if !strings.Contains(strings.ToLower(err.Error()), "parse") {
		t.Fatalf("expected parse hint in error: %v", err)
	}
}

// ── Streaming ───────────────────────────────────────────────────────────────

func TestEvalCodeStreamingConcatEqualsOneShot(t *testing.T) {
	// spec/audits/code_abi_v1.md §3.3: concatenated streaming
	// output is byte-equivalent to the one-shot output.
	prog := `[?for [in $i (10, 20, 30)] [yield [item n=$i]]]`
	oneShot, err := EvalCode("", prog, "text")
	if err != nil {
		t.Fatalf("one-shot failed: %v", err)
	}

	var chunks [][]byte
	onChunk := func(data []byte) error {
		// Copy the chunk so it survives past the cgo callback's
		// transient buffer reference.
		buf := make([]byte, len(data))
		copy(buf, data)
		chunks = append(chunks, buf)
		return nil
	}
	if err := EvalCodeStreaming("", prog, "text", onChunk); err != nil {
		t.Fatalf("streaming failed: %v", err)
	}

	var sb strings.Builder
	for _, c := range chunks {
		sb.Write(c)
	}
	if sb.String() != oneShot {
		t.Fatalf("streaming != one-shot:\n  streamed: %q\n  one-shot: %q",
			sb.String(), oneShot)
	}
}

func TestEvalCodeStreamingCallbackAbort(t *testing.T) {
	prog := `[?for [in $i (1, 2, 3)] [yield [item n=$i]]]`
	abortErr := errors.New("sink rejected chunk")
	onChunk := func(_ []byte) error {
		return abortErr
	}
	err := EvalCodeStreaming("", prog, "text", onChunk)
	if err == nil {
		t.Fatal("expected error from aborting callback")
	}
	if !errors.Is(err, abortErr) && err.Error() != abortErr.Error() {
		t.Logf("note: error propagation shape: %v", err)
	}
}

// ── Error wire format ───────────────────────────────────────────────────────

func TestErrorWireFormatCXERPrefix(t *testing.T) {
	// D3 of code_abi_v1.md: errors arrive as `CXERnnnn:msg` —
	// the cx-err: namespace prefix is stripped at the ABI boundary
	// (reserved for value-form errors inside programs).
	_, err := EvalCode("", "[?for", "text")
	if err == nil {
		t.Fatal("expected parse error")
	}
	msg := err.Error()
	if !strings.HasPrefix(msg, "CXER") {
		t.Fatalf("expected CXERnnnn prefix, got: %s", msg)
	}
	if strings.HasPrefix(msg, "cx-err:") {
		t.Fatalf("cx-err: namespace leaked into wire format: %s", msg)
	}
}

// ── Smoke: package surface didn't regress ───────────────────────────────────

func TestPackageSurfaceSmoke(t *testing.T) {
	// Quick sanity check that other package symbols still load and
	// run after the Phase 7 / Phase 5.2 surgery.
	v := Version()
	if v == "" {
		t.Fatal("Version() returned empty")
	}
	out, err := ToCx("[p Hello]")
	if err != nil {
		t.Fatalf("ToCx: %v", err)
	}
	if !strings.Contains(out, "Hello") {
		t.Fatalf("ToCx output missing greeting: %q", out)
	}
	// Round-trip via EvalCode. Use structured-body users so the
	// §5.2 rule 5 auto-unwrap keeps the whole [user …] element (the
	// no-attrs-named-head + single-bind shape unwraps single-value
	// bodies; structured bodies keep the element).
	doc := "[users [user [name Alice]] [user [name Bob]]]"
	prog := "[?for [user $u] [yield $u]]"
	count, err := EvalCode(doc, prog, "text")
	if err != nil {
		t.Fatalf("EvalCode: %v", err)
	}
	if want := 2; strings.Count(count, "[user") != want {
		t.Fatalf("expected %d user matches, got: %q", want, count)
	}
	_ = fmt.Sprintf // keep import alive
}
