# GitHub Secrets Configuration for HRAS Production Deployment

This document lists all required GitHub repository secrets for the automated EC2 deployment workflow.

## Required Secrets

### SSH Configuration
| Secret Name | Description | Example Value | Required |
|-------------|-------------|---------------|----------|
| `EC2_SSH_KEY` | Private SSH key for EC2 access | `-----BEGIN OPENSSH PRIVATE KEY-----\n...` | ✅ |
| `EC2_HOST` | EC2 instance public IP address | `18.215.166.248` | ✅ |
| `EC2_USER` | EC2 username | `ubuntu` | ✅ |

### Database Configuration
| Secret Name | Description | Example Value | Required |
|-------------|-------------|---------------|----------|
| `DB_PASSWORD` | PostgreSQL database password | `secure_prod_password_2024` | ✅ |

### Domain & SSL Configuration
| Secret Name | Description | Example Value | Required |
|-------------|-------------|---------------|----------|
| `DOMAIN` | Production domain name | `api.hras.owezzy.tech` | ✅ |
| `LETSENCRYPT_EMAIL` | Email for Let's Encrypt SSL certificates | `admin@hras.owezzy.tech` | ✅ |

### Notifications (Optional)
| Secret Name | Description | Example Value | Required |
|-------------|-------------|---------------|----------|
| `SLACK_WEBHOOK_URL` | Slack webhook for deployment notifications | `https://hooks.slack.com/services/...` | ⚪ |

## Setup Instructions

### 1. SSH Key Configuration

Generate an SSH key pair for the deployment:

```bash
# Generate new SSH key pair
ssh-keygen -t ed25519 -f hras-deploy-key -C "hras-github-actions"

# Copy public key to EC2 instance
ssh-copy-id -i hras-deploy-key.pub ubuntu@18.215.166.248

# Test connection
ssh -i hras-deploy-key ubuntu@18.215.166.248 "echo 'SSH connection successful'"
```

Add the **private key** content to GitHub:
1. Go to your GitHub repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `EC2_SSH_KEY`
4. Value: Copy the entire content of `hras-deploy-key` (including headers)

### 2. Database Password

Generate a secure database password:

```bash
# Generate secure password
openssl rand -base64 32
```

Add to GitHub secrets as `DB_PASSWORD`.

### 3. Domain Configuration

Set up your domain secrets:
- `DOMAIN`: Your production API domain (e.g., `api.hras.owezzy.tech`)
- `LETSENCRYPT_EMAIL`: Valid email for SSL certificate notifications

### 4. EC2 Instance Information

Add your EC2 instance details:
- `EC2_HOST`: Your EC2 public IP address
- `EC2_USER`: Usually `ubuntu` for Ubuntu instances, `ec2-user` for Amazon Linux

### 5. Slack Notifications (Optional)

Create a Slack webhook:
1. Go to your Slack workspace → Apps → Incoming Webhooks
2. Create a new webhook for your deployment channel
3. Copy the webhook URL to `SLACK_WEBHOOK_URL` secret

## Security Best Practices

### SSH Key Security
- ✅ Use Ed25519 keys (more secure than RSA)
- ✅ Generate deployment-specific keys (don't reuse personal keys)
- ✅ Restrict key usage to deployment user only
- ✅ Rotate keys regularly (every 90 days)

### Password Security
- ✅ Use strong, randomly generated passwords
- ✅ Different passwords for each environment
- ✅ Store passwords only in GitHub secrets (never in code)

### Network Security
- ✅ Restrict EC2 security groups to necessary ports only
- ✅ Use HTTPS for all external communication
- ✅ Enable SSH key authentication only (disable password auth)

## Verification

Test your secrets configuration:

```bash
# Test SSH connection
ssh -o BatchMode=yes ubuntu@18.215.166.248 "echo 'SSH test successful'"

# Test Docker Compose on EC2
ssh ubuntu@18.215.166.248 "cd /opt/hras && docker compose --version"

# Test domain resolution
nslookup api.hras.owezzy.tech

# Test SSL certificate
curl -I https://api.hras.owezzy.tech/api/health
```

## Troubleshooting

### SSH Connection Issues
```bash
# Debug SSH connection
ssh -v ubuntu@18.215.166.248

# Check key permissions
ls -la ~/.ssh/
chmod 600 ~/.ssh/id_rsa  # Fix permissions if needed
```

### Domain Issues
```bash
# Check DNS resolution
dig api.hras.owezzy.tech

# Check SSL certificate
openssl s_client -connect api.hras.owezzy.tech:443 -servername api.hras.owezzy.tech
```

### Database Connection Issues
```bash
# Test database connection from EC2
ssh ubuntu@18.215.166.248 "
  cd /opt/hras
  docker exec hras-postgres pg_isready -U hras -d hras
"
```

## Secret Rotation Schedule

| Secret | Rotation Frequency | Next Due |
|--------|-------------------|----------|
| `EC2_SSH_KEY` | Every 90 days | Track manually |
| `DB_PASSWORD` | Every 180 days | Track manually |
| Let's Encrypt Certs | Auto-renewal (90 days) | Automatic |

## Emergency Procedures

### Revoke Compromised SSH Key
1. Remove public key from EC2: `ssh ubuntu@18.215.166.248 "sed -i '/hras-github-actions/d' ~/.ssh/authorized_keys"`
2. Generate new key pair following setup instructions
3. Update `EC2_SSH_KEY` secret in GitHub
4. Test deployment pipeline

### Database Password Reset
1. Generate new password: `openssl rand -base64 32`
2. Update `DB_PASSWORD` secret in GitHub
3. Update password on EC2: `ssh ubuntu@18.215.166.248 "cd /opt/hras && docker exec -it hras-postgres psql -U postgres -c \"ALTER USER hras PASSWORD 'new_password';\"`
4. Restart services: `docker compose restart`
