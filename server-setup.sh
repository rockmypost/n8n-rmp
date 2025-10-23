#!/bin/bash
set -e

# N8N RockMyPost - Server Setup Script
# Installs Docker, clones repository, and prepares environment

REPO_URL="https://github.com/rockmypost/n8n-rmp.git"
PROJECT_DIR="n8n-rmp"
REQUIRED_PORTS=(22 80 443)

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
echo "🚀 N8N ROCKMYPOST - SERVER SETUP"
echo "================================="
echo "AWS Instance: 13.59.208.230"
echo "Domain: n8n.rockmypost.com"
echo "================================="
echo -e "${NC}"

# Check root permissions
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root or with sudo"
   echo "Usage: sudo bash server-setup.sh"
   exit 1
fi

# Get current user info
CURRENT_USER="${SUDO_USER:-root}"
if [[ "$CURRENT_USER" == "root" ]]; then
    USER_HOME="/root"
else
    USER_HOME="/home/$CURRENT_USER"
fi

log_info "Running as root, target user: $CURRENT_USER"

# Detect operating system
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    log_error "Cannot detect operating system"
    exit 1
fi

log_info "Detected system: $OS $VER"

# Install dependencies based on OS
install_dependencies() {
    if [[ "$OS" == *"Ubuntu"* || "$OS" == *"Debian"* ]]; then
        log_info "Installing dependencies for Ubuntu/Debian..."
        
        # Update system
        apt-get update -qq
        apt-get upgrade -y -qq
        
        # Install basic tools
        apt-get install -y -qq \
            curl wget git unzip nano htop net-tools \
            software-properties-common apt-transport-https \
            ca-certificates gnupg lsb-release ufw
        
        # Install Docker
        log_info "Installing Docker..."
        apt-get remove -y -qq docker docker-engine docker.io containerd runc 2>/dev/null || true
        
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
        
        apt-get update -qq
        apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # Configure firewall
        log_info "Configuring firewall..."
        ufw --force enable
        for port in "${REQUIRED_PORTS[@]}"; do
            ufw allow $port/tcp
        done
        
    elif [[ "$OS" == *"CentOS"* || "$OS" == *"Red Hat"* || "$OS" == *"Amazon Linux"* ]]; then
        log_info "Installing dependencies for CentOS/RHEL/Amazon Linux..."
        
        # Update system
        yum update -y -q
        
        # Install basic tools
        yum install -y -q \
            curl wget git unzip nano htop net-tools \
            yum-utils device-mapper-persistent-data lvm2
        
        # Install Docker
        log_info "Installing Docker..."
        yum remove -y -q docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
        
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # Configure firewall
        log_info "Configuring firewall..."
        systemctl start firewalld 2>/dev/null || true
        systemctl enable firewalld 2>/dev/null || true
        firewall-cmd --permanent --add-service=ssh 2>/dev/null || true
        firewall-cmd --permanent --add-service=http 2>/dev/null || true
        firewall-cmd --permanent --add-service=https 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
        
    else
        log_error "Unsupported operating system: $OS"
        echo "Supported systems: Ubuntu, Debian, CentOS, RHEL, Amazon Linux"
        exit 1
    fi
}

# Install Docker Compose standalone
install_docker_compose() {
    log_info "Installing Docker Compose standalone..."
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")' || echo "v2.20.0")
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
}

# Configure Docker service
configure_docker() {
    log_info "Configuring Docker service..."
    systemctl start docker
    systemctl enable docker
    
    # Add user to docker group
    if [[ "$CURRENT_USER" != "root" ]]; then
        usermod -aG docker $CURRENT_USER
        log_success "User $CURRENT_USER added to docker group"
    fi
}

# Clone repository and setup project
setup_project() {
    log_info "Setting up N8N project..."
    
    # Navigate to user home directory
    cd "$USER_HOME"
    
    # Clone or update repository
    if [[ -d "$PROJECT_DIR" ]]; then
        log_warning "Directory $PROJECT_DIR already exists, updating..."
        cd "$PROJECT_DIR"
        git pull origin main
    else
        log_info "Cloning repository..."
        git clone "$REPO_URL" "$PROJECT_DIR"
        cd "$PROJECT_DIR"
    fi
    
    # Fix ownership
    chown -R $CURRENT_USER:$CURRENT_USER "$USER_HOME/$PROJECT_DIR"
    
    # Setup environment file (create empty .env to force manual configuration)
    if [[ ! -f .env ]]; then
        cat > .env << 'EOF'
# N8N Configuration - REQUIRED: Configure all values before running ./start.sh
# Copy from .env.example and customize with your actual values

# Core Settings
N8N_HOST=
N8N_PROTOCOL=
WEBHOOK_URL=
VUE_APP_URL=
TIMEZONE=

# Security Settings
N8N_USER_MANAGEMENT_DISABLED=
N8N_OWNER_EMAIL=
N8N_OWNER_PASSWORD=

# Optional Settings
N8N_BASIC_AUTH_ACTIVE=
GOOGLE_OAUTH_CLIENT_ID=
GOOGLE_OAUTH_CLIENT_SECRET=
N8N_PAYLOAD_SIZE_MAX=
N8N_METRICS=
N8N_LOG_LEVEL=
N8N_PERSISTED_BINARY_DATA_TTL=

# SSL Configuration
LETSENCRYPT_EMAIL=
EOF
        chmod 600 .env
        log_success "Created empty .env file - configuration required"
        log_warning "IMPORTANT: Edit .env with your actual values before running ./start.sh"
    else
        log_warning ".env file already exists"
    fi
    
    # Make scripts executable
    chmod +x start.sh
    log_success "Made start.sh executable"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    echo "Docker version:"
    docker --version
    
    echo "Docker Compose version:"
    docker-compose --version
    
    echo "Git version:"
    git --version
    
    # Test Docker
    log_info "Testing Docker..."
    if docker run --rm hello-world > /dev/null 2>&1; then
        log_success "Docker test passed"
    else
        log_error "Docker test failed"
        exit 1
    fi
}

# Main execution
main() {
    install_dependencies
    install_docker_compose
    configure_docker
    setup_project
    verify_installation
    
    # Final success message
    echo ""
    echo -e "${GREEN}🎉 SERVER SETUP COMPLETED SUCCESSFULLY!${NC}"
    echo "================================================"
    echo ""
    echo -e "${GREEN}✅ Installed and Configured:${NC}"
    echo "   • Docker CE (latest version)"
    echo "   • Docker Compose"
    echo "   • Git and development tools"
    echo "   • Firewall (ports: ${REQUIRED_PORTS[*]})"
    echo ""
    echo -e "${GREEN}✅ Repository Setup:${NC}"
    echo "   • Repository: $REPO_URL"
    echo "   • Location: $USER_HOME/$PROJECT_DIR"
    echo "   • Environment: .env created (empty - requires configuration)"
    echo ""
    echo -e "${BLUE}🚀 Next Steps:${NC}"
    echo "   1. Restart your SSH session (for Docker permissions):"
    echo "      exit"
    echo "      ssh -i \"n8n-rmp.pem\" ubuntu@ec2-13-59-208-230.us-east-2.compute.amazonaws.com"
    echo ""
    echo "   2. Configure your environment (REQUIRED):"
    echo "      cd $PROJECT_DIR"
    echo "      cp .env.example .env"
    echo "      nano .env"
    echo "      # Configure ALL values: N8N_HOST, N8N_OWNER_EMAIL, N8N_OWNER_PASSWORD, etc."
    echo ""
    echo "   3. Start N8N services:"
    echo "      ./start.sh"
    echo ""
    echo -e "${GREEN}🌐 Access N8N at: https://n8n.rockmypost.com${NC}"
    echo -e "${YELLOW}🔒 SSL certificates will generate automatically on first run${NC}"
    echo ""
    echo -e "${BLUE}📋 Firewall Status:${NC}"
    echo "   • Port 22 (SSH): Open"
    echo "   • Port 80 (HTTP): Open for SSL verification"
    echo "   • Port 443 (HTTPS): Open for N8N access"
    echo ""
}

# Execute main function
main "$@"