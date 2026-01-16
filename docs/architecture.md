# Architecture

## Overview

Multi-cloud K3s cluster spanning VPS providers (Hetzner, Vultr, AWS) connected via Tailscale mesh network. GitOps deployment with ArgoCD, TLS via cert-manager, and disaster recovery to Cloudflare R2.

## Components

```
┌─────────────────────────────────────────────────────────────────┐
│                        Cloudflare                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │  DNS Zone   │  │  R2 Bucket  │  │   Tunnel    │              │
│  │  (*.domain) │  │  (backups)  │  │  (optional) │              │
│  └──────┬──────┘  └──────┬──────┘  └─────────────┘              │
└─────────┼────────────────┼──────────────────────────────────────┘
          │                │
          ▼                │
┌─────────────────────────────────────────────────────────────────┐
│                     Tailscale Mesh Network                       │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   Hetzner VPS   │  │   Vultr VPS     │  │    AWS VPS      │  │
│  │   (Master)      │◄─┼─►(Worker)       │◄─┼─►(Worker)       │  │
│  │   100.x.x.1     │  │   100.x.x.2     │  │   100.x.x.3     │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Layer Stack

| Layer | Component | Purpose |
|-------|-----------|---------|
| DNS | Cloudflare | Domain management, CDN proxy |
| Networking | Tailscale | Encrypted mesh between nodes |
| Orchestration | K3s | Lightweight Kubernetes |
| Ingress | Traefik + Gateway API | Traffic routing, TLS termination |
| TLS | cert-manager | Automated certificate management |
| GitOps | ArgoCD + KSOPS | Declarative deployments, secret decryption |
| Backup | Velero + Kopia | Cluster and PVC backup to R2 |
| IaC | OpenTofu | DNS and R2 bucket provisioning |
| Config | Ansible | Server provisioning and K3s installation |

## Traffic Flow

```
Internet → Cloudflare DNS → VPS Public IP → Traefik (Gateway)
                                                    │
                                    ┌───────────────┼───────────────┐
                                    ▼               ▼               ▼
                                HTTPRoute       HTTPRoute       HTTPRoute
                                    │               │               │
                                    ▼               ▼               ▼
                                Service A       Service B       Service C
```

## Secret Management

| Context | Tool | Storage |
|---------|------|---------|
| Local dev | direnv | `.envrc.local` (gitignored) |
| Ansible | Ansible Vault | `group_vars/all/vault.yml` |
| Kubernetes | SOPS + age | Encrypted in git, decrypted by KSOPS |
| OpenTofu | Environment | `TF_VAR_*` variables |

## Directory Structure

```
infra-k3s/
├── ansible/           # Server provisioning
│   ├── inventory/     # Host definitions
│   ├── playbooks/     # Orchestration
│   └── roles/         # Reusable components
├── kubernetes/        # GitOps manifests
│   ├── bootstrap/     # ArgoCD installation
│   ├── infrastructure/# Core services
│   └── apps/          # Application workloads
├── tofu/              # Infrastructure as Code
│   ├── modules/       # Reusable modules
│   └── stacks/        # Environment configs
├── scripts/           # Operational utilities
└── docs/              # Documentation
```

## Node Roles

- **k3s_masters**: Control plane, runs K3s server, API server binds to Tailscale IP
- **k3s_workers**: Workload nodes, join cluster via master's Tailscale IP

## Key Design Decisions

1. **Tailscale over VPN**: Zero-config mesh, no central gateway, works across NAT
2. **Gateway API over Ingress**: Modern standard, better multi-tenancy support
3. **cert-manager over Traefik ACME**: Centralized certificate management, supports DNS-01 for wildcards
4. **SOPS over Sealed Secrets**: Works offline, age encryption, git-friendly
5. **R2 over S3**: Zero egress fees for backup restoration
