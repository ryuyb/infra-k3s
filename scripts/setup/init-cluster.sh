#!/usr/bin/env bash
set -euo pipefail

# Initialize K3s cluster from scratch

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Initialize a new K3s cluster.

Options:
    --bootstrap              Run bootstrap playbook first
    --skip-bootstrap         Skip bootstrap, only install K3s
    -h, --help               Show this help message

Prerequisites:
    - Ansible inventory configured
    - SSH access to all nodes
    - Tailscale authkey in vault

Examples:
    $(basename "$0")
    $(basename "$0") --bootstrap
    $(basename "$0") --skip-bootstrap
EOF
}

BOOTSTRAP=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --bootstrap)
            BOOTSTRAP=true
            shift
            ;;
        --skip-bootstrap)
            BOOTSTRAP=false
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

echo "=== K3s Cluster Initialization ==="
echo "Project root: $PROJECT_ROOT"
echo "Bootstrap: $BOOTSTRAP"
echo ""

# Verify prerequisites
if [[ ! -f ansible/inventory/hosts.yml ]]; then
    echo "Error: ansible/inventory/hosts.yml not found" >&2
    exit 1
fi

if [[ ! -f .vault_pass ]]; then
    echo "Error: .vault_pass not found" >&2
    exit 1
fi

echo "Inventory:"
ansible-inventory --list --yaml | head -20
echo "..."
echo ""

read -p "Continue with cluster initialization? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Initialization cancelled."
    exit 0
fi

# Step 1: Bootstrap (optional)
if [[ "$BOOTSTRAP" == true ]]; then
    echo ""
    echo "=== Step 1: Bootstrap ==="
    ansible-playbook ansible/playbooks/bootstrap.yml
fi

# Step 2: Install K3s
echo ""
echo "=== Step 2: Install K3s Cluster ==="
ansible-playbook ansible/playbooks/k3s-cluster.yml

# Step 3: Verify
echo ""
echo "=== Step 3: Verify Cluster ==="
export KUBECONFIG="$PROJECT_ROOT/kubeconfig.yaml"
kubectl get nodes
kubectl get pods -A

echo ""
echo "Cluster initialization complete!"
echo "KUBECONFIG: $KUBECONFIG"
