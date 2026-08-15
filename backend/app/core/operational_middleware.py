"""ASGI operational middleware for limits, headers, correlation, and logging."""

import json
import logging
from time import perf_counter
from typing import Any, cast

from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.core.observability import CORRELATION_HEADER, resolve_correlation_id

_CORRELATION_HEADER_BYTES = CORRELATION_HEADER.lower().encode("ascii")
_SECURITY_HEADERS = (
    (b"cache-control", b"no-store"),
    (b"permissions-policy", b"camera=(), geolocation=(), microphone=()"),
    (b"referrer-policy", b"no-referrer"),
    (b"x-content-type-options", b"nosniff"),
    (b"x-frame-options", b"DENY"),
)
_DEFAULT_CSP = b"default-src 'none'; frame-ancestors 'none'; base-uri 'none'"
_DEVELOPMENT_DOCS_CSP = (
    b"default-src 'none'; "
    b"style-src https://cdn.jsdelivr.net 'unsafe-inline'; "
    b"script-src https://cdn.jsdelivr.net; "
    b"img-src https://fastapi.tiangolo.com data:; "
    b"connect-src 'self'; frame-ancestors 'none'; base-uri 'none'"
)
_HSTS_HEADER = (b"strict-transport-security", b"max-age=31536000; includeSubDomains")


def request_correlation_id(scope: Scope) -> str:
    state = cast(dict[str, Any], scope.setdefault("state", {}))
    value = state.get("correlation_id")
    return str(value) if value is not None else str(resolve_correlation_id(None))


class RequestBodyLimitMiddleware:
    """Buffer at most one bounded body before routing it into the application."""

    def __init__(self, app: ASGIApp, *, maximum_bytes: int) -> None:
        self._app = app
        self._maximum_bytes = maximum_bytes

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self._app(scope, receive, send)
            return

        content_length = self._content_length(scope)
        if content_length is not None and content_length > self._maximum_bytes:
            await self._reject(scope, send)
            return

        messages: list[Message] = []
        total = 0
        while True:
            message = await receive()
            messages.append(message)
            if message["type"] == "http.disconnect":
                break
            if message["type"] != "http.request":
                continue
            total += len(message.get("body", b""))
            if total > self._maximum_bytes:
                await self._reject(scope, send)
                return
            if not message.get("more_body", False):
                break

        index = 0

        async def replay() -> Message:
            nonlocal index
            if index < len(messages):
                message = messages[index]
                index += 1
                return message
            return {"type": "http.disconnect"}

        await self._app(scope, replay, send)

    @staticmethod
    def _content_length(scope: Scope) -> int | None:
        for name, value in scope.get("headers", ()):
            if name.lower() != b"content-length":
                continue
            try:
                return int(value)
            except ValueError:
                return None
        return None

    @staticmethod
    async def _reject(scope: Scope, send: Send) -> None:
        payload = json.dumps(
            {
                "error": {
                    "code": "request_too_large",
                    "correlation_id": request_correlation_id(scope),
                }
            },
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
        await send(
            {
                "type": "http.response.start",
                "status": 413,
                "headers": [
                    (b"content-length", str(len(payload)).encode("ascii")),
                    (b"content-type", b"application/json"),
                ],
            }
        )
        await send({"type": "http.response.body", "body": payload})


class OperationalMiddleware:
    """Apply safe headers and emit one content-free request completion record."""

    def __init__(
        self,
        app: ASGIApp,
        *,
        logger: logging.Logger,
        production: bool,
    ) -> None:
        self._app = app
        self._logger = logger
        self._production = production

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self._app(scope, receive, send)
            return

        correlation_id = resolve_correlation_id(self._header(scope, CORRELATION_HEADER))
        state = cast(dict[str, Any], scope.setdefault("state", {}))
        state["correlation_id"] = correlation_id
        started_at = perf_counter()
        status_code = 500
        response_started = False

        async def send_with_headers(message: Message) -> None:
            nonlocal response_started, status_code
            if message["type"] == "http.response.start":
                response_started = True
                status_code = cast(int, message["status"])
                headers = list(message.get("headers", ()))
                names = {name.lower() for name, _ in headers}
                for name, value in _SECURITY_HEADERS:
                    if name not in names:
                        headers.append((name, value))
                if b"content-security-policy" not in names:
                    docs_path = scope.get("path") in {
                        "/docs",
                        "/docs/oauth2-redirect",
                    }
                    headers.append(
                        (
                            b"content-security-policy",
                            (
                                _DEVELOPMENT_DOCS_CSP
                                if docs_path and not self._production
                                else _DEFAULT_CSP
                            ),
                        )
                    )
                if self._production and _HSTS_HEADER[0] not in names:
                    headers.append(_HSTS_HEADER)
                headers = [
                    (name, value)
                    for name, value in headers
                    if name.lower() != _CORRELATION_HEADER_BYTES
                ]
                headers.append(
                    (
                        _CORRELATION_HEADER_BYTES,
                        str(correlation_id).encode("ascii"),
                    )
                )
                message["headers"] = headers
            await send(message)

        try:
            await self._app(scope, receive, send_with_headers)
        except Exception:
            if response_started:
                raise
            payload = json.dumps(
                {
                    "error": {
                        "code": "internal_server_error",
                        "correlation_id": str(correlation_id),
                    }
                },
                sort_keys=True,
                separators=(",", ":"),
            ).encode("utf-8")
            await send_with_headers(
                {
                    "type": "http.response.start",
                    "status": 500,
                    "headers": [
                        (b"content-length", str(len(payload)).encode("ascii")),
                        (b"content-type", b"application/json"),
                    ],
                }
            )
            await send_with_headers({"type": "http.response.body", "body": payload})
        finally:
            route = scope.get("route")
            route_path = getattr(route, "path", "unmatched")
            duration_ms = max(0, int((perf_counter() - started_at) * 1000))
            self._logger.info(
                "",
                extra={
                    "event": "request_completed",
                    "correlation_id": str(correlation_id),
                    "method": scope.get("method", "UNKNOWN"),
                    "route": route_path,
                    "status_code": status_code,
                    "duration_ms": duration_ms,
                },
            )

    @staticmethod
    def _header(scope: Scope, requested_name: str) -> str | None:
        requested = requested_name.lower().encode("ascii")
        for name, value in scope.get("headers", ()):
            if name.lower() == requested:
                return cast(bytes, value).decode("ascii", errors="ignore")
        return None
