# HRAS Kubernetes Deployment Guide

This guide covers deploying HRAS backend on Kubernetes using Kind for local development and K3s for production on AWS EC2.

## Directory Structure

```
zarf/
├── docker/
│   ├── dockerfile.backend     # Multi-stage backend Dockerfile
│   └── README.md              # Docker build documentation
├── k8s/
│   ├── base/                  # Shared base manifests
│   │   ├── backend/           # Backend deployment, service, rbac
│   │   ├── postgres/          # PostgreSQL statefulset
│   │   ├── monitoring/        # Prometheus, Grafana, Alertmanager
│   │   ├── ingress/           # Nginx Ingress Controller
│   │   └── kustomization.yaml
│   ├── dev/                   # Kind local development overlay
│   │   ├── kind-config.yaml   # Kind cluster configuration
│   │   ├── namespace.yaml
│   │   ├── backend/           # Dev-specific patches
│   │   ├── postgres/          # Dev postgres config
│   │   ├── monitoring/        # Dev monitoring config
│   │   └── kustomization.yaml
│   └── prod/                  # K3s production overlay
│       ├── k3s-config.yaml    # K3s configuration
│       ├── namespace.yaml
│       ├── backend/           # Production patches + resource limits
│       ├── postgres/          # Production secrets
│       ├── ingress/           # Production ingress with SSL
│       └── kustomization.yaml
└── scripts/
    ├── k3s-setup.sh           # Install K3s on EC2
    ├── k3s-deploy.sh          # Deploy HRAS to K3s
    └── k3s-teardown.sh        # Remove K3s installation
```

## Prerequisites

### Common Requirements
- Docker 24.0+
- kubectl 1.29+
- kustomize 5.0+ (or kubectl with kustomize support)

### For Local Development (Kind)
- [Kind](https://kind.sigs.k8s.io/) 0.20+
- Ollama running on host machine

### For Production (K3s)
- AWS EC2 instance (t4g.medium recommended)
- Domain configured with DNS
- SSL certificate (cert-manager provisions automatically)

## Local Development with Kind

Kind (Kubernetes IN Docker) provides an isolated Kubernetes cluster for development.

### Quick Start

```bash
make kind-create      # Create cluster with port mappings
make kind-load        # Build and load backend image
make kind-deploy      # Deploy postgres + backend
make kind-status      # Verify deployment
```

### Cluster Creation

The Kind cluster is configured via `zarf/k8s/dev/kind-config.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 8000
        hostPort: 8000
        protocol: TCP
      - containerPort: 5432
        hostPort: 30432
        protocol: TCP
```

This exposes:
- Backend API: http://localhost:8000
- PostgreSQL: localhost:30432

### Deploying Components

```bash
make kind-deploy-postgres    # Deploy PostgreSQL first
make kind-deploy-backend     # Deploy backend (auto-ingests data)
```

The backend deployment includes an init container that automatically ingests sample UHRI data on first run.

### Ollama Configuration

For macOS/Windows, the dev overlay uses:
```
OLLAMA_BASE_URL=http://host.docker.internal:11434
```

For Linux hosts, update `zarf/k8s/dev/backend/configmap.yaml`:
```yaml
data:
  ollama_base_url: "http://172.17.0.1:11434"
```

### Monitoring Stack

```bash
make monitoring-deploy       # Deploy Prometheus, Grafana, Alertmanager
make monitoring-status       # Check monitoring pods
```

Access monitoring:
- Grafana: http://localhost:30031 (admin/CHANGE_ME_IN_PRODUCTION)
- Prometheus: http://localhost:30090
- Alertmanager: http://localhost:30093

### Troubleshooting Kind

```bash
make kind-logs-backend       # View backend logs
kubectl describe pod -n hras-system -l app=backend
kubectl get events -n hras-system --sort-by='.lastTimestamp'
```

### Cleanup

```bash
make kind-clean              # Remove all resources and delete cluster
```

## Production Deployment with K3s

K3s is a lightweight, production-ready Kubernetes distribution optimized for edge and resource-constrained environments.

### EC2 Instance Setup

Recommended instance: **t4g.medium** (ARM64, 2 vCPU, 4GB RAM)

Security group requirements:
- Port 22 (SSH)
- Port 80 (HTTP - redirects to HTTPS)
- Port 443 (HTTPS)
- Port 6443 (K3s API - optional, for remote kubectl)

### K3s Installation

SSH into EC2 and run:

```bash
./zarf/scripts/k3s-setup.sh
```

This script:
1. Installs K3s with containerd
2. Configures kubectl
3. Installs Nginx Ingress Controller
4. Configures cert-manager for SSL

Alternatively via Makefile:

```bash
make k3s-setup
```

### Deploying HRAS

```bash
make k3s-deploy
```

Or directly on EC2:

```bash
./zarf/scripts/k3s-deploy.sh
```

This deploys:
- PostgreSQL StatefulSet with persistent storage
- Backend Deployment with production resource limits
- Nginx Ingress with SSL termination
- Prometheus monitoring stack

### CORS Configuration for Amplify Frontend

The production ingress includes CORS headers for the Amplify-hosted frontend:

```yaml
nginx.ingress.kubernetes.io/cors-allow-origin: "https://feature-backend-refactor-testing.d3q35zh7ig6w8u.amplifyapp.com"
nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, PATCH, OPTIONS"
nginx.ingress.kubernetes.io/cors-allow-headers: "Accept, Content-Type, Authorization"
nginx.ingress.kubernetes.io/cors-allow-credentials: "true"
```

Update the CORS origin in `zarf/k8s/base/ingress/backend-ingress.yaml` if your Amplify domain changes.

### SSL Certificates

cert-manager automatically provisions Let's Encrypt certificates. Configure your email in the ClusterIssuer:

```yaml
spec:
  acme:
    email: your-email@domain.com
    server: https://acme-v02.api.letsencrypt.org/directory
```

### Production Resource Limits

The production overlay configures appropriate resource limits:

```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

### Monitoring Production

```bash
make k3s-status              # Check all pods and services
make k3s-logs                # Tail backend logs
kubectl top pods -n hras-system   # Resource usage
```

### Scaling

To scale the backend horizontally:

```bash
kubectl scale deployment backend -n hras-system --replicas=3
```

For HPA (Horizontal Pod Autoscaler):

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: hras-system
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

### Teardown

```bash
make k3s-teardown            # Remove K3s and all resources
```

Or with data preservation:

```bash
./zarf/scripts/k3s-teardown.sh --keep-data
```

## Kustomize Patterns

### Base Manifests

Base manifests in `zarf/k8s/base/` define the core resources with placeholder values:

```yaml
images:
  - name: backend-image
    newName: localhost/hras-backend
    newTag: latest
```

### Overlays

Overlays (dev/prod) customize the base:

```yaml
resources:
  - ../../base/backend

images:
  - name: backend-image
    newName: ghcr.io/your-org/hras-backend
    newTag: v1.0.0

patches:
  - path: deployment-patch.yaml
```

### Strategic Merge Patches

Patches modify specific fields without replacing entire resources:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  template:
    spec:
      containers:
        - name: backend
          resources:
            limits:
              memory: "4Gi"
```

## GitHub Actions CI/CD

The deployment workflow (`.github/workflows/deploy-production.yml`) automates:

1. Quality gates (lint, test)
2. Docker image build and push to GHCR
3. K3s deployment via SSH
4. Health checks
5. Automatic rollback on failure

Secrets required:
- `EC2_HOST`: EC2 public IP or hostname
- `EC2_SSH_PRIVATE_KEY`: SSH private key for deployment
- `DOMAIN`: Production domain (e.g., api.hras.example.com)
- `DATABASE_URL`: PostgreSQL connection string
- `OLLAMA_BASE_URL`: External Ollama service URL
- `OLLAMA_MODEL`: LLM model name

## Troubleshooting

### Pod Not Starting

```bash
kubectl describe pod <pod-name> -n hras-system
kubectl logs <pod-name> -n hras-system --previous
```

### Ingress Issues

```bash
kubectl get ingress -n hras-system
kubectl describe ingress backend-ingress -n hras-system
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### Certificate Issues

```bash
kubectl get certificate -n hras-system
kubectl describe certificate -n hras-system
kubectl logs -n cert-manager -l app=cert-manager
```

### Database Connection

```bash
kubectl exec -it postgres-0 -n hras-system -- psql -U hras -d hras
```

### Resource Constraints

```bash
kubectl top nodes
kubectl top pods -n hras-system
kubectl describe node
```

## Migration from k8s/ to zarf/k8s/

If you have an existing deployment using the old `k8s/` structure:

1. Scale down existing deployments
2. Backup persistent volumes
3. Delete old resources: `kubectl delete -k k8s/dev/`
4. Deploy using new structure: `kubectl apply -k zarf/k8s/dev/`
5. Verify data migration
6. Delete old `k8s/` directory
