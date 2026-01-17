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
| Storage | local-path | Local node storage (no distributed storage) |
| Ingress | Traefik + Gateway API | Traffic routing, TLS termination |
| TLS | cert-manager | Automated certificate management |
| GitOps | ArgoCD + Helm | Declarative deployments via Helm charts |
| Monitoring | Prometheus + Grafana | Metrics collection and visualization |
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
| Kubernetes | Sealed Secrets | Encrypted in git, decrypted by controller |
| OpenTofu | Environment | `TF_VAR_*` variables |

## Directory Structure

```
infra-k3s/
├── ansible/           # Server provisioning
│   ├── inventory/     # Host definitions
│   ├── playbooks/     # Orchestration
│   └── roles/         # Reusable components
├── helm/              # Helm charts
│   ├── infrastructure/      # ArgoCD Applications for infrastructure
│   ├── infrastructure-resources/  # Custom resources (Gateway, HTTPRoute, etc.)
│   └── apps/          # Application deployments
├── tofu/              # Infrastructure as Code
│   ├── modules/       # Reusable modules
│   └── stacks/        # Environment configs
├── scripts/           # Operational utilities
└── docs/              # Documentation
    ├── architecture.md
    ├── stateful-services.md
    └── disaster-recovery.md
```

## Node Roles

- **k3s_masters**: Control plane, runs K3s server, API server binds to Tailscale IP
- **k3s_workers**: Workload nodes, join cluster via master's Tailscale IP

## Storage Architecture

### Local Path Provisioner

The cluster uses K3s's built-in **local-path** storage provisioner:

- **Type**: Local node storage (hostPath-based)
- **Characteristics**:
  - No data replication across nodes
  - PVCs are bound to specific nodes
  - Fast I/O (direct disk access)
  - No network overhead

### Stateful Service Scheduling

Services with persistent volumes must be pinned to specific nodes:

**Methods**:
1. **NodeSelector (hostname)**: Pin to specific node
   ```yaml
   nodeSelector:
     kubernetes.io/hostname: master
   ```

2. **NodeSelector (labels)**: Pin to nodes with specific characteristics
   ```yaml
   nodeSelector:
     disk-type: ssd
     node-role.kubernetes.io/storage: "true"
   ```

3. **Node Affinity**: Complex scheduling rules with required/preferred logic

**Current Pinned Services**:
- Prometheus (10Gi) → master node
- Grafana (5Gi) → master node

See [stateful-services.md](stateful-services.md) for complete details.

### Backup Strategy

- **Velero** backs up PVCs to Cloudflare R2
- Enables disaster recovery across nodes
- Scheduled backups for stateful services

## Key Design Decisions

1. **Tailscale over VPN**: Zero-config mesh, no central gateway, works across NAT
2. **Gateway API over Ingress**: Modern standard, better multi-tenancy support
3. **cert-manager over Traefik ACME**: Centralized certificate management, supports DNS-01 for wildcards
4. **Sealed Secrets over SOPS**: No custom ArgoCD config, controller handles decryption
5. **R2 over S3**: Zero egress fees for backup restoration
6. **Helm over Kustomize**: Better templating, version management, and official chart ecosystem
7. **local-path over distributed storage**: Simpler setup, sufficient for small clusters with backup strategy
