#!/usr/bin/env python3
"""Capability-table drift check for tooling/lsp/README.md (#423).

Drives a live `cx lsp` initialize over stdio, extracts the advertised
`capabilities` object, and diffs it against EXPECTED — the exact set the
README capability table documents. Also probes textDocument/codeAction
and textDocument/inlayHint on an open document to verify the documented
"advertised, returns a well-formed empty list" status.

Usage: python3 check_capabilities.py [/path/to/cx]   (default: cx on $PATH)
Exit 0 when server and README agree; 1 on drift.
"""
import json
import subprocess
import sys
import threading
import time

# The capability keys tooling/lsp/README.md documents, and the shape we
# expect each to advertise. A key here that the server stops advertising,
# or a server key missing here, is README drift — fix the table.
EXPECTED = {
    "textDocumentSync": "present",          # full-document sync
    "hoverProvider": True,
    "completionProvider": "present",        # {triggerCharacters: ["[", "?", "@", ":", "/"]}
    "definitionProvider": True,
    "documentFormattingProvider": True,
    "semanticTokensProvider": "present",
    "documentSymbolProvider": True,
    "foldingRangeProvider": True,
    "selectionRangeProvider": True,
    "referencesProvider": True,
    "renameProvider": "present",            # {prepareProvider: true}
    "codeActionProvider": True,             # advertised; handler returns [] (recipes pending)
    "codeLensProvider": "present",          # {resolveProvider: false}
    "inlayHintProvider": True,              # advertised; handler returns [] (hints pending)
    "signatureHelpProvider": "present",
}


def frame(payload):
    body = json.dumps(payload).encode("utf-8")
    return f"Content-Length: {len(body)}\r\n\r\n".encode("utf-8") + body


def read_messages(stream, sink):
    while True:
        line = stream.readline()
        if not line:
            return
        if not line.startswith(b"Content-Length:"):
            continue
        length = int(line.split(b":", 1)[1].strip())
        while True:
            sep = stream.readline()
            if sep in (b"\r\n", b"\n") or not sep:
                break
        body = stream.read(length)
        try:
            sink.append(json.loads(body.decode("utf-8")))
        except Exception:
            continue


def main():
    cx = sys.argv[1] if len(sys.argv) > 1 else "cx"
    proc = subprocess.Popen([cx, "lsp"], stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    msgs = []
    threading.Thread(target=read_messages, args=(proc.stdout, msgs), daemon=True).start()

    proc.stdin.write(frame({"jsonrpc": "2.0", "id": 1, "method": "initialize",
                            "params": {"processId": None, "rootUri": None, "capabilities": {}}}))
    proc.stdin.write(frame({"jsonrpc": "2.0", "method": "initialized", "params": {}}))
    uri = "file:///tmp/check_capabilities_probe.cx"
    doc = "[report [item a] [item b]]\n"
    proc.stdin.write(frame({"jsonrpc": "2.0", "method": "textDocument/didOpen",
                            "params": {"textDocument": {"uri": uri, "languageId": "cx",
                                                        "version": 1, "text": doc}}}))
    rng = {"start": {"line": 0, "character": 0}, "end": {"line": 0, "character": 5}}
    proc.stdin.write(frame({"jsonrpc": "2.0", "id": 2, "method": "textDocument/codeAction",
                            "params": {"textDocument": {"uri": uri}, "range": rng,
                                       "context": {"diagnostics": []}}}))
    proc.stdin.write(frame({"jsonrpc": "2.0", "id": 3, "method": "textDocument/inlayHint",
                            "params": {"textDocument": {"uri": uri}, "range": rng}}))
    proc.stdin.flush()
    time.sleep(0.6)
    proc.stdin.write(frame({"jsonrpc": "2.0", "id": 99, "method": "shutdown", "params": None}))
    proc.stdin.write(frame({"jsonrpc": "2.0", "method": "exit"}))
    proc.stdin.flush()
    proc.wait(timeout=5)

    init = next((m for m in msgs if m.get("id") == 1), None)
    if not init or "result" not in init:
        print("FAIL: no initialize response"); return 1
    caps = init["result"].get("capabilities", {})

    failures = 0
    for key, want in EXPECTED.items():
        if key not in caps:
            print(f"DRIFT: README documents '{key}' but the server does not advertise it")
            failures += 1
        elif want is True and caps[key] is not True:
            print(f"DRIFT: '{key}' advertised as {caps[key]!r}, README documents true")
            failures += 1
    for key in caps:
        if key not in EXPECTED:
            print(f"DRIFT: server advertises '{key}' but the README table omits it")
            failures += 1

    # Documented stub statuses: codeAction + inlayHint return well-formed [].
    for rid, name in ((2, "codeAction"), (3, "inlayHint")):
        resp = next((m for m in msgs if m.get("id") == rid), None)
        if resp is None:
            print(f"DRIFT: no response to textDocument/{name} request")
            failures += 1
        elif resp.get("result") != []:
            print(f"DRIFT: textDocument/{name} returned {resp.get('result')!r} — README documents a well-formed empty list; update the table")
            failures += 1

    if failures:
        print(f"FAIL: {failures} capability drift finding(s)")
        print("advertised capabilities:", json.dumps(caps, indent=2, sort_keys=True))
        return 1
    print(f"OK: server advertises exactly the {len(EXPECTED)} capabilities the README documents; "
          "codeAction + inlayHint return well-formed empty lists as documented")
    return 0


if __name__ == "__main__":
    sys.exit(main())
