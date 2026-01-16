# Multi-Cloud K3s Infrastructure

Managing multiple VPS servers across cloud platforms with k3s, Tailscale networking, and GitOps.

## Features

- K3s cluster across Hetzner, Vultr, AWS
- Tailscale mesh networking (ZeroTier-ready)
- Ansible automation for provisioning
- ArgoCD GitOps deployment
- Velero backup to Cloudflare R2
- Disaster recovery with local PVC support

## Quick Start

### Prerequisites

```bash
brew install direnv sops age ansible
```

### Setup

```bash
# 1. Configure direnv for your shell
# zsh
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
# fish
echo 'direnv hook fish | source' >> ~/.config/fish/config.fish

# 2. Generate age key for SOPS (in project directory)
age-keygen -o .age-key.txt
# Update .sops.yaml with your public key from the output

# 3. Setup environment
cp .envrc.example .envrc.local
# Edit .envrc.local with your secrets
direnv allow

# 4. Create Ansible vault password (in project directory)
echo "your-vault-password" > .vault_pass
chmod 600 .vault_pass

# 5. Initialize Ansible vault
ansible-vault create ansible/inventory/group_vars/all/vault.yml
```

### Deploy

```bash
# Bootstrap VPS (initial setup)
ansible-playbook ansible/playbooks/bootstrap.yml

# Deploy K3s cluster
ansible-playbook ansible/playbooks/k3s-cluster.yml
```

## Directory Structure

```
ansible/          # Server provisioning
tofu/             # OpenTofu (Cloudflare DNS, R2)
kubernetes/       # GitOps manifests
scripts/          # Utilities
config/           # Shared configs
docs/             # Documentation
```

## Documentation

- [Architecture](ARCHITECTURE.md)
- [Implementation Plan](IMPLEMENTATION_PLAN.md)
- [Disaster Recovery](docs/disaster-recovery.md)
