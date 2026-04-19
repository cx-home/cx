# CX Conformance Test Suite
Version: 1.0 — 2026-04-19

Language-neutral tests for all CX implementations. Each test defines CX source
input and expected outputs for AST JSON, XML, and CX round-trip. Tests are
plain text, parseable in ~20 lines of any language.

---

## File Format

```
=== test: NNN-name
level: core|extended
tags: tag1 tag2
--- in_cx
<CX source>
--- out_ast
<expected AST as JSON>
--- out_xml
<expected XML output>
--- out_cx
<expected CX round-trip>
```

A section body runs from its `--- key` line to the next `--- key`, `=== test:`,
or EOF. Strip leading/trailing blank lines from section bodies before comparing.

---

## Parse Algorithm

```python
def parse_suite(path):
    tests, cur, section = [], None, None
    for raw in open(path):
        line = raw.rstrip("\n")
        if line.startswith("=== test:"):
            if cur: tests.append(cur)
            cur = {"name": line[9:].strip(), "sections": {}}
            section = None
        elif line.startswith("level:") and cur:
            cur["level"] = line[6:].strip()
        elif line.startswith("tags:") and cur:
            cur["tags"] = line[5:].strip().split()
        elif line.startswith("--- ") and cur:
            section = line[4:].strip()
            cur["sections"][section] = []
        elif section is not None and cur is not None:
            cur["sections"][section].append(line)
    if cur: tests.append(cur)
    for t in tests:
        for k, lines in t["sections"].items():
            while lines and not lines[0].strip(): lines.pop(0)
            while lines and not lines[-1].strip(): lines.pop()
            t["sections"][k] = "\n".join(lines)
    return tests
```

---

## Levels

**core** — Document, Element, Text, Comment, PI, XMLDecl, CXDirective,
EntityRef, RawText, EntityDecl, DoctypeDecl.
All conforming implementations MUST pass every core test.

**extended** — Scalar (auto-typed and explicit), TypeAnnotation, Alias, Anchor,
Merge, MultiDoc.
Implementations MUST pass all extended tests for each feature they claim.

---

## Comparison Rules

- **AST**: JSON key order is not significant. Compare semantically.
  Scalar numeric values must match type (int `30` ≠ float `30.0`).
- **XML**: Exact string match after stripping leading/trailing blank lines.
- **CX**: Exact string match after stripping leading/trailing blank lines.

---

## Target Languages

| Language      | Status      | Notes                              |
|---------------|-------------|------------------------------------|
| Rust          | Reference   | Primary implementation             |
| Go            | Planned     |                                    |
| TypeScript/JS | Planned     |                                    |
| Python        | In progress | Migrating from v2.0 to v2.1 AST    |
| Java          | Planned     |                                    |
| C#            | Planned     |                                    |
| Swift         | Planned     |                                    |
| C             | Planned     | Shared ABI / WASM bridge           |
| V (Vlang)     | Planned     |                                    |

---

## AST Quick Reference

Node types and their key fields (optional fields omitted when empty/absent):

| Type          | Key fields                                         |
|---------------|----------------------------------------------------|
| Document      | prolog[], doctype, elements[]                      |
| XMLDecl       | version, encoding?, standalone?                    |
| CXDirective   | attrs[]                                            |
| PI            | target, data?                                      |
| Comment       | value                                              |
| DoctypeDecl   | name, externalID?, intSubset[]                     |
| Element       | name, anchor?, merge?, dataType?, attrs[], items[] |
| Attribute     | name, value                                        |
| Text          | value                                              |
| Scalar        | dataType, value (native JSON type)                 |
| Alias         | name                                               |
| EntityRef     | name                                               |
| RawText       | value                                              |
| EntityDecl    | kind (GE/PE), name, def (string or ExternalEntityDef) |
| ElementDecl   | name, contentspec                                  |
| AttlistDecl   | name, defs[]                                       |
| NotationDecl  | name, publicID?, systemID?                         |
| ConditionalSect | kind (include/ignore), subset[]                  |

Scalar dataTypes: `int`, `float`, `bool`, `null`, `string`, `date`,
`datetime`, `bytes`. Values use native JSON types (number, boolean, null,
string).

Auto-typing applies ONLY when an element body has a single unquoted token and
no child elements. Priority: hex-int → int → float → bool → null → datetime →
date → Text.

---

## cx: Namespace

URI: `https://cxformat.org/ns`  
Reserved prefix: `cx`

| AST field          | XML attribute         |
|--------------------|-----------------------|
| element.anchor     | cx:anchor="name"      |
| element.merge      | cx:merge="name"       |
| element.dataType   | cx:type="string[]"    |
| alias node         | `<cx:alias name="…"/>` |

---

## Relation to test-case.txt

`test-case.txt` at the repo root is the legacy Python-only test harness (v2.0
AST format with `body: {kind, items}`). It will be retired once the Python
implementation migrates to the v2.1 AST. This conformance suite is canonical
for all language implementations.
