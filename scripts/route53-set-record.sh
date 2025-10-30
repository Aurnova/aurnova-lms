#!/bin/bash
set -euo pipefail

# Update an AWS Route 53 A record to point to the GCE instance IP
# Requirements: aws CLI configured, terraform state available to read instance IP
# Usage: ./scripts/route53-set-record.sh --hosted-zone-id Z12345ABC --record-name lms.syzygyx.com --ttl 60

HOSTED_ZONE_ID=""
RECORD_NAME=""
TTL="300"

print_error() { echo "[ERROR] $1" >&2; }
print_info() { echo "[INFO] $1"; }

while [[ $# -gt 0 ]]; do
  case $1 in
    --hosted-zone-id)
      HOSTED_ZONE_ID="$2"; shift 2 ;;
    --record-name)
      RECORD_NAME="$2"; shift 2 ;;
    --ttl)
      TTL="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --hosted-zone-id ZONE_ID --record-name lms.example.com [--ttl 60]"; exit 0 ;;
    *) print_error "Unknown arg: $1"; exit 1 ;;
  esac
done

if [[ -z "$HOSTED_ZONE_ID" || -z "$RECORD_NAME" ]]; then
  print_error "--hosted-zone-id and --record-name are required"; exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  print_error "aws CLI not found. Install and configure 'aws configure'."; exit 1
fi

# Get instance IP from Terraform outputs
if [[ ! -f "deploy/gcp/terraform.tfstate" ]]; then
  print_error "Terraform state not found at deploy/gcp/terraform.tfstate"; exit 1
fi

IP=$(cd deploy/gcp && terraform output -raw instance_ip)
print_info "Using IP: $IP for record: $RECORD_NAME"

CHANGE_BATCH=$(cat <<EOF
{
  "Comment": "Update ${RECORD_NAME} A record to ${IP}",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${RECORD_NAME}",
        "Type": "A",
        "TTL": ${TTL},
        "ResourceRecords": [{"Value": "${IP}"}]
      }
    }
  ]
}
EOF
)

echo "$CHANGE_BATCH" > /tmp/route53-change-batch.json
aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch file:///tmp/route53-change-batch.json

print_info "Route 53 record updated. Propagation may take a few minutes."