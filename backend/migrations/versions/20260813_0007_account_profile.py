"""Extend owner-scoped communication profiles.

Revision ID: 20260813_0007
Revises: 20260812_0006
Create Date: 2026-08-13
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260813_0007"
down_revision: str | None = "20260812_0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add explicit user profile context and a private bounded photo."""
    op.add_column("communication_profiles", sa.Column("job_title", sa.String(100)))
    op.add_column(
        "communication_profiles",
        sa.Column("likes", sa.JSON(), server_default=sa.text("'[]'"), nullable=False),
    )
    op.add_column(
        "communication_profiles",
        sa.Column("looking_for", sa.JSON(), server_default=sa.text("'[]'"), nullable=False),
    )
    op.add_column("communication_profiles", sa.Column("profile_photo_bytes", sa.LargeBinary()))
    op.add_column("communication_profiles", sa.Column("profile_photo_content_type", sa.String(32)))
    op.add_column(
        "communication_profiles", sa.Column("profile_photo_updated_at", sa.DateTime(timezone=True))
    )


def downgrade() -> None:
    """Remove profile extensions, including private photo bytes."""
    op.drop_column("communication_profiles", "profile_photo_updated_at")
    op.drop_column("communication_profiles", "profile_photo_content_type")
    op.drop_column("communication_profiles", "profile_photo_bytes")
    op.drop_column("communication_profiles", "looking_for")
    op.drop_column("communication_profiles", "likes")
    op.drop_column("communication_profiles", "job_title")
