"""Owner-scoped conversation, participant, and message routes."""

from typing import Literal, cast
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Response, status

from app.api.dependencies import CurrentUser, DatabaseSession
from app.db.models import Conversation, Message
from app.domain.conversation_import import (
    ConfirmedConversation,
    ConfirmedExtractionMetadata,
    ConfirmedMessage,
    ConfirmedSource,
)
from app.repositories.conversations import ConversationRepository
from app.repositories.users import ConsentRepository
from app.schemas.conversations import (
    ConversationConfirm,
    ConversationCreate,
    ConversationDetailRead,
    ConversationParticipantRead,
    ConversationSourceRead,
    ConversationSummaryRead,
    ExtractionMetadata,
    MessageCreate,
    MessageRead,
)

router = APIRouter(prefix="/api/v1/conversations", tags=["conversations"])


def _other_participant_name(conversation: Conversation) -> str:
    for participant in conversation.participants:
        if participant.role == "other":
            return participant.display_name
    return "Other person"


def _to_summary(conversation: Conversation) -> ConversationSummaryRead:
    return ConversationSummaryRead(
        id=conversation.id,
        title=conversation.title,
        participant_name=_other_participant_name(conversation),
        message_count=len(conversation.messages),
        source_type=cast(Literal["manual", "screenshot", "paste"], conversation.source_type),
        status=cast(Literal["draft", "confirmed"], conversation.status),
        readiness_score=conversation.readiness_score,
        created_at=conversation.created_at,
        updated_at=conversation.updated_at,
    )


def _to_detail(conversation: Conversation) -> ConversationDetailRead:
    return ConversationDetailRead(
        id=conversation.id,
        title=conversation.title,
        source_type=cast(Literal["manual", "screenshot", "paste"], conversation.source_type),
        status=cast(Literal["draft", "confirmed"], conversation.status),
        readiness_score=conversation.readiness_score,
        confirmed_at=conversation.confirmed_at,
        participants=[
            ConversationParticipantRead.model_validate(participant)
            for participant in conversation.participants
        ],
        messages=[MessageRead.model_validate(message) for message in conversation.messages],
        sources=[ConversationSourceRead.model_validate(source) for source in conversation.sources],
        extraction_metadata=(
            ExtractionMetadata.model_validate(conversation.extraction_metadata)
            if conversation.extraction_metadata is not None
            else None
        ),
        created_at=conversation.created_at,
        updated_at=conversation.updated_at,
    )


@router.post("", response_model=ConversationDetailRead, status_code=status.HTTP_201_CREATED)
async def create_conversation(
    payload: ConversationCreate,
    user: CurrentUser,
    session: DatabaseSession,
) -> ConversationDetailRead:
    """Create an empty owner-scoped conversation and its participant labels."""
    conversation = await ConversationRepository(session).create(
        user.id,
        title=payload.title,
        other_display_name=payload.other_participant_name,
    )
    await session.commit()
    return _to_detail(conversation)


@router.get("", response_model=list[ConversationSummaryRead])
async def list_conversations(
    user: CurrentUser,
    session: DatabaseSession,
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> list[ConversationSummaryRead]:
    """List paginated conversations without exposing message bodies."""
    conversations = await ConversationRepository(session).list_owned(
        user.id, limit=limit, offset=offset
    )
    return [_to_summary(conversation) for conversation in conversations]


@router.get("/{conversation_id}", response_model=ConversationDetailRead)
async def read_conversation(
    conversation_id: UUID,
    user: CurrentUser,
    session: DatabaseSession,
) -> ConversationDetailRead:
    """Return a conversation only when it belongs to the current user."""
    conversation = await ConversationRepository(session).get_owned(user.id, conversation_id)
    if conversation is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")
    return _to_detail(conversation)


@router.post(
    "/{conversation_id}/messages",
    response_model=MessageRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_message(
    conversation_id: UUID,
    payload: MessageCreate,
    user: CurrentUser,
    session: DatabaseSession,
) -> Message:
    """Create one manual message without providing an import surface."""
    message = await ConversationRepository(session).add_message(
        user.id,
        conversation_id,
        participant_id=payload.participant_id,
        body=payload.body,
    )
    if message is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")
    await session.commit()
    return message


@router.post("/{conversation_id}/confirm", response_model=ConversationDetailRead)
async def confirm_conversation_import(
    conversation_id: UUID,
    payload: ConversationConfirm,
    user: CurrentUser,
    session: DatabaseSession,
) -> ConversationDetailRead:
    """Persist reviewed messages only after explicit history consent."""
    has_consent = await ConsentRepository(session).has_active(user.id, "save_conversation_history")
    if not has_consent:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Saving conversation history requires active consent",
        )

    confirmed = ConfirmedConversation(
        title=payload.title,
        source_type=payload.source_type,
        readiness_score=payload.readiness_score,
        sources=tuple(
            ConfirmedSource(
                source_type=source.source_type,
                source_index=source.source_index,
                mime_type=source.mime_type,
                byte_size=source.byte_size,
                storage_status=source.storage_status,
            )
            for source in payload.sources
        ),
        messages=tuple(
            ConfirmedMessage(
                speaker=message.speaker,
                text=message.text,
                timestamp=message.timestamp,
                visible_timestamp_text=message.visible_timestamp_text,
                timestamp_estimated=message.timestamp_estimated,
                ocr_confidence=message.ocr_confidence,
                source_screenshot_index=message.source_screenshot_index,
            )
            for message in payload.messages
        ),
        extraction_metadata=(
            ConfirmedExtractionMetadata(
                provider=payload.extraction_metadata.provider,
                provider_version=payload.extraction_metadata.provider_version,
                extraction_version=payload.extraction_metadata.extraction_version,
                preprocessing_version=payload.extraction_metadata.preprocessing_version,
                confidence_available=payload.extraction_metadata.confidence_available,
            )
            if payload.extraction_metadata is not None
            else None
        ),
    )
    conversation = await ConversationRepository(session).confirm_import(
        user.id, conversation_id, confirmed
    )
    if conversation is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")
    await session.commit()
    return _to_detail(conversation)


@router.delete("/{conversation_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_conversation(
    conversation_id: UUID,
    user: CurrentUser,
    session: DatabaseSession,
) -> Response:
    """Permanently delete one owned conversation and its child records."""
    deleted = await ConversationRepository(session).delete_owned(user.id, conversation_id)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")
    await session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
