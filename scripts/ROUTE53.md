# AWS Route 53 DNS Setup

Use Route 53 to map your domain to the Canvas LMS VM IP.

## Requirements
- AWS CLI installed and configured (`aws configure`)
- Hosted Zone ID where your domain (or subdomain) is managed
- Terraform state available locally to read the VM public IP

## Quick usage
```bash
# Update A record for lms.syzygyx.com
./scripts/route53-set-record.sh \
  --hosted-zone-id Z123EXAMPLE \
  --record-name lms.syzygyx.com \
  --ttl 60
```

The script reads the public IP from Terraform output (`deploy/gcp/instance_ip`) and UPSERTs an A record to that IP.

## Integrate with setup
You can also have the `setup-gcp.sh` script update DNS automatically:
```bash
./setup-gcp.sh \
  --project-id YOUR_PROJECT_ID \
  --domain lms.syzygyx.com \
  --route53-hosted-zone-id Z123EXAMPLE
```

If `aws` CLI isn't available, the script will skip DNS and print a note to configure it manually.
