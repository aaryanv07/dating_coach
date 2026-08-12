"""Owner-scoped account export without raw sources or internal credentials."""

from datetime import datetime
from typing import cast
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.models import (
    AIOutputReport,
    AIUsageRecord,
    CommunicationProfile,
    ConsentRecord,
    Conversation,
    ConversationEventRelationship,
    SubscriptionEntitlement,
    User,
    UserPreference,
)
from app.domain.conversation_events import JsonObject, JsonValue


def _timestamp(value: datetime | None) -> str | None:
    return value.isoformat() if value is not None else None


class PrivacyExportRepository:
    """Serialize only data belonging to one verified application user."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def export(self, user: User) -> JsonObject:
        preferences = await self._session.get(UserPreference, user.id)
        profile = await self._session.get(CommunicationProfile, user.id)
        consents = list(
            await self._session.scalars(
                select(ConsentRecord)
                .where(ConsentRecord.user_id == user.id)
                .order_by(ConsentRecord.recorded_at, ConsentRecord.id)
            )
        )
        conversations = list(
            await self._session.scalars(
                select(Conversation)
                .where(Conversation.owner_id == user.id)
                .options(
                    selectinload(Conversation.participants),
                    selectinload(Conversation.messages),
                    selectinload(Conversation.sources),
                    selectinload(Conversation.events),
                )
                .order_by(Conversation.created_at, Conversation.id)
            )
        )
        event_conversation_ids: dict[UUID, UUID] = {
            event.id: conversation.id
            for conversation in conversations
            for event in conversation.events
        }
        relationships_by_conversation: dict[UUID, list[ConversationEventRelationship]] = {
            conversation.id: [] for conversation in conversations
        }
        if event_conversation_ids:
            relationships = list(
                await self._session.scalars(
                    select(ConversationEventRelationship)
                    .where(
                        ConversationEventRelationship.source_event_id.in_(
                            tuple(event_conversation_ids)
                        )
                    )
                    .order_by(
                        ConversationEventRelationship.created_at,
                        ConversationEventRelationship.id,
                    )
                )
            )
            for relationship in relationships:
                conversation_id = event_conversation_ids[relationship.source_event_id]
                relationships_by_conversation[conversation_id].append(relationship)
        entitlements = list(
            await self._session.scalars(
                select(SubscriptionEntitlement)
                .where(SubscriptionEntitlement.user_id == user.id)
                .order_by(SubscriptionEntitlement.created_at, SubscriptionEntitlement.id)
            )
        )
        usage_records = list(
            await self._session.scalars(
                select(AIUsageRecord)
                .where(AIUsageRecord.user_id == user.id)
                .order_by(AIUsageRecord.created_at, AIUsageRecord.id)
            )
        )
        output_reports = list(
            await self._session.scalars(
                select(AIOutputReport)
                .where(AIOutputReport.user_id == user.id)
                .order_by(AIOutputReport.created_at, AIOutputReport.id)
            )
        )

        preferences_payload: JsonValue = None
        if preferences is not None:
            preferences_payload = {
                "preferred_language": preferences.preferred_language,
                "coaching_style": preferences.coaching_style,
                "save_history": preferences.save_history,
                "updated_at": _timestamp(preferences.updated_at),
            }
        profile_payload: JsonValue = None
        if profile is not None:
            profile_payload = {
                "preferred_name": profile.preferred_name,
                "relationship_intention": profile.relationship_intention,
                "communication_tone": profile.communication_tone,
                "texting_style": profile.texting_style,
                "preferred_message_length": profile.preferred_message_length,
                "uses_emojis": profile.uses_emojis,
                "updated_at": _timestamp(profile.updated_at),
            }

        return {
            "account": {
                "id": str(user.id),
                "email": user.email,
                "display_name": user.display_name,
                "created_at": _timestamp(user.created_at),
                "updated_at": _timestamp(user.updated_at),
            },
            "preferences": preferences_payload,
            "communication_profile": profile_payload,
            "consents": [
                {
                    "id": str(record.id),
                    "consent_type": record.consent_type,
                    "granted": record.granted,
                    "policy_version": record.policy_version,
                    "recorded_at": _timestamp(record.recorded_at),
                }
                for record in consents
            ],
            "conversations": [
                self._conversation_payload(
                    conversation,
                    relationships_by_conversation[conversation.id],
                )
                for conversation in conversations
            ],
            "subscription_entitlements": [
                {
                    "id": str(entitlement.id),
                    "plan_code": entitlement.plan_code,
                    "status": entitlement.status,
                    "storefront": entitlement.storefront,
                    "current_period_start": _timestamp(entitlement.current_period_start),
                    "current_period_end": _timestamp(entitlement.current_period_end),
                    "verified_at": _timestamp(entitlement.verified_at),
                }
                for entitlement in entitlements
            ],
            "ai_usage": [
                {
                    "allowance_kind": usage.allowance_kind,
                    "status": usage.status,
                    "plan_code": usage.plan_code,
                    "window_start": _timestamp(usage.window_start),
                    "window_end": _timestamp(usage.window_end),
                    "model_identifier": usage.model_identifier,
                    "input_tokens": usage.input_tokens,
                    "output_tokens": usage.output_tokens,
                    "total_tokens": usage.total_tokens,
                    "cost_microusd": usage.cost_microusd,
                    "completed_at": _timestamp(usage.completed_at),
                    "released_at": _timestamp(usage.released_at),
                    "created_at": _timestamp(usage.created_at),
                }
                for usage in usage_records
            ],
            "ai_output_reports": [
                {
                    "id": str(report.id),
                    "conversation_id": str(report.conversation_id),
                    "response_id": str(report.response_id),
                    "category": report.category,
                    "status": report.status,
                    "created_at": _timestamp(report.created_at),
                    "updated_at": _timestamp(report.updated_at),
                }
                for report in output_reports
            ],
        }

    @staticmethod
    def _conversation_payload(
        conversation: Conversation,
        relationships: list[ConversationEventRelationship],
    ) -> JsonObject:
        return {
            "id": str(conversation.id),
            "title": conversation.title,
            "source_type": conversation.source_type,
            "status": conversation.status,
            "readiness_score": conversation.readiness_score,
            "confirmed_at": _timestamp(conversation.confirmed_at),
            "created_at": _timestamp(conversation.created_at),
            "updated_at": _timestamp(conversation.updated_at),
            "extraction_metadata": cast(JsonValue, conversation.extraction_metadata),
            "participants": [
                {
                    "id": str(participant.id),
                    "role": participant.role,
                    "display_name": participant.display_name,
                    "position": participant.position,
                }
                for participant in conversation.participants
            ],
            "messages": [
                {
                    "id": str(message.id),
                    "participant_id": str(message.participant_id),
                    "position": message.position,
                    "speaker": message.speaker,
                    "body": message.body,
                    "sent_at": _timestamp(message.sent_at),
                    "visible_timestamp_text": message.visible_timestamp_text,
                    "timestamp_estimated": message.timestamp_estimated,
                    "ocr_confidence": message.ocr_confidence,
                    "source_screenshot_index": message.source_screenshot_index,
                    "status": message.status,
                    "created_at": _timestamp(message.created_at),
                    "updated_at": _timestamp(message.updated_at),
                }
                for message in conversation.messages
            ],
            "sources": [
                {
                    "source_type": source.source_type,
                    "source_index": source.source_index,
                    "mime_type": source.mime_type,
                    "byte_size": source.byte_size,
                    "storage_status": source.storage_status,
                    "created_at": _timestamp(source.created_at),
                    "deleted_at": _timestamp(source.deleted_at),
                }
                for source in conversation.sources
            ],
            "events": [
                {
                    "id": str(event.id),
                    "position": event.position,
                    "event_type": event.event_type,
                    "speaker": event.speaker,
                    "text": event.text,
                    "timestamp": _timestamp(event.timestamp),
                    "timestamp_is_estimated": event.timestamp_is_estimated,
                    "raw_timestamp_text": event.raw_timestamp_text,
                    "source_image_index": event.source_image_index,
                    "source_region_id": event.source_region_id,
                    "ocr_confidence": event.ocr_confidence,
                    "classification_confidence": event.classification_confidence,
                    "speaker_confidence": event.speaker_confidence,
                    "timestamp_confidence": event.timestamp_confidence,
                    "relationship_confidence": event.relationship_confidence,
                    "requires_review": event.requires_review,
                    "metadata": event.metadata_json,
                    "created_at": _timestamp(event.created_at),
                    "updated_at": _timestamp(event.updated_at),
                    "deleted_at": _timestamp(event.deleted_at),
                }
                for event in conversation.events
            ],
            "relationships": [
                {
                    "id": str(relationship.id),
                    "source_event_id": str(relationship.source_event_id),
                    "target_event_id": str(relationship.target_event_id),
                    "relationship_type": relationship.relationship_type,
                    "confidence": relationship.confidence,
                    "metadata": relationship.metadata_json,
                    "created_at": _timestamp(relationship.created_at),
                    "updated_at": _timestamp(relationship.updated_at),
                }
                for relationship in relationships
            ],
        }
