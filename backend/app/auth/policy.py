"""Fail-closed policy for a future production authentication adapter."""

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from urllib.parse import urlsplit

from app.auth.contracts import AuthClaims, AuthClaimValidationError

SUPPORTED_ASYMMETRIC_ALGORITHMS = frozenset({"ES256", "RS256"})
MAX_CLOCK_SKEW_SECONDS = 300
MAX_TOKEN_LIFETIME_SECONDS = 24 * 60 * 60


class ProductionVerifierPolicyError(ValueError):
    """Content-free production-verifier policy failure."""

    def __init__(self, code: str) -> None:
        self.code = code
        super().__init__(code)


def _secure_metadata_url(value: str) -> bool:
    try:
        parsed = urlsplit(value)
        _ = parsed.port
    except ValueError:
        return False
    return (
        parsed.scheme == "https"
        and bool(parsed.hostname)
        and not parsed.username
        and not parsed.password
        and not parsed.query
        and not parsed.fragment
    )


@dataclass(frozen=True, slots=True)
class ProductionVerifierPolicy:
    """Exact issuer, audience, key, algorithm, and time validation policy."""

    issuer: str
    audience: str
    jwks_url: str
    allowed_algorithms: tuple[str, ...] = ("ES256", "RS256")
    clock_skew_seconds: int = 60
    maximum_token_lifetime_seconds: int = 60 * 60

    def validate_configuration(self) -> None:
        failures: list[str] = []
        if not _secure_metadata_url(self.issuer):
            failures.append("auth_issuer_unsafe")
        if not _secure_metadata_url(self.jwks_url):
            failures.append("auth_jwks_url_unsafe")
        if not self.audience or self.audience != self.audience.strip():
            failures.append("auth_audience_invalid")
        algorithms = set(self.allowed_algorithms)
        if (
            not algorithms
            or len(algorithms) != len(self.allowed_algorithms)
            or not algorithms.issubset(SUPPORTED_ASYMMETRIC_ALGORITHMS)
        ):
            failures.append("auth_algorithms_unsafe")
        if not 0 <= self.clock_skew_seconds <= MAX_CLOCK_SKEW_SECONDS:
            failures.append("auth_clock_skew_invalid")
        if not 60 <= self.maximum_token_lifetime_seconds <= MAX_TOKEN_LIFETIME_SECONDS:
            failures.append("auth_token_lifetime_invalid")
        if failures:
            raise ProductionVerifierPolicyError(",".join(dict.fromkeys(failures)))

    def validate_claims(
        self,
        claims: AuthClaims,
        *,
        now: datetime | None = None,
    ) -> None:
        """Validate already cryptographically verified claims against policy."""
        self.validate_configuration()
        try:
            claims.validate_structure()
        except AuthClaimValidationError as error:
            raise ProductionVerifierPolicyError(error.code) from error

        evaluated_at = now or datetime.now(UTC)
        if evaluated_at.tzinfo is None:
            raise ProductionVerifierPolicyError("auth_verification_clock_invalid")
        skew = timedelta(seconds=self.clock_skew_seconds)
        if claims.issuer != self.issuer:
            raise ProductionVerifierPolicyError("auth_issuer_mismatch")
        if self.audience not in claims.audiences:
            raise ProductionVerifierPolicyError("auth_audience_mismatch")
        if claims.issued_at is None or claims.expires_at is None:
            raise ProductionVerifierPolicyError("auth_time_claims_missing")
        if claims.issued_at > evaluated_at + skew:
            raise ProductionVerifierPolicyError("auth_issued_at_future")
        if claims.expires_at <= evaluated_at - skew:
            raise ProductionVerifierPolicyError("auth_token_expired")
        lifetime = claims.expires_at - claims.issued_at
        if lifetime <= timedelta(0) or lifetime > timedelta(
            seconds=self.maximum_token_lifetime_seconds
        ):
            raise ProductionVerifierPolicyError("auth_token_lifetime_invalid")
