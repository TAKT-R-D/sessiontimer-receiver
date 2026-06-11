#!/usr/bin/env python3
"""SessionTimer clicker receiver — Python edition (no Hammerspoon, no pip install).

Official source: https://github.com/TAKT-R-D/sessiontimer-receiver
This file is the ONLY thing SessionTimer's clicker talks to on your computer.
Read it — it is short on purpose. Security model: see README.md.

What it does (and ALL it does):
    GET /next  →  presses the Right Arrow key (macOS key code 124)
    GET /prev  →  presses the Left Arrow key  (macOS key code 123)
Any other request gets "404 not found" and presses nothing.
No shell commands, no eval, no file reads/writes, no downloads, no auto-update.
Standard library only — nothing is installed.

The keystroke goes to the FRONTMOST app, so your slideshow (Keynote, PowerPoint,
Google Slides in a browser, a PDF…) must be the front window in presentation mode.

Setup:
    1. Grant your terminal app Accessibility (System Settings → Privacy & Security
       → Accessibility) so "System Events" may post keystrokes. macOS may also ask
       to allow Local Network access for the terminal on the first connection.
    2. Run:  python3 self-helper.py
Stop with Ctrl-C. Uninstall: delete this file. Nothing else was installed or written.
"""
from http.server import BaseHTTPRequestHandler, HTTPServer
import atexit
import socket
import subprocess

PORT = 8722

# Absolute paths to the two macOS built-in tools this script calls — never
# anything found via $PATH, never with a shell.
OSASCRIPT = "/usr/bin/osascript"
DNS_SD = "/usr/bin/dns-sd"

# The complete keystroke vocabulary. Fixed by design (1 click = 1 slide):
# nothing outside this table can ever be pressed.
KEY_CODES = {
    "/next": 124,  # right arrow
    "/prev": 123,  # left arrow
}


def press(key_code: int) -> None:
    """Post one arrow keystroke via System Events (requires Accessibility)."""
    subprocess.run(
        [OSASCRIPT, "-e", f'tell application "System Events" to key code {key_code}'],
        check=False,
    )


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):  # noqa: N802
        key_code = KEY_CODES.get(self.path)
        if key_code is None:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"not found")
            return
        press(key_code)
        print(f"  {self.path}")  # visible activity log — you see every click it receives
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, *args):  # silence the default per-request log line
        pass


def advertise_bonjour():
    """Advertise `_clicker._tcp` via the OS `dns-sd` tool so SessionTimer lists this
    computer by name — no IP typing. Best-effort: without it, manual IP still works."""
    name = f"Clicker on {socket.gethostname().split('.')[0]}"
    try:
        proc = subprocess.Popen(
            [DNS_SD, "-R", name, "_clicker._tcp", "local.", str(PORT)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        atexit.register(proc.terminate)
        print(f'Advertised on Bonjour as "{name}"')
    except FileNotFoundError:
        print("dns-sd not found — Bonjour advertisement skipped (manual IP still works).")


if __name__ == "__main__":
    advertise_bonjour()
    # Listens on every interface at PORT (your iPhone must be able to reach it over
    # your Wi-Fi). Runs only while this script runs; Ctrl-C stops everything.
    print(f"Clicker receiver listening on :{PORT}  (Ctrl-C to stop)")
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
