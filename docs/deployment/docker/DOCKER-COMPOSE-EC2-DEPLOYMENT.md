# HRAS Production Deployment Guide (Docker Compose on EC2)

## Cost-Optimized Setup (~$9-19/month)

This guide deploys HRAS on a budget EC2 instance using Docker Compose as a systemd service.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS EC2                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                    Docker Compose                    │    │
│  │  ┌─────────┐  ┌─────────┐  ┌──────────────────┐    │    │
│  │  │  Nginx  │──│ Backend │──│ SQLite/PostgreSQL│    │    │
│  │  │  :80/443│  │  :8000  │  │                  │    │    │
│  │  └─────────┘  └────┬────┘  └──────────────────┘    │    │
│  │                    │                                │    │
│  │              ┌─────▼─────┐                         │    │
│  │              │  Ollama   │  (alpine/ollama:latest) │    │
│  │              │  :11434   │  51MB CPU-only image    │    │
│  │              └───────────┘                         │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
         │
         │ HTTPS
         ▼
┌─────────────────────┐
│   AWS Amplify       │
│   (Frontend)        │
│   feature-backend.. │
└─────────────────────┘
```

---

## Step 1: Choose EC2 Instance

### Recommended: t3.small ($15-19/month)

| Instance    | vCPU | RAM  | Cost (us-east-1) | Use Case                                    |
|-------------|------|------|------------------|---------------------------------------------|
| t3.micro    | 2    | 1GB  | ~$9/month        | ❌ Too small                                |
| **t3.small**| 2    | 2GB  | ~$15/month       | ✅ Embeddings only (cloud LLM recommended)  |
| t3.medium   | 2    | 4GB  | ~$30/month       | ✅ Small local models (llama3.2:3b)         |
| t3.large    | 2    | 8GB  | ~$60/month       | ✅ Full stack + cloud/larger models         |

> **Ollama is containerized**: Uses lightweight `alpine/ollama:latest` (51MB).
> Models are pulled into the container after deployment.

---

## Step 2: Launch EC2 Instance

### 2.1 AWS Console Setup

1. Go to **EC2 → Launch Instance**

2. **Name**: `hras-production`

3. **AMI**: Amazon Linux 2023 (free tier eligible)

4. **Instance type**: `t3.small`

5. **Key pair**: Create or select existing (save the .pem file!)

6. **Network settings**:
   - Create security group with:
     - SSH (22) from your IP
     - HTTP (80) from anywhere
     - HTTPS (443) from anywhere

7. **Storage**: 20GB gp3 (free tier: 30GB)

8. **Launch instance**

### 2.2 Allocate Elastic IP (Optional but Recommended)

```bash
# Prevents IP change on instance restart
# AWS Console → EC2 → Elastic IPs → Allocate → Associate with instance
```

---

## Step 3: Initial Server Setup

### 3.1 Connect to EC2

```bash
# Replace with your key and public IP
chmod 400 your-key.pem
ssh -i your-key.pem ec2-user@<EC2_PUBLIC_IP>
```

### 3.2 System Updates & Docker Installation

```bash
# Update system
sudo dnf update -y

# Install Docker
sudo dnf install -y docker git
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user

# Install Docker Compose plugin
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Verify installation
docker --version
docker compose version

# Re-login to apply docker group
exit
```

### 3.3 Reconnect and Continue

```bash
ssh -i your-key.pem ec2-user@<EC2_PUBLIC_IP>
```

---

## Step 4: Deploy HRAS

### 4.1 Clone Repository

```bash
sudo mkdir -p /opt/hras
sudo chown ec2-user:ec2-user /opt/hras
cd /opt/hras

git clone --branch feature/backend-refactor-testing https://github.com/owezzy/HRAS.git .
```

### 4.2 Create Data Directories

```bash
# Create all required directories
sudo mkdir -p /opt/hras/data/{backend,certbot/data,certbot/challenges}
sudo mkdir -p /opt/hras/logs/{nginx,backend,certbot}
sudo chown -R 1000:1000 /opt/hras/data /opt/hras/logs
```

### 4.3 Configure Environment

```bash
# Copy example config
cp .env.prod.example .env.prod

# Edit with your values
nano .env.prod
```

**Minimum required changes in `.env.prod`:**

```bash
# Your domain (or use EC2 public IP for testing)
DOMAIN=<EC2_PUBLIC_IP>
FRONTEND_DOMAIN=feature-backend-refactor-testing.d3q35zh7ig6w8u.amplifyapp.com

# Generate secure passwords (run these commands)
# openssl rand -hex 32
SECRET_KEY=<generated_64_char_hex>
JWT_SECRET_KEY=<generated_64_char_hex>

# Ollama is containerized - use container hostname
OLLAMA_BASE_URL=http://ollama:11434

# CORS - include your Amplify frontend
CORS_ORIGINS=["https://feature-backend-refactor-testing.d3q35zh7ig6w8u.amplifyapp.com","http://localhost:3000"]
```

### 4.4 Choose Docker Compose Configuration

**Option A: Minimal (t3.small - 2GB RAM)**

Use the lightweight configuration with SQLite and no monitoring:

```bash
# Use minimal compose file
export COMPOSE_FILE=zarf/docker/compose/docker-compose.minimal.yml
```

**Option B: Full (t3.medium+ - 4GB+ RAM)**

Use the full production configuration with PostgreSQL and monitoring:

```bash
# Use full compose file
export COMPOSE_FILE=zarf/docker/compose/docker-compose.prod.yml
```

---

## Step 5: Install as Systemd Service

### 5.1 Install Service

```bash
# For minimal deployment, update service file to use minimal compose
sudo sed -i 's/docker-compose.prod.yml/docker-compose.minimal.yml/g' zarf/docker/hras.service

# Copy service file
sudo cp zarf/docker/hras.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable on boot
sudo systemctl enable hras
```

### 5.2 Start HRAS

```bash
# Start the service
sudo systemctl start hras

# Check status
sudo systemctl status hras

# View logs
sudo journalctl -u hras -f
```

### 5.3 Pull Ollama Models

After services are running, pull models into the Ollama container:

```bash
cd /opt/hras

# Pull embedding model (required)
docker compose exec ollama ollama pull nomic-embed-text

# Pull LLM model based on instance size:
# t3.small/medium: Use cloud model (requires authentication)
docker compose exec ollama ollama pull nemotron-3-nano:30b-cloud

# Alternative for t3.medium: Use smaller local model
# docker compose exec ollama ollama pull llama3.2:3b

# Verify models
docker compose exec ollama ollama list
```

> **Cloud Model Auth**: For `nemotron-3-nano:30b-cloud`, run `ollama login` on host first.
> Credentials from `~/.ollama/` are mounted into the container automatically.

---

## Step 6: Configure SSL (HTTPS)

### Option A: Using Let's Encrypt (Requires Domain)

If you have a domain pointing to your EC2:

```bash
# Install certbot
sudo dnf install -y certbot

# Get certificate
sudo certbot certonly --standalone -d your-domain.com

# Certificate will be at /etc/letsencrypt/live/your-domain.com/
```

### Option B: Self-Signed (For Testing)

```bash
# Generate self-signed cert
sudo mkdir -p /opt/hras/data/certbot/data/live/hras
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /opt/hras/data/certbot/data/live/hras/privkey.pem \
  -out /opt/hras/data/certbot/data/live/hras/fullchain.pem \
  -subj "/CN=localhost"
```

### Option C: HTTP Only (Simplest for Testing)

Skip SSL for initial testing - works over HTTP on port 80.

---

## Step 7: Verify Deployment

### 7.1 Health Check

```bash
# From EC2
curl http://localhost:8000/health

# From your machine (replace with EC2 IP)
curl http://<EC2_PUBLIC_IP>/health
```

Expected response:
```json
{"status": "healthy", "version": "0.2.0"}
```

### 7.2 Test CORS

```bash
# Test preflight request
curl -X OPTIONS http://<EC2_PUBLIC_IP>/api/v1/chat \
  -H "Origin: https://feature-backend-refactor-testing.d3q35zh7ig6w8u.amplifyapp.com" \
  -H "Access-Control-Request-Method: POST" \
  -v
```

Should return `Access-Control-Allow-Origin` header.

---

## Step 8: Connect Frontend

Update your Amplify frontend environment:

```bash
NEXT_PUBLIC_API_URL=http://<EC2_PUBLIC_IP>
# or with HTTPS:
NEXT_PUBLIC_API_URL=https://your-domain.com
```

---

## Maintenance Commands

```bash
# Service management
sudo systemctl start hras
sudo systemctl stop hras
sudo systemctl restart hras
sudo systemctl status hras

# View logs
sudo journalctl -u hras -f                                        # Service logs
docker compose -f zarf/docker/compose/docker-compose.prod.yml logs -f backend   # Backend logs
docker compose -f zarf/docker/compose/docker-compose.prod.yml logs -f nginx     # Nginx logs

# Update deployment
cd /opt/hras
git pull origin feature/backend-refactor-testing
sudo systemctl reload hras              # Recreates containers

# Manual container management
docker compose -f zarf/docker/compose/docker-compose.prod.yml ps
docker compose -f zarf/docker/compose/docker-compose.prod.yml logs -f
docker compose -f zarf/docker/compose/docker-compose.prod.yml down
docker compose -f zarf/docker/compose/docker-compose.prod.yml up -d
```

---

## Cost Breakdown (Monthly)

| Resource             | Cost          |
|----------------------|---------------|
| t3.small (on-demand) | ~$15.00       |
| EBS 20GB gp3         | ~$1.60        |
| Elastic IP (if used) | ~$3.60        |
| Data transfer (10GB) | ~$0.90        |
| **Total**            | **~$19-21**   |

### Cost Optimization Tips

1. **Reserved Instance**: 1-year commitment → ~$10/month (40% savings)
2. **Spot Instance**: ~$5/month (but can be interrupted)
3. **Use SQLite**: Skip PostgreSQL container → saves RAM
4. **External LLM**: Use OpenAI API instead of local Ollama

---

## Troubleshooting

### Container won't start

```bash
# Check logs
docker compose -f zarf/docker/compose/docker-compose.prod.yml logs backend

# Check resource usage
docker stats

# Verify env file
cat .env.prod
```

### Out of memory

```bash
# Check memory
free -h

# Reduce workers in .env.prod
UVICORN_WORKERS=1

# Use swap (not recommended for production)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### CORS errors

```bash
# Verify CORS_ORIGINS in .env.prod matches your frontend URL exactly
# Check nginx logs for blocked requests
docker compose logs nginx | grep -i cors
```

### Port already in use

```bash
# Find what's using the port
sudo lsof -i :80
sudo lsof -i :8000

# Kill the process or change ports in docker-compose
```

---

## Security Checklist

- [ ] Change default passwords in `.env.prod`
- [ ] Restrict SSH to your IP in security group
- [ ] Enable HTTPS with valid SSL certificate
- [ ] Set `DEBUG=false` in production
- [ ] Configure AWS CloudWatch for monitoring
- [ ] Set up automated backups for data volumes
- [ ] Review and rotate secrets periodically

---

## Next Steps

1. **Domain Setup**: Point a domain to your EC2 Elastic IP
2. **SSL**: Configure Let's Encrypt for HTTPS
3. **Monitoring**: Enable CloudWatch or deploy Prometheus/Grafana
4. **Backups**: Set up automated EBS snapshots
5. **Scaling**: Consider moving to K3s or ECS for auto-scaling
