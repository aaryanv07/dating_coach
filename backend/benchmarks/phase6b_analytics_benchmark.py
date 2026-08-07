"""Content-free standalone benchmark for the deterministic Phase 6B engine."""

import json
from datetime import UTC, datetime, timedelta
from time import perf_counter
from uuid import UUID

from app.domain.conversation_analytics import (
    ANALYTICS_CALCULATION_VERSION,
    AnalyticsInputV1,
)
from app.domain.conversation_analytics_engine import (
    DeterministicConversationAnalyticsEngine,
)
from app.domain.conversation_events import (
    ConfirmedConversationEvent,
    ConfirmedConversationEventSequence,
    ConversationEventSpeaker,
    ConversationEventType,
)

EVENT_COUNT = 5000
ITERATIONS = 20


def _payload() -> AnalyticsInputV1:
    start = datetime(2026, 1, 1, tzinfo=UTC)
    events = tuple(
        ConfirmedConversationEvent(
            id=UUID(int=index + 1),
            position=index,
            event_type=ConversationEventType.TEXT_MESSAGE,
            speaker=(
                ConversationEventSpeaker.USER if index % 2 == 0 else ConversationEventSpeaker.OTHER
            ),
            text="Synthetic benchmark statement.",
            timestamp=start + timedelta(minutes=index),
            timestamp_is_estimated=False,
            raw_timestamp_text=None,
            source_image_index=None,
            source_region_id=None,
            ocr_confidence=None,
            classification_confidence=1.0,
            speaker_confidence=1.0,
            timestamp_confidence=1.0,
            relationship_confidence=None,
            requires_review=False,
            metadata={},
            deleted_at=None,
        )
        for index in range(EVENT_COUNT)
    )
    return AnalyticsInputV1(
        event_sequence=ConfirmedConversationEventSequence(
            schema_version="conversation-events.v1",
            events=events,
            relationships=(),
        )
    )


def main() -> None:
    """Run repeated calculations and print aggregate diagnostics only."""
    payload = _payload()
    engine = DeterministicConversationAnalyticsEngine()
    started = perf_counter()
    for _ in range(ITERATIONS):
        engine.analyze(payload)
    elapsed = perf_counter() - started
    processed = EVENT_COUNT * ITERATIONS
    print(
        json.dumps(
            {
                "calculation_version": ANALYTICS_CALCULATION_VERSION,
                "event_count": EVENT_COUNT,
                "iterations": ITERATIONS,
                "elapsed_ms": round(elapsed * 1000, 3),
                "events_per_second": round(processed / elapsed, 1),
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
