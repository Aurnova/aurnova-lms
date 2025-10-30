# Deployment Scripts

This directory contains utility scripts for managing the Aurnova LMS deployment.

## Scripts

### `generate-secrets.sh`
Generates secure secrets for Canvas LMS deployment.

```bash
./scripts/generate-secrets.sh
```

Outputs:
- `SECRET_KEY_BASE` (64 hex characters)
- `ENCRYPTION_KEY` (32 hex characters)  
- `CANVAS_LMS_ADMIN_PASSWORD` (secure password)

Use these values for GitHub Actions secrets or `.env` files.

### `quick-deploy.sh`
Quickly deploys application updates to existing infrastructure.

```bash
./scripts/quick-deploy.sh
```

Requirements:
- Infrastructure already deployed (run `setup-gcp.sh` first)
- SSH key exists at `~/.ssh/aurnova-lms-key`
- Terraform state available

This script:
1. Gets instance IP from Terraform state
2. Syncs files to the instance
3. Updates Docker containers
4. Performs health check

## Usage Examples

### Initial Setup
```bash
# Clone repository
git clone https://github.com/Aurnova/aurnova-lms.git
cd aurnova-lms

# Run full setup
./setup-gcp.sh --project-id your-project-id

# Generate secrets for GitHub Actions
./scripts/generate-secrets.sh
```

### Application Updates
```bash
# After making changes to the code
./scripts/quick-deploy.sh
```

### Secret Management
```bash
# Generate new secrets
./scripts/generate-secrets.sh > new-secrets.txt

# Update GitHub Actions secrets with the output
```

## Troubleshooting

### SSH Key Issues
If you get SSH connection errors:
```bash
# Check if SSH key exists
ls -la ~/.ssh/aurnova-lms-key*

# Re-run setup to regenerate keys
./setup-gcp.sh --project-id your-project-id
```

### Terraform State Issues
If Terraform state is missing:
```bash
# Check if state exists
ls -la deploy/gcp/terraform.tfstate*

# Re-run setup to recreate infrastructure
./setup-gcp.sh --project-id your-project-id
```

### Health Check Failures
If Canvas doesn't start properly:
```bash
# Check instance logs
ssh -i ~/.ssh/aurnova-lms-key ubuntu@INSTANCE_IP 'cd /opt/aurnova-lms && sudo docker compose logs'
```