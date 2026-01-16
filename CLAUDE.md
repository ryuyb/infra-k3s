# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multi-cloud K3s infrastructure managing VPS servers across providers (Hetzner, Vultr, AWS) with Tailscale networking, GitOps (ArgoCD), and disaster recovery via Velero to Cloudflare R2.

## Commands

### Ansible
```bash
# Bootstrap VPS (initial setup via public IP)
ansible-playbook ansible/playbooks/bootstrap.yml

# Deploy K3s cluster
ansible-playbook ansible/playbooks/k3s-cluster.yml

# Upgrade K3s (rolling, one node at a time)
ansible-playbook ansible/playbooks/upgrade.yml

# System maintenance
ansible-playbook ansible/playbooks/maintenance.yml

# Edit encrypted secrets
ansible-vault edit ansible/inventory/group_vars/all/vault.yml
```

### OpenTofu
```bash
cd tofu && tofu plan
tofu apply
tofu apply -target=module.cloudflare-dns
```

### Kubernetes/GitOps
```bash
# Encrypt secrets with SOPS
sops -e -i kubernetes/apps/myapp/secret.yaml

# Decrypt for viewing
sops -d kubernetes/apps/myapp/secret.yaml
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
- `kubernetes/` - GitOps manifests: `bootstrap/` (ArgoCD), `infrastructure/` (cert-manager, ingress, velero), `apps/`
- `scripts/` - Utilities for setup, backup, and disaster recovery
- `config/` - Shared Velero schedules and ArgoCD repo configs

### Key Patterns

**Ansible inventory**: Uses public IPs for initial bootstrap, then automatically switches to Tailscale IPs after installation. The `ansible_host` variable dynamically resolves: `{{ tailscale_ip | default(public_ip) }}`

**Secrets management**:
- Local dev: direnv (`.envrc`)
- Ansible: Ansible Vault (`group_vars/all/vault.yml`)
- Kubernetes: SOPS + age (encrypted in git, decrypted by ArgoCD with KSOPS)
- OpenTofu: Environment variables via `TF_VAR_*`

**GitOps**: ArgoCD with App of Apps pattern - `kubernetes/bootstrap/argocd/apps/` contains root applications that deploy infrastructure and apps

**Disaster recovery**: Velero + Kopia backs up local PVCs to Cloudflare R2. On node failure, workloads restore to another node via DR scripts.

### Ansible Role Dependencies
```
bootstrap.yml → common → firewall → tailscale
k3s-master.yml → k3s-prereq → k3s-server
k3s-worker.yml → k3s-prereq → k3s-agent
```

### Node Groups
- `k3s_masters` - Control plane nodes (k3s server)
- `k3s_workers` - Worker nodes (k3s agent)
