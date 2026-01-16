#!/usr/bin/env bash
set -euo pipefail

# Recover a failed node by re-provisioning and rejoining cluster

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Recover a failed node by re-provisioning and rejoining the K3s cluster.

Options:
    --node <name>            Node name to recover (required)
    --role <master|worker>   Node role (default: worker)
    --reinstall              Reinstall K3s on the node
    -h, --help               Show this help message

Prerequisites:
    - Ansible inventory configured with node
    - SSH access to the node
    - K3s cluster running

Examples:
    $(basename "$0") --node worker-1
    $(basename "$0") --node worker-2 --reinstall
    $(basename "$0") --node master-2 --role master
EOF
}

NODE=""
ROLE="worker"
REINSTALL=false

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
        --reinstall)
            REINSTALL=true
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

echo "=== Node Recovery Plan ==="
echo "Node: $NODE"
echo "Role: $ROLE"
echo "Reinstall K3s: $REINSTALL"
echo ""

# Check if node exists in Kubernetes
if kubectl get node "$NODE" &>/dev/null; then
    NODE_STATUS=$(kubectl get node "$NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    echo "Current node status: $NODE_STATUS"

    if [[ "$NODE_STATUS" == "True" ]]; then
        echo "Warning: Node appears to be healthy. Continue anyway?"
        read -p "[y/N] " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
else
    echo "Node not found in cluster (may have been removed)"
fi

echo ""
read -p "Continue with recovery? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Recovery cancelled."
    exit 0
fi

# Step 1: Remove node from cluster if exists
if kubectl get node "$NODE" &>/dev/null; then
    echo "Removing node from cluster..."
    kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --force || true
    kubectl delete node "$NODE" || true
fi

# Step 2: Run Ansible playbook
echo "Running Ansible playbook..."
cd "$PROJECT_ROOT"

if [[ "$REINSTALL" == true ]]; then
    echo "Uninstalling K3s on $NODE..."
    ansible-playbook ansible/playbooks/k3s-uninstall.yml --limit "$NODE" || true
fi

if [[ "$ROLE" == "master" ]]; then
    ansible-playbook ansible/playbooks/k3s-master.yml --limit "$NODE"
else
    ansible-playbook ansible/playbooks/k3s-worker.yml --limit "$NODE"
fi

# Step 3: Verify node joined
echo ""
echo "Waiting for node to join cluster..."
sleep 10

kubectl get nodes
echo ""
echo "Node recovery complete. Verify node status above."
