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
warn() { echo "[WARN]  $1"; }

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

# Clear any existing project config to avoid conflicts
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
if [[ -n "$CURRENT_PROJECT" && "$CURRENT_PROJECT" != "$PROJECT_ID" ]]; then
  info "Clearing current project config: $CURRENT_PROJECT"
  gcloud config unset project 2>/dev/null || true
fi

info "Creating project: $PROJECT_ID ($PROJECT_NAME)"
CREATE_ARGS=("projects" "create" "$PROJECT_ID" "--name" "$PROJECT_NAME")
if [[ -n "$ORG_ID" ]]; then
  CREATE_ARGS+=("--organization" "$ORG_ID")
fi

gcloud "${CREATE_ARGS[@]}"

info "Waiting for project to be fully created..."
sleep 5

info "Setting project in gcloud config"
gcloud config set project "$PROJECT_ID"

# Verify project is set correctly
VERIFIED_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
if [[ "$VERIFIED_PROJECT" != "$PROJECT_ID" ]]; then
  err "Failed to set project. Current: $VERIFIED_PROJECT, Expected: $PROJECT_ID"
  exit 1
fi

info "Linking billing account: $BILLING_ACCOUNT to project: $PROJECT_ID"
# Use full project format to avoid confusion
gcloud beta billing projects link "projects/$PROJECT_ID" \
  --billing-account "$BILLING_ACCOUNT" || {
  err "Failed to link billing. Trying alternative method..."
  # Alternative: use project number instead
  PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)" 2>/dev/null || echo "")
  if [[ -n "$PROJECT_NUMBER" ]]; then
    info "Using project number: $PROJECT_NUMBER"
    gcloud beta billing projects link "$PROJECT_NUMBER" \
      --billing-account "$BILLING_ACCOUNT" || {
      err "Billing link failed. You may need to link manually in Console:"
      err "https://console.cloud.google.com/billing/linkedaccount?project=$PROJECT_ID"
      exit 1
    }
  else
    err "Could not get project number. Please link billing manually:"
    err "https://console.cloud.google.com/billing/linkedaccount?project=$PROJECT_ID"
    exit 1
  fi
}

succ "Project created and selected: $PROJECT_ID"

info "Enabling common APIs (explicitly for $PROJECT_ID)"
APIS=(
  compute.googleapis.com
  iam.googleapis.com
  cloudresourcemanager.googleapis.com
  serviceusage.googleapis.com
  storage.googleapis.com
  cloudbilling.googleapis.com
)
for api in "${APIS[@]}"; do
  info "Enabling $api"
  gcloud services enable "$api" --project "$PROJECT_ID" --quiet || {
    warn "Failed to enable $api (may already be enabled or require permissions)"
  }
done

succ "All done. Next: run ./setup-gcp.sh --project-id $PROJECT_ID --domain your.domain"
