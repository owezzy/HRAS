#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../docker/config/deployment.env"

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" | tee -a ssl-setup.log
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a ssl-setup.log >&2
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" | tee -a ssl-setup.log
}

setup_letsencrypt_http() {
    log_info "Setting up Let's Encrypt SSL with HTTP challenge..."

    sudo mkdir -p /var/www/html/.well-known/acme-challenge
    sudo chown -R www-data:www-data /var/www/html

    sudo certbot certonly \
        --webroot \
        --webroot-path=/var/www/html \
        --email ${EMAIL} \
        --agree-tos \
        --no-eff-email \
        -d ${DOMAIN} \
        --non-interactive

    sudo ln -sf /etc/letsencrypt/live/${DOMAIN}/fullchain.pem /opt/hras/ssl/fullchain.pem
    sudo ln -sf /etc/letsencrypt/live/${DOMAIN}/privkey.pem /opt/hras/ssl/privkey.pem

    log_success "Let's Encrypt SSL certificate obtained via HTTP challenge"
}

setup_letsencrypt_dns() {
    log_info "Setting up Let's Encrypt SSL with DNS challenge..."

    if [[ -z "${ROUTE53_HOSTED_ZONE_ID:-}" ]]; then
        log_error "ROUTE53_HOSTED_ZONE_ID not set for DNS challenge"
        exit 1
    fi

    sudo certbot certonly \
        --dns-route53 \
        --email ${EMAIL} \
        --agree-tos \
        --no-eff-email \
        -d ${DOMAIN} \
        -d "*.${DOMAIN}" \
        --non-interactive

    sudo ln -sf /etc/letsencrypt/live/${DOMAIN}/fullchain.pem /opt/hras/ssl/fullchain.pem
    sudo ln -sf /etc/letsencrypt/live/${DOMAIN}/privkey.pem /opt/hras/ssl/privkey.pem

    log_success "Let's Encrypt SSL certificate obtained via DNS challenge"
}

setup_cloudflare_ssl() {
    log_info "Setting up Cloudflare SSL..."

    if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
        log_error "CLOUDFLARE_API_TOKEN not set for Cloudflare SSL"
        exit 1
    fi

    sudo pip3 install certbot-dns-cloudflare

    sudo tee /etc/letsencrypt/cloudflare.ini > /dev/null << EOF
dns_cloudflare_api_token = ${CLOUDFLARE_API_TOKEN}
EOF

    sudo chmod 600 /etc/letsencrypt/cloudflare.ini

    sudo certbot certonly \
        --dns-cloudflare \
        --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
        --email ${EMAIL} \
        --agree-tos \
        --no-eff-email \
        -d ${DOMAIN} \
        -d "*.${DOMAIN}" \
        --non-interactive

    sudo ln -sf /etc/letsencrypt/live/${DOMAIN}/fullchain.pem /opt/hras/ssl/fullchain.pem
    sudo ln -sf /etc/letsencrypt/live/${DOMAIN}/privkey.pem /opt/hras/ssl/privkey.pem

    log_success "Cloudflare SSL certificate obtained"
}

setup_ssl_renewal() {
    log_info "Setting up SSL certificate auto-renewal..."

    sudo tee /etc/systemd/system/certbot-renewal.service > /dev/null << 'EOF'
[Unit]
Description=Certbot Renewal Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --quiet --no-self-upgrade --post-hook "systemctl reload nginx"
StandardOutput=append:/opt/hras/logs/app/certbot-renewal.log
StandardError=append:/opt/hras/logs/app/certbot-renewal-error.log
EOF

    sudo tee /etc/systemd/system/certbot-renewal.timer > /dev/null << 'EOF'
[Unit]
Description=Run Certbot Renewal twice daily
Requires=certbot-renewal.service

[Timer]
OnCalendar=*-*-* 00,12:00:00
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable certbot-renewal.timer
    sudo systemctl start certbot-renewal.timer

    log_success "SSL auto-renewal configured"
}

test_ssl_configuration() {
    log_info "Testing SSL configuration..."

    if ! sudo nginx -t; then
        log_error "Nginx configuration test failed"
        return 1
    fi

    sudo systemctl reload nginx

    sleep 5

    if curl -sSf https://${DOMAIN}/health > /dev/null 2>&1; then
        log_success "SSL configuration test passed"
        return 0
    else
        log_error "SSL configuration test failed - HTTPS endpoint not responding"
        return 1
    fi
}

main() {
    log_info "Starting SSL certificate setup for ${DOMAIN}..."

    case "${SSL_PROVIDER:-letsencrypt}" in
        "letsencrypt")
            if [[ "${SSL_CHALLENGE:-http}" == "dns" ]]; then
                setup_letsencrypt_dns
            else
                setup_letsencrypt_http
            fi
            ;;
        "cloudflare")
            setup_cloudflare_ssl
            ;;
        *)
            log_error "Unknown SSL provider: ${SSL_PROVIDER:-letsencrypt}"
            exit 1
            ;;
    esac

    setup_ssl_renewal

    if test_ssl_configuration; then
        log_success "SSL setup completed successfully!"
        echo "
SSL Certificate Information:
- Domain: ${DOMAIN}
- Provider: ${SSL_PROVIDER:-letsencrypt}
- Challenge: ${SSL_CHALLENGE:-http}
- Auto-renewal: Enabled (twice daily)
- Certificate location: /opt/hras/ssl/

You can now access your site at: https://${DOMAIN}
"
    else
        log_error "SSL setup completed but configuration test failed"
        exit 1
    fi
}

main "$@"
