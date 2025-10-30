#!/bin/bash
set -euo pipefail

# Create a new GCP project and link billing, then set as default
# Requirements: gcloud authenticated; you must know ORG_ID (optional) and BILLING_ACCOUNT_ID
# Usage:
#   ./scripts/create-gcp-project.sh \
#     --project-id aurnova-lms-1234 \
#     --project-name "Aurnova LMS" \
#     --billing-account ABCDEF-ABCDEF-ABCDEF \
#     [--org-id 123456789012]

PROJECT_ID=""
PROJECT_NAME="Aurnova LMS"
ORG_ID=""
BILLING_ACCOUNT=""

err() { echo "[ERROR] $1" >&2; }
info() { echo "[INFO]  $1"; }
succ() { echo "[OK]   $1"; }

while [[ $# -gt 0 ]]; do
  case $1 in
    --project-id) PROJECT_ID="$2"; shift 2 ;;
    --project-name) PROJECT_NAME="$2"; shift 2 ;;
    --org-id) ORG_ID="$2"; shift 2 ;;
    --billing-account) BILLING_ACCOUNT="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) err "Unknown arg: $1"; exit 1 ;;
  esac
done

if [[ -z "$PROJECT_ID" || -z "$BILLING_ACCOUNT" ]]; then
  err "--project-id and --billing-account are required"; exit 1
fi

# Verify auth
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
  err "Not authenticated. Run: gcloud auth login"; exit 1
fi

info "Creating project: $PROJECT_ID ($PROJECT_NAME)"
CREATE_ARGS=("projects" "create" "$PROJECT_ID" "--name" "$PROJECT_NAME")
if [[ -n "$ORG_ID" ]]; then
  CREATE_ARGS+=("--organization" "$ORG_ID")
fi

gcloud "${CREATE_ARGS[@]}"

info "Linking billing account: $BILLING_ACCOUNT"
gcloud beta billing projects link "$PROJECT_ID" --billing-account "$BILLING_ACCOUNT"

info "Setting project in gcloud config"
gcloud config set project "$PROJECT_ID"

succ "Project created and selected: $PROJECT_ID"

info "Enable common APIs"
APIS=(
  compute.googleapis.com
  iam.googleapis.com
  cloudresourcemanager.googleapis.com
  serviceusage.googleapis.com
  storage.googleapis.com
)
for api in "${APIS[@]}"; do
  info "Enabling $api"
  gcloud services enable "$api" --quiet || true
done

succ "All done. Next: run ./setup-gcp.sh --project-id $PROJECT_ID --domain your.domain"
