# HRAS Production Deployment Guide

This guide covers deploying the HRAS backend in production environments. The frontend is deployed separately on AWS Amplify.

## Deployment Options

| Method | Best For | Description |
|--------|----------|-------------|
| **K3s on EC2** | Cost-effective production | Lightweight K8s on single EC2 instance |
| **Docker Compose** | Simple deployments | Traditional container orchestration |

## K3s Production Deployment (Recommended)

K3s is a lightweight, CNCF-certified Kubernetes distribution ideal for production workloads on AWS EC2.

### Architecture Overview

```
Internet
    ↓
Route53 (DNS)
    ↓
EC2 Instance (t4g.medium)
    ↓
K3s Cluster
    ↓
├── Nginx Ingress Controller (SSL termination, CORS)
├── Backend Deployment (FastAPI + LangChain)
├── PostgreSQL StatefulSet (persistent storage)
└── Monitoring Stack (Prometheus, Grafana)
```

### Quick Start

```bash
# 1. SSH into EC2 instance
ssh -i your-key.pem ubuntu@your-ec2-host

# 2. Clone repository
git clone https://github.com/your-org/hras.git
cd hras

# 3. Install K3s
./zarf/scripts/k3s-setup.sh

# 4. Deploy HRAS
./zarf/scripts/k3s-deploy.sh

# 5. Verify deployment
kubectl get pods -n hras-system
```

### Prerequisites

**EC2 Instance Requirements:**
- **Instance Type**: t4g.medium (ARM64, 2 vCPU, 4GB RAM) or better
- **OS**: Ubuntu 22.04 LTS
- **Storage**: 50GB+ SSD (GP3 recommended)
- **Network**: Public subnet with Elastic IP

**Security Group Rules:**
| Port | Protocol | Source | Description |
|------|----------|--------|-------------|
| 22 | TCP | Your IP | SSH access |
| 80 | TCP | 0.0.0.0/0 | HTTP (redirects to HTTPS) |
| 443 | TCP | 0.0.0.0/0 | HTTPS |
| 6443 | TCP | Your IP | K3s API (optional) |

### K3s Installation

The setup script (`zarf/scripts/k3s-setup.sh`) performs:

1. **K3s Installation** with containerd runtime
2. **kubectl Configuration** for the ubuntu user
3. **Nginx Ingress Controller** deployment
4. **cert-manager** for automatic SSL certificates
5. **Firewall Configuration** (ufw)

```bash
./zarf/scripts/k3s-setup.sh
```

### HRAS Deployment

The deploy script (`zarf/scripts/k3s-deploy.sh`) deploys:

1. **PostgreSQL StatefulSet** with persistent volume
2. **Backend Deployment** with production resource limits
3. **Nginx Ingress** with SSL and CORS for Amplify frontend
4. **Monitoring Stack** (Prometheus, Grafana, Alertmanager)

```bash
./zarf/scripts/k3s-deploy.sh
```

### CORS Configuration for Amplify

The ingress is pre-configured for CORS with the Amplify frontend:

```yaml
nginx.ingress.kubernetes.io/cors-allow-origin: "https://feature-backend-refactor-testing.d3q35zh7ig6w8u.amplifyapp.com"
nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, PATCH, OPTIONS"
nginx.ingress.kubernetes.io/cors-allow-headers: "Accept, Content-Type, Authorization"
nginx.ingress.kubernetes.io/cors-allow-credentials: "true"
```

Update the CORS origin in `zarf/k8s/base/ingress/backend-ingress.yaml` if your Amplify domain changes.

### SSL Certificates

cert-manager automatically provisions Let's Encrypt certificates:

```bash
# Check certificate status
kubectl get certificate -n hras-system
kubectl describe certificate hras-tls -n hras-system
```

### Monitoring

Access monitoring dashboards:
- **Prometheus**: http://your-domain:30090
- **Grafana**: http://your-domain:30031 (admin/CHANGE_ME_IN_PRODUCTION)
- **Alertmanager**: http://your-domain:30093

### Useful Commands

```bash
# Check pod status
kubectl get pods -n hras-system -o wide

# View backend logs
kubectl logs -f deployment/backend -n hras-system

# Check ingress
kubectl get ingress -n hras-system

# Scale backend
kubectl scale deployment backend -n hras-system --replicas=3

# Resource usage
kubectl top pods -n hras-system
```

### Teardown

```bash
# Remove HRAS but keep data
./zarf/scripts/k3s-teardown.sh --keep-data

# Complete removal
./zarf/scripts/k3s-teardown.sh
```

---

## Docker Compose Production Deployment

For simpler deployments without Kubernetes.

### Architecture Overview

```
Internet
    ↓
Route53 (DNS + Health Checks)
    ↓
EC2 Instance
    ↓
Nginx (SSL Termination, Reverse Proxy)
    ↓
HRAS Backend (FastAPI)
    ↓
├── ChromaDB (Vector Store)
├── PostgreSQL (Optional - Conversations)
├── Redis (Optional - Caching)
└── External Ollama Service
```

## Prerequisites

### System Requirements
- **OS**: Ubuntu 20.04+ or Amazon Linux 2
- **CPU**: 4+ cores (for AI workloads)
- **RAM**: 8GB+ (4GB for backend, 2GB for Nginx/monitoring, 2GB for OS)
- **Storage**: 100GB+ SSD (for vector store and logs)
- **Network**: Stable internet connection for Ollama external service

### Software Dependencies
- Docker 24.0+
- Docker Compose 2.0+
- OpenSSL (for SSL certificate generation)
- curl (for health checks)

### AWS Configuration
- **Route53**: Domain configured with DNS management
- **IAM User**: With Route53 permissions for DNS challenges
- **Security Groups**: Ports 80, 443 open for web traffic

## Quick Start

### 1. Server Setup

```bash
# Clone repository
git clone https://github.com/your-org/hras.git
cd hras

# Copy and configure environment
cp .env.prod.example .env.prod
nano .env.prod  # Configure all variables
```

### 2. Environment Configuration

Edit `.env.prod` with your specific values:

```bash
# Domain Configuration
DOMAIN=api.hras.yourdomain.com
FRONTEND_DOMAIN=app.hras.yourdomain.com

# SSL Configuration
CERTBOT_EMAIL=admin@yourdomain.com
AWS_ACCESS_KEY_ID=your-route53-access-key
AWS_SECRET_ACCESS_KEY=your-route53-secret-key

# Security Keys (Generate with: openssl rand -base64 64)
SECRET_KEY=your-64-char-secret-key
JWT_SECRET_KEY=your-64-char-jwt-secret
HEALTH_CHECK_TOKEN=random-health-check-token

# Database Passwords
POSTGRES_PASSWORD=secure-postgres-password
REDIS_PASSWORD=secure-redis-password
GRAFANA_ADMIN_PASSWORD=secure-grafana-password
```

### 3. Deploy

```bash
# Full deployment with all services
./scripts/deployment/deploy-production.sh deploy --postgres --monitoring --ssl-init

# Or backend-only deployment
./scripts/deployment/deploy-production.sh deploy-backend
```

### 4. Verify Deployment

```bash
# Check deployment status
./scripts/deployment/deploy-production.sh status

# Verify health
./scripts/deployment/deploy-production.sh verify

# Test API endpoint
curl https://api.hras.yourdomain.com/health
```

## Service Configuration

### Core Services

#### Nginx Reverse Proxy
- **Purpose**: SSL termination, rate limiting, CORS handling
- **Port**: 80 (HTTP redirect), 443 (HTTPS)
- **Features**:
  - Route53 health check endpoints (`/health`, `/healthz`)
  - CORS configuration for AWS Amplify frontend
  - Rate limiting (API: 10 req/s, Health: 30 req/s, Chat: 5 req/s)
  - Security headers (HSTS, CSP, etc.)
  - SSL certificate auto-renewal via Let's Encrypt

#### HRAS Backend
- **Purpose**: FastAPI application with AI/ML capabilities
- **Port**: 8000 (internal)
- **Features**:
  - RAG pipeline over UN human rights documents
  - Multi-agent system (LangGraph + LangChain)
  - Vector search with ChromaDB
  - Conversation persistence (optional PostgreSQL)
  - Prometheus metrics endpoint

### Optional Services

#### PostgreSQL Database
```bash
# Enable with profile
docker compose -f zarf/docker/compose/docker-compose.prod.yml --profile postgres up -d postgres
```
- **Purpose**: Conversation history storage
- **Port**: 5432 (internal)
- **Configuration**: `./postgres/postgresql.conf`

#### Redis Cache
```bash
# Enable with profile
docker compose -f zarf/docker/compose/docker-compose.prod.yml --profile redis up -d redis
```
- **Purpose**: API response caching, session storage
- **Port**: 6379 (internal)
- **Memory**: 512MB limit with LRU eviction

#### Monitoring Stack
```bash
# Enable with profile
docker compose -f zarf/docker/compose/docker-compose.prod.yml --profile monitoring up -d
```
- **Prometheus**: Metrics collection (port 9090)
- **Grafana**: Visualization dashboard (port 3001)
- **Loki**: Log aggregation (port 3100)
- **AlertManager**: Alert routing (port 9093)
- **Promtail**: Log shipping agent

## SSL/TLS Configuration

### Automatic Certificate Management

The deployment uses Let's Encrypt with Route53 DNS challenge for automatic SSL certificate provisioning and renewal.

#### Initial Certificate Setup
```bash
# Run once during initial deployment
./scripts/deployment/deploy-production.sh ssl-init
```

#### Certificate Renewal
- **Automatic**: Certbot daemon checks every 12 hours
- **Manual**: `docker compose -f zarf/docker/compose/docker-compose.prod.yml exec certbot certbot renew`
- **Notification**: Webhook alerts on renewal (configure `NOTIFICATION_WEBHOOK`)

#### Security Features
- **TLS 1.2/1.3**: Modern protocol support
- **Perfect Forward Secrecy**: ECDHE key exchange
- **OCSP Stapling**: Faster certificate validation
- **HSTS**: Force HTTPS with 2-year max-age
- **Security Headers**: CSP, X-Frame-Options, etc.

## AWS Integration

### Route53 Health Checks

Configure Route53 health checks pointing to:
- **Primary**: `https://api.hras.yourdomain.com/health`
- **Secondary**: `https://api.hras.yourdomain.com/healthz`

Health check configuration:
```json
{
  "Type": "HTTPS",
  "ResourcePath": "/health",
  "FullyQualifiedDomainName": "api.hras.yourdomain.com",
  "Port": 443,
  "RequestInterval": 30,
  "FailureThreshold": 3
}
```

### CORS for AWS Amplify

The Nginx configuration includes CORS headers for AWS Amplify frontend:

```nginx
add_header Access-Control-Allow-Origin "https://app.hras.yourdomain.com" always;
add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, PATCH, OPTIONS" always;
add_header Access-Control-Allow-Headers "Accept, Accept-Language, Content-Language, Content-Type, Authorization, X-Requested-With, Cache-Control, X-Request-ID" always;
add_header Access-Control-Allow-Credentials "true" always;
```

### IAM Permissions

Required IAM permissions for Route53 DNS challenge:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:ListHostedZones",
                "route53:GetChange"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "route53:ChangeResourceRecordSets"
            ],
            "Resource": "arn:aws:route53:::hostedzone/YOUR_ZONE_ID"
        }
    ]
}
```

## Monitoring and Alerting

### Prometheus Metrics

Available at `http://localhost:9090` (internal access only):

Key metrics to monitor:
- `http_requests_total`: API request count
- `http_request_duration_seconds`: Response times
- `up`: Service availability
- `nginx_http_requests_total`: Nginx request metrics
- `process_resident_memory_bytes`: Memory usage

### Grafana Dashboards

Access at `http://localhost:3001`:
- **Login**: admin / `${GRAFANA_ADMIN_PASSWORD}`
- **Dashboards**: Pre-configured for HRAS metrics
- **Data Sources**: Prometheus (metrics), Loki (logs)

### Alerting Rules

Configured alerts in `./monitoring/rules/hras-alerts.yml`:
- Backend service down
- High response times (>5s)
- High error rates (>10%)
- SSL certificate expiring (<7 days)
- Resource usage thresholds

### Log Aggregation

Logs are collected by Promtail and sent to Loki:
- **Nginx**: Access and error logs (JSON format)
- **Backend**: Application logs (structured JSON)
- **System**: Docker container logs
- **Retention**: 30 days (configurable in Loki config)

## Backup and Recovery

### Data Backup

```bash
# Backup script (run daily via cron)
docker compose -f zarf/docker/compose/docker-compose.prod.yml exec backend python -c "
import subprocess
import datetime

timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
subprocess.run(['tar', '-czf', f'/app/data/backup_{timestamp}.tar.gz', '/app/data/chroma_db'])
"

# PostgreSQL backup (if enabled)
docker compose -f zarf/docker/compose/docker-compose.prod.yml exec postgres pg_dump -U hras hras > backup_$(date +%Y%m%d).sql
```

### Disaster Recovery

```bash
# Stop services
docker compose -f zarf/docker/compose/docker-compose.prod.yml down

# Restore data volumes
tar -xzf backup_20240116_120000.tar.gz -C ${DATA_PATH}/backend/

# Restart services
./scripts/deployment/deploy-production.sh deploy
```

## Security Considerations

### Network Security
- **Firewall**: Only ports 80, 443 open to internet
- **Internal Networks**: Services isolated in Docker networks
- **Rate Limiting**: Nginx rate limiting prevents DDoS

### Application Security
- **Authentication**: JWT tokens with secure secrets
- **CORS**: Restricted to Amplify frontend domain
- **Headers**: Security headers prevent common attacks
- **Input Validation**: Pydantic models validate all inputs

### Container Security
- **Non-root Users**: All containers run as non-root
- **Read-only**: Containers have minimal write access
- **Secrets**: Environment variables, not embedded in images
- **Updates**: Regular base image updates

## Troubleshooting

### Common Issues

#### SSL Certificate Issues
```bash
# Check certificate status
openssl s_client -servername api.hras.yourdomain.com -connect api.hras.yourdomain.com:443

# Force certificate renewal
docker compose -f zarf/docker/compose/docker-compose.prod.yml exec certbot certbot renew --force-renewal
```

#### Backend Not Starting
```bash
# Check logs
docker compose -f zarf/docker/compose/docker-compose.prod.yml logs backend

# Check health
docker compose -f zarf/docker/compose/docker-compose.prod.yml exec backend curl -f http://localhost:8000/health
```

#### High Memory Usage
```bash
# Check resource usage
docker stats

# Restart services if needed
docker compose -f zarf/docker/compose/docker-compose.prod.yml restart backend
```

### Log Locations

- **Nginx**: `${LOGS_PATH}/nginx/`
- **Backend**: `${LOGS_PATH}/backend/`
- **PostgreSQL**: `${LOGS_PATH}/postgres/`
- **Certbot**: `${LOGS_PATH}/certbot/`

### Health Check Endpoints

- **Backend Health**: `https://api.hras.yourdomain.com/health`
- **Detailed Status**: `https://api.hras.yourdomain.com/health?detailed=true`
- **Metrics**: `http://localhost:8000/metrics` (internal)

## Maintenance

### Regular Tasks

#### Daily
- Monitor alerts in Grafana
- Check SSL certificate status
- Review error logs

#### Weekly
- Update Docker images: `docker compose pull && docker compose up -d`
- Review resource usage trends
- Clean up old logs: `find ${LOGS_PATH} -name "*.log" -mtime +7 -delete`

#### Monthly
- Security updates: `sudo apt update && sudo apt upgrade`
- Backup verification
- Certificate renewal testing

### Scaling Considerations

For higher traffic, consider:
- **Load Balancer**: Multiple backend instances behind ALB
- **Database**: Managed RDS PostgreSQL
- **Caching**: ElastiCache Redis cluster
- **Monitoring**: CloudWatch + Grafana Cloud

## Support

### Getting Help
1. Check logs in `${LOGS_PATH}`
2. Review Grafana dashboards for metrics
3. Consult troubleshooting section above
4. Open issue with deployment logs and configuration

### Useful Commands

```bash
# View all services
docker compose -f zarf/docker/compose/docker-compose.prod.yml ps

# Follow logs
docker compose -f zarf/docker/compose/docker-compose.prod.yml logs -f backend

# Execute commands in containers
docker compose -f zarf/docker/compose/docker-compose.prod.yml exec backend bash

# Update and restart
docker compose -f zarf/docker/compose/docker-compose.prod.yml pull
docker compose -f zarf/docker/compose/docker-compose.prod.yml up -d --force-recreate
```
