"""Owner-scoped, content-free AI output report persistence."""

from typing import cast
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import AIOutputReport, Conversation


class AIOutputReportRepository:
    """Persist only report metadata; never prompts, messages, or generated text."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create_or_get(
        self,
        *,
        user_id: UUID,
        conversation_id: UUID,
        response_id: UUID,
        category: str,
    ) -> AIOutputReport | None:
        owns_conversation = await self._session.scalar(
            select(Conversation.id).where(
                Conversation.id == conversation_id,
                Conversation.owner_id == user_id,
            )
        )
        if owns_conversation is None:
            return None

        existing = cast(
            AIOutputReport | None,
            await self._session.scalar(
                select(AIOutputReport).where(
                    AIOutputReport.user_id == user_id,
                    AIOutputReport.response_id == response_id,
                )
            ),
        )
        if existing is not None:
            return existing

        report = AIOutputReport(
            user_id=user_id,
            conversation_id=conversation_id,
            response_id=response_id,
            category=category,
        )
        self._session.add(report)
        await self._session.flush()
        return report
