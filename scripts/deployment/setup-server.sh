#!/bin/bash
set -euo pipefail

# HRAS Production Server Setup Script
# Prepares a clean Ubuntu/Amazon Linux server for HRAS deployment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        log_error "Cannot detect operating system"
        exit 1
    fi

    log_info "Detected OS: $OS $VER"
}

install_docker() {
    log_info "Installing Docker..."

    if command -v docker >/dev/null 2>&1; then
        log_info "Docker already installed"
        return 0
    fi

    if [[ "$OS" == *"Ubuntu"* ]]; then
        # Ubuntu installation
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg lsb-release

        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    elif [[ "$OS" == *"Amazon Linux"* ]]; then
        # Amazon Linux installation
        sudo yum update -y
        sudo yum install -y docker
        sudo systemctl start docker
        sudo systemctl enable docker

        # Install Docker Compose
        DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
        sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    else
        log_error "Unsupported operating system: $OS"
        exit 1
    fi

    # Add current user to docker group
    sudo usermod -aG docker $USER

    log_info "Docker installed successfully"
}

install_dependencies() {
    log_info "Installing system dependencies..."

    if [[ "$OS" == *"Ubuntu"* ]]; then
        sudo apt-get update
        sudo apt-get install -y \
            curl \
            wget \
            git \
            unzip \
            openssl \
            bc \
            jq \
            htop \
            nano \
            vim \
            ufw \
            fail2ban

    elif [[ "$OS" == *"Amazon Linux"* ]]; then
        sudo yum update -y
        sudo yum install -y \
            curl \
            wget \
            git \
            unzip \
            openssl \
            bc \
            jq \
            htop \
            nano \
            vim
    fi

    log_info "Dependencies installed successfully"
}

configure_firewall() {
    log_info "Configuring firewall..."

    if command -v ufw >/dev/null 2>&1; then
        # UFW (Ubuntu)
        sudo ufw --force reset
        sudo ufw default deny incoming
        sudo ufw default allow outgoing

        # Allow SSH
        sudo ufw allow ssh
        sudo ufw allow 22/tcp

        # Allow HTTP and HTTPS
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp

        # Enable firewall
        sudo ufw --force enable

        log_info "UFW firewall configured"

    elif command -v firewalld >/dev/null 2>&1; then
        # Firewalld (CentOS/RHEL)
        sudo systemctl enable firewalld
        sudo systemctl start firewalld

        sudo firewall-cmd --permanent --add-service=ssh
        sudo firewall-cmd --permanent --add-service=http
        sudo firewall-cmd --permanent --add-service=https
        sudo firewall-cmd --reload

        log_info "Firewalld configured"
    else
        log_warn "No supported firewall found. Please configure manually."
    fi
}

configure_fail2ban() {
    log_info "Configuring Fail2Ban..."

    if command -v fail2ban-server >/dev/null 2>&1; then
        sudo systemctl enable fail2ban
        sudo systemctl start fail2ban

        # Create SSH jail configuration
        sudo tee /etc/fail2ban/jail.d/sshd.conf > /dev/null << EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF

        sudo systemctl restart fail2ban
        log_info "Fail2Ban configured for SSH protection"
    else
        log_warn "Fail2Ban not available"
    fi
}

setup_directories() {
    log_info "Setting up HRAS directories..."

    sudo mkdir -p /opt/hras/{app,data,logs,ssl,scripts}
    sudo mkdir -p /opt/hras/data/{backend,postgres,redis,prometheus,loki,grafana,alertmanager}
    sudo mkdir -p /opt/hras/logs/{nginx,backend,postgres,redis,certbot}
    sudo mkdir -p /opt/hras/data/certbot/{data,challenges}

    # Set proper ownership
    sudo chown -R $USER:$USER /opt/hras
    sudo chmod -R 755 /opt/hras

    log_info "Directory structure created"
}

configure_docker_daemon() {
    log_info "Configuring Docker daemon..."

    sudo mkdir -p /etc/docker

    sudo tee /etc/docker/daemon.json > /dev/null << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "exec-opts": ["native.cgroupdriver=systemd"],
  "live-restore": true,
  "userland-proxy": false,
  "experimental": false,
  "metrics-addr": "0.0.0.0:9323",
  "default-ulimits": {
    "nofile": {
      "Hard": 64000,
      "Name": "nofile",
      "Soft": 64000
    }
  }
}
EOF

    sudo systemctl daemon-reload
    sudo systemctl restart docker

    log_info "Docker daemon configured"
}

install_aws_cli() {
    log_info "Installing AWS CLI v2..."

    if command -v aws >/dev/null 2>&1; then
        log_info "AWS CLI already installed"
        return 0
    fi

    cd /tmp
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install

    log_info "AWS CLI v2 installed"
}

optimize_system() {
    log_info "Optimizing system for production..."

    # Increase file limits
    sudo tee /etc/security/limits.d/hras.conf > /dev/null << EOF
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF

    # Kernel parameters for better networking
    sudo tee /etc/sysctl.d/99-hras.conf > /dev/null << EOF
# Network optimizations
net.core.somaxconn = 65536
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 3

# Memory management
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

# File system
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
EOF

    sudo sysctl -p /etc/sysctl.d/99-hras.conf

    log_info "System optimizations applied"
}

setup_logrotate() {
    log_info "Setting up log rotation..."

    sudo tee /etc/logrotate.d/hras > /dev/null << EOF
/opt/hras/logs/*/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        docker kill -s USR1 \$(docker ps -q --filter "label=com.docker.compose.service=nginx") 2>/dev/null || true
    endscript
}

/opt/hras/logs/docker/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

    log_info "Log rotation configured"
}

show_next_steps() {
    log_info "Server setup completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Configure environment file:"
    echo "   cp .env.prod.example .env.prod"
    echo "   nano .env.prod"
    echo ""
    echo "2. Deploy HRAS:"
    echo "   make prod-deploy-full"
    echo ""
    echo "3. Set up monitoring (optional):"
    echo "   make prod-monitoring"
    echo ""
    echo "Important notes:"
    echo "- You may need to log out and back in for Docker permissions to take effect"
    echo "- Configure your domain's DNS to point to this server before SSL setup"
    echo "- Update AWS credentials in .env.prod for Route53 DNS challenge"
    echo ""
    echo "Server details:"
    echo "- HRAS directory: /opt/hras/"
    echo "- Docker daemon: configured with logging and metrics"
    echo "- Firewall: ports 22, 80, 443 open"
    echo "- Fail2Ban: SSH brute force protection enabled"
}

main() {
    echo "HRAS Production Server Setup"
    echo "============================="
    echo ""

    detect_os
    install_dependencies
    install_docker
    configure_docker_daemon
    install_aws_cli
    setup_directories
    configure_firewall
    configure_fail2ban
    optimize_system
    setup_logrotate

    show_next_steps
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   log_error "This script should not be run as root. Please run as a regular user with sudo privileges."
   exit 1
fi

# Run main function
main "$@"
