#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_FILE="${PWD}/setup-hetzner.log"

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" | tee -a "${LOG_FILE}"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a "${LOG_FILE}" >&2
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" | tee -a "${LOG_FILE}"
}

resolve_env_file() {
    if [[ -n "${HRAS_ENV_FILE:-}" && -f "${HRAS_ENV_FILE}" ]]; then
        printf '%s\n' "${HRAS_ENV_FILE}"
        return 0
    fi

    local candidates=(
        "/opt/hras/.env.hetzner"
        "${REPO_ROOT}/.env.hetzner"
        "${REPO_ROOT}/.env.hetzner.example"
    )

    local file
    for file in "${candidates[@]}"; do
        if [[ -f "${file}" ]]; then
            printf '%s\n' "${file}"
            return 0
        fi
    done

    log_error "No .env.hetzner file found. Copy .env.hetzner.example to .env.hetzner and configure it first."
    exit 1
}

ENV_FILE="$(resolve_env_file)"
# shellcheck disable=SC1090
source "${ENV_FILE}"

if [[ ${EUID} -eq 0 ]]; then
    log_error "This script should not be run as root"
    exit 1
fi

setup_system() {
    log_info "Updating system packages..."
    sudo apt-get update -qq
    sudo apt-get upgrade -y -qq
    sudo apt-get install -y -qq \
        ca-certificates \
        curl \
        git \
        jq \
        htop \
        unzip \
        ufw \
        fail2ban \
        logrotate \
        rsync \
        bc \
        postgresql-client \
        monitoring-plugins-basic
    log_success "System packages installed"
}

setup_docker() {
    if command -v docker >/dev/null 2>&1; then
        log_info "Docker already installed. Skipping installation."
    else
        log_info "Installing Docker..."
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker "$USER"
    fi

    if ! docker compose version >/dev/null 2>&1; then
        log_info "Installing Docker Compose plugin..."
        sudo apt-get install -y -qq docker-compose-plugin
    fi

    sudo systemctl enable docker
    sudo systemctl start docker
    log_success "Docker is ready"
}

setup_swap() {
    local swap_size="${SWAP_SIZE_GB:-0}"

    if [[ ! "${swap_size}" =~ ^[0-9]+$ ]] || [[ "${swap_size}" -eq 0 ]]; then
        log_info "Swap creation skipped (SWAP_SIZE_GB not set to a positive integer)."
        return 0
    fi

    if sudo swapon --show | grep -q '/swapfile'; then
        log_info "Swap already configured. Skipping."
        return 0
    fi

    log_info "Creating ${swap_size}G swap file..."
    sudo fallocate -l "${swap_size}G" /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile

    if ! grep -q '^/swapfile ' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
    fi

    log_success "Swap configured"
}

setup_firewall() {
    log_info "Configuring UFW..."
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    if [[ -n "${ALLOWED_SSH_CIDR:-}" ]]; then
        sudo ufw allow from "${ALLOWED_SSH_CIDR}" to any port 22 proto tcp
    else
        sudo ufw allow 22/tcp
    fi

    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw --force enable
    log_success "Firewall configured"
}

setup_fail2ban() {
    log_info "Configuring fail2ban for SSH protection..."
    sudo tee /etc/fail2ban/jail.local >/dev/null <<'EOF'
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
EOF

    sudo systemctl enable fail2ban
    sudo systemctl restart fail2ban
    log_success "Fail2ban configured"
}

setup_directories() {
    log_info "Creating application directories..."
    sudo mkdir -p /opt/hras/{backups,data,logs}
    sudo mkdir -p /opt/hras/logs/{app,caddy}
    sudo chown -R "$USER":"$USER" /opt/hras
    sudo chmod 755 /opt/hras
    sudo chmod -R 755 /opt/hras/logs
    log_success "Application directories created"
}

setup_logrotate() {
    log_info "Installing logrotate policy..."
    sudo tee /etc/logrotate.d/hras-hetzner >/dev/null <<'EOF'
/opt/hras/logs/app/*.log /opt/hras/logs/caddy/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF
    log_success "Log rotation configured"
}

install_systemd_service() {
    local service_file="${SCRIPT_DIR}/../docker/hras-hetzner.service"
    if [[ ! -f "${service_file}" ]]; then
        log_info "Hetzner systemd service file not present yet. Skipping installation."
        return 0
    fi

    log_info "Installing systemd service..."
    sudo cp "${service_file}" /etc/systemd/system/hras-hetzner.service
    sudo systemctl daemon-reload
    sudo systemctl enable hras-hetzner.service
    log_success "Systemd service installed"
}

main() {
    log_info "Starting Hetzner server setup using ${ENV_FILE}..."
    setup_system
    setup_docker
    setup_swap
    setup_firewall
    setup_fail2ban
    setup_directories
    setup_logrotate
    install_systemd_service

    log_success "Hetzner server setup completed successfully"
    log_info "Next steps:"
    log_info "1. Copy this repository to /opt/hras"
    log_info "2. Copy .env.hetzner to /opt/hras/.env.hetzner"
    log_info "3. Start the stack with: ./zarf/scripts/deploy-hetzner.sh deploy"
}

main "$@"
