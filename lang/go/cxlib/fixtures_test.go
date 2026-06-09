package cxlib

import "testing"

// TestLoadFixturesCanary is the inline-string bootstrap guard (mirror of the
// V-side test_loader_parser_canary): parse a tiny .cxd-shaped document — no
// file load — and assert the loader reconstructs legacy-shaped fields.
func TestLoadFixturesCanary(t *testing.T) {
	src := "[test-suite\n" +
		"[case id=canary-001 level=core\n" +
		"[tags a b c]\n" +
		"[in-cx [#\n[doc [x 1]]\n#]]\n" +
		"[in-code [#\n[?find [x]]\n#]]\n" +
		"]\n" +
		"]"
	cases, err := ParseFixtureSuite(src, "<canary>")
	if err != nil {
		t.Fatalf("ParseFixtureSuite: %v", err)
	}
	if len(cases) != 1 {
		t.Fatalf("expected 1 case, got %d", len(cases))
	}
	c := cases[0]
	if c.Name != "canary-001" || c.Level != "core" {
		t.Errorf("name/level = %q/%q", c.Name, c.Level)
	}
	if got := c.Sections["in_cx"]; got != "[doc [x 1]]" {
		t.Errorf("in_cx = %q", got)
	}
	if len(c.Tags) != 3 || c.Tags[0] != "a" {
		t.Errorf("tags = %v", c.Tags)
	}
}

// TestLoadFixturesRawTextDashes — a `---` inside a RawText payload must NOT
// split the suite (Task 1 multidoc regression).
func TestLoadFixturesRawTextDashes(t *testing.T) {
	src := "[test-suite\n[case id=md-001\n[in-cx [#\n[a]\n---\n[b]\n#]]\n]\n]"
	cases, err := ParseFixtureSuite(src, "<canary>")
	if err != nil {
		t.Fatalf("ParseFixtureSuite: %v", err)
	}
	if len(cases) != 1 || cases[0].Sections["in_cx"] != "[a]\n---\n[b]" {
		t.Fatalf("rawtext dashes: %+v", cases)
	}
}

// TestCollectionDecode — regression for the v0.8.0 collection node tags
// (0x0F/0x10/0x11). Before the fix the Go decoder's default case returned an
// empty TextNode without consuming the payload, desyncing the stream.
func TestCollectionDecode(t *testing.T) {
	doc, err := Parse("[s [a [:S002]] [b [:S003]]]")
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	s := doc.Root()
	if s == nil || len(s.Items) != 2 {
		t.Fatalf("root: %+v", s)
	}
	a := s.Items[0].(*Element)
	if arr, ok := a.Items[0].(*ArrayNode); !ok || len(arr.Items) != 1 {
		t.Fatalf("expected *ArrayNode w/ 1 item, got %T", a.Items[0])
	}
	for _, src := range []string{"[x (1, 2, 3)]", "[x [1, 2, 3]]", "[x {k: 1, j: 2}]"} {
		if _, err := Parse(src); err != nil {
			t.Errorf("parse %q: %v", src, err)
		}
	}
}
