package cxlib

// CX-native conformance fixture loader — Go mirror of
// vcx/cx/fixture_loader.v (and lang/python/cxlib/fixtures.py).
//
// The canonical fixture format is the CX document (conformance/*.cxd, schema
// conformance/fixtures.cxs). This loader reads a suite via the CX parser
// itself (Parse → libcx C ABI) and reconstructs each [case …] into the
// legacy-shaped fields the test consumers expect, replacing the per-consumer
// hand-rolled `=== test:` / `--- key` text parsers.
//
// Section keys are returned in their LEGACY snake_case form (in_cx, out_ast,
// sv_expected_codes, …) so consumers key into Sections exactly as they did
// against the old .txt. Typed sections (atom arrays / bools) are rendered
// back to their legacy textual form.

import (
	"fmt"
	"os"
	"strings"
)

// FixtureCase mirrors fixture_loader.v's FixtureCase.
type FixtureCase struct {
	Name     string // legacy test name: id, plus " " + title when titled
	Level    string // "" when the case carried no level
	Tags     []string
	Meta     map[string]string // extra header lines: view/kind/note/chunk_at/pending/…
	Sections map[string]string // legacy section key -> normalized body
	Order    []string          // section keys, document order
}

// LoadFixtures parses a .cxd conformance suite and returns its cases.
func LoadFixtures(path string) ([]FixtureCase, error) {
	src, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("LoadFixtures: cannot read %s: %w", path, err)
	}
	return ParseFixtureSuite(string(src), path)
}

// ParseFixtureSuite parses suite text already in memory (path is for errors).
//
// Uses Parse (the single-document entry point). A suite payload may contain a
// `---` line inside a RawText block (CX multi-doc examples under test); the
// lexer consumes `---` inside RawText correctly and only treats a top-level
// `---` as a separator, so such a suite parses to a single intact document.
func ParseFixtureSuite(src, path string) ([]FixtureCase, error) {
	doc, err := Parse(src)
	if err != nil {
		return nil, fmt.Errorf("LoadFixtures: parse error in %s: %w", path, err)
	}
	var cases []FixtureCase
	root := doc.Root()
	if root == nil || root.Name != "test-suite" {
		return cases, nil
	}
	for _, child := range root.Items {
		if el, ok := child.(*Element); ok && el.Name == "case" {
			cases = append(cases, fixtureCaseFrom(el))
		}
	}
	return cases, nil
}

func fixtureCaseFrom(c *Element) FixtureCase {
	fc := FixtureCase{
		Meta:     map[string]string{},
		Sections: map[string]string{},
	}
	var id, title string
	for _, a := range c.Attrs {
		switch a.Name {
		case "id":
			id = scalarStr(a.Value)
		case "level":
			fc.Level = scalarStr(a.Value)
		}
	}
	for _, child := range c.Items {
		el, ok := child.(*Element)
		if !ok {
			continue
		}
		switch el.Name {
		case "title":
			title = fixtureRawtext(el) // inline [#…#] — exact, no normalize
		case "tags":
			fc.Tags = splitFields(fixtureText(el))
		case "meta":
			body := fixtureNormalize(fixtureRawtext(el))
			for _, line := range strings.Split(body, "\n") {
				idx := strings.IndexByte(line, ':')
				if idx < 0 {
					continue
				}
				fc.Meta[strings.TrimSpace(line[:idx])] = strings.TrimSpace(line[idx+1:])
			}
		case "expect-valid":
			if fixtureBool(el) {
				fc.Sections["sv_assert_valid"] = "1"
			} else {
				fc.Sections["sv_assert_valid"] = "0"
			}
			fc.Order = append(fc.Order, "sv_assert_valid")
		case "expect-codes":
			fc.Sections["sv_expected_codes"] = fixtureAtomCSV(el)
			fc.Order = append(fc.Order, "sv_expected_codes")
		case "expect-warn-codes":
			fc.Sections["sv_expected_warn_codes"] = fixtureAtomCSV(el)
			fc.Order = append(fc.Order, "sv_expected_warn_codes")
		default:
			key := strings.ReplaceAll(el.Name, "-", "_")
			fc.Sections[key] = fixtureNormalize(fixtureRawtext(el))
			fc.Order = append(fc.Order, key)
		}
	}
	if title != "" {
		fc.Name = id + " " + title
	} else {
		fc.Name = id
	}
	return fc
}

// fixtureRawtext concatenates the RawText payload(s) of a section element. (A
// literal `#]` in the payload is carried as adjacent RawText siblings;
// concatenation rejoins them.)
func fixtureRawtext(e *Element) string {
	var b strings.Builder
	for _, it := range e.Items {
		if rt, ok := it.(*RawTextNode); ok {
			b.WriteString(rt.Value)
		}
	}
	return b.String()
}

// fixtureText joins text/scalar body (used for the tags line).
func fixtureText(e *Element) string {
	var b strings.Builder
	for _, it := range e.Items {
		switch n := it.(type) {
		case *TextNode:
			b.WriteString(n.Value)
		case *ScalarNode:
			b.WriteString(scalarStr(n.Value))
		}
	}
	return b.String()
}

// fixtureNormalize is the loader rule: strip one leading and one trailing
// newline (the ones introduced by the `[#` ⏎ … ⏎ `#]` layout).
func fixtureNormalize(raw string) string {
	s := raw
	s = strings.TrimPrefix(s, "\n")
	s = strings.TrimSuffix(s, "\n")
	return s
}

func fixtureBool(e *Element) bool {
	for _, it := range e.Items {
		if s, ok := it.(*ScalarNode); ok {
			if b, ok := s.Value.(bool); ok {
				return b
			}
		}
	}
	return false
}

func fixtureAtomCSV(e *Element) string {
	var names []string
	for _, it := range e.Items {
		// The array-literal section body decodes to a collection node
		// (ArrayNode) whose items are atom scalars.
		arr, ok := it.(*ArrayNode)
		if !ok {
			continue
		}
		for _, item := range arr.Items {
			if s, ok := item.(*ScalarNode); ok {
				if name, ok := AtomName(s.Value); ok {
					names = append(names, name)
				} else if str, ok := s.Value.(string); ok {
					names = append(names, str)
				}
			}
		}
	}
	return strings.Join(names, ",")
}

// scalarStr renders an attr/scalar value to its plain string form.
func scalarStr(v any) string {
	if name, ok := AtomName(v); ok {
		return name
	}
	switch x := v.(type) {
	case bool:
		if x {
			return "true"
		}
		return "false"
	case nil:
		return "null"
	case string:
		return x
	default:
		return fmt.Sprint(x)
	}
}

// splitFields splits on runs of spaces/tabs and drops empties (mirrors the V
// loader's tags split_any(' \t')).
func splitFields(s string) []string {
	var out []string
	for _, f := range strings.FieldsFunc(s, func(r rune) bool { return r == ' ' || r == '\t' }) {
		if f != "" {
			out = append(out, f)
		}
	}
	return out
}
