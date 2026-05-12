package cxlib

import "testing"

// Mirrors V core's conformance/namespaces.txt for the Go binding's
// LocalName() / NamespaceURI() accessor surface (ADR 0002).

func TestNamespacesDefaultInheritsToDescendants(t *testing.T) {
	doc, err := Parse("[html xmlns=http://www.w3.org/1999/xhtml [body [p Hi]]]")
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	html := doc.Root()
	if html.LocalName() != "html" {
		t.Errorf("html.LocalName() = %q, want %q", html.LocalName(), "html")
	}
	if html.NamespaceURI() != "http://www.w3.org/1999/xhtml" {
		t.Errorf("html.NamespaceURI() = %q", html.NamespaceURI())
	}
	body := html.Get("body")
	if body.NamespaceURI() != "http://www.w3.org/1999/xhtml" {
		t.Errorf("body inherited ns wrong: %q", body.NamespaceURI())
	}
}

func TestNamespacesDefaultDoesNotApplyToAttrs(t *testing.T) {
	doc, _ := Parse("[html xmlns=urn:x id=top body]")
	html := doc.Root()
	for _, a := range html.Attrs {
		if a.Name == "id" && a.NamespaceURI() != "" {
			t.Errorf("id attr must have no ns; got %q", a.NamespaceURI())
		}
	}
}

func TestNamespacesPrefixedElement(t *testing.T) {
	doc, _ := Parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ [dc:title Hello]]")
	title := doc.Root().Get("dc:title")
	if title.LocalName() != "title" || title.NamespaceURI() != "http://purl.org/dc/elements/1.1/" {
		t.Errorf("dc:title resolution wrong: local=%q ns=%q", title.LocalName(), title.NamespaceURI())
	}
}

func TestNamespacesPrefixedAttribute(t *testing.T) {
	doc, _ := Parse("[doc xmlns:xl=http://www.w3.org/1999/xlink [link xl:href=https://example.com Click]]")
	link := doc.Root().Get("link")
	for _, a := range link.Attrs {
		if a.Name == "xl:href" {
			if a.LocalName() != "href" || a.NamespaceURI() != "http://www.w3.org/1999/xlink" {
				t.Errorf("xl:href resolution wrong: local=%q ns=%q", a.LocalName(), a.NamespaceURI())
			}
			return
		}
	}
	t.Errorf("xl:href not found")
}

func TestNamespacesReservedXMLPrefix(t *testing.T) {
	doc, _ := Parse("[doc xml:base=https://example.com content]")
	for _, a := range doc.Root().Attrs {
		if a.Name == "xml:base" {
			if a.NamespaceURI() != XMLNamespaceURI {
				t.Errorf("xml:base wrong ns: %q", a.NamespaceURI())
			}
			return
		}
	}
	t.Errorf("xml:base not found")
}

func TestNamespacesReservedCXPrefix(t *testing.T) {
	doc, _ := Parse("[doc [cx:meta key=value]]")
	meta := doc.Root().Get("cx:meta")
	if meta.NamespaceURI() != CXNamespaceURI {
		t.Errorf("cx:meta wrong ns: %q", meta.NamespaceURI())
	}
}

func TestNamespacesUndeclaredPrefixPassesThrough(t *testing.T) {
	doc, _ := Parse("[doc [foo:bar baz]]")
	bar := doc.Root().Get("foo:bar")
	if bar.LocalName() != "bar" || bar.NamespaceURI() != "" {
		t.Errorf("foo:bar should have empty ns: local=%q ns=%q", bar.LocalName(), bar.NamespaceURI())
	}
}

func TestNamespacesRedeclarationOverridesDefault(t *testing.T) {
	doc, _ := Parse(`[html xmlns=http://www.w3.org/1999/xhtml
  [body
    [svg xmlns=http://www.w3.org/2000/svg
      [circle r=10]
    ]
  ]
]`)
	html := doc.Root()
	body := html.Get("body")
	svg := body.Get("svg")
	circle := svg.Get("circle")
	if html.NamespaceURI() != "http://www.w3.org/1999/xhtml" ||
		body.NamespaceURI() != "http://www.w3.org/1999/xhtml" ||
		svg.NamespaceURI() != "http://www.w3.org/2000/svg" ||
		circle.NamespaceURI() != "http://www.w3.org/2000/svg" {
		t.Errorf("svg redeclaration wrong: html=%q body=%q svg=%q circle=%q",
			html.NamespaceURI(), body.NamespaceURI(), svg.NamespaceURI(), circle.NamespaceURI())
	}
}

func TestNamespacesEmptyURIUndeclares(t *testing.T) {
	doc, _ := Parse("[outer xmlns=urn:x [inner xmlns='' [child x=1]]]")
	outer := doc.Root()
	inner := outer.Get("inner")
	child := inner.Get("child")
	if outer.NamespaceURI() != "urn:x" || inner.NamespaceURI() != "" || child.NamespaceURI() != "" {
		t.Errorf("undeclaration wrong: outer=%q inner=%q child=%q",
			outer.NamespaceURI(), inner.NamespaceURI(), child.NamespaceURI())
	}
}

func TestNamespacesIdempotent(t *testing.T) {
	doc, _ := Parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ [dc:title Hi]]")
	first := doc.Root().Get("dc:title").NamespaceURI()
	ResolveNamespaces(doc)
	ResolveNamespaces(doc)
	second := doc.Root().Get("dc:title").NamespaceURI()
	if first != second || first != "http://purl.org/dc/elements/1.1/" {
		t.Errorf("idempotent wrong: first=%q second=%q", first, second)
	}
}

func TestNamespacesXmlnsAttrItselfHasNoResolvedURI(t *testing.T) {
	doc, _ := Parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ body]")
	for _, a := range doc.Root().Attrs {
		if a.Name == "xmlns:dc" {
			if a.NamespaceURI() != "" {
				t.Errorf("xmlns:dc declaration must have empty ns; got %q", a.NamespaceURI())
			}
			if a.LocalName() != "dc" {
				t.Errorf("xmlns:dc.LocalName() = %q, want %q", a.LocalName(), "dc")
			}
			return
		}
	}
	t.Errorf("xmlns:dc not found")
}
