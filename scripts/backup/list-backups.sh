#!/usr/bin/env bash
set -euo pipefail

# List Velero backups with status

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

List Velero backups with status.

Options:
    -a, --all                Show all backups (including failed)
    -n, --namespace <ns>     Filter by namespace
    -l, --label <key=value>  Filter by label
    --json                   Output as JSON
    -h, --help               Show this help message

Examples:
    $(basename "$0")
    $(basename "$0") --all
    $(basename "$0") -n myapp
    $(basename "$0") --json
EOF
}

SHOW_ALL=false
NAMESPACE=""
LABEL=""
JSON=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all)
            SHOW_ALL=true
            shift
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -l|--label)
            LABEL="$2"
            shift 2
            ;;
        --json)
            JSON=true
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

CMD="velero backup get"

if [[ "$JSON" == true ]]; then
    CMD="$CMD -o json"
fi

if [[ -n "$LABEL" ]]; then
    CMD="$CMD --selector $LABEL"
fi

eval "$CMD"

if [[ "$JSON" != true ]]; then
    echo ""
    echo "For details: velero backup describe <backup-name>"
    echo "For logs: velero backup logs <backup-name>"
fi
