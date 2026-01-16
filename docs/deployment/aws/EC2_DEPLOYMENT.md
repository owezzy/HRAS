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
1. **AMI**: Amazon Linux 2023 AMI (HVM)
2. **Instance Type**: t3.small (2 vCPU, 2 GB RAM)
3. **Key Pair**: Select your existing key pair
4. **Security Group**: hras-backend-sg
5. **Storage**: 20 GB gp3 EBS volume
6. **Tag**: Name = "hras-backend"

**Via AWS CLI:**
```bash
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \
  --count 1 \
  --instance-type t3.small \
  --key-name your-key-pair \
  --security-groups hras-backend-sg \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=hras-backend}]' \
  --block-device-mappings 'DeviceName=/dev/xvda,Ebs={VolumeSize=20,VolumeType=gp3}'
```

### 1.3 Allocate Elastic IP

```bash
# Allocate Elastic IP
aws ec2 allocate-address --domain vpc

# Associate with instance (replace with your instance-id and allocation-id)
aws ec2 associate-address \
  --instance-id i-1234567890abcdef0 \
  --allocation-id eipalloc-12345678
```

## Step 2: Server Setup

### 2.1 Connect to Instance

```bash
# SSH to instance (replace with your key and IP)
ssh -i ~/.ssh/your-key.pem ec2-user@your-elastic-ip
```

### 2.2 Install Prerequisites

```bash
# Update system
sudo yum update -y

# Install Docker
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Git
sudo yum install -y git

# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh
sudo systemctl enable ollama
sudo systemctl start ollama

# Verify installations
docker --version
docker-compose --version
git --version
ollama --version
```

### 2.3 Configure Ollama

```bash
# Download models (this may take 10-20 minutes)
ollama pull nemotron-3-nano:30b-cloud
ollama pull nomic-embed-text

# Verify models are available
ollama list

# Test model inference
ollama run nemotron-3-nano:30b-cloud "Hello, how are you?"
```

## Step 3: Deploy Application

### 3.1 Clone Repository

```bash
# Clone your HRAS repository
git clone https://github.com/your-username/HRAS.git
cd HRAS

# Or if using private repo
git clone https://your-token@github.com/your-username/HRAS.git
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

# LLM Configuration
OLLAMA_BASE_URL=http://host.docker.internal:11434
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
ssh -i ~/.ssh/your-key.pem ec2-user@your-elastic-ip
cd HRAS

# Start full stack with monitoring
docker compose -f zarf/docker/compose/docker-compose.yml --profile full up -d

# Verify all services are running
docker compose ps

# View logs if needed
docker compose logs backend
docker compose logs grafana
docker compose logs prometheus
```

### 3.4 Initialize Data

```bash
# Wait for services to be healthy (2-3 minutes)
sleep 180

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
