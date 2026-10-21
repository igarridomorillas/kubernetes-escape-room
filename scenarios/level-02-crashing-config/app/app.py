"""order-processor: tiny stand-in for an order queue worker.

Reads DATABASE_URL from the environment, warms an in-memory cache and serves
/healthz on port 8080. No real database is contacted (the URL is only checked
for presence), and only the Python standard library is used.
"""
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

CACHE_MIB = 32
PORT = 8080


def load_config():
    """Return (database_url, error). Mirrors a hard lookup in os.environ."""
    try:
        return os.environ["DATABASE_URL"], None
    except KeyError as exc:
        return None, f"KeyError: {exc}"


def warm_cache(mib):
    """Allocate and touch `mib` MiB so the pages are really resident."""
    cache = bytearray(mib * 1024 * 1024)
    for i in range(0, len(cache), 4096):
        cache[i] = 1
    return cache


class Handler(BaseHTTPRequestHandler):
    database_url = None

    def do_GET(self):
        if self.path != "/healthz":
            self.send_error(404)
            return
        body = json.dumps({"status": "healthy", "database": "connected"}, separators=(",", ":"))
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body.encode())

    def log_message(self, fmt, *args):
        print(f"http: {fmt % args}", flush=True)


def main():
    print("order-processor: loading configuration", flush=True)
    database_url, error = load_config()
    if error:
        print(f"ERROR config: {error}", flush=True)

    print(f"order-processor: warming {CACHE_MIB}MiB order cache", flush=True)
    cache = warm_cache(CACHE_MIB)

    if error:
        print("FATAL: cannot start without database configuration", flush=True)
        sys.exit(1)

    Handler.database_url = database_url
    print(f"order-processor: cache ready ({len(cache)} bytes), listening on :{PORT}", flush=True)
    HTTPServer(("", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
