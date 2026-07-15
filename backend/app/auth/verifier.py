"""Replaceable authentication-token verification implementations."""

from dataclasses import dataclass
from hmac import compare_digest
from typing import Protocol

from app.core.config import Settings


class AuthenticationError(Exception):
    """Raised when an authentication token cannot be trusted."""


@dataclass(frozen=True, slots=True)
class AuthClaims:
    """Minimal identity claims accepted by the application."""

    subject: str
    email: str | None = None
    display_name: str | None = None


class AuthenticationVerifier(Protocol):
    """Provider-neutral token verification contract."""

    async def verify(self, token: str) -> AuthClaims:
        """Verify a token and return trusted provider claims."""
        ...


class DevelopmentAuthenticationVerifier:
    """Single-token verifier restricted to local and test environments."""

    def __init__(self, settings: Settings) -> None:
        self._token = settings.development_auth_token
        self._claims = AuthClaims(
            subject=settings.development_auth_subject,
            email=settings.development_auth_email or None,
        )

    async def verify(self, token: str) -> AuthClaims:
        if not self._token or not compare_digest(token, self._token):
            raise AuthenticationError("Invalid authentication token")
        return self._claims


class StaticAuthenticationVerifier:
    """Deterministic injected verifier for integration tests and previews."""

    def __init__(self, identities: dict[str, AuthClaims]) -> None:
        self._identities = identities

    async def verify(self, token: str) -> AuthClaims:
        claims = self._identities.get(token)
        if claims is None:
            raise AuthenticationError("Invalid authentication token")
        return claims


class UnavailableAuthenticationVerifier:
    """Fail-closed placeholder until a production provider adapter is configured."""

    async def verify(self, token: str) -> AuthClaims:
        del token
        raise AuthenticationError("Authentication provider is unavailable")


def build_authentication_verifier(settings: Settings) -> AuthenticationVerifier:
    """Select the local verifier only for explicitly non-production environments."""
    if settings.app_environment in {"local", "test"}:
        return DevelopmentAuthenticationVerifier(settings)
    return UnavailableAuthenticationVerifier()
