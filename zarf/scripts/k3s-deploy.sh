#!/bin/bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-hras-production}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUSTOMIZE_DIR="${SCRIPT_DIR}/../k8s/prod"

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1"; }
error() { log "ERROR: $1" >&2; exit 1; }

check_prereqs() {
    command -v kubectl >/dev/null 2>&1 || error "kubectl not found"
    kubectl cluster-info >/dev/null 2>&1 || error "Cannot connect to K3s cluster"
    [[ -d "${KUSTOMIZE_DIR}" ]] || error "Kustomize directory not found: ${KUSTOMIZE_DIR}"
}

check_secrets() {
    local secret_file="${KUSTOMIZE_DIR}/postgres/secret.yaml"

    if grep -q "SEALED_SECRET_PLACEHOLDER" "${secret_file}"; then
        error "Update postgres password in ${secret_file} before deploying"
    fi
}

check_images() {
    local kustomization="${KUSTOMIZE_DIR}/backend/kustomization.yaml"

    if grep -q "OWNER" "${kustomization}"; then
        log "WARN: Update container registry in ${kustomization}"
        log "WARN: Replace 'OWNER' with your GitHub username/org"
    fi
}

deploy_manifests() {
    log "Deploying HRAS to ${NAMESPACE}..."

    kubectl apply -k "${KUSTOMIZE_DIR}"

    log "Waiting for deployments..."

    kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=300s || {
        log "WARN: Backend deployment may not be ready"
        kubectl get pods -n "${NAMESPACE}" -l app=backend
    }

    kubectl rollout status statefulset/postgres -n "${NAMESPACE}" --timeout=120s || {
        log "WARN: Postgres may not be ready"
        kubectl get pods -n "${NAMESPACE}" -l app=postgres
    }
}

wait_for_ingress() {
    log "Checking ingress status..."

    local max_wait=60
    local waited=0

    while ! kubectl get ingress -n "${NAMESPACE}" >/dev/null 2>&1; do
        sleep 2
        waited=$((waited + 2))
        [[ $waited -lt $max_wait ]] || break
    done

    kubectl get ingress -n "${NAMESPACE}" 2>/dev/null || log "No ingress resources found"
}

show_status() {
    log ""
    log "=== Deployment Status ==="
    log ""

    log "Pods:"
    kubectl get pods -n "${NAMESPACE}" -o wide

    log ""
    log "Services:"
    kubectl get svc -n "${NAMESPACE}"

    log ""
    log "Ingress:"
    kubectl get ingress -n "${NAMESPACE}" 2>/dev/null || log "No ingress configured"

    log ""
    log "PVCs:"
    kubectl get pvc -n "${NAMESPACE}"
}

main() {
    log "Deploying HRAS to K3s production cluster..."

    check_prereqs
    check_secrets
    check_images
    deploy_manifests
    wait_for_ingress
    show_status

    log ""
    log "Deployment complete!"
    log ""
    log "Access the API:"
    log "  Internal: kubectl port-forward svc/backend-service 8000:80 -n ${NAMESPACE}"
    log "  External: Configure DNS and TLS for your API domain"
}

main "$@"
