#!/usr/bin/env python3
"""edit-server.py — a tiny localhost-only bridge so the browser register
editor can read and write ONE file directly, for scripts/review.sh.

It serves web/editor.html and exposes exactly three endpoints:
  GET  /load    -> the current contents of the file being edited
  POST /save    -> overwrite that file with the request body, then exit 0
  POST /cancel  -> change nothing, then exit 2

It binds to 127.0.0.1 only: nothing is reachable from the network, and
nothing is sent anywhere. review.sh starts it against a plaintext file in
a private temp dir, opens your browser, waits for you to Save (or Cancel),
then re-encrypts. This is owner-side tooling (Python is fine here); the
executor recovery path never uses it.

Usage:  edit-server.py TARGET_FILE [--port N] [--open]
Exit codes: 0 = saved, 2 = cancelled, 1 = error/timeout.
"""

import http.server
import os
import sys
import threading
import webbrowser

HERE = os.path.dirname(os.path.abspath(__file__))
EDITOR_HTML = os.path.join(HERE, "editor.html")
IDLE_TIMEOUT = 3600  # give up after an hour untouched


def main() -> int:
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        sys.stderr.write(__doc__)
        return 1
    target = os.path.abspath(args[0])
    port = 8765
    do_open = False
    i = 1
    while i < len(args):
        if args[i] == "--port" and i + 1 < len(args):
            port = int(args[i + 1]); i += 2
        elif args[i] == "--open":
            do_open = True; i += 1
        else:
            i += 1

    if not os.path.isfile(EDITOR_HTML):
        sys.stderr.write(f"error: editor not found at {EDITOR_HTML}\n")
        return 1

    state = {"result": None}

    class Handler(http.server.BaseHTTPRequestHandler):
        def _send(self, code, body=b"", ctype="text/plain; charset=utf-8"):
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if body:
                self.wfile.write(body)

        def do_GET(self):
            if self.path in ("/", "/index.html", "/editor.html"):
                with open(EDITOR_HTML, "rb") as f:
                    self._send(200, f.read(), "text/html; charset=utf-8")
            elif self.path == "/load":
                data = b""
                if os.path.isfile(target):
                    with open(target, "rb") as f:
                        data = f.read()
                self._send(200, data)
            else:
                self._send(404, b"not found")

        def do_POST(self):
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length) if length else b""
            if self.path == "/save":
                try:
                    tmp = target + ".tmp"
                    with open(tmp, "wb") as f:
                        f.write(body)
                    os.replace(tmp, target)
                except OSError as e:
                    self._send(500, str(e).encode()); return
                self._send(200, b"saved")
                state["result"] = "saved"
                threading.Thread(target=httpd.shutdown, daemon=True).start()
            elif self.path == "/cancel":
                self._send(200, b"cancelled")
                state["result"] = "cancel"
                threading.Thread(target=httpd.shutdown, daemon=True).start()
            else:
                self._send(404, b"not found")

        def log_message(self, *a):
            pass  # keep the terminal quiet

    # 127.0.0.1 only. If the port is taken, walk upward a few slots.
    httpd = None
    for p in range(port, port + 20):
        try:
            httpd = http.server.HTTPServer(("127.0.0.1", p), Handler)
            port = p
            break
        except OSError:
            continue
    if httpd is None:
        sys.stderr.write("error: could not bind a local port.\n")
        return 1

    port = httpd.server_address[1]  # the actual bound port (handles --port 0)
    url = f"http://127.0.0.1:{port}/"
    sys.stderr.write(f"Register editor ready at {url}\n")
    sys.stderr.flush()
    if do_open:
        t = threading.Timer(0.4, lambda: webbrowser.open(url))
        t.daemon = True
        t.start()

    # Idle safety net so a forgotten tab can't hang review.sh forever.
    def bail():
        if state["result"] is None:
            state["result"] = "timeout"
            httpd.shutdown()
    idle = threading.Timer(IDLE_TIMEOUT, bail)
    idle.daemon = True  # must not keep the process alive after a save
    idle.start()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        state["result"] = "cancel"
    finally:
        idle.cancel()
        httpd.server_close()

    return {"saved": 0, "cancel": 2, "timeout": 1}.get(state["result"], 1)


if __name__ == "__main__":
    # Unbuffered stderr so review.sh sees the ready line immediately.
    try:
        sys.exit(main())
    except BrokenPipeError:
        sys.exit(1)
