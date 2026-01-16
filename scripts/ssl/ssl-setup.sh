#!/bin/bash

set -euo pipefail

DOMAIN=${DOMAIN:-}
EMAIL=${LETSENCRYPT_EMAIL:-}
AWS_REGION=${AWS_REGION:-us-east-1}

if [[ -z "$DOMAIN" ]]; then
    echo "❌ DOMAIN environment variable is required"
    exit 1
fi

if [[ -z "$EMAIL" ]]; then
    echo "❌ LETSENCRYPT_EMAIL environment variable is required"
    exit 1
fi

echo "🔒 Setting up SSL certificates for $DOMAIN..."

echo "📝 Creating Nginx configuration..."
cat > /etc/nginx/sites-available/hras << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;

    # SSL Configuration (will be updated by certbot)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    # Modern SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "strict-origin-when-cross-origin";

    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=general:10m rate=1r/s;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Frontend (Next.js)
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        # Rate limiting
        limit_req zone=general burst=5 nodelay;
    }

    # Backend API
    location /api {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Increase timeout for AI processing
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;

        # Rate limiting for API
        limit_req zone=api burst=20 nodelay;
    }

    # Health check endpoint (no rate limiting)
    location /health {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        access_log off;
    }

    # Metrics endpoint (restricted)
    location /metrics {
        proxy_pass http://127.0.0.1:8000;
        allow 127.0.0.1;
        allow 10.0.0.0/8;
        allow 172.16.0.0/12;
        allow 192.168.0.0/16;
        deny all;
        access_log off;
    }

    # Static assets caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
        proxy_pass http://127.0.0.1:3000;
        expires 1y;
        add_header Cache-Control "public, immutable";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

echo "🔗 Enabling Nginx site..."
ln -sf /etc/nginx/sites-available/hras /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t

systemctl reload nginx

echo "🌐 Obtaining Let's Encrypt certificate using Route53 DNS challenge..."

if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

certbot certonly \
    --dns-route53 \
    --dns-route53-propagation-seconds 60 \
    --email "$EMAIL" \
    --agree-tos \
    --non-interactive \
    --expand \
    -d "$DOMAIN" \
    -d "www.$DOMAIN"

echo "🔄 Setting up automatic certificate renewal..."
cat > /etc/systemd/system/certbot-renewal.service << 'EOF'
[Unit]
Description=Certbot Renewal
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --quiet --deploy-hook "systemctl reload nginx"

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/certbot-renewal.timer << 'EOF'
[Unit]
Description=Run certbot twice daily
Requires=certbot-renewal.service

[Timer]
OnCalendar=*-*-* 00,12:00:00
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable certbot-renewal.timer
systemctl start certbot-renewal.timer

echo "📋 Creating SSL monitoring script..."
cat > /opt/hras/check-ssl.sh << 'EOF'
#!/bin/bash

DOMAIN=$1
WARN_DAYS=${2:-30}
CRITICAL_DAYS=${3:-7}

if [[ -z "$DOMAIN" ]]; then
    echo "Usage: $0 <domain> [warn_days] [critical_days]"
    exit 1
fi

EXPIRY_DATE=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN":443 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -d= -f2)

if [[ -z "$EXPIRY_DATE" ]]; then
    echo "CRITICAL: Unable to retrieve SSL certificate for $DOMAIN"
    exit 2
fi

EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
CURRENT_EPOCH=$(date +%s)
DAYS_LEFT=$(( (EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))

if [[ $DAYS_LEFT -le $CRITICAL_DAYS ]]; then
    echo "CRITICAL: SSL certificate expires in $DAYS_LEFT days ($EXPIRY_DATE)"
    exit 2
elif [[ $DAYS_LEFT -le $WARN_DAYS ]]; then
    echo "WARNING: SSL certificate expires in $DAYS_LEFT days ($EXPIRY_DATE)"
    exit 1
else
    echo "OK: SSL certificate expires in $DAYS_LEFT days ($EXPIRY_DATE)"
    exit 0
fi
EOF

chmod +x /opt/hras/check-ssl.sh

echo "🔍 Testing SSL configuration..."
nginx -t

if systemctl is-active --quiet nginx; then
    systemctl reload nginx
else
    systemctl start nginx
fi

sleep 5

echo "✅ SSL setup complete!"
echo ""
echo "🔒 Certificate information:"
certbot certificates

echo ""
echo "📊 SSL test results:"
curl -I "https://$DOMAIN/health" | head -5

echo ""
echo "⏰ Renewal timer status:"
systemctl status certbot-renewal.timer --no-pager -l

echo ""
echo "🔍 To monitor SSL certificate expiry:"
echo "  /opt/hras/check-ssl.sh $DOMAIN"
