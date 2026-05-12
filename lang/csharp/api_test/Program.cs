// CX C# Document API test runner.
// Run: dotnet run --project csharp/api_test/api_test.csproj -c Release
using CX;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;

// ── fixture path ──────────────────────────────────────────────────────────────

// AppContext.BaseDirectory is e.g. csharp/api_test/bin/Release/net10.0/
// Walk up to find the repo root (contains a "fixtures" directory)
string FindFixturesDir()
{
    var dir = new DirectoryInfo(AppContext.BaseDirectory);
    while (dir != null)
    {
        string candidate = Path.Combine(dir.FullName, "fixtures");
        if (Directory.Exists(candidate) && File.Exists(Path.Combine(candidate, "api_config.cx")))
            return candidate;
        dir = dir.Parent;
    }
    throw new DirectoryNotFoundException("Cannot find fixtures/ directory");
}

string fixtures = FindFixturesDir();

// ── test runner ───────────────────────────────────────────────────────────────

int passed = 0, failed = 0;

void Expect(bool condition, string msg)
{
    if (condition) { Console.WriteLine($"  PASS: {msg}"); passed++; }
    else { Console.Error.WriteLine($"  FAIL: {msg}"); failed++; }
}

string Fx(string name) => File.ReadAllText(Path.Combine(fixtures, name));

void Section(string title) => Console.WriteLine($"\n── {title}");

// ── parse / root / get ────────────────────────────────────────────────────────

Section("parse / root / get");

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    Expect(doc is not null, "parse returns CXDocument");
    Expect(doc!.Root()?.Name == "config", "root returns first element");
}

{
    var doc = CXDocument.Parse("");
    Expect(doc.Root() is null, "root is null on empty input");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    Expect(doc.Get("config")?.Name == "config", "get top-level by name");
    Expect(doc.Get("missing") is null, "get missing returns null");
}

{
    var doc = CXDocument.Parse(Fx("api_multi.cx"));
    Expect(doc.Get("service")?.Attr("name") as string == "auth", "get multi top-level returns first");
}

{
    var doc = CXDocument.Parse(Fx("api_multi.cx"));
    int count = doc.Elements.OfType<Element>().Count(e => e.Name == "service");
    Expect(count == 3, "parse multiple top-level elements");
}

// ── attr ──────────────────────────────────────────────────────────────────────

Section("attr");

{
    var srv = CXDocument.Parse(Fx("api_config.cx")).At("config/server");
    Expect(srv?.Attr("host") as string == "localhost", "attr string");
    Expect(srv?.Attr("port") is long p && p == 8080L, "attr int");
    Expect(srv?.Attr("debug") is false, "attr bool false");
    double ratio = Convert.ToDouble(srv?.Attr("ratio"));
    Expect(Math.Abs(ratio - 1.5) < 1e-9, "attr float");
    Expect(srv?.Attr("nonexistent") is null, "attr missing returns null");
}

// ── scalar ────────────────────────────────────────────────────────────────────

Section("scalar");

{
    var el = CXDocument.Parse(Fx("api_scalars.cx")).At("values/count");
    var sv = el?.Scalar();
    Expect(sv is long l && l == 42L, "scalar int");
}

{
    var el = CXDocument.Parse(Fx("api_scalars.cx")).At("values/ratio");
    double v = Convert.ToDouble(el?.Scalar());
    Expect(Math.Abs(v - 1.5) < 1e-9, "scalar float");
}

{
    var el = CXDocument.Parse(Fx("api_scalars.cx")).At("values/enabled");
    Expect(el?.Scalar() is true, "scalar bool true");
}

{
    var el = CXDocument.Parse(Fx("api_scalars.cx")).At("values/disabled");
    Expect(el?.Scalar() is false, "scalar bool false");
}

{
    var el = CXDocument.Parse(Fx("api_scalars.cx")).At("values/nothing");
    Expect(el?.Scalar() is null, "scalar null");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    Expect(doc.Root()?.Scalar() is null, "scalar null when element has children");
}

// ── text ──────────────────────────────────────────────────────────────────────

Section("text");

{
    var doc = CXDocument.Parse(Fx("api_article.cx"));
    Expect(doc.At("article/body/h1")?.Text() == "Introduction", "text single token");
}

{
    var el = CXDocument.Parse(Fx("api_scalars.cx")).At("values/label");
    Expect(el?.Text() == "hello world", "text quoted");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    Expect(doc.Root()?.Text() == "", "text empty when no text children");
}

// ── children / get_all ────────────────────────────────────────────────────────

Section("children / GetAll");

{
    var config = CXDocument.Parse(Fx("api_config.cx")).Root();
    var kids = config?.Children().ToList();
    Expect(kids?.Count == 3, "children count");
    Expect(kids?.All(k => k is Element) == true, "children all elements");
    Expect(kids?.Select(k => k.Name).SequenceEqual(new[] { "server", "database", "logging" }) == true,
        "children names in order");
}

{
    var doc = CXDocument.Parse("[root [item 1] [item 2] [other x] [item 3]]");
    var items = doc.Root()?.GetAll("item").ToList();
    Expect(items?.Count == 3, "get_all direct children");
}

{
    var config = CXDocument.Parse(Fx("api_config.cx")).Root();
    Expect(!config?.GetAll("missing").Any() == true, "get_all empty for missing");
}

// ── at ────────────────────────────────────────────────────────────────────────

Section("at");

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    Expect(doc.At("config")?.Name == "config", "at single segment");
    Expect(doc.At("config/server")?.Name == "server", "at two segments (server)");
    Expect(doc.At("config/database")?.Name == "database", "at two segments (database)");
}

{
    var doc = CXDocument.Parse(Fx("api_article.cx"));
    Expect(doc.At("article/head/title")?.Text() == "Getting Started with CX", "at three segments (title)");
    Expect(doc.At("article/body/h1")?.Text() == "Introduction", "at three segments (h1)");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    Expect(doc.At("config/missing") is null, "at missing segment returns null");
    Expect(doc.At("missing") is null, "at missing root returns null");
    Expect(doc.At("config/server/missing/deep") is null, "at deep missing returns null");
}

{
    var doc = CXDocument.Parse(Fx("api_article.cx"));
    var body = doc.At("article/body");
    Expect(body?.At("section/h2")?.Text() == "Details", "element at relative path");
}

// ── find_all ──────────────────────────────────────────────────────────────────

Section("find_all");

{
    var doc = CXDocument.Parse(Fx("api_multi.cx"));
    Expect(doc.FindAll("service").Count() == 3, "find_all top-level");
}

{
    var doc = CXDocument.Parse(Fx("api_article.cx"));
    var ps = doc.FindAll("p").ToList();
    Expect(ps.Count == 3, "find_all deep count");
    Expect(ps[0].Text() == "First paragraph.", "find_all deep first");
    Expect(ps[1].Text() == "Nested paragraph.", "find_all deep second");
    Expect(ps[2].Text() == "Another nested paragraph.", "find_all deep third");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    Expect(!doc.FindAll("missing").Any(), "find_all missing returns empty");
}

{
    var body = CXDocument.Parse(Fx("api_article.cx")).At("article/body");
    Expect(body?.FindAll("p").Count() == 3, "find_all on element");
}

// ── find_first ────────────────────────────────────────────────────────────────

Section("find_first");

{
    var doc = CXDocument.Parse(Fx("api_article.cx"));
    var p = doc.FindFirst("p");
    Expect(p is not null, "find_first not null");
    Expect(p?.Text() == "First paragraph.", "find_first returns first match");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    Expect(doc.FindFirst("missing") is null, "find_first missing returns null");
}

{
    var doc = CXDocument.Parse(Fx("api_article.cx"));
    Expect(doc.FindFirst("h1")?.Text() == "Introduction", "find_first depth-first h1");
    Expect(doc.FindFirst("h2")?.Text() == "Details", "find_first depth-first h2");
}

{
    var section = CXDocument.Parse(Fx("api_article.cx")).At("article/body/section");
    Expect(section?.FindFirst("p")?.Text() == "Nested paragraph.", "find_first on element");
}

// ── mutation — Element ────────────────────────────────────────────────────────

Section("mutation — Element");

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    doc.Root()!.Append(new Element("cache"));
    var kids = doc.Root()!.Children().ToList();
    Expect(kids[^1].Name == "cache", "append adds to end");
    Expect(kids.Count == 4, "append increases count");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    doc.Root()!.Prepend(new Element("meta"));
    Expect(doc.Root()!.Children().First().Name == "meta", "prepend adds to front");
}

{
    var doc = CXDocument.Parse("[root [a 1] [c 3]]");
    doc.Root()!.Insert(1, new Element("b"));
    var names = doc.Root()!.Children().Select(k => k.Name).ToList();
    Expect(names.SequenceEqual(new[] { "a", "b", "c" }), "insert at index");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    var db = doc.At("config/database")!;
    doc.Root()!.Remove(db);
    Expect(doc.At("config/database") is null, "remove clears element");
    Expect(doc.At("config/server") is not null, "remove leaves others intact");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    var srv = doc.At("config/server")!;
    srv.SetAttr("env", "production");
    Expect(srv.Attr("env") as string == "production", "set_attr new");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    var srv = doc.At("config/server")!;
    srv.SetAttr("port", 9090L, "int");
    Expect(Convert.ToInt64(srv.Attr("port")) == 9090L, "set_attr update value");
    Expect(srv.Attrs.Count == 4, "set_attr no duplicate");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    var srv = doc.At("config/server")!;
    int originalCount = srv.Attrs.Count;
    srv.SetAttr("debug", true, "bool");
    Expect(srv.Attr("debug") is true, "set_attr change type value");
    Expect(srv.Attrs.Count == originalCount, "set_attr change type no dup");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    var srv = doc.At("config/server")!;
    int originalCount = srv.Attrs.Count;
    srv.RemoveAttr("debug");
    Expect(srv.Attr("debug") is null, "remove_attr removes it");
    Expect(srv.Attrs.Count == originalCount - 1, "remove_attr reduces count");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    var srv = doc.At("config/server")!;
    int originalCount = srv.Attrs.Count;
    srv.RemoveAttr("nonexistent");
    Expect(srv.Attrs.Count == originalCount, "remove_attr nonexistent is noop");
}

// ── mutation — Document ───────────────────────────────────────────────────────

Section("mutation — Document");

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    doc.Append(new Element("cache") { Attrs = new List<Attr> { new Attr("host", "redis") } });
    Expect(doc.Get("cache")?.Attr("host") as string == "redis", "doc append element");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    doc.Prepend(new Element("preamble"));
    Expect(doc.Root()?.Name == "preamble", "doc prepend makes new root");
    Expect(doc.Get("config") is not null, "doc prepend original still present");
}

// ── round-trips ───────────────────────────────────────────────────────────────

Section("round-trips");

{
    var original = CXDocument.Parse(Fx("api_config.cx"));
    var reparsed = CXDocument.Parse(original.ToCx());
    Expect(reparsed.At("config/server")?.Attr("host") as string == "localhost", "round-trip host");
    Expect(Convert.ToInt64(reparsed.At("config/server")?.Attr("port")) == 8080L, "round-trip port");
    Expect(reparsed.At("config/database")?.Attr("name") as string == "myapp", "round-trip database name");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    doc.At("config/server")!.SetAttr("env", "production");
    doc.At("config/server")!.Append(new Element("timeout")
    {
        Items = new List<Node> { new ScalarNode("int", 30L) }
    });
    var reparsed = CXDocument.Parse(doc.ToCx());
    Expect(reparsed.At("config/server")?.Attr("env") as string == "production",
        "round-trip after mutation env");
    Expect(Convert.ToInt64(reparsed.At("config/server")?.FindFirst("timeout")?.Scalar()) == 30L,
        "round-trip after mutation scalar");
}

{
    var original = CXDocument.Parse(Fx("api_article.cx"));
    var reparsed = CXDocument.Parse(original.ToCx());
    Expect(reparsed.At("article/head/title")?.Text() == "Getting Started with CX",
        "round-trip article title");
    Expect(reparsed.FindAll("p").Count() == 3, "round-trip article paragraphs");
}

// ── loads / dumps ─────────────────────────────────────────────────────────────

Section("loads / dumps");

{
    var data = CXDocument.Loads(Fx("api_config.cx"));
    Expect(data is Dictionary<string, object?> d, "loads returns dict");
    var config = (Dictionary<string, object?>)((Dictionary<string, object?>)data!)["config"]!;
    var server = (Dictionary<string, object?>)config["server"]!;
    Expect(server["host"] as string == "localhost", "loads server host");
    Expect(Convert.ToInt64(server["port"]) == 8080L, "loads server port");
}

{
    var data = CXDocument.Loads(Fx("api_config.cx"));
    var config = (Dictionary<string, object?>)((Dictionary<string, object?>)data!)["config"]!;
    var server = (Dictionary<string, object?>)config["server"]!;
    Expect(server["debug"] is false, "loads bool false");
}

{
    var data = CXDocument.Loads(Fx("api_scalars.cx"));
    var values = (Dictionary<string, object?>)((Dictionary<string, object?>)data!)["values"]!;
    Expect(Convert.ToInt64(values["count"]) == 42L, "loads scalar int");
    Expect(values["enabled"] is true, "loads scalar bool true");
    Expect(values["disabled"] is false, "loads scalar bool false");
    Expect(values["nothing"] is null, "loads scalar null");
}

{
    var data = CXDocument.LoadsXml("<server host=\"localhost\" port=\"8080\"/>");
    Expect(data is Dictionary<string, object?> d && d.ContainsKey("server"), "loads_xml");
}

{
    var data = CXDocument.LoadsJson("{\"port\": 8080, \"debug\": false}");
    Expect(data is Dictionary<string, object?> d2 && Convert.ToInt64(d2["port"]) == 8080L,
        "loads_json port");
    Expect(data is Dictionary<string, object?> d3 && d3["debug"] is false, "loads_json bool");
}

{
    var data = CXDocument.LoadsYaml("server:\n  host: localhost\n  port: 8080\n");
    Expect(data is Dictionary<string, object?> d && d.ContainsKey("server"), "loads_yaml");
}

{
    var original = new Dictionary<string, object?> {
        ["app"] = new Dictionary<string, object?> {
            ["name"] = "myapp",
            ["version"] = "1.0",
            ["port"] = 8080
        }
    };
    string cxStr = CXDocument.Dumps(original);
    var reparsed = CXDocument.Parse(cxStr);
    Expect(reparsed.FindFirst("app") is not null, "dumps produces parseable cx");
}

{
    var original = new Dictionary<string, object?> {
        ["server"] = new Dictionary<string, object?> {
            ["host"] = "localhost",
            ["port"] = 8080,
            ["debug"] = false
        }
    };
    var restored = CXDocument.Loads(CXDocument.Dumps(original)) as Dictionary<string, object?>;
    var srv2 = restored!["server"] as Dictionary<string, object?>;
    Expect(Convert.ToInt64(srv2!["port"]) == 8080L, "loads_dumps port preserved");
    Expect(srv2["host"] as string == "localhost", "loads_dumps host preserved");
    Expect(srv2["debug"] is false, "loads_dumps debug preserved");
}

// ── error / failure cases ─────────────────────────────────────────────────────

Section("error / failure cases");

{
    bool threw = false;
    try { CXDocument.Parse(Fx("errors/unclosed.cx")); }
    catch { threw = true; }
    Expect(threw, "unclosed bracket should throw");
}

{
    bool threw = false;
    try { CXDocument.Parse(Fx("errors/empty_name.cx")); }
    catch { threw = true; }
    Expect(threw, "empty element name should throw");
}

{
    bool threw = false;
    try { CXDocument.Parse(Fx("errors/nested_unclosed.cx")); }
    catch { threw = true; }
    Expect(threw, "nested unclosed should throw");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    Expect(doc.At("config/server/missing/deep/path") is null, "at deep missing returns null (no exception)");
}

{
    var doc = CXDocument.Parse("");
    Expect(!doc.FindAll("anything").Any(), "find_all on empty doc returns empty");
    Expect(doc.FindFirst("anything") is null, "find_first on empty doc returns null");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    Expect(doc.Root()?.Scalar() is null, "scalar null when element has child elements");
    Expect(doc.Root()?.Text() == "", "text empty when no text children");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    var srv = doc.At("config/server")!;
    srv.RemoveAttr("totally_missing"); // should not throw
    Expect(true, "remove_attr nonexistent does not raise");
}

{
    bool threw = false;
    try { CXDocument.ParseXml("<unclosed"); }
    catch { threw = true; }
    Expect(threw, "parse_xml invalid should throw");
}

// ── parse other formats ───────────────────────────────────────────────────────

Section("parse other formats");

{
    var doc = CXDocument.ParseXml("<root><child key=\"val\"/></root>");
    Expect(doc.Root()?.Name == "root", "parse_xml root");
    Expect(doc.FindFirst("child") is not null, "parse_xml child");
}

{
    var doc = CXDocument.ParseJson("{\"server\": {\"port\": 8080}}");
    Expect(doc.FindFirst("server") is not null, "parse_json server");
}

{
    var doc = CXDocument.ParseYaml("server:\n  port: 8080\n");
    Expect(doc.FindFirst("server") is not null, "parse_yaml server");
}

// ── stream (binary events decoder) ───────────────────────────────────────────

Section("stream");

{
    // Minimal document: StartDoc, StartElement, EndElement, EndDoc
    var events = CXDocument.Stream("[root]");
    Expect(events.Count == 4, "stream [root] yields 4 events");
    Expect(events[0].Type == "StartDoc",     "stream event[0] is StartDoc");
    Expect(events[1].Type == "StartElement", "stream event[1] is StartElement");
    Expect(events[1].Name == "root",         "stream StartElement name is 'root'");
    Expect(events[2].Type == "EndElement",   "stream event[2] is EndElement");
    Expect(events[2].Name == "root",         "stream EndElement name is 'root'");
    Expect(events[3].Type == "EndDoc",       "stream event[3] is EndDoc");
}

{
    // Attributes and typed values
    var events = CXDocument.Stream("[server host=localhost port=8080 debug=false]");
    var start = events.FirstOrDefault(e => e.Type == "StartElement");
    Expect(start is not null,                     "stream attr: StartElement present");
    Expect(start!.Name == "server",               "stream attr: element name");
    Expect(start.Attrs.Count == 3,                "stream attr: 3 attributes");
    Expect(start.Attrs[0].Name == "host",         "stream attr[0] name");
    Expect(start.Attrs[0].Value as string == "localhost", "stream attr[0] value");
    Expect(start.Attrs[1].Value is long p && p == 8080L,  "stream attr[1] int value");
    Expect(start.Attrs[2].Value is false,                 "stream attr[2] bool value");
}

{
    // Text child content
    var events = CXDocument.Stream("[title 'Hello World']");
    var textEv = events.FirstOrDefault(e => e.Type == "Text");
    Expect(textEv is not null,                      "stream text: Text event present");
    Expect(textEv!.Value as string == "Hello World","stream text: value correct");
}

{
    // Scalar child
    var events = CXDocument.Stream("[count 42]");
    var scalar = events.FirstOrDefault(e => e.Type == "Scalar");
    Expect(scalar is not null,               "stream scalar: Scalar event present");
    Expect(scalar!.Value is long v && v == 42L, "stream scalar: int value 42");
}

{
    // Nested elements produce multiple StartElement/EndElement pairs
    var events = CXDocument.Stream("[root [child 'text']]");
    var starts = events.Where(e => e.Type == "StartElement").ToList();
    var ends   = events.Where(e => e.Type == "EndElement").ToList();
    Expect(starts.Count == 2, "stream nested: 2 StartElement events");
    Expect(ends.Count   == 2, "stream nested: 2 EndElement events");
    Expect(starts[0].Name == "root",  "stream nested: first StartElement is root");
    Expect(starts[1].Name == "child", "stream nested: second StartElement is child");
}

{
    // Comment event
    var events = CXDocument.Stream("[root [-a comment]]");
    var comment = events.FirstOrDefault(e => e.Type == "Comment");
    Expect(comment is not null,                       "stream comment: Comment event present");
    Expect(comment!.Value as string == "a comment",   "stream comment: value correct");
}

// ── RemoveChild / RemoveAt ────────────────────────────────────────────────────

Section("RemoveChild / RemoveAt");

{
    var doc = CXDocument.Parse("[root [item a] [item b] [other x] [item c]]");
    var root = doc.Root()!;
    root.RemoveChild("item");
    var kids = root.Children().ToList();
    Expect(kids.Count == 1, "RemoveChild removes all matching children");
    Expect(kids[0].Name == "other", "RemoveChild leaves non-matching intact");
}

{
    var doc = CXDocument.Parse("[root [a] [b] [c]]");
    doc.Root()!.RemoveChild("missing");
    Expect(doc.Root()!.Children().Count() == 3, "RemoveChild nonexistent is no-op");
}

{
    var doc = CXDocument.Parse("[root [a] [b] [c]]");
    doc.Root()!.RemoveAt(1);
    var names = doc.Root()!.Children().Select(k => k.Name).ToList();
    Expect(names.SequenceEqual(new[] { "a", "c" }), "RemoveAt removes by index");
}

{
    var doc = CXDocument.Parse("[root [a] [b]]");
    doc.Root()!.RemoveAt(99);
    Expect(doc.Root()!.Children().Count() == 2, "RemoveAt out-of-bounds is no-op");
}

{
    var doc = CXDocument.Parse("[root [a] [b]]");
    doc.Root()!.RemoveAt(-1);
    Expect(doc.Root()!.Children().Count() == 2, "RemoveAt negative index is no-op");
}

// ── SelectAll / Select ────────────────────────────────────────────────────────

Section("SelectAll / Select");

{
    var doc = CXDocument.Parse(Fx("api_multi.cx"));
    var all = doc.SelectAll("//service").ToList();
    Expect(all.Count == 3, "SelectAll descendant axis matches all");
    Expect(all[0].Attr("name") as string == "auth", "SelectAll first result is auth");
}

{
    var doc = CXDocument.Parse(Fx("api_multi.cx"));
    var first = doc.Select("//service");
    Expect(first is not null, "Select returns first match");
    Expect(first!.Attr("name") as string == "auth", "Select first is auth");
}

{
    var doc = CXDocument.Parse(Fx("api_multi.cx"));
    var matched = doc.SelectAll("//service[@name=auth]").ToList();
    Expect(matched.Count == 1, "SelectAll attr string predicate");
    Expect(matched[0].Attr("name") as string == "auth", "SelectAll attr string value correct");
}

{
    var doc = CXDocument.Parse(Fx("api_multi.cx"));
    var matched = doc.SelectAll("//service[@port>=8080]").ToList();
    Expect(matched.Count == 2, "SelectAll numeric comparison >=");
}

{
    var doc = CXDocument.Parse(Fx("api_multi.cx"));
    var matched = doc.SelectAll("//service[@name=auth or @name=worker]").ToList();
    Expect(matched.Count == 2, "SelectAll boolean or predicate");
}

{
    var doc = CXDocument.Parse(Fx("api_multi.cx"));
    var matched = doc.SelectAll("//service[@port>8000 and @name=api]").ToList();
    Expect(matched.Count == 1, "SelectAll boolean and predicate");
    Expect(matched[0].Attr("name") as string == "api", "SelectAll and result is api");
}

{
    var doc = CXDocument.Parse(Fx("api_multi.cx"));
    var second = doc.Select("//service[2]");
    Expect(second is not null, "Select position predicate [2]");
    Expect(second!.Attr("name") as string == "api", "Select [2] is api");
}

{
    var doc = CXDocument.Parse(Fx("api_multi.cx"));
    var last = doc.Select("//service[last()]");
    Expect(last is not null, "Select last() predicate");
    Expect(last!.Attr("name") as string == "worker", "Select last() is worker");
}

{
    var doc = CXDocument.Parse(Fx("api_multi.cx"));
    var matched = doc.SelectAll("//service[contains(@name, 'or')]").ToList();
    Expect(matched.Count == 1, "SelectAll contains() predicate");
    Expect(matched[0].Attr("name") as string == "worker", "SelectAll contains result is worker");
}

{
    var doc = CXDocument.Parse(Fx("api_multi.cx"));
    var matched = doc.SelectAll("//service[starts-with(@name, 'a')]").ToList();
    Expect(matched.Count == 2, "SelectAll starts-with() predicate");
}

{
    var doc = CXDocument.Parse(Fx("api_article.cx"));
    var matched = doc.SelectAll("article/body/p").ToList();
    Expect(matched.Count == 1, "SelectAll child path (direct child only)");
    Expect(matched[0].Text() == "First paragraph.", "SelectAll child path result correct");
}

{
    var doc = CXDocument.Parse(Fx("api_multi.cx"));
    var matched = doc.SelectAll("//*[@port]").ToList();
    Expect(matched.Count == 3, "SelectAll wildcard with attr existence predicate");
}

{
    // select on Element searches only its subtree
    var body = CXDocument.Parse(Fx("api_article.cx")).At("article/body")!;
    var ps = body.SelectAll("//p").ToList();
    Expect(ps.Count == 3, "SelectAll on element searches subtree");
    Expect(ps[0].Text() == "First paragraph.", "SelectAll on element first result correct");
}

{
    var doc = CXDocument.Parse(Fx("api_multi.cx"));
    Expect(doc.Select("//nonexistent") is null, "Select returns null when no match");
}

// ── Transform ─────────────────────────────────────────────────────────────────

Section("Transform");

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    var updated = doc.Transform("config/server", el => { el.SetAttr("host", "prod.example.com"); return el; });
    Expect(!ReferenceEquals(doc, updated), "Transform returns new document");
    Expect(updated.At("config/server")?.Attr("host") as string == "prod.example.com",
        "Transform applies function to element");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    var updated = doc.Transform("config/server", el => { el.SetAttr("host", "prod.example.com"); return el; });
    Expect(doc.At("config/server")?.Attr("host") as string == "localhost",
        "Transform original document unchanged");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    var same = doc.Transform("config/missing", el => el);
    Expect(ReferenceEquals(doc, same), "Transform missing path returns same document");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    var result = doc
        .Transform("config/server", el => { el.SetAttr("host", "web.example.com"); return el; })
        .Transform("config/database", el => { el.SetAttr("host", "db.example.com"); return el; });
    Expect(result.At("config/server")?.Attr("host") as string == "web.example.com",
        "Transform chained — server updated");
    Expect(result.At("config/database")?.Attr("host") as string == "db.example.com",
        "Transform chained — database updated");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    var updated = doc.Transform("config", el => { el.SetAttr("version", "2.0"); return el; });
    Expect(updated.Root()?.Attr("version") as string == "2.0",
        "Transform on top-level element");
}

// ── TransformAll ──────────────────────────────────────────────────────────────

Section("TransformAll");

{
    var doc = CXDocument.Parse(Fx("api_multi.cx"));
    var updated = doc.TransformAll("//service", el => { el.SetAttr("active", true); return el; });
    Expect(!ReferenceEquals(doc, updated), "TransformAll returns new document");
    var services = updated.FindAll("service").ToList();
    Expect(services.Count == 3, "TransformAll all matches updated");
    Expect(services.All(s => s.Attr("active") is true), "TransformAll function applied to all");
}

{
    var doc = CXDocument.Parse(Fx("api_multi.cx"));
    doc.TransformAll("//service", el => { el.SetAttr("active", true); return el; });
    var services = doc.FindAll("service").ToList();
    Expect(services.All(s => s.Attr("active") is null), "TransformAll original unchanged");
}

{
    var doc = CXDocument.Parse(Fx("api_config.cx"));
    var same = doc.TransformAll("//nonexistent", el => el);
    Expect(same.ToCx() == doc.ToCx(), "TransformAll no matches returns equivalent document");
}

{
    var doc = CXDocument.Parse(Fx("api_article.cx"));
    var updated = doc.TransformAll("//p", el => { el.SetAttr("class", "para"); return el; });
    var ps = updated.FindAll("p").ToList();
    Expect(ps.Count == 3, "TransformAll deeply nested — all matched");
    Expect(ps.All(p => p.Attr("class") as string == "para"),
        "TransformAll deeply nested — all updated");
}

// ── data_bin one-shots (Phase 7.28; spec/abi.md §2.4–§2.5) ───────────────────

Section("data_bin one-shots");

byte[] Reframe(byte[] payload)
{
    var framed = new byte[4 + payload.Length];
    BitConverter.GetBytes((uint)payload.Length).CopyTo(framed, 0);
    Buffer.BlockCopy(payload, 0, framed, 4, payload.Length);
    return framed;
}

{
    var payload = CxLib.XmlToDataBin("<server><host>localhost</host><port>8080</port></server>");
    Expect(payload.Length > 4 && payload[0] == 'C' && payload[1] == 'X' && payload[2] == 'D' && payload[3] == 'B',
        "XmlToDataBin returns CXDB payload");
    var xml = CxLib.DataBinToXml(Reframe(payload));
    Expect(xml.Contains("server") && xml.Contains("localhost") && xml.Contains("8080"),
        "xml round-trip through data_bin");
}

{
    var payload = CxLib.JsonToDataBin("{\"name\": \"alice\", \"id\": 1}");
    var json = CxLib.DataBinToJson(Reframe(payload));
    Expect(json.Contains("alice") && json.Contains("1"), "json round-trip through data_bin");
}

{
    var payload = CxLib.YamlToDataBin("name: alice\nid: 1\n");
    var yaml = CxLib.DataBinToYaml(Reframe(payload));
    Expect(yaml.Contains("alice"), "yaml round-trip through data_bin");
}

{
    var payload = CxLib.TomlToDataBin("name = \"alice\"\nid = 1\n");
    var toml = CxLib.DataBinToToml(Reframe(payload));
    Expect(toml.Contains("alice"), "toml round-trip through data_bin");
}

{
    var payload = CxLib.MdToDataBin("# Title\n\nA paragraph.\n");
    var md = CxLib.DataBinToMd(Reframe(payload));
    Expect(md.Contains("Title"), "md round-trip through data_bin");
}

{
    var payload = CxLib.XmlToDataBin("<user id=\"1\" name=\"alice\"/>");
    var json = CxLib.DataBinToJson(Reframe(payload));
    Expect(json.Contains("alice") && json.Contains("1"), "xml → data_bin → json");
}

{
    var payload = CxLib.JsonToDataBin("{\"name\": \"alice\", \"active\": true}");
    var yaml = CxLib.DataBinToYaml(Reframe(payload));
    Expect(yaml.Contains("alice"), "json → data_bin → yaml");
}

{
    var payload = CxLib.TomlToDataBin("host = \"localhost\"\nport = 8080\n");
    var xml = CxLib.DataBinToXml(Reframe(payload));
    Expect(xml.Contains("localhost") && xml.Contains("8080"), "toml → data_bin → xml");
}

// ── namespaces (Phase 7.58 / ADR 0002) ────────────────────────────────────────

Section("namespaces");

{
    var doc = CXDocument.Parse("[html xmlns=http://www.w3.org/1999/xhtml [body [p Hi]]]");
    var html = doc.Root()!;
    Expect(html.LocalName() == "html", "default ns: element local");
    Expect(html.NamespaceUri() == "http://www.w3.org/1999/xhtml", "default ns: element URI");
    Expect(html.Get("body")!.NamespaceUri() == "http://www.w3.org/1999/xhtml",
        "default ns inherits to descendants");
}

{
    var doc = CXDocument.Parse("[html xmlns=urn:x id=top body]");
    var id = doc.Root()!.Attrs.First(a => a.Name == "id");
    Expect(id.NamespaceUri() == null, "default ns does NOT apply to unprefixed attrs");
    Expect(id.LocalName() == "id", "unprefixed attr local-name");
}

{
    var doc = CXDocument.Parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ [dc:title Hi]]");
    var title = doc.Root()!.Get("dc:title")!;
    Expect(title.LocalName() == "title", "prefixed element: local part");
    Expect(title.NamespaceUri() == "http://purl.org/dc/elements/1.1/",
        "prefixed element: resolved URI");
}

{
    var doc = CXDocument.Parse(
        "[doc xmlns:xl=http://www.w3.org/1999/xlink [link xl:href=https://example.com Click]]");
    var href = doc.Root()!.Get("link")!.Attrs.First(a => a.Name == "xl:href");
    Expect(href.LocalName() == "href" && href.NamespaceUri() == "http://www.w3.org/1999/xlink",
        "prefixed attribute resolves");
}

{
    var doc = CXDocument.Parse("[doc xml:base=https://example.com content]");
    var b = doc.Root()!.Attrs.First(a => a.Name == "xml:base");
    Expect(b.NamespaceUri() == CXDocument.XmlNamespaceUri, "reserved xml: prefix");
}

{
    var doc = CXDocument.Parse("[doc [cx:meta key=value]]");
    var m = doc.Root()!.Get("cx:meta")!;
    Expect(m.NamespaceUri() == CXDocument.CxNamespaceUri, "reserved cx: prefix");
}

{
    var doc = CXDocument.Parse("[doc [foo:bar baz]]");
    var bar = doc.Root()!.Get("foo:bar")!;
    Expect(bar.LocalName() == "bar" && bar.NamespaceUri() == null,
        "undeclared prefix passes through unbound");
}

{
    var doc = CXDocument.Parse(
        "[html xmlns=http://www.w3.org/1999/xhtml [body [svg xmlns=http://www.w3.org/2000/svg [circle r=10]]]]");
    var html = doc.Root()!;
    var body = html.Get("body")!;
    var svg = body.Get("svg")!;
    var circle = svg.Get("circle")!;
    Expect(html.NamespaceUri() == "http://www.w3.org/1999/xhtml" &&
           body.NamespaceUri() == "http://www.w3.org/1999/xhtml" &&
           svg.NamespaceUri() == "http://www.w3.org/2000/svg" &&
           circle.NamespaceUri() == "http://www.w3.org/2000/svg",
        "subtree redeclaration overrides default");
}

{
    var doc = CXDocument.Parse("[outer xmlns=urn:x [inner xmlns='' [child x=1]]]");
    var outer = doc.Root()!;
    var inner = outer.Get("inner")!;
    var child = inner.Get("child")!;
    Expect(outer.NamespaceUri() == "urn:x" &&
           inner.NamespaceUri() == null &&
           child.NamespaceUri() == null,
        "xmlns='' undeclares default ns");
}

{
    var doc = CXDocument.Parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ [dc:title Hi]]");
    var first = doc.Root()!.Get("dc:title")!.NamespaceUri();
    CXDocument.ResolveNamespaces(doc);
    CXDocument.ResolveNamespaces(doc);
    var second = doc.Root()!.Get("dc:title")!.NamespaceUri();
    Expect(first == second && first == "http://purl.org/dc/elements/1.1/",
        "ResolveNamespaces is idempotent");
}

{
    var doc = CXDocument.Parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ body]");
    var decl = doc.Root()!.Attrs.First(a => a.Name == "xmlns:dc");
    Expect(decl.NamespaceUri() == null && decl.LocalName() == "dc",
        "xmlns: declaration attrs have no resolved URI");
}

// ── ID/IDREF (Phase 7.62 / ADR 0003) ──────────────────────────────────────────

Section("id/idref");

{
    var cxIn = "[user #u-1 name=alice]";
    var doc = CXDocument.Parse(cxIn);
    Expect(doc.Root()!.Id == "u-1", "id declaration parsed");
    Expect(doc.ToCx() == cxIn, "id declaration round-trips");
}

{
    var doc = CXDocument.Parse("[item &a #u-1 v=42]");
    var item = doc.Root()!;
    Expect(item.Anchor == "a" && item.Id == "u-1", "id coexists with anchor");
}

{
    var doc = CXDocument.Parse("[users [user #u-1 name=alice] [reviewer assigned-to=@u-1]]");
    var a = doc.FindFirst("reviewer")!.Attrs.First(x => x.Name == "assigned-to");
    Expect(a.IsRef && (string)a.Value! == "u-1", "@id reference is_ref + value");
}

{
    var doc = CXDocument.Parse("[users [user #u-1 name=alice] [user #u-2 name=bob]]");
    Expect((string?)doc.ResolveId("u-1")?.Attr("name") == "alice", "ResolveId u-1");
    Expect((string?)doc.ResolveId("u-2")?.Attr("name") == "bob",   "ResolveId u-2");
    Expect(doc.ResolveId("u-3") is null, "ResolveId missing returns null");
}

{
    var doc = CXDocument.Parse("[a #x v=1] [b #y v=2] [c #z v=3]");
    var m = doc.ElementsById();
    Expect(m.Count == 3 && m["x"].Name == "a" && m["y"].Name == "b" && m["z"].Name == "c",
        "ElementsById full map");
}

{
    var cxIn = "[item label='@literal']";
    var doc = CXDocument.Parse(cxIn);
    var label = doc.Root()!.Attrs.First(a => a.Name == "label");
    Expect(!label.IsRef && (string)label.Value! == "@literal",
        "quoted '@literal' is not a reference");
    Expect(doc.ToCx() == cxIn, "quoted '@literal' round-trips");
}

{
    var doc = CXDocument.Parse("[users [reviewer assigned-to=@u-1] [user #u-1 name=alice]]");
    Expect((string?)doc.ResolveId("u-1")?.Attr("name") == "alice", "forward reference resolves");
}

{
    var cxIn = "[doc\n  [users\n    [user #u-1 name=alice]\n  ]\n  [reviews\n    [review target=@u-1 score=5]\n  ]\n]";
    var doc = CXDocument.Parse(cxIn);
    Expect(doc.ResolveId("u-1") is not null, "nested ResolveId");
    var t = doc.FindFirst("review")!.Attrs.First(a => a.Name == "target");
    Expect(t.IsRef && (string)t.Value! == "u-1", "nested ref attr");
}

{
    var doc = CXDocument.Parse(
        "[users [user #u-1 name=alice] " +
        "[reviewer assigned-to=@u-1] " +
        "[approver checked-by=@u-1]]");
    int count = 0;
    foreach (var el in doc.FindAll("reviewer").Concat(doc.FindAll("approver")))
        foreach (var a in el.Attrs)
            if (a.IsRef && (string?)a.Value == "u-1") count++;
    Expect(count == 2, "multiple refs to same id");
}

// Phase 7.70 / ADR 0003 D1: body-position reference round-trips through ast_bin v3.
{
    var cxIn = "[doc [section #section-3 [para See [ref @section-3].]]]";
    var doc = CXDocument.Parse(cxIn);
    var refEl = doc.FindFirst("ref")!;
    Expect(refEl.BodyRef == "section-3", "BodyRef survives ast_bin round-trip");
    Expect(refEl.Attrs.Count == 0, "body-ref element has no attrs");
    Expect(refEl.Items.Count == 0, "body-ref element has no items");
    Expect(doc.ToCx().Contains("[ref @section-3]"), "[ref @section-3] in ToCx output");
}

// ── ID/IDREF C ABI (Phase 7.65 / ADR 0003) ────────────────────────────────────

Section("id/idref C ABI");

{
    string doc = "[users\n  [user #u-1 name=alice]\n  [user #u-2 name=bob]\n  [reviewer assigned-to=@u-1]\n]";

    // 1. id_lookup happy path: AST-JSON contains type/name/id.
    {
        string? json = CxLib.IdLookup(doc, "u-1");
        Expect(json is not null, "IdLookup u-1 returns non-null");
        using var parsed = JsonDocument.Parse(json!);
        var r = parsed.RootElement;
        Expect(r.GetProperty("type").GetString() == "Element", "IdLookup u-1: type=Element");
        Expect(r.GetProperty("name").GetString() == "user",    "IdLookup u-1: name=user");
        Expect(r.GetProperty("id").GetString()   == "u-1",     "IdLookup u-1: id=u-1");
    }

    // 2. id_lookup missing returns null.
    {
        Expect(CxLib.IdLookup(doc, "does-not-exist") is null, "IdLookup missing returns null");
    }

    // 3. resolve_ref equals id_lookup for same id.
    {
        string? a = CxLib.IdLookup  (doc, "u-2");
        string? b = CxLib.ResolveRef(doc, "u-2");
        Expect(a is not null && a == b, "ResolveRef equals IdLookup for u-2");
    }

    // 4. node_id at cxpath: //user matches first user with id u-1; //reviewer has no id.
    {
        Expect(CxLib.NodeId(doc, "//user")     == "u-1", "NodeId //user == u-1");
        Expect(CxLib.NodeId(doc, "//reviewer") is null,  "NodeId //reviewer is null (no id)");
    }
}

// ── delimited (CSV/TSV/PSV/arbitrary) (ADR 0001 / Phase 7.68) ────────────────

Section("delimited");

// Emit (5)
{
    var src = "[users :table[name:string age:int active:bool]\n  alice 30 true\n  bob 25 false\n]";
    var got = CxLib.ToCsv(src);
    Expect(got == "name,age,active\r\nalice,30,true\r\nbob,25,false\r\n",
        "to_csv table direct");
}
{
    var src = "[users\n  [user id=1 name=alice +admin]\n  [user id=2 name=bob]\n  [user id=3 name=carol +admin]\n]";
    var got = CxLib.ToCsv(src);
    Expect(got == "id,name,admin\r\n1,alice,true\r\n2,bob,\r\n3,carol,true\r\n",
        "to_csv repeated row (missing +admin → empty cell)");
}
{
    var src = "[config\n  [server host=localhost port=8080 +tls]\n  [logging level=info format=json]\n]";
    var got = CxLib.ToCsv(src);
    var expected = "server.host,server.port,server.tls,logging.level,logging.format\r\nlocalhost,8080,true,info,json\r\n";
    Expect(got == expected, "to_csv dotted path");
}
{
    var src = "[t :table[a b c]\n  x y z\n]";
    Expect(CxLib.ToTsv(src) == "a\tb\tc\r\nx\ty\tz\r\n", "to_tsv");
}
{
    var src = "[t :table[a b]\n  x y\n]";
    Expect(CxLib.ToPsv(src) == "a|b\r\nx|y\r\n", "to_psv");
}

// Parse (3)
{
    var got = CxLib.FromCsv("name,age,active\nalice,30,true\nbob,25,false\n");
    var expected = "[table :table[name age:int active:bool]\n  alice 30 true\n  bob 25 false\n]";
    Expect(got == expected, "from_csv auto-types");
}
{
    var got = CxLib.FromCsv("name,age\nalice,\"30\"\nbob,\"25\"\n");
    var expected = "[table :table[name age]\n  alice 30\n  bob 25\n]";
    Expect(got == expected, "from_csv quoted stays string");
}
{
    var got = CxLib.FromCsv("name,age\nalice,30\nbob,\n");
    var expected = "[table :table[name age:int]\n  alice 30\n  bob null\n]";
    Expect(got == expected, "from_csv empty cell is null");
}

// Arbitrary delimiter + binary one-shots (4)
{
    var src = "[t :table[a b]\n  x y\n]";
    Expect(CxLib.ToDelimited(src, ';') == "a;b\r\nx;y\r\n",
        "to_delimited semicolon");
}
{
    var payload = CxLib.CsvToDataBin("name,age\nalice,30\nbob,25\n");
    Expect(payload.Length > 4 && payload[0] == 'C' && payload[1] == 'X' && payload[2] == 'D' && payload[3] == 'B',
        "csv_to_data_bin returns CXDB payload");
    var got = CxLib.DataBinToCsv(Reframe(payload));
    Expect(got == "name,age\r\nalice,30\r\nbob,25\r\n", "csv → data_bin → csv round-trip");
}
{
    var payload = CxLib.TsvToDataBin("a\tb\nx\ty\n");
    var got = CxLib.DataBinToTsv(Reframe(payload));
    Expect(got == "a\tb\r\nx\ty\r\n", "tsv → data_bin → tsv round-trip");
}
{
    var payload = CxLib.PsvToDataBin("a|b\nx|y\n");
    var got = CxLib.DataBinToPsv(Reframe(payload));
    Expect(got == "a|b\r\nx|y\r\n", "psv → data_bin → psv round-trip");
}

// ── streaming Table + schema-driven + chunked-table (Phase 7.74b-cont-2) ─────

Section("streaming table");

const string smallTableCx =
    "[points :table[name:string score:i32]\n" +
    "  alice 91\n" +
    "  bob 88\n" +
    "  carol 73\n" +
    "  dave 95\n" +
    "  eve 84\n" +
    "  frank 60\n" +
    "]";

{
    // 1. in-memory round-trip: chunked → reader → writer → from_data_bin.
    var payload = CxLib.ToDataBinChunked(smallTableCx);
    Expect(payload.Length > 12 &&
           payload[0] == 'C' && payload[1] == 'X' && payload[2] == 'D' && payload[3] == 'B',
        "ToDataBinChunked returns CXDB payload");

    var framed = Reframe(payload);
    using var reader = new TableReader(framed);
    var schema = reader.Schema();
    Expect(schema.Length > 4, "Schema returns framed ast_bin");
    var groups = reader.ToList();
    Expect(groups.Count >= 1, "reader yields at least one row group");

    using var writer = new TableWriter(schema);
    foreach (var g in groups) writer.Emit(g);
    var rebuilt = writer.CloseGetBytes();
    var cx = CxLib.FromDataBin(rebuilt);
    Expect(cx.Contains(":table"), "rebuilt CX contains :table body marker");
    Expect(cx.Contains("alice") && cx.Contains("frank"),
        "rebuilt CX contains all row values");
}

{
    // 2. fd round-trip: stream through fd writer → fd reader; assert schema +
    //    group count drift. Mirrors the Python pattern exactly.
    var payload = CxLib.ToDataBinChunked(smallTableCx);
    using (var rIn = new TableReader(Reframe(payload)))
    {
        var schema = rIn.Schema();
        var groups = rIn.ToList();

        string tmpPath = Path.Combine(Path.GetTempPath(),
            $"cx_csharp_streaming_{Guid.NewGuid()}.cxdb");
        try
        {
            using (var outFs = new FileStream(tmpPath, FileMode.Create, FileAccess.Write))
            {
                int outFd = (int)outFs.SafeFileHandle.DangerousGetHandle();
                using var w = TableWriter.ToFd(schema, outFd);
                foreach (var g in groups) w.Emit(g);
                // w.Close on dispose flushes end-of-table.
            }

            using var inFs = new FileStream(tmpPath, FileMode.Open, FileAccess.Read);
            int inFd = (int)inFs.SafeFileHandle.DangerousGetHandle();
            using var rOut = TableReader.FromFd(inFd);
            var schemaOut = rOut.Schema();
            var groupsOut = rOut.ToList();

            Expect(schemaOut.SequenceEqual(schema), "fd round-trip: schema preserved");
            Expect(groupsOut.Count == groups.Count,
                $"fd round-trip: group count preserved ({groupsOut.Count} vs {groups.Count})");
        }
        finally { try { File.Delete(tmpPath); } catch { } }
    }
}

{
    // 3. closed-handle errors.
    var payload = CxLib.ToDataBinChunked(smallTableCx);
    var framed = Reframe(payload);

    var reader = new TableReader(framed);
    reader.Close();
    Expect(reader.Next() is null, "Next() on closed reader yields null");
    bool threw = false;
    try { reader.Schema(); } catch (InvalidOperationException) { threw = true; }
    Expect(threw, "Schema() on closed reader throws");

    var r2 = new TableReader(framed);
    var schema = r2.Schema();
    var groups = r2.ToList();
    r2.Close();

    var writer = new TableWriter(schema);
    foreach (var g in groups) writer.Emit(g);
    _ = writer.CloseGetBytes();
    bool emitThrew = false;
    try { writer.Emit(groups[0]); }
    catch (InvalidOperationException) { emitThrew = true; }
    Expect(emitThrew, "Emit after CloseGetBytes throws");
}

{
    // 4. concatenate row groups from two distinct sources sharing a schema.
    var p1 = CxLib.ToDataBinChunked(
        "[points :table[name:string score:i32] alice 91 bob 88]");
    var p2 = CxLib.ToDataBinChunked(
        "[points :table[name:string score:i32] carol 73 dave 95 eve 84]");

    using var r1 = new TableReader(Reframe(p1));
    var schema = r1.Schema();
    var g1 = r1.ToList();
    using var r2 = new TableReader(Reframe(p2));
    var g2 = r2.ToList();

    Expect(g1.Count >= 1 && g2.Count >= 1, "both readers yield row groups");

    using var w = new TableWriter(schema);
    foreach (var g in g1) w.Emit(g);
    foreach (var g in g2) w.Emit(g);
    var rebuilt = w.CloseGetBytes();
    var cx = CxLib.FromDataBin(rebuilt);
    foreach (var needle in new[] { "alice", "bob", "carol", "dave", "eve" })
    {
        Expect(cx.Contains(needle), $"merged CX contains '{needle}'");
    }
}

Section("schema-driven encoding");

{
    // 5. schema-driven round-trip (CX text → schema-driven CXDB → CX text).
    string cxText = "[server [host \"localhost\"] [port 8080]]";
    string schema = "[server [host :string] [port :int]]";
    var payload = CxLib.ToDataBinSchemaDriven(cxText, schema);
    Expect(payload.Length > 12 &&
           payload[0] == 'C' && payload[1] == 'X' && payload[2] == 'D' && payload[3] == 'B',
        "ToDataBinSchemaDriven returns CXDB payload");

    var framed = Reframe(payload);
    var roundtrip = CxLib.FromDataBinSchemaDriven(framed, schema);
    Expect(roundtrip.Contains("server"),  "schema-driven round-trip contains 'server'");
    Expect(roundtrip.Contains("localhost"), "schema-driven round-trip contains 'localhost'");
    Expect(roundtrip.Contains("8080"),    "schema-driven round-trip contains '8080'");
}

Section("schema validator");

{
    // Smoke tests for the schema-validator binding (Phase 7.74d / ADR 0009).
    // The full sweep stays on the V/Python/Go side (51 fixtures × 3 bindings).
    string bookSchema = @"
[?cx schema-of book]

[book
  [body :elem]
  [attr id :string :req]
  [elem title :card='1..1']
  [elem author :card='1..*']
]

[title [body :string]]
[author [body :string]]
";

    // 1. Valid document — zero errors.
    {
        string doc = @"
[book id='b1'
  [title 'The Stand']
  [author 'King']
]
";
        var report = CxLib.Validate(doc, bookSchema);
        Expect(report.IsValid,         "valid book → IsValid");
        Expect(report.ErrorCount == 0, "valid book → ErrorCount == 0");
    }

    // 2. Missing :req attribute fires S002.
    {
        string doc = "[book\n  [title 'X']\n  [author 'Y']\n]\n";
        var report = CxLib.Validate(doc, bookSchema);
        Expect(report.ErrorCodes().SequenceEqual(new[] { "S002" }),
            "missing :req attr fires S002 only");
        Expect(report.Diagnostics[0].Severity == Severity.Error,
            "S002 diagnostic severity == Error");
    }

    // 3. Wrong root element fires S017.
    {
        string doc = "[other id='x']";
        var report = CxLib.Validate(doc, bookSchema);
        Expect(report.ErrorCodes().SequenceEqual(new[] { "S017" }),
            "root mismatch fires S017");
    }

    // 4. `[?cx schema=PATH]` directive without a caller-supplied schema fires S010.
    {
        string doc = "[?cx schema=path/to/book.cxs]\n[book id='b1' [title 'X']]\n";
        var report = CxLib.Validate(doc, "");
        Expect(report.ErrorCodes().SequenceEqual(new[] { "S010" }),
            "schema directive w/o caller schema fires S010");
    }

    // 5. ValidateWithDefaults populates ModifiedDoc from `:def='…'`.
    {
        string schema = @"
[?cx schema-of server]

[server
  [body :elem]
  [attr host :string :def='localhost']
]
";
        string doc = "[server]";
        var report = CxLib.ValidateWithDefaults(doc, schema);
        Expect(report.IsValid, "apply-defaults: zero errors");
        Expect(report.ModifiedDoc.Contains("host="),
            "apply-defaults writes default into ModifiedDoc");
    }
}

// ── streaming-write API (spec/streaming.md §6 + ADR 0011) ─────────────────────

Section("streaming-write — EventWriter");

byte[] ColSpec2()
{
    // 2 columns: name:string (0x30), score:i32 (0x12)
    using var ms = new MemoryStream();
    void U32(int v) { ms.Write(BitConverter.GetBytes(v), 0, 4); }
    U32(2);
    U32(4); ms.Write(System.Text.Encoding.UTF8.GetBytes("name"));  ms.WriteByte(0x30);
    U32(5); ms.Write(System.Text.Encoding.UTF8.GetBytes("score")); ms.WriteByte(0x12);
    return ms.ToArray();
}

byte[] RowGroup2()
{
    // uvarint(2) + col1 strings + col2 i32 LE
    using var ms = new MemoryStream();
    ms.WriteByte(2);
    ms.WriteByte(5); ms.Write(System.Text.Encoding.UTF8.GetBytes("alice"));
    ms.WriteByte(3); ms.Write(System.Text.Encoding.UTF8.GetBytes("bob"));
    ms.Write(BitConverter.GetBytes(91));
    ms.Write(BitConverter.GetBytes(88));
    return ms.ToArray();
}

void ExpectWcode(string code, Action f, string what)
{
    try
    {
        f();
        Expect(false, $"{what}: expected {code}, no exception thrown");
    }
    catch (InvalidOperationException e)
    {
        Expect(e.Message.StartsWith(code), $"{what}: expected {code} prefix, got {e.Message}");
    }
}

Expect(EventWriter.HasCapability, "capability bit 27 advertised");

{
    using var w = new EventWriter("cx");
    w.StartDoc();
    w.StartElement("greet");
    w.Text("hello");
    w.EndElement("greet");
    w.EndDoc();
    var bytes = w.CloseGetBytes();
    var s = System.Text.Encoding.UTF8.GetString(bytes);
    Expect(s.Contains("[greet"), "cx minimal: contains [greet");
    Expect(s.Contains("hello"),  "cx minimal: contains hello");
}

{
    using var w = new EventWriter("cx");
    w.StartDoc();
    w.StartElement("book", attrs: new[] {
        new EventAttr("id", "b1", "string"),
        new EventAttr("yr", "2024", "int"),
    });
    w.EndElement("book");
    w.EndDoc();
    var s = System.Text.Encoding.UTF8.GetString(w.CloseGetBytes());
    Expect(s.Contains("id="), "attrs: id=");
    Expect(s.Contains("b1"),  "attrs: b1");
}

{
    using var w = new EventWriter("xml");
    w.StartDoc();
    w.StartElement("greet");
    w.Text("hello");
    w.EndElement("greet");
    w.EndDoc();
    var s = System.Text.Encoding.UTF8.GetString(w.CloseGetBytes());
    Expect(s.Contains("<?xml version=\"1.0\"?>"), "xml minimal: prolog");
    Expect(s.Contains("<greet>") && s.Contains("</greet>"), "xml minimal: element tags");
    Expect(s.Contains("hello"), "xml minimal: text");
}

ExpectWcode("W001", () => { var w = new EventWriter("cx"); w.StartDoc(); w.StartDoc(); }, "W001 double StartDoc");
ExpectWcode("W002", () => { var w = new EventWriter("cx"); w.Text("premature"); }, "W002 text before StartDoc");
ExpectWcode("W003", () => { var w = new EventWriter("cx"); w.StartDoc(); w.EndDoc(); w.Text("post"); }, "W003 text after EndDoc");
ExpectWcode("W004", () => { var w = new EventWriter("cx"); w.StartDoc(); w.StartElement("open"); w.EndDoc(); }, "W004 unclosed element on EndDoc");
ExpectWcode("W005", () => { var w = new EventWriter("cx"); w.StartDoc(); w.StartElement("greet"); w.EndElement("farewell"); }, "W005 end-element mismatch");
ExpectWcode("W006", () => { var w = new EventWriter("cx"); w.StartDoc(); w.EndElement("orphan"); }, "W006 orphan EndElement");
ExpectWcode("W008", () => { var w = new EventWriter("cx"); w.StartDoc(); w.Scalar("42", "not_a_type"); }, "W008 invalid scalar type");
ExpectWcode("W009", () => { var w = new EventWriter("xml"); w.StartDoc(); w.StartTable(new byte[]{1,0,0,0,1,0,0,0,(byte)'x',0x12}); }, "W009 chunked on xml");
ExpectWcode("W012", () => { var w = new EventWriter("cx"); w.StartDoc(); w.RowGroup(new byte[]{1}); }, "W012 orphan RowGroup");
ExpectWcode("W013", () => { var w = new EventWriter("cx"); w.StartDoc(); w.EndTable(); }, "W013 orphan EndTable");

{
    // fail-closed: subsequent emit returns same W-code without effect.
    using var w = new EventWriter("cx");
    try { w.Text("premature"); Expect(false, "fail-closed: first call did not throw"); }
    catch (InvalidOperationException e1) { Expect(e1.Message.StartsWith("W002"), "fail-closed: first W002"); }
    try { w.Text("again"); Expect(false, "fail-closed: second call did not throw"); }
    catch (InvalidOperationException e2) { Expect(e2.Message.StartsWith("W002"), "fail-closed: second still W002"); }
}

{
    // Chunked-table CX round-trip.
    using var w = new EventWriter("cx");
    w.StartDoc();
    w.StartElement("points");
    w.StartTable(ColSpec2());
    w.RowGroup(RowGroup2());
    w.EndTable();
    w.EndElement("points");
    w.EndDoc();
    var s = System.Text.Encoding.UTF8.GetString(w.CloseGetBytes());
    Expect(s.Contains(":table"), "chunked: contains :table");
    Expect(s.Contains("alice"),  "chunked: contains alice");
    Expect(s.Contains("91"),     "chunked: contains 91");
}

{
    // fd writer path.
    string tmp = Path.Combine(Path.GetTempPath(), $"cx_event_writer_csharp_{Environment.ProcessId}.cx");
    try
    {
        using (var fs = new FileStream(tmp, FileMode.Create, FileAccess.Write))
        using (var w = EventWriter.ToFd("cx", (int)fs.SafeFileHandle.DangerousGetHandle()))
        {
            w.StartDoc();
            w.StartElement("greet");
            w.Text("hello");
            w.EndElement("greet");
            w.EndDoc();
            var bytes = w.CloseGetBytes();
            Expect(bytes.Length == 0, "fd writer: CloseGetBytes returns empty");
        }
        var written = File.ReadAllText(tmp);
        Expect(written.Contains("[greet"), "fd output: contains [greet");
        Expect(written.Contains("hello"),  "fd output: contains hello");
    }
    finally { try { File.Delete(tmp); } catch {} }
}

// ── Public Table API (ADR 0018 D1) ────────────────────────────────────────────

Section("Table API — construction");

{
    string src = "[users :table[name age:int]\n" +
                 "  alice 30\n" +
                 "  bob 25\n" +
                 "]";
    var t = Table.FromCx(src);
    Expect(t.RowCount == 2, "FromCx: rowCount=2");
    Expect(t.ColCount == 2, "FromCx: colCount=2");
}

{
    try
    {
        Table.FromCx("[product name=alice]");
        Expect(false, "FromCx no-table did not throw");
    }
    catch (InvalidOperationException e)
    {
        Expect(e.Message.Contains("no :table"), "FromCx no-table errors");
    }
}

{
    try
    {
        Table.Create(new[] { "a", "b" }, new[] { "int" },
            new List<IReadOnlyList<object?>>());
        Expect(false, "Create len-mismatch did not throw");
    }
    catch (ArgumentException e)
    {
        Expect(e.Message.Contains("len(cols)"), "Create len mismatch errors");
    }
}

{
    try
    {
        Table.Create(new[] { "a", "a" }, new[] { "int", "int" },
            new List<IReadOnlyList<object?>>());
        Expect(false, "Create duplicate did not throw");
    }
    catch (ArgumentException e)
    {
        Expect(e.Message.Contains("duplicate"), "Create duplicate cols errors");
    }
}

Section("Table API — access");

{
    var t = Table.Create(
        new[] { "a", "b" },
        new[] { "int", "string" },
        new List<IReadOnlyList<object?>> {
            new object?[] { 1L, "x" },
            new object?[] { 2L, "y" },
        });
    var row = t.Row(0);
    Expect((long)row["a"]! == 1L && (string)row["b"]! == "x", "Row(0) by name");
    var col = t.Column("b");
    Expect((string)col[0]! == "x" && (string)col[1]! == "y", "Column(name)");
    Expect((long)t.Cell(1, 0)! == 2L, "Cell(r,c)");
    Expect((string)t.CellByName(1, "b")! == "y", "CellByName");
}

{
    var t = Table.Create(
        new[] { "v" }, new[] { "int" },
        new List<IReadOnlyList<object?>> {
            new object?[] { 1L }, new object?[] { 2L }, new object?[] { 3L },
            new object?[] { 4L }, new object?[] { 5L },
        });
    Expect(t.Head(2).RowCount == 2, "Head(2)");
    Expect(t.Tail(2).RowCount == 2, "Tail(2)");
    Expect(t.Slice(1, 4).RowCount == 3, "Slice(1,4)");
}

{
    var t = Table.Create(
        new[] { "a", "b", "c" },
        new[] { "int", "int", "int" },
        new List<IReadOnlyList<object?>> { new object?[] { 1L, 2L, 3L } });
    var sel = t.SelectCols(new[] { "c", "a" });
    Expect(sel.Cols.SequenceEqual(new[] { "c", "a" }), "SelectCols reorders");
}

Section("Table API — iteration / conversion");

{
    var t = Table.Create(
        new[] { "a" }, new[] { "int" },
        new List<IReadOnlyList<object?>> {
            new object?[] { 1L }, new object?[] { 2L }
        });
    int sum = 0;
    foreach (var row in t) sum += (int)(long)row["a"]!;
    Expect(sum == 3, "Iteration sums values");
}

{
    var t = Table.Create(
        new[] { "a" }, new[] { "int" },
        new List<IReadOnlyList<object?>> { new object?[] { 1L } });
    Expect(t.ToCx().Contains(":table[a:int]"), "ToCx contains :table[a:int]");
}

{
    var t = Table.Create(
        new[] { "a" }, new[] { "int" },
        new List<IReadOnlyList<object?>> {
            new object?[] { 1L }, new object?[] { 2L }
        });
    string js = t.ToJson();
    Expect(js.Contains("\"a\":1"), "ToJson contains a:1");
}

{
    var a = Table.Create(new[] { "a" }, new[] { "int" },
        new List<IReadOnlyList<object?>> { new object?[] { 1L } });
    var b = Table.Create(new[] { "a" }, new[] { "int" },
        new List<IReadOnlyList<object?>> { new object?[] { 1L } });
    Expect(a.Equals(b), "Equals on equal tables");
}

{
    string src = "[u :table[name tags]\n" +
                 "  alice [admin, user,]\n" +
                 "]";
    var t = Table.FromCx(src);
    var row = t.Row(0);
    Expect(row["tags"] is IList<object?>, "FromCx collection cell yields list");
}

// ── summary ───────────────────────────────────────────────────────────────────

Console.WriteLine($"\ncsharp/api_test: {passed} passed, {failed} failed  [{(failed == 0 ? "OK" : "FAILED")}]");
if (failed > 0) Environment.Exit(1);
