package cxlib

import (
	"encoding/json"
	"strings"
	"testing"
)

// Tests for the ID/IDREF C ABI surface (cx_id_lookup / cx_resolve_ref /
// cx_node_id) per ADR 0003 / Phase 7.65. Document-level resolve is
// already tested by identity_test.go; these exercise the stateless
// string-in/string-out C ABI variants.

const idAbiDoc = `[users
  [user #u-1 name=alice]
  [user #u-2 name=bob]
  [reviewer assigned-to=@u-1]
]`

func TestIDLookupReturnsAstJSON(t *testing.T) {
	out, err := IDLookup(idAbiDoc, "u-1")
	if err != nil {
		t.Fatal(err)
	}
	if out == "" {
		t.Fatal("expected non-empty result")
	}
	var payload map[string]interface{}
	if err := json.Unmarshal([]byte(out), &payload); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	if payload["type"] != "Element" || payload["name"] != "user" || payload["id"] != "u-1" {
		t.Fatalf("payload = %v", payload)
	}
}

func TestIDLookupMissingReturnsEmpty(t *testing.T) {
	out, err := IDLookup(idAbiDoc, "does-not-exist")
	if err != nil {
		t.Fatal(err)
	}
	if out != "" {
		t.Fatalf("expected empty, got %q", out)
	}
}

func TestResolveRefMatchesIDLookup(t *testing.T) {
	a, err := IDLookup(idAbiDoc, "u-2")
	if err != nil {
		t.Fatal(err)
	}
	b, err := ResolveRef(idAbiDoc, "u-2")
	if err != nil {
		t.Fatal(err)
	}
	if a != b {
		t.Fatalf("resolve_ref %q != id_lookup %q", b, a)
	}
}

func TestNodeIDForIDBearingElement(t *testing.T) {
	out, err := NodeID(idAbiDoc, "//user")
	if err != nil {
		t.Fatal(err)
	}
	if out != "u-1" {
		t.Fatalf("NodeID(//user) = %q, want u-1", out)
	}
}

func TestNodeIDEmptyForNonIDBearing(t *testing.T) {
	out, err := NodeID(idAbiDoc, "//reviewer")
	if err != nil {
		t.Fatal(err)
	}
	if out != "" {
		t.Fatalf("NodeID(//reviewer) = %q, want empty", out)
	}
}

func TestIDLookupParseError(t *testing.T) {
	_, err := IDLookup("[unclosed", "u-1")
	if err == nil {
		t.Fatal("expected parse error")
	}
	if !strings.Contains(err.Error(), "expect") && !strings.Contains(err.Error(), "parse") && !strings.Contains(err.Error(), "unexpected") && !strings.Contains(err.Error(), "EOF") {
		t.Logf("error: %v", err)
	}
}
