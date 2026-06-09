package cxlib

import (
	"encoding/binary"
	"strings"
	"testing"
)

// Round-trip tests for the Go data_bin one-shot wrappers
// (Phase 7.28 V core; Phase 7.31 Go binding).
//
// Loaders return UNFRAMED payload bytes (matching ToDataBin's
// convention; extractBinPayload strips the [u32 LE size] header).
// Dumpers expect FRAMED input (matching FromDataBin's convention).
// Tests use reframe() to bridge the two when round-tripping.

// reframe prepends a [u32 LE size] header to a payload.
func reframe(payload []byte) []byte {
	out := make([]byte, 4+len(payload))
	binary.LittleEndian.PutUint32(out[:4], uint32(len(payload)))
	copy(out[4:], payload)
	return out
}

// ── XML one-shot ─────────────────────────────────────────────────────────────

func TestXmlToDataBinReturnsCXColPayload(t *testing.T) {
	payload, err := XmlToDataBin("<server><host>localhost</host><port>8080</port></server>")
	if err != nil {
		t.Fatalf("XmlToDataBin: %v", err)
	}
	if len(payload) < 5 {
		t.Fatalf("expected non-empty payload, got %d bytes", len(payload))
	}
	// Magic check: payload starts with 5-byte "CXCol" magic.
	if string(payload[:5]) != "CXCol" {
		t.Fatalf("expected CXCol magic, got %q", string(payload[:5]))
	}
}

func TestXmlRoundTripThroughDataBin(t *testing.T) {
	payload, err := XmlToDataBin("<server><host>localhost</host><port>8080</port></server>")
	if err != nil {
		t.Fatalf("XmlToDataBin: %v", err)
	}
	out, err := DataBinToXml(reframe(payload))
	if err != nil {
		t.Fatalf("DataBinToXml: %v", err)
	}
	if !strings.Contains(out, "server") || !strings.Contains(out, "localhost") || !strings.Contains(out, "8080") {
		t.Fatalf("expected server/localhost/8080 in xml output, got: %s", out)
	}
}

// ── JSON one-shot ────────────────────────────────────────────────────────────

func TestJsonRoundTripThroughDataBin(t *testing.T) {
	payload, err := JsonToDataBin(`{"name": "alice", "id": 1}`)
	if err != nil {
		t.Fatalf("JsonToDataBin: %v", err)
	}
	out, err := DataBinToJson(reframe(payload))
	if err != nil {
		t.Fatalf("DataBinToJson: %v", err)
	}
	if !strings.Contains(out, "alice") || !strings.Contains(out, "1") {
		t.Fatalf("expected alice/1 in json output, got: %s", out)
	}
}

// ── YAML one-shot ────────────────────────────────────────────────────────────

func TestYamlRoundTripThroughDataBin(t *testing.T) {
	payload, err := YamlToDataBin("name: alice\nid: 1\n")
	if err != nil {
		t.Fatalf("YamlToDataBin: %v", err)
	}
	out, err := DataBinToYaml(reframe(payload))
	if err != nil {
		t.Fatalf("DataBinToYaml: %v", err)
	}
	if !strings.Contains(out, "alice") {
		t.Fatalf("expected alice in yaml output, got: %s", out)
	}
}

// ── TOML one-shot ────────────────────────────────────────────────────────────

func TestTomlRoundTripThroughDataBin(t *testing.T) {
	payload, err := TomlToDataBin(`name = "alice"
id = 1
`)
	if err != nil {
		t.Fatalf("TomlToDataBin: %v", err)
	}
	out, err := DataBinToToml(reframe(payload))
	if err != nil {
		t.Fatalf("DataBinToToml: %v", err)
	}
	if !strings.Contains(out, "alice") {
		t.Fatalf("expected alice in toml output, got: %s", out)
	}
}

// ── Cross-format compositions ────────────────────────────────────────────────

func TestXmlToDataBinToJson(t *testing.T) {
	payload, err := XmlToDataBin(`<user id="1" name="alice"/>`)
	if err != nil {
		t.Fatalf("XmlToDataBin: %v", err)
	}
	out, err := DataBinToJson(reframe(payload))
	if err != nil {
		t.Fatalf("DataBinToJson: %v", err)
	}
	if !strings.Contains(out, "alice") || !strings.Contains(out, "1") {
		t.Fatalf("expected alice/1 in json output, got: %s", out)
	}
}

func TestJsonToDataBinToYaml(t *testing.T) {
	payload, err := JsonToDataBin(`{"name": "alice", "active": true}`)
	if err != nil {
		t.Fatalf("JsonToDataBin: %v", err)
	}
	out, err := DataBinToYaml(reframe(payload))
	if err != nil {
		t.Fatalf("DataBinToYaml: %v", err)
	}
	if !strings.Contains(out, "alice") {
		t.Fatalf("expected alice in yaml output, got: %s", out)
	}
}

func TestTomlToDataBinToXml(t *testing.T) {
	payload, err := TomlToDataBin(`host = "localhost"
port = 8080
`)
	if err != nil {
		t.Fatalf("TomlToDataBin: %v", err)
	}
	out, err := DataBinToXml(reframe(payload))
	if err != nil {
		t.Fatalf("DataBinToXml: %v", err)
	}
	if !strings.Contains(out, "localhost") || !strings.Contains(out, "8080") {
		t.Fatalf("expected localhost/8080 in xml output, got: %s", out)
	}
}
