// CX Go conformance runner.
//
// Run: cd lang/go/conformance && go run .
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	cxlib "github.com/cx-home/cx/lang/go"
)

// ── suite parser ──────────────────────────────────────────────────────────────

type test struct {
	name     string
	sections map[string]string
}

func parseSuite(path string) ([]test, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	var tests []test
	var cur *test
	var section string
	var buf []string

	flush := func() {
		if cur != nil && section != "" {
			lines := buf
			for len(lines) > 0 && strings.TrimSpace(lines[0]) == "" {
				lines = lines[1:]
			}
			for len(lines) > 0 && strings.TrimSpace(lines[len(lines)-1]) == "" {
				lines = lines[:len(lines)-1]
			}
			cur.sections[section] = strings.Join(lines, "\n")
		}
		buf = buf[:0]
	}

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "=== test:") {
			flush()
			if cur != nil {
				tests = append(tests, *cur)
			}
			cur = &test{name: strings.TrimSpace(line[9:]), sections: make(map[string]string)}
			section = ""
		} else if strings.HasPrefix(line, "--- ") && cur != nil {
			flush()
			section = strings.TrimSpace(line[4:])
		} else if section != "" && cur != nil {
			buf = append(buf, line)
		}
	}
	flush()
	if cur != nil {
		tests = append(tests, *cur)
	}
	return tests, scanner.Err()
}

// ── dispatch ──────────────────────────────────────────────────────────────────

type convFn func(string) (string, error)

func dispatch(fmt, out string) convFn {
	type key struct{ in, out string }
	table := map[key]convFn{
		{"cx", "cx"}:     cxlib.ToCx,
		{"cx", "xml"}:    cxlib.ToXml,
		{"cx", "ast"}:    cxlib.ToAst,
		{"cx", "json"}:   cxlib.ToJson,
		{"cx", "yaml"}:   cxlib.ToYaml,
		{"cx", "toml"}:   cxlib.ToToml,
		{"cx", "md"}:     cxlib.ToMd,
		{"xml", "cx"}:    cxlib.XmlToCx,
		{"xml", "xml"}:   cxlib.XmlToXml,
		{"xml", "ast"}:   cxlib.XmlToAst,
		{"xml", "json"}:  cxlib.XmlToJson,
		{"xml", "yaml"}:  cxlib.XmlToYaml,
		{"xml", "toml"}:  cxlib.XmlToToml,
		{"xml", "md"}:    cxlib.XmlToMd,
		{"json", "cx"}:   cxlib.JsonToCx,
		{"json", "xml"}:  cxlib.JsonToXml,
		{"json", "ast"}:  cxlib.JsonToAst,
		{"json", "json"}: cxlib.JsonToJson,
		{"json", "yaml"}: cxlib.JsonToYaml,
		{"json", "toml"}: cxlib.JsonToToml,
		{"json", "md"}:   cxlib.JsonToMd,
		{"yaml", "cx"}:   cxlib.YamlToCx,
		{"yaml", "xml"}:  cxlib.YamlToXml,
		{"yaml", "ast"}:  cxlib.YamlToAst,
		{"yaml", "json"}: cxlib.YamlToJson,
		{"yaml", "yaml"}: cxlib.YamlToYaml,
		{"yaml", "toml"}: cxlib.YamlToToml,
		{"yaml", "md"}:   cxlib.YamlToMd,
		{"toml", "cx"}:   cxlib.TomlToCx,
		{"toml", "xml"}:  cxlib.TomlToXml,
		{"toml", "ast"}:  cxlib.TomlToAst,
		{"toml", "json"}: cxlib.TomlToJson,
		{"toml", "yaml"}: cxlib.TomlToYaml,
		{"toml", "toml"}: cxlib.TomlToToml,
		{"toml", "md"}:   cxlib.TomlToMd,
		{"md", "cx"}:     cxlib.MdToCx,
		{"md", "xml"}:    cxlib.MdToXml,
		{"md", "ast"}:    cxlib.MdToAst,
		{"md", "json"}:   cxlib.MdToJson,
		{"md", "yaml"}:   cxlib.MdToYaml,
		{"md", "toml"}:   cxlib.MdToToml,
		{"md", "md"}:     cxlib.MdToMd,
	}
	return table[key{fmt, out}]
}

// ── schema validator ──────────────────────────────────────────────────────────

func splitCodes(raw string) []string {
	out := []string{}
	for _, c := range strings.Split(raw, ",") {
		if t := strings.TrimSpace(c); t != "" {
			out = append(out, t)
		}
	}
	return out
}

func runSchemaValidatorTest(s map[string]string) []string {
	var failures []string
	report, err := cxlib.Validate(s["in_cx"], s["schema_cxs"])
	if err != nil {
		return []string{fmt.Sprintf("validate raised: %v", err)}
	}
	collectByseverity := func(sev cxlib.Severity) []string {
		out := []string{}
		for _, d := range report.Diagnostics {
			if d.Severity == sev {
				out = append(out, d.Code)
			}
		}
		return out
	}
	codesEqual := func(a, b []string) bool {
		if len(a) != len(b) {
			return false
		}
		for i := range a {
			if a[i] != b[i] {
				return false
			}
		}
		return true
	}

	if v, ok := s["sv_assert_valid"]; ok {
		if strings.TrimSpace(v) != "1" {
			failures = append(failures, fmt.Sprintf("sv_assert_valid: only \"1\" is supported, got %q", v))
		} else if !report.IsValid() {
			failures = append(failures, fmt.Sprintf("sv_assert_valid: expected zero error diagnostics, got %v", report.ErrorCodes()))
		}
	}
	if v, ok := s["sv_expected_codes"]; ok {
		expected := splitCodes(v)
		got := collectByseverity(cxlib.SeverityError)
		if !codesEqual(expected, got) {
			failures = append(failures, fmt.Sprintf("sv_expected_codes mismatch\n  expected: %v\n  got:      %v", expected, got))
		}
	}
	if v, ok := s["sv_expected_warn_codes"]; ok {
		expected := splitCodes(v)
		got := collectByseverity(cxlib.SeverityWarn)
		if !codesEqual(expected, got) {
			failures = append(failures, fmt.Sprintf("sv_expected_warn_codes mismatch\n  expected: %v\n  got:      %v", expected, got))
		}
	}
	if v, ok := s["sv_expected_info_codes"]; ok {
		expected := splitCodes(v)
		got := collectByseverity(cxlib.SeverityInfo)
		if !codesEqual(expected, got) {
			failures = append(failures, fmt.Sprintf("sv_expected_info_codes mismatch\n  expected: %v\n  got:      %v", expected, got))
		}
	}
	return failures
}

// ── streaming-write runner ────────────────────────────────────────────────────

func firstNonblankNoncomment(text string) string {
	for _, line := range strings.Split(text, "\n") {
		t := strings.TrimSpace(line)
		if t != "" && !strings.HasPrefix(t, "#") {
			return t
		}
	}
	return ""
}

func stripComments(text string) string {
	out := []string{}
	for _, ln := range strings.Split(text, "\n") {
		if !strings.HasPrefix(strings.TrimSpace(ln), "#") {
			out = append(out, ln)
		}
	}
	return strings.Join(out, "\n")
}

func decodeQuoted(s string) string {
	s = strings.TrimSpace(s)
	if strings.HasPrefix(s, `"`) && strings.HasSuffix(s, `"`) {
		return s[1 : len(s)-1]
	}
	return s
}

func hexBytes(s string) ([]byte, error) {
	s = strings.TrimSpace(s)
	out := make([]byte, len(s)/2)
	for i := 0; i < len(out); i++ {
		var b byte
		_, err := fmt.Sscanf(s[i*2:i*2+2], "%02x", &b)
		if err != nil {
			return nil, err
		}
		out[i] = b
	}
	return out, nil
}

func dispatchEvent(w *cxlib.EventWriter, line string) error {
	line = strings.TrimSpace(line)
	if line == "" || strings.HasPrefix(line, "#") {
		return nil
	}
	head, rest, _ := strings.Cut(line, " ")
	switch head {
	case "StartDoc":
		return w.StartDoc()
	case "EndDoc":
		return w.EndDoc()
	case "StartElement":
		toks := strings.Fields(rest)
		if len(toks) == 0 {
			return fmt.Errorf("StartElement: missing name")
		}
		name := toks[0]
		var anchor, dataType, merge *string
		for _, tok := range toks[1:] {
			if k, v, ok := strings.Cut(tok, "="); ok {
				vv := v
				switch k {
				case "anchor":    anchor = &vv
				case "data_type": dataType = &vv
				case "merge":     merge = &vv
				}
			}
		}
		return w.StartElementOpts(name, anchor, dataType, merge, nil)
	case "EndElement":
		return w.EndElement(strings.TrimSpace(rest))
	case "Text":
		return w.Text(decodeQuoted(rest))
	case "Scalar":
		typ, val, _ := strings.Cut(rest, ":")
		return w.Scalar(val, strings.TrimSpace(typ))
	case "Comment":
		return w.Comment(decodeQuoted(rest))
	case "PI":
		toks := strings.SplitN(rest, " ", 2)
		target := toks[0]
		data := ""
		if len(toks) > 1 && strings.HasPrefix(toks[1], "data=") {
			data = decodeQuoted(toks[1][5:])
		}
		return w.PI(target, data)
	case "EntityRef":
		return w.EntityRef(strings.TrimSpace(rest))
	case "RawText":
		return w.RawText(decodeQuoted(rest))
	case "Alias":
		return w.Alias(strings.TrimSpace(rest))
	case "StartTable":
		b, err := hexBytes(rest)
		if err != nil { return err }
		return w.StartTable(b)
	case "RowGroup":
		b, err := hexBytes(rest)
		if err != nil { return err }
		return w.RowGroup(b)
	case "EndTable":
		return w.EndTable()
	default:
		return fmt.Errorf("unknown event op: %q", head)
	}
}

func runStreamingWriteTest(s map[string]string) []string {
	fmtName := strings.TrimSpace(s["format"])
	expectErr := firstNonblankNoncomment(s["expect_err"])
	expectOk, hasOk := s["expect_ok"]
	expectOkContains, hasOkContains := s["expect_ok_contains"]
	if hasOk { expectOk = stripComments(expectOk) }
	if hasOkContains { expectOkContains = stripComments(expectOkContains) }

	w, err := cxlib.NewEventWriter(fmtName)
	if err != nil {
		if expectErr != "" && strings.Contains(err.Error(), expectErr) {
			return nil
		}
		return []string{fmt.Sprintf("NewEventWriter(%q): %v", fmtName, err)}
	}

	var triggered string
	for _, raw := range strings.Split(s["events"], "\n") {
		if err := dispatchEvent(w, raw); err != nil {
			triggered = err.Error()
			break
		}
	}

	if expectErr != "" {
		if triggered == "" {
			// Surface close-time errors.
			if _, ce := w.CloseGetBytes(); ce != nil {
				triggered = ce.Error()
			}
		}
		if triggered == "" {
			w.Close()
			return []string{fmt.Sprintf("expected %s but writer produced no error", expectErr)}
		}
		if !strings.Contains(triggered, expectErr) {
			return []string{fmt.Sprintf("expected %s in error, got %q", expectErr, triggered)}
		}
		return nil
	}

	if triggered != "" {
		w.Close()
		return []string{fmt.Sprintf("unexpected error: %s", triggered)}
	}
	out, err := w.CloseGetBytes()
	if err != nil {
		return []string{fmt.Sprintf("close_get_bytes: %v", err)}
	}
	outStr := string(out)
	var failures []string
	if hasOk {
		if strings.TrimSpace(expectOk) != strings.TrimSpace(outStr) {
			failures = append(failures, fmt.Sprintf("expect_ok mismatch\n  expected:\n%s\n  got:\n%s", expectOk, outStr))
		}
	}
	if hasOkContains {
		for _, needle := range strings.Split(expectOkContains, "\n") {
			n := strings.TrimSpace(needle)
			if n != "" && !strings.Contains(outStr, n) {
				failures = append(failures, fmt.Sprintf("expect_ok_contains: missing %q in output:\n%s", n, outStr))
			}
		}
	}
	return failures
}

// ── test runner ───────────────────────────────────────────────────────────────

func runTest(t test) []string {
	var failures []string
	s := t.sections

	// Streaming-write suite: events + format.
	if _, hasEvents := s["events"]; hasEvents {
		if _, hasFmt := s["format"]; hasFmt {
			return runStreamingWriteTest(s)
		}
	}

	// Schema validator suite: in_cx + schema_cxs paired with sv_* assertions.
	if _, hasSchema := s["schema_cxs"]; hasSchema {
		if _, hasDoc := s["in_cx"]; hasDoc {
			return runSchemaValidatorTest(s)
		}
	}

	var src, inFmt string
	for _, pair := range [][2]string{
		{"in_cx", "cx"}, {"in_xml", "xml"}, {"in_json", "json"},
		{"in_yaml", "yaml"}, {"in_toml", "toml"}, {"in_md", "md"},
	} {
		if v, ok := s[pair[0]]; ok {
			src, inFmt = v, pair[1]
			break
		}
	}
	if inFmt == "" {
		return failures
	}

	call := func(outFmt string) (string, error) {
		fn := dispatch(inFmt, outFmt)
		if fn == nil {
			return "", fmt.Errorf("no dispatch for %s->%s", inFmt, outFmt)
		}
		return fn(src)
	}

	// out_ast
	if exp, ok := s["out_ast"]; ok {
		out, err := call("ast")
		if err != nil {
			failures = append(failures, fmt.Sprintf("out_ast parse error: %v", err))
		} else {
			var expected, got interface{}
			if e := json.Unmarshal([]byte(exp), &expected); e != nil {
				failures = append(failures, fmt.Sprintf("out_ast: bad expected json: %v", e))
			} else if e := json.Unmarshal([]byte(out), &got); e != nil {
				failures = append(failures, fmt.Sprintf("out_ast: bad got json: %v", e))
			} else {
				eb, _ := json.Marshal(expected)
				gb, _ := json.Marshal(got)
				if string(eb) != string(gb) {
					failures = append(failures, fmt.Sprintf("out_ast mismatch\n  expected: %s\n  got:      %s", eb, gb))
				}
			}
		}
	}

	// out_xml
	if exp, ok := s["out_xml"]; ok {
		out, err := call("xml")
		if err != nil {
			failures = append(failures, fmt.Sprintf("out_xml parse error: %v", err))
		} else if strings.TrimSpace(exp) != strings.TrimSpace(out) {
			failures = append(failures, fmt.Sprintf("out_xml mismatch\n  expected:\n%s\n  got:\n%s", exp, out))
		}
	}

	// out_cx
	if exp, ok := s["out_cx"]; ok {
		out, err := call("cx")
		if err != nil {
			failures = append(failures, fmt.Sprintf("out_cx parse error: %v", err))
		} else if strings.TrimSpace(exp) != strings.TrimSpace(out) {
			failures = append(failures, fmt.Sprintf("out_cx mismatch\n  expected:\n%s\n  got:\n%s", exp, out))
		}
	}

	// out_json
	if exp, ok := s["out_json"]; ok {
		out, err := call("json")
		if err != nil {
			failures = append(failures, fmt.Sprintf("out_json parse error: %v", err))
		} else {
			var expected, got interface{}
			if e := json.Unmarshal([]byte(exp), &expected); e != nil {
				failures = append(failures, fmt.Sprintf("out_json: bad expected json: %v", e))
			} else if e := json.Unmarshal([]byte(out), &got); e != nil {
				failures = append(failures, fmt.Sprintf("out_json: bad got json: %v", e))
			} else {
				eb, _ := json.Marshal(expected)
				gb, _ := json.Marshal(got)
				if string(eb) != string(gb) {
					failures = append(failures, fmt.Sprintf("out_json mismatch\n  expected: %s\n  got:      %s", eb, gb))
				}
			}
		}
	}

	// out_md
	if exp, ok := s["out_md"]; ok {
		out, err := call("md")
		if err != nil {
			failures = append(failures, fmt.Sprintf("out_md parse error: %v", err))
		} else if strings.TrimSpace(exp) != strings.TrimSpace(out) {
			failures = append(failures, fmt.Sprintf("out_md mismatch\n  expected:\n%s\n  got:\n%s", exp, out))
		}
	}

	return failures
}

// ── suite runner ──────────────────────────────────────────────────────────────

func runSuite(path string) int {
	tests, err := parseSuite(path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error reading %s: %v\n", path, err)
		return 1
	}
	passed, failed := 0, 0
	for _, t := range tests {
		failures := runTest(t)
		if len(failures) == 0 {
			passed++
		} else {
			failed++
			fmt.Printf("FAIL  %s\n", t.name)
			for _, f := range failures {
				for _, line := range strings.Split(f, "\n") {
					fmt.Printf("      %s\n", line)
				}
			}
		}
	}
	fmt.Printf("%s: %d passed, %d failed\n", path, passed, failed)
	return failed
}

// ── entry point ───────────────────────────────────────────────────────────────

func main() {
	_, file, _, _ := runtime.Caller(0)
	// file is lang/go/conformance/main.go; conformance/ is ../../../conformance/
	base := filepath.Join(filepath.Dir(file), "..", "..", "..", "conformance")

	suites := os.Args[1:]
	if len(suites) == 0 {
		suites = []string{
			filepath.Join(base, "core.txt"),
			filepath.Join(base, "extended.txt"),
			filepath.Join(base, "xml.txt"),
			filepath.Join(base, "md.txt"),
			filepath.Join(base, "schema_validate.txt"),
			filepath.Join(base, "streaming_write.txt"),
		}
	}

	totalFailed := 0
	for _, s := range suites {
		totalFailed += runSuite(s)
	}
	if totalFailed > 0 {
		os.Exit(1)
	}
}
