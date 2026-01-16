#!/bin/bash
set -euo pipefail

# HRAS Docker Compose Service Installation Script
# Run this on EC2 to install HRAS as a systemd service

INSTALL_DIR="/opt/hras"
REPO_URL="https://github.com/owezzy/HRAS.git"
BRANCH="${1:-feature/backend-refactor-testing}"

echo "=== HRAS Docker Compose Service Installer ==="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user 2>/dev/null || usermod -aG docker ubuntu 2>/dev/null || true
fi

# Install Docker Compose plugin if not present
if ! docker compose version &> /dev/null; then
    echo "Installing Docker Compose plugin..."
    apt-get update && apt-get install -y docker-compose-plugin 2>/dev/null || \
    yum install -y docker-compose-plugin 2>/dev/null || \
    (mkdir -p /usr/local/lib/docker/cli-plugins && \
     curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
     -o /usr/local/lib/docker/cli-plugins/docker-compose && \
     chmod +x /usr/local/lib/docker/cli-plugins/docker-compose)
fi

# Create installation directory
echo "Creating installation directory..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/data"/{backend,postgres,redis,prometheus,loki,grafana,alertmanager,certbot}
mkdir -p "$INSTALL_DIR/logs"/{nginx,backend,postgres,redis,certbot}

# Clone or update repository
if [[ -d "$INSTALL_DIR/.git" ]]; then
    echo "Updating repository..."
    cd "$INSTALL_DIR"
    git fetch origin
    git checkout "$BRANCH"
    git pull origin "$BRANCH"
else
    echo "Cloning repository..."
    git clone --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

# Create .env.prod from example if it doesn't exist
if [[ ! -f "$INSTALL_DIR/.env.prod" ]]; then
    echo "Creating .env.prod from template..."
    cp .env.prod.example .env.prod
    echo ""
    echo "⚠️  IMPORTANT: Edit /opt/hras/.env.prod with your actual values:"
    echo "   - DOMAIN (your API domain)"
    echo "   - POSTGRES_PASSWORD"
    echo "   - SECRET_KEY"
    echo "   - JWT_SECRET_KEY"
    echo "   - AWS credentials (for SSL)"
    echo ""
fi

# Install systemd service
echo "Installing systemd service..."
cp zarf/docker/hras.service /etc/systemd/system/hras.service
systemctl daemon-reload
systemctl enable hras.service

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit configuration:    sudo nano /opt/hras/.env.prod"
echo "  2. Start the service:     sudo systemctl start hras"
echo "  3. Check status:          sudo systemctl status hras"
echo "  4. View logs:             sudo journalctl -u hras -f"
echo ""
echo "Service commands:"
echo "  sudo systemctl start hras     # Start HRAS"
echo "  sudo systemctl stop hras      # Stop HRAS"
echo "  sudo systemctl restart hras   # Restart HRAS"
echo "  sudo systemctl reload hras    # Recreate containers"
echo ""
