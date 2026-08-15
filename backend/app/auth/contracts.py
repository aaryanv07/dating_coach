"""Provider-neutral authentication contracts and claim validation."""

from dataclasses import dataclass
from datetime import datetime

LOCAL_AUTH_ISSUER = "urn:convocoach:local"
LOCAL_AUTH_AUDIENCE = "convocoach-api"
MAX_BEARER_TOKEN_LENGTH = 8192
MAX_AUTH_SUBJECT_LENGTH = 255
MAX_AUTH_ISSUER_LENGTH = 512
MAX_AUTH_AUDIENCE_LENGTH = 255
MAX_AUTH_EMAIL_LENGTH = 320
MAX_AUTH_DISPLAY_NAME_LENGTH = 120
MAX_AUTH_PERMISSIONS = 64
MAX_AUTH_PERMISSION_LENGTH = 128


class AuthClaimValidationError(ValueError):
    """Content-free failure raised for structurally invalid trusted claims."""

    def __init__(self, code: str) -> None:
        self.code = code
        super().__init__(code)


def _validate_text(value: str, *, field: str, maximum: int) -> None:
    if not value or value != value.strip():
        raise AuthClaimValidationError(f"{field}_invalid")
    if len(value) > maximum or any(ord(character) < 32 for character in value):
        raise AuthClaimValidationError(f"{field}_invalid")


@dataclass(frozen=True, slots=True)
class AuthClaims:
    """Minimal claims returned only after a verifier trusts a credential."""

    subject: str
    issuer: str = LOCAL_AUTH_ISSUER
    audiences: tuple[str, ...] = (LOCAL_AUTH_AUDIENCE,)
    permissions: tuple[str, ...] = ()
    email: str | None = None
    email_verified: bool = False
    display_name: str | None = None
    issued_at: datetime | None = None
    expires_at: datetime | None = None

    def validate_structure(self) -> None:
        """Validate bounded identity data before current-user resolution."""
        _validate_text(
            self.subject,
            field="auth_subject",
            maximum=MAX_AUTH_SUBJECT_LENGTH,
        )
        _validate_text(
            self.issuer,
            field="auth_issuer",
            maximum=MAX_AUTH_ISSUER_LENGTH,
        )
        if not self.audiences or len(set(self.audiences)) != len(self.audiences):
            raise AuthClaimValidationError("auth_audience_invalid")
        for audience in self.audiences:
            _validate_text(
                audience,
                field="auth_audience",
                maximum=MAX_AUTH_AUDIENCE_LENGTH,
            )
        if len(self.permissions) > MAX_AUTH_PERMISSIONS or len(set(self.permissions)) != len(
            self.permissions
        ):
            raise AuthClaimValidationError("auth_permissions_invalid")
        for permission in self.permissions:
            _validate_text(
                permission,
                field="auth_permissions",
                maximum=MAX_AUTH_PERMISSION_LENGTH,
            )
            if any(character.isspace() for character in permission):
                raise AuthClaimValidationError("auth_permissions_invalid")
        if self.email is not None:
            _validate_text(
                self.email,
                field="auth_email",
                maximum=MAX_AUTH_EMAIL_LENGTH,
            )
        if self.display_name is not None:
            _validate_text(
                self.display_name,
                field="auth_display_name",
                maximum=MAX_AUTH_DISPLAY_NAME_LENGTH,
            )
        if self.issued_at is not None and self.issued_at.tzinfo is None:
            raise AuthClaimValidationError("auth_issued_at_invalid")
        if self.expires_at is not None and self.expires_at.tzinfo is None:
            raise AuthClaimValidationError("auth_expires_at_invalid")
