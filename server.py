import http.server, subprocess, hashlib, os, json
TH = os.environ["TH"]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def ok(self):
        t = self.headers.get("X-T", "")
        if hashlib.sha256(t.encode()).hexdigest() != TH:
            self.send_response(403); self.end_headers(); return False
        return True
    def send(self, body, ctype="application/json"):
        self.send_response(200); self.send_header("content-type", ctype); self.send_header("content-length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def do_GET(self):
        if not self.ok(): return
        if self.path.startswith("/shot"):
            p = subprocess.run(["adb", "exec-out", "screencap", "-p"], capture_output=True, timeout=40)
            self.send(p.stdout, "image/png")
        else:
            self.send(b'{"ok":true}')
    def do_POST(self):
        if not self.ok(): return
        n = int(self.headers.get("content-length", 0)); b = json.loads(self.rfile.read(n))
        try:
            p = subprocess.run(["bash", "-c", b["cmd"]], stdin=subprocess.DEVNULL, capture_output=True, timeout=b.get("timeout", 80))
            out = {"rc": p.returncode, "out": p.stdout.decode(errors="replace")[-30000:], "err": p.stderr.decode(errors="replace")[-6000:]}
        except subprocess.TimeoutExpired:
            out = {"rc": -9, "out": "timeout"}
        self.send(json.dumps(out).encode())
http.server.ThreadingHTTPServer(("127.0.0.1", 8077), H).serve_forever()
