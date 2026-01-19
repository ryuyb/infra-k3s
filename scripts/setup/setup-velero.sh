#!/usr/bin/env bash
set -euo pipefail

# Setup Velero with R2 credentials (SOPS-managed)

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
    VELERO_BUCKET            R2 bucket name
    R2_ENDPOINT              R2 endpoint URL

SOPS-managed secrets:
    k8s/secrets/velero-r2-credentials.sops.yaml

Examples:
    $(basename "$0") --create-secret
    $(basename "$0") --all
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOPS_VELERO_SECRET_FILE="${SOPS_VELERO_SECRET_FILE:-$PROJECT_ROOT/k8s/secrets/velero-r2-credentials.sops.yaml}"

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

require_env() {
    local missing=()
    [[ -z "${VELERO_BUCKET:-}" ]] && missing+=("VELERO_BUCKET")
    [[ -z "${R2_ENDPOINT:-}" ]] && missing+=("R2_ENDPOINT")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Error: Missing environment variables: ${missing[*]}" >&2
        echo "Set these in .envrc.local and run 'direnv allow'" >&2
        exit 1
    fi
}

require_sops_secret() {
    if ! command -v sops &>/dev/null; then
        echo "Error: sops is required to decrypt $SOPS_VELERO_SECRET_FILE" >&2
        exit 1
    fi

    if [[ ! -f "$SOPS_VELERO_SECRET_FILE" ]]; then
        echo "Error: Missing SOPS secret file: $SOPS_VELERO_SECRET_FILE" >&2
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
    require_sops_secret

    # Apply decrypted secret from SOPS
    sops -d "$SOPS_VELERO_SECRET_FILE" | kubectl apply -f -

    echo "Secret created successfully."
}

# Install Velero
install_velero() {
    echo "Installing Velero..."
    require_env

    if ! kubectl -n velero get secret velero-r2-credentials &>/dev/null; then
        echo "velero-r2-credentials secret not found; creating from SOPS..."
        create_secret
    fi

    if ! command -v velero &>/dev/null; then
        echo "Error: velero CLI not installed" >&2
        echo "Install with: brew install velero" >&2
        exit 1
    fi

    local creds
    creds="$(kubectl -n velero get secret velero-r2-credentials -o jsonpath='{.data.cloud}' | base64 -d)"

    velero install \
        --provider aws \
        --plugins velero/velero-plugin-for-aws:v1.9.0 \
        --bucket "$VELERO_BUCKET" \
        --secret-file /dev/stdin \
        --backup-location-config "region=auto,s3ForcePathStyle=true,s3Url=${R2_ENDPOINT}" \
        --use-node-agent \
        --uploader-type=kopia \
        <<< "$creds"

    echo "Velero installed successfully."
}

# Apply backup schedules
apply_schedules() {
    echo "Applying backup schedules..."

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
