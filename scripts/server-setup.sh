#!/bin/bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "🚀 Starting HRAS server setup and hardening..."

echo "📦 Updating system packages..."
apt-get update && apt-get upgrade -y

echo "🔐 Installing essential security packages..."
apt-get install -y \
    curl \
    wget \
    git \
    htop \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    ufw \
    fail2ban \
    unattended-upgrades \
    logrotate \
    rsync \
    jq

echo "🐳 Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

echo "📝 Installing Docker Compose..."
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "🌐 Installing Nginx..."
apt-get install -y nginx
systemctl enable nginx

echo "🔒 Installing Certbot..."
apt-get install -y certbot python3-certbot-nginx python3-certbot-dns-route53

echo "🛡️ Configuring UFW firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw allow 80/tcp
ufw allow 443/tcp
echo "y" | ufw enable

echo "🚫 Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
port = http,https
logpath = /var/log/nginx/access.log
EOF

systemctl enable fail2ban
systemctl start fail2ban

echo "🔄 Configuring automatic security updates..."
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

echo "📊 Installing monitoring tools..."
apt-get install -y prometheus-node-exporter

cat > /etc/systemd/system/node-exporter.service << 'EOF'
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/prometheus-node-exporter --web.listen-address=:9100
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl enable node-exporter
systemctl start node-exporter

echo "🗂️ Creating application directories..."
mkdir -p /opt/hras/{data,backups,logs,ssl}
mkdir -p /var/log/hras

chown -R ubuntu:ubuntu /opt/hras
chown -R ubuntu:ubuntu /var/log/hras

echo "🔧 Configuring log rotation..."
cat > /etc/logrotate.d/hras << 'EOF'
/var/log/hras/*.log {
    daily
    rotate 30
    compress
    delaycompress
    copytruncate
    notifempty
    missingok
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
    endscript
}
EOF

echo "⚡ Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

echo "📝 Creating system service files..."
cat > /etc/systemd/system/hras.service << 'EOF'
[Unit]
Description=HRAS Application
Requires=docker.service
After=docker.service

[Service]
Type=forking
RemainAfterExit=yes
WorkingDirectory=/opt/hras
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
ExecReload=/usr/local/bin/docker-compose restart
TimeoutStartSec=0
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo "🔑 Setting up SSH hardening..."
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config

systemctl reload sshd

echo "🧹 Cleaning up..."
apt-get autoremove -y
apt-get autoclean

echo "✅ Server setup complete!"
echo ""
echo "Next steps:"
echo "1. Run SSL certificate provisioning: sudo ./ssl-setup.sh"
echo "2. Deploy the application: sudo ./deploy.sh"
echo "3. Set up monitoring: sudo ./monitoring-setup.sh"
echo ""
echo "📋 Security checklist:"
echo "  ✅ UFW firewall configured"
echo "  ✅ fail2ban installed and configured"
echo "  ✅ SSH hardened"
echo "  ✅ Automatic security updates enabled"
echo "  ✅ Non-root user configured"
echo "  ✅ Docker installed with proper permissions"
echo ""
echo "🔍 Verify setup:"
echo "  • Check firewall: sudo ufw status"
echo "  • Check fail2ban: sudo fail2ban-client status"
echo "  • Check services: systemctl status docker nginx"
