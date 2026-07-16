"""Phase 3 metadata and relationship contract tests."""

from app.db import models as database_models
from app.db.base import Base

del database_models


def test_phase_four_tables_are_registered() -> None:
    assert set(Base.metadata.tables) == {
        "users",
        "user_preferences",
        "communication_profiles",
        "consent_records",
        "conversations",
        "conversation_participants",
        "conversation_sources",
        "conversation_events",
        "conversation_event_relationships",
        "messages",
        "deletion_requests",
    }


def test_conversation_children_have_explicit_cascade_behavior() -> None:
    participants = Base.metadata.tables["conversation_participants"]
    messages = Base.metadata.tables["messages"]
    sources = Base.metadata.tables["conversation_sources"]
    events = Base.metadata.tables["conversation_events"]
    relationships = Base.metadata.tables["conversation_event_relationships"]

    participant_conversation_fk = next(
        key for key in participants.foreign_keys if key.column.table.name == "conversations"
    )
    message_conversation_fk = next(
        key for key in messages.foreign_keys if key.column.table.name == "conversations"
    )
    source_conversation_fk = next(
        key for key in sources.foreign_keys if key.column.table.name == "conversations"
    )
    event_conversation_fk = next(
        key for key in events.foreign_keys if key.column.table.name == "conversations"
    )

    assert participant_conversation_fk.ondelete == "CASCADE"
    assert message_conversation_fk.ondelete == "CASCADE"
    assert source_conversation_fk.ondelete == "CASCADE"
    assert event_conversation_fk.ondelete == "CASCADE"
    assert {key.ondelete for key in relationships.foreign_keys} == {"CASCADE"}


def test_screenshot_content_has_no_persistence_column() -> None:
    source_columns = set(Base.metadata.tables["conversation_sources"].columns.keys())

    assert "path" not in source_columns
    assert "content" not in source_columns
    assert "bytes" not in source_columns
    conversation_columns = set(Base.metadata.tables["conversations"].columns.keys())
    assert "extraction_metadata" in conversation_columns
    message_columns = set(Base.metadata.tables["messages"].columns.keys())
    assert "visible_timestamp_text" in message_columns


def test_event_runtime_has_bounded_content_free_columns() -> None:
    events = Base.metadata.tables["conversation_events"]
    relationships = Base.metadata.tables["conversation_event_relationships"]

    assert {
        "event_type",
        "speaker",
        "classification_confidence",
        "speaker_confidence",
        "timestamp_confidence",
        "relationship_confidence",
        "requires_review",
        "metadata_json",
        "deleted_at",
    }.issubset(events.columns.keys())
    assert {"source_event_id", "target_event_id", "relationship_type", "confidence"}.issubset(
        relationships.columns.keys()
    )
    for table in (events, relationships):
        assert "screenshot_bytes" not in table.columns
        assert "source_path" not in table.columns
