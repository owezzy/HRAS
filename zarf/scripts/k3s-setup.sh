#!/bin/bash
set -euo pipefail

K3S_VERSION="${K3S_VERSION:-v1.31.4+k3s1}"
INSTALL_DIR="/etc/rancher/k3s"
CONFIG_FILE="${INSTALL_DIR}/config.yaml"

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1"; }
error() { log "ERROR: $1" >&2; exit 1; }

check_root() {
    [[ $EUID -eq 0 ]] || error "Run as root: sudo $0"
}

check_system() {
    log "Checking system requirements..."

    local mem_kb
    mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    [[ $mem_kb -ge 3500000 ]] || error "Minimum 4GB RAM required (found: $((mem_kb / 1024))MB)"

    local cpu_count
    cpu_count=$(nproc)
    [[ $cpu_count -ge 2 ]] || error "Minimum 2 CPUs required (found: ${cpu_count})"

    command -v curl >/dev/null 2>&1 || error "curl is required"

    log "System check passed: ${cpu_count} CPUs, $((mem_kb / 1024))MB RAM"
}

install_prereqs() {
    log "Installing prerequisites..."

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq
        apt-get install -y -qq curl wget jq
    elif command -v yum >/dev/null 2>&1; then
        yum install -y -q curl wget jq
    fi
}

setup_firewall() {
    log "Configuring firewall..."

    local ports=(6443 443 80 10250 8472)

    if command -v ufw >/dev/null 2>&1; then
        for port in "${ports[@]}"; do
            ufw allow "${port}/tcp" >/dev/null 2>&1 || true
        done
        ufw allow 8472/udp >/dev/null 2>&1 || true
    elif command -v firewall-cmd >/dev/null 2>&1; then
        for port in "${ports[@]}"; do
            firewall-cmd --permanent --add-port="${port}/tcp" >/dev/null 2>&1 || true
        done
        firewall-cmd --permanent --add-port=8472/udp >/dev/null 2>&1 || true
        firewall-cmd --reload >/dev/null 2>&1 || true
    fi
}

install_k3s() {
    log "Installing K3s ${K3S_VERSION}..."

    mkdir -p "${INSTALL_DIR}"

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local config_source="${script_dir}/../k8s/prod/k3s-config.yaml"

    if [[ -f "${config_source}" ]]; then
        cp "${config_source}" "${CONFIG_FILE}"
        log "Copied K3s config from ${config_source}"
    else
        log "WARN: K3s config not found at ${config_source}, using defaults"
    fi

    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" sh -s - server

    local max_wait=120
    local waited=0
    while ! kubectl get nodes >/dev/null 2>&1; do
        sleep 2
        waited=$((waited + 2))
        [[ $waited -lt $max_wait ]] || error "K3s failed to start within ${max_wait}s"
    done

    log "K3s installed and running"
}

install_nginx_ingress() {
    log "Installing Nginx Ingress Controller..."

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.0/deploy/static/provider/cloud/deploy.yaml

    log "Waiting for Ingress Controller..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s || log "WARN: Ingress controller may not be ready"
}

install_cert_manager() {
    log "Installing cert-manager..."

    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml

    log "Waiting for cert-manager..."
    kubectl wait --namespace cert-manager \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/instance=cert-manager \
        --timeout=120s || log "WARN: cert-manager may not be ready"
}

setup_kubeconfig() {
    log "Setting up kubeconfig..."

    mkdir -p "${HOME}/.kube"
    cp /etc/rancher/k3s/k3s.yaml "${HOME}/.kube/config"
    chmod 600 "${HOME}/.kube/config"

    if [[ -n "${SUDO_USER:-}" ]]; then
        local user_home
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
        mkdir -p "${user_home}/.kube"
        cp /etc/rancher/k3s/k3s.yaml "${user_home}/.kube/config"
        chown -R "${SUDO_USER}:${SUDO_USER}" "${user_home}/.kube"
        chmod 600 "${user_home}/.kube/config"
    fi
}

main() {
    log "Starting K3s setup for HRAS production..."

    check_root
    check_system
    install_prereqs
    setup_firewall
    install_k3s
    install_nginx_ingress
    install_cert_manager
    setup_kubeconfig

    log "K3s setup complete!"
    log ""
    log "Next steps:"
    log "  1. Update DNS: Point your domain to this server's IP"
    log "  2. Update secrets in zarf/k8s/prod/postgres/secret.yaml"
    log "  3. Run: ./k3s-deploy.sh"
}

main "$@"
