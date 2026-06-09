package cxlib

import (
	"encoding/binary"
	"strings"
	"testing"
)

// iterator_test.go Tier-1 binding wrapper for Go.
//
// W3f scope: synthetic IteratorNode round-trip via the ast_bin
// encoder/decoder. True lazy-pull via a C ABI `cx_iterator_pull` export
// lands in a follow-on ADR; this milestone covers wire transport +
// binding-side IteratorNode type surface.
//
// The W3c renderer (V core) materialises iterators at the host emit
// boundary — `EvalCode` returns a rendered string, never an
// IteratorNode directly. This test exercises the lower-level ast_bin
// codec where Iterator values are observable as a transport between
// CX-aware consumers (cxbin payloads, persisted caches).

// ── construction + identity ────────────────────────────────────

func TestIteratorNodeConstruction(t *testing.T) {
	it := &IteratorNode{
		SourceKind: IterRange,
		SourceArgs: []Node{
			&ScalarNode{DataType: "int", Value: int64(0)},
			&ScalarNode{DataType: "int", Value: int64(10)},
			&ScalarNode{DataType: "int", Value: int64(1)},
		},
	}
	if it.SourceKind != IterRange {
		t.Errorf("SourceKind = %d, want %d", it.SourceKind, IterRange)
	}
	if it.KindName() != "iter_range" {
		t.Errorf("KindName = %q, want iter_range", it.KindName())
	}
	if len(it.SourceArgs) != 3 {
		t.Errorf("SourceArgs len = %d, want 3", len(it.SourceArgs))
	}
	if it.SingleUse {
		t.Errorf("SingleUse default should be false")
	}
}

func TestIteratorNodeIdentityEqualityOQ4(t *testing.T) {
	// pointer-identity equality. Two distinct
	// *IteratorNode values are unequal even with matching shape.
	a := &IteratorNode{SourceKind: IterRange}
	b := &IteratorNode{SourceKind: IterRange}
	if a == b {
		t.Errorf("expected pointer-distinct iterators to compare unequal")
	}
	if a != a {
		t.Errorf("identity comparison broken")
	}
}

func TestIteratorNodeSingleUseRewalkBlocked(t *testing.T) {
	// single-use iterator can't be reset.
	it := &IteratorNode{
		SourceKind: IterRange,
		SingleUse:  true,
		Memo: []Node{
			&ScalarNode{DataType: "int", Value: int64(1)},
			&ScalarNode{DataType: "int", Value: int64(2)},
		},
	}
	out := it.Materialize()
	if len(out) != 2 {
		t.Fatalf("first walk got %d items, want 2", len(out))
	}
	if err := it.Reset(); err == nil {
		t.Errorf("expected error on single-use Reset()")
	} else if !strings.Contains(err.Error(), "single-use") {
		t.Errorf("error message %q lacks 'single-use'", err.Error())
	}
}

func TestIteratorNodeMultiUseReset(t *testing.T) {
	it := &IteratorNode{
		SourceKind: IterRange,
		Memo: []Node{
			&ScalarNode{DataType: "int", Value: int64(1)},
			&ScalarNode{DataType: "int", Value: int64(2)},
		},
	}
	out1 := it.Materialize()
	if err := it.Reset(); err != nil {
		t.Fatalf("unexpected Reset error: %v", err)
	}
	// After reset Exhausted is sticky but walk pointer is rewound.
	it.Exhausted = false
	out2 := it.Materialize()
	if len(out1) != 2 || len(out2) != 2 {
		t.Errorf("multi-use re-walk lengths = (%d, %d), want (2, 2)",
			len(out1), len(out2))
	}
}

// ── ast_bin round-trip ─────────────────────────────────────────────

func wrapDoc(n Node) *Document {
	return &Document{Elements: []Node{n}}
}

// stripFrame strips the [u32 LE size] frame from encodeAST output so
// it matches the input shape decodeAST expects.
func stripFrame(framed []byte) []byte {
	size := binary.LittleEndian.Uint32(framed[:4])
	return framed[4 : 4+size]
}

func TestIteratorRoundTripRange(t *testing.T) {
	src := &IteratorNode{
		SourceKind: IterRange,
		SourceArgs: []Node{
			&ScalarNode{DataType: "int", Value: int64(0)},
			&ScalarNode{DataType: "int", Value: int64(10)},
			&ScalarNode{DataType: "int", Value: int64(2)},
		},
	}
	doc, err := decodeAST(stripFrame(encodeAST(wrapDoc(src))))
	if err != nil {
		t.Fatalf("decodeAST: %v", err)
	}
	out, ok := doc.Elements[0].(*IteratorNode)
	if !ok {
		t.Fatalf("decoded type = %T, want *IteratorNode", doc.Elements[0])
	}
	if out.SourceKind != IterRange {
		t.Errorf("SourceKind = %d, want %d", out.SourceKind, IterRange)
	}
	if len(out.SourceArgs) != 3 {
		t.Errorf("SourceArgs len = %d, want 3", len(out.SourceArgs))
	}
	// Memo NOT preserved; decoded iterator starts fresh.
	if out.Materialize() != nil && len(out.Materialize()) != 0 {
		t.Errorf("decoded Memo should be empty (memo resets on decode)")
	}
	// identity NOT preserved across the wire.
	if out == src {
		t.Errorf("expected new pointer after wire round-trip")
	}
}

func TestIteratorRoundTripSingleUseFlag(t *testing.T) {
	// single_use byte must round-trip verbatim.
	src := &IteratorNode{
		SourceKind: IterMap,
		SingleUse:  true,
		SourceArgs: []Node{&ScalarNode{DataType: "int", Value: int64(1)}},
	}
	doc, err := decodeAST(stripFrame(encodeAST(wrapDoc(src))))
	if err != nil {
		t.Fatalf("decodeAST: %v", err)
	}
	out := doc.Elements[0].(*IteratorNode)
	if !out.SingleUse {
		t.Errorf("SingleUse lost across wire")
	}
	if out.SourceKind != IterMap {
		t.Errorf("SourceKind = %d, want IterMap", out.SourceKind)
	}
}

func TestIteratorRoundTripNestedClosure(t *testing.T) {
	// combinator slot-1 closure is an EvalDirective and
	// round-trips through ast_bin via the existing tag 0x0E.
	innerIter := &IteratorNode{
		SourceKind: IterRange,
		SourceArgs: []Node{
			&ScalarNode{DataType: "int", Value: int64(0)},
			&ScalarNode{DataType: "int", Value: int64(3)},
		},
	}
	closure := &EvalDirectiveNode{
		Name:  "fn",
		Attrs: []Attr{{Name: "x", Value: "x", DataType: ""}},
		Items: []Node{&ScalarNode{DataType: "int", Value: int64(42)}},
	}
	src := &IteratorNode{
		SourceKind: IterMap,
		SourceArgs: []Node{innerIter, closure},
	}
	doc, err := decodeAST(stripFrame(encodeAST(wrapDoc(src))))
	if err != nil {
		t.Fatalf("decodeAST: %v", err)
	}
	out := doc.Elements[0].(*IteratorNode)
	if out.SourceKind != IterMap {
		t.Errorf("outer SourceKind = %d, want IterMap", out.SourceKind)
	}
	if len(out.SourceArgs) != 2 {
		t.Fatalf("SourceArgs len = %d, want 2", len(out.SourceArgs))
	}
	nested, ok := out.SourceArgs[0].(*IteratorNode)
	if !ok {
		t.Fatalf("nested arg[0] type = %T, want *IteratorNode", out.SourceArgs[0])
	}
	if nested.SourceKind != IterRange {
		t.Errorf("nested SourceKind = %d, want IterRange", nested.SourceKind)
	}
	closureOut, ok := out.SourceArgs[1].(*EvalDirectiveNode)
	if !ok {
		t.Fatalf("closure arg[1] type = %T, want *EvalDirectiveNode", out.SourceArgs[1])
	}
	if closureOut.Name != "fn" {
		t.Errorf("closure name = %q, want fn", closureOut.Name)
	}
}

func TestIteratorRoundTripAllW3aW3cKinds(t *testing.T) {
	// v0.8.0 producers MUST emit only ordinals 0..16.
	// All non-zero W3a/W3c kinds must round-trip cleanly.
	for kind := IterRange; kind <= IterReduce; kind++ {
		k := kind
		t.Run(IterKindName(k), func(t *testing.T) {
			src := &IteratorNode{
				SourceKind: k,
				SourceArgs: []Node{&ScalarNode{DataType: "int", Value: int64(int(k))}},
			}
			doc, err := decodeAST(stripFrame(encodeAST(wrapDoc(src))))
			if err != nil {
				t.Fatalf("decodeAST: %v", err)
			}
			out, ok := doc.Elements[0].(*IteratorNode)
			if !ok {
				t.Fatalf("type = %T, want *IteratorNode", doc.Elements[0])
			}
			if out.SourceKind != k {
				t.Errorf("SourceKind = %d, want %d", out.SourceKind, k)
			}
		})
	}
}

// ── error path ─────────────────────────────────────────────

func TestIteratorDecodeRejectsUnknownKindOrdinal(t *testing.T) {
	// Hand-craft a buffer with kind ordinal 0xFF — above the
	// IterReduce ceiling (16). Decoder MUST reject.
	buf := []byte{}
	buf = append(buf, 0x05)       // version
	buf = append(buf, 0x00, 0x00) // prolog count = 0
	buf = append(buf, 0x01, 0x00) // element count = 1
	buf = append(buf, 0x16)       // Iterator tag
	buf = append(buf, 0xFF)       // bogus source_kind ordinal
	buf = append(buf, 0x00)       // single_use
	buf = append(buf, 0x00, 0x00) // source_args_count = 0

	_, err := decodeAST(buf)
	if err == nil {
		t.Fatalf("expected error on unknown ordinal 0xFF")
	}
	if !strings.Contains(err.Error(), "IteratorSourceKind") {
		t.Errorf("error message %q lacks 'IteratorSourceKind'", err.Error())
	}
	if !strings.Contains(err.Error(), "255") {
		t.Errorf("error message %q lacks ordinal 255", err.Error())
	}
}
