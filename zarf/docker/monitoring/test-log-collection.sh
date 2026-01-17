#!/bin/bash
set -euo pipefail

# HRAS Log Collection Test Script
# Tests the Loki + Promtail + Grafana monitoring stack

echo "🔍 HRAS Monitoring Stack Test"
echo "=============================="

LOKI_URL="http://localhost:3100"
GRAFANA_URL="http://localhost:3001"
TIMEOUT=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# Test 1: Check if containers are running
echo -e "\n${BLUE}1. Checking container status...${NC}"
containers=("hras-loki" "hras-promtail" "hras-grafana" "hras-backend" "hras-caddy" "hras-postgres" "hras-ollama")

for container in "${containers[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        print_status "OK" "Container $container is running"
    else
        print_status "ERROR" "Container $container is not running"
    fi
done

# Test 2: Check Loki health
echo -e "\n${BLUE}2. Testing Loki health...${NC}"
if curl -sf "${LOKI_URL}/ready" > /dev/null 2>&1; then
    print_status "OK" "Loki is healthy and ready"
else
    print_status "ERROR" "Loki is not responding at $LOKI_URL"
    exit 1
fi

# Test 3: Check Promtail metrics
echo -e "\n${BLUE}3. Testing Promtail metrics...${NC}"
if docker exec hras-promtail wget -q -O- http://localhost:3100/metrics | grep -q "promtail_build_info"; then
    print_status "OK" "Promtail metrics endpoint is working"
else
    print_status "WARN" "Promtail metrics may not be accessible"
fi

# Test 4: Generate test logs and verify collection
echo -e "\n${BLUE}4. Generating test logs...${NC}"

# Generate backend test logs
print_status "INFO" "Generating structured JSON logs in backend container"
docker exec hras-backend python -c '
import json
import sys
from datetime import datetime

test_logs = [
    {"level": "INFO", "message": "Test log collection - API health check", "timestamp": datetime.utcnow().isoformat() + "Z", "service": "hras-backend", "request_id": "test-001", "event_type": "test.health"},
    {"level": "WARN", "message": "Test warning message", "timestamp": datetime.utcnow().isoformat() + "Z", "service": "hras-backend", "request_id": "test-002", "event_type": "test.warn"},
    {"level": "ERROR", "message": "Test error for log aggregation", "timestamp": datetime.utcnow().isoformat() + "Z", "service": "hras-backend", "request_id": "test-003", "event_type": "test.error"}
]

for log in test_logs:
    print(json.dumps(log), flush=True)
' || print_status "WARN" "Could not generate backend test logs"

# Generate Caddy test logs
print_status "INFO" "Generating test request to create Caddy logs"
if command -v curl > /dev/null; then
    curl -s "http://localhost:80/health" > /dev/null || print_status "WARN" "Could not generate Caddy test logs"
fi

# Test 5: Wait and query logs from Loki
echo -e "\n${BLUE}5. Waiting for logs to be ingested...${NC}"
sleep 10

# Test 6: Query logs by service
echo -e "\n${BLUE}6. Testing log queries...${NC}"

# Query backend logs
print_status "INFO" "Querying backend logs from Loki"
backend_query='{container="hras-backend"}'
backend_result=$(curl -s -G "${LOKI_URL}/loki/api/v1/query" --data-urlencode "query=$backend_query" --data-urlencode "limit=10" || echo "")

if echo "$backend_result" | grep -q '"status":"success"'; then
    log_count=$(echo "$backend_result" | jq -r '.data.result | length' 2>/dev/null || echo "0")
    if [ "$log_count" -gt 0 ]; then
        print_status "OK" "Found $log_count backend log streams in Loki"

        # Show sample log entry
        sample_log=$(echo "$backend_result" | jq -r '.data.result[0].values[0][1]' 2>/dev/null || echo "")
        if [ -n "$sample_log" ] && [ "$sample_log" != "null" ]; then
            print_status "INFO" "Sample backend log: $sample_log"
        fi
    else
        print_status "WARN" "No backend logs found in Loki"
    fi
else
    print_status "ERROR" "Failed to query backend logs from Loki"
fi

# Query Caddy logs
print_status "INFO" "Querying Caddy logs from Loki"
caddy_query='{container="hras-caddy"}'
caddy_result=$(curl -s -G "${LOKI_URL}/loki/api/v1/query" --data-urlencode "query=$caddy_query" --data-urlencode "limit=10" || echo "")

if echo "$caddy_result" | grep -q '"status":"success"'; then
    log_count=$(echo "$caddy_result" | jq -r '.data.result | length' 2>/dev/null || echo "0")
    if [ "$log_count" -gt 0 ]; then
        print_status "OK" "Found $log_count Caddy log streams in Loki"
    else
        print_status "WARN" "No Caddy logs found in Loki"
    fi
else
    print_status "ERROR" "Failed to query Caddy logs from Loki"
fi

# Test 7: Check Grafana data source
echo -e "\n${BLUE}7. Testing Grafana integration...${NC}"
if curl -sf "${GRAFANA_URL}/api/health" > /dev/null 2>&1; then
    print_status "OK" "Grafana is accessible"

    # Test Loki data source
    datasource_test=$(curl -s "${GRAFANA_URL}/api/datasources/proxy/uid/loki/loki/api/v1/labels" 2>/dev/null || echo "")
    if echo "$datasource_test" | grep -q "container"; then
        print_status "OK" "Grafana can query Loki successfully"
    else
        print_status "WARN" "Grafana-Loki data source may need configuration"
    fi
else
    print_status "WARN" "Grafana is not accessible at $GRAFANA_URL"
fi

# Test 8: Label verification
echo -e "\n${BLUE}8. Verifying log labels...${NC}"
labels_result=$(curl -s "${LOKI_URL}/loki/api/v1/labels" || echo "")
if echo "$labels_result" | grep -q '"status":"success"'; then
    print_status "OK" "Loki labels endpoint is working"

    # Check for expected labels
    expected_labels=("container" "service" "job" "stream" "level")
    for label in "${expected_labels[@]}"; do
        if echo "$labels_result" | grep -q "\"$label\""; then
            print_status "OK" "Label '$label' is available"
        else
            print_status "WARN" "Label '$label' not found"
        fi
    done
else
    print_status "ERROR" "Failed to retrieve labels from Loki"
fi

# Test 9: Show useful queries for debugging
echo -e "\n${BLUE}9. Useful LogQL queries for HRAS:${NC}"
print_status "INFO" "Backend logs: {container=\"hras-backend\"}"
print_status "INFO" "Error logs: {container=\"hras-backend\"} |= \"ERROR\""
print_status "INFO" "JSON parsed: {container=\"hras-backend\"} | json | level=\"ERROR\""
print_status "INFO" "Request logs: {container=\"hras-backend\"} | json | event_type=~\".*request.*\""
print_status "INFO" "AI/ML logs: {container=\"hras-backend\"} | json | event_type=~\"ai\\..+\""
print_status "INFO" "Caddy access: {container=\"hras-caddy\"} |= \"http\""
print_status "INFO" "All services: {job=~\"hras-.+\"}"

# Summary
echo -e "\n${BLUE}📊 Test Summary${NC}"
echo "==============="
print_status "INFO" "Log collection test completed"
print_status "INFO" "Check Grafana at: $GRAFANA_URL"
print_status "INFO" "Access Loki directly at: $LOKI_URL"
print_status "INFO" "Sample LogQL query: {container=\"hras-backend\"} | json | level=\"INFO\""

echo -e "\n${YELLOW}💡 Next Steps:${NC}"
echo "1. Open Grafana and verify Loki data source"
echo "2. Create dashboards with the provided LogQL queries"
echo "3. Set up alerting rules for ERROR level logs"
echo "4. Monitor log ingestion rates in Prometheus"

echo -e "\n${GREEN}✅ Log collection test finished!${NC}"
