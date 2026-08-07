#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
PROJECT_ID="${CONVOCOACH_GCP_PROJECT_ID:-}"
REGION="${CONVOCOACH_GCP_REGION:-asia-south1}"
TFVARS="${CONVOCOACH_TFVARS_FILE:-$ROOT/infra/gcp/production.auto.tfvars}"

if [[ -z "$PROJECT_ID" || ! -f "$TFVARS" ]]; then
  print -u2 "Set CONVOCOACH_GCP_PROJECT_ID and create the untracked production.auto.tfvars file."
  exit 1
fi
if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
  print -u2 "Production deployment requires a reviewed clean source revision."
  exit 1
fi
if ! command -v terraform >/dev/null 2>&1; then
  print -u2 "Terraform 1.8 or newer is required."
  exit 1
fi

cd "$ROOT/infra/gcp"
terraform init -input=false
terraform validate
terraform plan -input=false -out=production.tfplan
terraform apply -input=false production.tfplan

gcloud run jobs execute convocoach-migrations \
  --project "$PROJECT_ID" \
  --region "$REGION" \
  --wait

api_domain="$(sed -n 's/^api_domain[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' "$TFVARS" | head -n 1)"
if [[ -z "$api_domain" ]]; then
  print -u2 "Deployment applied, but api_domain could not be read for the smoke check."
  exit 1
fi

"$ROOT/scripts/verify_production_endpoint.zsh" "https://$api_domain"
print "production_deployment=verified"
