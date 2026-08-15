"""Add explicit account profile onboarding fields.

Revision ID: 20260813_0008
Revises: 20260813_0007
Create Date: 2026-08-13
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260813_0008"
down_revision: str | None = "20260813_0007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add bounded, user-authored onboarding data."""
    op.add_column("communication_profiles", sa.Column("age", sa.Integer()))
    op.add_column("communication_profiles", sa.Column("gender", sa.String(64)))
    op.add_column(
        "communication_profiles",
        sa.Column(
            "profile_setup_completed",
            sa.Boolean(),
            server_default=sa.false(),
            nullable=False,
        ),
    )
    op.create_check_constraint(
        "ck_communication_profiles_adult_age",
        "communication_profiles",
        "age IS NULL OR (age >= 18 AND age <= 120)",
    )


def downgrade() -> None:
    """Remove onboarding fields."""
    op.drop_constraint(
        "ck_communication_profiles_adult_age",
        "communication_profiles",
        type_="check",
    )
    op.drop_column("communication_profiles", "profile_setup_completed")
    op.drop_column("communication_profiles", "gender")
    op.drop_column("communication_profiles", "age")
