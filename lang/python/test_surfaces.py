"""Smoke tests for the v0.8.0 directive / value surfaces exposed
through the Python Tier-1 binding.

Covers:
  - CXPath value expressions (`//user[@active=true]`)
  - code.md §8.2 — multi-arm `[?match]` (`[case …]` … `[else …]`)
  - code.md §8.10 — `[?modify]` with `[set]` / `[delete]` / `[set-attr]` /
               `[rename]` / `[using]`
  - atom scalar kind (`:NAME` literals, Atom value wrapper)

These are *binding-surface* smoke tests: they confirm that each new
directive/value form parses + evaluates through `cxlib.eval_code`, and
that the Atom decoder path round-trips through `cxlib.parse` + emit.
Deeper semantics live in `vcx/tests/code_eval_fixtures_test.v` and the
cross-binding `conformance_code.py` runner.

Phase 3.3 of spec/v0_8_0_status.md.
"""

from __future__ import annotations

import os
import sys
import unittest

# Allow `python3 -m unittest test_surfaces` from lang/python/.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import cxlib  # noqa: E402


def _strip(s: str) -> str:
    return s.strip()


# ── CXPath value expressions ─────────────────────────────────────


class TestCXPathValueExpr(unittest.TestCase):
    DOC_USERS = (
        '[users\n'
        '  [user active=true  [name Alice]]\n'
        '  [user active=false [name Bob]]\n'
        '  [user active=true  [name Carol]]]'
    )

    def test_path_value_selects_all_users(self):
        out = cxlib.eval_code(self.DOC_USERS, '//user', 'text')
        # Three [user ...] elements, one per line.
        self.assertEqual(len(out.strip().splitlines()), 3)

    def test_attribute_predicate_filters(self):
        out = cxlib.eval_code(self.DOC_USERS, '//user[@active=true]', 'text')
        lines = out.strip().splitlines()
        self.assertEqual(len(lines), 2)
        # Both surviving rows must be the active-true rows.
        for line in lines:
            self.assertIn('active=true', line)

    def test_child_step_selects_name(self):
        out = cxlib.eval_code(self.DOC_USERS, '//user/name', 'text')
        lines = out.strip().splitlines()
        self.assertEqual(len(lines), 3)
        for line in lines:
            self.assertTrue(line.startswith('[name'))


# ── multi-arm [?match] ───────────────────────────────────────────


class TestMatchMultiArm(unittest.TestCase):

    def test_scalar_literal_case_hits(self):
        prog = (
            '[?let $s = 200 :in '
            '  [?match $s '
            '    :case 200 :yield :ok '
            '    :case 404 :yield :not-found '
            '    :else     :yield :err]]'
        )
        self.assertEqual(_strip(cxlib.eval_code('[doc]', prog, 'text')), ':ok')

    def test_else_arm_fires_on_miss(self):
        prog = (
            '[?let $s = 500 :in '
            '  [?match $s '
            '    :case 200 :yield :ok '
            '    :case 404 :yield :not-found '
            '    :else     :yield :err]]'
        )
        self.assertEqual(_strip(cxlib.eval_code('[doc]', prog, 'text')), ':err')

    def test_no_else_returns_empty_sequence(self):
        prog = (
            '[?let $s = 500 :in '
            '  [?match $s '
            '    :case 200 :yield :ok '
            '    :case 404 :yield :not-found]]'
        )
        self.assertEqual(_strip(cxlib.eval_code('[doc]', prog, 'text')), '')

    def test_wildcard_case(self):
        prog = (
            '[?let $v = "surprise" :in '
            '  [?match $v '
            '    :case 200 :yield :http-ok '
            '    :case _   :yield :other]]'
        )
        self.assertEqual(_strip(cxlib.eval_code('[doc]', prog, 'text')), ':other')


# ── [?modify] ────────────────────────────────────────────────────


class TestModify(unittest.TestCase):
    DOC_USERS = '[users [user id=1 [name Alice]] [user id=2 [name Bob]]]'

    def test_set_attribute_value(self):
        # Setting an attribute value at a focused path.
        prog = '[?modify $doc //user[@id=1]/@name [set "Alicia"]]'
        out = cxlib.eval_code(self.DOC_USERS, prog, 'text')
        self.assertIn('Alicia', out)
        # Bob is untouched.
        self.assertIn('Bob', out)

    def test_delete_focus(self):
        doc = ('[users '
               '[user active=true [name Alice]] '
               '[user active=false [name Bob]]]')
        prog = '[?modify $doc //user[@active=false] [delete]]'
        out = cxlib.eval_code(doc, prog, 'text')
        self.assertNotIn('Bob', out)
        self.assertIn('Alice', out)

    def test_rename_element(self):
        doc = '[doc [widget id=1 [label "Click me"]]]'
        prog = '[?modify $doc //widget [rename component]]'
        out = cxlib.eval_code(doc, prog, 'text')
        self.assertIn('[component', out)
        self.assertNotIn('[widget', out)

    def test_no_match_is_identity(self):
        prog = '[?modify $doc //missing :delete]'
        out = cxlib.eval_code(self.DOC_USERS, prog, 'text').strip()
        # No matches → unchanged.
        self.assertIn('Alice', out)
        self.assertIn('Bob', out)


# ── atom scalar kind ─────────────────────────────────────────────


class TestAtomScalarKind(unittest.TestCase):

    def test_atom_literal_in_eval_text(self):
        out = cxlib.eval_code('', ':ok', 'text')
        self.assertEqual(_strip(out), ':ok')

    def test_for_yields_atom_sequence(self):
        prog = '[?for $i :in (:a, :b, :c) :yield $i]'
        out = cxlib.eval_code('', prog, 'text')
        self.assertEqual(_strip(out), ':a\n:b\n:c')

    def test_atom_decodes_to_Atom_wrapper(self):
        doc = cxlib.parse('[response code=:not-found]')
        attr = doc.elements[0].attrs[0]
        self.assertEqual(attr.data_type, 'atom')
        self.assertIsInstance(attr.value, cxlib.Atom)
        self.assertEqual(attr.value, cxlib.Atom('not-found'))

    def test_atom_type_strict_equality(self):
        # atoms are type-strict; an atom is never equal
        # to a same-named string and vice versa.
        a = cxlib.Atom('ok')
        self.assertEqual(a, cxlib.Atom('ok'))
        self.assertNotEqual(a, 'ok')
        self.assertNotEqual('ok', a)
        # Hashable — required for set/dict membership.
        self.assertEqual(hash(a), hash(cxlib.Atom('ok')))
        self.assertIn(a, {cxlib.Atom('ok'), cxlib.Atom('err')})

    def test_atom_attr_round_trips_through_to_cx(self):
        doc = cxlib.parse('[response code=:not-found]')
        out = doc.to_cx()
        self.assertIn(':not-found', out)
        self.assertNotIn('"not-found"', out)

    def test_atom_str_form(self):
        self.assertEqual(str(cxlib.Atom('hello')), ':hello')

    def test_atom_in_match_case(self):
        # Mix atom value with [?match] dispatch — both surfaces in one
        # program.
        prog = (
            '[?let $x = :ok :in '
            '  [?match $x '
            '    :case :ok  :yield "good" '
            '    :else      :yield "bad"]]'
        )
        out = cxlib.eval_code('[doc]', prog, 'text')
        self.assertEqual(_strip(out), '"good"')

    # ── Layer-1 helpers ──────────────────────────────────────

    def test_atom_constructor_returns_typed_atom(self):
        # Gate 33.1 — Layer-1 `atom(name)` returns the typed wrapper.
        a = cxlib.atom('ok')
        self.assertIsInstance(a, cxlib.Atom)
        self.assertEqual(a.name, 'ok')
        self.assertEqual(a, cxlib.Atom('ok'))

    def test_atom_constructor_accepts_kebab_and_underscores(self):
        for n in ('not-found', 'http_2', 'A', '_private'):
            self.assertEqual(cxlib.atom(n).name, n)

    def test_atom_constructor_rejects_reserved_names(self):
        # Gate 33.5 closed-list reservation.
        for n in ('true', 'false', 'null'):
            with self.assertRaises(ValueError) as ctx:
                cxlib.atom(n)
            self.assertIn('reserved', str(ctx.exception))

    def test_atom_constructor_rejects_invalid_identifier(self):
        for n in ('', '1abc', 'has space', 'has.dot', 'has/slash'):
            with self.assertRaises(ValueError):
                cxlib.atom(n)

    def test_atom_constructor_rejects_non_string(self):
        with self.assertRaises(TypeError):
            cxlib.atom(42)

    def test_is_atom_predicate(self):
        # Gate 33.2 — predicate distinguishes atom from string.
        self.assertTrue(cxlib.is_atom(cxlib.atom('ok')))
        self.assertFalse(cxlib.is_atom('ok'))
        self.assertFalse(cxlib.is_atom(None))
        self.assertFalse(cxlib.is_atom(42))
        self.assertFalse(cxlib.is_atom(True))

    def test_atom_name_accessor(self):
        self.assertEqual(cxlib.atom_name(cxlib.atom('ok')), 'ok')
        self.assertEqual(cxlib.atom_name(cxlib.atom('not-found')), 'not-found')

    def test_atom_name_rejects_non_atom(self):
        # Gate 33.2 — type-strict; no coercion from string.
        with self.assertRaises(TypeError):
            cxlib.atom_name('ok')
        with self.assertRaises(TypeError):
            cxlib.atom_name(None)

    def test_atom_hash_disjoint_from_string(self):
        # Gate 33.6 — atom hash and string hash domains must be disjoint
        # (typed wrapper carries discriminator). The Atom wrapper hash
        # mixes the type tag via dataclass identity.
        a = cxlib.atom('ok')
        self.assertNotEqual(hash(a), hash('ok'))

    def test_atom_ast_bin_roundtrip(self):
        # Gate 33.3 — round-trip through ast_bin via cx_to_ast_bin →
        # decode_ast → encode_ast → cx_ast_bin_to_cx. Atom must survive
        # byte-identical in canonical render.
        src = '[event kind=:click]'
        doc = cxlib.parse(src)
        # Decoded value is the typed Atom.
        attr = doc.elements[0].attrs[0]
        self.assertTrue(cxlib.is_atom(attr.value))
        self.assertEqual(cxlib.atom_name(attr.value), 'click')
        # Round-trip preserves the colon-prefixed canonical form.
        out = doc.to_cx().strip()
        self.assertEqual(out, '[event kind=:click]')

    def test_features_advertises_atom_cap_bit(self):
        # Gate capability bit 33 (0x200000000) MUST be
        # set in cx_features() once the binding supports atom round-trip.
        # We delegate the bit-set decision to libcx (the Python binding
        # is a thin wrapper). Skip with a warning if libcx hasn't yet
        # flipped the bit so we don't gate Python's tests on V state.
        bits = cxlib.features()
        if not (bits & (1 << 33)):
            self.skipTest(
                'libcx cx_features() has not yet advertised bit 33 '
                '(0x200000000) for atom support; Python binding is '
                'ready, awaiting V cap-bit flip in vcx/cx/cabi.v'
            )
        self.assertTrue(bits & (1 << 33))


# ── Layer-1 Document.select_all ──────────────────────────────


class TestDocumentSelectAll(unittest.TestCase):
    DOC = (
        '[users '
        '[user active=true [name Alice]] '
        '[user active=false [name Bob]] '
        '[user active=true [name Carol]]]'
    )

    def test_select_all_with_predicate(self):
        doc = cxlib.parse(self.DOC)
        res = doc.select_all('//user[@active=true]')
        self.assertEqual(len(res), 2)
        for e in res:
            self.assertIsInstance(e, cxlib.Element)
            self.assertEqual(e.name, 'user')

    def test_select_all_no_match_returns_empty_list(self):
        doc = cxlib.parse(self.DOC)
        self.assertEqual(doc.select_all('//missing'), [])

    def test_select_all_unfiltered(self):
        doc = cxlib.parse(self.DOC)
        res = doc.select_all('//user')
        self.assertEqual(len(res), 3)


# ── Layer-1 Document.modify ──────────────────────────────────


class TestDocumentModify(unittest.TestCase):

    def test_modify_delete_returns_new_doc(self):
        doc = cxlib.parse(
            '[users '
            '[user active=true [name Alice]] '
            '[user active=false [name Bob]]]'
        )
        new_doc = doc.modify('//user[@active=false]', '[delete]')
        self.assertIsInstance(new_doc, cxlib.Document)
        out = new_doc.to_cx()
        self.assertNotIn('Bob', out)
        self.assertIn('Alice', out)

    def test_modify_rename_element(self):
        doc = cxlib.parse('[doc [widget id=1 [label "Click me"]]]')
        new_doc = doc.modify('//widget', '[rename component]')
        out = new_doc.to_cx()
        self.assertIn('component', out)
        self.assertNotIn('widget', out)

    def test_modify_is_pure_functional(self):
        # receiver unchanged.
        doc = cxlib.parse('[doc [widget id=1]]')
        original_cx = doc.to_cx()
        _ = doc.modify('//widget', '[rename component]')
        self.assertEqual(doc.to_cx(), original_cx)

    def test_modify_no_match_returns_identity_doc(self):
        doc = cxlib.parse('[users [user [name Alice]]]')
        new_doc = doc.modify('//missing', '[delete]')
        self.assertIn('Alice', new_doc.to_cx())


# ── Combined / regression ───────────────────────────────────────────────────


class TestCombined(unittest.TestCase):

    def test_cxpath_inside_modify_uses_predicate(self):
        # CXPath value form is the focus arg of [?modify]
        # This exercises both surfaces in one program.
        doc = ('[users '
               '[user active=true [name Alice]] '
               '[user active=false [name Bob]] '
               '[user active=true [name Carol]]]')
        prog = '[?modify $doc //user[@active=false] [delete]]'
        out = cxlib.eval_code(doc, prog, 'text')
        self.assertNotIn('Bob', out)
        self.assertIn('Alice', out)
        self.assertIn('Carol', out)


if __name__ == '__main__':
    unittest.main()
