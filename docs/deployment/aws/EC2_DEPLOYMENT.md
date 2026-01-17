# AWS EC2 Backend Deployment Guide

Complete step-by-step guide for deploying HRAS backend with full monitoring stack to AWS EC2.

## Prerequisites

- AWS Account with EC2 access
- AWS CLI configured with appropriate permissions
- SSH key pair for EC2 access
- Domain name (optional): `hras.owezzy.tech`

## Step 1: Launch EC2 Instance

### 1.1 Create Security Group

```bash
# Create security group
aws ec2 create-security-group \
  --group-name hras-backend-sg \
  --description "HRAS Backend Security Group"

# Add ingress rules
aws ec2 authorize-security-group-ingress \
  --group-name hras-backend-sg \
  --protocol tcp --port 22 --cidr 0.0.0.0/0    # SSH

aws ec2 authorize-security-group-ingress \
  --group-name hras-backend-sg \
  --protocol tcp --port 8000 --cidr 0.0.0.0/0  # Backend API

aws ec2 authorize-security-group-ingress \
  --group-name hras-backend-sg \
  --protocol tcp --port 3001 --cidr 0.0.0.0/0  # Grafana

aws ec2 authorize-security-group-ingress \
  --group-name hras-backend-sg \
  --protocol tcp --port 9090 --cidr 0.0.0.0/0  # Prometheus
```

### 1.2 Launch Instance

**Via AWS Console:**
1. **AMI**: Ubuntu Server 24.04 LTS (HVM)
2. **Instance Type**: t3.small (2 vCPU, 2 GB RAM) or t3.medium (4 GB RAM) for local models
3. **Key Pair**: Select your existing key pair
4. **Security Group**: hras-backend-sg
5. **Storage**: 20 GB gp3 EBS volume
6. **Tag**: Name = "hras-backend"

**Via AWS CLI:**
```bash
aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --count 1 \
  --instance-type t3.small \
  --key-name your-key-pair \
  --security-groups hras-backend-sg \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=hras-backend}]' \
  --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=20,VolumeType=gp3}'
```

> **Note**: The AMI ID above is for Ubuntu 24.04 in us-east-1. Find your region's AMI at https://cloud-images.ubuntu.com/locator/ec2/

### 1.3 Static IP (Optional)

**Option A: Elastic IP ($3.65/month)**
```bash
# Allocate Elastic IP
aws ec2 allocate-address --domain vpc

# Associate with instance (replace with your instance-id and allocation-id)
aws ec2 associate-address \
  --instance-id i-01ff0b8da320eb9f8 \
  --allocation-id eipalloc-12345678
```

**Option B: Use Public DNS/IP (Free)**

Skip Elastic IP and use the instance's public DNS or IP directly. Note: IP changes on stop/start.

```bash
# Get current public DNS (run on EC2)
curl -s http://169.254.169.254/latest/meta-data/public-hostname

# Get current public IP
curl -s http://169.254.169.254/latest/meta-data/public-ipv4
```

## Step 2: Server Setup

### 2.1 Connect to Instance

```bash
# SSH to instance (replace with your key and IP)
ssh -i ~/.ssh/your-key.pem ubuntu@52.90.150.69
```

### 2.2 Install Prerequisites

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu

# Install Docker Compose plugin and BuildKit
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL -o /usr/local/lib/docker/cli-plugins/docker-compose https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Install Git
sudo apt install -y git

# Verify installations
docker --version
docker compose version
git --version
```

> **Note**: Ollama is now containerized - no separate installation required.
> Models are pulled inside the container after starting Docker Compose.

## Step 3: Deploy Application

### 3.1 Clone Repository

```bash
# Clone your HRAS repository
git clone https://github.com/owezzy/HRAS.git
cd HRAS

# Or if using private repo
git clone https://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n@github.com/owezzy/HRAS.git
cd HRAS
```

### 3.2 Environment Configuration

```bash
# Copy environment template
cp backend/.env.example backend/.env

# Edit environment variables
nano backend/.env
```

**Production Environment Variables:**
```env
# Database
DATABASE_URL=postgresql+asyncpg://hras:hras_prod_password@postgres:5432/hras
USE_POSTGRES=true

# LLM Configuration (containerized Ollama)
OLLAMA_BASE_URL=http://ollama:11434
OLLAMA_MODEL=nemotron-3-nano:30b-cloud
OLLAMA_EMBEDDING_MODEL=nomic-embed-text

# Vector Store
CHROMA_PERSIST_DIRECTORY=/app/chroma_db

# Application
DEBUG=false
APP_ENV=production
LOG_LEVEL=INFO

# CORS (replace with your domain)
CORS_ORIGINS=["https://hras.owezzy.tech", "https://www.hras.owezzy.tech"]
```

### 3.3 Start Services

```bash
# Log out and back in to refresh Docker group membership
exit
ssh -i ~/.ssh/your-key.pem ubuntu@your-elastic-ip
cd HRAS

# Build backend image with BuildKit enabled
DOCKER_BUILDKIT=1 docker build -t hras-backend:latest -f zarf/docker/dockerfile.backend .

# Start full stack with monitoring (skip build since we built manually)
docker compose -f zarf/docker/compose/docker-compose.yml --profile full up -d --no-build

# Verify all services are running
docker compose -f zarf/docker/compose/docker-compose.yml ps

# View logs if needed
docker compose -f zarf/docker/compose/docker-compose.yml logs backend
docker compose -f zarf/docker/compose/docker-compose.yml logs grafana
docker compose -f zarf/docker/compose/docker-compose.yml logs prometheus
```

### 3.4 Pull Ollama Models

Once the Ollama container is running, pull the required models:

```bash
# Pull embedding model (required for RAG)
docker compose -f zarf/docker/compose/docker-compose.yml exec ollama ollama pull nomic-embed-text

# Pull LLM model (choose one based on your instance size)
# For t3.large (8GB): cloud model via authenticated Ollama
docker compose -f zarf/docker/compose/docker-compose.yml exec ollama ollama pull nemotron-3-nano:30b-cloud

# Alternative: For t3.medium (4GB) use a smaller local model
# docker compose -f zarf/docker/compose/docker-compose.yml exec ollama ollama pull llama3.2:3b

# Verify models are available
docker compose -f zarf/docker/compose/docker-compose.yml exec ollama ollama list
```

> **Cloud Model Authentication**: The `nemotron-3-nano:30b-cloud` model requires Ollama authentication.
> Run `ollama login` on your host machine first, then mount credentials into container.
> Credentials are automatically mounted from `~/.ollama/id_ed25519*`.

### 3.5 Initialize Data

```bash
# Wait for services to be healthy (1-2 minutes after model pull)
sleep 60

# Ingest initial documents
curl -X POST http://localhost:8000/api/v1/admin/ingest \
  -H "Content-Type: application/json"

# Verify ingestion
curl http://localhost:8000/api/v1/admin/stats

# Test chat endpoint
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What human rights recommendations exist for Kenya?"}'
```

## Step 4: Verify Deployment

### 4.1 Check Service Health

```bash
# Backend API health
curl http://your-elastic-ip:8000/health

# Prometheus metrics
curl http://your-elastic-ip:8000/metrics

# Grafana (should return HTML)
curl http://your-elastic-ip:3001/

# Prometheus web UI
curl http://your-elastic-ip:9090/
```

### 4.2 Access Web Interfaces

Open in browser:
- **Backend API**: http://your-elastic-ip:8000/docs
- **Grafana**: http://your-elastic-ip:3001 (no login required)
- **Prometheus**: http://your-elastic-ip:9090

### 4.3 Test Full Pipeline

```bash
# Test RAG pipeline
curl -X POST http://your-elastic-ip:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Explain the treaty body reporting process for human rights"
  }'
```

## Next Steps

1. **Configure Custom Domain** - Set up hras.owezzy.tech
2. **Deploy Frontend** - AWS Amplify setup
3. **Set up Alerts** - Configure alerting rules
4. **Security Hardening** - Production security checklist

Expected monthly cost: ~$23 (EC2 t3.small + EBS + Elastic IP)
