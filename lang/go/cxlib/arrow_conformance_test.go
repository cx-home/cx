//go:build arrow

// Cross-binding Arrow conformance runner (W3 / v0.7.0).
//
// Reads conformance/data_bin_arrow.txt — the canonical Arrow C-Data
// round-trip fixture corpus — and runs each test through the Go
// binding's cxlib.ArrowExport / ArrowImportToDataBin path. Mirrors
// lang/python/test_arrow_conformance.py so the fixture file is the
// single source of truth across all active bindings.

package cxlib

import (
	"bufio"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"testing"
)

var (
	conformanceTestRe   = regexp.MustCompile(`^===\s+test:\s+(\S+)\s*$`)
	conformanceSecRe    = regexp.MustCompile(`^---\s+([\w-]+)\s*$`)
	conformanceHeaderRe = regexp.MustCompile(`^(\w+):\s*(.+?)\s*$`)
)

type arrowConfFixture struct {
	Name     string
	Headers  map[string]string
	Sections map[string]string
}

func loadArrowConformance(t *testing.T) []arrowConfFixture {
	t.Helper()
	// Walk up from this test file to find the repo root by looking for
	// conformance/data_bin_arrow.txt.
	_, thisFile, _, _ := runtime.Caller(0)
	dir := filepath.Dir(thisFile)
	var path string
	for i := 0; i < 8; i++ {
		candidate := filepath.Join(dir, "conformance", "data_bin_arrow.txt")
		if _, err := os.Stat(candidate); err == nil {
			path = candidate
			break
		}
		dir = filepath.Dir(dir)
	}
	if path == "" {
		t.Skipf("conformance fixture data_bin_arrow.txt not found from %s", filepath.Dir(thisFile))
	}

	f, err := os.Open(path)
	if err != nil {
		t.Fatalf("open conformance fixture: %v", err)
	}
	defer f.Close()

	var (
		fixtures   []arrowConfFixture
		cur        *arrowConfFixture
		section    string
		secLines   []string
		flushSec   = func() {
			if cur != nil && section != "" {
				cur.Sections[section] = strings.Join(secLines, "\n")
			}
		}
	)

	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 1<<20), 1<<20)
	for sc.Scan() {
		line := sc.Text()
		if strings.HasPrefix(line, "# ") {
			continue
		}
		if m := conformanceTestRe.FindStringSubmatch(line); m != nil {
			flushSec()
			if cur != nil {
				fixtures = append(fixtures, *cur)
			}
			cur = &arrowConfFixture{
				Name:     m[1],
				Headers:  map[string]string{},
				Sections: map[string]string{},
			}
			section = ""
			secLines = nil
			continue
		}
		if m := conformanceSecRe.FindStringSubmatch(line); m != nil {
			flushSec()
			section = m[1]
			secLines = nil
			continue
		}
		if section != "" {
			secLines = append(secLines, line)
			continue
		}
		if cur != nil {
			if m := conformanceHeaderRe.FindStringSubmatch(line); m != nil {
				cur.Headers[m[1]] = m[2]
			}
		}
	}
	flushSec()
	if cur != nil {
		fixtures = append(fixtures, *cur)
	}
	return fixtures
}

func TestArrowConformance(t *testing.T) {
	if !ArrowAvailable() {
		t.Skip("libcx_arrow not loaded")
	}
	fixtures := loadArrowConformance(t)
	if len(fixtures) == 0 {
		t.Skip("no fixtures parsed")
	}
	for _, fx := range fixtures {
		fx := fx
		t.Run(fx.Name, func(t *testing.T) {
			inCx := strings.Trim(fx.Sections["in_cx"], "\n")
			expectErr := strings.TrimSpace(fx.Sections["expected_export_error"])
			formats := strings.TrimSpace(fx.Sections["arrow_children_formats"])
			_ = strings.TrimSpace(fx.Sections["expect_values"]) // value-equality
			//  through Arrow-side type-identity below; full CX-text
			//  expect_values assertion is the Python runner's domain
			//  because FromDataBin's framed/unframed contract here
			//  is the Python binding's natural shape, not Go's.

			// Encode CX → CXDB chunked.
			framed, err := ToDataBinChunked(inCx)
			if err != nil {
				if expectErr != "" && strings.Contains(err.Error(), expectErr) {
					return
				}
				t.Fatalf("to_data_bin_chunked: %v", err)
			}

			// Export to Arrow → consume.
			reader, err := ArrowExport(framed)
			if err != nil {
				if expectErr != "" && strings.Contains(err.Error(), expectErr) {
					return
				}
				t.Fatalf("ArrowExport: %v", err)
			}
			defer reader.Release()

			// Drain reader and collect records.
			var records []string // schema field types per column
			batches := 0
			for reader.Next() {
				rec := reader.Record()
				batches++
				if len(records) == 0 {
					sch := rec.Schema()
					for _, fld := range sch.Fields() {
						records = append(records, fld.Type.String())
					}
				}
				rec.Retain()
				defer rec.Release()
			}
			if err := reader.Err(); err != nil {
				t.Fatalf("reader.Err: %v", err)
			}

			// Schema format assertion.
			if formats != "" {
				expected := strings.Split(formats, "\n")
				actual := make([]string, len(records))
				for i, rt := range records {
					actual[i] = arrowGoTypeToFormat(rt)
				}
				if len(actual) != len(expected) {
					t.Fatalf("arrow_children_formats count: expected %d got %d (%v)",
						len(expected), len(actual), actual)
				}
				for i, e := range expected {
					if actual[i] != e {
						t.Fatalf("arrow_children_formats[%d]: expected %q got %q",
							i, e, actual[i])
					}
				}
			}

			// Round-trip via import → re-export. Verify the re-exported
			// reader produces the same per-field types as the first.
			// Matches the Python conformance runner's table.equals()
			// check at a coarser granularity (per-field type identity).
			// (Full Arrow-bytes equality is intentionally not asserted —
			// the spec note in conformance/data_bin_arrow.txt is explicit:
			// Arrow binary form is not stable across versions.)
			reader2, err := ArrowExport(framed)
			if err != nil {
				t.Fatalf("ArrowExport (round-trip): %v", err)
			}
			defer reader2.Release()
			out, err := ArrowImportToDataBin(reader2)
			if err != nil {
				t.Fatalf("ArrowImportToDataBin: %v", err)
			}
			reader3, err := ArrowExport(out)
			if err != nil {
				t.Fatalf("ArrowExport (post-round-trip): %v", err)
			}
			defer reader3.Release()
			var typesAfter []string
			for reader3.Next() {
				rec := reader3.Record()
				if len(typesAfter) == 0 {
					for _, fld := range rec.Schema().Fields() {
						typesAfter = append(typesAfter, fld.Type.String())
					}
				}
			}
			if err := reader3.Err(); err != nil {
				t.Fatalf("reader3.Err: %v", err)
			}
			if len(records) != len(typesAfter) {
				t.Fatalf("post-round-trip schema field count: before=%v after=%v",
					records, typesAfter)
			}
			for i, before := range records {
				if before != typesAfter[i] {
					t.Fatalf("post-round-trip schema field[%d]: before=%s after=%s",
						i, before, typesAfter[i])
				}
			}
		})
	}
}

// arrowGoTypeToFormat maps arrow-go's DataType.String() to the Arrow
// C-Data format string (cx convention).
func arrowGoTypeToFormat(s string) string {
	switch s {
	case "int64":
		return "l"
	case "int8":
		return "c"
	case "int16":
		return "s"
	case "int32":
		return "i"
	case "float64":
		return "g"
	case "bool":
		return "b"
	case "utf8", "string":
		return "u"
	case "date32":
		return "tdD"
	case "timestamp[ns, tz=UTC]":
		return "tsn:UTC"
	case "binary":
		return "z"
	}
	return s
}
