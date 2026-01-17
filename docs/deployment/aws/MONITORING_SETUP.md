# AWS Monitoring Setup Guide

Complete guide for configuring Prometheus and Grafana monitoring stack in production AWS environment.

## Overview

Your HRAS deployment includes comprehensive monitoring:
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization dashboards (open access)
- **Backend Metrics**: 18+ metric types from FastAPI application
- **System Metrics**: EC2 instance and PostgreSQL monitoring

## Step 1: Verify Monitoring Stack

### 1.1 Check Service Status

```bash
# SSH to your EC2 instance
ssh -i ~/.ssh/your-key.pem ec2-user@your-elastic-ip

# Navigate to HRAS directory
cd HRAS

# Check all services are running
docker compose ps

# Expected output:
# hras-backend         running   0.0.0.0:8000->8000/tcp
# hras-grafana         running   0.0.0.0:3001->3000/tcp
# hras-prometheus      running   0.0.0.0:9090->9090/tcp
# hras-postgres        running   0.0.0.0:5433->5432/tcp
```

### 1.2 Test Metrics Endpoints

```bash
# Backend metrics (should return Prometheus format)
curl http://localhost:8000/metrics | head -20

# Prometheus targets (should show healthy targets)
curl http://localhost:9090/api/v1/targets | jq .

# Grafana health
curl http://localhost:3001/api/health
```

## Step 2: Access Monitoring Dashboards

### 2.1 Set Up SSH Tunnel (Recommended for Security)

Monitoring services run on EC2 but are NOT exposed publicly. Access them via SSH tunnel:

```bash
# From your local machine, create SSH tunnel
ssh -i ~/.ssh/your-key.pem -L 3001:localhost:3001 -L 9090:localhost:9090 ubuntu@<your-ec2-ip>

# Keep this terminal open. In another terminal, access:
# Grafana:    http://localhost:3001
# Prometheus: http://localhost:9090
```

### 2.2 Open Grafana Dashboard

**URL**: http://localhost:3001 (via SSH tunnel)

- **Authentication**: None required (configured for internal access)
- **Default Dashboard**: HRAS Overview (auto-loaded)
- **Additional Dashboards**: HRAS Technical Metrics

**Note**: Grafana and Prometheus ports (3001, 9090) should NOT be in your EC2 security group. Keep them internal-only.

### 2.2 Key Dashboards

**1. HRAS Overview Dashboard**
- HTTP request rates and status codes
- RAG query latency (P50, P95, P99)
- Active chat sessions
- Vector store document count
- Model inference performance
- Agent workflow success rates

**2. HRAS Technical Dashboard**
- Database operation metrics
- Token usage by LLM model
- Error rates by component
- Document ingestion rates
- Agent step execution details

### 2.3 Prometheus Query Interface

**URL**: http://localhost:9090 (via SSH tunnel)

**Key Queries to Try:**
```promql
# HTTP request rate
sum(rate(hras_http_requests_total[5m]))

# RAG query P95 latency
histogram_quantile(0.95, sum(rate(hras_rag_query_duration_seconds_bucket[5m])) by (le))

# Error rate percentage
sum(rate(hras_errors_total[5m])) / sum(rate(hras_http_requests_total[5m])) * 100

# Active sessions
hras_chat_sessions_active

# Vector store size
hras_vectorstore_documents
```

## Step 3: Configure Alerting (Optional)

### 3.1 Create Alert Rules

Create `zarf/monitoring/alerts/hras-alerts.yml`:

```yaml
groups:
  - name: hras-critical
    rules:
      - alert: HighErrorRate
        expr: sum(rate(hras_http_requests_total{status_code=~"5.."}[5m])) / sum(rate(hras_http_requests_total[5m])) > 0.05
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value | humanizePercentage }} for the last 5 minutes"

      - alert: RAGQuerySlow
        expr: histogram_quantile(0.95, sum(rate(hras_rag_query_duration_seconds_bucket[5m])) by (le)) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "RAG queries are slow"
          description: "95th percentile latency is {{ $value }}s"

      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "{{ $labels.job }} has been down for more than 1 minute"

      - alert: LowVectorStoreDocuments
        expr: hras_vectorstore_documents < 100
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Low document count in vector store"
          description: "Only {{ $value }} documents in vector store"
```

### 3.2 Configure Alertmanager (Optional)

Add Alertmanager service to `docker-compose.yml`:

```yaml
alertmanager:
  image: prom/alertmanager:latest
  container_name: hras-alertmanager
  ports:
    - "9093:9093"
  volumes:
    - ../../../zarf/monitoring/alertmanager:/etc/alertmanager:ro
    - alertmanager_data:/alertmanager
  command:
    - '--config.file=/etc/alertmanager/alertmanager.yml'
    - '--storage.path=/alertmanager'
    - '--web.external-url=http://localhost:9093'
  profiles:
    - monitoring
    - full
```

Create `zarf/monitoring/alertmanager/alertmanager.yml`:

```yaml
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@hras.owezzy.tech'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
  - name: 'web.hook'
    email_configs:
      - to: 'admin@hras.owezzy.tech'
        subject: 'HRAS Alert: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          {{ end }}
```

## Step 4: Custom Metrics Integration

### 4.1 Add Business Metrics

Your backend already exports comprehensive metrics. To add custom metrics:

```python
# In backend/src/app/core/metrics.py
from prometheus_client import Counter, Histogram

# Add custom business metrics
SUCCESSFUL_QUERIES_BY_COUNTRY = Counter(
    'hras_successful_queries_by_country_total',
    'Successful queries by country',
    ['country']
)

QUERY_COMPLEXITY = Histogram(
    'hras_query_complexity_score',
    'Query complexity scoring',
    buckets=(0.1, 0.5, 1.0, 2.0, 5.0, 10.0)
)
```

Use in your application:
```python
# In your chat service
SUCCESSFUL_QUERIES_BY_COUNTRY.labels(country=detected_country).inc()
QUERY_COMPLEXITY.observe(calculate_complexity_score(query))
```

### 4.2 Frontend Monitoring Integration

Add frontend performance monitoring to your Next.js app:

```bash
# Install web vitals
cd frontend
npm install web-vitals
```

Create `frontend/lib/analytics.ts`:
```typescript
import { getCLS, getFID, getFCP, getLCP, getTTFB } from 'web-vitals'

function sendToAnalytics({ name, delta, value, id }: any) {
  // Send to your backend or analytics service
  fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/metrics/web-vitals`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name, delta, value, id, timestamp: Date.now() })
  })
}

export function reportWebVitals() {
  getCLS(sendToAnalytics)
  getFID(sendToAnalytics)
  getFCP(sendToAnalytics)
  getLCP(sendToAnalytics)
  getTTFB(sendToAnalytics)
}
```

## Step 5: Log Aggregation

### 5.1 Configure Centralized Logging

Add log aggregation to your monitoring stack:

```yaml
# Add to docker-compose.yml
loki:
  image: grafana/loki:latest
  container_name: hras-loki
  ports:
    - "3100:3100"
  volumes:
    - ../../../zarf/monitoring/loki:/etc/loki:ro
    - loki_data:/loki
  command: -config.file=/etc/loki/loki.yml
  profiles:
    - monitoring
    - full

promtail:
  image: grafana/promtail:latest
  container_name: hras-promtail
  volumes:
    - ../../../zarf/monitoring/promtail:/etc/promtail:ro
    - /var/log:/var/log:ro
    - /var/lib/docker/containers:/var/lib/docker/containers:ro
  command: -config.file=/etc/promtail/promtail.yml
  profiles:
    - monitoring
    - full
```

### 5.2 Configure Log Parsing

Create `zarf/monitoring/loki/loki.yml`:
```yaml
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1

schema_config:
  configs:
    - from: 2023-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
```

## Step 6: Production Monitoring Checklist

### 6.1 Security Hardening

**IMPORTANT**: Do NOT expose monitoring ports publicly.

```bash
# Ensure ports 3001 and 9090 are NOT in your security group
# Access monitoring only via SSH tunnel

# If you need to revoke public access:
aws ec2 revoke-security-group-ingress \
  --group-name hras-backend-sg \
  --protocol tcp --port 3001 --cidr 0.0.0.0/0

aws ec2 revoke-security-group-ingress \
  --group-name hras-backend-sg \
  --protocol tcp --port 9090 --cidr 0.0.0.0/0
```

### 6.2 Backup Configuration

```bash
# Backup Prometheus data
docker run --rm \
  -v hras_prometheus_data:/prometheus \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/prometheus-$(date +%Y%m%d).tar.gz /prometheus

# Backup Grafana configuration
docker run --rm \
  -v hras_grafana_data:/grafana \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/grafana-$(date +%Y%m%d).tar.gz /grafana
```

### 6.3 Monitoring the Monitoring

Add health checks for your monitoring stack:

```bash
# Check if Prometheus is scraping successfully
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'

# Check Grafana datasource connectivity
curl -s http://localhost:3001/api/datasources/proxy/1/api/v1/query?query=up | jq .
```

## Step 7: Cost Optimization

### 7.1 Configure Retention Policies

```yaml
# In Prometheus config
global:
  scrape_interval: 15s  # Don't go below 10s
  evaluation_interval: 15s

# In command args:
--storage.tsdb.retention.time=7d  # Adjust based on needs
--storage.tsdb.retention.size=5GB
```

### 7.2 Monitor Resource Usage

```bash
# Check container resource usage
docker stats

# Check disk usage
df -h
du -sh /var/lib/docker/volumes/hras_prometheus_data/
du -sh /var/lib/docker/volumes/hras_grafana_data/
```

## Troubleshooting Common Issues

### Issue: Grafana Shows No Data

```bash
# Check Prometheus connection
docker logs hras-grafana | grep -i prometheus

# Verify Prometheus is scraping backend
curl http://localhost:9090/api/v1/targets

# Check backend metrics endpoint
curl http://localhost:8000/metrics
```

### Issue: High Memory Usage

```bash
# Check Prometheus memory usage
docker stats hras-prometheus

# Reduce scrape frequency if needed
# Edit zarf/monitoring/prometheus.yml:
scrape_interval: 30s  # Instead of 15s
```

### Issue: Missing Metrics

```bash
# Check if backend metrics middleware is active
docker logs hras-backend | grep -i metrics

# Verify metrics are being exported
curl http://localhost:8000/metrics | grep hras_
```

## Monitoring URLs Summary

After successful deployment, access monitoring services:

**Via SSH Tunnel (Recommended for Security):**
```bash
# Set up SSH tunnel from your local machine
ssh -i ~/.ssh/your-key.pem -L 3001:localhost:3001 -L 9090:localhost:9090 ubuntu@<your-ec2-ip>

# Then access from your browser:
# - Grafana: http://localhost:3001
# - Prometheus: http://localhost:9090
```

**Access via SSH Tunnel (Recommended):**
- **Grafana Dashboards**: http://localhost:3001 (after SSH tunnel)
  - No authentication required for internal access
  - HRAS Overview dashboard pre-loaded
  - HRAS Technical dashboard available

- **Prometheus**: http://localhost:9090 (after SSH tunnel)
  - Query interface for custom metrics exploration
  - Target health monitoring

- **Raw Metrics**: http://localhost:8000/metrics (internal only)
  - Backend Prometheus metrics endpoint
  - 18+ different metric types available
  - Access via SSH tunnel or from within EC2

**Security Note**: Monitoring ports (3001, 9090) are NOT exposed publicly. All remote access is via SSH tunneling. This prevents unauthorized access to monitoring data.

Your monitoring stack provides comprehensive observability into:
- ✅ HTTP request performance and errors
- ✅ RAG pipeline latency and success rates
- ✅ LLM inference performance and token usage
- ✅ Vector search operations and results
- ✅ Agent workflow execution and success
- ✅ Database operations and connection health
- ✅ Business metrics (conversations, messages, documents)

**Total monitoring cost**: $0 additional (runs on same EC2 instance)
