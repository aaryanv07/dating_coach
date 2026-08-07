"""Account deletion foundation integration tests."""

import asyncio
from typing import cast
from uuid import UUID

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import func, select

from app.db.models import (
    CommunicationProfile,
    ConsentRecord,
    Conversation,
    ConversationEvent,
    ConversationEventRelationship,
    DeletionRequest,
)
from app.db.session import SessionFactory


async def _private_record_counts(
    session_factory: SessionFactory, user_id: UUID
) -> tuple[int, int, int, int, int, int]:
    async with session_factory() as session:
        conversation_count = await session.scalar(
            select(func.count()).select_from(Conversation).where(Conversation.owner_id == user_id)
        )
        profile_count = await session.scalar(
            select(func.count())
            .select_from(CommunicationProfile)
            .where(CommunicationProfile.user_id == user_id)
        )
        consent_count = await session.scalar(
            select(func.count()).select_from(ConsentRecord).where(ConsentRecord.user_id == user_id)
        )
        deletion_count = await session.scalar(
            select(func.count())
            .select_from(DeletionRequest)
            .where(DeletionRequest.user_id == user_id)
        )
        event_count = await session.scalar(select(func.count()).select_from(ConversationEvent))
        relationship_count = await session.scalar(
            select(func.count()).select_from(ConversationEventRelationship)
        )
    return (
        int(conversation_count or 0),
        int(profile_count or 0),
        int(consent_count or 0),
        int(deletion_count or 0),
        int(event_count or 0),
        int(relationship_count or 0),
    )


def test_account_deletion_removes_private_data_and_blocks_reentry(
    api_client: TestClient, auth_a: dict[str, str]
) -> None:
    user_id = api_client.get("/api/v1/users/me", headers=auth_a).json()["id"]
    api_client.patch(
        "/api/v1/communication-profile",
        headers=auth_a,
        json={"preferred_name": "Delete me", "communication_tone": "calm"},
    )
    consent = api_client.post(
        "/api/v1/consents",
        headers=auth_a,
        json={
            "consent_type": "save_conversation_history",
            "granted": True,
            "policy_version": "phase6a1-test",
        },
    )
    assert consent.status_code == 201
    conversation = api_client.post(
        "/api/v1/conversations",
        headers=auth_a,
        json={"title": "Temporary synthetic data"},
    )
    assert conversation.status_code == 201
    event_sequence = api_client.put(
        f"/api/v1/conversations/{conversation.json()['id']}/events",
        headers=auth_a,
        json={
            "schema_version": "conversation-events.v1",
            "events": [
                {
                    "id": "00000000-0000-4000-8000-000000000301",
                    "position": 0,
                    "event_type": "text_message",
                    "speaker": "user",
                    "text": "Synthetic cascade target",
                    "timestamp": None,
                    "timestamp_is_estimated": False,
                    "raw_timestamp_text": None,
                    "source_image_index": 0,
                    "source_region_id": "synthetic-delete-1",
                    "ocr_confidence": 1.0,
                    "classification_confidence": 1.0,
                    "speaker_confidence": 1.0,
                    "timestamp_confidence": None,
                    "relationship_confidence": None,
                    "requires_review": False,
                    "metadata": {},
                    "deleted_at": None,
                },
                {
                    "id": "00000000-0000-4000-8000-000000000302",
                    "position": 1,
                    "event_type": "reaction",
                    "speaker": "other",
                    "text": None,
                    "timestamp": None,
                    "timestamp_is_estimated": False,
                    "raw_timestamp_text": None,
                    "source_image_index": 0,
                    "source_region_id": "synthetic-delete-2",
                    "ocr_confidence": 1.0,
                    "classification_confidence": 1.0,
                    "speaker_confidence": 1.0,
                    "timestamp_confidence": None,
                    "relationship_confidence": 1.0,
                    "requires_review": False,
                    "metadata": {"reaction": "heart"},
                    "deleted_at": None,
                },
            ],
            "relationships": [
                {
                    "id": "00000000-0000-4000-8000-000000000303",
                    "source_event_id": "00000000-0000-4000-8000-000000000302",
                    "target_event_id": "00000000-0000-4000-8000-000000000301",
                    "relationship_type": "reaction_target",
                    "confidence": 1.0,
                    "metadata": {},
                }
            ],
        },
    )
    assert event_sequence.status_code == 200

    application = cast(FastAPI, api_client.app)
    before_counts = asyncio.run(
        _private_record_counts(
            cast(SessionFactory, application.state.session_factory), UUID(user_id)
        )
    )
    assert before_counts == (1, 1, 1, 0, 2, 1)

    response = api_client.post("/api/v1/privacy/delete-account", headers=auth_a)

    assert response.status_code == 202
    assert response.json()["status"] == "pending"
    assert "provider-account cleanup is pending" in response.json()["message"]
    counts = asyncio.run(
        _private_record_counts(
            cast(SessionFactory, application.state.session_factory), UUID(user_id)
        )
    )
    assert counts == (0, 0, 0, 1, 0, 0)
    assert api_client.get("/api/v1/users/me", headers=auth_a).status_code == 403
