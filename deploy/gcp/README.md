# Deploy to Google Cloud (GCE + Docker Compose)

This deployment uses a single Compute Engine VM with Docker Compose to run Canvas LMS. It provisions:
- Static public IP
- Firewall for SSH (22), HTTP (80/8080), HTTPS (443)
- Ubuntu 22.04 VM with a startup script that installs Docker + Compose

## Prerequisites
- Terraform >= 1.5
- gcloud SDK installed and authenticated: `gcloud auth application-default login`
- A GCP project with billing enabled

## Steps
1. Configure variables (either via CLI flags, tfvars, or environment):
   - `project_id` (required)
   - Optional: `region`, `zone`, `machine_type`, `boot_disk_size_gb`, `instance_name`

2. Initialize and apply:
   ```bash
   cd deploy/gcp
   terraform init
   terraform apply -auto-approve -var project_id=YOUR_PROJECT
   ```

3. Capture the VM IP:
   ```bash
   terraform output instance_ip
   ```

4. Copy project files and .env to the VM and start:
   ```bash
   # assuming current dir is repo root
   IP=$(cd deploy/gcp && terraform output -raw instance_ip)
   rsync -avz --delete . ubuntu@$IP:/opt/aurnova-lms/
   ssh ubuntu@$IP 'cd /opt/aurnova-lms && sudo docker compose pull && sudo docker compose up -d'
   ```

5. Access Canvas:
   - http://IP_ADDRESS (port 80) or map a DNS A-record to the IP and use your domain

## TLS and Domain (optional)
- Put a reverse proxy (NGINX/Traefik) in front on the same VM or in your edge/load balancer to terminate TLS for your domain.
- Update `CANVAS_LMS_DOMAIN` in `.env` to your FQDN.

## Using managed databases (optional)
- Replace `postgres` with Cloud SQL and update `DATABASE_URL`.
- Replace `redis` with Memorystore and update `REDIS_URL`.

## Maintenance
- Update: `ssh ubuntu@IP 'cd /opt/aurnova-lms && sudo docker compose pull && sudo docker compose up -d'`
- Logs: `ssh ubuntu@IP 'sudo docker compose logs -f'`
- Destroy infra: `terraform destroy -var project_id=YOUR_PROJECT`
