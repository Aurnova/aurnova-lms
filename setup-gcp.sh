#!/bin/bash
set -euo pipefail

# Aurnova LMS - Google Cloud Setup Script
# This script automates the initial setup and deployment using gcloud CLI

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PROJECT_ID=""
REGION="us-central1"
ZONE="us-central1-a"
INSTANCE_NAME="aurnova-lms"
BUCKET_NAME=""
SERVICE_ACCOUNT_NAME="aurnova-lms-sa"
SSH_KEY_NAME="aurnova-lms-key"
DOMAIN=""
ROUTE53_HOSTED_ZONE_ID=""

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists gcloud; then
        print_error "gcloud CLI is not installed. Please install it first:"
        echo "https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    if ! command_exists terraform; then
        print_error "Terraform is not installed. Please install it first:"
        echo "https://developer.hashicorp.com/terraform/downloads"
        exit 1
    fi
    
    if ! command_exists git; then
        print_error "Git is not installed. Please install it first."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Function to get project ID
get_project_id() {
    if [ -z "$PROJECT_ID" ]; then
        print_status "Available projects:"
        gcloud projects list --format="table(projectId,name)"
        echo
        read -p "Enter your GCP Project ID: " PROJECT_ID
        
        if [ -z "$PROJECT_ID" ]; then
            print_error "Project ID is required"
            exit 1
        fi
    fi
    
    # Set project
    print_status "Setting project to $PROJECT_ID"
    gcloud config set project "$PROJECT_ID"
    
    # Verify project exists and is accessible
    if ! gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
        print_error "Project $PROJECT_ID not found or not accessible"
        exit 1
    fi
    
    print_success "Project set to $PROJECT_ID"
}

# Function to enable required APIs
enable_apis() {
    print_status "Enabling required APIs..."
    
    local apis=(
        "compute.googleapis.com"
        "iam.googleapis.com"
        "storage.googleapis.com"
        "cloudresourcemanager.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        print_status "Enabling $api..."
        gcloud services enable "$api" --quiet
    done
    
    print_success "All required APIs enabled"
}

# Function to create Terraform state bucket
create_terraform_bucket() {
    if [ -z "$BUCKET_NAME" ]; then
        BUCKET_NAME="aurnova-lms-terraform-$(date +%s)"
    fi
    
    print_status "Creating Terraform state bucket: $BUCKET_NAME"
    
    # Create bucket
    gcloud storage buckets create "gs://$BUCKET_NAME" \
        --location="$REGION" \
        --uniform-bucket-level-access \
        --quiet
    
    print_success "Terraform state bucket created: gs://$BUCKET_NAME"
}

# Function to create service account
create_service_account() {
    print_status "Creating service account: $SERVICE_ACCOUNT_NAME"
    
    # Create service account
    gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
        --display-name="Aurnova LMS Service Account" \
        --description="Service account for Aurnova LMS deployment" \
        --quiet || true
    
    # Assign required roles
    local roles=(
        "roles/compute.instanceAdmin"
        "roles/compute.networkAdmin"
        "roles/iam.serviceAccountUser"
        "roles/storage.admin"
    )
    
    for role in "${roles[@]}"; do
        print_status "Assigning role: $role"
        gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
            --role="$role" \
            --quiet
    done
    
    print_success "Service account created and configured"
}

# Function to generate SSH key
generate_ssh_key() {
    local ssh_dir="$HOME/.ssh"
    local key_path="$ssh_dir/$SSH_KEY_NAME"
    
    if [ ! -f "$key_path" ]; then
        print_status "Generating SSH key: $key_path"
        ssh-keygen -t rsa -b 4096 -C "aurnova-lms" -f "$key_path" -N ""
        print_success "SSH key generated"
    else
        print_status "SSH key already exists: $key_path"
    fi
    
    # Add to SSH agent
    ssh-add "$key_path" 2>/dev/null || true
}

# Function to create Terraform backend config
create_terraform_backend() {
    print_status "Creating Terraform backend configuration..."
    
    cat > deploy/gcp/backend.tf << EOF
terraform {
  backend "gcs" {
    bucket = "$BUCKET_NAME"
    prefix = "terraform/state"
  }
}
EOF
    
    print_success "Terraform backend configuration created"
}

# Function to create terraform.tfvars
create_terraform_vars() {
    print_status "Creating terraform.tfvars..."
    
    cat > deploy/gcp/terraform.tfvars << EOF
project_id = "$PROJECT_ID"
region     = "$REGION"
zone       = "$ZONE"
instance_name = "$INSTANCE_NAME"
EOF
    
    print_success "terraform.tfvars created"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    cd deploy/gcp
    
    # Initialize Terraform
    terraform init
    
    # Plan deployment
    print_status "Planning Terraform deployment..."
    terraform plan -out=tfplan
    
    # Ask for confirmation
    echo
    print_warning "This will create a GCE instance and associated resources."
    read -p "Do you want to proceed? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Apply deployment
        print_status "Applying Terraform deployment..."
        terraform apply tfplan
        
        # Get instance IP
        INSTANCE_IP=$(terraform output -raw instance_ip)
        print_success "Infrastructure deployed successfully!"
        print_success "Instance IP: $INSTANCE_IP"
    else
        print_warning "Deployment cancelled"
        exit 0
    fi
    
    cd - >/dev/null
}

# Function to deploy application
deploy_application() {
    if [ -z "${INSTANCE_IP:-}" ]; then
        print_error "Instance IP not found. Please run infrastructure deployment first."
        exit 1
    fi
    
    print_status "Deploying Canvas LMS application..."
    
    # Generate secrets
    local secret_key_base=$(openssl rand -hex 64)
    local encryption_key=$(openssl rand -hex 32)
    
    # Create production .env
    local domain_value="${DOMAIN:-localhost}"
    cat > .env << EOF
CANVAS_LMS_DOMAIN=${domain_value}
CANVAS_LMS_TIME_ZONE=UTC
CANVAS_LMS_ACCOUNT_NAME=Aurnova University
CANVAS_LMS_ADMIN_EMAIL=admin@aurnova.com
CANVAS_LMS_ADMIN_PASSWORD=changeme123
CANVAS_LMS_ADMIN_NAME=Administrator
SECRET_KEY_BASE=$secret_key_base
ENCRYPTION_KEY=$encryption_key
EOF
    
    # Copy files to instance
    print_status "Copying files to instance..."
    rsync -avz --delete \
        --exclude='.git' \
        --exclude='.github' \
        --exclude='deploy/gcp/.terraform' \
        --exclude='deploy/gcp/terraform.tfstate*' \
        --exclude='deploy/gcp/tfplan' \
        -e "ssh -i $HOME/.ssh/$SSH_KEY_NAME -o StrictHostKeyChecking=no" \
        . ubuntu@$INSTANCE_IP:/opt/aurnova-lms/
    
    # Deploy application
    print_status "Starting Canvas LMS..."
    ssh -i "$HOME/.ssh/$SSH_KEY_NAME" -o StrictHostKeyChecking=no ubuntu@$INSTANCE_IP << 'EOF'
        cd /opt/aurnova-lms
        sudo docker compose pull
        sudo docker compose up -d
        sudo docker compose logs --tail=20
EOF
    
    print_success "Application deployed successfully!"
    if [ -n "$DOMAIN" ]; then
      print_success "Canvas LMS will be available at: http://$DOMAIN (after DNS)"
    fi
    print_success "Canvas LMS is available at: http://$INSTANCE_IP"
    print_success "Admin email: admin@aurnova.com"
    print_success "Admin password: changeme123"
}

# Function to display GitHub Actions setup
display_github_setup() {
    print_status "GitHub Actions Setup Instructions:"
    echo
    echo "To enable automated deployments, add these secrets to your GitHub repository:"
    echo
    echo "1. Go to: https://github.com/Aurnova/aurnova-lms/settings/secrets/actions"
    echo "2. Add the following secrets:"
    echo
    echo "   GCP_PROJECT_ID = $PROJECT_ID"
    echo "   GCP_SA_KEY = (service account key JSON - see below)"
    echo "   SSH_PRIVATE_KEY = (contents of $HOME/.ssh/$SSH_KEY_NAME)"
    echo "   CANVAS_LMS_DOMAIN = your-domain.com"
    echo "   CANVAS_LMS_ADMIN_EMAIL = admin@your-domain.com"
    echo "   CANVAS_LMS_ADMIN_PASSWORD = your-secure-password"
    echo
    echo "3. Download service account key:"
    echo "   gcloud iam service-accounts keys create ~/aurnova-lms-sa-key.json \\"
    echo "     --iam-account=$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com"
    echo "   cat ~/aurnova-lms-sa-key.json"
    echo
    echo "4. Copy the JSON content and add it as GCP_SA_KEY secret"
    echo
}

# Main function
main() {
    echo "?? Aurnova LMS - Google Cloud Setup"
    echo "=================================="
    echo
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --project-id)
                PROJECT_ID="$2"
                shift 2
                ;;
            --region)
                REGION="$2"
                shift 2
                ;;
            --zone)
                ZONE="$2"
                shift 2
                ;;
            --instance-name)
                INSTANCE_NAME="$2"
                shift 2
                ;;
            --bucket-name)
                BUCKET_NAME="$2"
                shift 2
                ;;
            --domain)
                DOMAIN="$2"
                shift 2
                ;;
            --route53-hosted-zone-id)
                ROUTE53_HOSTED_ZONE_ID="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo
                echo "Options:"
                echo "  --project-id ID      GCP Project ID"
                echo "  --region REGION      GCP region (default: us-central1)"
                echo "  --zone ZONE          GCP zone (default: us-central1-a)"
                echo "  --instance-name NAME Instance name (default: aurnova-lms)"
                echo "  --bucket-name NAME   Terraform state bucket name"
                echo "  --domain FQDN        Public domain (e.g., lms.example.com)"
                echo "  --route53-hosted-zone-id Z  Route 53 Hosted Zone ID (optional)"
                echo "  --help               Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Check if user is authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_error "Not authenticated with gcloud. Please run: gcloud auth login"
        exit 1
    fi
    
    # Run setup steps
    check_prerequisites
    get_project_id
    enable_apis
    create_terraform_bucket
    create_service_account
    generate_ssh_key
    create_terraform_backend
    create_terraform_vars
    deploy_infrastructure
    deploy_application

    # Optionally update Route 53 DNS
    if [ -n "$ROUTE53_HOSTED_ZONE_ID" ] && [ -n "$DOMAIN" ]; then
      if command -v aws >/dev/null 2>&1; then
        print_status "Updating Route 53 A record $DOMAIN -> $INSTANCE_IP"
        ./scripts/route53-set-record.sh --hosted-zone-id "$ROUTE53_HOSTED_ZONE_ID" --record-name "$DOMAIN" --ttl 60 || print_warning "Route 53 update failed; configure DNS manually."
      else
        print_warning "aws CLI not found. Skipping Route 53 update."
      fi
    fi
    display_github_setup
    
    print_success "Setup completed successfully! ??"
}

# Run main function
main "$@"