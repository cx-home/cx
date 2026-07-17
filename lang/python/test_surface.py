"""v0.8.0 Python Layer-1 + Layer-2 surface tests (Phase 3.3).

Covers the 16-method Layer-1 contract per `spec/bindings.md` §2.1, the
two code-projection helpers (`cx_code_diagram`,
`cx_code_tree`), the three atom free-functions, and the
`cxlib.idioms` Layer-2 sugar (Doc subscript / iterator / explain).

Companion to `lang/python/test_surfaces.py` (which covers the
v0.8.0 *directive* surfaces via `eval_code`).
Where that file exercises the v0.8.0 *language* surface through the
evaluator, THIS file exercises the v0.8.0 *binding* surface — the Doc
/ Node façade and the new diagram / tree exports.

Run from the repo root:

    cd lang/python && python3 -m unittest test_surface
"""
from __future__ import annotations

import os
import sys
import unittest

# Allow `python3 -m unittest test_surface` from lang/python/.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import cxlib  # noqa: E402
from cxlib.code import Doc, Node  # noqa: E402
from cxlib import idioms  # noqa: E402


HELLO_SRC = "[hello]"
USERS_SRC = (
    "[users\n"
    "  [user active=true  [name Alice]]\n"
    "  [user active=false [name Bob]]\n"
    "  [user active=true  [name Carol]]]"
)


# ─── Layer-1 — 16-method canonical surface ──────────────────────────────────


class TestLayer1Doc(unittest.TestCase):
    """One test per Doc-side Layer-1 method (10 of the 16)."""

    # Method 1 — parse(bytes) -> Doc
    def test_parse_returns_doc(self):
        d = Doc.parse(HELLO_SRC.encode())
        self.assertIsInstance(d, Doc)

    def test_parse_accepts_str(self):
        # Convenience: Doc.parse also accepts str (Layer-1 spec is
        # `bytes` but Python users routinely pass `str` — the binding
        # encodes UTF-8 internally).
        d = Doc.parse(HELLO_SRC)
        self.assertIsInstance(d, Doc)

    def test_module_parse_alias(self):
        # cxlib.parse_doc(bytes) ≡ Doc.parse(bytes) — matches the
        # spec/bindings.md §2.1 free-function entry point.
        d = cxlib.parse_doc(HELLO_SRC.encode())
        self.assertIsInstance(d, Doc)

    # Method 2 — Doc.bytes() -> bytes
    def test_bytes_round_trips(self):
        d = Doc.parse(HELLO_SRC)
        b = d.bytes()
        self.assertIsInstance(b, bytes)
        # Re-parse the emitted bytes — should hash equal.
        d2 = Doc.parse(b)
        self.assertEqual(d.hash(), d2.hash())

    # Method 3 — Doc.hash() -> str
    def test_hash_is_sha256_hex(self):
        d = Doc.parse(HELLO_SRC)
        h = d.hash()
        self.assertIsInstance(h, str)
        self.assertEqual(len(h), 64)
        int(h, 16)  # raises if not hex

    # Method 4 — Doc.equals(other) -> bool
    def test_equals_canonical_bytes(self):
        a = Doc.parse(HELLO_SRC)
        b = Doc.parse(HELLO_SRC)
        c = Doc.parse("[other]")
        self.assertTrue(a.equals(b))
        self.assertFalse(a.equals(c))

    # Method 5 — Doc.eval(code) -> Value
    def test_eval_returns_text(self):
        d = Doc.parse(HELLO_SRC)
        out = d.eval("[?for [in $i (1,2,3)] [yield $i]]", "text")
        self.assertIn("1", out)
        self.assertIn("3", out)

    # Method 6 — Doc.select_all(cxpath) -> [Node]
    def test_select_all_returns_node_list(self):
        d = Doc.parse(USERS_SRC)
        users = d.select_all("//user")
        self.assertEqual(len(users), 3)
        for u in users:
            self.assertIsInstance(u, Node)
            self.assertEqual(u.name(), "user")

    # Method 7 — Doc.select(cxpath) -> Node?
    def test_select_first_match(self):
        d = Doc.parse(USERS_SRC)
        first = d.select("//user")
        self.assertIsNotNone(first)
        self.assertEqual(first.name(), "user")

    def test_select_no_match_returns_none(self):
        d = Doc.parse(USERS_SRC)
        self.assertIsNone(d.select("//nonexistent"))

    # Method 8 — Doc.modify(focus, action) -> Doc
    def test_modify_returns_new_doc(self):
        d = Doc.parse(USERS_SRC)
        new_d = d.modify("//user[= $_@active false]", "[delete]")
        # Receiver is unchanged (pure-functional contract).
        self.assertEqual(len(d.select_all("//user")), 3)
        # New Doc has the inactive user removed.
        self.assertEqual(len(new_d.select_all("//user")), 2)

    # Method 9 — Doc.find_all(name) -> [Node]
    def test_find_all_by_name(self):
        d = Doc.parse(USERS_SRC)
        names = d.find_all("name")
        self.assertEqual(len(names), 3)
        for n in names:
            self.assertEqual(n.name(), "name")

    # Method 10 — Doc.root() -> Node
    def test_root_returns_node(self):
        d = Doc.parse(USERS_SRC)
        r = d.root()
        self.assertIsNotNone(r)
        self.assertEqual(r.name(), "users")


class TestLayer1Node(unittest.TestCase):
    """One test per Node-side Layer-1 method (6 of the 16)."""

    def setUp(self):
        self.doc = Doc.parse(USERS_SRC)
        users = self.doc.select_all("//user")
        self.user = users[0]  # Alice — active=true

    # Method 11 — Node.name() -> str
    def test_node_name(self):
        self.assertEqual(self.user.name(), "user")

    # Method 12 — Node.attr(name) -> Value?
    def test_node_attr_present(self):
        # active=true is parsed as a bool scalar.
        self.assertEqual(self.user.attr("active"), True)

    def test_node_attr_missing(self):
        self.assertIsNone(self.user.attr("nonexistent"))

    # Method 13 — Node.attrs() -> Map
    def test_node_attrs_map(self):
        attrs = self.user.attrs()
        self.assertIsInstance(attrs, dict)
        self.assertIn("active", attrs)

    # Method 14 — Node.children() -> [Node]
    def test_node_children(self):
        kids = self.user.children()
        self.assertEqual(len(kids), 1)
        self.assertEqual(kids[0].name(), "name")

    # Method 15 — Node.body() -> Value
    def test_node_body(self):
        # Body of [name Alice] is the bareword Alice (parses as string
        # scalar).
        name_node = self.user.children()[0]
        body = name_node.body()
        self.assertIn("Alice", str(body))

    # Method 16 — Node.kind() -> str
    def test_node_kind(self):
        self.assertEqual(self.user.kind(), "element")


# ─── atom Layer-1 (free functions) ─────────────────────────────────


class TestAtomLayer1(unittest.TestCase):
    """Re-asserts the three atom helpers from
    `cxlib/__init__.py`.  Phase 3.7 already shipped these; this guards
    against accidental removal during the Layer-1 retarget."""

    def test_atom_constructs(self):
        a = cxlib.atom("ok")
        self.assertTrue(cxlib.is_atom(a))
        self.assertEqual(cxlib.atom_name(a), "ok")

    def test_is_atom_rejects_string(self):
        self.assertFalse(cxlib.is_atom("ok"))

    def test_atom_name_type_strict(self):
        with self.assertRaises(TypeError):
            cxlib.atom_name("ok")  # not an Atom


# ─── cx_code_diagram / cx_code_tree ──────────────────────────────


class TestCodeDiagram(unittest.TestCase):

    def test_diagram_returns_string(self):
        out = cxlib.cx_code_diagram(HELLO_SRC)
        self.assertIsInstance(out, str)
        self.assertGreater(len(out), 0)

    def test_diagram_via_doc_method(self):
        d = Doc.parse(HELLO_SRC)
        out = d.diagram()
        self.assertIsInstance(out, str)
        self.assertGreater(len(out), 0)

    def test_diagram_unsupported_format_raises(self):
        with self.assertRaises(RuntimeError) as ctx:
            cxlib.cx_code_diagram(HELLO_SRC, "png")
        self.assertIn("CXER", str(ctx.exception))


class TestCodeTree(unittest.TestCase):

    def test_tree_returns_dict(self):
        tree = cxlib.cx_code_tree(HELLO_SRC)
        self.assertIsInstance(tree, dict)
        # required shape.
        self.assertIn("kind", tree)
        self.assertIn("loc", tree)
        self.assertIsInstance(tree["loc"], dict)
        self.assertIn("start", tree["loc"])
        self.assertIn("end", tree["loc"])

    def test_tree_loc_spans_source(self):
        tree = cxlib.cx_code_tree(HELLO_SRC)
        # Stub returns loc.end = len(source).  Forward-compatible: the
        # walker MUST keep loc.end <= len(source) and start >= 0.
        self.assertEqual(tree["loc"]["start"], 0)
        self.assertGreaterEqual(tree["loc"]["end"], 0)
        self.assertLessEqual(tree["loc"]["end"], len(HELLO_SRC.encode("utf-8")))

    def test_tree_via_doc_method(self):
        d = Doc.parse(HELLO_SRC)
        tree = d.tree()
        self.assertIsInstance(tree, dict)
        self.assertIn("kind", tree)

    def test_tree_empty_source(self):
        # Stub contract: empty source returns a minimal-shape root with
        # loc.{start,end} = 0.
        tree = cxlib.cx_code_tree("")
        self.assertEqual(tree["loc"]["start"], 0)
        self.assertEqual(tree["loc"]["end"], 0)


# ─── cx_code_eval re-export ─────────────────────────────────────────────────


class TestCodeEvalAlias(unittest.TestCase):
    """`cxlib.cx_code_eval` re-exports `cxlib.eval_code`
    — the v0.8.0 C ABI symbol name."""

    def test_alias_returns_eval_output(self):
        out_via_alias = cxlib.cx_code_eval(HELLO_SRC, "[?for [in $i (1,2)] [yield $i]]", "text")
        out_via_legacy = cxlib.eval_code(HELLO_SRC, "[?for [in $i (1,2)] [yield $i]]", "text")
        self.assertEqual(out_via_alias, out_via_legacy)


# ─── Layer-2 — `cxlib.idioms` sugar ─────────────────────────────────────────


class TestLayer2Idioms(unittest.TestCase):

    def test_subscript_desugars_to_select_all(self):
        doc = idioms.Doc.parse(USERS_SRC)
        users = doc["//user"]
        self.assertEqual(len(users), 3)

    def test_truediv_iterates_select_all(self):
        doc = idioms.Doc.parse(USERS_SRC)
        names = [n.name() for n in (doc / "//user")]
        self.assertEqual(names, ["user", "user", "user"])

    def test_contains_checks_match(self):
        doc = idioms.Doc.parse(USERS_SRC)
        self.assertIn("//user", doc)
        self.assertNotIn("//nonexistent", doc)

    def test_iter_yields_root_children(self):
        doc = idioms.Doc.parse(USERS_SRC)
        kids = list(iter(doc))
        # root is [users [user ...] [user ...] [user ...]] → 3 children.
        self.assertEqual(len(kids), 3)

    def test_clone_independent(self):
        doc = idioms.Doc.parse(USERS_SRC)
        clone = doc.clone()
        self.assertTrue(doc.equals(clone))

    def test_explain_getitem(self):
        s = idioms.explain(None, "getitem", "//user")
        self.assertIn("select_all", s)
        self.assertIn("//user", s)

    def test_explain_setitem(self):
        s = idioms.explain(None, "setitem", "//user/@name", "Alice")
        self.assertIn("modify", s)
        self.assertIn("[set", s)

    def test_explain_truediv(self):
        s = idioms.explain(None, "truediv", "//user")
        self.assertIn("iter", s)
        self.assertIn("select_all", s)


if __name__ == "__main__":
    unittest.main()
