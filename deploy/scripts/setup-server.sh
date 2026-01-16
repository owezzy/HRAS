#!/bin/bash
set -euo pipefail

# HRAS Server Setup Script
# This script sets up an EC2 instance for HRAS deployment
# Usage: ./setup-server.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/deployment.env"

# Logging functions
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" | tee -a setup.log
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a setup.log >&2
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" | tee -a setup.log
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_error "This script should not be run as root"
    exit 1
fi

# Update system packages
setup_system() {
    log_info "Updating system packages..."
    sudo apt-get update -qq
    sudo apt-get upgrade -y -qq

    # Install essential packages
    sudo apt-get install -y -qq \
        curl \
        wget \
        git \
        htop \
        unzip \
        ufw \
        fail2ban \
        logrotate \
        certbot \
        python3-certbot-dns-route53 \
        nginx \
        jq \
        awscli \
        monitoring-plugins-basic \
        redis-server \
        postgresql-client

    log_success "System packages updated"
}

# Setup Docker
setup_docker() {
    log_info "Installing Docker..."

    # Remove old versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh

    # Add user to docker group
    sudo usermod -aG docker $USER

    # Install Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    # Enable Docker service
    sudo systemctl enable docker
    sudo systemctl start docker

    log_success "Docker installed and configured"
}

# Setup firewall
setup_firewall() {
    log_info "Configuring firewall..."

    # Reset UFW
    sudo ufw --force reset

    # Default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # Allow SSH
    sudo ufw allow ssh

    # Allow HTTP and HTTPS
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp

    # Allow application port
    sudo ufw allow ${BACKEND_PORT}/tcp

    # Allow database port (only from localhost)
    sudo ufw allow from 127.0.0.1 to any port ${POSTGRES_PORT}

    # Allow Redis port (only from localhost)
    sudo ufw allow from 127.0.0.1 to any port ${REDIS_PORT}

    # Enable UFW
    sudo ufw --force enable

    log_success "Firewall configured"
}

# Setup fail2ban
setup_fail2ban() {
    log_info "Configuring fail2ban..."

    # Create jail.local configuration
    sudo tee /etc/fail2ban/jail.local > /dev/null << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log

[nginx-noscript]
enabled = true
port = http,https
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 6

[nginx-badbots]
enabled = true
port = http,https
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 2

[nginx-noproxy]
enabled = true
port = http,https
filter = nginx-noproxy
logpath = /var/log/nginx/access.log
maxretry = 2
EOF

    sudo systemctl enable fail2ban
    sudo systemctl restart fail2ban

    log_success "Fail2ban configured"
}

# Setup directories
setup_directories() {
    log_info "Creating application directories..."

    # Create application directories
    sudo mkdir -p /opt/hras/{app,data,logs,backups,ssl}
    sudo mkdir -p /opt/hras/data/{postgres,redis,chroma,uploads}
    sudo mkdir -p /opt/hras/logs/{app,nginx,postgres,redis}

    # Set ownership
    sudo chown -R $USER:$USER /opt/hras
    sudo chown -R 999:999 /opt/hras/data/postgres  # PostgreSQL user
    sudo chown -R 999:999 /opt/hras/data/redis     # Redis user

    # Set permissions
    chmod 755 /opt/hras
    chmod 750 /opt/hras/data
    chmod 750 /opt/hras/ssl
    chmod 755 /opt/hras/logs

    log_success "Application directories created"
}

# Setup Nginx
setup_nginx() {
    log_info "Configuring Nginx..."

    # Remove default site
    sudo rm -f /etc/nginx/sites-enabled/default

    # Create HRAS configuration
    sudo tee /etc/nginx/sites-available/hras > /dev/null << EOF
# HRAS Nginx Configuration
upstream hras_backend {
    server 127.0.0.1:${BACKEND_PORT} max_fails=3 fail_timeout=30s;
    keepalive 32;
}

# Rate limiting zones
limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone \$binary_remote_addr zone=auth:10m rate=5r/s;

# Security headers map
map \$sent_http_content_type \$content_security_policy {
    default "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self'; frame-ancestors 'none';";
}

server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN};

    # Security headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        allow all;
    }

    # Redirect to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN} www.${DOMAIN};

    # SSL Configuration
    ssl_certificate /opt/hras/ssl/fullchain.pem;
    ssl_certificate_key /opt/hras/ssl/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    # Modern configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # HSTS
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

    # Security headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy \$content_security_policy always;

    # Logging
    access_log /opt/hras/logs/nginx/access.log combined;
    error_log /opt/hras/logs/nginx/error.log warn;

    # Client settings
    client_max_body_size 10M;
    client_body_timeout 30s;
    client_header_timeout 30s;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # API endpoints
    location /api/ {
        limit_req zone=api burst=20 nodelay;

        proxy_pass http://hras_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;

        # Connection settings
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }

    # Authentication endpoints (stricter rate limiting)
    location ~ ^/api/v[0-9]+/auth/ {
        limit_req zone=auth burst=5 nodelay;

        proxy_pass http://hras_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;

        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }

    # Health check endpoint (no rate limiting)
    location = /health {
        proxy_pass http://hras_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        access_log off;
    }

    # Metrics endpoint (restricted access)
    location /metrics {
        allow 127.0.0.1;
        deny all;

        proxy_pass http://hras_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Static files (if any)
    location /static/ {
        root /opt/hras/app;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Deny access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    location ~ \.(env|log|sql|bak|backup|swp|tmp)$ {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

    # Enable site
    sudo ln -sf /etc/nginx/sites-available/hras /etc/nginx/sites-enabled/

    # Test configuration
    sudo nginx -t

    # Enable and start Nginx
    sudo systemctl enable nginx
    sudo systemctl restart nginx

    log_success "Nginx configured"
}

# Setup log rotation
setup_logrotate() {
    log_info "Setting up log rotation..."

    sudo tee /etc/logrotate.d/hras > /dev/null << 'EOF'
/opt/hras/logs/app/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 ubuntu ubuntu
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
    endscript
}

/opt/hras/logs/nginx/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 www-data www-data
    sharedscripts
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
    endscript
}

/opt/hras/logs/postgres/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 999 999
}
EOF

    log_success "Log rotation configured"
}

# Setup monitoring user
setup_monitoring() {
    log_info "Setting up monitoring..."

    # Create monitoring user
    sudo useradd -r -s /bin/false -d /nonexistent monitoring || true

    # Create monitoring directories
    sudo mkdir -p /opt/hras/monitoring/{prometheus,grafana,alertmanager}
    sudo chown -R monitoring:monitoring /opt/hras/monitoring

    log_success "Monitoring user and directories created"
}

# Setup systemd services
setup_systemd_services() {
    log_info "Setting up systemd services..."

    # Create HRAS service file
    sudo tee /etc/systemd/system/hras.service > /dev/null << EOF
[Unit]
Description=HRAS Backend API Service
After=network.target docker.service postgresql.service
Requires=docker.service
Wants=postgresql.service

[Service]
Type=notify
User=ubuntu
Group=docker
WorkingDirectory=/opt/hras/app
Environment=PYTHONPATH=/opt/hras/app
ExecStartPre=/usr/bin/docker-compose -f /opt/hras/app/docker-compose.prod.yml pull
ExecStart=/usr/bin/docker-compose -f /opt/hras/app/docker-compose.prod.yml up
ExecStop=/usr/bin/docker-compose -f /opt/hras/app/docker-compose.prod.yml down
Restart=always
RestartSec=10
StandardOutput=append:/opt/hras/logs/app/hras.log
StandardError=append:/opt/hras/logs/app/hras-error.log

[Install]
WantedBy=multi-user.target
EOF

    # Create health check service
    sudo tee /etc/systemd/system/hras-healthcheck.service > /dev/null << 'EOF'
[Unit]
Description=HRAS Health Check Service
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/hras/scripts/health-check.sh
StandardOutput=append:/opt/hras/logs/app/healthcheck.log
StandardError=append:/opt/hras/logs/app/healthcheck-error.log
EOF

    # Create health check timer
    sudo tee /etc/systemd/system/hras-healthcheck.timer > /dev/null << 'EOF'
[Unit]
Description=Run HRAS Health Check every 2 minutes
Requires=hras-healthcheck.service

[Timer]
OnCalendar=*:*:00/120
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Reload systemd
    sudo systemctl daemon-reload

    log_success "Systemd services configured"
}

# Main setup function
main() {
    log_info "Starting HRAS server setup..."

    # Check if deployment config exists
    if [[ ! -f "${SCRIPT_DIR}/../config/deployment.env" ]]; then
        log_error "Deployment configuration not found. Please copy deployment.env.example to deployment.env and configure it."
        exit 1
    fi

    setup_system
    setup_docker
    setup_firewall
    setup_fail2ban
    setup_directories
    setup_nginx
    setup_logrotate
    setup_monitoring
    setup_systemd_services

    log_success "Server setup completed successfully!"
    log_info "Next steps:"
    log_info "1. Configure SSL certificates with: ./setup-ssl.sh"
    log_info "2. Deploy the application with: ./deploy.sh"
    log_info "3. Set up monitoring with: ./setup-monitoring.sh"

    # Print important information
    echo "
===========================================
HRAS Server Setup Complete
===========================================

Important Information:
- Application directory: /opt/hras
- Nginx configuration: /etc/nginx/sites-available/hras
- Logs directory: /opt/hras/logs
- Data directory: /opt/hras/data

Security Notes:
- Firewall is configured and active
- Fail2ban is protecting SSH and web services
- User added to docker group (logout/login required)

Next Steps:
1. Run 'newgrp docker' or logout/login to activate docker group
2. Configure SSL certificates
3. Deploy the application
4. Set up monitoring

To check status:
- sudo ufw status
- sudo fail2ban-client status
- sudo systemctl status nginx
- sudo systemctl status docker
"
}

# Run main function
main "$@"
