"""Account deletion foundation integration tests."""

import asyncio
from typing import cast
from uuid import UUID

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import func, select

from app.db.models import CommunicationProfile, ConsentRecord, Conversation, DeletionRequest
from app.db.session import SessionFactory


async def _private_record_counts(
    session_factory: SessionFactory, user_id: UUID
) -> tuple[int, int, int, int]:
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
    return (
        int(conversation_count or 0),
        int(profile_count or 0),
        int(consent_count or 0),
        int(deletion_count or 0),
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
    api_client.post(
        "/api/v1/consents",
        headers=auth_a,
        json={"consent_type": "history", "granted": True, "policy_version": "test"},
    )
    api_client.post(
        "/api/v1/conversations",
        headers=auth_a,
        json={"title": "Temporary synthetic data"},
    )

    response = api_client.post("/api/v1/privacy/delete-account", headers=auth_a)

    assert response.status_code == 202
    assert response.json()["status"] == "pending"
    assert "provider-account cleanup is pending" in response.json()["message"]
    application = cast(FastAPI, api_client.app)
    counts = asyncio.run(
        _private_record_counts(
            cast(SessionFactory, application.state.session_factory), UUID(user_id)
        )
    )
    assert counts == (0, 0, 0, 1)
    assert api_client.get("/api/v1/users/me", headers=auth_a).status_code == 403
