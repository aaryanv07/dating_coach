"""Repositories for users, preferences, profiles, consent, and deletion."""

from datetime import datetime
from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.verifier import AuthClaims
from app.db.models import (
    CommunicationProfile,
    ConsentRecord,
    Conversation,
    DeletionRequest,
    User,
    UserPreference,
    utc_now,
)


class AccountDeletedError(Exception):
    """Raised when a deleted auth subject attempts to access the application."""


class UserRepository:
    """Owns application-user provisioning and user-scoped settings."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_or_create(self, claims: AuthClaims) -> User:
        user = await self._session.scalar(select(User).where(User.auth_subject == claims.subject))
        if user is not None:
            if user.deleted_at is not None:
                raise AccountDeletedError
            return user

        user = User(
            auth_subject=claims.subject,
            email=claims.email,
            display_name=claims.display_name,
        )
        self._session.add(user)
        await self._session.flush()
        return user

    async def get_preferences(self, user_id: UUID) -> UserPreference:
        preferences = await self._session.get(UserPreference, user_id)
        if preferences is None:
            preferences = UserPreference(user_id=user_id)
            self._session.add(preferences)
            await self._session.flush()
        return preferences

    async def update_preferences(
        self,
        user_id: UUID,
        *,
        preferred_language: str | None,
        coaching_style: str | None,
        save_history: bool | None,
    ) -> UserPreference:
        preferences = await self.get_preferences(user_id)
        if preferred_language is not None:
            preferences.preferred_language = preferred_language
        if coaching_style is not None:
            preferences.coaching_style = coaching_style
        if save_history is not None:
            preferences.save_history = save_history
        await self._session.flush()
        return preferences

    async def get_profile(self, user_id: UUID) -> CommunicationProfile:
        profile = await self._session.get(CommunicationProfile, user_id)
        if profile is None:
            profile = CommunicationProfile(user_id=user_id)
            self._session.add(profile)
            await self._session.flush()
        return profile

    async def update_profile(
        self,
        user_id: UUID,
        *,
        preferred_name: str | None,
        relationship_intention: str | None,
        communication_tone: str | None,
        texting_style: str | None,
        preferred_message_length: str | None,
        uses_emojis: bool | None,
    ) -> CommunicationProfile:
        profile = await self.get_profile(user_id)
        if preferred_name is not None:
            profile.preferred_name = preferred_name
        if relationship_intention is not None:
            profile.relationship_intention = relationship_intention
        if communication_tone is not None:
            profile.communication_tone = communication_tone
        if texting_style is not None:
            profile.texting_style = texting_style
        if preferred_message_length is not None:
            profile.preferred_message_length = preferred_message_length
        if uses_emojis is not None:
            profile.uses_emojis = uses_emojis
        await self._session.flush()
        return profile


class ConsentRepository:
    """Appends and lists explicit user consent decisions."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def record(
        self,
        user_id: UUID,
        *,
        consent_type: str,
        granted: bool,
        policy_version: str,
    ) -> ConsentRecord:
        record = ConsentRecord(
            user_id=user_id,
            consent_type=consent_type,
            granted=granted,
            policy_version=policy_version,
        )
        self._session.add(record)
        await self._session.flush()
        return record

    async def list_for_user(self, user_id: UUID) -> list[ConsentRecord]:
        records = await self._session.scalars(
            select(ConsentRecord)
            .where(ConsentRecord.user_id == user_id)
            .order_by(ConsentRecord.recorded_at.desc())
        )
        return list(records)

    async def has_active(self, user_id: UUID, consent_type: str) -> bool:
        latest = await self._session.scalar(
            select(ConsentRecord)
            .where(
                ConsentRecord.user_id == user_id,
                ConsentRecord.consent_type == consent_type,
            )
            .order_by(ConsentRecord.recorded_at.desc(), ConsentRecord.id.desc())
            .limit(1)
        )
        return latest is not None and latest.granted


class PrivacyRepository:
    """Starts an idempotent account deletion and removes private child data."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def request_account_deletion(self, user: User) -> DeletionRequest:
        existing = await self._session.scalar(
            select(DeletionRequest).where(DeletionRequest.user_id == user.id)
        )
        if existing is not None:
            return existing

        await self._session.execute(delete(Conversation).where(Conversation.owner_id == user.id))
        await self._session.execute(delete(ConsentRecord).where(ConsentRecord.user_id == user.id))
        await self._session.execute(
            delete(CommunicationProfile).where(CommunicationProfile.user_id == user.id)
        )
        await self._session.execute(delete(UserPreference).where(UserPreference.user_id == user.id))

        user.email = None
        user.display_name = None
        user.deleted_at = utc_now()
        request = DeletionRequest(user_id=user.id)
        self._session.add(request)
        await self._session.flush()
        return request


def deletion_timestamp(user: User) -> datetime | None:
    """Expose the deletion timestamp without leaking other identity fields."""
    return user.deleted_at
