#!/bin/bash
set -euo pipefail

# Complete deployment script for Aurnova LMS
# This script creates the GCP project and deploys Canvas LMS

echo "?? Aurnova LMS - Complete Deployment"
echo "===================================="
echo

# Step 1: Get billing account
echo "Step 1: Listing billing accounts..."
BILLING_ACCOUNTS=$(gcloud billing accounts list --format="table(displayName,billingAccountId)")

if [ -z "$BILLING_ACCOUNTS" ]; then
  echo "? No billing accounts found. Please ensure billing is set up."
  exit 1
fi

echo "$BILLING_ACCOUNTS"
echo
read -p "Enter the billing account ID (e.g., 0X0X0X-0X0X0X-0X0X0X): " BILLING_ACCOUNT

if [ -z "$BILLING_ACCOUNT" ]; then
  echo "? Billing account ID is required"
  exit 1
fi

# Step 2: Create project
PROJECT_ID="aurnova-lms"
echo
echo "Step 2: Creating GCP project: $PROJECT_ID"
./scripts/create-gcp-project.sh \
  --project-id "$PROJECT_ID" \
  --project-name "Aurnova LMS" \
  --billing-account "$BILLING_ACCOUNT"

# Step 3: Deploy infrastructure and application
echo
echo "Step 3: Deploying Canvas LMS..."
./setup-gcp.sh \
  --project-id "$PROJECT_ID" \
  --domain lms.syzygyx.com \
  --route53-hosted-zone-id Z3NYTS7HNUXA87

echo
echo "? Deployment complete!"
echo "Canvas LMS should be available at: http://lms.syzygyx.com"
echo "(DNS propagation may take a few minutes)"
