#!/usr/bin/env bash
set -euo pipefail

# Failover workloads from one node to another

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Failover workloads from source node to target node.

Options:
    --source-node <node>     Node to failover from (required)
    --target-node <node>     Node to failover to (optional, uses scheduler)
    --backup <name>          Use existing backup (optional, creates new if not specified)
    --drain                  Drain source node before failover
    --cordon                 Cordon source node (prevent new pods)
    -h, --help               Show this help message

Examples:
    $(basename "$0") --source-node worker-1 --drain
    $(basename "$0") --source-node worker-1 --target-node worker-2
    $(basename "$0") --source-node worker-1 --backup daily-2024-01-15
EOF
}

SOURCE_NODE=""
TARGET_NODE=""
BACKUP_NAME=""
DRAIN=false
CORDON=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --source-node)
            SOURCE_NODE="$2"
            shift 2
            ;;
        --target-node)
            TARGET_NODE="$2"
            shift 2
            ;;
        --backup)
            BACKUP_NAME="$2"
            shift 2
            ;;
        --drain)
            DRAIN=true
            shift
            ;;
        --cordon)
            CORDON=true
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

if [[ -z "$SOURCE_NODE" ]]; then
    echo "Error: --source-node is required" >&2
    show_help
    exit 1
fi

echo "=== Failover Plan ==="
echo "Source node: $SOURCE_NODE"
echo "Target node: ${TARGET_NODE:-<scheduler will decide>}"
echo "Backup: ${BACKUP_NAME:-<will create new>}"
echo "Drain: $DRAIN"
echo "Cordon: $CORDON"
echo ""
read -p "Continue with failover? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Failover cancelled."
    exit 0
fi

# Step 1: Cordon or drain source node
if [[ "$DRAIN" == true ]]; then
    echo "Draining node $SOURCE_NODE..."
    kubectl drain "$SOURCE_NODE" --ignore-daemonsets --delete-emptydir-data --force
elif [[ "$CORDON" == true ]]; then
    echo "Cordoning node $SOURCE_NODE..."
    kubectl cordon "$SOURCE_NODE"
fi

# Step 2: Create backup if not specified
if [[ -z "$BACKUP_NAME" ]]; then
    BACKUP_NAME="failover-$(date +%Y%m%d-%H%M%S)"
    echo "Creating backup: $BACKUP_NAME..."
    velero backup create "$BACKUP_NAME" --wait
fi

# Step 3: Wait for pods to be rescheduled
echo "Waiting for pods to be rescheduled..."
sleep 10

# Step 4: Show status
echo ""
echo "=== Failover Status ==="
kubectl get pods -A -o wide | grep -v Running || true
echo ""
echo "Failover complete. Verify workloads are running on other nodes."
echo ""
echo "To uncordon the source node later:"
echo "  kubectl uncordon $SOURCE_NODE"
