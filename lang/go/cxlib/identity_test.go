package cxlib

import (
	"strings"
	"testing"
)

// Tests for ID/IDREF resolution per ADR 0003 / spec/identity.md.
// Mirrors V's conformance/identity.txt cases.

func TestIdentityDeclarationOnlyRoundTrips(t *testing.T) {
	in := "[user #u-1 name=alice]"
	doc, err := Parse(in)
	if err != nil {
		t.Fatal(err)
	}
	user := doc.Root()
	if user.Id != "u-1" {
		t.Fatalf("Id = %q, want u-1", user.Id)
	}
	got := doc.ToCx()
	if got != in {
		t.Fatalf("round-trip:\n got: %q\nwant: %q", got, in)
	}
}

func TestIdentityWithAnchorCoexists(t *testing.T) {
	doc, err := Parse("[item &a #u-1 v=42]")
	if err != nil {
		t.Fatal(err)
	}
	item := doc.Root()
	if item.Anchor != "a" || item.Id != "u-1" {
		t.Fatalf("Anchor=%q Id=%q, want a / u-1", item.Anchor, item.Id)
	}
}

func TestIdentityAttributeValueRefMarked(t *testing.T) {
	doc, err := Parse("[users [user #u-1 name=alice] [reviewer assigned-to=@u-1]]")
	if err != nil {
		t.Fatal(err)
	}
	reviewer := doc.FindFirst("reviewer")
	for _, a := range reviewer.Attrs {
		if a.Name == "assigned-to" {
			if !a.IsRef || a.Value != "u-1" {
				t.Fatalf("attr=%+v, want IsRef=true Value=u-1", a)
			}
			return
		}
	}
	t.Fatal("assigned-to attr missing")
}

func TestIdentityResolveID(t *testing.T) {
	doc, err := Parse("[users [user #u-1 name=alice] [user #u-2 name=bob]]")
	if err != nil {
		t.Fatal(err)
	}
	if el := doc.ResolveID("u-1"); el == nil || el.Attr("name") != "alice" {
		t.Fatalf("ResolveID(u-1) = %v", el)
	}
	if el := doc.ResolveID("u-2"); el == nil || el.Attr("name") != "bob" {
		t.Fatalf("ResolveID(u-2) = %v", el)
	}
	if doc.ResolveID("u-3") != nil {
		t.Fatal("ResolveID(u-3) should be nil")
	}
}

func TestIdentityElementsByID(t *testing.T) {
	doc, err := Parse("[a #x v=1] [b #y v=2] [c #z v=3]")
	if err != nil {
		t.Fatal(err)
	}
	m := doc.ElementsByID()
	if len(m) != 3 || m["x"].Name != "a" || m["y"].Name != "b" || m["z"].Name != "c" {
		t.Fatalf("ElementsByID() = %v", m)
	}
}

func TestIdentityQuotedAtLiteralIsNotRef(t *testing.T) {
	in := "[item label='@literal']"
	doc, err := Parse(in)
	if err != nil {
		t.Fatal(err)
	}
	for _, a := range doc.Root().Attrs {
		if a.Name == "label" {
			if a.IsRef || a.Value != "@literal" {
				t.Fatalf("attr=%+v, want IsRef=false Value=@literal", a)
			}
		}
	}
	if got := doc.ToCx(); got != in {
		t.Fatalf("round-trip: got %q want %q", got, in)
	}
}

func TestIdentityForwardReferenceResolves(t *testing.T) {
	doc, err := Parse("[users [reviewer assigned-to=@u-1] [user #u-1 name=alice]]")
	if err != nil {
		t.Fatal(err)
	}
	user := doc.ResolveID("u-1")
	if user == nil || user.Attr("name") != "alice" {
		t.Fatalf("forward ref: %v", user)
	}
}

func TestIdentityNestedRoundTrip(t *testing.T) {
	in := "[doc\n  [users\n    [user #u-1 name=alice]\n  ]\n  [reviews\n    [review target=@u-1 score=5]\n  ]\n]"
	doc, err := Parse(in)
	if err != nil {
		t.Fatal(err)
	}
	if doc.ResolveID("u-1") == nil {
		t.Fatal("u-1 should resolve")
	}
	review := doc.FindFirst("review")
	for _, a := range review.Attrs {
		if a.Name == "target" && (!a.IsRef || a.Value != "u-1") {
			t.Fatalf("target attr = %+v", a)
		}
	}
}

func TestIdentityMultipleRefsToSameID(t *testing.T) {
	doc, err := Parse(
		"[users [user #u-1 name=alice] " +
			"[reviewer assigned-to=@u-1] " +
			"[approver checked-by=@u-1]]")
	if err != nil {
		t.Fatal(err)
	}
	count := 0
	for _, el := range append(doc.FindAll("reviewer"), doc.FindAll("approver")...) {
		for _, a := range el.Attrs {
			if a.IsRef && a.Value == "u-1" {
				count++
			}
		}
	}
	if count != 2 {
		t.Fatalf("expected 2 IsRef attrs, got %d", count)
	}
}


// TestBodyRefSurvivesAstBinRoundTrip — Phase 7.70: ast_bin v3 carries
// body_ref through the V↔binding boundary. The field is populated
// post-parse from the v3 wire bytes, not re-detected from text.
func TestBodyRefSurvivesAstBinRoundTrip(t *testing.T) {
	in := "[doc [section #section-3 [para See [ref @section-3].]]]"
	doc, err := Parse(in)
	if err != nil {
		t.Fatal(err)
	}
	section := doc.FindFirst("section")
	if section == nil {
		t.Fatal("section not found")
	}
	para := section.FindFirst("para")
	if para == nil {
		t.Fatal("para not found")
	}
	var refNode *Element
	for _, c := range para.Items {
		if el, ok := c.(*Element); ok && el.Name == "ref" {
			refNode = el
			break
		}
	}
	if refNode == nil {
		t.Fatal("ref node not found in para body")
	}
	if refNode.BodyRef != "section-3" {
		t.Fatalf("BodyRef = %q, want %q", refNode.BodyRef, "section-3")
	}
	if len(refNode.Attrs) != 0 {
		t.Fatalf("ref node should have no attrs, got %d", len(refNode.Attrs))
	}
	if len(refNode.Items) != 0 {
		t.Fatalf("ref node should have no items, got %d", len(refNode.Items))
	}
	out := doc.ToCx()
	if !strings.Contains(out, "[ref @section-3]") {
		t.Fatalf("CX emit lost body_ref: %s", out)
	}
}
