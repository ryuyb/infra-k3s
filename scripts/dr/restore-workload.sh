#!/usr/bin/env bash
set -euo pipefail

# Restore specific workload from backup

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Restore a specific workload from Velero backup.

Options:
    --app <name>             Application/namespace to restore (required)
    --backup <name>          Backup name (default: latest)
    --target-node <node>     Target node for restoration (optional)
    --include-pvs            Include persistent volumes
    -h, --help               Show this help message

Examples:
    $(basename "$0") --app myapp --backup latest
    $(basename "$0") --app myapp --backup daily-2024-01-15 --include-pvs
    $(basename "$0") --app myapp --target-node worker-2
EOF
}

APP=""
BACKUP_NAME="latest"
TARGET_NODE=""
INCLUDE_PVS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --app)
            APP="$2"
            shift 2
            ;;
        --backup)
            BACKUP_NAME="$2"
            shift 2
            ;;
        --target-node)
            TARGET_NODE="$2"
            shift 2
            ;;
        --include-pvs)
            INCLUDE_PVS=true
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

if [[ -z "$APP" ]]; then
    echo "Error: --app is required" >&2
    show_help
    exit 1
fi

# Find latest backup if specified
if [[ "$BACKUP_NAME" == "latest" ]]; then
    echo "Finding latest backup..."
    BACKUP_NAME=$(velero backup get -o json | jq -r '.items | sort_by(.metadata.creationTimestamp) | last | .metadata.name')
    if [[ -z "$BACKUP_NAME" || "$BACKUP_NAME" == "null" ]]; then
        echo "Error: No backups found" >&2
        exit 1
    fi
    echo "Using backup: $BACKUP_NAME"
fi

RESTORE_NAME="${APP}-restore-$(date +%Y%m%d-%H%M%S)"

echo "=== Restore Plan ==="
echo "Application: $APP"
echo "Backup: $BACKUP_NAME"
echo "Restore name: $RESTORE_NAME"
echo "Target node: ${TARGET_NODE:-<scheduler will decide>}"
echo "Include PVs: $INCLUDE_PVS"
echo ""
read -p "Continue with restore? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    exit 0
fi

# Build restore command
CMD="velero restore create $RESTORE_NAME --from-backup $BACKUP_NAME --include-namespaces $APP"

if [[ "$INCLUDE_PVS" == true ]]; then
    CMD="$CMD --restore-volumes"
fi

echo "Executing: $CMD"
eval "$CMD"

echo ""
echo "Restore initiated. Monitor with:"
echo "  velero restore describe $RESTORE_NAME"
echo "  kubectl get pods -n $APP -w"
