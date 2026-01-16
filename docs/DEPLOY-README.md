# HRAS Deployment System

A comprehensive CI/CD deployment automation system for HRAS backend deployment to AWS EC2 with zero-downtime, automated backups, monitoring, and rollback capabilities.

## 🚀 Quick Start

1. **Configure deployment settings:**
   ```bash
   cp deploy/config/deployment.env.example deploy/config/deployment.env
   # Edit deployment.env with your AWS and application settings
   ```

2. **Set up AWS infrastructure (optional):**
   ```bash
   make deploy-aws-setup  # Creates EC2 instance, security groups, etc.
   ```

3. **Set up the server:**
   ```bash
   make deploy-setup  # Install Docker, configure firewall, etc.
   ```

4. **Configure SSL certificates:**
   ```bash
   make deploy-ssl  # Set up Let's Encrypt with Route53 DNS challenge
   ```

5. **Deploy the application:**
   ```bash
   make deploy-production  # Deploy with automatic backup
   ```

6. **Set up monitoring:**
   ```bash
   make deploy-monitoring  # Prometheus, Grafana, alerting
   ```

## 📁 Directory Structure

```
deploy/
├── config/
│   └── deployment.env          # Deployment configuration
├── scripts/
│   ├── setup-aws.sh           # AWS infrastructure setup
│   ├── setup-server.sh        # Server preparation and security
│   ├── setup-ssl.sh           # SSL certificate automation
│   ├── deploy.sh              # Application deployment
│   ├── rollback.sh            # Deployment rollback
│   ├── backup.sh              # Automated backups
│   ├── health-check.sh        # Comprehensive health monitoring
│   └── setup-monitoring.sh    # Monitoring stack setup
└── docker-compose.prod.yml    # Production Docker Compose
```

## 🔧 Configuration

### Environment Variables

Key settings in `deploy/config/deployment.env`:

```bash
# AWS Configuration
AWS_REGION=us-east-1
EC2_INSTANCE_ID=i-0123456789abcdef0
EC2_HOST=your-domain.com

# Domain and SSL
DOMAIN=hras.example.com
EMAIL=admin@example.com
SSL_PROVIDER=letsencrypt  # or cloudflare
SSL_CHALLENGE=dns         # or http

# Application
APP_VERSION=latest
DEPLOYMENT_STRATEGY=rolling  # or blue-green
BACKUP_BEFORE_DEPLOY=true
ROLLBACK_ON_FAILURE=true

# Monitoring
ENABLE_MONITORING=true
GRAFANA_ADMIN_PASSWORD=secure_password
```

## 🛠 Make Commands

### Core Deployment
- `make deploy-setup` - Set up EC2 instance for production
- `make deploy-ssl` - Configure SSL certificates
- `make deploy-production` - Deploy application with backup
- `make deploy-rollback` - Rollback to previous version
- `make deploy-backup` - Create manual backup

### Monitoring & Health
- `make deploy-health-check` - Run comprehensive health check
- `make deploy-monitoring` - Set up monitoring stack
- `make deploy-status` - Show deployment status
- `make deploy-logs` - View application logs

### Remote Operations
- `make deploy-remote-setup` - Run setup on remote server
- `make deploy-remote-deploy` - Deploy from local to remote
- `make deploy-ssh` - SSH into production server

## 🏗 Features

### ✅ Deployment Automation
- **Zero-downtime deployments** with rolling updates
- **Blue-green deployment** strategy support
- **Automatic rollback** on deployment failure
- **Health check validation** before traffic switching
- **Git-based deployments** with version tracking

### 🔒 Security & SSL
- **Automated SSL certificates** with Let's Encrypt
- **DNS challenge support** for Route53/Cloudflare
- **Auto-renewal** with systemd timers
- **Security hardening** with UFW and fail2ban
- **Rate limiting** and DDoS protection via Nginx

### 💾 Backup & Recovery
- **Automated backups** before each deployment
- **Multi-component backups**: application, database, vector store
- **S3 integration** with lifecycle policies
- **Point-in-time recovery** with versioned backups
- **Backup verification** and integrity checks

### 📊 Monitoring & Alerting
- **Prometheus** metrics collection
- **Grafana** dashboards for visualization
- **System metrics**: CPU, memory, disk, network
- **Application metrics**: request rates, response times, errors
- **SSL certificate monitoring** with expiration alerts
- **Webhook notifications** for critical events

### 🔧 Maintenance & Operations
- **Health check system** with comprehensive validation
- **Log rotation** and management
- **Resource cleanup** and optimization
- **Service management** with systemd
- **Remote operations** support

## 🎯 Deployment Strategies

### Rolling Deployment (Default)
- Updates services one by one
- Maintains service availability
- Lower resource requirements
- Gradual rollout with validation

### Blue-Green Deployment
- Parallel environment deployment
- Instant traffic switching
- Full rollback capability
- Higher resource requirements

## 📈 Monitoring Dashboard

The deployment includes pre-configured Grafana dashboards:

- **HRAS Overview**: Application health, request rates, response times
- **System Metrics**: CPU, memory, disk usage, network stats
- **Infrastructure**: Docker containers, database connections
- **SSL Monitoring**: Certificate validity and expiration tracking

Access: `https://your-domain.com:3001` (admin/password from config)

## 🚨 Alerting Rules

Configured Prometheus alerts:
- Application downtime
- High error rates (>10% 5xx responses)
- High response times (>2s 95th percentile)
- System resource exhaustion
- SSL certificate expiration
- Database connectivity issues

## 🔄 Backup Strategy

### Automated Backups
- **Before each deployment** (configurable)
- **Daily scheduled backups** via cron
- **Retention policy**: 30 days local, lifecycle in S3

### Backup Components
- Application code and configuration
- PostgreSQL database (if enabled)
- ChromaDB vector store
- SSL certificates and Nginx config
- System configuration files

### Recovery Process
```bash
# List available backups
make deploy-rollback --list

# Rollback to specific backup
make deploy-rollback 20241215_143022

# Rollback to latest
make deploy-rollback
```

## 🏥 Health Checks

Comprehensive health monitoring includes:

- **Application endpoints** - API and health check responses
- **SSL certificate validity** - Expiration monitoring
- **Docker services** - Container health and status
- **System resources** - CPU, memory, disk usage
- **Database connectivity** - PostgreSQL connection tests
- **Vector store** - ChromaDB document counts
- **Log file sizes** - Growth monitoring
- **Security status** - Firewall and fail2ban

Health check scoring:
- **100%**: All systems healthy
- **70-99%**: Warning state, some issues
- **<70%**: Critical state, immediate attention required

## 🛡 Security Features

### Network Security
- UFW firewall with minimal open ports
- Fail2ban protection against brute force
- Rate limiting in Nginx
- Security headers (HSTS, CSP, XSS protection)

### SSL/TLS
- Modern TLS configuration (TLS 1.2+)
- Perfect Forward Secrecy
- OCSP stapling
- Automatic certificate renewal

### Application Security
- Non-root container execution
- Secrets management via environment variables
- CORS configuration
- Input validation and sanitization

## 📋 Prerequisites

### Local Development Machine
- Make
- SSH client
- AWS CLI (for AWS setup)
- Docker and Docker Compose

### AWS Requirements
- EC2 instance (t3.large recommended)
- Security groups configured
- Route53 hosted zone (for DNS challenge SSL)
- S3 bucket (for backups)
- IAM permissions for EC2, S3, Route53

### Server Requirements
- Ubuntu 22.04 LTS
- 4GB+ RAM
- 20GB+ storage
- Public IP address

## 🚀 Production Checklist

Before going live:

- [ ] Configure all settings in `deployment.env`
- [ ] Set up AWS infrastructure or provision server
- [ ] Configure DNS records
- [ ] Run server setup and SSL configuration
- [ ] Deploy and verify application
- [ ] Set up monitoring and alerting
- [ ] Test backup and rollback procedures
- [ ] Configure log rotation and cleanup
- [ ] Set up automated health checks
- [ ] Document emergency procedures

## 🔧 Troubleshooting

### Common Issues

**Deployment fails with SSL errors:**
```bash
# Check certificate status
openssl x509 -in /opt/hras/ssl/fullchain.pem -text -noout

# Regenerate certificates
make deploy-ssl
```

**Health checks failing:**
```bash
# Run detailed health check
make deploy-health-check

# Check service status
systemctl status hras nginx docker
```

**High resource usage:**
```bash
# Check system resources
make deploy-status

# Review logs for issues
make deploy-logs
```

### Log Locations

- Application: `/opt/hras/logs/app/`
- Nginx: `/opt/hras/logs/nginx/`
- Deployment: `/opt/hras/logs/app/deployment.log`
- Health checks: `/opt/hras/logs/app/health-*.json`

### Emergency Procedures

**Immediate rollback:**
```bash
make deploy-rollback
```

**Service restart:**
```bash
sudo systemctl restart hras nginx
```

**Emergency access:**
```bash
make deploy-ssh
```

## 📞 Support

For deployment issues:
1. Check health check output: `make deploy-health-check`
2. Review logs: `make deploy-logs`
3. Verify configuration: `make deploy-status`
4. Test connectivity: SSH and basic curl tests

The deployment system is designed for production reliability with comprehensive error handling, monitoring, and recovery capabilities.
