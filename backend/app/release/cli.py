"""Content-safe command-line validation for a release-candidate manifest."""

import argparse
import json
from collections.abc import Sequence
from pathlib import Path

from pydantic import ValidationError

from app.release.contracts import (
    QualificationStatus,
    ReleaseCandidateManifestV1,
    ReleaseCandidateManifestV2,
)
from app.release.gates import ReleaseGateEvaluator


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate and evaluate a ConvoCoach release-candidate manifest."
    )
    parser.add_argument("manifest", type=Path)
    parser.add_argument(
        "--expect-status",
        choices=tuple(status.value for status in QualificationStatus),
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    """Evaluate one manifest without echoing invalid content or host paths."""
    arguments = _parser().parse_args(argv)
    try:
        raw_manifest = arguments.manifest.read_text(encoding="utf-8")
        payload = json.loads(raw_manifest)
        if not isinstance(payload, dict):
            raise ValueError("release_manifest_invalid")
        version = payload.get("schema_version")
        manifest = (
            ReleaseCandidateManifestV2.model_validate_json(raw_manifest)
            if version == "release-candidate-manifest.v2"
            else ReleaseCandidateManifestV1.model_validate_json(raw_manifest)
        )
    except (OSError, UnicodeError, ValueError, json.JSONDecodeError, ValidationError):
        print(
            json.dumps(
                {
                    "schema_version": "release-gate-cli-result.v1",
                    "status": "invalid",
                    "failure_codes": ["release_manifest_invalid"],
                },
                separators=(",", ":"),
                sort_keys=True,
            )
        )
        return 2

    report = ReleaseGateEvaluator().evaluate(manifest)
    print(report.model_dump_json())
    if arguments.expect_status is not None and report.status.value != arguments.expect_status:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
