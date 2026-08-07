"""Evaluate granular production launch evidence without echoing invalid data."""

import argparse
import json
from collections.abc import Sequence
from pathlib import Path

from pydantic import ValidationError

from app.release.production_launch import (
    ProductionLaunchEvidenceV1,
    evaluate_production_launch,
)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Evaluate production launch evidence.")
    parser.add_argument("evidence", type=Path)
    arguments = parser.parse_args(argv)
    try:
        evidence = ProductionLaunchEvidenceV1.model_validate_json(
            arguments.evidence.read_text(encoding="utf-8")
        )
    except (OSError, UnicodeError, ValueError, ValidationError):
        print(
            json.dumps(
                {
                    "schema_version": "production-launch-cli-result.v1",
                    "status": "invalid",
                    "failure_codes": ["production_launch_evidence_invalid"],
                },
                separators=(",", ":"),
                sort_keys=True,
            )
        )
        return 2
    report = evaluate_production_launch(evidence)
    print(report.model_dump_json())
    return 0 if report.status.value == "qualified" else 1


if __name__ == "__main__":
    raise SystemExit(main())
