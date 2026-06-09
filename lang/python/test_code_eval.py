"""Phase 5 Tier-1 binding parity (Python) — cx_code_eval* surface.

Covers the cx_code_eval* entry-point family exported from
vcx/code/cabi.v + documented at spec/audits/code_abi_v1.md.
The C ABI shape is:

    cx_code_eval              (NUL-terminated one-shot)
    cx_code_eval_with_len     (explicit-length one-shot)
    cx_code_eval_streaming    (length-bearing streaming via cb)

Pythonic wrappers under cxlib.eval_code / cxlib.eval_code_streaming
route through the _with_len + streaming forms (the binding always uses
length-bearing variants so non-NUL-terminated input flows through
unchanged).
"""

import unittest
import cxlib


class TestEvalCodeOneShot(unittest.TestCase):

    def test_simple_find(self):
        input_cx = '[doc [order id=1 status="open"] [order id=2 status="closed"] [order id=3 status="open"]]'
        prog = '[?for [order $m] [yield $m]]'
        out = cxlib.eval_code(input_cx, prog, 'text')
        lines = out.split('\n')
        self.assertEqual(len(lines), 3)
        for line in lines:
            self.assertTrue(line.startswith('[order'))

    def test_for_comprehension(self):
        prog = '[?for [in $i (1, 2, 3)] [yield [item n=$i]]]'
        out = cxlib.eval_code('', prog, 'text')
        self.assertEqual(out, '[item n=1]\n[item n=2]\n[item n=3]')

    def test_empty_input_ok(self):
        out = cxlib.eval_code('', '[?let [= $x 42] [ok value=$x]]', '')
        self.assertEqual(out, '[ok value=42]')

    def test_default_target_is_text(self):
        a = cxlib.eval_code('', '[ok value=1]', '')
        b = cxlib.eval_code('', '[ok value=1]', 'text')
        self.assertEqual(a, b)
        self.assertEqual(a, '[ok value=1]')

    def test_cx_target(self):
        out = cxlib.eval_code('', '[ok value="x"]', 'cx')
        self.assertEqual(out, '[ok value=x]')

    def test_unknown_target_rejected(self):
        with self.assertRaises(RuntimeError) as ctx:
            cxlib.eval_code('', '[ok]', 'protobuf')
        msg = str(ctx.exception)
        self.assertIn('CXER0100', msg)
        self.assertIn('protobuf', msg)

    def test_svg_target_returns_diagram(self):
        # Phase 4.1 landed the diagram renderer — svg / mermaid / png
        # now return embedded-source diagrams instead of CXER0001.
        # html remains Phase-4-gated (no canonical mapping defined yet).
        out = cxlib.eval_code('', '[?for [user $u] [yield $u]]', 'svg')
        self.assertIn('cx:source', out)

    def test_html_target_still_phase4_gated(self):
        with self.assertRaises(RuntimeError) as ctx:
            cxlib.eval_code('', '[ok]', 'html')
        msg = str(ctx.exception)
        self.assertIn('CXER0001', msg)

    def test_parse_error_routes_cxer0100(self):
        with self.assertRaises(RuntimeError) as ctx:
            cxlib.eval_code('', '[?for', 'text')
        msg = str(ctx.exception)
        self.assertIn('CXER0100', msg)
        self.assertIn('parse', msg.lower())


class TestEvalCodeStreaming(unittest.TestCase):

    def test_concat_equals_oneshot(self):
        """spec/audits/code_abi_v1.md §3.3 contract: concatenated
        streaming output is byte-equivalent to the one-shot output."""
        prog = '[?for [in $i (10, 20, 30)] [yield [item n=$i]]]'
        one_shot = cxlib.eval_code('', prog, 'text')

        chunks: list[bytes] = []
        def on_chunk(data: bytes):
            chunks.append(data)
            return 0

        cxlib.eval_code_streaming('', prog, on_chunk, 'text')
        streamed = b''.join(chunks).decode()
        self.assertEqual(streamed, one_shot)

    def test_callback_abort(self):
        """A non-zero return from on_chunk aborts evaluation cleanly."""
        prog = '[?for [in $i (1, 2, 3)] [yield [item n=$i]]]'
        seen: list[bytes] = []

        def on_chunk(data: bytes):
            seen.append(data)
            return 1   # abort on first chunk

        with self.assertRaises(RuntimeError):
            cxlib.eval_code_streaming('', prog, on_chunk, 'text')

    def test_callback_exception_propagates(self):
        """A raising on_chunk is captured + re-raised wrapped in RuntimeError."""
        prog = '[ok value=1]'

        def boom(_data: bytes):
            raise ValueError('sink rejected chunk')

        with self.assertRaises(RuntimeError) as ctx:
            cxlib.eval_code_streaming('', prog, boom, 'text')
        # Exception chaining surfaces the ValueError via __cause__.
        self.assertIsNotNone(ctx.exception.__cause__)
        self.assertIsInstance(ctx.exception.__cause__, ValueError)


class TestRenderTargets(unittest.TestCase):
    """Phase 3.11 follow-up: exercise the json/yaml/xml/csv/tsv renderers
    through the libcx → cffi → cxlib path. Pins documented shapes from
    vcx/code/render.v and spec/abi.md §2.16.1."""

    def test_json_scalar_ast_shape(self):
        out = cxlib.eval_code('', '[?let [= $x 42] $x]', 'json')
        self.assertEqual(out, '{"type":"Scalar","dataType":"int","value":42}')

    def test_json_sequence_is_array(self):
        out = cxlib.eval_code('', '[?let [= $x (1, 2, 3)] $x]', 'json')
        self.assertTrue(out.startswith('['))
        self.assertTrue(out.endswith(']'))
        for v in ('"value":1', '"value":2', '"value":3'):
            self.assertIn(v, out)

    def test_yaml_record_wraps_root_key(self):
        out = cxlib.eval_code('', '[ok value=1]', 'yaml')
        self.assertIn('ok:', out)
        self.assertIn('1', out)

    def test_xml_record_emits_element(self):
        out = cxlib.eval_code('', '[ok value=1]', 'xml')
        self.assertIn('<ok', out)

    def test_csv_records_emit_header_and_rows(self):
        doc = '[doc [order id=1 status="open"] [order id=2 status="closed"]]'
        out = cxlib.eval_code(doc, '[?for [order $m] [yield $m]]', 'csv')
        lines = out.split('\n')
        self.assertEqual(lines[0], 'id,status')
        self.assertEqual(lines[1], '1,open')
        self.assertEqual(lines[2], '2,closed')

    def test_csv_non_tabular_rejected(self):
        with self.assertRaises(RuntimeError) as ctx:
            cxlib.eval_code('', '[?let [= $x 42] $x]', 'csv')
        self.assertIn('CXER0100', str(ctx.exception))


class TestErrorWireFormat(unittest.TestCase):

    def test_cxer_prefix_format(self):
        """D3 of code_abi_v1.md: errors arrive as `CXERnnnn:msg` —
        the cx-err: namespace prefix is stripped at the ABI boundary
        (that prefix is reserved for value-form errors inside programs).
        Note: bare-ident-only programs like `not a valid program` parse
        successfully (each ident becomes a no-arg call); use an
        unterminated directive to force a parse error."""
        with self.assertRaises(RuntimeError) as ctx:
            cxlib.eval_code('', '[?for', 'text')
        msg = str(ctx.exception)
        self.assertTrue(msg.startswith('CXER'),
                        f'expected CXERnnnn prefix, got: {msg}')


if __name__ == '__main__':
    unittest.main()
