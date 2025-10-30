#!/bin/bash
set -euo pipefail

# Generate secrets for Canvas LMS deployment
# This script generates the required secrets and outputs them in a format
# suitable for GitHub Actions secrets or .env files

echo "?? Generating Canvas LMS Secrets"
echo "================================"
echo

# Generate SECRET_KEY_BASE (64 hex characters)
SECRET_KEY_BASE=$(openssl rand -hex 64)
echo "SECRET_KEY_BASE=$SECRET_KEY_BASE"
echo

# Generate ENCRYPTION_KEY (32 hex characters)  
ENCRYPTION_KEY=$(openssl rand -hex 32)
echo "ENCRYPTION_KEY=$ENCRYPTION_KEY"
echo

# Generate a secure admin password
ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
echo "CANVAS_LMS_ADMIN_PASSWORD=$ADMIN_PASSWORD"
echo

echo "?? GitHub Actions Secrets:"
echo "=========================="
echo "Copy these values to your GitHub repository secrets:"
echo
echo "SECRET_KEY_BASE = $SECRET_KEY_BASE"
echo "ENCRYPTION_KEY = $ENCRYPTION_KEY"
echo "CANVAS_LMS_ADMIN_PASSWORD = $ADMIN_PASSWORD"
echo

echo "?? .env file content:"
echo "===================="
cat << EOF
SECRET_KEY_BASE=$SECRET_KEY_BASE
ENCRYPTION_KEY=$ENCRYPTION_KEY
CANVAS_LMS_ADMIN_PASSWORD=$ADMIN_PASSWORD
EOF