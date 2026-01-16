#!/usr/bin/env bash
set -euo pipefail

# Setup Velero with R2 credentials

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Setup Velero with Cloudflare R2 credentials.

Options:
    --create-secret          Create velero-r2-credentials secret
    --install                Install Velero with node-agent
    --apply-schedules        Apply backup schedules
    --all                    Do all of the above
    -h, --help               Show this help message

Environment variables required:
    R2_ACCESS_KEY_ID         R2 API token ID
    R2_SECRET_ACCESS_KEY     R2 API token secret
    VELERO_BUCKET            R2 bucket name
    R2_ENDPOINT              R2 endpoint URL

Examples:
    $(basename "$0") --create-secret
    $(basename "$0") --all
EOF
}

CREATE_SECRET=false
INSTALL=false
APPLY_SCHEDULES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --create-secret)
            CREATE_SECRET=true
            shift
            ;;
        --install)
            INSTALL=true
            shift
            ;;
        --apply-schedules)
            APPLY_SCHEDULES=true
            shift
            ;;
        --all)
            CREATE_SECRET=true
            INSTALL=true
            APPLY_SCHEDULES=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

# Validate environment variables
check_env() {
    local missing=()
    [[ -z "${R2_ACCESS_KEY_ID:-}" ]] && missing+=("R2_ACCESS_KEY_ID")
    [[ -z "${R2_SECRET_ACCESS_KEY:-}" ]] && missing+=("R2_SECRET_ACCESS_KEY")
    [[ -z "${VELERO_BUCKET:-}" ]] && missing+=("VELERO_BUCKET")
    [[ -z "${R2_ENDPOINT:-}" ]] && missing+=("R2_ENDPOINT")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Error: Missing environment variables: ${missing[*]}" >&2
        echo "Set these in .envrc.local and run 'direnv allow'" >&2
        exit 1
    fi
}

# Create velero namespace if not exists
ensure_namespace() {
    kubectl get namespace velero &>/dev/null || kubectl create namespace velero
}

# Create R2 credentials secret
create_secret() {
    echo "Creating velero-r2-credentials secret..."
    check_env

    # Delete existing secret if exists
    kubectl delete secret velero-r2-credentials -n velero 2>/dev/null || true

    # Create credentials file content
    local creds="[default]
aws_access_key_id=${R2_ACCESS_KEY_ID}
aws_secret_access_key=${R2_SECRET_ACCESS_KEY}"

    kubectl create secret generic velero-r2-credentials \
        --namespace velero \
        --from-literal=cloud="$creds"

    echo "Secret created successfully."
}

# Install Velero
install_velero() {
    echo "Installing Velero..."
    check_env

    if ! command -v velero &>/dev/null; then
        echo "Error: velero CLI not installed" >&2
        echo "Install with: brew install velero" >&2
        exit 1
    fi

    velero install \
        --provider aws \
        --plugins velero/velero-plugin-for-aws:v1.9.0 \
        --bucket "$VELERO_BUCKET" \
        --secret-file /dev/stdin \
        --backup-location-config "region=auto,s3ForcePathStyle=true,s3Url=${R2_ENDPOINT}" \
        --use-node-agent \
        --uploader-type=kopia \
        <<< "[default]
aws_access_key_id=${R2_ACCESS_KEY_ID}
aws_secret_access_key=${R2_SECRET_ACCESS_KEY}"

    echo "Velero installed successfully."
}

# Apply backup schedules
apply_schedules() {
    echo "Applying backup schedules..."

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

    kubectl apply -f "$PROJECT_ROOT/kubernetes/infrastructure/velero/schedules.yaml"

    echo "Schedules applied."
}

# Main
if [[ "$CREATE_SECRET" == false && "$INSTALL" == false && "$APPLY_SCHEDULES" == false ]]; then
    show_help
    exit 0
fi

ensure_namespace

[[ "$CREATE_SECRET" == true ]] && create_secret
[[ "$INSTALL" == true ]] && install_velero
[[ "$APPLY_SCHEDULES" == true ]] && apply_schedules

echo ""
echo "Done! Check status with: velero backup-location get"
