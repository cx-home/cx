using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;

namespace CX;

/// <summary>
/// Severity of a single <see cref="Diagnostic"/> emitted by the schema
/// validator. Wire format byte: 0=Info, 1=Warn, 2=Error
/// (spec/abi.md §2.13.2).
/// </summary>
public enum Severity
{
    Info  = 0,
    Warn  = 1,
    Error = 2,
}

/// <summary>One validator finding. Code is the spec rule id (e.g. <c>"S006"</c>,
/// <c>"W001"</c>) — the prefix letter is the wire-format namespace tag
/// (S = schema validator, W = streaming-write, D = data validator).</summary>
public sealed record Diagnostic(string Code, Severity Severity, string Message, uint Line, uint Col);

/// <summary>
/// Result of a <c>cx_validate</c> / <c>cx_validate_apply_defaults</c>
/// call. <see cref="Diagnostics"/> is the ordered list of findings;
/// <see cref="ModifiedDoc"/> carries the canonical CX text with
/// schema-driven defaults inserted (empty for plain <c>Validate</c>,
/// or when the schema declares no defaults).
/// </summary>
public sealed class ValidationReport
{
    public List<Diagnostic> Diagnostics { get; init; } = new();
    public string           ModifiedDoc { get; init; } = "";

    public bool IsValid     => !Diagnostics.Any(d => d.Severity == Severity.Error);
    public int  ErrorCount  => Diagnostics.Count(d => d.Severity == Severity.Error);
    public int  WarnCount   => Diagnostics.Count(d => d.Severity == Severity.Warn);
    public int  InfoCount   => Diagnostics.Count(d => d.Severity == Severity.Info);

    public List<string> ErrorCodes() =>
        Diagnostics.Where(d => d.Severity == Severity.Error).Select(d => d.Code).ToList();
}

/// <summary>
/// CX schema-validator binding — <c>cx_validate</c> +
/// <c>cx_validate_apply_defaults</c> (ADR 0009 / spec/schema.md §10 /
/// spec/abi.md §2.13). The C ABI returns a framed binary diagnostics
/// payload:
/// <code>
///   [u32 LE total_size]
///   [u32 LE diag_count]
///   diagnostic* {
///     [u32 line] [u32 col]
///     [u8 prefix]                    // 'S'/'W'/'D'; 0x00 = no prefix
///     [u32 error_code]
///     [u8 severity]                  // 0=info, 1=warn, 2=error
///     [u32 message_len] [message_utf8]
///   }
/// </code>
/// The prefix byte is the ASCII rule-code namespace tag — <c>S</c> for
/// the schema validator, <c>W</c> for streaming-write (ADR 0011), <c>D</c>
/// for the future data validator. Bindings render the public Code string
/// as <c>&lt;prefix&gt;&lt;numeric:D3&gt;</c> (e.g. <c>"S006"</c>,
/// <c>"W001"</c>); a 0x00 prefix renders the numeric without a letter.
/// </summary>
public static partial class CxLib
{
    [DllImport(Lib, EntryPoint = "cx_validate_with_len")]
    private static extern IntPtr NativeValidateWithLen(
        byte[] doc, UIntPtr docLen, byte[] schema, UIntPtr schemaLen, out IntPtr err);

    [DllImport(Lib, EntryPoint = "cx_validate_apply_defaults_with_len")]
    private static extern IntPtr NativeValidateApplyDefaultsWithLen(
        byte[] doc, UIntPtr docLen, byte[] schema, UIntPtr schemaLen,
        out IntPtr modifiedOut, out IntPtr err);

    /// <summary>
    /// Validate <paramref name="doc"/> against <paramref name="schema"/>.
    /// Schema-load errors (missing schema-of, unknown anchor, etc.)
    /// surface as a single error-severity Diagnostic in the returned
    /// report, not as an exception. Throws only when the document text
    /// itself is malformed CX.
    /// </summary>
    public static ValidationReport Validate(string doc, string schema)
    {
        byte[] docBytes    = Encoding.UTF8.GetBytes(doc);
        byte[] schemaBytes = Encoding.UTF8.GetBytes(schema);
        IntPtr raw = NativeValidateWithLen(
            docBytes, (UIntPtr)docBytes.Length,
            schemaBytes, (UIntPtr)schemaBytes.Length,
            out IntPtr err);
        var diagnostics = ExtractDiagnostics(raw, err);
        return new ValidationReport { Diagnostics = diagnostics, ModifiedDoc = "" };
    }

    /// <summary>
    /// Validate <paramref name="doc"/> against <paramref name="schema"/>
    /// and additionally apply schema-driven defaults; the returned
    /// report's <see cref="ValidationReport.ModifiedDoc"/> carries the
    /// canonical CX text with defaults inserted (empty when the schema
    /// declares no defaults).
    /// </summary>
    public static ValidationReport ValidateWithDefaults(string doc, string schema)
    {
        byte[] docBytes    = Encoding.UTF8.GetBytes(doc);
        byte[] schemaBytes = Encoding.UTF8.GetBytes(schema);
        IntPtr raw = NativeValidateApplyDefaultsWithLen(
            docBytes, (UIntPtr)docBytes.Length,
            schemaBytes, (UIntPtr)schemaBytes.Length,
            out IntPtr modifiedPtr, out IntPtr err);
        var diagnostics = ExtractDiagnostics(raw, err);
        string modified = "";
        if (modifiedPtr != IntPtr.Zero)
        {
            modified = Marshal.PtrToStringUTF8(modifiedPtr) ?? "";
            Free(modifiedPtr);
        }
        return new ValidationReport { Diagnostics = diagnostics, ModifiedDoc = modified };
    }

    private static List<Diagnostic> ExtractDiagnostics(IntPtr raw, IntPtr err)
    {
        if (raw == IntPtr.Zero)
        {
            string msg = err != IntPtr.Zero
                ? (Marshal.PtrToStringUTF8(err) ?? "unknown error")
                : "cx_validate: unknown error";
            if (err != IntPtr.Zero) Free(err);
            throw new InvalidOperationException(msg);
        }
        // Read [u32 LE total_size] header, then copy body bytes out.
        uint size = (uint)(
              Marshal.ReadByte(raw, 0)
            | (Marshal.ReadByte(raw, 1) << 8)
            | (Marshal.ReadByte(raw, 2) << 16)
            | (Marshal.ReadByte(raw, 3) << 24));
        var payload = new byte[size];
        Marshal.Copy(raw + 4, payload, 0, (int)size);
        Free(raw);
        return ParseDiagnosticsPayload(payload);
    }

    private static List<Diagnostic> ParseDiagnosticsPayload(byte[] payload)
    {
        var diags = new List<Diagnostic>();
        if (payload.Length < 4) return diags;
        int off = 0;
        uint count = ReadU32(payload, ref off);
        for (uint i = 0; i < count; i++)
        {
            if (off + 18 > payload.Length) break;
            uint line   = ReadU32(payload, ref off);
            uint col    = ReadU32(payload, ref off);
            byte prefix = payload[off]; off += 1;
            uint code   = ReadU32(payload, ref off);
            byte sev    = payload[off]; off += 1;
            uint mlen   = ReadU32(payload, ref off);
            if (off + (int)mlen > payload.Length) break;
            string msg = Encoding.UTF8.GetString(payload, off, (int)mlen);
            off += (int)mlen;
            diags.Add(new Diagnostic(
                Code:     FormatCode(prefix, code),
                Severity: (Severity)sev,
                Message:  msg,
                Line:     line,
                Col:      col));
        }
        return diags;
    }

    private static string FormatCode(byte prefix, uint numeric)
    {
        // Prefix is the ASCII namespace tag ('S'/'W'/'D'); 0x00 means
        // "namespace unspecified" — render numeric only.
        if (prefix == 0) return $"{numeric:D3}";
        return $"{(char)prefix}{numeric:D3}";
    }

    private static uint ReadU32(byte[] buf, ref int off)
    {
        uint v = (uint)(buf[off] | (buf[off + 1] << 8) | (buf[off + 2] << 16) | (buf[off + 3] << 24));
        off += 4;
        return v;
    }
}
