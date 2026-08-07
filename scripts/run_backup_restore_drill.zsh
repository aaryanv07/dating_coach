#!/bin/zsh
set -euo pipefail

PROJECT_ID="${CONVOCOACH_GCP_PROJECT_ID:-}"
REGION="${CONVOCOACH_GCP_REGION:-asia-south1}"
SOURCE_INSTANCE="${CONVOCOACH_SQL_INSTANCE:-convocoach-production}"

if [[ "${CONVOCOACH_APPROVE_COSTED_RESTORE_DRILL:-}" != "YES" ]]; then
  print -u2 "Set CONVOCOACH_APPROVE_COSTED_RESTORE_DRILL=YES to authorize the temporary billed instance."
  exit 1
fi
if [[ -z "$PROJECT_ID" ]]; then
  print -u2 "Set CONVOCOACH_GCP_PROJECT_ID."
  exit 1
fi

backup_id="$(gcloud sql backups list \
  --project "$PROJECT_ID" \
  --instance "$SOURCE_INSTANCE" \
  --filter='status=SUCCESSFUL' \
  --sort-by='~endTime' \
  --limit=1 \
  --format='value(id)')"
if [[ -z "$backup_id" ]]; then
  print -u2 "No successful backup is available for the isolated drill."
  exit 1
fi

target="convocoach-restore-drill-$(date -u +%Y%m%d%H%M%S)"
gcloud sql backups restore "$backup_id" \
  --project "$PROJECT_ID" \
  --backup-instance "$SOURCE_INSTANCE" \
  --restore-instance "$target" \
  --region "$REGION" \
  --database-version POSTGRES_16 \
  --availability-type zonal \
  --tier db-custom-1-3840 \
  --no-assign-ip \
  --network "projects/$PROJECT_ID/global/networks/convocoach-production" \
  --no-backup \
  --no-deletion-protection

print "restore_drill_instance=$target"
print "restore_drill_backup_id=$backup_id"
print "The restore completed. Schema/revision verification and controlled deletion remain mandatory before evidence may pass."
