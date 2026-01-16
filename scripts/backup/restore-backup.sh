#!/usr/bin/env bash
set -euo pipefail

# Restore from Velero backup

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <backup-name>

Restore from a Velero backup.

Options:
    -n, --namespace <ns>     Restore specific namespace only
    --namespace-mapping <old:new>  Map namespace during restore
    --include-resources <types>    Include specific resource types
    --exclude-resources <types>    Exclude specific resource types
    --restore-pvs            Restore persistent volumes (default: true)
    --wait                   Wait for restore to complete
    -h, --help               Show this help message

Examples:
    $(basename "$0") daily-2024-01-15
    $(basename "$0") -n myapp app-backup
    $(basename "$0") --namespace-mapping old-ns:new-ns backup-name
    $(basename "$0") --wait full-backup
EOF
}

NAMESPACE=""
NS_MAPPING=""
INCLUDE_RESOURCES=""
EXCLUDE_RESOURCES=""
RESTORE_PVS=true
WAIT=false
BACKUP_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --namespace-mapping)
            NS_MAPPING="$2"
            shift 2
            ;;
        --include-resources)
            INCLUDE_RESOURCES="$2"
            shift 2
            ;;
        --exclude-resources)
            EXCLUDE_RESOURCES="$2"
            shift 2
            ;;
        --restore-pvs)
            RESTORE_PVS=true
            shift
            ;;
        --no-restore-pvs)
            RESTORE_PVS=false
            shift
            ;;
        --wait)
            WAIT=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            show_help
            exit 1
            ;;
        *)
            BACKUP_NAME="$1"
            shift
            ;;
    esac
done

if [[ -z "$BACKUP_NAME" ]]; then
    echo "Error: Backup name is required" >&2
    show_help
    exit 1
fi

# Generate restore name
RESTORE_NAME="${BACKUP_NAME}-restore-$(date +%Y%m%d-%H%M%S)"

# Build velero command
CMD="velero restore create $RESTORE_NAME --from-backup $BACKUP_NAME"

if [[ -n "$NAMESPACE" ]]; then
    CMD="$CMD --include-namespaces $NAMESPACE"
fi

if [[ -n "$NS_MAPPING" ]]; then
    CMD="$CMD --namespace-mappings $NS_MAPPING"
fi

if [[ -n "$INCLUDE_RESOURCES" ]]; then
    CMD="$CMD --include-resources $INCLUDE_RESOURCES"
fi

if [[ -n "$EXCLUDE_RESOURCES" ]]; then
    CMD="$CMD --exclude-resources $EXCLUDE_RESOURCES"
fi

if [[ "$RESTORE_PVS" == true ]]; then
    CMD="$CMD --restore-volumes"
fi

if [[ "$WAIT" == true ]]; then
    CMD="$CMD --wait"
fi

echo "Restoring from backup: $BACKUP_NAME"
echo "Restore name: $RESTORE_NAME"
echo "Command: $CMD"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    eval "$CMD"
    echo ""
    echo "Restore initiated. Check status with:"
    echo "  velero restore describe $RESTORE_NAME"
else
    echo "Restore cancelled."
fi
