"""Provider-independent safety controls for external conversation coaching."""

from __future__ import annotations

import re
from dataclasses import dataclass
from enum import StrEnum

EXTERNAL_AI_CONSENT_TYPE = "external_ai_processing"
EXTERNAL_AI_POLICY_VERSION = "external-ai-processing-v3"


class ExternalSafetySignal(StrEnum):
    """Content-free risk labels that may cross internal service boundaries."""

    MINOR_ROMANTIC_OR_SEXUAL = "minor_romantic_or_sexual"
    BOUNDARY_EVASION = "boundary_evasion"
    COERCION = "coercion"
    STALKING = "stalking"
    DECEPTION = "deception"
    HARASSMENT = "harassment"


class ExternalSafetyViolationCode(StrEnum):
    """Stable failure reasons that never contain conversation content."""

    INPUT_BLOCKED = "input_blocked"
    OUTPUT_UNSAFE = "output_unsafe"
    SAFETY_REDIRECT_MISSING = "safety_redirect_missing"


@dataclass(frozen=True, slots=True)
class ExternalSafetyViolation(Exception):
    """A content-free safety failure suitable for safe error mapping."""

    code: ExternalSafetyViolationCode


@dataclass(frozen=True, slots=True)
class ExternalSafetyAssessment:
    """Deterministic pre-provider risk assessment."""

    signals: tuple[ExternalSafetySignal, ...]
    block_provider: bool


_AGE_PATTERN = re.compile(
    r"\b(?:i(?:'m|\s+am)|he(?:'s|\s+is)|she(?:'s|\s+is)|"
    r"they(?:'re|\s+are)|age(?:d)?|turn(?:ed|ing)?)\s+(?:only\s+)?(1[0-7])\b",
    re.IGNORECASE,
)
_ROMANTIC_OR_SEXUAL_PATTERN = re.compile(
    r"\b(?:date|dating|romantic|romance|kiss|kissing|sexy|sexual|sex|"
    r"hook\s*up|boyfriend|girlfriend|send\s+nudes?)\b",
    re.IGNORECASE,
)
_SIGNAL_PATTERNS: tuple[tuple[ExternalSafetySignal, re.Pattern[str]], ...] = (
    (
        ExternalSafetySignal.BOUNDARY_EVASION,
        re.compile(
            r"\b(?:leave\s+me\s+alone|not\s+interested|"
            r"(?:do\s+not|don't|stop)\s+(?:text|message|contact|call|follow|"
            r"come|ask|push))\b",
            re.IGNORECASE,
        ),
    ),
    (
        ExternalSafetySignal.COERCION,
        re.compile(r"\b(?:pressure|force|guilt|blackmail|threaten|coerce)\w*\b", re.I),
    ),
    (
        ExternalSafetySignal.STALKING,
        re.compile(
            r"\b(?:track(?:ing)?\s+(?:them|her|him)|follow(?:ing)?\s+"
            r"(?:them|her|him)|show\s+up\s+unannounced|wait\s+outside)\b",
            re.IGNORECASE,
        ),
    ),
    (
        ExternalSafetySignal.DECEPTION,
        re.compile(
            r"\b(?:catfish\w*|impersonat\w*|pretend\s+to\s+be|fake\s+profile|"
            r"lie\s+to\s+(?:them|her|him))\b",
            re.IGNORECASE,
        ),
    ),
    (
        ExternalSafetySignal.HARASSMENT,
        re.compile(
            r"\b(?:keep\s+(?:texting|calling|messaging)|spam(?:ming)?|"
            r"won't\s+take\s+no|will\s+not\s+take\s+no)\b",
            re.IGNORECASE,
        ),
    ),
)
_UNSAFE_DRAFT_PATTERNS = (
    re.compile(r"\bmake\s+(?:them|her|him)\s+jealous\b", re.I),
    re.compile(r"\bshow\s+up\s+unannounced\b", re.I),
    re.compile(r"\b(?:track|stalk|blackmail|threaten|coerce)\w*\b", re.I),
    re.compile(r"\b(?:pressure|guilt)\s+(?:them|her|him)\b", re.I),
    re.compile(r"\bpretend\s+to\s+be\b", re.I),
    re.compile(r"\bfake\s+(?:profile|account)\b", re.I),
    re.compile(r"\bkeep\s+(?:texting|calling|messaging)\s+until\b", re.I),
)


def assess_reviewed_messages(message_texts: tuple[str, ...]) -> ExternalSafetyAssessment:
    """Identify narrow high-risk signals without retaining or returning input text."""
    combined = "\n".join(message_texts)
    signals: list[ExternalSafetySignal] = []
    if _AGE_PATTERN.search(combined) and _ROMANTIC_OR_SEXUAL_PATTERN.search(combined):
        signals.append(ExternalSafetySignal.MINOR_ROMANTIC_OR_SEXUAL)
    for signal, pattern in _SIGNAL_PATTERNS:
        if pattern.search(combined):
            signals.append(signal)
    unique_signals = tuple(dict.fromkeys(signals))
    return ExternalSafetyAssessment(
        signals=unique_signals,
        block_provider=ExternalSafetySignal.MINOR_ROMANTIC_OR_SEXUAL in unique_signals,
    )


def validate_coaching_output_safety(
    assessment: ExternalSafetyAssessment,
    *,
    reply_drafts: tuple[str, ...],
    safety_notices: tuple[str, ...],
) -> None:
    """Reject unsafe drafts and require a safety-only redirect for detected risks."""
    if assessment.block_provider:
        raise ExternalSafetyViolation(ExternalSafetyViolationCode.INPUT_BLOCKED)
    if assessment.signals and (reply_drafts or not safety_notices):
        raise ExternalSafetyViolation(ExternalSafetyViolationCode.SAFETY_REDIRECT_MISSING)
    if any(pattern.search(draft) for draft in reply_drafts for pattern in _UNSAFE_DRAFT_PATTERNS):
        raise ExternalSafetyViolation(ExternalSafetyViolationCode.OUTPUT_UNSAFE)
