#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/deployment.env"

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" | tee -a aws-setup.log
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a aws-setup.log >&2
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" | tee -a aws-setup.log
}

check_aws_cli() {
    if ! command -v aws >/dev/null 2>&1; then
        log_error "AWS CLI is not installed"
        echo "Please install AWS CLI: https://aws.amazon.com/cli/"
        exit 1
    fi

    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS CLI is not configured"
        echo "Please run: aws configure"
        exit 1
    fi

    log_success "AWS CLI is configured"
}

create_security_group() {
    log_info "Creating security group for HRAS..."

    local sg_name="hras-production-sg"
    local sg_description="Security group for HRAS production deployment"

    local sg_id
    sg_id=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=${sg_name}" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null || echo "None")

    if [[ "$sg_id" != "None" ]]; then
        log_info "Security group already exists: $sg_id"
        echo "$sg_id"
        return 0
    fi

    sg_id=$(aws ec2 create-security-group \
        --group-name "$sg_name" \
        --description "$sg_description" \
        --query 'GroupId' \
        --output text)

    aws ec2 authorize-security-group-ingress \
        --group-id "$sg_id" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --query 'Return' \
        --output text >/dev/null

    aws ec2 authorize-security-group-ingress \
        --group-id "$sg_id" \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --query 'Return' \
        --output text >/dev/null

    aws ec2 authorize-security-group-ingress \
        --group-id "$sg_id" \
        --protocol tcp \
        --port 443 \
        --cidr 0.0.0.0/0 \
        --query 'Return' \
        --output text >/dev/null

    aws ec2 create-tags \
        --resources "$sg_id" \
        --tags Key=Name,Value="HRAS Production" Key=Project,Value=HRAS

    log_success "Security group created: $sg_id"
    echo "$sg_id"
}

create_key_pair() {
    local key_name="hras-deploy-key"
    local key_path="${EC2_SSH_KEY_PATH:-~/.ssh/hras-deploy-key.pem}"

    log_info "Creating EC2 key pair..."

    if aws ec2 describe-key-pairs --key-names "$key_name" >/dev/null 2>&1; then
        log_info "Key pair already exists: $key_name"
        return 0
    fi

    aws ec2 create-key-pair \
        --key-name "$key_name" \
        --query 'KeyMaterial' \
        --output text > "$key_path"

    chmod 600 "$key_path"

    log_success "Key pair created: $key_name -> $key_path"
}

launch_ec2_instance() {
    log_info "Launching EC2 instance..."

    local ami_id
    ami_id=$(aws ec2 describe-images \
        --owners 099720109477 \
        --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
        --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
        --output text)

    local sg_id
    sg_id=$(create_security_group)

    local user_data
    read -r -d '' user_data << 'EOF' || true
#!/bin/bash
apt-get update -qq
apt-get install -y -qq curl wget git htop unzip
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
EOF

    local instance_id
    instance_id=$(aws ec2 run-instances \
        --image-id "$ami_id" \
        --count 1 \
        --instance-type t3.large \
        --key-name hras-deploy-key \
        --security-group-ids "$sg_id" \
        --user-data "$user_data" \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=HRAS Production},{Key=Project,Value=HRAS}]' \
        --query 'Instances[0].InstanceId' \
        --output text)

    log_info "Waiting for instance to be running..."
    aws ec2 wait instance-running --instance-ids "$instance_id"

    local public_ip
    public_ip=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)

    log_success "EC2 instance launched: $instance_id"
    log_success "Public IP: $public_ip"

    echo "
EC2 Instance Information:
Instance ID: $instance_id
Public IP: $public_ip
Security Group: $sg_id
Key Pair: hras-deploy-key

To connect:
ssh -i ~/.ssh/hras-deploy-key.pem ubuntu@$public_ip

Update your deployment.env file with:
EC2_INSTANCE_ID=$instance_id
EC2_HOST=$public_ip
"
}

setup_route53_domain() {
    if [[ -z "${ROUTE53_HOSTED_ZONE_ID:-}" ]]; then
        log_info "Route53 not configured, skipping DNS setup"
        return 0
    fi

    log_info "Setting up Route53 DNS records..."

    local public_ip
    public_ip=$(aws ec2 describe-instances \
        --instance-ids "${EC2_INSTANCE_ID}" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)

    local change_batch
    change_batch=$(cat << EOF
{
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "${DOMAIN}",
                "Type": "A",
                "TTL": 300,
                "ResourceRecords": [
                    {
                        "Value": "$public_ip"
                    }
                ]
            }
        }
    ]
}
EOF
)

    local change_id
    change_id=$(aws route53 change-resource-record-sets \
        --hosted-zone-id "${ROUTE53_HOSTED_ZONE_ID}" \
        --change-batch "$change_batch" \
        --query 'ChangeInfo.Id' \
        --output text)

    log_info "Waiting for DNS changes to propagate..."
    aws route53 wait resource-record-sets-changed --id "$change_id"

    log_success "DNS records updated for ${DOMAIN}"
}

create_s3_backup_bucket() {
    if [[ -z "${S3_BACKUP_BUCKET:-}" ]]; then
        log_info "S3 backup not configured, skipping bucket creation"
        return 0
    fi

    log_info "Creating S3 backup bucket..."

    if aws s3 ls "s3://${S3_BACKUP_BUCKET}" >/dev/null 2>&1; then
        log_info "S3 bucket already exists: ${S3_BACKUP_BUCKET}"
        return 0
    fi

    aws s3 mb "s3://${S3_BACKUP_BUCKET}" --region "${AWS_REGION}"

    aws s3api put-bucket-versioning \
        --bucket "${S3_BACKUP_BUCKET}" \
        --versioning-configuration Status=Enabled

    local lifecycle_config
    lifecycle_config=$(cat << EOF
{
    "Rules": [
        {
            "ID": "hras-backup-lifecycle",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "${S3_BACKUP_PREFIX}/"
            },
            "Transitions": [
                {
                    "Days": 30,
                    "StorageClass": "STANDARD_IA"
                },
                {
                    "Days": 90,
                    "StorageClass": "GLACIER"
                },
                {
                    "Days": 365,
                    "StorageClass": "DEEP_ARCHIVE"
                }
            ],
            "Expiration": {
                "Days": 2555
            }
        }
    ]
}
EOF
)

    aws s3api put-bucket-lifecycle-configuration \
        --bucket "${S3_BACKUP_BUCKET}" \
        --lifecycle-configuration "$lifecycle_config"

    log_success "S3 backup bucket created: ${S3_BACKUP_BUCKET}"
}

show_next_steps() {
    echo "
===========================================
AWS Infrastructure Setup Complete
===========================================

Next Steps:

1. Update deployment.env with the instance information above
2. Wait 2-3 minutes for the instance to fully boot
3. Run server setup:
   make deploy-setup

4. Configure SSL certificates:
   make deploy-ssl

5. Deploy the application:
   make deploy-production

6. Set up monitoring:
   make deploy-monitoring

Connection Information:
- SSH: ssh -i ~/.ssh/hras-deploy-key.pem ubuntu@[PUBLIC_IP]
- Web (after deployment): https://${DOMAIN}

AWS Resources Created:
- EC2 Instance: ${EC2_INSTANCE_ID:-"Will be shown after launch"}
- Security Group: Created with appropriate rules
- Key Pair: hras-deploy-key
$(if [[ -n "${S3_BACKUP_BUCKET:-}" ]]; then echo "- S3 Bucket: ${S3_BACKUP_BUCKET}"; fi)
$(if [[ -n "${ROUTE53_HOSTED_ZONE_ID:-}" ]]; then echo "- Route53 DNS: ${DOMAIN}"; fi)

For troubleshooting, check:
- AWS Console EC2 dashboard
- Instance logs: aws logs describe-log-groups
- Security group settings
"
}

main() {
    log_info "Starting AWS infrastructure setup for HRAS..."

    check_aws_cli
    create_key_pair
    launch_ec2_instance
    setup_route53_domain
    create_s3_backup_bucket
    show_next_steps

    log_success "AWS infrastructure setup completed!"
}

main "$@"
