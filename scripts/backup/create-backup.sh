#!/usr/bin/env bash
set -euo pipefail

# Create Velero backup with optional labels and namespace filtering

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <backup-name>

Create a Velero backup.

Options:
    -n, --namespace <ns>     Backup specific namespace (can be repeated)
    -l, --label <key=value>  Add label selector (can be repeated)
    -s, --storage <location> Backup storage location (default: r2-default)
    --ttl <duration>         Backup TTL (default: 720h / 30 days)
    --wait                   Wait for backup to complete
    -h, --help               Show this help message

Examples:
    $(basename "$0") daily-2024-01-15
    $(basename "$0") -n myapp -n another-app app-backup
    $(basename "$0") -l backup=critical --ttl 168h critical-backup
    $(basename "$0") --wait full-backup
EOF
}

NAMESPACES=()
LABELS=()
STORAGE="r2-default"
TTL="720h"
WAIT=false
BACKUP_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACES+=("$2")
            shift 2
            ;;
        -l|--label)
            LABELS+=("$2")
            shift 2
            ;;
        -s|--storage)
            STORAGE="$2"
            shift 2
            ;;
        --ttl)
            TTL="$2"
            shift 2
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

cmd=(velero backup create "$BACKUP_NAME" --storage-location "$STORAGE" --ttl "$TTL")

if [[ ${#NAMESPACES[@]} -gt 0 ]]; then
    cmd+=(--include-namespaces "$(IFS=,; echo "${NAMESPACES[*]}")")
fi

if [[ ${#LABELS[@]} -gt 0 ]]; then
    cmd+=(--selector "$(IFS=,; echo "${LABELS[*]}")")
fi

if [[ "$WAIT" == true ]]; then
    cmd+=(--wait)
fi

printf -v cmd_str '%q ' "${cmd[@]}"
echo "Creating backup: $BACKUP_NAME"
echo "Command: ${cmd_str% }"
"${cmd[@]}"

echo ""
echo "Backup created. Check status with:"
echo "  velero backup describe $BACKUP_NAME"
