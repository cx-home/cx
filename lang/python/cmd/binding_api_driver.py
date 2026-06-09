#!/usr/bin/env python3
"""Binding-API parity driver — Python.

Reads one JSON fixture object on stdin:

    {"id": "...", "in_cx": "...", "ops": {...}}

Executes the op-tree through the Python Layer-1 surface
(`cxlib.code.Doc`) and prints the canonical result on stdout. On
binding-side error, prints `ERR:<code>` (one line) and exits 0 — error
shape itself is part of the parity contract.

Exit 2 = invocation / protocol error (not a fixture failure).
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any

# Add the repo's lang/python so `import cxlib` finds the bundled lib.
REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "lang" / "python"))

# Steer the loader to the in-tree libcx if a system-installed one is
# missing; the Makefile sets LIBCX_PATH but allow standalone use too.
if "LIBCX_PATH" not in os.environ:
    candidate = REPO / "vcx" / "target" / (
        "libcx.dylib" if sys.platform == "darwin" else "libcx.so"
    )
    if candidate.exists():
        os.environ["LIBCX_PATH"] = str(candidate)

from cxlib.code import Doc  # noqa: E402
from cxlib import cx as _cx  # noqa: E402


# ── result-rendering helpers ────────────────────────────────────────────────
#
# The fixture file's `--- out_text` uses canonical CX surface forms for
# every Layer-1 return shape. We render the same shapes here so all four
# drivers can be diffed byte-for-byte.


def render_str(value: str) -> str:
    """Render a string scalar as canonical CX (quoted, with backslash
    escapes for `"` and `\\`)."""
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def render_value(value: Any) -> str:
    """Canonical-CX rendering of a scalar / bool / int / atom / None."""
    if value is None:
        return "()"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value) if isinstance(value, float) else str(value)
    if isinstance(value, str):
        return render_str(value)
    if isinstance(value, dict):
        # Attrs map. Render as `{k: v, ...}` to match fixture 073.
        parts = [f"{k}: {render_value(v)}" for k, v in value.items()]
        return "{" + ", ".join(parts) + "}"
    if isinstance(value, list):
        return "\n".join(render_value(v) for v in value)
    return repr(value)


def render_node_cx(node) -> str:
    """Serialize a Node (Layer-1) back to canonical CX bytes."""
    # `Node.element` is the underlying cxlib.ast.Element. Wrap in a
    # Document so the canonical emitter handles it uniformly.
    from cxlib import ast as _ast
    el = node.element
    doc = _ast.Document(elements=[el])
    return doc.to_cx().rstrip("\n")


def render_node_list(nodes) -> str:
    return "\n".join(render_node_cx(n) for n in nodes)


# ── op-tree evaluator ──────────────────────────────────────────────────────


class EvalError(Exception):
    """Carries the CXERnnnn code surfaced by a Layer-1 method."""

    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


def extract_error_code(msg: str) -> str:
    """Pull `CXERnnnn` out of an exception message; fall back to a
    stable token so cross-binding diffs surface real divergence."""
    import re
    m = re.search(r"CXER\d{4}", msg)
    if m:
        return m.group(0)
    return "UNKNOWN-ERROR"


def evaluate(op: dict, doc: Doc | None, env: dict[str, Any] | None = None) -> Any:
    """Walk the op-tree. Returns Python values (Doc / Node / str / int /
    bool / list / dict / None / 'Action'-tagged tuple).

    `env` carries block-local named bindings (fixture 053)."""
    if env is None:
        env = {}
    kind = op["kind"]
    if kind == "doc_ref":
        if doc is None:
            raise EvalError("CXER0100")
        return doc
    if kind == "str":
        return op["value"]
    if kind == "num":
        v = op["value"]
        return float(v) if "." in v else int(v)
    if kind == "bool":
        return op["value"]
    if kind == "action":
        # An action constructor — return a tagged tuple consumed by
        # `modify`. Layer-1 `Doc.modify` takes a string action; this
        # ctor produces the canonical CX action string.
        return ("__ACTION__", op["name"], [evaluate(a, doc, env) for a in op["args"]])
    if kind == "lambda_cx":
        # A pre-lowered `[?fn ...]` CX source. Surfaces as a string the
        # action renderer will splice verbatim.
        return ("__LAMBDA_CX__", op["source"])
    if kind == "method":
        target = evaluate(op["target"], doc, env)
        args = [evaluate(a, doc, env) for a in op["args"]]
        return dispatch(target, op["method"], args, doc)
    if kind == "var":
        name = op["name"]
        if name not in env:
            raise EvalError(f"UNDEFINED-VAR-{name}")
        return env[name]
    if kind == "eq":
        lhs = evaluate(op["left"], doc, env)
        rhs = evaluate(op["right"], doc, env)
        return _eq_values(lhs, rhs)
    if kind == "block":
        block_env = dict(env)
        for b in op["bindings"]:
            block_env[b["name"]] = evaluate(b["op"], doc, block_env)
        return block_env[op["result"]]
    if kind == "spawn":
        # Run the body in a fresh OS thread. The parity-test purpose
        # is to verify the binding's GC thread-register path works.
        import threading
        result: list[Any] = [None]
        err: list[EvalError | None] = [None]
        def runner() -> None:
            try:
                result[0] = evaluate(op["body"], doc, env)
            except EvalError as e:
                err[0] = e
            except Exception as e:  # noqa: BLE001
                err[0] = EvalError(extract_error_code(str(e)))
        t = threading.Thread(target=runner)
        t.start()
        t.join()
        if err[0] is not None:
            raise err[0]
        return result[0]
    raise EvalError(f"UNKNOWN-OP-{kind}")


def _eq_values(lhs: Any, rhs: Any) -> bool:
    """Equality semantics that match the fixture's intent:

    `__RAW__`-tagged tuples (bytes/hash output) compare by their string
    payload; other scalars compare directly. This means
    `doc.bytes() == doc.bytes()` and `doc.hash() == other.hash()` both
    work without special-casing each driver type."""
    def unwrap(v: Any) -> Any:
        if isinstance(v, tuple) and v and v[0] == "__RAW__":
            return v[1]
        return v
    return unwrap(lhs) == unwrap(rhs)


def render_action(action_tuple) -> str:
    """Render a tagged action tuple as the canonical CX action string
    accepted by `Doc.modify(focus, action)`."""
    _, name, args = action_tuple
    # Clause form per spec/code.md §8.10: `[set "x"]`, `[delete]`,
    # `[rename component]`, `[set-attr "status" "v"]`, `[append [...]]`.
    kw_map = {
        "Set": "set",
        "Delete": "delete",
        "Rename": "rename",
        "SetAttr": "set-attr",
        "DeleteAttr": "delete-attr",
        "Append": "append",
        "Prepend": "prepend",
        "InsertBefore": "insert-before",
        "InsertAfter": "insert-after",
        "Replace": "replace",
        "Using": "using",
    }
    kw = kw_map.get(name, name.lower())
    rendered_args: list[str] = []
    for a in args:
        if isinstance(a, tuple) and a and a[0] == "__LAMBDA_CX__":
            # Pre-lowered CX `[?fn ...]` source — splice verbatim.
            rendered_args.append(a[1])
        elif isinstance(a, str):
            # Bare identifier for :rename; quoted for everything else.
            if kw == "rename" and a.isidentifier():
                rendered_args.append(a)
            elif kw in ("append", "prepend", "insert-before", "insert-after", "replace") and a.startswith("["):
                rendered_args.append(a)
            else:
                rendered_args.append(render_str(a))
        elif isinstance(a, bool):
            rendered_args.append("true" if a else "false")
        elif isinstance(a, (int, float)):
            rendered_args.append(str(a))
        else:
            rendered_args.append(str(a))
    return f"[{kw} " + " ".join(rendered_args) + "]" if rendered_args else f"[{kw}]"


def dispatch(target: Any, method: str, args: list, doc: Doc | None) -> Any:
    """Apply `method` to `target` using Layer-1 binding methods.

    Returns rich typed values (Doc, Node, list[Node], or `("__RAW__",
    str)` for bytes / hash output that must NOT be quoted by the
    renderer)."""
    # Doc.* methods.
    if isinstance(target, Doc):
        try:
            if method == "bytes":
                # Doc.bytes() returns the canonical-CX bytes; emit as
                # raw text (no quote wrapping).
                return ("__RAW__", target.bytes().decode("utf-8").rstrip("\n"))
            if method == "hash":
                # SHA-256 hex string. Bindings return the bare hex; we
                # normalize by emitting raw (no `"sha256:"` prefix —
                # the fixture's out_text is illustrative).
                return ("__RAW__", target.hash())
            if method == "equals":
                other = args[0]
                if not isinstance(other, Doc):
                    raise EvalError("CXER0100")
                return target.equals(other)
            if method == "eval":
                return ("__RAW__", target.eval(args[0]).rstrip("\n"))
            if method == "select_all":
                return target.select_all(args[0])
            if method == "select":
                return target.select(args[0])
            if method == "modify":
                focus = args[0]
                action = args[1]
                if isinstance(action, tuple) and action[0] == "__ACTION__":
                    action_str = render_action(action)
                else:
                    action_str = str(action)
                return target.modify(focus, action_str)
            if method == "find_all":
                return target.find_all(args[0])
            if method == "root":
                return target.root()
            if method == "parse":
                # Doc.parse on an existing Doc — re-parse from bytes/str.
                src = args[0]
                if isinstance(src, tuple) and src[0] == "__RAW__":
                    src = src[1]
                if isinstance(src, str):
                    src = src.encode("utf-8")
                return Doc.parse(src)
            if method == "diagram":
                fmt = args[0] if args else "mermaid"
                return ("__RAW__", target.diagram(fmt))
            if method == "tree":
                return ("__RAW__", json.dumps(target.tree(), sort_keys=True))
        except EvalError:
            raise
        except Exception as e:  # noqa: BLE001
            raise EvalError(extract_error_code(str(e)))
        raise EvalError(f"UNKNOWN-DOC-METHOD-{method}")

    # Node.* methods.
    # We detect Node via the Layer-1 façade class.
    from cxlib.code import Node
    if isinstance(target, Node):
        try:
            if method == "name":
                return target.name()
            if method == "attr":
                return target.attr(args[0])
            if method == "attrs":
                return target.attrs()
            if method == "children":
                return target.children()
            if method == "body":
                return target.body()
            if method == "kind":
                return target.kind()
        except Exception as e:  # noqa: BLE001
            raise EvalError(extract_error_code(str(e)))
        raise EvalError(f"UNKNOWN-NODE-METHOD-{method}")

    # `target` could also be a list (select_all result) — fixture 082
    # would call `.count()` on it, but that's UNSUPPORTED at the
    # mini-syntax level since `count` is not in the 16-method surface.
    if isinstance(target, list):
        if method == "count":
            return len(target)
        raise EvalError(f"UNKNOWN-LIST-METHOD-{method}")

    # Layer-1 contract: calling a method on a null receiver surfaces
    # CXER0100 across every binding (V / Go / Rust route through their
    # error type; Python's None reaches here unchanged).
    if target is None:
        raise EvalError("CXER0100")

    raise EvalError(f"UNKNOWN-TARGET-{type(target).__name__}-{method}")


def render_result(value: Any) -> str:
    """Stringify the top-level result for parity comparison."""
    if value is None:
        return "()"
    if isinstance(value, tuple) and value and value[0] == "__RAW__":
        return value[1]
    if isinstance(value, Doc):
        return value.bytes().decode("utf-8").rstrip("\n")
    from cxlib.code import Node
    if isinstance(value, Node):
        return render_node_cx(value)
    if isinstance(value, list):
        if all(isinstance(v, Node) for v in value):
            return render_node_list(value)
        return "\n".join(render_result(v) for v in value)
    return render_value(value)


def main() -> int:
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            print("ERR:NO-INPUT", file=sys.stderr)
            return 2
        fx = json.loads(raw)
        in_cx = fx.get("in_cx", "")
        op = fx.get("ops")
        if op is None:
            print("UNSUPPORTED")
            return 0
        try:
            doc: Doc | None = None
            if in_cx:
                doc = Doc.parse(in_cx.encode("utf-8"))
        except Exception as e:  # noqa: BLE001
            # Parse-error fixtures (e.g. 090) are valid — surface the
            # error code uniformly.
            print(f"ERR:{extract_error_code(str(e))}")
            return 0
        try:
            value = evaluate(op, doc)
            print(render_result(value))
            return 0
        except EvalError as e:
            print(f"ERR:{e.code}")
            return 0
    except Exception as e:  # noqa: BLE001
        print(f"DRIVER-CRASH:{e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
