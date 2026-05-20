/**
 * CX Document API — AST types, parse, query, mutation, CX emitter, loads/dumps.
 */
import {
  toAstBin as _toAstBin,
  toAstBinWithIncludeRoot as _toAstBinWithIncludeRoot,
  toDataBin as _toDataBin,
  fromDataBin as _fromDataBin,
  selectAllPaths as _selectAllPaths,
  // Phase 5 helpers
  astBinToCx as _astBinToCx,
  astBinToXml as _astBinToXml,
  astBinToJson as _astBinToJson,
  astBinToYaml as _astBinToYaml,
  astBinToToml as _astBinToToml,
  astBinToMd as _astBinToMd,
  xmlToAstBin as _xmlToAstBin,
  jsonToAstBin as _jsonToAstBin,
  yamlToAstBin as _yamlToAstBin,
  tomlToAstBin as _tomlToAstBin,
  mdToAstBin as _mdToAstBin,
  // Legacy text-only converters still used by loads_<fmt>
  jsonToCx as _jsonToCx,
  xmlToJson as _xmlToJson,
  jsonToJson as _jsonToJson,
  yamlToJson as _yamlToJson,
  tomlToJson as _tomlToJson,
  mdToJson as _mdToJson,
} from './index';
import { decodeAST as _decodeAST, encodeAST as _encodeAST } from './binary';
import { decode as _cxdbDecode, encode as _cxdbEncode } from './data_bin';

// ── Node types ────────────────────────────────────────────────────────────────

export interface Attr {
  name: string;
  value: any;       // string | number | boolean | null
  dataType?: string | null;  // null/undefined means string (omitted in JSON)
  /**
   * v3.4 (ADR 0002): expanded-name fields populated by
   * resolveNamespaces(). `local` is the part after the first ':' in
   * `name` (or the whole name); `nsUri` is the resolved URI. Per XML
   * Namespaces 1.0 §6.2 the default namespace does not apply to
   * unprefixed attributes — `nsUri` is null for them.
   */
  local?: string;
  nsUri?: string | null;
  /** v3.4 (ADR 0003): true when the source was a bare `@id` reference
   *  token. Quoted strings starting with '@' have isRef = false. */
  isRef?: boolean;
  /** v3.5 (ADR 0016): BracketBody attribute value — `name=[BodyItem*]`.
   *  When set, `value` is unused and the attribute's content is the
   *  parsed body sequence. Used by CXL evaluation directives like
   *  `[?if cond :then=[BODY] :else=[BODY]]`. Inert outside CXL evaluation;
   *  round-trips as opaque structure (ADR 0016 R5). ast_bin v5+. */
  body?: Node[];
}

/** Local part of an attribute's name (post-colon, or whole name). */
export function attrLocalName(a: Attr): string {
  return a.local ?? '';
}

/** Resolved namespace URI for prefixed attributes; null otherwise. */
export function attrNamespaceUri(a: Attr): string | null {
  return a.nsUri ?? null;
}

export class TextNode {
  readonly type = 'Text' as const;
  constructor(public value: string) {}
}

export class ScalarNode {
  readonly type = 'Scalar' as const;
  constructor(public dataType: string, public value: any) {}
}

export class CommentNode {
  readonly type = 'Comment' as const;
  constructor(public value: string) {}
}

export class RawTextNode {
  readonly type = 'RawText' as const;
  constructor(public value: string) {}
}

export class EntityRefNode {
  readonly type = 'EntityRef' as const;
  constructor(public name: string) {}
}

export class AliasNode {
  readonly type = 'Alias' as const;
  constructor(public name: string) {}
}

export class PINode {
  readonly type = 'PI' as const;
  constructor(public target: string, public data?: string | null) {}
}

export class XMLDeclNode {
  readonly type = 'XMLDecl' as const;
  constructor(
    public version: string = '1.0',
    public encoding?: string | null,
    public standalone?: string | null,
  ) {}
}

export class CXDirectiveNode {
  readonly type = 'CXDirective' as const;
  /** v0.6.0 — directives may carry an `&anchor` and/or nested elements.
   *  Used by the standalone-fragment form `[?cx frag &name [body :TYPE :flags]]`
   *  (spec/schema.md §8). ast_bin format version 4 carries them. */
  constructor(
    public attrs: Attr[] = [],
    public anchor: string | null = null,
    public items: Node[] = [],
  ) {}
}

export class InterpolationNode {
  /** v3.5 (ADR 0016) [58] — `[?=EXPR]`. EXPR is opaque text at v0.6.0;
   *  the CXL evaluator at v0.7.0+ parses it as CXPath at evaluation time. */
  readonly type = 'Interpolation' as const;
  constructor(public expr: string) {}
}

export class EvalDirectiveNode {
  /** v3.5 (ADR 0016) [59] — `[?Name attrs body]`. Reserved EvalNames
   *  (if/for/with/cond/include/def/use/let/fn/match/try) parse into this
   *  node. Inert at v0.6.0; the CXL evaluator dispatches on `name`. */
  readonly type = 'EvalDirective' as const;
  constructor(
    public name: string,
    public attrs: Attr[] = [],
    public items: Node[] = [],
  ) {}
}

export class BlockContentNode {
  readonly type = 'BlockContent' as const;
  constructor(public items: Node[] = []) {}
}

export class DoctypeDeclNode {
  readonly type = 'DoctypeDecl' as const;
  constructor(
    public name: string,
    public externalID?: any,
    public intSubset: any[] = [],
  ) {}
}

export type Node =
  | Element
  | TextNode
  | ScalarNode
  | CommentNode
  | RawTextNode
  | EntityRefNode
  | AliasNode
  | PINode
  | XMLDeclNode
  | CXDirectiveNode
  | BlockContentNode
  | DoctypeDeclNode
  | InterpolationNode
  | EvalDirectiveNode;

// ── Element ───────────────────────────────────────────────────────────────────

export class Element {
  readonly type = 'Element' as const;
  name: string;
  anchor?: string | null;
  merge?: string | null;
  dataType?: string | null;
  attrs: Attr[];
  items: Node[];
  /** v3.4 (ADR 0002): expanded-name fields populated by resolveNamespaces(). */
  local: string = '';
  nsUri: string | null = null;
  /** v3.4 (ADR 0003): syntactic ID declaration ("#name" token); null
   *  when the element has no ID. Distinct from `anchor`. */
  id: string | null = null;
  /** v3.4 (ADR 0003 D1): body-position reference target — set when the
   *  element body is a bare `@<id>` token (e.g. `[ref @section-3]`).
   *  Null for ordinary elements. Carried over the ast_bin wire format
   *  at v3+ (Phase 7.70 bumped 2 → 3). */
  bodyRef: string | null = null;
  /** v0.7.0 Z2 (spec/i18n.md §1.3): in-scope BCP 47 language tag.
   *  Populated by resolveNamespaces(). `null` = no cx:lang in scope;
   *  `""` = explicit cx:lang="" shadow; otherwise the locally-declared
   *  or inherited tag. Use `lang()` for the flattened accessor. */
  langResolved: string | null = null;

  constructor(opts: {
    name: string;
    anchor?: string | null;
    merge?: string | null;
    dataType?: string | null;
    attrs?: Attr[];
    items?: Node[];
    id?: string | null;
    bodyRef?: string | null;
  }) {
    this.name = opts.name;
    this.anchor = opts.anchor ?? null;
    this.merge = opts.merge ?? null;
    this.dataType = opts.dataType ?? null;
    this.attrs = opts.attrs ?? [];
    this.items = opts.items ?? [];
    this.id = opts.id ?? null;
    this.bodyRef = opts.bodyRef ?? null;
  }

  /** Local part of the element name (post-colon, or whole name). */
  localName(): string { return this.local; }

  /** Resolved namespace URI; null when no binding is in scope and
   * the prefix is not reserved. */
  namespaceUri(): string | null { return this.nsUri; }

  /** BCP 47 language tag in scope at this Element per spec/i18n.md
   *  §1.3. Returns `""` when no cx:lang is in scope or when an
   *  ancestor's declaration was shadowed by an explicit `cx:lang=""`. */
  lang(): string { return this.langResolved ?? ''; }

  /** First child Element with this name. */
  get(name: string): Element | null {
    for (const item of this.items) {
      if (item instanceof Element && item.name === name) return item;
    }
    return null;
  }

  /** All child Elements with this name. */
  getAll(name: string): Element[] {
    return this.items.filter(
      (i): i is Element => i instanceof Element && i.name === name,
    );
  }

  /** Attribute value by name, or null. */
  attr(name: string): any {
    for (const a of this.attrs) {
      if (a.name === name) return a.value;
    }
    return null;
  }

  /** Concatenated Text and Scalar child content. */
  text(): string {
    const parts: string[] = [];
    for (const item of this.items) {
      if (item instanceof TextNode) {
        parts.push(item.value);
      } else if (item instanceof ScalarNode) {
        parts.push(item.value === null ? 'null' : String(item.value));
      }
    }
    return parts.join(' ');
  }

  /** Value of first Scalar child, or null. */
  scalar(): any {
    for (const item of this.items) {
      if (item instanceof ScalarNode) return item.value;
    }
    return null;
  }

  /** All child Elements (excludes Text, Scalar, and other nodes). */
  children(): Element[] {
    return this.items.filter((i): i is Element => i instanceof Element);
  }

  /** All descendant Elements with this name (depth-first). */
  findAll(name: string): Element[] {
    const result: Element[] = [];
    for (const item of this.items) {
      if (item instanceof Element) {
        if (item.name === name) result.push(item);
        result.push(...item.findAll(name));
      }
    }
    return result;
  }

  /** First descendant Element with this name (depth-first). */
  findFirst(name: string): Element | null {
    for (const item of this.items) {
      if (item instanceof Element) {
        if (item.name === name) return item;
        const found = item.findFirst(name);
        if (found !== null) return found;
      }
    }
    return null;
  }

  /** Navigate by slash-separated path: el.at('server/host'). */
  at(path: string): Element | null {
    const parts = path.split('/').filter(p => p.length > 0);
    let cur: Element | null = this;
    for (const part of parts) {
      if (cur === null) return null;
      cur = cur.get(part);
    }
    return cur;
  }

  /** Append a child node. */
  append(node: Node): void {
    this.items.push(node);
  }

  /** Prepend a child node. */
  prepend(node: Node): void {
    this.items.unshift(node);
  }

  /** Insert a child node at index. */
  insert(index: number, node: Node): void {
    this.items.splice(index, 0, node);
  }

  /** Remove a child node by identity. */
  remove(node: Node): void {
    this.items = this.items.filter(i => i !== node);
  }

  /** Set an attribute value, updating if it already exists. */
  setAttr(name: string, value: any, dataType?: string | null): void {
    for (const a of this.attrs) {
      if (a.name === name) {
        a.value = value;
        a.dataType = dataType ?? null;
        return;
      }
    }
    this.attrs.push({ name, value, dataType: dataType ?? null });
  }

  /** Remove an attribute by name. */
  removeAttr(name: string): void {
    this.attrs = this.attrs.filter(a => a.name !== name);
  }

  /** Remove all direct child Elements with this name. */
  removeChild(name: string): void {
    this.items = this.items.filter(i => !(i instanceof Element && i.name === name));
  }

  /** Remove child node at index (no-op if out of bounds). */
  removeAt(index: number): void {
    if (index >= 0 && index < this.items.length) {
      this.items.splice(index, 1);
    }
  }

  /** First Element matching a CXPath expression (subtree of this element). */
  select(expr: string): Element | null {
    const results = this.selectAll(expr);
    return results.length > 0 ? results[0] : null;
  }

  /**
   * All Elements matching a CXPath expression (subtree of this element).
   *
   * v3.4: thunks to libcx via cx_select_all_paths (CB-5). Returned
   * Elements are *live references* into this Element's tree —
   * mutations propagate, preserving prior behavior. Semantics match
   * V's Element.select_all: this element's items become the top-level
   * candidate set, so a child-axis expression like `child` matches
   * direct children, and `//child` matches at any descendant depth.
   */
  selectAll(expr: string): Element[] {
    // Emit each Element child as a top-level node. The round-trip
    // makes V's Document.select_all_paths walk the same candidate set
    // V's Element.select_all would. Track a doc-index → orig-index
    // mapping (non-Element items don't affect CXPath matches but shift
    // item indices).
    const parts: string[] = [];
    const docToOrig: number[] = [];
    for (let i = 0; i < this.items.length; i++) {
      const item = this.items[i];
      if (item instanceof Element) {
        parts.push(_emitElement(item, 0));
        docToOrig.push(i);
      }
    }
    const docStr = parts.join('').replace(/\n$/, '');
    const paths = _selectAllPaths(docStr, expr);
    const out: Element[] = [];
    for (const p of paths) {
      if (p.length === 0) continue;
      const top = p[0];
      if (top < 0 || top >= docToOrig.length) continue;
      let node: Node = this.items[docToOrig[top]];
      let ok = true;
      for (let i = 1; i < p.length; i++) {
        if (!(node instanceof Element)) { ok = false; break; }
        const k = p[i];
        if (k < 0 || k >= node.items.length) { ok = false; break; }
        node = node.items[k];
      }
      if (ok && node instanceof Element) out.push(node);
    }
    return out;
  }
}

// ── Document ──────────────────────────────────────────────────────────────────

export class Document {
  elements: Node[];
  prolog: Node[];
  doctype?: DoctypeDeclNode | null;

  constructor(opts: {
    elements?: Node[];
    prolog?: Node[];
    doctype?: DoctypeDeclNode | null;
  } = {}) {
    this.elements = opts.elements ?? [];
    this.prolog = opts.prolog ?? [];
    this.doctype = opts.doctype ?? null;
  }

  /** First top-level Element. */
  root(): Element | null {
    for (const e of this.elements) {
      if (e instanceof Element) return e;
    }
    return null;
  }

  /** First top-level Element with this name. */
  get(name: string): Element | null {
    for (const e of this.elements) {
      if (e instanceof Element && e.name === name) return e;
    }
    return null;
  }

  /** Navigate by slash-separated path from root: doc.at('article/body/p'). */
  at(path: string): Element | null {
    const parts = path.split('/').filter(p => p.length > 0);
    if (parts.length === 0) return this.root();
    const cur = this.get(parts[0]);
    if (cur === null || parts.length === 1) return cur;
    return cur.at(parts.slice(1).join('/'));
  }

  /** All descendant Elements with this name (depth-first through entire document). */
  findAll(name: string): Element[] {
    const result: Element[] = [];
    for (const e of this.elements) {
      if (e instanceof Element) {
        if (e.name === name) result.push(e);
        result.push(...e.findAll(name));
      }
    }
    return result;
  }

  /** First descendant Element with this name (depth-first through entire document). */
  findFirst(name: string): Element | null {
    for (const e of this.elements) {
      if (e instanceof Element) {
        if (e.name === name) return e;
        const found = e.findFirst(name);
        if (found !== null) return found;
      }
    }
    return null;
  }

  /** Return the Element declaring `#id`, or null. v3.4 (ADR 0003). */
  resolveId(id: string): Element | null {
    return _findElementById(this.elements, id) ?? _findElementById(this.prolog, id);
  }

  /** Return the Element targeted by `e.bodyRef` in this document, or
   *  `null` when bodyRef is unset or the target ID is undeclared.
   *  v0.7.0 (ADR 0003 D1 second bullet / GG13 row at v0_7_0_status.md). */
  resolveBodyRef(e: Element): Element | null {
    if (!e || !e.bodyRef) return null;
    return this.resolveId(e.bodyRef);
  }

  /** {id: Element} map for the whole document. v3.4 (ADR 0003). */
  elementsById(): Record<string, Element> {
    const out: Record<string, Element> = {};
    _collectElementsById(this.elements, out);
    _collectElementsById(this.prolog, out);
    return out;
  }

  /** Append a top-level node. */
  append(node: Node): void {
    this.elements.push(node);
  }

  /** Prepend a top-level node. */
  prepend(node: Node): void {
    this.elements.unshift(node);
  }

  /** First Element matching a CXPath expression. */
  select(expr: string): Element | null {
    const results = this.selectAll(expr);
    return results.length > 0 ? results[0] : null;
  }

  /**
   * All Elements matching a CXPath expression.
   *
   * v3.4: thunks to libcx via cx_select_all_paths (CB-5). Returned
   * Elements are live references into this Document's tree —
   * mutations propagate.
   */
  selectAll(expr: string): Element[] {
    const { navigateDocPath } = require('./cxpath');
    const paths = _selectAllPaths(this.to_cx(), expr);
    const out: Element[] = [];
    for (const p of paths) {
      const el = navigateDocPath(this, p);
      if (el !== null) out.push(el);
    }
    return out;
  }

  /** Return new Document with element at path replaced by f(element). */
  transform(path: string, f: (el: Element) => Element): Document {
    const { elemDetached, docReplaceAt, pathCopyElement } = require('./cxpath');
    const parts = path.split('/').filter((p: string) => p.length > 0);
    if (parts.length === 0) return this;
    for (let i = 0; i < this.elements.length; i++) {
      const node = this.elements[i];
      if (node instanceof Element && node.name === parts[0]) {
        if (parts.length === 1) {
          return docReplaceAt(this, i, f(elemDetached(node)));
        }
        const updated = pathCopyElement(node, parts.slice(1), f);
        if (updated !== null) {
          return docReplaceAt(this, i, updated);
        }
        return this;
      }
    }
    return this;
  }

  /**
   * Return new Document with all matching elements replaced by f(element).
   *
   * v3.4: thunks to libcx via cx_select_all_paths (CB-5). Paths are
   * applied bottom-up (longest first) so when a parent is rewritten
   * its f-input already contains the f-results of descendant matches —
   * matching the prior post-order semantics.
   */
  transformAll(expr: string, f: (el: Element) => Element): Document {
    const { elemDetached, navigateDocPath, replaceAtDocPath } = require('./cxpath');
    const paths = _selectAllPaths(this.to_cx(), expr);
    if (paths.length === 0) return this;
    const sorted = [...paths].sort((a, b) => b.length - a.length);
    let newDoc: Document = this;
    for (const p of sorted) {
      const target = navigateDocPath(newDoc, p);
      if (target === null) continue;
      newDoc = replaceAtDocPath(newDoc, p, f(elemDetached(target)));
    }
    return newDoc;
  }

  to_cx(): string {
    return _emitDoc(this);
  }

  /**
   * Serialize this Document to a FRAMED [u32 LE size][payload]
   * binary AST Buffer. Used internally by to_xml / to_json / etc.
   * (Phase 5 / CB-1) and exported for callers that want to pass the
   * document directly to libcx without round-tripping through CX text.
   */
  to_ast_bin(): Buffer {
    return _encodeAST(this);
  }

  // v3.4 (Phase 5 / CB-1): format methods now go through
  // cx_ast_bin_to_<fmt>(this.to_ast_bin()) directly, avoiding the
  // prior emit-CX-and-reparse detour.
  to_xml(): string  { return _astBinToXml (this.to_ast_bin()); }
  to_json(): string { return _astBinToJson(this.to_ast_bin()); }
  to_yaml(): string { return _astBinToYaml(this.to_ast_bin()); }
  to_toml(): string { return _astBinToToml(this.to_ast_bin()); }
  to_md(): string   { return _astBinToMd  (this.to_ast_bin()); }
}

// ── Deserialization: AST JSON dict → native types ─────────────────────────────

function _nodeFromDict(d: any): Node {
  const t: string = d.type ?? '';
  if (t === 'Element') {
    return new Element({
      name: d.name,
      anchor: d.anchor ?? null,
      merge: d.merge ?? null,
      dataType: d.dataType ?? null,
      attrs: (d.attrs ?? []).map((a: any): Attr => ({
        name: a.name,
        value: a.value,
        dataType: a.dataType ?? null,
      })),
      items: (d.items ?? []).map(_nodeFromDict),
    });
  }
  if (t === 'Text') return new TextNode(d.value);
  if (t === 'Scalar') return new ScalarNode(d.dataType, d.value);
  if (t === 'Comment') return new CommentNode(d.value);
  if (t === 'RawText') return new RawTextNode(d.value);
  if (t === 'EntityRef') return new EntityRefNode(d.name);
  if (t === 'Alias') return new AliasNode(d.name);
  if (t === 'PI') return new PINode(d.target, d.data ?? null);
  if (t === 'XMLDecl') return new XMLDeclNode(d.version ?? '1.0', d.encoding ?? null, d.standalone ?? null);
  if (t === 'CXDirective') {
    return new CXDirectiveNode(
      (d.attrs ?? []).map((a: any): Attr => ({ name: a.name, value: a.value, dataType: null })),
    );
  }
  if (t === 'DoctypeDecl') return new DoctypeDeclNode(d.name, d.externalID ?? null, d.intSubset ?? []);
  if (t === 'BlockContent') return new BlockContentNode((d.items ?? []).map(_nodeFromDict));
  // unknown node — preserve as text
  return new TextNode(String(d));
}

function _docFromDict(d: any): Document {
  let doctype: DoctypeDeclNode | null = null;
  if (d.doctype) {
    const dt = d.doctype;
    doctype = new DoctypeDeclNode(dt.name, dt.externalID ?? null, dt.intSubset ?? []);
  }
  return new Document({
    prolog: (d.prolog ?? []).map(_nodeFromDict),
    doctype,
    elements: (d.elements ?? []).map(_nodeFromDict),
  });
}

// ── Namespace resolution (ADR 0002 / spec/namespaces.md) ──────────────────────
//
// Mirrors V core's vcx/cx/namespaces.v. Walks a parsed Document,
// populating Element.{local, nsUri} and Attr.{local, nsUri} based on
// in-scope xmlns / xmlns: declarations. Called at the tail of every
// parse entry point so consumers see a uniform expanded-name view.
//
// Reserved prefixes:
//   - `xml`   → http://www.w3.org/XML/1998/namespace
//   - `cx`    → https://cx-home.org/ns/cx
//   - `xmlns` → declaration-only; never resolves as a name prefix

export const XML_NAMESPACE_URI = 'http://www.w3.org/XML/1998/namespace';
export const CX_NAMESPACE_URI  = 'https://cx-home.org/ns/cx';

function _splitNsPrefix(name: string): [string, string] {
  const i = name.indexOf(':');
  if (i < 0) return ['', name];
  return [name.slice(0, i), name.slice(i + 1)];
}

function _lookupNs(prefix: string, scope: Map<string, string>[]): string | null {
  if (prefix === 'xml') return XML_NAMESPACE_URI;
  if (prefix === 'cx')  return CX_NAMESPACE_URI;
  if (prefix === 'xmlns') return null;
  for (let i = scope.length - 1; i >= 0; i--) {
    const uri = scope[i].get(prefix);
    if (uri !== undefined) {
      return uri.length > 0 ? uri : null;
    }
  }
  return null;
}

function _resolveElement(e: Element, scope: Map<string, string>[]): void {
  const frame = new Map<string, string>();
  for (const a of e.attrs) {
    const v = a.value === null || a.value === undefined ? '' : String(a.value);
    if (a.name === 'xmlns') {
      frame.set('', v);
    } else if (a.name.startsWith('xmlns:') && a.name.length > 6) {
      frame.set(a.name.slice(6), v);
    }
  }
  const pushed = frame.size > 0;
  if (pushed) scope.push(frame);

  const [prefix, local] = _splitNsPrefix(e.name);
  e.local = local;
  e.nsUri = _lookupNs(prefix, scope);

  for (const a of e.attrs) {
    const [ap, al] = _splitNsPrefix(a.name);
    a.local = al;
    if (a.name === 'xmlns' || ap === 'xmlns') {
      a.nsUri = null;
      continue;
    }
    if (ap === '') {
      // Default ns does not apply to unprefixed attrs.
      a.nsUri = null;
      continue;
    }
    a.nsUri = _lookupNs(ap, scope);
  }

  for (const item of e.items) {
    if (item instanceof Element) {
      _resolveElement(item, scope);
    }
  }

  if (pushed) scope.pop();
}

/** Populate Element.{local, nsUri} and Attr.{local, nsUri} on every
 *  node in `doc` per ADR 0002 / spec/namespaces.md. Also propagates
 *  cx:lang inherited scope per spec/i18n.md §1.3 — sets
 *  Element.langResolved on every Element. Idempotent. Called
 *  automatically by parse / parseXml / parseJson / parseYaml /
 *  parseToml / parseMd. */
export function resolveNamespaces(doc: Document): void {
  const scope: Map<string, string>[] = [];
  for (const n of doc.elements) {
    if (n instanceof Element) _resolveElement(n, scope);
  }
  const langStack: (string | null)[] = [];
  for (const n of doc.elements) {
    if (n instanceof Element) _resolveElementLang(n, langStack);
  }
}

/** Propagate cx:lang per spec/i18n.md §1.3. Mirrors V's
 *  vcx/cx/namespaces.v::resolve_element_lang. */
function _resolveElementLang(el: Element, stack: (string | null)[]): void {
  let ownTag: string | null = null;
  let declared = false;
  for (const a of el.attrs) {
    if (a.name === 'cx:lang') {
      ownTag = typeof a.value === 'string' ? a.value
        : a.value == null ? ''
        : String(a.value);
      declared = true;
      break;
    }
  }
  const resolved = declared ? ownTag
    : stack.length > 0 ? stack[stack.length - 1]
    : null;
  el.langResolved = resolved;
  stack.push(resolved);
  for (const item of el.items) {
    if (item instanceof Element) _resolveElementLang(item, stack);
  }
  stack.pop();
}

// ── Public parse functions ────────────────────────────────────────────────────

/** Parse a CX string into a Document (uses binary protocol).
 *  Optional `opts.includeRoot` enables spec/include.md §1-§8
 *  ?include resolution (v0.7.0 GG4). Empty / undefined preserves
 *  directives in the AST. */
export function parse(cxStr: string, opts?: { includeRoot?: string }): Document {
  const root = opts?.includeRoot ?? '';
  const data = root
    ? _toAstBinWithIncludeRoot(cxStr, root)
    : _toAstBin(cxStr);
  const doc = _decodeAST(data);
  resolveNamespaces(doc);
  return doc;
}

// v3.4 (Phase 5 / CB-2): parse_<format> goes through cx_<fmt>_to_ast_bin
// directly, avoiding the prior cx_<fmt>_to_ast → JSON.parse → walk-dict
// pipeline.

/** Parse an XML string into a Document. */
export function parseXml(xmlStr: string): Document {
  const doc = _decodeAST(_xmlToAstBin(xmlStr));
  resolveNamespaces(doc);
  return doc;
}

/** Parse a JSON string into a Document. */
export function parseJson(jsonStr: string): Document {
  const doc = _decodeAST(_jsonToAstBin(jsonStr));
  resolveNamespaces(doc);
  return doc;
}

/** Parse a YAML string into a Document. */
export function parseYaml(yamlStr: string): Document {
  const doc = _decodeAST(_yamlToAstBin(yamlStr));
  resolveNamespaces(doc);
  return doc;
}

/** Parse a TOML string into a Document. */
export function parseToml(tomlStr: string): Document {
  const doc = _decodeAST(_tomlToAstBin(tomlStr));
  resolveNamespaces(doc);
  return doc;
}

/** Parse a Markdown string into a Document. */
export function parseMd(mdStr: string): Document {
  const doc = _decodeAST(_mdToAstBin(mdStr));
  resolveNamespaces(doc);
  return doc;
}

// ── Data binding: loads / dumps ───────────────────────────────────────────────

/**
 * Deserialize CX data string into native JS types (object/array/scalar).
 *
 * v3.4: parses through CXDB v1 (cx_to_data_bin) directly into JS types —
 * no JSON-string detour. Type fidelity preserved (integers stay integer
 * Numbers — or bigint when wider than 2^53 — bool stays bool, dates
 * round-trip as Date, bytes as Buffer). Closes audit finding CB-3.
 */
export function loads(cxStr: string): any {
  return _cxdbDecode(_toDataBin(cxStr));
}

/**
 * Serialize native JS types (object/array/scalar) to a CX string.
 *
 * v3.4: encodes JS value as CXDB v1 bytes directly, then calls
 * cx_from_data_bin to produce canonical CX. No JSON-string detour;
 * type fidelity preserved on round-trip with loads(). Closes audit
 * finding CB-3.
 */
export function dumps(data: any): string {
  return _fromDataBin(_cxdbEncode(data));
}

/** Deserialize an XML string into native JS types. */
export function loadsXml(xmlStr: string): any {
  return JSON.parse(_xmlToJson(xmlStr));
}

/** Deserialize a JSON string via the CX semantic bridge. */
export function loadsJson(jsonStr: string): any {
  return JSON.parse(_jsonToJson(jsonStr));
}

/** Deserialize a YAML string into native JS types. */
export function loadsYaml(yamlStr: string): any {
  return JSON.parse(_yamlToJson(yamlStr));
}

/** Deserialize a TOML string into native JS types. */
export function loadsToml(tomlStr: string): any {
  return JSON.parse(_tomlToJson(tomlStr));
}

/** Deserialize a Markdown string into native JS types. */
export function loadsMd(mdStr: string): any {
  return JSON.parse(_mdToJson(mdStr));
}

// ── CX emitter ────────────────────────────────────────────────────────────────

const _DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const _DATETIME_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/;
const _HEX_RE = /^0[xX][0-9a-fA-F]+$/;

// ── ID/IDREF helpers (ADR 0003) ───────────────────────────────────────────────

function _findElementById(nodes: Node[], id: string): Element | null {
  for (const n of nodes) {
    if (n instanceof Element) {
      if (n.id === id) return n;
      const found = _findElementById(n.items, id);
      if (found) return found;
    }
  }
  return null;
}

function _collectElementsById(nodes: Node[], out: Record<string, Element>): void {
  for (const n of nodes) {
    if (n instanceof Element) {
      if (n.id) out[n.id] = n;
      _collectElementsById(n.items, out);
    }
  }
}

function _wouldAutotype(s: string): boolean {
  if (s.includes(' ')) return false;
  if (_HEX_RE.test(s)) return true;
  // integer check
  if (/^-?\d+$/.test(s)) return true;
  // float check
  if (s.includes('.') || s.toLowerCase().includes('e')) {
    if (!isNaN(Number(s)) && s.trim() !== '') return true;
  }
  if (s === 'true' || s === 'false' || s === 'null') return true;
  if (_DATETIME_RE.test(s)) return true;
  if (_DATE_RE.test(s)) return true;
  return false;
}

function _cxChooseQuote(s: string): string {
  if (!s.includes("'")) return `'${s}'`;
  if (!s.includes('"')) return `"${s}"`;
  if (!s.includes("'''")) return `'''${s}'''`;
  return `"${s}"`;  // best effort; embedded ''' stays as-is
}

function _cxQuoteText(s: string): string {
  const needs =
    s.startsWith(' ') || s.endsWith(' ') ||
    s.includes('  ') || s.includes('\n') || s.includes('\t') ||
    s.includes('[') || s.includes(']') || s.includes('&') ||
    s.startsWith(':') || s.startsWith("'") || s.startsWith('"') ||
    _wouldAutotype(s);
  return needs ? _cxChooseQuote(s) : s;
}

function _cxQuoteAttr(s: string): string {
  if (!s || s.includes(' ') || s.includes("'") || s.includes('"')) {
    return `'${s}'`;
  }
  return s;
}

function _emitScalar(s: ScalarNode): string {
  const v = s.value;
  if (v === null || v === undefined) return 'null';
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  if (typeof v === 'number') {
    if (Number.isInteger(v) && s.dataType !== 'float') return String(v);
    // float — ensure decimal point present
    const f = String(v);
    return (f.includes('.') || f.toLowerCase().includes('e')) ? f : f + '.0';
  }
  return String(v);
}

function _emitAttr(a: Attr): string {
  if (a.isRef) {
    // ADR 0003 D1: bare `@id` round-trips verbatim.
    return `${a.name}=@${a.value}`;
  }
  const dt = a.dataType;
  if (dt === 'int') return `${a.name}=${Math.trunc(Number(a.value))}`;
  if (dt === 'float') {
    const f = String(Number(a.value));
    const v = (f.includes('.') || f.toLowerCase().includes('e')) ? f : f + '.0';
    return `${a.name}=${v}`;
  }
  if (dt === 'bool') return `${a.name}=${a.value ? 'true' : 'false'}`;
  if (dt === 'null') return `${a.name}=null`;
  // string attr — quote if would autotype OR starts with '@' (else
  // would mis-parse as is_ref reference per ADR 0003).
  const s = String(a.value);
  const startsAt = s.length > 0 && s[0] === '@';
  const v = (_wouldAutotype(s) || startsAt) ? _cxChooseQuote(s) : _cxQuoteAttr(s);
  return `${a.name}=${v}`;
}

function _emitInline(node: Node): string {
  if (node instanceof TextNode) {
    return node.value.trim() === '' ? '' : _cxQuoteText(node.value);
  }
  if (node instanceof ScalarNode) return _emitScalar(node);
  if (node instanceof EntityRefNode) return `&${node.name};`;
  if (node instanceof RawTextNode) return `[#${node.value}#]`;
  if (node instanceof Element) return _emitElement(node, 0).replace(/\n$/, '');
  if (node instanceof BlockContentNode) {
    const inner = node.items.map(n => {
      if (n instanceof TextNode) return n.value;
      if (n instanceof Element) return _emitElement(n, 0).replace(/\n$/, '');
      return '';
    }).join('');
    return `[|${inner}|]`;
  }
  return '';
}

function _emitElement(e: Element, depth: number): string {
  const ind = '  '.repeat(depth);
  // v3.4 (ADR 0003 D1): body-position reference shape `[<name> @<id>]`.
  // No meta or attrs/items per parser contract — just the bare ref body.
  if (e.bodyRef) {
    return `${ind}[${e.name} @${e.bodyRef}]\n`;
  }
  const hasChildElems = e.items.some(i => i instanceof Element);
  const hasText = e.items.some(
    i => i instanceof TextNode || i instanceof ScalarNode ||
         i instanceof EntityRefNode || i instanceof RawTextNode,
  );
  const isMultiline = hasChildElems && !hasText;

  const metaParts: string[] = [];
  if (e.anchor) metaParts.push(`&${e.anchor}`);
  if (e.merge) metaParts.push(`*${e.merge}`);
  if (e.id) metaParts.push(`#${e.id}`);
  if (e.dataType) metaParts.push(`:${e.dataType}`);
  for (const a of e.attrs) metaParts.push(_emitAttr(a));
  const meta = metaParts.length > 0 ? (' ' + metaParts.join(' ')) : '';

  if (isMultiline) {
    let out = `${ind}[${e.name}${meta}\n`;
    for (const item of e.items) {
      out += _emitNode(item, depth + 1);
    }
    out += `${ind}]\n`;
    return out;
  }

  if (e.items.length === 0 && !meta) {
    return `${ind}[${e.name}]\n`;
  }

  const bodyParts = e.items.map(_emitInline).filter(p => p !== '');
  const body = bodyParts.join(' ');
  const sep = body ? ' ' : '';
  return `${ind}[${e.name}${meta}${sep}${body}]\n`;
}

function _emitNode(node: Node, depth: number): string {
  const ind = '  '.repeat(depth);
  if (node instanceof Element) return _emitElement(node, depth);
  if (node instanceof TextNode) return _cxQuoteText(node.value);
  if (node instanceof ScalarNode) return _emitScalar(node);
  if (node instanceof CommentNode) return `${ind}[-${node.value}]\n`;
  if (node instanceof RawTextNode) return `${ind}[#${node.value}#]\n`;
  if (node instanceof EntityRefNode) return `&${node.name};`;
  if (node instanceof AliasNode) return `${ind}[*${node.name}]\n`;
  if (node instanceof BlockContentNode) {
    const inner = node.items.map(i => _emitNode(i, 0)).join('');
    return `${ind}[|${inner}|]\n`;
  }
  if (node instanceof PINode) {
    const data = node.data ? ` ${node.data}` : '';
    return `${ind}[?${node.target}${data}]\n`;
  }
  if (node instanceof XMLDeclNode) {
    const parts = [`version=${node.version}`];
    if (node.encoding) parts.push(`encoding=${node.encoding}`);
    if (node.standalone) parts.push(`standalone=${node.standalone}`);
    return `[?xml ${parts.join(' ')}]\n`;
  }
  if (node instanceof CXDirectiveNode) {
    const attrStr = node.attrs.map(a => `${a.name}=${_cxQuoteAttr(String(a.value))}`).join(' ');
    return `[?cx ${attrStr}]\n`;
  }
  if (node instanceof DoctypeDeclNode) {
    let ext = '';
    if (node.externalID) {
      if ('public' in node.externalID) {
        const pub = node.externalID.public;
        const sys = node.externalID.system ?? '';
        ext = ` PUBLIC '${pub}' '${sys}'`;
      } else if ('system' in node.externalID) {
        ext = ` SYSTEM '${node.externalID.system}'`;
      }
    }
    return `[!DOCTYPE ${node.name}${ext}]\n`;
  }
  return '';
}

function _emitDoc(doc: Document): string {
  const parts: string[] = [];
  for (const node of doc.prolog) {
    parts.push(_emitNode(node, 0));
  }
  if (doc.doctype) {
    parts.push(_emitNode(doc.doctype, 0));
  }
  for (const node of doc.elements) {
    parts.push(_emitNode(node, 0));
  }
  return parts.join('').replace(/\n+$/, '');
}
