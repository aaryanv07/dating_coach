"""Protected, aggregate-only operator routes."""

from fastapi import APIRouter, Response

from app.api.dependencies import DatabaseSession, UserMetricsOperator
from app.db.models import utc_now
from app.repositories.user_metrics import UserMetricsRepository
from app.schemas.admin import UserMetricsV1

router = APIRouter(prefix="/api/v1/admin", tags=["operator"])


@router.get("/user-metrics", response_model=UserMetricsV1)
async def read_user_metrics(
    response: Response,
    _: UserMetricsOperator,
    session: DatabaseSession,
) -> UserMetricsV1:
    """Return content-free account aggregates to an authorized operator."""
    generated_at = utc_now()
    snapshot = await UserMetricsRepository(session).snapshot(evaluated_at=generated_at)
    response.headers["Cache-Control"] = "private, no-store, max-age=0"
    response.headers["Pragma"] = "no-cache"
    return UserMetricsV1(
        generated_at=generated_at,
        total_registered_accounts=snapshot.total_registered_accounts,
        active_accounts=snapshot.active_accounts,
        deleted_accounts=snapshot.deleted_accounts,
        new_registered_accounts_7d=snapshot.new_registered_accounts_7d,
        new_registered_accounts_30d=snapshot.new_registered_accounts_30d,
        paid_active_accounts=snapshot.paid_active_accounts,
        free_active_accounts=snapshot.free_active_accounts,
        ai_active_accounts_24h=snapshot.ai_active_accounts_24h,
        ai_active_accounts_7d=snapshot.ai_active_accounts_7d,
        ai_active_accounts_30d=snapshot.ai_active_accounts_30d,
    )
