#!/usr/bin/env python3
"""Relay for the guided web walkthrough panel.

The panel POSTs each viewer event (Next, Previous, a typed message) here; the relay
prints it as one JSON line on stdout. Run it under the Monitor tool so every line
reaches the agent the moment the viewer acts. It also serves the panel itself at
/guide-panel.js, so a page can load (or reload) it with one fetch.

Usage: guide-relay.py [port]   (default 47610; binds 127.0.0.1 only)
"""

import json
import signal
import sys
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MAX_BODY = 16 * 1024
PANEL = Path(__file__).with_name("guide-panel.js")


class Relay(BaseHTTPRequestHandler):
    def _cors(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        # Chrome's Private Network Access preflight for pages calling localhost.
        self.send_header("Access-Control-Allow-Private-Network", "true")

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self) -> None:
        if self.path.split("?")[0] == "/guide-panel.js":
            body = PANEL.read_bytes()
            self.send_response(200)
            self._cors()
            self.send_header("Content-Type", "text/javascript; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_response(200 if self.path == "/health" else 404)
        self._cors()
        self.end_headers()

    def do_POST(self) -> None:
        length = min(int(self.headers.get("Content-Length") or 0), MAX_BODY)
        raw = self.rfile.read(length)
        try:
            event = json.loads(raw)
            line = json.dumps(event if isinstance(event, dict) else {"type": "unknown"})
        except ValueError:
            line = json.dumps({"type": "unparseable"})
        print(line, flush=True)
        self.send_response(204)
        self._cors()
        self.end_headers()

    def log_message(self, format: str, *args: object) -> None:  # noqa: A002 (base signature)
        """Keep stdout to one line per event: request logging is dropped."""
        del format, args


def main() -> None:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 47610
    server = ThreadingHTTPServer(("127.0.0.1", port), Relay)

    def stop(signum: int, frame: object) -> None:
        del signum, frame
        server.server_close()
        sys.exit(0)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    print(json.dumps({"type": "relay-ready", "port": port}), flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
