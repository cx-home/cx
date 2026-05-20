#!/usr/bin/env python3
"""
⛔ DO NOT PUBLISH — see DO-NOT-PUBLISH.md in this directory.

This server is on the back burner as of 2026-05-19. The implementation
materially undersells CXL: ~400 lines of Python with HTML embedded as
strings, validation logic in Python, data filtering in Python, state in
Python. The stated value proposition ("thin Python, fat CXL") is not
delivered. Reconsider when the cx-eval gaps listed in DO-NOT-PUBLISH.md
are closed.

────────────────────────────────────────────────────────────────────

Minimal HTMX demo server for examples/htmx/.

Each subdirectory under examples/htmx/ ships an HTMX pattern:
  active-search/      typeahead search filtering a user list
  click-to-edit/      view/edit toggle for a contact card
  click-to-load/      paginated "load more" rows
  inline-validation/  field-level validation feedback
  modal-dialog/       modal popup fragment

Each one has:
  *.cx     — context document (pure data)
  *.cxl    — CXL template(s) — directives evaluate to HTML fragments
  README.md — what HTMX pattern + which CXL features

This server hosts a landing page that links to each demo and wires
each template's hx-* URLs back to a route that re-renders the right
fragment via `cx eval TEMPLATE.cxl --data=DATA.cx | cx --to=xml`.

Run:
    python3 examples/htmx/serve.py                # default port 8000
    python3 examples/htmx/serve.py --port=9000

Open:
    http://localhost:8000/

Requirements: `cx` on $PATH (v0.7.0+).
"""

import argparse
import json
import os
import re
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

HERE = os.path.dirname(os.path.abspath(__file__))


def cx_eval_render(template_rel: str, data_rel: str, inline_data: str = None) -> str:
    """Pipe `cx eval template (--data=data | -d inline)` through `cx --to=xml`."""
    tpl  = os.path.join(HERE, template_rel)
    cmd  = ["cx", "eval", tpl]
    if inline_data is not None:
        cmd += ["-d", inline_data]
    else:
        cmd += [f"--data={os.path.join(HERE, data_rel)}"]
    try:
        eval_out = subprocess.run(
            cmd, capture_output=True, text=True, check=True,
        ).stdout
        xml_out = subprocess.run(
            ["cx", "--from=cx", "--to=xml"],
            input=eval_out, capture_output=True, text=True, check=True,
        ).stdout
        return xml_out
    except subprocess.CalledProcessError as e:
        return (
            f'<pre style="color:#c33;background:#fee;padding:1em">'
            f'cx pipeline failed:\n  STDOUT: {e.stdout}\n  STDERR: {e.stderr}'
            f'</pre>'
        )


def validate_field(name: str, value: str) -> str:
    """Toy validators for the inline-validation demo. Returns the error
    message (string, possibly empty) or "" if valid."""
    if name == "email":
        if "@" not in value or "." not in value:
            return "Must be a valid email address"
    elif name == "password":
        if len(value) < 6:
            return "Password must be at least 6 characters"
    elif name == "username":
        if len(value) < 3:
            return "Username must be at least 3 characters"
        if not value.replace("_", "").isalnum():
            return "Username may only contain letters, digits, and underscores"
    return ""


# In-memory contact store for the click-to-edit demo. Edits made via
# PUT /contact/{cid} update this dict; subsequent GET /contact/{cid}
# and /contact/{cid}/edit render against the updated values via an
# inline data document. Keyed by cid as written in contact.cx (default
# "42"). Reset on server restart — fine for a demo.
CONTACT_STORE: dict = {}


def _load_contact(data_rel: str):
    """Load contact.cx into CONTACT_STORE if not already cached."""
    if CONTACT_STORE:
        return
    raw = subprocess.run(
        ["cx", "--to=json", os.path.join(HERE, data_rel)],
        capture_output=True, text=True, check=True,
    ).stdout
    doc = json.loads(raw)
    contact = doc.get("contacts", {}).get("contact", {})
    CONTACT_STORE.update({
        "cid":   str(contact.get("cid", "42")),
        "first": str(contact.get("first", "")),
        "last":  str(contact.get("last", "")),
        "email": str(contact.get("email", "")),
    })


def _contact_data_doc() -> str:
    """Build a CX data document from the in-memory contact store.
    Root is `[contacts ...]` to match the template's //contact xpath."""
    c = CONTACT_STORE
    return (
        f'[contacts [contact cid="{c["cid"]}"'
        f' first="{c["first"]}"'
        f' last="{c["last"]}"'
        f' email="{c["email"]}"]]'
    )


def filter_users_by_search(data_rel: str, query: str) -> str:
    """Read users.cx, filter users whose name OR email contains the query
    (case-insensitive), return a CX text document containing only the
    matches. Used by the active-search demo to do real input-driven
    filtering — cx-eval's :where currently can't compare an attribute
    to another attribute, so we filter Python-side and pass the result
    inline to `cx eval -d '…' rows-template`."""
    data_path = os.path.join(HERE, data_rel)
    raw = subprocess.run(
        ["cx", "--to=json", data_path],
        capture_output=True, text=True, check=True,
    ).stdout
    doc = json.loads(raw)
    users = doc.get("users", {}).get("user", [])
    if isinstance(users, dict):
        users = [users]
    q = (query or "").strip().lower()
    if q:
        users = [
            u for u in users
            if q in str(u.get("name", "")).lower()
            or q in str(u.get("email", "")).lower()
        ]
    # Build a minimal CX doc with the filtered users.
    parts = ["[users"]
    for u in users:
        parts.append(
            f'  [user name="{u.get("name","")}"'
            f' email="{u.get("email","")}"'
            f' role="{u.get("role","")}"]'
        )
    parts.append("]")
    return "\n".join(parts)


# ── Demo registry ────────────────────────────────────────────────────

DEMOS = {
    "active-search": {
        "template": "active-search/search.cxl",
        "data":     "active-search/users.cx",
        "title":    "Active search",
        "blurb":    "Typeahead search filtering a user list via FLWOR :where",
    },
    "click-to-load": {
        "template": "click-to-load/page.cxl",
        "data":     "click-to-load/agents.cx",
        "title":    "Click to load",
        "blurb":    "Paginated load-more rendering a page slice",
    },
    "inline-validation": {
        "template": "inline-validation/form.cxl",
        "data":     "inline-validation/signup.cx",
        "title":    "Inline validation",
        "blurb":    "Field-level validation feedback with hx-trigger=changed",
    },
    "modal-dialog": {
        "template": "modal-dialog/modal.cxl",
        "data":     "modal-dialog/modal.cx",
        "title":    "Modal dialog",
        "blurb":    "Modal popup fragment with backdrop swap",
    },
    "click-to-edit": {
        "template": "click-to-edit/view.cxl",
        "data":     "click-to-edit/contact.cx",
        "title":    "Click to edit",
        "blurb":    "Read-only contact card → hx-get swaps in edit form → hx-put swaps back",
    },
}


# ── Pages (landing + per-demo) ───────────────────────────────────────

SHARED_STYLE = """<style>
  body { font-family: system-ui, -apple-system, sans-serif;
         max-width: 720px; margin: 2em auto; line-height: 1.5; color: #222; }
  h1 { margin-bottom: 0.2em; }
  .subtitle, .meta { color: #666; }
  .demo { border: 1px solid #ddd; border-radius: 6px;
          padding: 1em; margin: 1em 0; }
  .demo h2 { margin-top: 0; }
  a { color: #06c; text-decoration: none; }
  code { background: #f5f5f5; padding: 0.1em 0.3em; border-radius: 3px;
         font-size: 0.92em; }
  pre  { background: #f5f5f5; padding: 0.8em; border-radius: 4px;
         overflow-x: auto; }
  .table { width: 100%; border-collapse: collapse; margin-top: 1em; }
  .table th, .table td { padding: 0.5em; border-bottom: 1px solid #eee;
                         text-align: left; }
  input, button { font-size: 1em; padding: 0.5em; }
  input { width: 100%; box-sizing: border-box; }
  button { cursor: pointer; }
  .modal-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,0.4);
                    display: flex; align-items: center; justify-content: center;
                    z-index: 1000; padding: 1em; }
  .modal-dialog { background: white; padding: 1.5em 2em; border-radius: 8px;
                  width: 100%; max-width: 480px; box-sizing: border-box;
                  box-shadow: 0 8px 32px rgba(0,0,0,0.2); }
  .modal-header { position: relative; margin-bottom: 1em;
                  padding-right: 2em;
                  border-bottom: 1px solid #eee; padding-bottom: 0.5em; }
  .modal-header h3 { margin: 0; }
  .modal-header .modal-subtitle { color: #888; font-size: 0.9em;
                                   margin-top: 0.2em; }
  .modal-body .field { display: flex; gap: 0.5em; padding: 0.3em 0; }
  .modal-body .field label { min-width: 6em; }
  .close { position: absolute; top: 0; right: 0;
           background: none; border: 0; font-size: 1.5em;
           cursor: pointer; padding: 0 0.3em; line-height: 1;
           color: #888; }
  .close:hover { color: #222; }
  .error { color: #c33; font-size: 0.9em; margin-top: 0.2em; }
  .field { margin: 0.5em 0; }
  .btn, .btn-primary { display: inline-block; padding: 0.4em 0.8em;
                       border: 1px solid #ccc; background: #f8f8f8;
                       border-radius: 4px; margin-right: 0.3em; }
  .btn-primary { background: #06c; color: white; border-color: #06c; }
  label { display: inline-block; min-width: 8em; font-weight: 600; }
</style>
"""

INDEX_PAGE_HEAD = (
    '<!DOCTYPE html><html><head><title>CX + HTMX demos</title>'
    '<script src="https://unpkg.com/htmx.org@1.9.10"></script>'
    + SHARED_STYLE +
    '</head><body>'
    '<h1>CX + HTMX demos</h1>'
    '<p class="subtitle">CXL as the server-side template engine for HTMX-driven UI fragments.</p>'
)
INDEX_PAGE_TAIL = (
    '<h2>How it works</h2>'
    '<ol>'
    '<li>Browser loads this page.</li>'
    '<li>HTMX attaches to elements with <code>hx-*</code> attributes.</li>'
    '<li>On trigger, HTMX POSTs/GETs to the server.</li>'
    '<li>Server runs <code>cx eval TEMPLATE.cxl --data=DATA.cx | cx --to=xml</code> '
    'and returns the HTML fragment.</li>'
    '<li>HTMX swaps the fragment into the target element.</li>'
    '</ol>'
    '<p>Source: <code>examples/htmx/*/*.cxl</code></p>'
    '</body></html>'
)

DEMO_PAGE_HEAD = (
    '<!DOCTYPE html><html><head>'
    '<title>__TITLE__ — CX + HTMX demo</title>'
    '<script src="https://unpkg.com/htmx.org@1.9.10"></script>'
    + SHARED_STYLE +
    '</head><body>'
    '<nav><a href="/">← back to demos</a></nav>'
    '<h1>__TITLE__</h1>'
    '<p class="meta">__BLURB__<br>'
    'Template: <code>examples/htmx/__TEMPLATE__</code><br>'
    'Data: <code>examples/htmx/__DATA__</code></p>'
)
DEMO_PAGE_TAIL = (
    '<h3>What\'s happening</h3>'
    '<p>HTMX attributes in the rendered fragment fire requests back to this server. '
    'The server re-runs the same <code>cx eval … | cx --to=xml</code> pipeline and '
    'returns the new fragment.</p>'
    '</body></html>'
)


def page_index() -> str:
    parts = []
    for k, d in DEMOS.items():
        parts.append(
            f'<div class="demo"><h2><a href="/demo/{k}">{d["title"]}</a></h2>'
            f'<p>{d["blurb"]}</p>'
            f'<p style="margin:0;font-size:0.9em;color:#888">'
            f'<code>{d["template"]}</code> + <code>{d["data"]}</code></p>'
            f'</div>'
        )
    return INDEX_PAGE_HEAD + "\n".join(parts) + INDEX_PAGE_TAIL


def page_demo(key: str, body_html: str) -> str:
    d = DEMOS[key]
    head = (DEMO_PAGE_HEAD
            .replace("__TITLE__", d["title"])
            .replace("__BLURB__", d["blurb"])
            .replace("__TEMPLATE__", d["template"])
            .replace("__DATA__", d["data"]))
    return head + body_html + DEMO_PAGE_TAIL


def page_demo_initial(key: str) -> str:
    """Demo landing page — wraps the initial render with the page chrome."""
    d = DEMOS[key]
    if key == "active-search":
        # Template now includes the input + table + tbody#search-results.
        body = cx_eval_render(d["template"], d["data"])
    elif key == "click-to-edit":
        _load_contact(d["data"])
        body = ('<div id="results">'
                + cx_eval_render(d["template"], d["data"],
                                 inline_data=_contact_data_doc())
                + '</div>')
    elif key == "click-to-load":
        body = (
            '<table class="table"><tbody>' + cx_eval_render(d["template"], d["data"])
            + '</tbody></table>'
        )
    elif key == "inline-validation":
        body = '<div id="results">' + cx_eval_render(d["template"], d["data"]) + '</div>'
    elif key == "modal-dialog":
        # Initially hidden — show a button that opens the modal.
        body = (
            '<button class="btn-primary" hx-get="/modal/user-info" '
            'hx-target="body" hx-swap="beforeend">Open modal</button>'
            '<p style="color:#888">(modal markup is rendered server-side and appended to body)</p>'
        )
    else:
        body = '<div id="results">' + cx_eval_render(d["template"], d["data"]) + '</div>'
    return page_demo(key, body)


# ── HTTP handler ─────────────────────────────────────────────────────

class Handler(BaseHTTPRequestHandler):
    def _send(self, body: str, code: int = 200, ctype: str = "text/html"):
        self.send_response(code)
        self.send_header("Content-Type", ctype + "; charset=utf-8")
        self.end_headers()
        self.wfile.write(body.encode())

    def _read_body(self):
        n = int(self.headers.get("Content-Length", 0))
        return self.rfile.read(n).decode() if n else ""

    def do_GET(self):
        path = urlparse(self.path).path

        if path == "/":
            return self._send(page_index())

        m = re.match(r"^/demo/([\w-]+)$", path)
        if m and m.group(1) in DEMOS:
            return self._send(page_demo_initial(m.group(1)))

        # ── active-search has no GET endpoint (POST only) ──

        # ── click-to-edit ──
        # GET /contact/{cid}/edit → edit form, populated from store
        if re.match(r"^/contact/[\w-]+/edit$", path):
            d = DEMOS["click-to-edit"]
            _load_contact(d["data"])
            return self._send(cx_eval_render(
                "click-to-edit/edit.cxl", d["data"],
                inline_data=_contact_data_doc()))
        # GET /contact/{cid} → view (Cancel button), from store
        if re.match(r"^/contact/[\w-]+$", path):
            d = DEMOS["click-to-edit"]
            _load_contact(d["data"])
            return self._send(cx_eval_render(
                "click-to-edit/view.cxl", d["data"],
                inline_data=_contact_data_doc()))

        # ── click-to-load ──
        # GET /agents?page=N → render the final page (dataset is fixed,
        # so we terminate pagination on the first click with an "end of
        # list" row instead of looping the same data forever).
        if path == "/agents":
            d = DEMOS["click-to-load"]
            return self._send(cx_eval_render(
                "click-to-load/page-final.cxl", d["data"]))

        # ── modal-dialog ──
        # GET /modal/{mid} → render the modal
        m = re.match(r"^/modal/[\w-]+$", path)
        if m:
            d = DEMOS["modal-dialog"]
            return self._send(cx_eval_render(d["template"], d["data"]))
        # GET /modal/{mid}/close → empty (HTMX swaps backdrop with this)
        if re.match(r"^/modal/[\w-]+/close$", path):
            return self._send("")

        return self._send("not found", 404, "text/plain")

    def do_POST(self):
        path = urlparse(self.path).path
        _body = self._read_body()  # not used — demos are stateless

        # ── active-search ──
        if path == "/search":
            # Parse search input, filter Python-side, eval rows template
            # against the filtered subset.
            d = DEMOS["active-search"]
            form = parse_qs(_body)
            query = form.get("search", [""])[0]
            filtered = filter_users_by_search(d["data"], query)
            return self._send(cx_eval_render(
                "active-search/search-rows.cxl", d["data"],
                inline_data=filtered))

        # ── inline-validation ──
        # POST /signup/validate → check the field; return error text or
        # an empty "✓ looks good" message. hx-target="next .error" has
        # default innerHTML swap, so we return just the message text.
        if path == "/signup/validate":
            form = parse_qs(_body)
            # The form body has the changed field as a single key=value
            # pair; pick the first non-empty one.
            field_name, field_value = "", ""
            for k, vs in form.items():
                field_name = k
                field_value = vs[0] if vs else ""
                break
            err = validate_field(field_name, field_value)
            if err:
                return self._send(err)
            return self._send(
                '<span style="color:#3a3">✓ looks good</span>'
            )
        # POST /signup → re-render the whole form
        if path == "/signup":
            d = DEMOS["inline-validation"]
            return self._send(cx_eval_render(d["template"], d["data"]))

        return self._send("not found", 404, "text/plain")

    def do_PUT(self):
        path = urlparse(self.path).path
        _body = self._read_body()

        # ── click-to-edit ──
        # PUT /contact/{cid} → save form values to in-memory store,
        # then return view fragment built from the updated values.
        if re.match(r"^/contact/[\w-]+$", path):
            d = DEMOS["click-to-edit"]
            _load_contact(d["data"])
            form = parse_qs(_body)
            for src_name, store_key in [
                ("firstName", "first"),
                ("lastName",  "last"),
                ("email",     "email"),
            ]:
                if src_name in form:
                    CONTACT_STORE[store_key] = form[src_name][0]
            return self._send(cx_eval_render(
                "click-to-edit/view.cxl", d["data"],
                inline_data=_contact_data_doc()))

        return self._send("not found", 404, "text/plain")

    def log_message(self, fmt, *args):
        sys.stderr.write(f"  {self.address_string()} {fmt % args}\n")


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--port", type=int, default=8000)
    args = p.parse_args()
    print(f"CX + HTMX demos on http://localhost:{args.port}/", file=sys.stderr)
    try:
        HTTPServer(("", args.port), Handler).serve_forever()
    except KeyboardInterrupt:
        print("\nshutting down", file=sys.stderr)


if __name__ == "__main__":
    main()
