#!/usr/bin/env python3
"""Fast Codespaces preview server for Godot 4 Web exports.

Serves precompressed WASM/PCK/JS assets (created by run_port.sh),
sets WebAssembly MIME correctly, and disables caching during development.
"""
import functools
import os
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class GodotHandler(SimpleHTTPRequestHandler):
    def guess_type(self, path):
        if path.endswith(".wasm"):
            return "application/wasm"
        if path.endswith(".pck"):
            return "application/octet-stream"
        return super().guess_type(path)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, must-revalidate")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

    def send_head(self):
        requested = self.translate_path(self.path)
        compressed = requested + ".gz"
        accepts_gzip = "gzip" in self.headers.get("Accept-Encoding", "").lower()
        if (
            accepts_gzip
            and os.path.isfile(requested)
            and requested.endswith((".wasm", ".pck", ".js"))
            and os.path.isfile(compressed)
        ):
            try:
                handle = open(compressed, "rb")
            except OSError:
                return super().send_head()

            self.send_response(200)
            self.send_header("Content-Type", self.guess_type(requested))
            self.send_header("Content-Encoding", "gzip")
            self.send_header("Vary", "Accept-Encoding")
            self.send_header("Content-Length", str(os.fstat(handle.fileno()).st_size))
            self.end_headers()
            return handle
        return super().send_head()

    def copyfile(self, source, outputfile):
        try:
            super().copyfile(source, outputfile)
        except (BrokenPipeError, ConnectionResetError):
            # A cancelled browser request is not a game server crash.
            pass


def main():
    directory = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "build/web")
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8080
    if not os.path.isfile(os.path.join(directory, "index.html")):
        raise SystemExit("Missing Godot web export: " + directory + "/index.html")
    handler = functools.partial(GodotHandler, directory=directory)
    server = ThreadingHTTPServer(("0.0.0.0", port), handler)
    print(f"Happy Farm browser preview: http://localhost:{port}", flush=True)
    print("Using gzip-compressed WebAssembly for faster Codespaces loading.", flush=True)
    try:
        server.serve_forever(poll_interval=0.3)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
