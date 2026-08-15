"""Content-free hashing helpers for supply-chain and artifact evidence."""

from hashlib import sha256
from pathlib import Path

from app.release.contracts import (
    ArtifactPlatform,
    ReleaseArtifactProvenanceV1,
    SourceRevision,
    SupplyChainComponentEvidenceV1,
)


class EvidenceCollectionError(ValueError):
    """Content-free evidence collection failure."""

    def __init__(self, code: str) -> None:
        self.code = code
        super().__init__(code)


def _digest_file(path: Path) -> tuple[str, int]:
    if path.is_symlink() or not path.is_file():
        raise EvidenceCollectionError("evidence_input_not_regular_file")
    digest = sha256()
    size = 0
    with path.open("rb") as source:
        while block := source.read(1024 * 1024):
            digest.update(block)
            size += len(block)
    if size <= 0:
        raise EvidenceCollectionError("evidence_input_empty")
    return digest.hexdigest(), size


def collect_supply_chain_component(
    *,
    repository_root: Path,
    relative_path: str,
    component_id: str,
) -> SupplyChainComponentEvidenceV1:
    """Hash one allowlisted repository input without serializing its path."""
    requested = Path(relative_path)
    if requested.is_absolute() or ".." in requested.parts:
        raise EvidenceCollectionError("evidence_path_unsafe")
    root = repository_root.resolve()
    resolved = (root / requested).resolve()
    if not resolved.is_relative_to(root):
        raise EvidenceCollectionError("evidence_path_unsafe")
    digest, size = _digest_file(resolved)
    return SupplyChainComponentEvidenceV1(
        component_id=component_id,
        sha256=digest,
        size_bytes=size,
    )


def collect_artifact_provenance(
    *,
    artifact_path: Path,
    artifact_id: str,
    platform: ArtifactPlatform,
    media_type: str,
    source_revision: SourceRevision,
    source_matches_revision: bool,
    build_command_id: str,
    signed: bool,
) -> ReleaseArtifactProvenanceV1:
    """Hash one file artifact without returning its host path."""
    digest, size = _digest_file(artifact_path)
    return ReleaseArtifactProvenanceV1(
        artifact_id=artifact_id,
        platform=platform,
        media_type=media_type,
        sha256=digest,
        size_bytes=size,
        source_revision=source_revision,
        source_matches_revision=source_matches_revision,
        build_command_id=build_command_id,
        signed=signed,
    )
