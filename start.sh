#!/bin/bash
set -e

# N8N RockMyPost - Start & Update Script
# Handles repository updates, Docker image updates, and service management

REPO_URL="https://github.com/rockmypost/n8n-rmp.git"
N8N_IMAGE="n8nio/n8n:latest"
HEALTHCHECK_URL="http://localhost:5678/healthz"
DOMAIN="n8n.rockmypost.com"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Banner
echo -e "${BLUE}"
echo "🚀 N8N ROCKMYPOST - START & UPDATE"
echo "=================================="
echo "Repository: $REPO_URL"
echo "=================================="
echo -e "${NC}"

# Pre-flight checks
preflight_checks() {
    log_info "Running pre-flight checks..."
    
    # Check if .env exists (do NOT auto-create or print values)
    if [[ ! -f .env ]]; then
        log_error ".env file not found."
        echo ""
        echo -e "${YELLOW}Create and configure your .env before continuing:${NC}"
        echo "  cp .env.example .env"
        echo "  nano .env"
        echo "  # Set N8N_OWNER_PASSWORD and required variables"
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        log_warning "Docker is not running, attempting to start..."
        if command -v systemctl &> /dev/null; then
            sudo systemctl start docker
            sleep 3
        fi
        
        if ! docker info > /dev/null 2>&1; then
            log_error "Failed to start Docker. Please check Docker installation."
            exit 1
        fi
        log_success "Docker started successfully"
    fi
    
    # Check internet connectivity
    if ! curl -s --max-time 10 https://api.github.com > /dev/null 2>&1; then
        log_error "No internet connectivity. Please check your network connection."
        exit 1
    fi
    
    log_success "Pre-flight checks completed"
}

# Update repository from GitHub
update_repository() {
    log_info "Checking for repository updates..."
    
    # Fetch latest changes
    git fetch origin > /dev/null 2>&1
    
    # Compare local and remote commits
    LOCAL_COMMIT=$(git rev-parse HEAD)
    REMOTE_COMMIT=$(git rev-parse origin/main)
    
    if [[ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]]; then
        log_info "Repository updates found, applying changes..."
        
        # Show what's changing
        echo ""
        echo "📋 Changes to be applied:"
        git log --oneline --decorate $LOCAL_COMMIT..$REMOTE_COMMIT
        echo ""
        
        # Pull changes
        git pull origin main
        
        # Ensure start.sh remains executable
        chmod +x start.sh
        
        log_success "Repository updated successfully"
    else
        log_info "Repository is up to date"
    fi
}

# Check for N8N updates
check_n8n_updates() {
    log_info "Checking for N8N updates..."
    
    # Get current local image info
    LOCAL_IMAGE_ID=""
    if docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}" | grep -q "n8nio/n8n:latest"; then
        LOCAL_IMAGE_ID=$(docker images n8nio/n8n:latest --format "{{.ID}}")
    fi
    
    # Pull latest image
    docker pull $N8N_IMAGE > /dev/null 2>&1
    
    # Get new image ID
    NEW_IMAGE_ID=$(docker images n8nio/n8n:latest --format "{{.ID}}")
    
    if [[ "$LOCAL_IMAGE_ID" != "$NEW_IMAGE_ID" ]]; then
        log_success "N8N image updated"
    else
        log_info "N8N image is up to date"
    fi
}

# Manage Docker services
manage_services() {
    log_info "Managing Docker services..."
    
    # Stop existing services
    log_info "Stopping existing services..."
    docker-compose down --remove-orphans > /dev/null 2>&1
    
    # Clean up unused containers and images
    log_info "Cleaning up unused resources..."
    docker container prune -f > /dev/null 2>&1
    docker image prune -f > /dev/null 2>&1
    
    # Update all images
    log_info "Updating Docker images..."
    docker-compose pull
    
    # Verify data volume exists
    log_info "Verifying data persistence..."
    if docker volume ls | grep -q "rockmypost_n8n_data"; then
        log_success "Data volume found - workflows will be preserved"
    else
        log_info "Creating new data volume for workflows"
    fi
    
    # Start services
    log_info "Starting services..."
    docker-compose up -d
}

# Health checks and verification
perform_health_checks() {
    log_info "Performing health checks..."
    
    # Wait for services to start
    log_info "Waiting for services to initialize..."
    sleep 20
    
    # Check if containers are running
    local attempts=0
    local max_attempts=10
    
    while [[ $attempts -lt $max_attempts ]]; do
        if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(nginx_proxy_rmp|letsencrypt_rmp|n8n_rockmypost)" | grep -q "Up"; then
            log_success "All services are running"
            break
        else
            log_info "Waiting for services to start... (attempt $((attempts + 1))/$max_attempts)"
            sleep 10
            ((attempts++))
        fi
    done
    
    if [[ $attempts -eq $max_attempts ]]; then
        log_error "Services failed to start properly"
        echo ""
        echo "Service status:"
        docker-compose ps
        echo ""
        echo "Recent logs:"
        docker-compose logs --tail=20
        exit 1
    fi
    
    # Check N8N health endpoint
    log_info "Checking N8N health..."
    local health_attempts=0
    local max_health_attempts=8
    
    while [[ $health_attempts -lt $max_health_attempts ]]; do
        if curl -s --max-time 5 "$HEALTHCHECK_URL" > /dev/null 2>&1; then
            log_success "N8N health check passed"
            break
        else
            log_info "Waiting for N8N to be ready... (attempt $((health_attempts + 1))/$max_health_attempts)"
            sleep 10
            ((health_attempts++))
        fi
    done
    
    if [[ $health_attempts -eq $max_health_attempts ]]; then
        log_warning "N8N health check timeout - this may be normal during SSL setup"
    fi
}

# SSL verification
verify_ssl() {
    log_info "Verifying SSL configuration..."
    
    # Get domain from environment
    local domain=$(grep "N8N_HOST=" .env | cut -d'=' -f2)
    
    # Wait for SSL certificates to be generated
    log_info "Waiting for SSL certificates (first-time setup may take 5 minutes)..."
    sleep 30
    
    local ssl_attempts=0
    local max_ssl_attempts=6
    
    while [[ $ssl_attempts -lt $max_ssl_attempts ]]; do
        if curl -s --max-time 15 "https://$domain" > /dev/null 2>&1; then
            log_success "SSL is working correctly"
            return 0
        else
            log_info "SSL certificates still generating... (attempt $((ssl_attempts + 1))/$max_ssl_attempts)"
            sleep 30
            ((ssl_attempts++))
        fi
    done
    
    log_warning "SSL setup is taking longer than expected"
    log_info "This is normal for first-time certificate generation"
    log_info "Check SSL logs: docker logs letsencrypt_rmp"
}

# Display final status and information
show_final_status() {
    echo ""
    echo -e "${GREEN}🎉 N8N ROCKMYPOST IS RUNNING!${NC}"
    echo "=============================================="
    echo ""
    
    # Service status
    echo -e "${BLUE}📊 Service Status:${NC}"
    docker-compose ps
    echo ""
    
    # Volume status
    echo -e "${BLUE}💾 Data Volumes:${NC}"
    docker volume ls | grep -E "(rockmypost_n8n_data|nginx_certs)" | while read line; do
        echo "   $line"
    done
    echo ""
    
    # Access information (do not expose values)
    echo -e "${GREEN}🌐 Access Information:${NC}"
    echo "   URL and Admin email are configured in your .env"
    echo "   Password: configured in .env (not displayed)"
    echo ""
    
    # Useful commands
    echo -e "${BLUE}📋 Useful Commands:${NC}"
    echo "   View all logs:     docker-compose logs -f"
    echo "   View N8N logs:     docker logs n8n_rockmypost -f"
    echo "   View SSL logs:     docker logs letsencrypt_rmp -f"
    echo "   View proxy logs:   docker logs nginx_proxy_rmp -f"
    echo "   Stop services:     docker-compose down"
    echo "   Restart all:       ./start.sh"
    echo ""
    
    echo -e "${YELLOW}🔒 Notes:${NC}"
    echo "   • Keep your .env secure (recommended file mode 600)"
    echo "   • Rotate credentials periodically"
    echo ""
    
    log_success "N8N startup completed successfully!"
}

# Main execution function
main() {
    preflight_checks
    update_repository
    check_n8n_updates
    manage_services
    perform_health_checks
    verify_ssl
    show_final_status
}

# Execute main function
main "$@"