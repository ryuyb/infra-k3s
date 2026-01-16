#!/usr/bin/env bash
set -euo pipefail

# Join a new node to existing K3s cluster

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Join a new node to the K3s cluster.

Options:
    --node <name>            Node name from inventory (required)
    --role <master|worker>   Node role (default: worker)
    --bootstrap              Run bootstrap playbook first
    -h, --help               Show this help message

Prerequisites:
    - Node added to ansible/inventory/hosts.yml
    - SSH access to the node
    - K3s cluster already running

Examples:
    $(basename "$0") --node worker-3
    $(basename "$0") --node worker-3 --bootstrap
    $(basename "$0") --node master-2 --role master
EOF
}

NODE=""
ROLE="worker"
BOOTSTRAP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --node)
            NODE="$2"
            shift 2
            ;;
        --role)
            ROLE="$2"
            shift 2
            ;;
        --bootstrap)
            BOOTSTRAP=true
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

if [[ -z "$NODE" ]]; then
    echo "Error: --node is required" >&2
    show_help
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

echo "=== Join Node to Cluster ==="
echo "Node: $NODE"
echo "Role: $ROLE"
echo "Bootstrap: $BOOTSTRAP"
echo ""

# Verify node exists in inventory
if ! ansible-inventory --host "$NODE" &>/dev/null; then
    echo "Error: Node '$NODE' not found in inventory" >&2
    echo "Add the node to ansible/inventory/hosts.yml first"
    exit 1
fi

read -p "Continue? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Step 1: Bootstrap (optional)
if [[ "$BOOTSTRAP" == true ]]; then
    echo ""
    echo "=== Step 1: Bootstrap ==="
    ansible-playbook ansible/playbooks/bootstrap.yml --limit "$NODE"
fi

# Step 2: Join cluster
echo ""
echo "=== Step 2: Join Cluster ==="
if [[ "$ROLE" == "master" ]]; then
    ansible-playbook ansible/playbooks/k3s-master.yml --limit "$NODE"
else
    ansible-playbook ansible/playbooks/k3s-worker.yml --limit "$NODE"
fi

# Step 3: Verify
echo ""
echo "=== Step 3: Verify ==="
sleep 5
kubectl get nodes

echo ""
echo "Node $NODE joined successfully!"
