from __future__ import annotations

import mimetypes
import os
import posixpath
from pathlib import Path
from urllib.parse import unquote

mimetypes.add_type("application/javascript", ".js")
mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/json", ".json")
mimetypes.add_type("image/png", ".png")

STATIC_ROOT = Path(os.environ.get("KTMS_STATIC_ROOT", "/web")).resolve()
INDEX_FILE = STATIC_ROOT / "index.html"
BLOCKED_SEGMENTS = {
    "__pycache__",
    "app",
    ".cache",
    ".local",
    ".redis",
    ".vim",
}


class StaticFlutterApp:
    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self._send_text(send, 404, "Not found")
            return

        method = scope.get("method", "GET").upper()
        if method not in {"GET", "HEAD"}:
            await self._send_text(send, 405, "Method not allowed")
            return

        try:
            target = self._resolve_path(scope.get("path", "/"))
            if target is None or not target.exists() or not target.is_file():
                await self._send_text(send, 404, "Not found")
                return

            content_type = mimetypes.guess_type(str(target))[0] or "application/octet-stream"
            body = b"" if method == "HEAD" else target.read_bytes()
            headers = [
                (b"content-type", content_type.encode("ascii")),
                (b"cache-control", self._cache_control(target).encode("ascii")),
            ]
            if method == "HEAD":
                headers.append((b"content-length", str(target.stat().st_size).encode("ascii")))
            else:
                headers.append((b"content-length", str(len(body)).encode("ascii")))

            await send(
                {
                    "type": "http.response.start",
                    "status": 200,
                    "headers": headers,
                }
            )
            await send({"type": "http.response.body", "body": body})
        except Exception:
            await self._send_text(send, 500, "Internal server error")

    def _resolve_path(self, raw_path: str) -> Path | None:
        decoded_path = unquote(raw_path.split("?", 1)[0])
        normalized = posixpath.normpath(decoded_path).lstrip("/")

        if normalized in {"", "."}:
            return INDEX_FILE

        segments = [segment for segment in normalized.split("/") if segment]
        if any(segment.startswith(".") or segment in BLOCKED_SEGMENTS for segment in segments):
            return None

        target = (STATIC_ROOT / normalized).resolve()
        if STATIC_ROOT not in target.parents and target != STATIC_ROOT:
            return None

        if target.is_dir():
            return target / "index.html"

        if target.exists():
            return target

        if Path(normalized).suffix:
            return None

        return INDEX_FILE

    def _cache_control(self, target: Path) -> str:
        if target.name in {"index.html", "flutter_service_worker.js"}:
            return "no-cache"
        return "public, max-age=3600"

    async def _send_text(self, send, status: int, text: str):
        body = text.encode("utf-8")
        await send(
            {
                "type": "http.response.start",
                "status": status,
                "headers": [
                    (b"content-type", b"text/plain; charset=utf-8"),
                    (b"content-length", str(len(body)).encode("ascii")),
                ],
            }
        )
        await send({"type": "http.response.body", "body": body})


app = StaticFlutterApp()
