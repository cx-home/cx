#!/usr/bin/env node
import {
  createConnection,
  TextDocuments,
  ProposedFeatures,
  InitializeParams,
  CompletionItem,
  CompletionItemKind,
  TextDocumentPositionParams,
  TextDocumentSyncKind,
  InitializeResult,
  Diagnostic,
  DiagnosticSeverity,
  DocumentFormattingParams,
  TextEdit,
  Range,
  Position,
} from 'vscode-languageserver/node';
import { TextDocument } from 'vscode-languageserver-textdocument';
import { spawnSync } from 'child_process';

const connection = createConnection(ProposedFeatures.all);
const documents = new TextDocuments(TextDocument);

// ── Type annotation suffixes ────────────────────────────────────────────────

const TYPE_COMPLETIONS: CompletionItem[] = [
  // Generic types (v3.3 + v3.4)
  { label: ':int',      kind: CompletionItemKind.TypeParameter, detail: 'integer scalar' },
  { label: ':float',    kind: CompletionItemKind.TypeParameter, detail: 'float scalar' },
  { label: ':bool',     kind: CompletionItemKind.TypeParameter, detail: 'boolean scalar' },
  { label: ':string',   kind: CompletionItemKind.TypeParameter, detail: 'string scalar' },
  { label: ':null',     kind: CompletionItemKind.TypeParameter, detail: 'null scalar' },
  { label: ':date',     kind: CompletionItemKind.TypeParameter, detail: 'date (YYYY-MM-DD)' },
  { label: ':datetime', kind: CompletionItemKind.TypeParameter, detail: 'datetime (ISO-8601)' },
  { label: ':bytes',    kind: CompletionItemKind.TypeParameter, detail: 'binary bytes' },
  // v3.4 sized integer types
  { label: ':i8',       kind: CompletionItemKind.TypeParameter, detail: 'signed 8-bit (v3.4)' },
  { label: ':i16',      kind: CompletionItemKind.TypeParameter, detail: 'signed 16-bit (v3.4)' },
  { label: ':i32',      kind: CompletionItemKind.TypeParameter, detail: 'signed 32-bit (v3.4)' },
  { label: ':i64',      kind: CompletionItemKind.TypeParameter, detail: 'signed 64-bit (v3.4)' },
  { label: ':u8',       kind: CompletionItemKind.TypeParameter, detail: 'unsigned 8-bit (v3.4)' },
  { label: ':u16',      kind: CompletionItemKind.TypeParameter, detail: 'unsigned 16-bit (v3.4)' },
  { label: ':u32',      kind: CompletionItemKind.TypeParameter, detail: 'unsigned 32-bit (v3.4)' },
  { label: ':u64',      kind: CompletionItemKind.TypeParameter, detail: 'unsigned 64-bit (v3.4)' },
  // v3.4 sized float types
  { label: ':f16',      kind: CompletionItemKind.TypeParameter, detail: 'float 16-bit (v3.4)' },
  { label: ':f32',      kind: CompletionItemKind.TypeParameter, detail: 'float 32-bit (v3.4)' },
  { label: ':f64',      kind: CompletionItemKind.TypeParameter, detail: 'float 64-bit (v3.4)' },
  // v3.4 arbitrary precision
  { label: ':decimal',  kind: CompletionItemKind.TypeParameter, detail: 'arbitrary-precision decimal (v3.4)' },
  { label: ':bigint',   kind: CompletionItemKind.TypeParameter, detail: 'arbitrary-precision integer (v3.4)' },
  // Array forms
  { label: ':int[]',    kind: CompletionItemKind.TypeParameter, detail: 'array of integers' },
  { label: ':float[]',  kind: CompletionItemKind.TypeParameter, detail: 'array of floats' },
  { label: ':bool[]',   kind: CompletionItemKind.TypeParameter, detail: 'array of booleans' },
  { label: ':string[]', kind: CompletionItemKind.TypeParameter, detail: 'array of strings' },
  { label: ':[]',       kind: CompletionItemKind.TypeParameter, detail: 'inferred-type array' },
  { label: ':table',    kind: CompletionItemKind.TypeParameter, detail: 'tabular block (v3.4)' },
].map((item, i) => ({ ...item, sortText: String(i).padStart(3, '0') }));

const BOOL_COMPLETIONS: CompletionItem[] = [
  { label: 'true',  kind: CompletionItemKind.Value },
  { label: 'false', kind: CompletionItemKind.Value },
  { label: 'null',  kind: CompletionItemKind.Value },
];

// ── cx CLI bridge ───────────────────────────────────────────────────────────

const CX_BIN = process.env.CX_BIN || 'cx';

interface CxResult {
  stdout: string;
  stderr: string;
  code: number;
}

function runCx(args: string[], input: string): CxResult {
  try {
    const r = spawnSync(CX_BIN, args, { input, encoding: 'utf8', timeout: 5000 });
    return { stdout: r.stdout || '', stderr: r.stderr || '', code: r.status ?? -1 };
  } catch (e) {
    return { stdout: '', stderr: `cx CLI invocation failed: ${e}`, code: -1 };
  }
}

// ── Diagnostics ─────────────────────────────────────────────────────────────

// Parse cx parse error format "LINE:COL: message" into an LSP diagnostic.
function parseCxError(stderr: string, fallbackMsg: string): Diagnostic | null {
  const m = stderr.match(/^(?:error: )?(\d+):(\d+):\s*(.+)/m);
  if (m) {
    const line = parseInt(m[1], 10) - 1;
    const col = parseInt(m[2], 10) - 1;
    return {
      severity: DiagnosticSeverity.Error,
      range: {
        start: { line, character: col },
        end: { line, character: col + 1 },
      },
      message: m[3].trim(),
      source: 'cx',
    };
  }
  if (stderr.trim().length > 0) {
    return {
      severity: DiagnosticSeverity.Error,
      range: { start: { line: 0, character: 0 }, end: { line: 0, character: 0 } },
      message: stderr.trim(),
      source: 'cx',
    };
  }
  if (fallbackMsg.length > 0) {
    return {
      severity: DiagnosticSeverity.Error,
      range: { start: { line: 0, character: 0 }, end: { line: 0, character: 0 } },
      message: fallbackMsg,
      source: 'cx',
    };
  }
  return null;
}

// Parse cx lint --format=json output into LSP diagnostics.
interface LintFinding {
  check: string;
  severity: 'info' | 'warn' | 'error';
  message: string;
  path?: string;
  line?: number;
  col?: number;
  suggestion?: string;
}

function lintSeverityToLsp(s: string): DiagnosticSeverity {
  switch (s) {
    case 'error': return DiagnosticSeverity.Error;
    case 'warn':  return DiagnosticSeverity.Warning;
    case 'info':  return DiagnosticSeverity.Information;
    default:      return DiagnosticSeverity.Hint;
  }
}

function lintFindingsToDiagnostics(findings: LintFinding[]): Diagnostic[] {
  return findings.map(f => {
    const line = (f.line ?? 1) - 1;
    const col  = (f.col  ?? 1) - 1;
    let msg = `[${f.check}] ${f.message}`;
    if (f.suggestion) msg += `\n  suggestion: ${f.suggestion}`;
    return {
      severity: lintSeverityToLsp(f.severity),
      range: {
        start: { line, character: col },
        end: { line, character: col + 1 },
      },
      message: msg,
      source: 'cx-lint',
    };
  });
}

async function validateTextDocument(doc: TextDocument): Promise<void> {
  const diags: Diagnostic[] = [];

  // 1. Parse: surface parse errors via `cx canonical` (which fails with
  //    the parser's `LINE:COL: msg` message on invalid input).
  const parsed = runCx(['canonical'], doc.getText());
  if (parsed.code !== 0) {
    const d = parseCxError(parsed.stderr, 'parse error');
    if (d) diags.push(d);
  } else {
    // 2. Lint: run only when the document parses cleanly.
    const lint = runCx(['lint', '--format=json', '--fail-on=none'], doc.getText());
    if (lint.code === 0 && lint.stdout.trim().length > 0) {
      try {
        const findings = JSON.parse(lint.stdout) as LintFinding[];
        diags.push(...lintFindingsToDiagnostics(findings));
      } catch {
        // Bad JSON — just skip lint diagnostics this round.
      }
    }
  }

  connection.sendDiagnostics({ uri: doc.uri, diagnostics: diags });
}

// ── Element name extraction (for completion) ───────────────────────────────

function extractElementNames(text: string): string[] {
  const seen = new Set<string>();
  const re = /\[([a-zA-Z_][\w.-]*)/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(text)) !== null) {
    seen.add(m[1]);
  }
  return Array.from(seen).sort();
}

interface Context {
  kind: 'type' | 'element' | 'value' | 'sigil' | 'none';
  prefix: string;
}

function getContext(doc: TextDocument, pos: TextDocumentPositionParams['position']): Context {
  const text = doc.getText();
  const offset = doc.offsetAt(pos);
  const before = text.slice(0, offset);

  // After : — type annotation
  const typeMatch = before.match(/:([a-z0-9\[\]]*)$/);
  if (typeMatch) return { kind: 'type', prefix: typeMatch[1] };

  // After [ — element name (with prefix)
  const elemMatch = before.match(/\[([a-zA-Z_][\w.-]*)$/);
  if (elemMatch) return { kind: 'element', prefix: elemMatch[1] };

  // Start of element
  if (before.match(/\[$/)) return { kind: 'element', prefix: '' };

  // After = — attribute value
  if (before.match(/=\s*$/)) return { kind: 'value', prefix: '' };

  // After + or - inside an element — boolean sigil completion (v3.4)
  if (before.match(/[+-][a-zA-Z_][\w.-]*$/)) {
    const m = before.match(/([+-])([a-zA-Z_][\w.-]*)$/);
    if (m) return { kind: 'sigil', prefix: m[2] };
  }

  return { kind: 'none', prefix: '' };
}

// ── LSP lifecycle ────────────────────────────────────────────────────────────

connection.onInitialize((_params: InitializeParams): InitializeResult => {
  return {
    capabilities: {
      textDocumentSync: TextDocumentSyncKind.Incremental,
      completionProvider: {
        triggerCharacters: [':', '[', '=', '+', '-'],
        resolveProvider: false,
      },
      documentFormattingProvider: true,
    },
    serverInfo: { name: 'cx-language-server', version: '0.2.0' },
  };
});

connection.onCompletion((params: TextDocumentPositionParams): CompletionItem[] => {
  const doc = documents.get(params.textDocument.uri);
  if (!doc) return [];

  const ctx = getContext(doc, params.position);

  if (ctx.kind === 'type') {
    return TYPE_COMPLETIONS.filter(c => c.label.startsWith(':' + ctx.prefix));
  }

  if (ctx.kind === 'element') {
    const names = extractElementNames(doc.getText());
    return names
      .filter(n => n.startsWith(ctx.prefix))
      .map(n => ({ label: n, kind: CompletionItemKind.Field }));
  }

  if (ctx.kind === 'value') {
    return BOOL_COMPLETIONS;
  }

  if (ctx.kind === 'sigil') {
    // Suggest known boolean attribute names that appear elsewhere.
    const text = doc.getText();
    const seen = new Set<string>();
    const re = /[+-]([a-zA-Z_][\w.-]*)/g;
    let m: RegExpExecArray | null;
    while ((m = re.exec(text)) !== null) seen.add(m[1]);
    return Array.from(seen)
      .filter(n => n.startsWith(ctx.prefix))
      .sort()
      .map(n => ({ label: n, kind: CompletionItemKind.Property }));
  }

  return [];
});

// ── Formatting (cx fmt) ─────────────────────────────────────────────────────

connection.onDocumentFormatting(async (params: DocumentFormattingParams): Promise<TextEdit[]> => {
  const doc = documents.get(params.textDocument.uri);
  if (!doc) return [];
  const formatted = runCx(['fmt'], doc.getText());
  if (formatted.code !== 0) {
    // On parse error the fmt subcommand fails; surface diagnostics instead.
    return [];
  }
  // Replace the entire document with the formatted output.
  const lastLine = doc.lineCount - 1;
  const lastChar = doc.getText().split('\n').slice(-1)[0].length;
  const range: Range = {
    start: Position.create(0, 0),
    end: Position.create(lastLine, lastChar),
  };
  return [TextEdit.replace(range, formatted.stdout)];
});

// ── Re-validate on open / change / save ─────────────────────────────────────

documents.onDidChangeContent((change) => {
  void validateTextDocument(change.document);
});

documents.onDidOpen((e) => {
  void validateTextDocument(e.document);
});

documents.listen(connection);
connection.listen();
