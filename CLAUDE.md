# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multi-cloud K3s infrastructure managing VPS servers across providers (Hetzner, Vultr, AWS) with Tailscale networking, GitOps (ArgoCD + Helm), and disaster recovery via Velero to Cloudflare R2.

## Commands

### Ansible
```bash
# Bootstrap VPS (initial setup via public IP)
ansible-playbook ansible/playbooks/bootstrap.yml

# Deploy K3s cluster
ansible-playbook ansible/playbooks/k3s-cluster.yml

# Deploy ArgoCD via Helm and GitOps (after K3s is running)
# Set DOMAIN environment variable for HTTPRoute
DOMAIN=yourdomain.com ansible-playbook ansible/playbooks/deploy-argocd.yml

# Setup cluster secrets from environment variables
ansible-playbook ansible/playbooks/setup-secrets.yml

# Upgrade K3s (rolling, one node at a time)
ansible-playbook ansible/playbooks/upgrade.yml

# System maintenance
ansible-playbook ansible/playbooks/maintenance.yml

# Edit encrypted secrets
ansible-vault edit ansible/inventory/group_vars/all/vault.yml

# One-command cluster initialization (bootstrap + K3s + ArgoCD)
DOMAIN=yourdomain.com ./scripts/setup/init-cluster.sh --with-argocd
```

### Helm
```bash
# List installed Helm releases
helm list -A

# Upgrade ArgoCD
helm upgrade argocd argo/argo-cd -n argocd --values helm/infrastructure/values.yaml

# View infrastructure components
kubectl get applications -n argocd
```

### OpenTofu
```bash
cd tofu && tofu plan
tofu apply
tofu apply -target=module.cloudflare-dns
```

### Kubernetes/GitOps
```bash
# Encrypt secrets with Sealed Secrets
kubectl create secret generic myapp-secret \
  --from-literal=key=value \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > kubernetes/apps/myapp/sealedsecret.yaml

# Fetch cluster certificate for offline encryption
kubeseal --fetch-cert > sealed-secrets-cert.pem

# Encrypt using local certificate (no cluster connection needed)
kubeseal --cert sealed-secrets-cert.pem --format yaml < secret.yaml > sealedsecret.yaml
```

### Disaster Recovery
```bash
./scripts/backup/create-backup.sh
./scripts/backup/list-backups.sh
./scripts/dr/failover.sh --source-node vps-aws-1 --target-node vps-vultr-1
./scripts/dr/restore-workload.sh --app myapp --backup latest --target-node vps-vultr-1
```

## Architecture

### Directory Layout
- `ansible/` - Server provisioning: playbooks orchestrate roles for bootstrap, k3s setup, networking
- `tofu/` - OpenTofu modules for Cloudflare DNS and R2 backup buckets
- `helm/` - Helm charts: `infrastructure/` (App of Apps for infrastructure components), `apps/` (application deployments)
- `kubernetes/` - Legacy kustomize manifests (being migrated to Helm)
- `scripts/` - Utilities for setup, backup, and disaster recovery
- `config/` - Shared Velero schedules and ArgoCD repo configs

### Key Patterns

**Ansible inventory**: Uses public IPs for initial bootstrap, then automatically switches to Tailscale IPs after installation. The `ansible_host` variable dynamically resolves: `{{ tailscale_ip | default(public_ip) }}`

**Secrets management**:
- Local dev: direnv (`.envrc`)
- Ansible: Ansible Vault (`group_vars/all/vault.yml`)
- Kubernetes: Sealed Secrets (encrypted in git, decrypted by sealed-secrets controller)
- OpenTofu: Environment variables via `TF_VAR_*`

**GitOps**: ArgoCD with App of Apps pattern using Helm charts:
- ArgoCD installed via Helm chart
- Infrastructure components deployed via Helm charts (cert-manager, traefik, external-dns, etc.)
- `helm/infrastructure/` contains ArgoCD Applications that reference official Helm charts
- Custom resources (Gateway, HTTPRoutes, ClusterIssuers) managed via Helm templates

**Disaster recovery**: Velero (deployed via Helm) backs up local PVCs to Cloudflare R2. On node failure, workloads restore to another node via DR scripts.

### Ansible Role Dependencies
```
bootstrap.yml → common → firewall → tailscale
k3s-master.yml → k3s-prereq → k3s-server
k3s-worker.yml → k3s-prereq → k3s-agent
deploy-argocd.yml → argocd (runs on k3s_masters[0], installs Helm, deploys ArgoCD chart)
```

### Node Groups
- `k3s_masters` - Control plane nodes (k3s server)
- `k3s_workers` - Worker nodes (k3s agent)
