// CX C# conformance runner.
// Run: DOTNET_ROOT=/opt/homebrew/opt/dotnet/libexec dotnet run --project csharp/conformance/conformance.csproj
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;
using CX;

// ── suite parser ──────────────────────────────────────────────────────────────

static List<(string name, Dictionary<string, string> sections)> ParseSuite(string path)
{
    var tests = new List<(string, Dictionary<string, string>)>();
    (string, Dictionary<string, string>)? cur = null;
    string? section = null;
    var buf = new List<string>();

    void Flush()
    {
        if (cur is var (cname, csecs) && section != null)
        {
            var lines = buf.ToList();
            while (lines.Count > 0 && string.IsNullOrWhiteSpace(lines[0])) lines.RemoveAt(0);
            while (lines.Count > 0 && string.IsNullOrWhiteSpace(lines[^1])) lines.RemoveAt(lines.Count - 1);
            csecs[section] = string.Join("\n", lines);
        }
        buf.Clear();
    }

    foreach (var raw in File.ReadAllLines(path))
    {
        if (raw.StartsWith("=== test:"))
        {
            Flush();
            if (cur.HasValue) tests.Add(cur.Value);
            cur = (raw[9..].Trim(), new Dictionary<string, string>());
            section = null;
        }
        else if (raw.StartsWith("--- ") && cur.HasValue)
        {
            Flush();
            section = raw[4..].Trim();
        }
        else if (section != null && cur.HasValue)
        {
            buf.Add(raw);
        }
    }
    Flush();
    if (cur.HasValue) tests.Add(cur.Value);
    return tests;
}

// ── JSON equality ─────────────────────────────────────────────────────────────

static bool JsonEqual(JsonNode? a, JsonNode? b)
{
    if (a is null && b is null) return true;
    if (a is null || b is null) return false;
    if (a is JsonObject ao && b is JsonObject bo)
    {
        if (ao.Count != bo.Count) return false;
        foreach (var kv in ao)
        {
            if (!bo.TryGetPropertyValue(kv.Key, out var bv)) return false;
            if (!JsonEqual(kv.Value, bv)) return false;
        }
        return true;
    }
    if (a is JsonArray aa && b is JsonArray ba)
    {
        if (aa.Count != ba.Count) return false;
        for (int i = 0; i < aa.Count; i++)
            if (!JsonEqual(aa[i], ba[i])) return false;
        return true;
    }
    // Compare as values
    return a.ToJsonString() == b.ToJsonString();
}

static bool JsonStrEqual(string a, string b)
{
    try { return JsonEqual(JsonNode.Parse(a), JsonNode.Parse(b)); }
    catch { return false; }
}

// ── dispatch ──────────────────────────────────────────────────────────────────

static string Dispatch(string inFmt, string outFmt, string input) => (inFmt, outFmt) switch
{
    ("cx",   "cx")   => CxLib.ToCx(input),   ("cx",   "xml")  => CxLib.ToXml(input),
    ("cx",   "ast")  => CxLib.ToAst(input),  ("cx",   "json") => CxLib.ToJson(input),
    ("cx",   "yaml") => CxLib.ToYaml(input), ("cx",   "toml") => CxLib.ToToml(input),
    ("cx",   "md")   => CxLib.ToMd(input),
    ("xml",  "cx")   => CxLib.XmlToCx(input), ("xml", "xml")  => CxLib.XmlToXml(input),
    ("xml",  "ast")  => CxLib.XmlToAst(input),("xml", "json") => CxLib.XmlToJson(input),
    ("xml",  "yaml") => CxLib.XmlToYaml(input),("xml","toml") => CxLib.XmlToToml(input),
    ("xml",  "md")   => CxLib.XmlToMd(input),
    ("json", "cx")   => CxLib.JsonToCx(input), ("json","xml") => CxLib.JsonToXml(input),
    ("json", "ast")  => CxLib.JsonToAst(input),("json","json")=> CxLib.JsonToJson(input),
    ("json", "yaml") => CxLib.JsonToYaml(input),("json","toml")=>CxLib.JsonToToml(input),
    ("json", "md")   => CxLib.JsonToMd(input),
    ("yaml", "cx")   => CxLib.YamlToCx(input), ("yaml","xml") => CxLib.YamlToXml(input),
    ("yaml", "ast")  => CxLib.YamlToAst(input),("yaml","json")=> CxLib.YamlToJson(input),
    ("yaml", "yaml") => CxLib.YamlToYaml(input),("yaml","toml")=>CxLib.YamlToToml(input),
    ("yaml", "md")   => CxLib.YamlToMd(input),
    ("toml", "cx")   => CxLib.TomlToCx(input), ("toml","xml") => CxLib.TomlToXml(input),
    ("toml", "ast")  => CxLib.TomlToAst(input),("toml","json")=> CxLib.TomlToJson(input),
    ("toml", "yaml") => CxLib.TomlToYaml(input),("toml","toml")=>CxLib.TomlToToml(input),
    ("toml", "md")   => CxLib.TomlToMd(input),
    ("md",   "cx")   => CxLib.MdToCx(input),   ("md",  "xml") => CxLib.MdToXml(input),
    ("md",   "ast")  => CxLib.MdToAst(input),  ("md",  "json")=> CxLib.MdToJson(input),
    ("md",   "yaml") => CxLib.MdToYaml(input), ("md",  "toml")=> CxLib.MdToToml(input),
    ("md",   "md")   => CxLib.MdToMd(input),
    _ => throw new ArgumentException($"no dispatch for {inFmt}:{outFmt}")
};

// ── streaming-write fixture support ───────────────────────────────────────────

static string DecodeQuoted(string s)
{
    s = s.Trim();
    if (s.Length >= 2 && s.StartsWith("\"") && s.EndsWith("\""))
        return s.Substring(1, s.Length - 2);
    return s;
}

static byte[] HexBytes(string s)
{
    s = s.Trim();
    var bytes = new byte[s.Length / 2];
    for (int i = 0; i < bytes.Length; i++)
        bytes[i] = Convert.ToByte(s.Substring(i * 2, 2), 16);
    return bytes;
}

static void DispatchEvent(EventWriter w, string op, string rest)
{
    switch (op)
    {
        case "StartDoc":     w.StartDoc(); break;
        case "EndDoc":       w.EndDoc();   break;
        case "StartElement":
        {
            var toks = rest.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            string name = toks[0];
            string? anchor = null, dt = null, merge = null;
            for (int i = 1; i < toks.Length; i++)
            {
                int eq = toks[i].IndexOf('=');
                if (eq < 0) continue;
                string k = toks[i].Substring(0, eq), v = toks[i].Substring(eq + 1);
                if (k == "anchor")    anchor = v;
                if (k == "data_type") dt = v;
                if (k == "merge")     merge = v;
            }
            w.StartElement(name, anchor, dt, merge); break;
        }
        case "EndElement":   w.EndElement(rest.Trim()); break;
        case "Text":         w.Text(DecodeQuoted(rest)); break;
        case "Scalar":
        {
            int c = rest.IndexOf(':');
            string typ = c >= 0 ? rest.Substring(0, c).Trim() : rest.Trim();
            string val = c >= 0 ? rest.Substring(c + 1)        : "";
            w.Scalar(val, typ); break;
        }
        case "Comment":      w.Comment(DecodeQuoted(rest)); break;
        case "PI":
        {
            var parts = rest.Split(new[] {' ', '\t'}, 2);
            string target = parts[0].Trim();
            string data = "";
            if (parts.Length > 1)
            {
                var rest2 = parts[1].Trim();
                if (rest2.StartsWith("data=")) data = DecodeQuoted(rest2.Substring(5));
            }
            w.Pi(target, data); break;
        }
        case "EntityRef":    w.EntityRef(rest.Trim()); break;
        case "RawText":      w.RawText(DecodeQuoted(rest)); break;
        case "Alias":        w.Alias(rest.Trim()); break;
        case "StartTable":   w.StartTable(HexBytes(rest)); break;
        case "RowGroup":     w.RowGroup(HexBytes(rest)); break;
        case "EndTable":     w.EndTable(); break;
        default: throw new ArgumentException($"unknown event op: {op}");
    }
}

static string FirstNonBlankNonComment(string text)
{
    foreach (var line in text.Split('\n'))
    {
        var t = line.Trim();
        if (t.Length > 0 && !t.StartsWith("#")) return t;
    }
    return "";
}

static string StripComments(string text)
{
    var keep = new List<string>();
    foreach (var line in text.Split('\n'))
        if (!line.TrimStart().StartsWith("#")) keep.Add(line);
    return string.Join("\n", keep);
}

static List<string> RunStreamingWriteTest(Dictionary<string, string> s)
{
    var failures = new List<string>();
    string fmt = s.GetValueOrDefault("format", "cx").Trim();
    string expectErr = s.TryGetValue("expect_err", out var ee) ? FirstNonBlankNonComment(ee) : "";
    string? expectOk = s.TryGetValue("expect_ok", out var eo) ? StripComments(eo) : null;
    string? expectOkContains = s.TryGetValue("expect_ok_contains", out var eoc) ? StripComments(eoc) : null;

    EventWriter w;
    try { w = new EventWriter(fmt); }
    catch (Exception e)
    {
        if (expectErr.Length > 0 && e.Message.Contains(expectErr)) return failures;
        failures.Add($"EventWriter({fmt}) raised: {e.Message}");
        return failures;
    }

    string? triggered = null;
    foreach (var raw in s["events"].Split('\n'))
    {
        var line = raw.Trim();
        if (line.Length == 0) continue;
        int sp = line.IndexOf(' ');
        string op = sp < 0 ? line : line.Substring(0, sp);
        string rest = sp < 0 ? ""   : line.Substring(sp + 1);
        try { DispatchEvent(w, op, rest); }
        catch (InvalidOperationException e) { triggered = e.Message; break; }
        catch (Exception e) { failures.Add($"unexpected exception in {op}: {e.Message}"); w.Close(); return failures; }
    }

    if (expectErr.Length > 0)
    {
        if (triggered is null)
        {
            try { w.CloseGetBytes(); }
            catch (InvalidOperationException e) { triggered = e.Message; }
            catch (Exception) {}
        }
        else { w.Close(); }
        if (triggered is null) failures.Add($"expected {expectErr} but writer produced no error");
        else if (!triggered.Contains(expectErr)) failures.Add($"expected {expectErr} in error, got {triggered}");
        return failures;
    }

    if (triggered != null) { failures.Add($"unexpected error: {triggered}"); w.Close(); return failures; }

    byte[] bytes;
    try { bytes = w.CloseGetBytes(); }
    catch (Exception e) { failures.Add($"CloseGetBytes raised: {e.Message}"); return failures; }
    string outStr = System.Text.Encoding.UTF8.GetString(bytes);
    if (expectOk != null && expectOk.Trim() != outStr.Trim())
        failures.Add($"expect_ok mismatch\n  expected:\n{expectOk}\n  got:\n{outStr}");
    if (expectOkContains != null)
    {
        foreach (var needle in expectOkContains.Split('\n'))
        {
            var n = needle.Trim();
            if (n.Length > 0 && !outStr.Contains(n))
                failures.Add($"expect_ok_contains: missing {n} in output:\n{outStr}");
        }
    }
    return failures;
}

// ── test runner ───────────────────────────────────────────────────────────────

static List<string> RunTest((string name, Dictionary<string, string> sections) t)
{
    var failures = new List<string>();
    var s = t.sections;

    // ── streaming-write (events + format) ───────────────────────────────────
    if (s.ContainsKey("events") && s.ContainsKey("format"))
        return RunStreamingWriteTest(s);

    string? src = null, inFmt = null;
    foreach (var (k, fmt) in new[] { ("in_cx","cx"), ("in_xml","xml"), ("in_json","json"),
                                      ("in_yaml","yaml"), ("in_toml","toml"), ("in_md","md") })
        if (s.TryGetValue(k, out var v)) { src = v; inFmt = fmt; break; }
    if (inFmt is null) return failures;

    (string? out_, string? err) Call(string outFmt)
    {
        try { return (Dispatch(inFmt, outFmt, src!), null); }
        catch (Exception e) { return (null, e.Message); }
    }

    if (s.TryGetValue("out_ast",  out var expAst))  { var (o,e) = Call("ast");  if (e!=null) failures.Add($"out_ast parse error: {e}"); else if (!JsonStrEqual(expAst, o!)) failures.Add($"out_ast mismatch\n  expected: {expAst}\n  got:      {o}"); }
    if (s.TryGetValue("out_xml",  out var expXml))  { var (o,e) = Call("xml");  if (e!=null) failures.Add($"out_xml parse error: {e}");  else if (expXml.Trim() != o!.Trim()) failures.Add($"out_xml mismatch\n  expected:\n{expXml}\n  got:\n{o}"); }
    if (s.TryGetValue("out_cx",   out var expCx))   { var (o,e) = Call("cx");   if (e!=null) failures.Add($"out_cx parse error: {e}");   else if (expCx.Trim()  != o!.Trim()) failures.Add($"out_cx mismatch\n  expected:\n{expCx}\n  got:\n{o}"); }
    if (s.TryGetValue("out_json", out var expJson)) { var (o,e) = Call("json"); if (e!=null) failures.Add($"out_json parse error: {e}"); else if (!JsonStrEqual(expJson, o!)) failures.Add($"out_json mismatch\n  expected: {expJson}\n  got:      {o}"); }
    if (s.TryGetValue("out_md",   out var expMd))   { var (o,e) = Call("md");   if (e!=null) failures.Add($"out_md parse error: {e}");   else if (expMd.Trim()  != o!.Trim()) failures.Add($"out_md mismatch\n  expected:\n{expMd}\n  got:\n{o}"); }

    return failures;
}

// ── suite runner ──────────────────────────────────────────────────────────────

static int RunSuite(string path)
{
    var tests = ParseSuite(path);
    int passed = 0, failed = 0;
    foreach (var t in tests)
    {
        List<string> failures;
        try   { failures = RunTest(t); }
        catch (Exception e) { failures = [$"runner exception: {e.Message}"]; }

        if (failures.Count == 0) { passed++; }
        else
        {
            failed++;
            Console.WriteLine($"FAIL  {t.name}");
            foreach (var f in failures)
                foreach (var line in f.Split('\n'))
                    Console.WriteLine($"      {line}");
        }
    }
    Console.WriteLine($"{path}: {passed} passed, {failed} failed");
    return failed;
}

// ── entry point ───────────────────────────────────────────────────────────────

string base_ = FindConformanceDir();
string[] suites = args.Length > 0 ? args : [
    Path.Combine(base_, "core.txt"),
    Path.Combine(base_, "extended.txt"),
    Path.Combine(base_, "xml.txt"),
    Path.Combine(base_, "md.txt"),
    Path.Combine(base_, "streaming_write.txt"),
];

int totalFailed = suites.Sum(RunSuite);
Environment.Exit(totalFailed > 0 ? 1 : 0);

// ── helpers ───────────────────────────────────────────────────────────────────

static string FindConformanceDir()
{
    var dir = new DirectoryInfo(AppContext.BaseDirectory);
    while (dir != null)
    {
        var candidate = Path.Combine(dir.FullName, "conformance");
        // Must contain actual .txt test files, not just be a project directory
        if (Directory.Exists(candidate) && File.Exists(Path.Combine(candidate, "core.txt")))
            return candidate;
        dir = dir.Parent;
    }
    throw new DirectoryNotFoundException("Cannot find conformance/ directory with core.txt");
}
