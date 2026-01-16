# AWS Deployment Troubleshooting Guide

Common issues and solutions for HRAS AWS deployment.

## General Debugging

### Check Service Status
```bash
# SSH to EC2 instance
ssh -i ~/.ssh/your-key.pem ec2-user@your-elastic-ip

# Check all containers
docker compose -f zarf/docker/compose/docker-compose.yml ps

# Check specific service logs
docker logs hras-backend
docker logs hras-grafana
docker logs hras-prometheus
```

## Backend Issues

### Issue: Backend Container Won't Start
```bash
# Check detailed logs
docker compose -f zarf/docker/compose/docker-compose.yml logs backend

# Common causes:
# 1. Ollama not accessible
curl http://localhost:11434/api/version

# 2. Database connection issues
docker logs hras-postgres

# 3. Environment variables missing
cat backend/.env
```

**Solution:**
```bash
# Restart Ollama service
sudo systemctl restart ollama

# Verify models are downloaded
ollama list

# Check PostgreSQL is healthy
docker compose -f zarf/docker/compose/docker-compose.yml exec postgres pg_isready -U hras
```

### Issue: "Can't connect to Ollama"
```bash
# Check Ollama status
sudo systemctl status ollama

# Check if models are downloaded
ollama list

# Test Ollama directly
ollama run nemotron-3-nano:30b-cloud "Hello"
```

**Solution:**
```bash
# If Ollama isn't running
sudo systemctl start ollama
sudo systemctl enable ollama

# If models are missing
ollama pull nemotron-3-nano:30b-cloud
ollama pull nomic-embed-text

# Update backend environment
# Ensure OLLAMA_BASE_URL=http://host.docker.internal:11434
```

### Issue: "Database connection failed"
```bash
# Check PostgreSQL logs
docker logs hras-postgres

# Test connection
docker compose -f zarf/docker/compose/docker-compose.yml exec postgres psql -U hras -d hras -c "SELECT 1;"
```

**Solution:**
```bash
# Restart PostgreSQL
docker compose -f zarf/docker/compose/docker-compose.yml restart postgres

# Wait for healthy status
docker compose -f zarf/docker/compose/docker-compose.yml ps postgres

# Verify database URL in backend/.env
DATABASE_URL=postgresql+asyncpg://hras:hras_prod_password@postgres:5432/hras
```

## Frontend Issues (AWS Amplify)

### Issue: Amplify Build Fails
```bash
# Check build logs in Amplify Console
# Common errors and solutions:
```

**Error: "Module not found"**
```bash
# Check amplify.yml working directory
appRoot: frontend

# Verify package.json exists
ls frontend/package.json

# Check build command
npm run build  # Should succeed locally
```

**Error: "Out of memory"**
```bash
# In amplify.yml, add memory limit
env:
  variables:
    NODE_OPTIONS: "--max-old-space-size=4096"
```

### Issue: API Calls Fail from Frontend
```bash
# Check browser console for CORS errors
# Verify NEXT_PUBLIC_API_URL is correct

# Test API directly
curl -X POST https://api.hras.owezzy.tech/api/v1/chat \
  -H "Content-Type: application/json" \
  -H "Origin: https://hras.owezzy.tech" \
  -d '{"message": "test"}'
```

**Solution:**
```bash
# Update backend CORS in backend/.env
CORS_ORIGINS=["https://hras.owezzy.tech", "https://www.hras.owezzy.tech"]

# Restart backend
docker compose -f zarf/docker/compose/docker-compose.yml restart backend

# Update Amplify environment variables
NEXT_PUBLIC_API_URL = https://api.hras.owezzy.tech
```

## Monitoring Issues

### Issue: Grafana Shows No Data
```bash
# Check if Prometheus is running
curl http://localhost:9090/api/v1/targets

# Check if backend metrics are available
curl http://localhost:8000/metrics | grep hras_

# Check Grafana logs
docker logs hras-grafana | grep -i error
```

**Solution:**
```bash
# Restart Prometheus
docker compose -f zarf/docker/compose/docker-compose.yml restart prometheus

# Wait 2-3 minutes for data collection
# Refresh Grafana dashboard
```

### Issue: "Prometheus Can't Scrape Backend"
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'

# Check if backend container is accessible from Prometheus
docker compose -f zarf/docker/compose/docker-compose.yml exec prometheus wget -O- http://backend:8000/metrics
```

**Solution:**
```bash
# Verify containers are on same network
docker network ls
docker compose -f zarf/docker/compose/docker-compose.yml ps

# Check prometheus.yml configuration
cat zarf/monitoring/prometheus.yml
```

## SSL/Domain Issues

### Issue: "SSL Certificate Error"
```bash
# Check certificate status
curl -I https://api.hras.owezzy.tech
# Look for certificate errors

# Check Let's Encrypt certificate
sudo certbot certificates
```

**Solution:**
```bash
# Renew certificate
sudo certbot renew

# Restart nginx
docker compose -f zarf/docker/compose/docker-compose.yml restart nginx
```

### Issue: "Domain Not Resolving"
```bash
# Check DNS resolution
nslookup hras.owezzy.tech
nslookup api.hras.owezzy.tech

# Check from different location
dig hras.owezzy.tech @8.8.8.8
```

**Solution:**
```bash
# Wait for DNS propagation (up to 48 hours)
# Verify DNS records in CloudFlare/Route53
# Check TTL values (lower = faster propagation)
```

## Performance Issues

### Issue: "High Memory Usage"
```bash
# Check container memory usage
docker stats

# Check EC2 instance memory
free -h
top
```

**Solution:**
```bash
# Restart high-memory containers
docker compose -f zarf/docker/compose/docker-compose.yml restart backend

# Consider upgrading to t3.medium if consistently high
# Or optimize Prometheus retention
--storage.tsdb.retention.time=3d
```

### Issue: "Slow RAG Queries"
```bash
# Check metrics in Grafana
# Query: histogram_quantile(0.95, sum(rate(hras_rag_query_duration_seconds_bucket[5m])) by (le))

# Check Ollama performance
time ollama run nemotron-3-nano:30b-cloud "Quick test"

# Check ChromaDB size
du -sh chroma_db/
```

**Solution:**
```bash
# Consider smaller model for faster inference
ollama pull nemotron-3-nano:7b  # Instead of 30b

# Optimize vector search
# Reduce top_k in retrieval settings

# Check if models fit in RAM
ollama ps
```

## Security Issues

### Issue: "Unauthorized Access to Monitoring"
```bash
# Check security group rules
aws ec2 describe-security-groups --group-names hras-backend-sg
```

**Solution:**
```bash
# Restrict access to monitoring ports
aws ec2 revoke-security-group-ingress \
  --group-name hras-backend-sg \
  --protocol tcp --port 3001 --cidr 0.0.0.0/0

# Add your IP only
aws ec2 authorize-security-group-ingress \
  --group-name hras-backend-sg \
  --protocol tcp --port 3001 --cidr your-ip/32
```

## Data Issues

### Issue: "No Documents in Vector Store"
```bash
# Check ingestion status
curl http://localhost:8000/api/v1/admin/stats

# Check ChromaDB logs
docker logs hras-backend | grep -i chroma

# Manually trigger ingestion
curl -X POST http://localhost:8000/api/v1/admin/ingest
```

**Solution:**
```bash
# Verify documents exist in data/ directory
ls -la backend/data/

# Check ChromaDB volume mount
docker compose -f zarf/docker/compose/docker-compose.yml ps backend

# Restart with clean ChromaDB (if needed)
docker volume rm hras_chroma_data
docker compose -f zarf/docker/compose/docker-compose.yml up -d backend
```

## Network Issues

### Issue: "Can't Access Services from Outside"
```bash
# Check security group
aws ec2 describe-security-groups --group-names hras-backend-sg

# Check if service is listening
netstat -tlnp | grep :8000
```

**Solution:**
```bash
# Ensure service binds to 0.0.0.0, not 127.0.0.1
# Check docker compose port mappings:
ports:
  - "8000:8000"  # Correct
  # not "127.0.0.1:8000:8000"  # Wrong
```

## Cost Issues

### Issue: "Unexpected High AWS Bill"
```bash
# Check current costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost

# Check resource usage
aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name]'
```

**Solution:**
```bash
# Stop non-essential services
docker compose -f zarf/docker/compose/docker-compose.yml stop frontend

# Use smaller instance type (if needed)
# t3.micro instead of t3.small (less RAM but cheaper)

# Set up billing alerts
aws cloudwatch put-metric-alarm --alarm-name "High-AWS-Bill" --metric-name EstimatedCharges
```

## Emergency Recovery

### Issue: "Complete System Failure"
```bash
# Create new EC2 instance
# Follow EC2_DEPLOYMENT.md from step 1

# Restore data from backups
# PostgreSQL: docker run --rm -v backup.sql:/backup.sql postgres:17-alpine psql
# ChromaDB: docker run --rm -v backup.tar.gz:/backup.tar.gz alpine tar xzf /backup.tar.gz
```

### Issue: "Lost SSH Access"
```bash
# Use EC2 Instance Connect (AWS Console)
# Or create new key pair and associate

# Emergency access via Systems Manager (if enabled)
aws ssm start-session --target i-1234567890abcdef0
```

## Useful Debugging Commands

### Container Debugging
```bash
# Get shell in container
docker compose -f zarf/docker/compose/docker-compose.yml exec backend bash

# Check container resource limits
docker inspect hras-backend | grep -i memory

# View real-time logs
docker compose -f zarf/docker/compose/docker-compose.yml logs -f backend
```

### Network Debugging
```bash
# Test connectivity between containers
docker compose -f zarf/docker/compose/docker-compose.yml exec backend curl http://postgres:5432
docker compose -f zarf/docker/compose/docker-compose.yml exec prometheus wget -O- http://backend:8000/metrics
```

### System Health Check Script
Create `scripts/health-check.sh`:
```bash
#!/bin/bash
echo "=== HRAS Health Check ==="

# Check containers
echo "Container Status:"
docker compose -f zarf/docker/compose/docker-compose.yml ps

# Check key endpoints
echo -e "\nEndpoint Health:"
curl -s http://localhost:8000/health || echo "❌ Backend unhealthy"
curl -s http://localhost:9090/-/healthy || echo "❌ Prometheus unhealthy"
curl -s http://localhost:3001/api/health || echo "❌ Grafana unhealthy"

# Check disk space
echo -e "\nDisk Usage:"
df -h

# Check memory
echo -e "\nMemory Usage:"
free -h

echo "=== Health Check Complete ==="
```

## Getting Help

1. **Check Docker Logs**: Always start with container logs
2. **Verify Network**: Ensure containers can communicate
3. **Check Resources**: Monitor CPU, memory, disk usage
4. **Test Endpoints**: Use curl to verify service health
5. **Review Configurations**: Check environment variables and config files

For additional support, check:
- Docker Compose documentation
- AWS Amplify documentation
- Prometheus/Grafana documentation
- HRAS project GitHub issues

Most issues can be resolved by restarting services and checking logs systematically.
