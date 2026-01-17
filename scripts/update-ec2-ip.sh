#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

OLD_IP=""
NEW_IP=""
DRY_RUN=false

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <new-ip>

Update EC2 IP address references across the HRAS project.

Arguments:
    new-ip          The new EC2 public IP address

Options:
    -o, --old-ip    Specify old IP to replace (auto-detected if not provided)
    -d, --dry-run   Show what would be changed without making changes
    -h, --help      Show this help message

Examples:
    $(basename "$0") 54.123.45.67
    $(basename "$0") --old-ip 18.215.166.248 54.123.45.67
    $(basename "$0") --dry-run 54.123.45.67

Files that will be updated:
    - frontend/.env.production
    - docs/deployment/aws/*.md
    - Any other files containing the old IP
EOF
    exit 0
}

validate_ip() {
    local ip=$1
    if [[ ! $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Error: Invalid IP address format: $ip" >&2
        exit 1
    fi
}

detect_old_ip() {
    local env_file="$PROJECT_ROOT/frontend/.env.production"
    if [[ -f "$env_file" ]]; then
        local detected
        detected=$(grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' "$env_file" | head -1 || true)
        if [[ -n "$detected" ]]; then
            echo "$detected"
            return
        fi
    fi
    echo ""
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--old-ip)
            OLD_IP="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Error: Unknown option $1" >&2
            usage
            ;;
        *)
            NEW_IP="$1"
            shift
            ;;
    esac
done

if [[ -z "$NEW_IP" ]]; then
    echo "Error: New IP address is required" >&2
    usage
fi

validate_ip "$NEW_IP"

if [[ -z "$OLD_IP" ]]; then
    OLD_IP=$(detect_old_ip)
    if [[ -z "$OLD_IP" ]]; then
        echo "Error: Could not auto-detect old IP. Please specify with --old-ip" >&2
        exit 1
    fi
    echo "Auto-detected old IP: $OLD_IP"
fi

validate_ip "$OLD_IP"

if [[ "$OLD_IP" == "$NEW_IP" ]]; then
    echo "Old and new IP are the same. Nothing to do."
    exit 0
fi

echo ""
echo "=== HRAS EC2 IP Update ==="
echo "Old IP: $OLD_IP"
echo "New IP: $NEW_IP"
echo "Dry run: $DRY_RUN"
echo ""

FILES_TO_UPDATE=(
    "frontend/.env.production"
    "docs/deployment/aws/EC2_DEPLOYMENT.md"
    "docs/deployment/aws/TROUBLESHOOTING.md"
    "README.md"
)

update_count=0

for file in "${FILES_TO_UPDATE[@]}"; do
    filepath="$PROJECT_ROOT/$file"
    if [[ -f "$filepath" ]]; then
        if grep -q "$OLD_IP" "$filepath"; then
            echo "Updating: $file"
            if [[ "$DRY_RUN" == false ]]; then
                if [[ "$(uname)" == "Darwin" ]]; then
                    sed -i '' "s/$OLD_IP/$NEW_IP/g" "$filepath"
                else
                    sed -i "s/$OLD_IP/$NEW_IP/g" "$filepath"
                fi
            fi
            ((update_count++))
        fi
    fi
done

echo ""
find "$PROJECT_ROOT" -type f \( -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name ".env*" \) \
    -not -path "*/.git/*" \
    -not -path "*/node_modules/*" \
    -not -path "*/.next/*" \
    -exec grep -l "$OLD_IP" {} \; 2>/dev/null | while read -r file; do
    rel_path="${file#$PROJECT_ROOT/}"
    already_updated=false
    for known in "${FILES_TO_UPDATE[@]}"; do
        if [[ "$rel_path" == "$known" ]]; then
            already_updated=true
            break
        fi
    done
    if [[ "$already_updated" == false ]]; then
        echo "Additional file found: $rel_path"
        if [[ "$DRY_RUN" == false ]]; then
            if [[ "$(uname)" == "Darwin" ]]; then
                sed -i '' "s/$OLD_IP/$NEW_IP/g" "$file"
            else
                sed -i "s/$OLD_IP/$NEW_IP/g" "$file"
            fi
        fi
        ((update_count++)) || true
    fi
done

echo ""
echo "=== Summary ==="
if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run complete. No files were modified."
else
    echo "Updated $update_count file(s)."
fi

echo ""
echo "=== Next Steps ==="
echo "1. Commit and push changes:"
echo "   git add -A && git commit -m 'chore: update EC2 IP to $NEW_IP' && git push"
echo ""
echo "2. Update Amplify environment variable:"
echo "   NEXT_PUBLIC_API_URL=https://$NEW_IP"
echo ""
echo "3. Redeploy on EC2:"
echo "   ssh ubuntu@$NEW_IP 'cd ~/HRAS && git pull && docker compose -f zarf/docker/compose/docker-compose.yml --profile full up -d'"
