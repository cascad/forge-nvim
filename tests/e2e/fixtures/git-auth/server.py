"""Loopback fixture: synthetic Basic challenge + настоящий git http-backend.

CGI: https://git-scm.com/docs/git-http-backend. Только private origin.git.
"""
import argparse
import base64
import json
import os
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import urlsplit

# Только fixture данные, не пользовательский аккаунт или token.
USERNAME = "forge-fixture"
PASSWORD = "fixture-password-42"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--ready", type=Path, required=True)
    parser.add_argument("--audit", type=Path, required=True)
    args = parser.parse_args()
    expected = "Basic " + base64.b64encode(f"{USERNAME}:{PASSWORD}".encode()).decode()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def serve_git(self):
            url = urlsplit(self.path)
            if url.path not in ("/origin.git/info/refs", "/origin.git/git-receive-pack"):
                self.send_error(404)
                return
            authorization = self.headers.get("Authorization", "")
            authorized = authorization == expected
            record = {"method": self.command, "path": url.path,
                      "has_auth": bool(authorization), "authorized": authorized}
            if authorization.startswith("Basic "):
                decoded = base64.b64decode(authorization[6:]).decode("utf-8", errors="replace")
                name, _, password = decoded.partition(":")
                record.update(username_matches=name == USERNAME,
                              password_matches=password == PASSWORD,
                              password_length=len(password))
            if not authorized:
                record["status"] = 401
                self.send_response(401)
                self.send_header("WWW-Authenticate", 'Basic realm="Forge fixture"')
                self.send_header("Content-Length", "0")
                self.end_headers()
            else:
                body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
                env = dict(os.environ, GIT_PROJECT_ROOT=str(args.base.resolve()),
                           GIT_HTTP_EXPORT_ALL="1", REQUEST_METHOD=self.command,
                           PATH_INFO=url.path, QUERY_STRING=url.query,
                           CONTENT_TYPE=self.headers.get("Content-Type", ""),
                           CONTENT_LENGTH=str(len(body)), REMOTE_USER=USERNAME,
                           REMOTE_ADDR="127.0.0.1", AUTH_TYPE="Basic",
                           SERVER_NAME="127.0.0.1", SERVER_PORT=str(self.server.server_port),
                           SERVER_PROTOCOL=self.request_version,
                           HTTP_GIT_PROTOCOL=self.headers.get("Git-Protocol", ""))
                result = subprocess.run(["git", "http-backend"], input=body,
                                        capture_output=True, env=env, timeout=15)
                separator = b"\r\n\r\n" if b"\r\n\r\n" in result.stdout else b"\n\n"
                header, found, payload = result.stdout.partition(separator)
                if result.returncode or not found:
                    record["status"] = 500
                    record["backend_error"] = result.stderr.decode(errors="replace")
                    self.send_error(500, "Fixture Git backend failed")
                else:
                    status, headers = 200, []
                    for line in header.decode("latin1").splitlines():
                        key, value = line.split(":", 1)
                        if key.lower() == "status":
                            status = int(value.strip().split()[0])
                        else:
                            headers.append((key, value.strip()))
                    record["status"] = status
                    self.send_response(status)
                    for key, value in headers:
                        self.send_header(key, value)
                    self.send_header("Content-Length", str(len(payload)))
                    self.end_headers()
                    self.wfile.write(payload)
            # Authorization header/secret никогда не записываются.
            with args.audit.open("a", encoding="utf-8") as stream:
                stream.write(json.dumps(record) + "\n")

        do_GET = serve_git
        do_POST = serve_git

    with HTTPServer(("127.0.0.1", 0), Handler) as server:
        args.ready.write_text(json.dumps({"pid": os.getpid(),
                                         "url": f"http://127.0.0.1:{server.server_port}/origin.git"}),
                              encoding="utf-8")
        server.serve_forever()


if __name__ == "__main__":
    main()
