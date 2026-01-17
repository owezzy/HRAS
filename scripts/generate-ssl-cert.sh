#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="$SCRIPT_DIR/../zarf/docker/caddy/certs"

IP="${1:-18.215.166.248}"

mkdir -p "$CERTS_DIR"

echo "Generating self-signed certificate for IP: $IP"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$CERTS_DIR/key.pem" \
    -out "$CERTS_DIR/cert.pem" \
    -subj "/CN=$IP" \
    -addext "subjectAltName=IP:$IP"

chmod 644 "$CERTS_DIR/cert.pem"
chmod 600 "$CERTS_DIR/key.pem"

echo "Certificate generated successfully:"
echo "  - $CERTS_DIR/cert.pem"
echo "  - $CERTS_DIR/key.pem"
echo ""
echo "Certificate details:"
openssl x509 -in "$CERTS_DIR/cert.pem" -noout -text | grep -E "(Subject:|IP Address:)"
