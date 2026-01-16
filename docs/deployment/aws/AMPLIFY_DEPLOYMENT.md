# AWS Amplify Frontend Deployment Guide

Complete guide for deploying HRAS Next.js frontend to AWS Amplify with custom domain and www redirects.

## Prerequisites

- AWS Account with Amplify access
- GitHub repository with HRAS code
- Domain name: `hras.owezzy.tech` (configured in CloudFlare/Route53)
- EC2 backend deployed (see EC2_DEPLOYMENT.md)

## Step 1: Prepare Frontend for Amplify

### 1.1 Update Environment Configuration

Create `frontend/.env.production`:
```env
# Point to your EC2 backend
NEXT_PUBLIC_API_URL=http://your-ec2-elastic-ip:8000

# Or if using API subdomain:
# NEXT_PUBLIC_API_URL=https://api.hras.owezzy.tech
```

### 1.2 Configure Next.js for Amplify

Update `frontend/next.config.js`:
```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  // Enable static export for better Amplify compatibility
  output: 'standalone',

  // Handle www subdomain redirects
  async redirects() {
    return [
      {
        source: '/:path*',
        has: [
          {
            type: 'host',
            value: 'www.hras.owezzy.tech',
          },
        ],
        destination: 'https://hras.owezzy.tech/:path*',
        permanent: true,
      },
    ]
  },

  // Your existing configuration...
  experimental: {
    optimizePackageImports: ['@mui/material', '@mui/icons-material'],
  },

  // CORS and API configuration
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: `${process.env.NEXT_PUBLIC_API_URL}/:path*`,
      },
    ]
  },
}

module.exports = nextConfig
```

### 1.3 Create Amplify Build Configuration

Create `frontend/amplify.yml`:
```yaml
version: 1
applications:
  - frontend:
      phases:
        preBuild:
          commands:
            - npm ci --cache .npm --prefer-offline --no-audit
        build:
          commands:
            - npm run build
      artifacts:
        baseDirectory: .next
        files:
          - '**/*'
      cache:
        paths:
          - .next/cache/**/*
          - .npm/**/*
    appRoot: frontend
env:
  variables:
    AMPLIFY_MONOREPO_APP_ROOT: frontend
    AMPLIFY_DIFF_DEPLOY: false
    AMPLIFY_DIFF_DEPLOY_ROOT: frontend
```

### 1.4 Update CORS Configuration

Update backend CORS settings in `backend/src/app/core/config.py`:
```python
class Settings(BaseSettings):
    # ... existing settings ...

    cors_origins: list[str] = [
        "https://hras.owezzy.tech",
        "https://www.hras.owezzy.tech",
        "http://localhost:3000",  # Local development
        # Add your Amplify preview domains
        "https://main.d1234567890.amplifyapp.com",  # Will be updated after creation
    ]
```

## Step 2: Create Amplify Application

### 2.1 Via AWS Console (Recommended)

1. **Navigate to AWS Amplify Console**
   - Go to AWS Console → Amplify

2. **Create New App**
   - Click "Create app" → "Host web app"
   - Choose "GitHub" as source

3. **Connect Repository**
   - Authorize GitHub access
   - Select your HRAS repository
   - Choose branch: `main` (or your production branch)

4. **Configure App Settings**
   - **App name**: `hras-frontend`
   - **Environment name**: `production`
   - **Build and test settings**: Use our `amplify.yml`

5. **Configure Advanced Settings**
   ```
   Base directory: frontend
   Build command: npm run build
   Output directory: .next
   Node.js version: 18
   ```

6. **Deploy**
   - Click "Save and deploy"
   - Wait for build to complete (~3-5 minutes)

### 2.2 Via AWS CLI (Alternative)

```bash
# Install Amplify CLI
npm install -g @aws-amplify/cli

# Initialize Amplify project
cd frontend
amplify init

# Add hosting
amplify add hosting

# Deploy
amplify publish
```

## Step 3: Configure Custom Domain

### 3.1 Add Custom Domain in Amplify

1. **Domain Management**
   - Amplify Console → Your app → Domain management
   - Click "Add domain"

2. **Domain Configuration**
   - **Domain**: `hras.owezzy.tech`
   - **Configure subdomains**:
     - `hras.owezzy.tech` → `main` branch
     - `www.hras.owezzy.tech` → **Redirect to** `hras.owezzy.tech`

3. **SSL Certificate**
   - Amplify automatically provisions SSL certificate
   - Takes 10-20 minutes to complete

### 3.2 Update DNS Records

**If using CloudFlare:**
```
Type: CNAME
Name: hras.owezzy.tech
Content: main.d1234567890.amplifyapp.com  # From Amplify console

Type: CNAME
Name: www.hras.owezzy.tech
Content: main.d1234567890.amplifyapp.com
```

**If using Route 53:**
```bash
# Get your Amplify domain from console first
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "hras.owezzy.tech",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "main.d1234567890.amplifyapp.com"}]
      }
    }]
  }'
```

## Step 4: Configure Environment Variables

### 4.1 Add Environment Variables in Amplify

1. **Environment Variables**
   - Amplify Console → Your app → Environment variables
   - Add the following:

```
NEXT_PUBLIC_API_URL = http://your-ec2-elastic-ip:8000
NODE_ENV = production
AMPLIFY_MONOREPO_APP_ROOT = frontend
```

### 4.2 Update Backend CORS

After getting your final Amplify URL, update backend CORS:

```bash
# SSH to your EC2 instance
ssh -i ~/.ssh/your-key.pem ec2-user@your-elastic-ip

# Edit backend environment
cd HRAS
nano backend/.env
```

Add your Amplify URL:
```env
CORS_ORIGINS=["https://hras.owezzy.tech", "https://www.hras.owezzy.tech", "https://main.d1234567890.amplifyapp.com"]
```

Restart backend:
```bash
docker compose -f zarf/docker/compose/docker-compose.yml restart backend
```

## Step 5: Configure Redirects and Rewrites

### 5.1 Amplify Redirect Rules

1. **Rewrites and Redirects**
   - Amplify Console → Your app → Rewrites and redirects
   - Add the following rules:

```
# www to non-www redirect
Source: https://www.hras.owezzy.tech/<*>
Target: https://hras.owezzy.tech/<*>
Type: 301 (Permanent Redirect)

# API proxy (if needed)
Source: /api/<*>
Target: http://your-ec2-elastic-ip:8000/<*>
Type: 200 (Rewrite)

# SPA fallback
Source: /<*>
Target: /index.html
Type: 200 (Rewrite)
Condition: 404-NOT_FOUND
```

### 5.2 Test Redirects

```bash
# Test www redirect
curl -I https://www.hras.owezzy.tech
# Should return: 301 redirect to https://hras.owezzy.tech

# Test main domain
curl -I https://hras.owezzy.tech
# Should return: 200 OK
```

## Step 6: Enable Branch Deployments (Optional)

### 6.1 Configure Branch-based Deployments

1. **Branch Management**
   - Amplify Console → Your app → App settings → Branch deployments
   - Connect additional branches:

```
main branch      → https://hras.owezzy.tech (production)
develop branch   → https://develop.d1234567890.amplifyapp.com
feature branches → https://pr-123.d1234567890.amplifyapp.com
```

### 6.2 Environment-specific Variables

Set different API URLs per branch:
```
Production (main):    NEXT_PUBLIC_API_URL = https://api.hras.owezzy.tech
Development (develop): NEXT_PUBLIC_API_URL = http://dev-ec2-ip:8000
```

## Step 7: Performance Optimization

### 7.1 Enable Amplify Performance Features

1. **Performance Settings**
   - Amplify Console → Your app → App settings → Performance
   - Enable:
     - **Server-side rendering (SSR)**: For Next.js SSR support
     - **Image optimization**: Automatic WebP conversion
     - **Compression**: Gzip/Brotli compression

### 7.2 Configure Caching Headers

In your `frontend/next.config.js`:
```javascript
const nextConfig = {
  // ... existing config ...

  async headers() {
    return [
      {
        source: '/_next/static/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable',
          },
        ],
      },
      {
        source: '/api/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=300', // 5 minutes
          },
        ],
      },
    ]
  },
}
```

## Step 8: Monitoring and Logs

### 8.1 Enable Amplify Monitoring

1. **Access Logs**
   - Amplify Console → Your app → Monitoring
   - View build logs, access logs, and performance metrics

2. **CloudWatch Integration**
   - Amplify automatically sends metrics to CloudWatch
   - Set up alarms for build failures, high error rates

### 8.2 Test Full Application

```bash
# Test frontend
curl https://hras.owezzy.tech

# Test API connectivity from frontend
# Open browser developer tools and check:
# Network tab → API calls to your EC2 backend
# Console → No CORS errors
```

## Step 9: Deployment Pipeline

### 9.1 Automatic Deployments

Amplify automatically deploys when you push to connected branches:

```bash
# Make changes to frontend
cd frontend
# ... make changes ...

# Commit and push
git add .
git commit -m "Update frontend configuration"
git push origin main

# Amplify automatically:
# 1. Detects push
# 2. Runs build
# 3. Deploys to production
# 4. Updates https://hras.owezzy.tech
```

### 9.2 Build Notifications

Set up notifications in Amplify Console:
1. **App settings** → **Notifications**
2. **Add SNS topic** for build status
3. **Slack/Email integration** for deployment notifications

## Troubleshooting

### Common Issues

1. **Build Fails - "Module not found"**
   ```bash
   # Check amplify.yml build commands
   # Ensure correct working directory: frontend/
   ```

2. **CORS Errors**
   ```bash
   # Update backend CORS_ORIGINS with your Amplify URL
   # Restart backend containers
   ```

3. **API Calls Fail**
   ```bash
   # Check NEXT_PUBLIC_API_URL is correct
   # Verify EC2 security group allows traffic
   ```

4. **Custom Domain Not Working**
   ```bash
   # Verify DNS CNAME records
   # Wait 24-48 hours for DNS propagation
   # Check SSL certificate status in Amplify
   ```

## Cost Estimation

**AWS Amplify Costs:**
- **Build minutes**: 1000 minutes/month free tier
- **Data transfer**: 15 GB/month free tier
- **Hosting**: 5 GB storage free tier
- **Typical cost**: $0-5/month for moderate traffic

**Total Frontend Cost**: ~$0-5/month (generous free tier)

## Next Steps

1. **[Configure API Subdomain](./DOMAIN_SSL.md)** - Set up api.hras.owezzy.tech
2. **[Set up Monitoring](./MONITORING_SETUP.md)** - Frontend performance monitoring
3. **[Enable CI/CD](./CICD.md)** - Advanced deployment pipeline
4. **[Security Hardening](./SECURITY.md)** - Frontend security checklist

Your HRAS frontend is now deployed with:
- ✅ Custom domain: https://hras.owezzy.tech
- ✅ www redirect: www.hras.owezzy.tech → hras.owezzy.tech
- ✅ Automatic SSL certificate
- ✅ Global CDN distribution
- ✅ Automatic deployments from GitHub
