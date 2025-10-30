# Required GitHub Secrets

This document lists the GitHub secrets required for automated deployment.

## Required Secrets

### GCP Authentication
- `GCP_SA_KEY`: Service account JSON key with the following permissions:
  - Compute Instance Admin
  - Service Account User
  - Storage Admin (for Terraform state)
- `GCP_PROJECT_ID`: Your Google Cloud Project ID

### SSH Access
- `SSH_PRIVATE_KEY`: Private SSH key for accessing the GCE instance
  - Generate with: `ssh-keygen -t rsa -b 4096 -C "github-actions"`
  - Add public key to GCE instance metadata or authorized_keys

### Canvas Configuration
- `CANVAS_LMS_DOMAIN`: Your Canvas domain (e.g., canvas.aurnova.com)
- `CANVAS_LMS_TIME_ZONE`: Timezone (e.g., America/New_York)
- `CANVAS_LMS_ACCOUNT_NAME`: Institution name (e.g., Aurnova University)
- `CANVAS_LMS_ADMIN_EMAIL`: Admin user email
- `CANVAS_LMS_ADMIN_PASSWORD`: Admin user password (use strong password)
- `CANVAS_LMS_ADMIN_NAME`: Admin user full name

### Security (Optional - will be generated if not provided)
- `SECRET_KEY_BASE`: Rails secret key base (64 hex chars)
- `ENCRYPTION_KEY`: Canvas encryption key (32 hex chars)

## Setting Up Secrets

1. Go to your repository settings
2. Navigate to "Secrets and variables" > "Actions"
3. Click "New repository secret"
4. Add each secret with the exact name listed above

## Generating Security Keys

If you don't provide `SECRET_KEY_BASE` and `ENCRYPTION_KEY`, they will be auto-generated during deployment:

```bash
# Generate SECRET_KEY_BASE
openssl rand -hex 64

# Generate ENCRYPTION_KEY  
openssl rand -hex 32
```

## SSH Key Setup

1. Generate SSH key pair:
   ```bash
   ssh-keygen -t rsa -b 4096 -C "github-actions" -f ~/.ssh/github-actions
   ```

2. Add public key to GCE instance:
   ```bash
   # Copy public key content
   cat ~/.ssh/github-actions.pub
   
   # Add to instance metadata or authorized_keys
   gcloud compute instances add-metadata INSTANCE_NAME \
     --metadata-from-file ssh-keys=~/.ssh/github-actions.pub
   ```

3. Add private key to GitHub secrets as `SSH_PRIVATE_KEY`:
   ```bash
   cat ~/.ssh/github-actions
   ```

## Service Account Permissions

Create a service account with these roles:
- Compute Instance Admin
- Service Account User  
- Storage Admin (for Terraform state bucket)

Or use these individual permissions:
- compute.instances.*
- compute.firewalls.*
- compute.addresses.*
- iam.serviceAccounts.actAs
- storage.objects.*