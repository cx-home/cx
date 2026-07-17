"""Tests for cxlib.EventWriter (Phase 7.74h — Python streaming-write wrapper)."""
from __future__ import annotations
import os
import sys
import struct
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(__file__))

import cxlib


class TestEventWriterBasics(unittest.TestCase):

    def test_capability_bit_27_set(self):
        from cxlib.cx import features
        self.assertTrue(features() & (1 << 27), 'capability bit 27 should be set')

    def test_minimal_cx_roundtrip(self):
        with cxlib.EventWriter('cx') as w:
            w.start_doc()
            w.start_element('greet')
            w.text('hello')
            w.end_element('greet')
            w.end_doc()
            out = w.close_get_bytes()
        s = out.decode()
        self.assertIn('[greet', s)
        self.assertIn('hello', s)

    def test_minimal_xml(self):
        with cxlib.EventWriter('xml') as w:
            w.start_doc()
            w.start_element('greet')
            w.text('hello & welcome')
            w.end_element('greet')
            w.end_doc()
            out = w.close_get_bytes()
        s = out.decode()
        self.assertIn('<?xml version="1.0"?>', s)
        self.assertIn('<greet>', s)
        self.assertIn('hello &amp; welcome', s)
        self.assertIn('</greet>', s)

    def test_attrs_roundtrip(self):
        with cxlib.EventWriter('cx') as w:
            w.start_doc()
            w.start_element('row', attrs=[('id', 1, 'int'), ('name', 'alice')])
            w.end_element('row')
            w.end_doc()
            out = w.close_get_bytes()
        s = out.decode()
        self.assertIn('id=1', s)
        self.assertIn('name=', s)


class TestEventWriterWcodes(unittest.TestCase):

    def assertWcode(self, code: str, fn, *args, **kw):
        with self.assertRaises(RuntimeError) as ctx:
            fn(*args, **kw)
        self.assertIn(code, str(ctx.exception),
                      f'expected {code} in error, got {ctx.exception!r}')

    def test_w001_double_start_doc(self):
        w = cxlib.EventWriter('cx')
        try:
            w.start_doc()
            self.assertWcode('W001', w.start_doc)
        finally:
            try: w.close_get_bytes()
            except Exception: pass

    def test_w002_event_before_start_doc(self):
        w = cxlib.EventWriter('cx')
        try:
            self.assertWcode('W002', w.text, 'premature')
        finally:
            try: w.close_get_bytes()
            except Exception: pass

    def test_w003_event_after_end_doc(self):
        w = cxlib.EventWriter('cx')
        try:
            w.start_doc()
            w.end_doc()
            self.assertWcode('W003', w.text, 'post')
        finally:
            try: w.close_get_bytes()
            except Exception: pass

    def test_w004_unclosed_element(self):
        w = cxlib.EventWriter('cx')
        try:
            w.start_doc()
            w.start_element('open')
            self.assertWcode('W004', w.end_doc)
        finally:
            try: w.close_get_bytes()
            except Exception: pass

    def test_w005_end_element_mismatch(self):
        w = cxlib.EventWriter('cx')
        try:
            w.start_doc()
            w.start_element('greet')
            self.assertWcode('W005', w.end_element, 'farewell')
        finally:
            try: w.close_get_bytes()
            except Exception: pass

    def test_w006_orphan_end_element(self):
        w = cxlib.EventWriter('cx')
        try:
            w.start_doc()
            self.assertWcode('W006', w.end_element, 'orphan')
        finally:
            try: w.close_get_bytes()
            except Exception: pass

    def test_w008_invalid_data_type(self):
        w = cxlib.EventWriter('cx')
        try:
            w.start_doc()
            self.assertWcode('W008', w.scalar, '42', data_type='not_a_type')
        finally:
            try: w.close_get_bytes()
            except Exception: pass

    def test_w009_alias_on_xml(self):
        w = cxlib.EventWriter('xml')
        try:
            w.start_doc()
            self.assertWcode('W009', w.alias, 'ref')
        finally:
            try: w.close_get_bytes()
            except Exception: pass

    def test_w012_orphan_row_group(self):
        w = cxlib.EventWriter('cx')
        try:
            w.start_doc()
            self.assertWcode('W012', w.row_group, b'\x01')
        finally:
            try: w.close_get_bytes()
            except Exception: pass

    def test_w013_orphan_end_table(self):
        w = cxlib.EventWriter('cx')
        try:
            w.start_doc()
            self.assertWcode('W013', w.end_table)
        finally:
            try: w.close_get_bytes()
            except Exception: pass

    def test_fail_closed(self):
        """After a W-code, subsequent emits raise the same diagnostic."""
        w = cxlib.EventWriter('cx')
        try:
            w.start_doc()
            w.start_element('a')
            with self.assertRaises(RuntimeError):
                w.end_element('b')
            # Subsequent emit should also raise (with W005).
            with self.assertRaises(RuntimeError) as ctx:
                w.text('still broken')
            self.assertIn('W005', str(ctx.exception))
        finally:
            try: w.close_get_bytes()
            except Exception: pass


class TestEventWriterChunkedTable(unittest.TestCase):

    def _col_spec_2(self) -> bytes:
        # 2 columns: name:string (0x30), score:i32 (0x12).
        out = bytearray()
        out += struct.pack('<I', 2)
        out += struct.pack('<I', 4) + b'name'
        out.append(0x30)
        out += struct.pack('<I', 5) + b'score'
        out.append(0x12)
        return bytes(out)

    def _row_group_2_rows(self) -> bytes:
        # uvarint(2) + col1 strings ("alice","bob") + col2 i32 LE (91,88).
        out = bytearray()
        out.append(2)  # uvarint(2)
        out += b'\x05alice'
        out += b'\x03bob'
        out += struct.pack('<i', 91)
        out += struct.pack('<i', 88)
        return bytes(out)

    def test_chunked_table_cx_emit(self):
        with cxlib.EventWriter('cx') as w:
            w.start_doc()
            w.start_element('points')
            w.start_table(self._col_spec_2())
            w.row_group(self._row_group_2_rows())
            w.end_table()
            w.end_element('points')
            w.end_doc()
            out = w.close_get_bytes()
        s = out.decode()
        # #509: the writer must emit the CURRENT `[table[…]]` clause-child
        # form (the retired `:table[` opener is unparseable), and the text
        # must round-trip through the binding's own parse entry — a
        # structural assertion, not a substring pin.
        self.assertIn('[table[', s)
        tbl = cxlib.Table.from_cx(s)
        self.assertEqual(tbl.row_count, 2)
        self.assertEqual(tbl.row(0)['name'], 'alice')
        self.assertEqual(tbl.row(0)['score'], 91)
        self.assertEqual(tbl.row(1)['name'], 'bob')
        self.assertEqual(tbl.row(1)['score'], 88)

    def test_chunked_table_w009_on_xml(self):
        w = cxlib.EventWriter('xml')
        try:
            w.start_doc()
            with self.assertRaises(RuntimeError) as ctx:
                w.start_table(self._col_spec_2())
            self.assertIn('W009', str(ctx.exception))
        finally:
            try: w.close_get_bytes()
            except Exception: pass


class TestEventWriterFd(unittest.TestCase):

    def test_fd_writer_basic(self):
        with tempfile.NamedTemporaryFile() as tf:
            with cxlib.EventWriter('cx', fd=tf.fileno()) as w:
                w.start_doc()
                w.start_element('hi')
                w.text('there')
                w.end_element('hi')
                w.end_doc()
                out = w.close_get_bytes()
            # fd writers return empty bytes from close_get_bytes.
            self.assertEqual(out, b'')
            tf.seek(0)
            content = tf.read().decode()
            self.assertIn('[hi', content)
            self.assertIn('there', content)


if __name__ == '__main__':
    unittest.main()
