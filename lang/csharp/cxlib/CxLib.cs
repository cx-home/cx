using System;
using System.IO;
using System.Runtime.InteropServices;

namespace CX;

/// <summary>CX C# binding — P/Invoke wrapper around libcx.</summary>
public static partial class CxLib
{
    private const string Lib = "cx";

    static CxLib()
    {
        NativeLibrary.SetDllImportResolver(typeof(CxLib).Assembly,
            (name, _, _) =>
            {
                if (name != Lib) return IntPtr.Zero;
                var candidates = new List<string>();

                // 1. Explicit path override
                var envPath = Environment.GetEnvironmentVariable("LIBCX_PATH");
                if (envPath != null) candidates.Add(envPath);

                // 2. Directory override
                var envDir = Environment.GetEnvironmentVariable("LIBCX_LIB_DIR");
                if (envDir != null)
                {
                    candidates.Add(Path.Combine(envDir, "libcx.dylib"));
                    candidates.Add(Path.Combine(envDir, "libcx.so"));
                }

                // 3. System paths
                foreach (var dir in new[] { "/usr/local/lib", "/opt/homebrew/lib", "/usr/lib",
                                            "/usr/lib/x86_64-linux-gnu", "/usr/lib/aarch64-linux-gnu" })
                {
                    candidates.Add(Path.Combine(dir, "libcx.dylib"));
                    candidates.Add(Path.Combine(dir, "libcx.so"));
                }

                // 4. Repo-relative fallback (development)
                try
                {
                    string repoRoot = FindRepoRoot(AppContext.BaseDirectory);
                    candidates.Add(Path.Combine(repoRoot, "vcx", "target", "libcx.dylib"));
                    candidates.Add(Path.Combine(repoRoot, "vcx", "target", "libcx.so"));
                    candidates.Add(Path.Combine(repoRoot, "dist", "lib", "libcx.dylib"));
                    candidates.Add(Path.Combine(repoRoot, "dist", "lib", "libcx.so"));
                }
                catch { /* no repo root found — skip */ }

                foreach (var p in candidates)
                    if (File.Exists(p) && NativeLibrary.TryLoad(p, out var h)) return h;
                throw new DllNotFoundException(
                    "libcx not found. Install with 'sudo make install' or set LIBCX_PATH.");
            });

        // Run libcx's thread-init handshake at module load (spec/abi.md
        // §1.5.5, capability bit 26). The .NET CLR doesn't yet trip the
        // libgc trampoline-page issue the way Rust's cargo workers do
        // (Rust SIGABRT, fixed in commit f646840), but the spec calls
        // cx_init mandatory for all bindings — wire it now while the
        // ABI is fresh.
        NativeInit();
    }

    [DllImport(Lib, EntryPoint = "cx_init")]
    private static extern int NativeInit();

    private static string FindRepoRoot(string start)
    {
        var dir = new DirectoryInfo(start);
        while (dir != null)
        {
            if (Directory.Exists(Path.Combine(dir.FullName, "vcx"))) return dir.FullName;
            dir = dir.Parent;
        }
        throw new DirectoryNotFoundException("Cannot locate repo root from " + start);
    }

    // ── memory ────────────────────────────────────────────────────────────────

    [DllImport(Lib, EntryPoint = "cx_free")]
    private static extern void Free(IntPtr s);

    [DllImport(Lib, EntryPoint = "cx_version")]
    private static extern IntPtr NativeVersion();

    // ── CX input ──────────────────────────────────────────────────────────────
    [DllImport(Lib, EntryPoint = "cx_to_cx")]          private static extern IntPtr NativeToCx        (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_to_cx_compact")]  private static extern IntPtr NativeToCxCompact (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_ast_to_cx")]      private static extern IntPtr NativeAstToCx     (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_to_xml")]  private static extern IntPtr NativeToXml (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_to_ast")]  private static extern IntPtr NativeToAst (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_to_json")] private static extern IntPtr NativeToJson(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_to_yaml")] private static extern IntPtr NativeToYaml(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_to_toml")] private static extern IntPtr NativeToToml(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_to_md")]   private static extern IntPtr NativeToMd  (string i, out IntPtr e);

    // ── CXL evaluator (capability bit 28; spec/eval.md) ────────────────────────
    [DllImport(Lib, EntryPoint = "cx_eval")]
    private static extern IntPtr NativeEvalCxl(string input, string program, string outputTarget, out IntPtr e);

    // ── XML input ─────────────────────────────────────────────────────────────
    [DllImport(Lib, EntryPoint = "cx_xml_to_cx")]   private static extern IntPtr NativeXmlToCx  (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_xml_to_xml")]  private static extern IntPtr NativeXmlToXml (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_xml_to_ast")]  private static extern IntPtr NativeXmlToAst (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_xml_to_json")] private static extern IntPtr NativeXmlToJson(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_xml_to_yaml")] private static extern IntPtr NativeXmlToYaml(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_xml_to_toml")] private static extern IntPtr NativeXmlToToml(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_xml_to_md")]   private static extern IntPtr NativeXmlToMd  (string i, out IntPtr e);

    // ── JSON input ────────────────────────────────────────────────────────────
    [DllImport(Lib, EntryPoint = "cx_json_to_cx")]   private static extern IntPtr NativeJsonToCx  (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_json_to_xml")]  private static extern IntPtr NativeJsonToXml (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_json_to_ast")]  private static extern IntPtr NativeJsonToAst (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_json_to_json")] private static extern IntPtr NativeJsonToJson(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_json_to_yaml")] private static extern IntPtr NativeJsonToYaml(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_json_to_toml")] private static extern IntPtr NativeJsonToToml(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_json_to_md")]   private static extern IntPtr NativeJsonToMd  (string i, out IntPtr e);

    // ── YAML input ────────────────────────────────────────────────────────────
    [DllImport(Lib, EntryPoint = "cx_yaml_to_cx")]   private static extern IntPtr NativeYamlToCx  (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_yaml_to_xml")]  private static extern IntPtr NativeYamlToXml (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_yaml_to_ast")]  private static extern IntPtr NativeYamlToAst (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_yaml_to_json")] private static extern IntPtr NativeYamlToJson(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_yaml_to_yaml")] private static extern IntPtr NativeYamlToYaml(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_yaml_to_toml")] private static extern IntPtr NativeYamlToToml(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_yaml_to_md")]   private static extern IntPtr NativeYamlToMd  (string i, out IntPtr e);

    // ── TOML input ────────────────────────────────────────────────────────────
    [DllImport(Lib, EntryPoint = "cx_toml_to_cx")]   private static extern IntPtr NativeTomlToCx  (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_toml_to_xml")]  private static extern IntPtr NativeTomlToXml (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_toml_to_ast")]  private static extern IntPtr NativeTomlToAst (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_toml_to_json")] private static extern IntPtr NativeTomlToJson(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_toml_to_yaml")] private static extern IntPtr NativeTomlToYaml(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_toml_to_toml")] private static extern IntPtr NativeTomlToToml(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_toml_to_md")]   private static extern IntPtr NativeTomlToMd  (string i, out IntPtr e);

    // ── MD input ──────────────────────────────────────────────────────────────
    [DllImport(Lib, EntryPoint = "cx_md_to_cx")]   private static extern IntPtr NativeMdToCx  (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_md_to_xml")]  private static extern IntPtr NativeMdToXml (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_md_to_ast")]  private static extern IntPtr NativeMdToAst (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_md_to_json")] private static extern IntPtr NativeMdToJson(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_md_to_yaml")] private static extern IntPtr NativeMdToYaml(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_md_to_toml")] private static extern IntPtr NativeMdToToml(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_md_to_md")]   private static extern IntPtr NativeMdToMd  (string i, out IntPtr e);

    // ── binary functions ──────────────────────────────────────────────────────
    [DllImport(Lib, EntryPoint = "cx_to_ast_bin",    CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeToAstBin   (string i, out IntPtr e);

    [DllImport(Lib, EntryPoint = "cx_to_events_bin", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeToEventsBin(string i, out IntPtr e);

    [DllImport(Lib, EntryPoint = "cx_to_data_bin",   CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeToDataBin  (string i, out IntPtr e);

    // cx_from_data_bin takes binary input (no charset marshalling).
    [DllImport(Lib, EntryPoint = "cx_from_data_bin")]
    private static extern IntPtr NativeFromDataBin(byte[] i, out IntPtr e);

    // data_bin one-shot loaders/dumpers (Phase 7.28; spec/abi.md §2.4–§2.5).
    [DllImport(Lib, EntryPoint = "cx_xml_to_data_bin",  CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeXmlToDataBin (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_json_to_data_bin", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeJsonToDataBin(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_yaml_to_data_bin", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeYamlToDataBin(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_toml_to_data_bin", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeTomlToDataBin(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_md_to_data_bin",   CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeMdToDataBin  (string i, out IntPtr e);

    [DllImport(Lib, EntryPoint = "cx_data_bin_to_xml")]
    private static extern IntPtr NativeDataBinToXml (byte[] i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_data_bin_to_json")]
    private static extern IntPtr NativeDataBinToJson(byte[] i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_data_bin_to_yaml")]
    private static extern IntPtr NativeDataBinToYaml(byte[] i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_data_bin_to_toml")]
    private static extern IntPtr NativeDataBinToToml(byte[] i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_data_bin_to_md")]
    private static extern IntPtr NativeDataBinToMd  (byte[] i, out IntPtr e);

    // Delimited (CSV/TSV/PSV/arbitrary) C ABI (ADR 0001 / Phase 7.68).
    // Text-text (8): 2 delim-bearing + 6 named-delimiter aliases.
    [DllImport(Lib, EntryPoint = "cx_to_delimited",   CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeToDelimited  (string i, sbyte delim, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_from_delimited", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeFromDelimited(string i, sbyte delim, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_to_csv",   CharSet = CharSet.Ansi)] private static extern IntPtr NativeToCsv  (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_from_csv", CharSet = CharSet.Ansi)] private static extern IntPtr NativeFromCsv(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_to_tsv",   CharSet = CharSet.Ansi)] private static extern IntPtr NativeToTsv  (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_from_tsv", CharSet = CharSet.Ansi)] private static extern IntPtr NativeFromTsv(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_to_psv",   CharSet = CharSet.Ansi)] private static extern IntPtr NativeToPsv  (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_from_psv", CharSet = CharSet.Ansi)] private static extern IntPtr NativeFromPsv(string i, out IntPtr e);

    // Binary one-shots (6): csv/tsv/psv ↔ data_bin.
    [DllImport(Lib, EntryPoint = "cx_csv_to_data_bin", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeCsvToDataBin(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_tsv_to_data_bin", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeTsvToDataBin(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_psv_to_data_bin", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativePsvToDataBin(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_data_bin_to_csv")]
    private static extern IntPtr NativeDataBinToCsv(byte[] i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_data_bin_to_tsv")]
    private static extern IntPtr NativeDataBinToTsv(byte[] i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_data_bin_to_psv")]
    private static extern IntPtr NativeDataBinToPsv(byte[] i, out IntPtr e);

    // CXPath path-tracking C ABI (Phase 4 / CB-5).
    [DllImport(Lib, EntryPoint = "cx_select_all_paths", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeSelectAllPaths(string input, string expr, out IntPtr e);

    // Phase 5 / CB-1 — ast_bin → text format (binary input, no charset
    // marshalling on the input).
    [DllImport(Lib, EntryPoint = "cx_ast_bin_to_cx")]
    private static extern IntPtr NativeAstBinToCx  (byte[] i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_ast_bin_to_xml")]
    private static extern IntPtr NativeAstBinToXml (byte[] i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_ast_bin_to_json")]
    private static extern IntPtr NativeAstBinToJson(byte[] i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_ast_bin_to_yaml")]
    private static extern IntPtr NativeAstBinToYaml(byte[] i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_ast_bin_to_toml")]
    private static extern IntPtr NativeAstBinToToml(byte[] i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_ast_bin_to_md")]
    private static extern IntPtr NativeAstBinToMd  (byte[] i, out IntPtr e);

    // Phase 5 / CB-2 — text → ast_bin (returns framed binary).
    [DllImport(Lib, EntryPoint = "cx_xml_to_ast_bin",  CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeXmlToAstBin (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_json_to_ast_bin", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeJsonToAstBin(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_yaml_to_ast_bin", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeYamlToAstBin(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_toml_to_ast_bin", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeTomlToAstBin(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_md_to_ast_bin",   CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeMdToAstBin  (string i, out IntPtr e);

    // Phase 5 / CB-4 — events handle API.
    [DllImport(Lib, EntryPoint = "cx_events_open", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeEventsOpen (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_events_next")]
    private static extern IntPtr NativeEventsNext (IntPtr handle, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_events_close")]
    private static extern void   NativeEventsClose(IntPtr handle);

    // Phase 6 — canonical-form tooling (spec/abi.md §2.6).
    [DllImport(Lib, EntryPoint = "cx_fmt",       CharSet = CharSet.Ansi)] private static extern IntPtr NativeFmt      (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_canonical", CharSet = CharSet.Ansi)] private static extern IntPtr NativeCanonical(string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_hash",      CharSet = CharSet.Ansi)] private static extern IntPtr NativeHash     (string i, out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_eq",        CharSet = CharSet.Ansi)] private static extern IntPtr NativeEq       (string a, string b, out IntPtr e);

    // Phase 7.47 — cx diff (ADR 0012). format = "unified" | "json" | "summary".
    [DllImport(Lib, EntryPoint = "cx_diff",      CharSet = CharSet.Ansi)] private static extern IntPtr NativeDiff     (string a, string b, string format, out IntPtr e);

    // Phase 7.49 — cx lint (ADR 0013). format = "text" | "json" | "summary".
    [DllImport(Lib, EntryPoint = "cx_lint",      CharSet = CharSet.Ansi)] private static extern IntPtr NativeLint     (string input, string format, string disabled, out IntPtr e);

    // Phase 7.65 — ID/IDREF C ABI (ADR 0003).
    [DllImport(Lib, EntryPoint = "cx_id_lookup",   CharSet = CharSet.Ansi)] private static extern IntPtr NativeIdLookup  (string input, string id,     out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_resolve_ref", CharSet = CharSet.Ansi)] private static extern IntPtr NativeResolveRef(string input, string @ref,   out IntPtr e);
    [DllImport(Lib, EntryPoint = "cx_node_id",     CharSet = CharSet.Ansi)] private static extern IntPtr NativeNodeId    (string input, string cxpath, out IntPtr e);

    // ── helper ────────────────────────────────────────────────────────────────

    private static string Unwrap(IntPtr result, IntPtr errPtr)
    {
        if (result == IntPtr.Zero)
        {
            string msg = errPtr != IntPtr.Zero
                ? (Marshal.PtrToStringUTF8(errPtr) ?? "unknown error")
                : "unknown error";
            if (errPtr != IntPtr.Zero) Free(errPtr);
            throw new InvalidOperationException(msg);
        }
        string s = Marshal.PtrToStringUTF8(result) ?? "";
        Free(result);
        return s;
    }

    // ── binary helper ─────────────────────────────────────────────────────────

    /// <summary>
    /// Read a [u32 LE: payload_size][payload…] buffer from a native pointer,
    /// copy the payload into a managed byte[], free the native buffer, and return
    /// the payload bytes.
    /// </summary>
    private static byte[] UnwrapBin(IntPtr result, IntPtr errPtr)
    {
        if (result == IntPtr.Zero)
        {
            string msg = errPtr != IntPtr.Zero
                ? (Marshal.PtrToStringUTF8(errPtr) ?? "unknown error")
                : "unknown error";
            if (errPtr != IntPtr.Zero) Free(errPtr);
            throw new InvalidOperationException(msg);
        }

        // Read the 4-byte little-endian payload size.
        uint payloadSize = (uint)(
              Marshal.ReadByte(result, 0)
            | (Marshal.ReadByte(result, 1) << 8)
            | (Marshal.ReadByte(result, 2) << 16)
            | (Marshal.ReadByte(result, 3) << 24));

        var payload = new byte[payloadSize];
        Marshal.Copy(result + 4, payload, 0, (int)payloadSize);
        Free(result);
        return payload;
    }

    /// <summary>Call cx_to_ast_bin and return the raw payload bytes.</summary>
    public static byte[] AstBin(string cxStr)
    {
        var r = NativeToAstBin(cxStr, out var e);
        return UnwrapBin(r, e);
    }

    /// <summary>Call cx_to_events_bin and return the raw payload bytes.</summary>
    public static byte[] EventsBin(string cxStr)
    {
        var r = NativeToEventsBin(cxStr, out var e);
        return UnwrapBin(r, e);
    }

    /// <summary>
    /// Call cx_to_data_bin and return the CXDB v1 PAYLOAD (the [u32 LE size]
    /// frame is stripped by UnwrapBin). Pass the result to <see cref="DataBin.Decode"/>.
    /// </summary>
    public static byte[] ToDataBin(string cxStr)
    {
        var r = NativeToDataBin(cxStr, out var e);
        return UnwrapBin(r, e);
    }

    /// <summary>
    /// Call cx_select_all_paths and decode the framed [u32 size][u32 n_paths][...]
    /// blob into a list of structural paths. Each path is an int[] of
    /// 0-based indices: first into Document.Elements, subsequent into
    /// Element.Items. Match order is preorder (same as cx_select_all).
    /// See spec/abi.md §2.7. Throws ArgumentException on parse error.
    /// </summary>
    public static List<int[]> SelectAllPaths(string cxText, string expr)
    {
        var r = NativeSelectAllPaths(cxText, expr, out var ePtr);
        if (r == IntPtr.Zero)
        {
            string msg = ePtr != IntPtr.Zero
                ? (Marshal.PtrToStringUTF8(ePtr) ?? "unknown error")
                : "unknown error";
            if (ePtr != IntPtr.Zero) Free(ePtr);
            // Bad CXPath expression or bad CX input — both are caller bugs.
            throw new ArgumentException(msg);
        }
        uint payloadSize = (uint)(
              Marshal.ReadByte(r, 0)
            | (Marshal.ReadByte(r, 1) << 8)
            | (Marshal.ReadByte(r, 2) << 16)
            | (Marshal.ReadByte(r, 3) << 24));
        var payload = new byte[payloadSize];
        Marshal.Copy(r + 4, payload, 0, (int)payloadSize);
        Free(r);
        int off = 0;
        int ReadU32()
        {
            uint v = (uint)(
                  payload[off]
                | (payload[off + 1] << 8)
                | (payload[off + 2] << 16)
                | (payload[off + 3] << 24));
            off += 4;
            return (int)v;
        }
        int nPaths = ReadU32();
        var paths = new List<int[]>(nPaths);
        for (int i = 0; i < nPaths; i++)
        {
            int depth = ReadU32();
            var path = new int[depth];
            for (int k = 0; k < depth; k++) path[k] = ReadU32();
            paths.Add(path);
        }
        return paths;
    }

    // ── Phase 5 / CB-1 — ast_bin → text format ───────────────────────────────

    private delegate IntPtr AstBinToTextFn(byte[] i, out IntPtr e);

    private static string AstBinToText(AstBinToTextFn fn, byte[] framed)
    {
        if (framed is null || framed.Length == 0)
            throw new InvalidOperationException("ast_bin_to_*: empty input");
        var r = fn(framed, out var ePtr);
        if (r == IntPtr.Zero)
        {
            string msg = ePtr != IntPtr.Zero
                ? (Marshal.PtrToStringUTF8(ePtr) ?? "unknown error")
                : "unknown error";
            if (ePtr != IntPtr.Zero) Free(ePtr);
            throw new InvalidOperationException(msg);
        }
        string s = Marshal.PtrToStringUTF8(r) ?? "";
        Free(r);
        return s;
    }

    public static string AstBinToCx  (byte[] framed) => AstBinToText(NativeAstBinToCx,   framed);
    public static string AstBinToXml (byte[] framed) => AstBinToText(NativeAstBinToXml,  framed);
    public static string AstBinToJson(byte[] framed) => AstBinToText(NativeAstBinToJson, framed);
    public static string AstBinToYaml(byte[] framed) => AstBinToText(NativeAstBinToYaml, framed);
    public static string AstBinToToml(byte[] framed) => AstBinToText(NativeAstBinToToml, framed);
    public static string AstBinToMd  (byte[] framed) => AstBinToText(NativeAstBinToMd,   framed);

    // ── Phase 5 / CB-2 — text → ast_bin (frame stripped) ────────────────────

    public static byte[] XmlToAstBin (string i) { var r = NativeXmlToAstBin (i, out var e); return UnwrapBin(r, e); }
    public static byte[] JsonToAstBin(string i) { var r = NativeJsonToAstBin(i, out var e); return UnwrapBin(r, e); }
    public static byte[] YamlToAstBin(string i) { var r = NativeYamlToAstBin(i, out var e); return UnwrapBin(r, e); }
    public static byte[] TomlToAstBin(string i) { var r = NativeTomlToAstBin(i, out var e); return UnwrapBin(r, e); }
    public static byte[] MdToAstBin  (string i) { var r = NativeMdToAstBin  (i, out var e); return UnwrapBin(r, e); }

    // ── data_bin one-shot loaders/dumpers (Phase 7.28; spec/abi.md §2.4–§2.5) ─

    /// <summary>Encode XML text to CXDB v1 PAYLOAD bytes (frame stripped).</summary>
    public static byte[] XmlToDataBin (string i) { var r = NativeXmlToDataBin (i, out var e); return UnwrapBin(r, e); }
    /// <summary>Encode JSON text to CXDB v1 PAYLOAD bytes (frame stripped).</summary>
    public static byte[] JsonToDataBin(string i) { var r = NativeJsonToDataBin(i, out var e); return UnwrapBin(r, e); }
    /// <summary>Encode YAML text to CXDB v1 PAYLOAD bytes (frame stripped).</summary>
    public static byte[] YamlToDataBin(string i) { var r = NativeYamlToDataBin(i, out var e); return UnwrapBin(r, e); }
    /// <summary>Encode TOML text to CXDB v1 PAYLOAD bytes (frame stripped).</summary>
    public static byte[] TomlToDataBin(string i) { var r = NativeTomlToDataBin(i, out var e); return UnwrapBin(r, e); }
    /// <summary>Encode Markdown text to CXDB v1 PAYLOAD bytes (frame stripped).</summary>
    public static byte[] MdToDataBin  (string i) { var r = NativeMdToDataBin  (i, out var e); return UnwrapBin(r, e); }

    /// <summary>Decode FRAMED CXDB v1 bytes to XML text.</summary>
    public static string DataBinToXml (byte[] framed) { var r = NativeDataBinToXml (framed, out var e); return Unwrap(r, e); }
    /// <summary>Decode FRAMED CXDB v1 bytes to JSON text.</summary>
    public static string DataBinToJson(byte[] framed) { var r = NativeDataBinToJson(framed, out var e); return Unwrap(r, e); }
    /// <summary>Decode FRAMED CXDB v1 bytes to YAML text.</summary>
    public static string DataBinToYaml(byte[] framed) { var r = NativeDataBinToYaml(framed, out var e); return Unwrap(r, e); }
    /// <summary>Decode FRAMED CXDB v1 bytes to TOML text.</summary>
    public static string DataBinToToml(byte[] framed) { var r = NativeDataBinToToml(framed, out var e); return Unwrap(r, e); }
    /// <summary>Decode FRAMED CXDB v1 bytes to Markdown text.</summary>
    public static string DataBinToMd  (byte[] framed) { var r = NativeDataBinToMd  (framed, out var e); return Unwrap(r, e); }

    // ── Delimited (CSV/TSV/PSV/arbitrary) (ADR 0001 / Phase 7.68) ────────────

    /// <summary>Convert CX text to delimited text using the given single-byte delimiter.</summary>
    public static string ToDelimited(string input, char delim)
    {
        if (delim > 0x7F)
            throw new ArgumentException("delim must be a single ASCII byte", nameof(delim));
        var r = NativeToDelimited(input, (sbyte)delim, out var e);
        return Unwrap(r, e);
    }

    /// <summary>Convert delimited text to CX text using the given single-byte delimiter.</summary>
    public static string FromDelimited(string input, char delim)
    {
        if (delim > 0x7F)
            throw new ArgumentException("delim must be a single ASCII byte", nameof(delim));
        var r = NativeFromDelimited(input, (sbyte)delim, out var e);
        return Unwrap(r, e);
    }

    /// <summary>Convert CX text to CSV (delimiter ',').</summary>
    public static string ToCsv  (string i) { var r = NativeToCsv  (i, out var e); return Unwrap(r, e); }
    /// <summary>Convert CSV text to canonical CX text.</summary>
    public static string FromCsv(string i) { var r = NativeFromCsv(i, out var e); return Unwrap(r, e); }
    /// <summary>Convert CX text to TSV (delimiter '\t').</summary>
    public static string ToTsv  (string i) { var r = NativeToTsv  (i, out var e); return Unwrap(r, e); }
    /// <summary>Convert TSV text to canonical CX text.</summary>
    public static string FromTsv(string i) { var r = NativeFromTsv(i, out var e); return Unwrap(r, e); }
    /// <summary>Convert CX text to PSV (delimiter '|').</summary>
    public static string ToPsv  (string i) { var r = NativeToPsv  (i, out var e); return Unwrap(r, e); }
    /// <summary>Convert PSV text to canonical CX text.</summary>
    public static string FromPsv(string i) { var r = NativeFromPsv(i, out var e); return Unwrap(r, e); }

    /// <summary>Encode CSV text to CXDB v1 PAYLOAD bytes (frame stripped).</summary>
    public static byte[] CsvToDataBin(string i) { var r = NativeCsvToDataBin(i, out var e); return UnwrapBin(r, e); }
    /// <summary>Encode TSV text to CXDB v1 PAYLOAD bytes (frame stripped).</summary>
    public static byte[] TsvToDataBin(string i) { var r = NativeTsvToDataBin(i, out var e); return UnwrapBin(r, e); }
    /// <summary>Encode PSV text to CXDB v1 PAYLOAD bytes (frame stripped).</summary>
    public static byte[] PsvToDataBin(string i) { var r = NativePsvToDataBin(i, out var e); return UnwrapBin(r, e); }

    /// <summary>Decode FRAMED CXDB v1 bytes to CSV text.</summary>
    public static string DataBinToCsv(byte[] framed) { var r = NativeDataBinToCsv(framed, out var e); return Unwrap(r, e); }
    /// <summary>Decode FRAMED CXDB v1 bytes to TSV text.</summary>
    public static string DataBinToTsv(byte[] framed) { var r = NativeDataBinToTsv(framed, out var e); return Unwrap(r, e); }
    /// <summary>Decode FRAMED CXDB v1 bytes to PSV text.</summary>
    public static string DataBinToPsv(byte[] framed) { var r = NativeDataBinToPsv(framed, out var e); return Unwrap(r, e); }

    // ── Phase 5 / CB-4 — events handle API (used by EventStream) ────────────

    internal static IntPtr EventsOpen(string input, out IntPtr errOut) => NativeEventsOpen(input, out errOut);
    internal static IntPtr EventsNext(IntPtr handle, out IntPtr errOut) => NativeEventsNext(handle, out errOut);
    internal static void   EventsClose(IntPtr handle) => NativeEventsClose(handle);
    internal static void   CxFree(IntPtr p) => Free(p);

    // ── Phase 6 / canonical-form tooling (spec/abi.md §2.6) ──────────────────

    /// <summary>Lossless canonical text CX. Idempotent.</summary>
    public static string Fmt(string i)       { var r = NativeFmt      (i, out var e); return Unwrap(r, e); }

    /// <summary>Strict canonical text CX.</summary>
    public static string Canonical(string i) { var r = NativeCanonical(i, out var e); return Unwrap(r, e); }

    /// <summary>SHA-256 hex (64 lowercase hex chars) of the strict canonical bytes.</summary>
    public static string Hash(string i)      { var r = NativeHash     (i, out var e); return Unwrap(r, e); }

    /// <summary>True iff strict-canonical(a) == strict-canonical(b).</summary>
    public static bool Eq(string a, string b)
    {
        var r = NativeEq(a, b, out var ePtr);
        if (r == IntPtr.Zero)
        {
            string msg = ePtr != IntPtr.Zero
                ? (Marshal.PtrToStringUTF8(ePtr) ?? "unknown error")
                : "unknown error";
            if (ePtr != IntPtr.Zero) Free(ePtr);
            throw new InvalidOperationException(msg);
        }
        string s = Marshal.PtrToStringUTF8(r) ?? "";
        Free(r);
        return s == "1";
    }

    /// <summary>
    /// Semantic diff between two CX inputs, walking the strict-canonical
    /// forms. <paramref name="format"/> is <c>"unified"</c>, <c>"json"</c>,
    /// or <c>"summary"</c>. Empty result means data-equivalent.
    /// Per spec/decisions/0012-cx-diff.md.
    /// </summary>
    public static string Diff(string a, string b, string format = "unified")
    {
        var r = NativeDiff(a, b, format, out var ePtr);
        if (r == IntPtr.Zero)
        {
            string msg = ePtr != IntPtr.Zero
                ? (Marshal.PtrToStringUTF8(ePtr) ?? "unknown error")
                : "unknown error";
            if (ePtr != IntPtr.Zero) Free(ePtr);
            throw new InvalidOperationException(msg);
        }
        string s = Marshal.PtrToStringUTF8(r) ?? "";
        Free(r);
        return s;
    }

    /// <summary>
    /// Style + correctness warnings. <paramref name="format"/> is
    /// <c>"text"</c>, <c>"json"</c>, or <c>"summary"</c>.
    /// <paramref name="disabled"/> is a comma-separated list of check
    /// IDs to suppress (empty string runs all). Empty result means no
    /// findings. Per spec/decisions/0013-cx-lint.md.
    /// </summary>
    public static string Lint(string input, string format = "text", string disabled = "")
    {
        var r = NativeLint(input, format, disabled, out var ePtr);
        if (r == IntPtr.Zero)
        {
            string msg = ePtr != IntPtr.Zero
                ? (Marshal.PtrToStringUTF8(ePtr) ?? "unknown error")
                : "unknown error";
            if (ePtr != IntPtr.Zero) Free(ePtr);
            throw new InvalidOperationException(msg);
        }
        string s = Marshal.PtrToStringUTF8(r) ?? "";
        Free(r);
        return s;
    }

    // ── ID/IDREF C ABI (Phase 7.65 / ADR 0003) ────────────────────────────────

    private static string? UnwrapNullable(IntPtr result, IntPtr errPtr)
    {
        if (result == IntPtr.Zero)
        {
            string msg = errPtr != IntPtr.Zero
                ? (Marshal.PtrToStringUTF8(errPtr) ?? "unknown error")
                : "unknown error";
            if (errPtr != IntPtr.Zero) Free(errPtr);
            throw new InvalidOperationException(msg);
        }
        string s = Marshal.PtrToStringUTF8(result) ?? "";
        Free(result);
        return s.Length == 0 ? null : s;
    }

    /// <summary>
    /// Parse <paramref name="input"/> and return the AST-JSON of the element
    /// declaring <c>#id</c>. Returns <c>null</c> if no element declares that
    /// id. Throws on parse error. Per ADR 0003.
    /// </summary>
    public static string? IdLookup(string input, string id)
    {
        var r = NativeIdLookup(input, id, out var ePtr);
        return UnwrapNullable(r, ePtr);
    }

    /// <summary>
    /// Parse <paramref name="input"/> and return the AST-JSON of the element
    /// declaring the id named by <paramref name="ref"/>. Observationally
    /// equivalent to <see cref="IdLookup"/> (refs and ids share a namespace).
    /// Returns <c>null</c> if the id is not declared. Throws on parse error.
    /// </summary>
    public static string? ResolveRef(string input, string @ref)
    {
        var r = NativeResolveRef(input, @ref, out var ePtr);
        return UnwrapNullable(r, ePtr);
    }

    /// <summary>
    /// Parse <paramref name="input"/>, run CXPath <paramref name="cxpath"/>,
    /// and return the syntactic ID of the matched element. Returns
    /// <c>null</c> when no match or matched element has no id. Throws on
    /// parse / cxpath error.
    /// </summary>
    public static string? NodeId(string input, string cxpath)
    {
        var r = NativeNodeId(input, cxpath, out var ePtr);
        return UnwrapNullable(r, ePtr);
    }

    /// <summary>
    /// Call cx_from_data_bin with FRAMED CXDB v1 bytes (as returned by
    /// <see cref="DataBin.Encode"/>) and return the canonical CX text.
    /// </summary>
    public static string FromDataBin(byte[] framed)
    {
        if (framed.Length == 0)
            throw new InvalidOperationException("cx_from_data_bin: empty input");
        var r = NativeFromDataBin(framed, out var e);
        return Unwrap(r, e);
    }

    // ── public API ────────────────────────────────────────────────────────────

    public static string Version()
    {
        var p = NativeVersion();
        var s = Marshal.PtrToStringUTF8(p) ?? "";
        Free(p);
        return s;
    }

    [DllImport(Lib, EntryPoint = "cx_features")]
    private static extern IntPtr NativeFeatures();

    /// <summary>
    /// libcx capability bitmask (spec/abi.md §3 / §1.1). Hex C-string with
    /// optional <c>0x</c> prefix is parsed and returned as <see cref="ulong"/>.
    /// </summary>
    public static ulong Features()
    {
        var p = NativeFeatures();
        if (p == IntPtr.Zero) return 0UL;
        string s = Marshal.PtrToStringUTF8(p) ?? "";
        Free(p);
        if (s.StartsWith("0x") || s.StartsWith("0X")) s = s.Substring(2);
        return ulong.TryParse(s, System.Globalization.NumberStyles.HexNumber,
            System.Globalization.CultureInfo.InvariantCulture, out var v) ? v : 0UL;
    }

    // CX input
    public static string ToCx        (string i) { var r = NativeToCx        (i, out var e); return Unwrap(r, e); }
    public static string ToCxCompact (string i) { var r = NativeToCxCompact (i, out var e); return Unwrap(r, e); }
    public static string AstToCx     (string i) { var r = NativeAstToCx     (i, out var e); return Unwrap(r, e); }
    public static string ToXml (string i) { var r = NativeToXml (i, out var e); return Unwrap(r, e); }
    public static string ToAst (string i) { var r = NativeToAst (i, out var e); return Unwrap(r, e); }
    public static string ToJson(string i) { var r = NativeToJson(i, out var e); return Unwrap(r, e); }
    public static string ToYaml(string i) { var r = NativeToYaml(i, out var e); return Unwrap(r, e); }
    public static string ToToml(string i) { var r = NativeToToml(i, out var e); return Unwrap(r, e); }
    public static string ToMd  (string i) { var r = NativeToMd  (i, out var e); return Unwrap(r, e); }

    /// <summary>
    /// Evaluate a CXL program against a CX context document.
    /// <paramref name="outputTarget"/> may be "" (honour the program's
    /// [?cx output-target=…] directive, default "text") or one of
    /// "text" / "cx" / "html" at CXL 1.0 (v0.6.0).
    /// </summary>
    public static string EvalCxl(string input, string program, string outputTarget = "")
    {
        var r = NativeEvalCxl(input, program, outputTarget ?? "", out var e);
        return Unwrap(r, e);
    }

    // XML input
    public static string XmlToCx  (string i) { var r = NativeXmlToCx  (i, out var e); return Unwrap(r, e); }
    public static string XmlToXml (string i) { var r = NativeXmlToXml (i, out var e); return Unwrap(r, e); }
    public static string XmlToAst (string i) { var r = NativeXmlToAst (i, out var e); return Unwrap(r, e); }
    public static string XmlToJson(string i) { var r = NativeXmlToJson(i, out var e); return Unwrap(r, e); }
    public static string XmlToYaml(string i) { var r = NativeXmlToYaml(i, out var e); return Unwrap(r, e); }
    public static string XmlToToml(string i) { var r = NativeXmlToToml(i, out var e); return Unwrap(r, e); }
    public static string XmlToMd  (string i) { var r = NativeXmlToMd  (i, out var e); return Unwrap(r, e); }

    // JSON input
    public static string JsonToCx  (string i) { var r = NativeJsonToCx  (i, out var e); return Unwrap(r, e); }
    public static string JsonToXml (string i) { var r = NativeJsonToXml (i, out var e); return Unwrap(r, e); }
    public static string JsonToAst (string i) { var r = NativeJsonToAst (i, out var e); return Unwrap(r, e); }
    public static string JsonToJson(string i) { var r = NativeJsonToJson(i, out var e); return Unwrap(r, e); }
    public static string JsonToYaml(string i) { var r = NativeJsonToYaml(i, out var e); return Unwrap(r, e); }
    public static string JsonToToml(string i) { var r = NativeJsonToToml(i, out var e); return Unwrap(r, e); }
    public static string JsonToMd  (string i) { var r = NativeJsonToMd  (i, out var e); return Unwrap(r, e); }

    // YAML input
    public static string YamlToCx  (string i) { var r = NativeYamlToCx  (i, out var e); return Unwrap(r, e); }
    public static string YamlToXml (string i) { var r = NativeYamlToXml (i, out var e); return Unwrap(r, e); }
    public static string YamlToAst (string i) { var r = NativeYamlToAst (i, out var e); return Unwrap(r, e); }
    public static string YamlToJson(string i) { var r = NativeYamlToJson(i, out var e); return Unwrap(r, e); }
    public static string YamlToYaml(string i) { var r = NativeYamlToYaml(i, out var e); return Unwrap(r, e); }
    public static string YamlToToml(string i) { var r = NativeYamlToToml(i, out var e); return Unwrap(r, e); }
    public static string YamlToMd  (string i) { var r = NativeYamlToMd  (i, out var e); return Unwrap(r, e); }

    // TOML input
    public static string TomlToCx  (string i) { var r = NativeTomlToCx  (i, out var e); return Unwrap(r, e); }
    public static string TomlToXml (string i) { var r = NativeTomlToXml (i, out var e); return Unwrap(r, e); }
    public static string TomlToAst (string i) { var r = NativeTomlToAst (i, out var e); return Unwrap(r, e); }
    public static string TomlToJson(string i) { var r = NativeTomlToJson(i, out var e); return Unwrap(r, e); }
    public static string TomlToYaml(string i) { var r = NativeTomlToYaml(i, out var e); return Unwrap(r, e); }
    public static string TomlToToml(string i) { var r = NativeTomlToToml(i, out var e); return Unwrap(r, e); }
    public static string TomlToMd  (string i) { var r = NativeTomlToMd  (i, out var e); return Unwrap(r, e); }

    // MD input
    public static string MdToCx  (string i) { var r = NativeMdToCx  (i, out var e); return Unwrap(r, e); }
    public static string MdToXml (string i) { var r = NativeMdToXml (i, out var e); return Unwrap(r, e); }
    public static string MdToAst (string i) { var r = NativeMdToAst (i, out var e); return Unwrap(r, e); }
    public static string MdToJson(string i) { var r = NativeMdToJson(i, out var e); return Unwrap(r, e); }
    public static string MdToYaml(string i) { var r = NativeMdToYaml(i, out var e); return Unwrap(r, e); }
    public static string MdToToml(string i) { var r = NativeMdToToml(i, out var e); return Unwrap(r, e); }
    public static string MdToMd  (string i) { var r = NativeMdToMd  (i, out var e); return Unwrap(r, e); }
}
