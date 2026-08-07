"""Replaceable authentication-token verification implementations."""

import asyncio
from collections.abc import Mapping
from datetime import UTC, datetime
from hmac import compare_digest
from typing import Protocol, cast

import jwt
from jwt import PyJWKClient

from app.auth.contracts import (
    LOCAL_AUTH_AUDIENCE,
    LOCAL_AUTH_ISSUER,
    AuthClaims,
)
from app.auth.policy import ProductionVerifierPolicy, ProductionVerifierPolicyError
from app.core.config import Settings


class AuthenticationError(Exception):
    """Raised when an authentication token cannot be trusted."""

    def __init__(self, code: str = "authentication_failed") -> None:
        self.code = code
        super().__init__(code)


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
            issuer=LOCAL_AUTH_ISSUER,
            audiences=(LOCAL_AUTH_AUDIENCE,),
            email=settings.development_auth_email or None,
            email_verified=bool(settings.development_auth_email),
        )
        self._claims.validate_structure()

    async def verify(self, token: str) -> AuthClaims:
        if not self._token or not compare_digest(token, self._token):
            raise AuthenticationError("authentication_failed")
        return self._claims


class StaticAuthenticationVerifier:
    """Deterministic injected verifier for integration tests and previews."""

    def __init__(self, identities: dict[str, AuthClaims]) -> None:
        self._identities = identities

    async def verify(self, token: str) -> AuthClaims:
        claims = self._identities.get(token)
        if claims is None:
            raise AuthenticationError("authentication_failed")
        claims.validate_structure()
        return claims


class ProductionTokenDecoder(Protocol):
    """Synchronous cryptographic decoder isolated for deterministic tests."""

    def decode(self, token: str) -> Mapping[str, object]:
        """Verify and decode one provider token or raise a safe failure."""
        ...


class PyJWTProductionTokenDecoder:
    """Resolve a JWKS key and verify signature plus required OIDC claims."""

    def __init__(self, policy: ProductionVerifierPolicy) -> None:
        self._policy = policy
        self._jwks = PyJWKClient(
            policy.jwks_url,
            cache_keys=True,
            lifespan=300,
            timeout=5,
        )

    def decode(self, token: str) -> Mapping[str, object]:
        try:
            header = jwt.get_unverified_header(token)
            algorithm = header.get("alg")
            key_id = header.get("kid")
            if (
                not isinstance(algorithm, str)
                or algorithm not in self._policy.allowed_algorithms
                or not isinstance(key_id, str)
                or not key_id
                or len(key_id) > 128
                or any(ord(character) < 32 for character in key_id)
            ):
                raise AuthenticationError("authentication_failed")
            signing_key = self._jwks.get_signing_key_from_jwt(token)
            if signing_key.algorithm_name != algorithm:
                raise AuthenticationError("authentication_failed")
            payload = jwt.decode(
                token,
                key=signing_key.key,
                algorithms=[algorithm],
                audience=self._policy.audience,
                issuer=self._policy.issuer,
                leeway=self._policy.clock_skew_seconds,
                options={"require": ["sub", "iss", "aud", "iat", "exp"]},
            )
        except AuthenticationError:
            raise
        except Exception as error:
            raise AuthenticationError("authentication_failed") from error
        return cast(Mapping[str, object], payload)


class ProductionAuthenticationVerifier:
    """Strict asymmetric OIDC/JWKS verifier with minimal trusted claims."""

    def __init__(
        self,
        policy: ProductionVerifierPolicy,
        *,
        decoder: ProductionTokenDecoder | None = None,
    ) -> None:
        policy.validate_configuration()
        self.policy = policy
        self._decoder = decoder or PyJWTProductionTokenDecoder(policy)

    async def verify(self, token: str) -> AuthClaims:
        try:
            payload = await asyncio.to_thread(self._decoder.decode, token)
            claims = _claims_from_payload(payload)
            self.policy.validate_claims(claims)
            return claims
        except AuthenticationError:
            raise
        except (ProductionVerifierPolicyError, ValueError, TypeError) as error:
            raise AuthenticationError("authentication_failed") from error


class UnavailableAuthenticationVerifier:
    """Fail-closed placeholder for any unsupported verifier configuration."""

    async def verify(self, token: str) -> AuthClaims:
        del token
        raise AuthenticationError("authentication_unavailable")


def build_authentication_verifier(settings: Settings) -> AuthenticationVerifier:
    """Select only an explicitly allowed verifier for the current environment."""
    if (
        settings.app_environment in {"local", "test"}
        and settings.authentication_verifier_mode == "development"
    ):
        return DevelopmentAuthenticationVerifier(settings)
    if settings.authentication_verifier_mode == "production_contract":
        policy = ProductionVerifierPolicy(
            issuer=settings.authentication_issuer,
            audience=settings.authentication_audience,
            jwks_url=settings.authentication_jwks_url,
            allowed_algorithms=settings.authentication_allowed_algorithms,
            clock_skew_seconds=settings.authentication_clock_skew_seconds,
            maximum_token_lifetime_seconds=(settings.authentication_maximum_token_lifetime_seconds),
        )
        return ProductionAuthenticationVerifier(policy)
    return UnavailableAuthenticationVerifier()


def _claims_from_payload(payload: Mapping[str, object]) -> AuthClaims:
    subject = _required_string_claim(payload, "sub")
    issuer = _required_string_claim(payload, "iss")
    audience_value = payload.get("aud")
    audiences: tuple[str, ...]
    if isinstance(audience_value, str):
        audiences = (audience_value,)
    elif (
        isinstance(audience_value, list)
        and audience_value
        and all(isinstance(item, str) for item in audience_value)
    ):
        audiences = tuple(cast(list[str], audience_value))
    else:
        raise AuthenticationError("authentication_failed")
    email_value = payload.get("email")
    name_value = payload.get("name")
    email = email_value if isinstance(email_value, str) else None
    display_name = name_value if isinstance(name_value, str) else None
    return AuthClaims(
        subject=subject,
        issuer=issuer,
        audiences=audiences,
        email=email,
        email_verified=payload.get("email_verified") is True,
        display_name=display_name,
        issued_at=_required_numeric_date(payload, "iat"),
        expires_at=_required_numeric_date(payload, "exp"),
    )


def _required_string_claim(payload: Mapping[str, object], key: str) -> str:
    value = payload.get(key)
    if not isinstance(value, str):
        raise AuthenticationError("authentication_failed")
    return value


def _required_numeric_date(payload: Mapping[str, object], key: str) -> datetime:
    value = payload.get(key)
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise AuthenticationError("authentication_failed")
    try:
        return datetime.fromtimestamp(value, UTC)
    except (OverflowError, OSError, ValueError) as error:
        raise AuthenticationError("authentication_failed") from error
