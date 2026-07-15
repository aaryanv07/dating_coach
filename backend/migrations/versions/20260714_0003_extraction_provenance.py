"""Add content-free extraction provenance.

Revision ID: 20260714_0003
Revises: 20260714_0002
Create Date: 2026-07-14
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260714_0003"
down_revision: str | None = "20260714_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Record only extraction provider and pipeline version metadata."""
    op.add_column(
        "conversations",
        sa.Column("extraction_metadata", sa.JSON(), nullable=True),
    )
    op.add_column(
        "messages",
        sa.Column("visible_timestamp_text", sa.String(length=80), nullable=True),
    )


def downgrade() -> None:
    """Remove extraction provenance without affecting confirmed messages."""
    op.drop_column("messages", "visible_timestamp_text")
    op.drop_column("conversations", "extraction_metadata")
