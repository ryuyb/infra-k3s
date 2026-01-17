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
    --with-argocd            Deploy ArgoCD and GitOps after K3s installation
    -h, --help               Show this help message

Prerequisites:
    - Ansible inventory configured
    - SSH access to all nodes
    - Tailscale authkey in vault
    - Environment variables for secrets (if using --with-argocd):
      R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, VELERO_BUCKET, R2_ENDPOINT, CLOUDFLARE_API_TOKEN

Examples:
    $(basename "$0")
    $(basename "$0") --bootstrap
    $(basename "$0") --skip-bootstrap
    $(basename "$0") --with-argocd
    $(basename "$0") --bootstrap --with-argocd
EOF
}

BOOTSTRAP=true
DEPLOY_ARGOCD=false

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
        --with-argocd)
            DEPLOY_ARGOCD=true
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
echo "Deploy ArgoCD: $DEPLOY_ARGOCD"
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

# Step 4: Deploy ArgoCD (optional)
if [[ "$DEPLOY_ARGOCD" == true ]]; then
    echo ""
    echo "=== Step 4: Deploy ArgoCD and GitOps ==="

    # Check required environment variables
    if [[ -z "${R2_ACCESS_KEY_ID:-}" ]] || [[ -z "${R2_SECRET_ACCESS_KEY:-}" ]] || \
       [[ -z "${VELERO_BUCKET:-}" ]] || [[ -z "${R2_ENDPOINT:-}" ]] || \
       [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
        echo "Error: Required environment variables not set" >&2
        echo "Please set: R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, VELERO_BUCKET, R2_ENDPOINT, CLOUDFLARE_API_TOKEN" >&2
        exit 1
    fi

    ansible-playbook ansible/playbooks/deploy-argocd.yml

    echo ""
    echo "ArgoCD deployed! Access the UI with:"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  URL: https://localhost:8080"
    echo ""
    echo "Get admin password:"
    echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
fi

echo ""
echo "Cluster initialization complete!"
echo "KUBECONFIG: $KUBECONFIG"
