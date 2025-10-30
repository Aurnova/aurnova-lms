#!/bin/bash
set -euo pipefail

# Quick deployment script for existing infrastructure
# This script assumes infrastructure is already deployed and just updates the application

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get instance IP from Terraform
get_instance_ip() {
    if [ ! -f "deploy/gcp/terraform.tfstate" ]; then
        print_error "Terraform state not found. Please run setup-gcp.sh first."
        exit 1
    fi
    
    cd deploy/gcp
    INSTANCE_IP=$(terraform output -raw instance_ip 2>/dev/null || echo "")
    cd - >/dev/null
    
    if [ -z "$INSTANCE_IP" ]; then
        print_error "Could not get instance IP from Terraform state"
        exit 1
    fi
    
    print_status "Instance IP: $INSTANCE_IP"
}

# Deploy application
deploy_app() {
    local instance_ip="$1"
    local ssh_key="$HOME/.ssh/aurnova-lms-key"
    
    if [ ! -f "$ssh_key" ]; then
        print_error "SSH key not found: $ssh_key"
        print_error "Please run setup-gcp.sh first to generate the SSH key"
        exit 1
    fi
    
    print_status "Deploying application to $instance_ip..."
    
    # Copy files to instance
    print_status "Copying files..."
    rsync -avz --delete \
        --exclude='.git' \
        --exclude='.github' \
        --exclude='deploy/gcp/.terraform' \
        --exclude='deploy/gcp/terraform.tfstate*' \
        --exclude='deploy/gcp/tfplan' \
        -e "ssh -i $ssh_key -o StrictHostKeyChecking=no" \
        . ubuntu@$instance_ip:/opt/aurnova-lms/
    
    # Deploy application
    print_status "Starting Canvas LMS..."
    ssh -i "$ssh_key" -o StrictHostKeyChecking=no ubuntu@$instance_ip << 'EOF'
        cd /opt/aurnova-lms
        
        # Pull latest images
        sudo docker compose pull
        
        # Stop existing containers
        sudo docker compose down || true
        
        # Start with new configuration
        sudo docker compose up -d
        
        # Wait a moment for startup
        sleep 10
        
        # Show logs
        sudo docker compose logs --tail=20
EOF
    
    print_success "Application deployed successfully!"
    print_success "Canvas LMS is available at: http://$instance_ip"
}

# Health check
health_check() {
    local instance_ip="$1"
    
    print_status "Performing health check..."
    
    for i in {1..30}; do
        if curl -f -s "http://$instance_ip" > /dev/null 2>&1; then
            print_success "Canvas is responding at http://$instance_ip"
            return 0
        fi
        print_status "Attempt $i/30: Canvas not ready yet..."
        sleep 10
    done
    
    print_error "Canvas failed to start after 5 minutes"
    return 1
}

# Main function
main() {
    echo "?? Quick Deploy - Aurnova LMS"
    echo "============================="
    echo
    
    get_instance_ip
    deploy_app "$INSTANCE_IP"
    
    if health_check "$INSTANCE_IP"; then
        print_success "Deployment completed successfully! ??"
    else
        print_error "Deployment failed health check"
        exit 1
    fi
}

# Run main function
main "$@"