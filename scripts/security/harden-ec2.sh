#!/bin/bash
# =============================================================================
# HRAS EC2 Instance Security Hardening Script
# Run this script on a fresh EC2 instance before deploying HRAS
#
# Usage: sudo ./harden-ec2.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

HRAS_USER=${HRAS_USER:-hras}
SSH_PORT=${SSH_PORT:-22}

log_info "Starting EC2 security hardening..."

log_info "Updating system packages..."
apt-get update && apt-get upgrade -y
apt-get install -y \
    ufw \
    fail2ban \
    unattended-upgrades \
    apt-listchanges \
    auditd \
    audispd-plugins \
    logwatch \
    rkhunter \
    chkrootkit \
    aide \
    libpam-pwquality

if ! id "$HRAS_USER" &>/dev/null; then
    log_info "Creating HRAS service user..."
    useradd -r -m -s /bin/bash -c "HRAS Service Account" "$HRAS_USER"
    usermod -aG docker "$HRAS_USER" 2>/dev/null || true
fi

log_info "Configuring SSH hardening..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

cat > /etc/ssh/sshd_config.d/99-hras-hardening.conf << 'EOF'
Protocol 2
Port 22

PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

MaxAuthTries 3
MaxSessions 3
MaxStartups 10:30:60
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2

X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
PermitTunnel no
GatewayPorts no

Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512

SyslogFacility AUTH
LogLevel VERBOSE
EOF

sshd -t && systemctl restart sshd

log_info "Configuring UFW firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

ufw limit ssh comment "SSH with rate limiting"
ufw allow 80/tcp comment "HTTP"
ufw allow 443/tcp comment "HTTPS"

ufw deny 23/tcp comment "Block Telnet"
ufw deny 3389/tcp comment "Block RDP"

ufw logging medium
ufw --force enable

log_info "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = auto

destemail = root@localhost
sender = fail2ban@localhost
action = %(action_mwl)s

ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 5
bantime = 300

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
bantime = 86400

[recidive]
enabled = true
filter = recidive
logpath = /var/log/fail2ban.log
bantime = 604800
findtime = 86400
maxretry = 3
EOF

systemctl enable fail2ban
systemctl restart fail2ban

log_info "Configuring automatic security updates..."
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::Package-Blacklist {
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::SyslogEnable "true";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

log_info "Configuring kernel security parameters..."
cat > /etc/sysctl.d/99-hras-security.conf << 'EOF'
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
kernel.dmesg_restrict = 1

fs.suid_dumpable = 0
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
EOF

sysctl --system

log_info "Configuring audit daemon..."
cat > /etc/audit/rules.d/hras-audit.rules << 'EOF'
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /var/log/auth.log -p wa -k auth_log

-a always,exit -F arch=b64 -S execve -k exec
-a always,exit -F arch=b64 -S connect -k network

-a always,exit -F arch=b64 -S open -S openat -S creat -F exit=-EACCES -k access_denied
-a always,exit -F arch=b64 -S open -S openat -S creat -F exit=-EPERM -k access_denied

-w /opt/hras/ -p wa -k hras_changes
EOF

systemctl enable auditd
systemctl restart auditd

log_info "Setting secure file permissions..."
chmod 700 /root
chmod 600 /etc/ssh/sshd_config
find /var/log -type f -exec chmod 640 {} \;

log_info "Disabling unused network protocols..."
cat > /etc/modprobe.d/hras-disable-protocols.conf << 'EOF'
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
EOF

log_info "Creating HRAS directories with secure permissions..."
mkdir -p /opt/hras/{data,logs,backups,ssl}
chown -R "$HRAS_USER:$HRAS_USER" /opt/hras
chmod 750 /opt/hras
chmod 700 /opt/hras/ssl
chmod 700 /opt/hras/backups

log_info "Creating security monitoring script..."
cat > /opt/hras/security-check.sh << 'SCRIPT'
#!/bin/bash
echo "=== HRAS Security Status Report ==="
echo "Generated: $(date)"
echo ""

echo "=== fail2ban Status ==="
fail2ban-client status 2>/dev/null || echo "fail2ban not running"
echo ""

echo "=== UFW Status ==="
ufw status verbose
echo ""

echo "=== Recent SSH Failures (last 10) ==="
grep "Failed password\|Invalid user" /var/log/auth.log 2>/dev/null | tail -10 || echo "No failures found"
echo ""

echo "=== Active Network Connections ==="
ss -tulpn | grep -E ':22|:80|:443|:8000' || echo "No relevant connections"
echo ""

echo "=== Docker Container Status ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Docker not available"
echo ""

echo "=== Disk Usage ==="
df -h / /opt/hras 2>/dev/null
echo ""

echo "=== Memory Usage ==="
free -h
echo ""
SCRIPT

chmod 700 /opt/hras/security-check.sh

log_info "Setting up logrotate for HRAS logs..."
cat > /etc/logrotate.d/hras << 'EOF'
/opt/hras/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 hras hras
    sharedscripts
    postrotate
        docker kill --signal=USR1 hras-nginx 2>/dev/null || true
    endscript
}
EOF

echo ""
log_info "=========================================="
log_info "EC2 Security Hardening Complete!"
log_info "=========================================="
echo ""
log_warn "IMPORTANT: Review the following:"
echo "  1. Verify SSH access still works before closing this session"
echo "  2. Add your SSH public key to /home/$HRAS_USER/.ssh/authorized_keys"
echo "  3. Review firewall rules: ufw status verbose"
echo "  4. Review fail2ban status: fail2ban-client status"
echo "  5. Run security check: /opt/hras/security-check.sh"
echo ""
log_info "Next steps:"
echo "  1. Deploy HRAS application: cd /opt/hras && docker compose up -d"
echo "  2. Configure SSL certificates using Route53 DNS challenge"
echo "  3. Set up CloudWatch agent for log shipping"
