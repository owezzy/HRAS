#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../docker/config/deployment.env"

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" | tee -a monitoring-setup.log
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a monitoring-setup.log >&2
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" | tee -a monitoring-setup.log
}

setup_prometheus_config() {
    log_info "Setting up Prometheus configuration..."

    mkdir -p /opt/hras/app/monitoring

    cat > /opt/hras/app/monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    scrape_interval: 30s

  - job_name: 'hras-backend'
    static_configs:
      - targets: ['backend:8000']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
    scrape_interval: 30s

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']
    scrape_interval: 30s

  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']
    scrape_interval: 30s

  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx-exporter:9113']
    scrape_interval: 30s
EOF

    log_success "Prometheus configuration created"
}

setup_prometheus_rules() {
    log_info "Setting up Prometheus alerting rules..."

    mkdir -p /opt/hras/app/monitoring/rules

    cat > /opt/hras/app/monitoring/rules/hras.yml << 'EOF'
groups:
  - name: hras-alerts
    rules:
      - alert: HRASBackendDown
        expr: up{job="hras-backend"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "HRAS Backend is down"
          description: "HRAS Backend has been down for more than 1 minute"

      - alert: HRASHighResponseTime
        expr: http_request_duration_seconds{quantile="0.95"} > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High response time for HRAS"
          description: "95th percentile response time is {{ $value }}s"

      - alert: HRASHighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High error rate in HRAS"
          description: "Error rate is {{ $value }} errors per second"

      - alert: PostgreSQLDown
        expr: up{job="postgres"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "PostgreSQL is down"
          description: "PostgreSQL database has been down for more than 1 minute"

      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage"
          description: "CPU usage is {{ $value }}% on {{ $labels.instance }}"

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High memory usage"
          description: "Memory usage is {{ $value }}% on {{ $labels.instance }}"

      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space"
          description: "Disk space is {{ $value }}% full on {{ $labels.instance }}"

      - alert: SSLCertificateExpiringSoon
        expr: probe_ssl_earliest_cert_expiry - time() < 7 * 24 * 3600
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "SSL certificate expiring soon"
          description: "SSL certificate expires in {{ $value | humanizeDuration }}"
EOF

    log_success "Prometheus alerting rules created"
}

setup_grafana_datasources() {
    log_info "Setting up Grafana datasources..."

    mkdir -p /opt/hras/app/monitoring/grafana/datasources

    cat > /opt/hras/app/monitoring/grafana/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
EOF

    log_success "Grafana datasources configured"
}

setup_grafana_dashboards() {
    log_info "Setting up Grafana dashboards..."

    mkdir -p /opt/hras/app/monitoring/grafana/dashboards

    cat > /opt/hras/app/monitoring/grafana/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'HRAS Dashboards'
    orgId: 1
    folder: 'HRAS'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

    cat > /opt/hras/app/monitoring/grafana/dashboards/hras-overview.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "HRAS Overview",
    "tags": ["hras"],
    "style": "dark",
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Application Status",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=\"hras-backend\"}",
            "legendFormat": "Backend"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "mappings": [
              {
                "options": {
                  "0": {
                    "text": "DOWN",
                    "color": "red"
                  },
                  "1": {
                    "text": "UP",
                    "color": "green"
                  }
                },
                "type": "value"
              }
            ]
          }
        },
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 0
        }
      },
      {
        "id": 2,
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "Requests/sec"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 12,
          "y": 0
        }
      },
      {
        "id": 3,
        "title": "Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "http_request_duration_seconds{quantile=\"0.95\"}",
            "legendFormat": "95th percentile"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 8
        }
      },
      {
        "id": 4,
        "title": "Error Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total{status=~\"5..\"}[5m])",
            "legendFormat": "5xx errors/sec"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 12,
          "y": 8
        }
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "5s"
  }
}
EOF

    log_success "Grafana dashboards configured"
}

setup_alertmanager() {
    log_info "Setting up Alertmanager..."

    mkdir -p /opt/hras/app/monitoring

    cat > /opt/hras/app/monitoring/alertmanager.yml << EOF
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@${DOMAIN}'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
  - name: 'web.hook'
    webhook_configs:
      - url: '${ALERTMANAGER_WEBHOOK_URL:-http://localhost:5001/}'
        send_resolved: true

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
EOF

    log_success "Alertmanager configured"
}

setup_nginx_monitoring() {
    log_info "Setting up Nginx monitoring..."

    sudo tee /etc/nginx/conf.d/status.conf > /dev/null << 'EOF'
server {
    listen 127.0.0.1:8080;
    server_name localhost;

    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        allow 172.20.0.0/16;
        deny all;
    }
}
EOF

    sudo nginx -t && sudo systemctl reload nginx

    log_success "Nginx monitoring configured"
}

setup_log_monitoring() {
    log_info "Setting up log monitoring..."

    mkdir -p /opt/hras/app/monitoring/loki

    cat > /opt/hras/app/monitoring/loki/loki.yml << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /tmp/loki
  storage:
    filesystem:
      chunks_directory: /tmp/loki/chunks
      rules_directory: /tmp/loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093

analytics:
  reporting_enabled: false
EOF

    log_success "Log monitoring configured"
}

setup_monitoring_services() {
    log_info "Setting up monitoring systemd services..."

    sudo tee /etc/systemd/system/hras-monitoring.service > /dev/null << 'EOF'
[Unit]
Description=HRAS Monitoring Stack
After=network.target docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/hras/app
ExecStart=/usr/bin/docker-compose -f zarf/docker/compose/docker-compose.prod.yml up -d prometheus grafana node-exporter
ExecStop=/usr/bin/docker-compose -f zarf/docker/compose/docker-compose.prod.yml stop prometheus grafana node-exporter
StandardOutput=append:/opt/hras/logs/app/monitoring.log
StandardError=append:/opt/hras/logs/app/monitoring-error.log

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable hras-monitoring.service

    log_success "Monitoring systemd services configured"
}

verify_monitoring_setup() {
    log_info "Verifying monitoring setup..."

    cd /opt/hras/app

    if docker-compose -f zarf/docker/compose/docker-compose.prod.yml up -d prometheus grafana node-exporter; then
        log_success "Monitoring services started"

        sleep 30

        local endpoints=(
            "http://localhost:9090/-/healthy"
            "http://localhost:3001/api/health"
            "http://localhost:9100/metrics"
        )

        for endpoint in "${endpoints[@]}"; do
            if curl -sSf "$endpoint" >/dev/null 2>&1; then
                log_success "Endpoint responding: $endpoint"
            else
                log_error "Endpoint not responding: $endpoint"
                return 1
            fi
        done

        return 0
    else
        log_error "Failed to start monitoring services"
        return 1
    fi
}

main() {
    log_info "Starting HRAS monitoring setup..."

    if [[ "${ENABLE_MONITORING:-true}" != "true" ]]; then
        log_info "Monitoring disabled in configuration, skipping setup"
        exit 0
    fi

    setup_prometheus_config
    setup_prometheus_rules
    setup_grafana_datasources
    setup_grafana_dashboards
    setup_alertmanager
    setup_nginx_monitoring
    setup_log_monitoring
    setup_monitoring_services

    if verify_monitoring_setup; then
        log_success "Monitoring setup completed successfully!"

        echo "
===========================================
HRAS Monitoring Setup Complete
===========================================

Monitoring Services:
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3001 (admin/${GRAFANA_ADMIN_PASSWORD:-admin})
- Node Exporter: http://localhost:9100/metrics

Grafana Dashboards:
- HRAS Overview: Pre-configured dashboard for application metrics
- System Metrics: CPU, memory, disk usage
- Application Performance: Request rates, response times, errors

Alerting:
- Prometheus rules configured for critical alerts
- Alertmanager webhook: ${ALERTMANAGER_WEBHOOK_URL:-not configured}

Management Commands:
- Start monitoring: sudo systemctl start hras-monitoring
- Stop monitoring: sudo systemctl stop hras-monitoring
- View logs: sudo journalctl -u hras-monitoring -f

Next Steps:
1. Configure alert webhook URL in deployment.env
2. Set up notification channels in Grafana
3. Customize alerting rules as needed
4. Monitor system performance
"
    else
        log_error "Monitoring setup failed"
        exit 1
    fi
}

main "$@"
