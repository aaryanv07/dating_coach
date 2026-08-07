"""Owner-scoped conversation and message repository."""

from typing import cast
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.models import (
    Conversation,
    ConversationEvent,
    ConversationEventRelationship,
    ConversationParticipant,
    ConversationSource,
    Message,
    utc_now,
)
from app.domain.conversation_events import ConfirmedConversationEventSequence
from app.domain.conversation_import import ConfirmedConversation


class ConversationRepository:
    """Ensures every conversation operation includes the authenticated owner."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(self, owner_id: UUID, *, title: str, other_display_name: str) -> Conversation:
        conversation = Conversation(owner_id=owner_id, title=title)
        conversation.participants = [
            ConversationParticipant(
                user_id=owner_id,
                role="user",
                display_name="Me",
                position=0,
            ),
            ConversationParticipant(
                role="other",
                display_name=other_display_name,
                position=1,
            ),
        ]
        conversation.messages = []
        conversation.sources = []
        conversation.events = []
        self._session.add(conversation)
        await self._session.flush()
        return conversation

    async def list_owned(self, owner_id: UUID, *, limit: int, offset: int) -> list[Conversation]:
        conversations = await self._session.scalars(
            select(Conversation)
            .where(Conversation.owner_id == owner_id)
            .options(
                selectinload(Conversation.participants),
                selectinload(Conversation.messages).load_only(Message.id),
            )
            .order_by(Conversation.updated_at.desc(), Conversation.id)
            .limit(limit)
            .offset(offset)
        )
        return list(conversations)

    async def get_owned(self, owner_id: UUID, conversation_id: UUID) -> Conversation | None:
        return cast(
            Conversation | None,
            await self._session.scalar(
                select(Conversation)
                .where(
                    Conversation.id == conversation_id,
                    Conversation.owner_id == owner_id,
                )
                .options(
                    selectinload(Conversation.participants),
                    selectinload(Conversation.messages),
                    selectinload(Conversation.sources),
                    selectinload(Conversation.events),
                )
            ),
        )

    async def add_message(
        self,
        owner_id: UUID,
        conversation_id: UUID,
        *,
        participant_id: UUID,
        body: str,
    ) -> Message | None:
        conversation = await self.get_owned(owner_id, conversation_id)
        if conversation is None:
            return None
        if not any(participant.id == participant_id for participant in conversation.participants):
            return None

        next_position = await self._session.scalar(
            select(func.coalesce(func.max(Message.position), -1) + 1).where(
                Message.conversation_id == conversation_id
            )
        )
        message = Message(
            conversation_id=conversation_id,
            participant_id=participant_id,
            position=int(next_position or 0),
            speaker=next(
                participant.role
                for participant in conversation.participants
                if participant.id == participant_id
            ),
            body=body,
        )
        conversation.updated_at = utc_now()
        self._session.add(message)
        await self._session.flush()
        return message

    async def confirm_import(
        self,
        owner_id: UUID,
        conversation_id: UUID,
        payload: ConfirmedConversation,
    ) -> Conversation | None:
        """Atomically replace draft content with normalized, confirmed data."""
        conversation = await self.get_owned(owner_id, conversation_id)
        if conversation is None:
            return None

        participants_by_role = {
            participant.role: participant for participant in conversation.participants
        }
        conversation.messages.clear()
        conversation.sources.clear()
        await self._session.flush()

        for source in payload.sources:
            conversation.sources.append(
                ConversationSource(
                    source_type=source.source_type,
                    source_index=source.source_index,
                    mime_type=source.mime_type,
                    byte_size=source.byte_size,
                    storage_status=source.storage_status,
                    deleted_at=utc_now() if source.storage_status == "deleted" else None,
                )
            )

        for position, normalized in enumerate(payload.messages):
            participant = participants_by_role[normalized.speaker]
            conversation.messages.append(
                Message(
                    participant_id=participant.id,
                    position=position,
                    speaker=normalized.speaker,
                    body=normalized.text,
                    sent_at=normalized.timestamp,
                    visible_timestamp_text=normalized.visible_timestamp_text,
                    timestamp_estimated=normalized.timestamp_estimated,
                    ocr_confidence=normalized.ocr_confidence,
                    source_screenshot_index=normalized.source_screenshot_index,
                    status="confirmed",
                )
            )

        conversation.title = payload.title
        conversation.source_type = payload.source_type
        conversation.status = "confirmed"
        conversation.readiness_score = payload.readiness_score
        conversation.extraction_metadata = (
            {
                "provider": payload.extraction_metadata.provider,
                "provider_version": payload.extraction_metadata.provider_version,
                "extraction_version": payload.extraction_metadata.extraction_version,
                "preprocessing_version": payload.extraction_metadata.preprocessing_version,
                "confidence_available": payload.extraction_metadata.confidence_available,
            }
            if payload.extraction_metadata is not None
            else None
        )
        conversation.confirmed_at = utc_now()
        conversation.updated_at = utc_now()
        await self._session.flush()
        return conversation

    async def replace_events(
        self,
        owner_id: UUID,
        conversation_id: UUID,
        payload: ConfirmedConversationEventSequence,
    ) -> Conversation | None:
        """Atomically replace only the event sequence, leaving legacy messages untouched."""
        conversation = await self.get_owned(owner_id, conversation_id)
        if conversation is None:
            return None

        conversation.events.clear()
        await self._session.flush()

        events_by_id: dict[UUID, ConversationEvent] = {}
        for event in payload.events:
            stored = ConversationEvent(
                id=event.id,
                position=event.position,
                event_type=event.event_type.value,
                speaker=event.speaker.value,
                text=event.text,
                timestamp=event.timestamp,
                timestamp_is_estimated=event.timestamp_is_estimated,
                raw_timestamp_text=event.raw_timestamp_text,
                source_image_index=event.source_image_index,
                source_region_id=event.source_region_id,
                ocr_confidence=event.ocr_confidence,
                classification_confidence=event.classification_confidence,
                speaker_confidence=event.speaker_confidence,
                timestamp_confidence=event.timestamp_confidence,
                relationship_confidence=event.relationship_confidence,
                requires_review=event.requires_review,
                metadata_json=event.metadata,
                deleted_at=event.deleted_at,
            )
            conversation.events.append(stored)
            events_by_id[event.id] = stored

        await self._session.flush()
        for relationship in payload.relationships:
            self._session.add(
                ConversationEventRelationship(
                    id=relationship.id,
                    source_event=events_by_id[relationship.source_event_id],
                    target_event=events_by_id[relationship.target_event_id],
                    relationship_type=relationship.relationship_type.value,
                    confidence=relationship.confidence,
                    metadata_json=relationship.metadata,
                )
            )

        conversation.updated_at = utc_now()
        await self._session.flush()
        return conversation

    async def list_event_relationships(
        self, conversation_id: UUID
    ) -> list[ConversationEventRelationship]:
        """Load relationships after ownership has already been established."""
        relationships = await self._session.scalars(
            select(ConversationEventRelationship)
            .join(
                ConversationEvent,
                ConversationEventRelationship.source_event_id == ConversationEvent.id,
            )
            .where(ConversationEvent.conversation_id == conversation_id)
            .order_by(
                ConversationEventRelationship.created_at,
                ConversationEventRelationship.id,
            )
        )
        return list(relationships)

    async def delete_owned(self, owner_id: UUID, conversation_id: UUID) -> bool:
        conversation = await self.get_owned(owner_id, conversation_id)
        if conversation is None:
            return False
        await self._session.delete(conversation)
        await self._session.flush()
        return True
