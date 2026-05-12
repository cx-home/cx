#!/usr/bin/env python3
"""Python conformance runner — delegates to libcx via ctypes."""
import sys, os, json
sys.path.insert(0, os.path.dirname(__file__))

from cxlib.cx import (
    to_cx, to_xml, to_ast, to_json, to_md,
    xml_to_cx, xml_to_xml, xml_to_ast, xml_to_json, xml_to_md,
    md_to_cx, md_to_xml, md_to_ast, md_to_json, md_to_md,
)
from cxlib.validate import validate, validate_with_defaults, Severity
from cxlib.event_writer import EventWriter

MULTIDOC_SEP = '\n---\n'

# ── suite parser ─────────────────────────────────────────────────────────────

def parse_suite(path):
    tests, cur, section, buf = [], None, None, []

    def flush():
        if cur is not None and section is not None:
            lines = buf[:]
            while lines and not lines[0].strip():  lines.pop(0)
            while lines and not lines[-1].strip(): lines.pop()
            cur['sections'][section] = '\n'.join(lines)
        buf.clear()

    with open(path) as f:
        for raw in f:
            raw = raw.rstrip('\n')
            if raw.startswith('=== test:'):
                flush()
                if cur: tests.append(cur)
                cur = {'name': raw[9:].strip(), 'sections': {}}
                section = None
            elif raw.startswith('level:') and cur:
                cur['level'] = raw[6:].strip()
            elif raw.startswith('tags:') and cur:
                cur['tags'] = raw[5:].strip().split()
            elif raw.startswith('--- ') and cur:
                flush()
                section = raw[4:].strip()
            elif section and cur:
                buf.append(raw)

    flush()
    if cur: tests.append(cur)
    return tests

# ── test runner ───────────────────────────────────────────────────────────────

# ── streaming-write runner ────────────────────────────────────────────────────

def _parse_event_line(line):
    """Return (op, args) for an event statement. `args` is a list of raw
    tokens (strings); the dispatcher decodes their semantics per op."""
    line = line.strip()
    if not line: return None
    # The grammar is simple — split on first space, then peel quoted strings.
    head, _, rest = line.partition(' ')
    return head, rest

def _decode_quoted(s):
    s = s.strip()
    if s.startswith('"') and s.endswith('"'):
        return s[1:-1]
    return s

def _hex_bytes(s):
    return bytes.fromhex(s.strip())

def _dispatch_event(w, op, rest):
    if op == 'StartDoc':       w.start_doc()
    elif op == 'EndDoc':       w.end_doc()
    elif op == 'StartElement':
        # name [anchor=v] [data_type=v] [merge=v]
        toks = rest.split()
        name = toks[0]
        kw = {}
        for tok in toks[1:]:
            if '=' in tok:
                k, _, v = tok.partition('=')
                kw[k] = v
        w.start_element(name,
                        anchor=kw.get('anchor'),
                        data_type=kw.get('data_type'),
                        merge=kw.get('merge'))
    elif op == 'EndElement':   w.end_element(rest.strip())
    elif op == 'Text':         w.text(_decode_quoted(rest))
    elif op == 'Scalar':
        # Scalar <type>:<value>
        typ, _, val = rest.partition(':')
        w.scalar(val, data_type=typ.strip())
    elif op == 'Comment':      w.comment(_decode_quoted(rest))
    elif op == 'PI':
        toks = rest.split(None, 1)
        target = toks[0]
        data = None
        if len(toks) > 1 and toks[1].startswith('data='):
            data = _decode_quoted(toks[1][5:])
        w.pi(target, data)
    elif op == 'EntityRef':    w.entity_ref(rest.strip())
    elif op == 'RawText':      w.raw_text(_decode_quoted(rest))
    elif op == 'Alias':        w.alias(rest.strip())
    elif op == 'StartTable':   w.start_table(_hex_bytes(rest))
    elif op == 'RowGroup':     w.row_group(_hex_bytes(rest))
    elif op == 'EndTable':     w.end_table()
    else:
        raise ValueError(f'unknown event op: {op!r}')


def _first_nonblank_noncomment(text):
    for line in (text or '').splitlines():
        t = line.strip()
        if t and not t.startswith('#'):
            return t
    return ''


def _strip_comments(text):
    if text is None: return None
    out = [ln for ln in text.splitlines() if not ln.strip().startswith('#')]
    return '\n'.join(out)


def run_streaming_write_test(s):
    failures = []
    fmt = s['format'].strip()
    expect_err = _first_nonblank_noncomment(s.get('expect_err', ''))
    expect_ok = _strip_comments(s.get('expect_ok'))
    expect_ok_contains = _strip_comments(s.get('expect_ok_contains'))

    try:
        w = EventWriter(fmt)
    except Exception as e:
        if expect_err and expect_err in str(e):
            return failures
        return [f'EventWriter({fmt}) raised: {e}']

    try:
        triggered = None
        for raw in s['events'].splitlines():
            parsed = _parse_event_line(raw)
            if not parsed: continue
            op, rest = parsed
            try:
                _dispatch_event(w, op, rest)
            except RuntimeError as e:
                triggered = str(e)
                break
            except Exception as e:
                return [f'unexpected exception running event {op!r}: {e}']

        if expect_err:
            if triggered is None:
                # Maybe the error surfaces on close.
                try:
                    w.close_get_bytes()
                except RuntimeError as e:
                    triggered = str(e)
                except Exception:
                    pass
            if triggered is None:
                return [f'expected {expect_err} but writer produced no error']
            if expect_err not in triggered:
                return [f'expected {expect_err} in error, got {triggered!r}']
            return failures

        # Happy path.
        if triggered is not None:
            return [f'unexpected error: {triggered}']
        try:
            out = w.close_get_bytes()
        except RuntimeError as e:
            return [f'close_get_bytes raised: {e}']
        out_str = out.decode('utf-8', errors='replace')
        if expect_ok is not None:
            if expect_ok.strip() != out_str.strip():
                failures.append(
                    f'expect_ok mismatch\n  expected:\n{expect_ok}\n  got:\n{out_str}')
        if expect_ok_contains is not None:
            for needle in expect_ok_contains.splitlines():
                needle = needle.strip()
                if needle and needle not in out_str:
                    failures.append(f'expect_ok_contains: missing {needle!r} in output:\n{out_str}')
    finally:
        try:
            if not w._closed:                          # pylint: disable=protected-access
                w.__exit__(None, None, None)
        except Exception:
            pass
    return failures


def run_test(t):
    failures = []
    s = t['sections']

    # ── streaming-write (events + format) ───────────────────────────────────
    if 'events' in s and 'format' in s:
        return run_streaming_write_test(s)

    # ── schema validator (sv_*) ──────────────────────────────────────────────
    # When schema_cxs is present, the test pairs an in_cx target document with
    # a schema source and asserts on validation outcomes. Per
    # conformance/schema_validate.txt header.
    if 'schema_cxs' in s and 'in_cx' in s:
        try:
            report = validate(s['in_cx'], s['schema_cxs'])
        except RuntimeError as e:
            failures.append(f'validate raised: {e}')
            return failures

        def split_codes(raw):
            return [c.strip() for c in raw.split(',') if c.strip()]

        if 'sv_assert_valid' in s:
            if s['sv_assert_valid'].strip() != '1':
                failures.append(f'sv_assert_valid: only "1" is supported, got {s["sv_assert_valid"]!r}')
            elif not report.is_valid():
                failures.append(
                    f'sv_assert_valid: expected zero error diagnostics, got {report.error_codes()}'
                )
        if 'sv_expected_codes' in s:
            expected = split_codes(s['sv_expected_codes'])
            got = [d.code for d in report.diagnostics if d.severity == Severity.ERROR]
            if expected != got:
                failures.append(f'sv_expected_codes mismatch\n  expected: {expected}\n  got:      {got}')
        if 'sv_expected_warn_codes' in s:
            expected = split_codes(s['sv_expected_warn_codes'])
            got = [d.code for d in report.diagnostics if d.severity == Severity.WARN]
            if expected != got:
                failures.append(f'sv_expected_warn_codes mismatch\n  expected: {expected}\n  got:      {got}')
        if 'sv_expected_info_codes' in s:
            expected = split_codes(s['sv_expected_info_codes'])
            got = [d.code for d in report.diagnostics if d.severity == Severity.INFO]
            if expected != got:
                failures.append(f'sv_expected_info_codes mismatch\n  expected: {expected}\n  got:      {got}')
        return failures

    if   'in_cx'  in s: src, fmt = s['in_cx'],  'cx'
    elif 'in_xml' in s: src, fmt = s['in_xml'], 'xml'
    elif 'in_md'  in s: src, fmt = s['in_md'],  'md'
    else: return failures  # no input — skip

    if fmt == 'xml':
        emit_cx, emit_xml, emit_ast, emit_json, emit_md = xml_to_cx, xml_to_xml, xml_to_ast, xml_to_json, xml_to_md
    elif fmt == 'md':
        emit_cx, emit_xml, emit_ast, emit_json, emit_md = md_to_cx, md_to_xml, md_to_ast, md_to_json, md_to_md
    else:
        emit_cx, emit_xml, emit_ast, emit_json, emit_md = to_cx, to_xml, to_ast, to_json, to_md

    def call(fn, text):
        try:
            return fn(text), None
        except RuntimeError as e:
            return None, str(e)

    # ── out_ast ───────────────────────────────────────────────────────────────
    if 'out_ast' in s:
        out, err = call(emit_ast, src)
        if err:
            failures.append(f'out_ast parse error: {err}')
        else:
            expected = json.loads(s['out_ast'])
            got = json.loads(out)
            if expected != got:
                failures.append(
                    f'out_ast mismatch\n  expected: {json.dumps(expected, indent=2)}\n  got:      {json.dumps(got, indent=2)}'
                )

    # ── out_xml ───────────────────────────────────────────────────────────────
    if 'out_xml' in s:
        out, err = call(emit_xml, src)
        if err:
            failures.append(f'out_xml parse error: {err}')
        elif s['out_xml'].strip() != out.strip():
            failures.append(f'out_xml mismatch\n  expected:\n{s["out_xml"]}\n  got:\n{out}')

    # ── out_cx ────────────────────────────────────────────────────────────────
    if 'out_cx' in s:
        out, err = call(emit_cx, src)
        if err:
            failures.append(f'out_cx parse error: {err}')
        elif s['out_cx'].strip() != out.strip():
            failures.append(f'out_cx mismatch\n  expected:\n{s["out_cx"]}\n  got:\n{out}')

    # ── out_json ──────────────────────────────────────────────────────────────
    if 'out_json' in s:
        out, err = call(emit_json, src)
        if err:
            failures.append(f'out_json parse error: {err}')
        else:
            expected = json.loads(s['out_json'])
            got = json.loads(out)
            if expected != got:
                failures.append(
                    f'out_json mismatch\n  expected: {json.dumps(expected, indent=2)}\n  got:      {json.dumps(got, indent=2)}'
                )

    # ── out_md ────────────────────────────────────────────────────────────────
    if 'out_md' in s:
        out, err = call(emit_md, src)
        if err:
            failures.append(f'out_md parse error: {err}')
        elif s['out_md'].strip() != out.strip():
            failures.append(f'out_md mismatch\n  expected:\n{s["out_md"]}\n  got:\n{out}')

    return failures

# ── suite runner ──────────────────────────────────────────────────────────────

def run_suite(path):
    tests = parse_suite(path)
    passed = failed = 0
    for t in tests:
        try:
            failures = run_test(t)
        except Exception as e:
            failures = [f'runner exception: {e}']
        if failures:
            failed += 1
            print(f'FAIL  {t["name"]}')
            for f in failures:
                for line in f.splitlines():
                    print(f'      {line}')
        else:
            passed += 1
    print(f'{path}: {passed} passed, {failed} failed')
    return failed

# ── entry point ───────────────────────────────────────────────────────────────

if __name__ == '__main__':
    base = os.path.join(os.path.dirname(__file__), '..', '..', 'conformance')
    suites = sys.argv[1:] or [
        os.path.join(base, 'core.txt'),
        os.path.join(base, 'extended.txt'),
        os.path.join(base, 'xml.txt'),
        os.path.join(base, 'md.txt'),
        os.path.join(base, 'schema_validate.txt'),
        os.path.join(base, 'streaming_write.txt'),
    ]
    total_failed = sum(run_suite(s) for s in suites)
    sys.exit(1 if total_failed else 0)
