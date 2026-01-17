# HRAS Monitoring Stack Configuration

Fixed Loki + Promtail + Grafana log collection for HRAS Docker deployment.

## 🔧 Issues Fixed

### 1. **Container Log Collection**
- **Problem**: Promtail was looking for file-based logs (`/var/log/backend/`) but HRAS containers log to stdout
- **Fix**: Updated Promtail to use Docker service discovery with proper container log access

### 2. **JSON Log Parsing**
- **Problem**: Promtail expected `message` field but HRAS backend uses structlog with `event` field
- **Fix**: Updated JSON parsing pipeline to extract correct fields from structured logs

### 3. **Service Coverage**
- **Problem**: Configuration included nginx, redis, certbot but HRAS uses Caddy, PostgreSQL, Ollama
- **Fix**: Removed irrelevant services and added proper HRAS container configs

### 4. **Container Filtering**
- **Problem**: Generic docker discovery without proper HRAS container targeting
- **Fix**: Added specific container name filters and proper labeling

## 📁 File Structure

```
zarf/docker/monitoring/
├── promtail.yml              # ✅ Fixed - Docker container log collection
├── loki.yml                  # ✅ Enhanced - Better limits and retention
├── grafana/
│   └── datasources/
│       └── datasources.yml   # ✅ Verified - Loki connection
└── test-log-collection.sh    # 🆕 New - Comprehensive test script
```

## 🎯 Container Coverage

| Service | Container Name | Log Type | Status |
|---------|---------------|----------|---------|
| **Backend** | `hras-backend` | Structured JSON | ✅ Fixed |
| **Caddy** | `hras-caddy` | Access/Error logs | ✅ Fixed |
| **PostgreSQL** | `hras-postgres` | Database logs | ✅ Fixed |
| **Ollama** | `hras-ollama` | LLM service logs | ✅ Fixed |
| **Monitoring** | `hras-prometheus`, `hras-grafana`, `hras-loki` | System logs | ✅ Fixed |

## 🔍 Key Changes Made

### Promtail Configuration (`promtail.yml`)

**Before:**
```yaml
# Static file paths that don't exist in containers
- job_name: hras-backend
  static_configs:
    - targets: [localhost]
      labels:
        __path__: /var/log/backend/*.log  # ❌ Wrong path
  pipeline_stages:
    - json:
        expressions:
          message: message                # ❌ Wrong field
```

**After:**
```yaml
# Docker service discovery with proper container targeting
- job_name: hras-backend
  docker_sd_configs:
    - host: unix:///var/run/docker.sock
      filters:
        - name: name
          values: ["hras-backend"]        # ✅ Specific targeting
  pipeline_stages:
    - docker: {}                         # ✅ Parse Docker JSON format
    - json:
        expressions:
          message: event                  # ✅ Correct structlog field
          level: level
          timestamp: timestamp
          service: service
          request_id: request_id
```

### Backend JSON Structure Handled

HRAS backend emits structured JSON logs via structlog:

```json
{
  "timestamp": "2026-01-17T20:30:15.123Z",
  "level": "INFO",
  "event": "chat_session_started",
  "service": "hras-backend",
  "version": "1.0.0",
  "environment": "production",
  "request_id": "req-12345",
  "user_id": "user-67890",
  "event_type": "ai.inference"
}
```

Promtail now correctly extracts:
- **Message**: `event` field (not `message`)
- **Labels**: `level`, `service`, `environment`, `event_type`
- **Timestamp**: ISO8601 format from `timestamp` field
- **Context**: `request_id`, `user_id` for tracing

## 🚀 Quick Start

### 1. Deploy Stack
```bash
cd /Users/owen_adirah/WebstormProjects/HRAS

# Start full monitoring stack
docker compose -f zarf/docker/compose/docker-compose.yml up -d --profile full

# Verify containers
docker ps | grep hras-
```

### 2. Test Log Collection
```bash
# Run comprehensive test
./zarf/docker/monitoring/test-log-collection.sh

# Check specific container logs
docker logs hras-promtail
docker logs hras-loki
```

### 3. Access Interfaces
- **Grafana**: http://localhost:3001 (admin/admin - anonymous enabled)
- **Loki API**: http://localhost:3100
- **Prometheus**: http://localhost:9090

## 📊 Useful LogQL Queries

### Backend Application Logs
```logql
# All backend logs
{container="hras-backend"}

# Error logs only
{container="hras-backend"} | json | level="ERROR"

# AI/ML inference logs
{container="hras-backend"} | json | event_type=~"ai\\..*"

# Request tracing by ID
{container="hras-backend"} | json | request_id="req-12345"

# Performance monitoring
{container="hras-backend"} | json | duration_ms > 1000
```

### Infrastructure Logs
```logql
# Caddy access logs
{container="hras-caddy"}

# Database logs
{container="hras-postgres"}

# All HRAS services
{job=~"hras-.*"}

# Error aggregation across services
{job=~"hras-.*"} |= "ERROR"
```

### Advanced Queries
```logql
# Request rate by endpoint
rate({container="hras-backend"} | json | method="POST"[5m])

# Error rate percentage
(
  rate({container="hras-backend"} | json | level="ERROR"[5m]) /
  rate({container="hras-backend"}[5m])
) * 100

# Top error messages
topk(10,
  count by (event) (
    {container="hras-backend"} | json | level="ERROR"
  )
)
```

## 🔧 Troubleshooting

### Promtail Not Collecting Logs

1. **Check container access**:
```bash
docker exec hras-promtail ls -la /var/run/docker.sock
docker exec hras-promtail ls -la /var/log/
```

2. **Verify Promtail targets**:
```bash
curl http://localhost:3100/targets
```

3. **Check Promtail logs**:
```bash
docker logs hras-promtail | grep -E "(error|failed|target)"
```

### Loki Connection Issues

1. **Test Loki health**:
```bash
curl http://localhost:3100/ready
curl http://localhost:3100/metrics
```

2. **Check ingestion**:
```bash
curl -G "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={container="hras-backend"}' \
  --data-urlencode 'limit=5'
```

### Grafana Data Source

1. **Test connection**:
```bash
curl http://localhost:3001/api/datasources/proxy/uid/loki/loki/api/v1/labels
```

2. **Re-provision if needed**:
```bash
docker compose restart hras-grafana
```

## 📈 Monitoring Metrics

The monitoring stack collects:

### Application Metrics (Prometheus)
- Request rates and latencies
- AI/ML inference metrics
- Database connection pools
- Custom HRAS business metrics

### Log Metrics (Loki/Promtail)
- Log ingestion rates
- Error rates by service
- Request tracing
- Structured event analysis

### Infrastructure Metrics
- Container resource usage
- Database performance
- Reverse proxy metrics
- LLM service health

## 🔄 Maintenance

### Log Retention
- **Loki**: 7 days (168h) configured in `loki.yml`
- **Promtail**: Position tracking in `/tmp/positions.yaml`
- **Docker**: JSON log files rotated by Docker engine

### Scaling Considerations
- Increase Loki `ingestion_rate_mb` for high-volume logging
- Add Loki clustering for production workloads
- Use persistent volumes for Grafana dashboards

### Security
- Anonymous access enabled for development
- Production: Configure authentication for Grafana
- Production: Enable Loki multi-tenancy if needed

## ✅ Validation Checklist

After deployment, verify:

- [ ] All HRAS containers running (`docker ps`)
- [ ] Promtail discovering targets (`curl localhost:3100/targets`)
- [ ] Loki ingesting logs (`curl Loki query API`)
- [ ] Grafana accessing Loki (`curl datasource proxy`)
- [ ] Backend JSON logs parsed correctly
- [ ] Request tracing working with `request_id`
- [ ] Error logs aggregated and searchable
- [ ] Dashboards showing metrics and logs

## 🎯 Next Steps

1. **Create Dashboards**: Build Grafana dashboards for HRAS-specific metrics
2. **Set Up Alerting**: Configure alerts for error rates, performance degradation
3. **Log Analysis**: Use LogQL for business intelligence and debugging
4. **Performance Tuning**: Monitor ingestion rates and optimize as needed

---

**Configuration Status**: ✅ **FIXED** - Ready for production log collection
