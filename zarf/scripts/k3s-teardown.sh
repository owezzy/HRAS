#!/bin/bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-hras-production}"
UNINSTALL_K3S="${UNINSTALL_K3S:-false}"

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1"; }
error() { log "ERROR: $1" >&2; exit 1; }

confirm() {
    local message="$1"
    read -r -p "${message} [y/N]: " response
    [[ "${response,,}" == "y" ]]
}

delete_namespace() {
    log "Deleting namespace ${NAMESPACE}..."

    if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
        kubectl delete namespace "${NAMESPACE}" --timeout=120s || {
            log "WARN: Namespace deletion may be stuck, forcing..."
            kubectl get namespace "${NAMESPACE}" -o json | \
                jq '.spec.finalizers = []' | \
                kubectl replace --raw "/api/v1/namespaces/${NAMESPACE}/finalize" -f - || true
        }
        log "Namespace ${NAMESPACE} deleted"
    else
        log "Namespace ${NAMESPACE} does not exist"
    fi
}

delete_ingress_resources() {
    log "Cleaning up ingress resources..."

    kubectl delete ingressclass nginx --ignore-not-found=true
    kubectl delete namespace ingress-nginx --ignore-not-found=true --timeout=60s || true
}

delete_cert_manager() {
    log "Cleaning up cert-manager..."

    kubectl delete namespace cert-manager --ignore-not-found=true --timeout=60s || true
}

uninstall_k3s() {
    log "Uninstalling K3s..."

    if [[ -f /usr/local/bin/k3s-uninstall.sh ]]; then
        /usr/local/bin/k3s-uninstall.sh
        log "K3s uninstalled"
    else
        log "K3s uninstall script not found"
    fi
}

cleanup_data() {
    log "Cleaning up data directories..."

    rm -rf /var/lib/rancher/k3s/storage/*

    log "Data directories cleaned"
}

main() {
    log "HRAS K3s Teardown"
    log ""

    if [[ "${1:-}" == "--full" ]] || [[ "${UNINSTALL_K3S}" == "true" ]]; then
        if ! confirm "This will COMPLETELY UNINSTALL K3s and DELETE ALL DATA. Continue?"; then
            log "Aborted"
            exit 0
        fi

        delete_namespace
        delete_ingress_resources
        delete_cert_manager
        uninstall_k3s
        cleanup_data

        log ""
        log "Full K3s teardown complete"
    else
        if ! confirm "This will delete the ${NAMESPACE} namespace and all HRAS resources. Continue?"; then
            log "Aborted"
            exit 0
        fi

        delete_namespace

        log ""
        log "HRAS resources deleted. K3s cluster is still running."
        log "Run with --full to completely uninstall K3s"
    fi
}

main "$@"
