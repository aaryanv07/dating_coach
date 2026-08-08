"""FastAPI dependencies for verified identity and database access."""

from collections.abc import AsyncIterator
from typing import Annotated, cast

from fastapi import Depends, HTTPException, Request, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.contracts import (
    MAX_BEARER_TOKEN_LENGTH,
    AuthClaims,
    AuthClaimValidationError,
)
from app.auth.verifier import (
    AuthenticationError,
    AuthenticationVerifier,
)
from app.db.models import User
from app.db.session import SessionFactory
from app.repositories.users import AccountDeletedError, UserRepository

bearer_scheme = HTTPBearer(auto_error=False)


async def get_database_session(request: Request) -> AsyncIterator[AsyncSession]:
    """Provide one transaction-capable session per request."""
    session_factory = cast(SessionFactory | None, request.app.state.session_factory)
    if session_factory is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database is not configured",
        )
    async with session_factory() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise


DatabaseSession = Annotated[AsyncSession, Depends(get_database_session)]


async def get_verified_claims(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Security(bearer_scheme)],
) -> AuthClaims:
    """Verify bearer credentials without trusting client-supplied user IDs."""
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials
    if (
        not token
        or len(token) > MAX_BEARER_TOKEN_LENGTH
        or any(character.isspace() or ord(character) < 32 for character in token)
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    verifier = cast(AuthenticationVerifier, request.app.state.auth_verifier)
    try:
        claims = await verifier.verify(token)
        claims.validate_structure()
        return claims
    except (AuthenticationError, AuthClaimValidationError) as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        ) from error


VerifiedClaims = Annotated[AuthClaims, Depends(get_verified_claims)]

USER_METRICS_PERMISSION = "read:user-metrics"


async def require_user_metrics_permission(claims: VerifiedClaims) -> AuthClaims:
    """Allow aggregate user metrics only to explicitly authorized operators."""
    if USER_METRICS_PERMISSION not in claims.permissions:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient operator permission",
        )
    return claims


UserMetricsOperator = Annotated[AuthClaims, Depends(require_user_metrics_permission)]


async def get_current_user(
    claims: VerifiedClaims,
    session: DatabaseSession,
) -> User:
    """Resolve the verified provider subject to a server-owned user record."""
    try:
        user = await UserRepository(session).get_or_create(claims)
    except AccountDeletedError as error:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account deletion has been requested",
        ) from error
    await session.commit()
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
