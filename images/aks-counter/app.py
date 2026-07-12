from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse


APP_HOST = "0.0.0.0"
APP_PORT = 8080
COUNTER_FILE = Path("/data/counter.txt")


def read_counter() -> int:
    if not COUNTER_FILE.exists():
        return 0

    try:
        return int(COUNTER_FILE.read_text(encoding="utf-8").strip())
    except ValueError:
        return 0


def write_counter(value: int) -> None:
    COUNTER_FILE.parent.mkdir(parents=True, exist_ok=True)
    COUNTER_FILE.write_text(f"{value}\n", encoding="utf-8")


def increment_counter() -> int:
    value = read_counter() + 1
    write_counter(value)
    return value


def render_page(counter_value: int) -> bytes:
    html = f"""<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Caso Practico 2 - App AKS Counter</title>
  <style>
    body {{
      margin: 0;
      font-family: Arial, Helvetica, sans-serif;
      background: #f5f7fa;
      color: #1f2933;
    }}
    main {{
      max-width: 760px;
      margin: 48px auto;
      padding: 32px;
      background: #ffffff;
      border: 1px solid #d9e2ec;
      border-radius: 8px;
    }}
    h1 {{
      margin: 0 0 8px;
      font-size: 32px;
    }}
    dl {{
      display: grid;
      grid-template-columns: 180px 1fr;
      gap: 12px 20px;
      margin: 28px 0 0;
    }}
    dt {{
      font-weight: 700;
      color: #52606d;
    }}
    dd {{
      margin: 0;
    }}
    .counter {{
      font-size: 48px;
      font-weight: 700;
      color: #0f766e;
    }}
    code {{
      background: #edf2f7;
      padding: 2px 6px;
      border-radius: 4px;
    }}
  </style>
</head>
<body>
  <main>
    <h1>Caso Practico 2</h1>
    <p>App AKS Counter</p>
    <div class="counter">{counter_value}</div>
    <dl>
      <dt>Imagen</dt>
      <dd><code>aks-counter</code></dd>
      <dt>Tag</dt>
      <dd><code>casopractico2</code></dd>
      <dt>Puerto</dt>
      <dd><code>8080 HTTP</code></dd>
      <dt>Persistencia</dt>
      <dd><code>/data/counter.txt</code></dd>
    </dl>
  </main>
</body>
</html>
"""
    return html.encode("utf-8")


class CounterHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        path = urlparse(self.path).path

        if path == "/healthz":
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.end_headers()
            self.wfile.write(b"ok\n")
            return

        if path != "/":
            self.send_error(HTTPStatus.NOT_FOUND)
            return

        counter_value = increment_counter()
        body = render_page(counter_value)

        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:
        print(f"{self.address_string()} - {format % args}", flush=True)


def main() -> None:
    COUNTER_FILE.parent.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer((APP_HOST, APP_PORT), CounterHandler)
    print(f"aks-counter listening on {APP_HOST}:{APP_PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
