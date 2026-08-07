"""Privacy-safe request correlation and structured operational logging."""

import json
import logging
from datetime import UTC, datetime
from uuid import UUID, uuid4

CORRELATION_HEADER = "X-Correlation-ID"
OPERATIONAL_LOGGER_NAME = "convocoach.operations"


def resolve_correlation_id(candidate: str | None) -> UUID:
    """Accept one canonical UUID or generate a new opaque request identifier."""
    if candidate is not None:
        normalized = candidate.strip().lower()
        try:
            parsed = UUID(normalized)
        except ValueError:
            pass
        else:
            if str(parsed) == normalized:
                return parsed
    return uuid4()


class PrivacySafeJsonFormatter(logging.Formatter):
    """Serialize only the allowlisted content-free operational fields."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, str | int] = {
            "timestamp": datetime.fromtimestamp(record.created, UTC)
            .isoformat()
            .replace("+00:00", "Z"),
            "level": record.levelname,
            "event": str(getattr(record, "event", "operational_event")),
        }
        for name in (
            "correlation_id",
            "method",
            "route",
            "lifecycle",
        ):
            value = getattr(record, name, None)
            if isinstance(value, str):
                payload[name] = value
        for name in ("status_code", "duration_ms"):
            value = getattr(record, name, None)
            if isinstance(value, int):
                payload[name] = value
        return json.dumps(payload, sort_keys=True, separators=(",", ":"))


def configure_operational_logging(log_level: str) -> logging.Logger:
    """Configure one isolated logger without attaching sensitive application data."""
    logger = logging.getLogger(OPERATIONAL_LOGGER_NAME)
    logger.setLevel(log_level)
    logger.propagate = False
    if not any(
        isinstance(handler.formatter, PrivacySafeJsonFormatter) for handler in logger.handlers
    ):
        handler = logging.StreamHandler()
        handler.setFormatter(PrivacySafeJsonFormatter())
        logger.addHandler(handler)
    return logger
