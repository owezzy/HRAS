# HRAS Security Deployment Checklist

## Pre-Deployment Security Checklist

### 1. AWS Infrastructure Security

#### Security Groups
- [ ] SSH access restricted to VPN/bastion CIDR only (not 0.0.0.0/0)
- [ ] HTTP (80) open for Let's Encrypt and redirect to HTTPS
- [ ] HTTPS (443) open for public access
- [ ] Application port (8000) only accessible from nginx security group
- [ ] All unused ports are blocked

#### IAM Configuration
- [ ] EC2 instance uses IAM role (not static credentials)
- [ ] IAM role has minimal permissions (Route53, CloudWatch, Secrets Manager only)
- [ ] No wildcard (*) permissions in IAM policies
- [ ] AWS access keys rotated if using static credentials

#### VPC Configuration
- [ ] Application in private subnet (if using load balancer)
- [ ] VPC Flow Logs enabled
- [ ] Network ACLs configured as additional layer

### 2. EC2 Instance Hardening

#### SSH Security
- [ ] Root login disabled (`PermitRootLogin no`)
- [ ] Password authentication disabled (`PasswordAuthentication no`)
- [ ] Only SSH key authentication allowed
- [ ] Modern SSH ciphers configured
- [ ] SSH connection limits configured

#### Firewall (UFW)
- [ ] Default deny incoming
- [ ] Only required ports allowed (22, 80, 443)
- [ ] Rate limiting on SSH
- [ ] Logging enabled

#### fail2ban
- [ ] fail2ban installed and enabled
- [ ] SSH jail configured
- [ ] Nginx jails configured
- [ ] Recidive jail for repeat offenders

#### System Updates
- [ ] Automatic security updates enabled
- [ ] Kernel security parameters hardened (sysctl)
- [ ] Audit logging enabled (auditd)

### 3. SSL/TLS Configuration

#### Certificate
- [ ] Valid SSL certificate installed
- [ ] Certificate auto-renewal configured (certbot timer)
- [ ] Certificate expiry monitoring enabled
- [ ] DH parameters generated (4096-bit recommended)

#### TLS Settings
- [ ] TLS 1.2 and 1.3 only (no TLS 1.0/1.1)
- [ ] Strong cipher suites configured
- [ ] OCSP stapling enabled
- [ ] Session tickets disabled

### 4. Nginx Security

#### Headers
- [ ] Strict-Transport-Security (HSTS) with preload
- [ ] X-Frame-Options: DENY
- [ ] X-Content-Type-Options: nosniff
- [ ] Referrer-Policy: strict-origin-when-cross-origin
- [ ] Content-Security-Policy configured
- [ ] Permissions-Policy configured

#### Rate Limiting
- [ ] API rate limiting enabled (10 req/s recommended)
- [ ] Chat endpoint rate limiting (5 req/s for AI operations)
- [ ] Admin endpoints strictly rate limited
- [ ] Connection limits per IP

#### Access Control
- [ ] /metrics endpoint blocked externally
- [ ] /docs, /redoc blocked in production (or IP-restricted)
- [ ] Admin endpoints IP-restricted
- [ ] Invalid Host headers rejected

### 5. Container Security

#### Docker Configuration
- [ ] Non-root user in container
- [ ] `no-new-privileges` security option
- [ ] Read-only root filesystem where possible
- [ ] tmpfs for /tmp with noexec,nosuid
- [ ] Resource limits configured (memory, CPU)

#### Image Security
- [ ] Minimal base image (slim/alpine)
- [ ] No secrets in Docker image
- [ ] Image vulnerability scanning performed
- [ ] Multi-stage build to minimize attack surface

#### Network Isolation
- [ ] Separate Docker networks for tiers
- [ ] Database only accessible from backend network
- [ ] No unnecessary port exposures

### 6. Application Security

#### CORS
- [ ] Specific origins configured (no wildcards)
- [ ] Credentials handling properly configured
- [ ] Methods restricted to required HTTP methods
- [ ] Headers restricted to required headers

#### Input Validation
- [ ] Pydantic models validate all inputs
- [ ] SQL injection prevention (parameterized queries)
- [ ] Request size limits configured

#### API Security
- [ ] API documentation disabled in production
- [ ] Metrics endpoint not publicly accessible
- [ ] Security headers middleware enabled
- [ ] Trusted host validation enabled

### 7. Secrets Management

#### Environment Variables
- [ ] No secrets in source control
- [ ] .env files in .gitignore
- [ ] Production secrets in AWS Secrets Manager or SSM
- [ ] Database passwords are strong (32+ chars)

#### Credential Rotation
- [ ] AWS access keys rotated regularly
- [ ] Database passwords rotatable
- [ ] API keys have expiration

### 8. Logging & Monitoring

#### Security Logging
- [ ] Authentication attempts logged
- [ ] Failed requests logged with IP
- [ ] Admin operations logged
- [ ] Structured JSON logging enabled

#### Monitoring Alerts
- [ ] High rate limit hits alert
- [ ] Unauthorized access attempts alert
- [ ] Server error spike alert
- [ ] SSL certificate expiry alert
- [ ] High resource usage alerts

#### Log Management
- [ ] Log rotation configured
- [ ] Logs shipped to CloudWatch or similar
- [ ] Log retention policy defined

### 9. Database Security

#### SQLite (if used)
- [ ] Database file in protected directory
- [ ] File permissions restricted (640)
- [ ] Regular backups configured

#### PostgreSQL (if used)
- [ ] Strong password authentication
- [ ] SSL/TLS for connections
- [ ] Minimal user privileges
- [ ] Connection from app tier only

### 10. Backup & Recovery

- [ ] Database backup strategy defined
- [ ] Vector store backup strategy defined
- [ ] Configuration backup before changes
- [ ] Rollback procedure documented and tested


## Post-Deployment Verification

### Security Tests
```bash
# Test SSL configuration
curl -vI https://your-domain.com 2>&1 | grep -E "SSL|TLS|certificate"

# Test security headers
curl -I https://your-domain.com/api/v1/health

# Test rate limiting
for i in {1..20}; do curl -s -o /dev/null -w "%{http_code}\n" https://your-domain.com/api/v1/health; done

# Test blocked endpoints
curl -I https://your-domain.com/metrics  # Should return 404/403
curl -I https://your-domain.com/docs     # Should return 404/403 in production

# Test CORS
curl -I -H "Origin: https://evil.com" https://your-domain.com/api/v1/health
```

### SSL Labs Test
- [ ] Run SSL Labs test: https://www.ssllabs.com/ssltest/
- [ ] Achieve A+ rating

### Security Headers Test
- [ ] Run security headers test: https://securityheaders.com/
- [ ] Achieve A+ rating


## Emergency Contacts

| Role | Contact |
|------|---------|
| Security Lead | security@yourdomain.com |
| DevOps Lead | devops@yourdomain.com |
| AWS Account Admin | aws-admin@yourdomain.com |


## Incident Response

1. **Detect**: Monitor alerts and logs for suspicious activity
2. **Contain**: Block attacking IPs, disable compromised credentials
3. **Investigate**: Review logs, identify scope of breach
4. **Remediate**: Patch vulnerabilities, rotate credentials
5. **Report**: Document incident and notify stakeholders
6. **Recover**: Restore services, verify integrity


## Regular Security Tasks

| Task | Frequency |
|------|-----------|
| Review security logs | Daily |
| Check fail2ban bans | Daily |
| Verify backup integrity | Weekly |
| Review IAM permissions | Monthly |
| Rotate access keys | Quarterly |
| Security audit | Annually |
| Penetration testing | Annually |
