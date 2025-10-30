# Aurnova LMS (Canvas LMS Deployment)

This repository provides a Docker Compose setup to run [Canvas LMS](https://github.com/instructure/canvas-lms) with PostgreSQL and Redis.

### Deploy to Google Cloud

#### Automated Deployment (Recommended)
This repository includes GitHub Actions for automated deployment:

1. **Infrastructure**: Provisions GCE VM with Terraform
2. **Deploy**: Deploys Canvas LMS application  
3. **Update**: Daily checks and updates for new versions

**Setup**:
1. Configure required [GitHub Secrets](.github/SECRETS.md)
2. Run "Infrastructure" workflow to provision VM
3. Run "Deploy Application" workflow to deploy Canvas
4. Updates run automatically daily

#### Manual Deployment
See `deploy/gcp/README.md` for manual Terraform-based provisioning and deployment commands.

## Prerequisites
- Docker and Docker Compose v2
- `openssl` (for generating secrets)

## Quick start (local)
1. Copy env template and set secrets:
   ```bash
   cd aurnova-lms
   cp .env.example .env
   openssl rand -hex 64 | pbcopy   # paste into SECRET_KEY_BASE in .env
   openssl rand -hex 32 | pbcopy   # paste into ENCRYPTION_KEY in .env
   ```
2. Start services:
   ```bash
   docker compose up -d
   ```
3. Access Canvas at http://localhost:8080

The first boot may run initializations/migrations. Watch logs:
```bash
docker compose logs -f canvas-web
```

## Configuration
- Edit `.env` for domain, timezone, account name, and initial admin user.
- Data is persisted via named volumes: `pgdata`, `redisdata`, `canvasdata`.

## Services
- `postgres` (PostgreSQL 13)
- `redis` (Redis 6)
- `canvas-web` (Canvas LMS web app)
- `canvas-jobs` (background jobs)

## Production notes
- Set `CANVAS_LMS_DOMAIN` to your public domain and terminate TLS in a reverse proxy (e.g., NGINX, Traefik, or a cloud load balancer).
- Store secrets (SECRET_KEY_BASE, ENCRYPTION_KEY) securely (e.g., GitHub Actions Secrets, cloud secret manager).
- Use managed PostgreSQL/Redis where appropriate and update `DATABASE_URL`/`REDIS_URL`.

## Maintenance
- Stop: `docker compose down`
- Update images: `docker compose pull && docker compose up -d`
- View logs: `docker compose logs -f`

## License
This repo provides orchestration only. Canvas LMS is licensed by Instructure; see their repository for terms.
