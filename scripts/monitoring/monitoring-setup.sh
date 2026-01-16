#!/bin/bash

set -euo pipefail

echo "📊 Setting up monitoring and alerting for HRAS..."

DEPLOYMENT_DIR="/opt/hras"
MONITORING_DIR="/opt/hras/monitoring"

mkdir -p "$MONITORING_DIR"
cd "$MONITORING_DIR"

echo "🐳 Creating monitoring Docker Compose..."
cat > docker-compose.monitoring.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: hras-prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=15d'
      - '--web.enable-lifecycle'
    restart: unless-stopped
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: hras-grafana
    ports:
      - "3001:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin123}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=https://${DOMAIN:-localhost}/grafana
      - GF_SERVER_SERVE_FROM_SUB_PATH=true
    restart: unless-stopped
    networks:
      - monitoring

  alertmanager:
    image: prom/alertmanager:latest
    container_name: hras-alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager:/etc/alertmanager
      - alertmanager_data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.external-url=http://localhost:9093'
    restart: unless-stopped
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    container_name: hras-node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    restart: unless-stopped
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: hras-cadvisor
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    privileged: true
    restart: unless-stopped
    networks:
      - monitoring

volumes:
  prometheus_data:
  grafana_data:
  alertmanager_data:

networks:
  monitoring:
    driver: bridge
EOF

echo "📊 Creating Prometheus configuration..."
mkdir -p prometheus
cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'hras-backend'
    static_configs:
      - targets: ['host.docker.internal:8000']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'hras-frontend'
    static_configs:
      - targets: ['host.docker.internal:3000']
    metrics_path: '/api/metrics'
    scrape_interval: 30s

  - job_name: 'nginx'
    static_configs:
      - targets: ['host.docker.internal:80']
    metrics_path: '/nginx_status'
    scrape_interval: 30s
EOF

echo "🚨 Creating Prometheus alert rules..."
cat > prometheus/alert_rules.yml << 'EOF'
groups:
- name: hras_alerts
  rules:
  - alert: ServiceDown
    expr: up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Service {{ $labels.job }} is down"
      description: "{{ $labels.job }} has been down for more than 1 minute."

  - alert: HighCPUUsage
    expr: (100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 80
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage on {{ $labels.instance }}"
      description: "CPU usage is above 80% for more than 2 minutes."

  - alert: HighMemoryUsage
    expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage on {{ $labels.instance }}"
      description: "Memory usage is above 85% for more than 2 minutes."

  - alert: DiskSpaceLow
    expr: (1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})) * 100 > 90
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Low disk space on {{ $labels.instance }}"
      description: "Disk usage is above 90%."

  - alert: ContainerDown
    expr: absent(container_last_seen{name=~"hras-.*"})
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Container {{ $labels.name }} is not running"
      description: "HRAS container {{ $labels.name }} has been down for more than 1 minute."

  - alert: SSLCertExpiring
    expr: probe_ssl_earliest_cert_expiry - time() < 86400 * 30
    for: 1h
    labels:
      severity: warning
    annotations:
      summary: "SSL certificate expiring soon"
      description: "SSL certificate for {{ $labels.instance }} expires in less than 30 days."
EOF

echo "📧 Creating Alertmanager configuration..."
mkdir -p alertmanager
cat > alertmanager/alertmanager.yml << EOF
global:
  smtp_smarthost: '${SMTP_HOST:-localhost:587}'
  smtp_from: '${ALERT_EMAIL_FROM:-alerts@${DOMAIN:-localhost}}'
  smtp_auth_username: '${SMTP_USERNAME:-}'
  smtp_auth_password: '${SMTP_PASSWORD:-}'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
- name: 'web.hook'
  email_configs:
  - to: '${ALERT_EMAIL_TO:-admin@${DOMAIN:-localhost}}'
    subject: '[HRAS Alert] {{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
    body: |
      {{ range .Alerts }}
      Alert: {{ .Annotations.summary }}
      Description: {{ .Annotations.description }}
      Instance: {{ .Labels.instance }}
      Severity: {{ .Labels.severity }}
      {{ end }}

  slack_configs:
  - api_url: '${SLACK_WEBHOOK_URL:-}'
    channel: '#alerts'
    title: 'HRAS Alert'
    text: '{{ range .Alerts }}{{ .Annotations.summary }}: {{ .Annotations.description }}{{ end }}'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
EOF

echo "📈 Creating Grafana provisioning..."
mkdir -p grafana/provisioning/{datasources,dashboards}

cat > grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

cat > grafana/provisioning/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'HRAS Dashboards'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: /var/lib/grafana/dashboards
EOF

echo "📊 Creating HRAS Dashboard..."
mkdir -p grafana/dashboards
cat > grafana/dashboards/hras-overview.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "HRAS Overview",
    "tags": ["hras"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Service Status",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=~\"hras-.*\"}",
            "legendFormat": "{{ job }}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "mappings": [
              {
                "options": {
                  "0": {
                    "text": "DOWN"
                  },
                  "1": {
                    "text": "UP"
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
        "title": "HTTP Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{ method }} {{ handler }}"
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
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "95th percentile"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 24,
          "x": 0,
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

echo "🔧 Creating monitoring management script..."
cat > manage-monitoring.sh << 'EOF'
#!/bin/bash

set -euo pipefail

COMMAND=${1:-status}

case $COMMAND in
  start)
    echo "🚀 Starting monitoring stack..."
    docker-compose -f docker-compose.monitoring.yml up -d
    ;;
  stop)
    echo "🛑 Stopping monitoring stack..."
    docker-compose -f docker-compose.monitoring.yml down
    ;;
  restart)
    echo "🔄 Restarting monitoring stack..."
    docker-compose -f docker-compose.monitoring.yml restart
    ;;
  status)
    echo "📊 Monitoring stack status:"
    docker-compose -f docker-compose.monitoring.yml ps
    echo ""
    echo "🌐 Access URLs:"
    echo "  Grafana: http://localhost:3001 (admin/${GRAFANA_ADMIN_PASSWORD:-admin123})"
    echo "  Prometheus: http://localhost:9090"
    echo "  Alertmanager: http://localhost:9093"
    ;;
  logs)
    SERVICE=${2:-}
    if [[ -n "$SERVICE" ]]; then
      docker-compose -f docker-compose.monitoring.yml logs -f "$SERVICE"
    else
      docker-compose -f docker-compose.monitoring.yml logs -f
    fi
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|logs [service]}"
    exit 1
    ;;
esac
EOF

chmod +x manage-monitoring.sh

echo "🚀 Starting monitoring stack..."
docker-compose -f docker-compose.monitoring.yml up -d

echo "⏳ Waiting for services to start..."
sleep 30

echo "✅ Monitoring setup complete!"
echo ""
echo "📊 Access URLs:"
echo "  Grafana: http://localhost:3001"
echo "  Prometheus: http://localhost:9090"
echo "  Alertmanager: http://localhost:9093"
echo ""
echo "📋 Management:"
echo "  Start: ./manage-monitoring.sh start"
echo "  Stop: ./manage-monitoring.sh stop"
echo "  Status: ./manage-monitoring.sh status"
echo "  Logs: ./manage-monitoring.sh logs [service]"
echo ""
echo "🔧 Configuration files:"
echo "  Prometheus: ./prometheus/prometheus.yml"
echo "  Alertmanager: ./alertmanager/alertmanager.yml"
echo "  Grafana dashboards: ./grafana/dashboards/"
