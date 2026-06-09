#!/usr/bin/env python3
"""Probe `cx lsp` for diagnostics on a source file via LSP stdio."""
import json
import subprocess
import sys
import threading


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
        # consume blank line
        while True:
            sep = stream.readline()
            if sep in (b"\r\n", b"\n"):
                break
            if not sep:
                return
        body = stream.read(length)
        try:
            msg = json.loads(body.decode("utf-8"))
        except Exception:
            continue
        sink.append(msg)


def run(cx_path, source_path):
    with open(source_path, "r") as f:
        source = f.read()
    proc = subprocess.Popen(
        [cx_path, "lsp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    msgs = []
    t = threading.Thread(target=read_messages, args=(proc.stdout, msgs), daemon=True)
    t.start()

    # initialize
    proc.stdin.write(frame({
        "jsonrpc": "2.0", "id": 1, "method": "initialize",
        "params": {"processId": None, "rootUri": None, "capabilities": {}}
    }))
    proc.stdin.write(frame({"jsonrpc": "2.0", "method": "initialized", "params": {}}))

    uri = "file://" + source_path
    proc.stdin.write(frame({
        "jsonrpc": "2.0", "method": "textDocument/didOpen",
        "params": {"textDocument": {"uri": uri, "languageId": "cx", "version": 1, "text": source}}
    }))
    proc.stdin.flush()

    # wait for diagnostics
    import time
    time.sleep(0.5)

    proc.stdin.write(frame({"jsonrpc": "2.0", "id": 99, "method": "shutdown", "params": None}))
    proc.stdin.write(frame({"jsonrpc": "2.0", "method": "exit"}))
    proc.stdin.flush()
    proc.wait(timeout=3)

    diags = []
    for m in msgs:
        if m.get("method") == "textDocument/publishDiagnostics":
            diags.extend(m["params"]["diagnostics"])
    return diags


def hover(cx_path, source_path, line, character):
    with open(source_path, "r") as f:
        source = f.read()
    proc = subprocess.Popen(
        [cx_path, "lsp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    msgs = []
    t = threading.Thread(target=read_messages, args=(proc.stdout, msgs), daemon=True)
    t.start()
    proc.stdin.write(frame({
        "jsonrpc": "2.0", "id": 1, "method": "initialize",
        "params": {"processId": None, "rootUri": None, "capabilities": {}}
    }))
    proc.stdin.write(frame({"jsonrpc": "2.0", "method": "initialized", "params": {}}))
    uri = "file://" + source_path
    proc.stdin.write(frame({
        "jsonrpc": "2.0", "method": "textDocument/didOpen",
        "params": {"textDocument": {"uri": uri, "languageId": "cx", "version": 1, "text": source}}
    }))
    proc.stdin.write(frame({
        "jsonrpc": "2.0", "id": 50, "method": "textDocument/hover",
        "params": {"textDocument": {"uri": uri}, "position": {"line": line, "character": character}}
    }))
    proc.stdin.flush()
    import time
    time.sleep(0.5)
    proc.stdin.write(frame({"jsonrpc": "2.0", "id": 99, "method": "shutdown", "params": None}))
    proc.stdin.write(frame({"jsonrpc": "2.0", "method": "exit"}))
    proc.stdin.flush()
    proc.wait(timeout=3)
    for m in msgs:
        if m.get("id") == 50:
            return m.get("result")
    return None


def completion(cx_path, source_path, line, character):
    with open(source_path, "r") as f:
        source = f.read()
    proc = subprocess.Popen(
        [cx_path, "lsp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    msgs = []
    t = threading.Thread(target=read_messages, args=(proc.stdout, msgs), daemon=True)
    t.start()
    proc.stdin.write(frame({
        "jsonrpc": "2.0", "id": 1, "method": "initialize",
        "params": {"processId": None, "rootUri": None, "capabilities": {}}
    }))
    proc.stdin.write(frame({"jsonrpc": "2.0", "method": "initialized", "params": {}}))
    uri = "file://" + source_path
    proc.stdin.write(frame({
        "jsonrpc": "2.0", "method": "textDocument/didOpen",
        "params": {"textDocument": {"uri": uri, "languageId": "cx", "version": 1, "text": source}}
    }))
    proc.stdin.write(frame({
        "jsonrpc": "2.0", "id": 60, "method": "textDocument/completion",
        "params": {"textDocument": {"uri": uri}, "position": {"line": line, "character": character}}
    }))
    proc.stdin.flush()
    import time
    time.sleep(0.5)
    proc.stdin.write(frame({"jsonrpc": "2.0", "id": 99, "method": "shutdown", "params": None}))
    proc.stdin.write(frame({"jsonrpc": "2.0", "method": "exit"}))
    proc.stdin.flush()
    proc.wait(timeout=3)
    for m in msgs:
        if m.get("id") == 60:
            return m.get("result")
    return None


if __name__ == "__main__":
    cx = sys.argv[1]
    op = sys.argv[2]
    if op == "diag":
        path = sys.argv[3]
        print(json.dumps(run(cx, path), indent=2))
    elif op == "hover":
        path = sys.argv[3]
        line = int(sys.argv[4])
        col = int(sys.argv[5])
        print(json.dumps(hover(cx, path, line, col), indent=2))
    elif op == "completion":
        path = sys.argv[3]
        line = int(sys.argv[4])
        col = int(sys.argv[5])
        print(json.dumps(completion(cx, path, line, col), indent=2))
