# Multi-Cloud K3s Infrastructure Implementation Plan

Based on ARCHITECTURE.md, this plan implements the infrastructure in 6 phases with detailed tasks and verification checklists.

---

## Phase 1: Foundation

### Task 1.1: Create Directory Structure & Base Files
**Files to create:**
- `README.md`
- `.gitignore`
- `.envrc.example`
- `.sops.yaml`

**Checklist:**
- [x] README.md contains project overview and quick start
- [x] .gitignore excludes: `.envrc`, `*.tfstate*`, `*.retry`, `__pycache__`, `.vault_pass`
- [x] .envrc.example has all required env vars (CLOUDFLARE_*, AWS_*, ANSIBLE_VAULT_*)
- [x] .sops.yaml configured for kubernetes/ path with age encryption

---

### Task 1.2: Ansible Base Structure
**Files to create:**
```
ansible/
├── ansible.cfg
├── inventory/
│   ├── hosts.yml
│   └── group_vars/
│       ├── all.yml
│       ├── k3s_masters.yml
│       └── k3s_workers.yml
```

**Checklist:**
- [x] ansible.cfg sets inventory path, vault password file, SSH settings
- [x] hosts.yml has k3s_masters and k3s_workers groups with placeholder hosts
- [x] all.yml defines ansible_host dynamic resolution: `{{ tailscale_ip | default(public_ip) }}`
- [x] Validate: `ansible-inventory --list` runs without errors

---

### Task 1.3: Ansible Role - common
**Files to create:**
```
ansible/roles/common/
├── tasks/
│   ├── main.yml
│   └── gather_facts.yml
├── handlers/main.yml
└── defaults/main.yml
```

**Functionality:**
- Install base packages (curl, wget, htop, vim, etc.)
- Configure timezone and locale
- Setup SSH hardening
- Gather Tailscale facts for dynamic IP resolution

**Checklist:**
- [x] main.yml installs essential packages
- [x] gather_facts.yml checks Tailscale installation and sets tailscale_ip fact
- [x] Supports both Debian/Ubuntu and RHEL/CentOS families
- [x] Validate: `ansible-playbook --syntax-check` passes

---

### Task 1.4: Ansible Role - firewall
**Files to create:**
```
ansible/roles/firewall/
├── tasks/main.yml
├── handlers/main.yml
└── defaults/main.yml
```

**Functionality:**
- Install and configure UFW (Debian) or firewalld (RHEL)
- Allow SSH (22), Tailscale (41641/udp), K3s ports (6443, 10250)
- Default deny incoming, allow outgoing

**Checklist:**
- [ ] Firewall enabled with default deny policy
- [ ] SSH port allowed
- [ ] Tailscale UDP port allowed
- [ ] K3s API port (6443) allowed from Tailscale network only
- [ ] Validate: `ufw status` shows correct rules (on test)

---

### Task 1.5: Ansible Role - tailscale
**Files to create:**
```
ansible/roles/tailscale/
├── tasks/main.yml
├── handlers/main.yml
└── defaults/main.yml
```

**Functionality:**
- Install Tailscale from official repo
- Authenticate with authkey
- Enable Tailscale SSH
- Export Tailscale IP as fact

**Checklist:**
- [ ] Installs Tailscale for Debian and RHEL families
- [ ] Authenticates with `tailscale up --authkey --ssh`
- [ ] Sets `tailscale_ip` fact after authentication
- [ ] Handler restarts tailscaled on config changes
- [ ] Validate: Role syntax check passes

---

### Task 1.6: Bootstrap Playbook
**Files to create:**
```
ansible/playbooks/
├── bootstrap.yml
└── site.yml
```

**Functionality:**
- bootstrap.yml: Initial VPS setup (common → firewall → tailscale)
- site.yml: Main entry point that includes all playbooks

**Checklist:**
- [ ] bootstrap.yml targets all hosts
- [ ] Runs roles in order: common, firewall, tailscale
- [ ] site.yml imports bootstrap and k3s playbooks
- [ ] Validate: `ansible-playbook playbooks/bootstrap.yml --syntax-check`

---

## Phase 2: K3s Cluster

### Task 2.1: Ansible Role - k3s-prereq
**Files to create:**
```
ansible/roles/k3s-prereq/
├── tasks/main.yml
├── handlers/main.yml
└── defaults/main.yml
```

**Functionality:**
- Disable swap
- Load required kernel modules (br_netfilter, overlay)
- Set sysctl parameters for networking
- Install container runtime dependencies

**Checklist:**
- [ ] Swap disabled and removed from fstab
- [ ] Kernel modules loaded and persisted
- [ ] sysctl net.bridge.bridge-nf-call-iptables = 1
- [ ] Validate: `sysctl net.bridge.bridge-nf-call-iptables` returns 1

---

### Task 2.2: Ansible Role - k3s-server
**Files to create:**
```
ansible/roles/k3s-server/
├── tasks/main.yml
├── handlers/main.yml
├── defaults/main.yml
└── templates/
    └── k3s-config.yaml.j2
```

**Functionality:**
- Install k3s in server mode
- Configure to use Tailscale IP for API server
- Generate and store k3s token
- Setup kubeconfig

**Checklist:**
- [ ] K3s installed via official script
- [ ] API server binds to Tailscale IP
- [ ] k3s token saved to vault or host_vars
- [ ] kubeconfig accessible at /etc/rancher/k3s/k3s.yaml
- [ ] Validate: `kubectl get nodes` shows master node Ready

---

### Task 2.3: Ansible Role - k3s-agent
**Files to create:**
```
ansible/roles/k3s-agent/
├── tasks/main.yml
├── handlers/main.yml
├── defaults/main.yml
└── templates/
    └── k3s-agent-config.yaml.j2
```

**Functionality:**
- Install k3s in agent mode
- Join cluster using master's Tailscale IP and token
- Configure node labels

**Checklist:**
- [ ] K3s agent installed and joined to cluster
- [ ] Uses Tailscale IP to connect to master
- [ ] Node labels applied (zone, instance-type)
- [ ] Validate: `kubectl get nodes` shows worker node Ready

---

### Task 2.4: K3s Cluster Playbooks
**Files to create:**
```
ansible/playbooks/
├── k3s-cluster.yml
├── k3s-master.yml
├── k3s-worker.yml
└── k3s-uninstall.yml
```

**Checklist:**
- [ ] k3s-master.yml: k3s-prereq → k3s-server on k3s_masters
- [ ] k3s-worker.yml: k3s-prereq → k3s-agent on k3s_workers
- [ ] k3s-cluster.yml: Orchestrates master then workers
- [ ] k3s-uninstall.yml: Clean removal of k3s
- [ ] Validate: All playbooks pass syntax check

---

## Phase 3: GitOps (ArgoCD)

### Task 3.1: Kubernetes Bootstrap Structure
**Files to create:**
```
kubernetes/
├── bootstrap/
│   ├── namespaces.yaml
│   └── argocd/
│       ├── install.yaml
│       ├── projects/
│       │   └── infrastructure.yaml
│       └── apps/
│           ├── infrastructure.yaml
│           └── apps.yaml
```

**Checklist:**
- [ ] namespaces.yaml creates: argocd, cert-manager, ingress-nginx, velero
- [ ] install.yaml is ArgoCD installation manifest (from official)
- [ ] App of Apps pattern: infrastructure.yaml and apps.yaml root apps
- [ ] Validate: `kubectl apply --dry-run=client -f kubernetes/bootstrap/`

---

### Task 3.2: Infrastructure Apps
**Files to create:**
```
kubernetes/infrastructure/
├── cert-manager/
│   └── kustomization.yaml
├── ingress-nginx/
│   └── kustomization.yaml
├── velero/
│   └── kustomization.yaml
├── external-dns/
│   └── kustomization.yaml
└── sealed-secrets/
    └── kustomization.yaml
```

**Checklist:**
- [ ] Each app has kustomization.yaml referencing upstream + patches
- [ ] cert-manager configured for Let's Encrypt
- [ ] ingress-nginx with appropriate annotations
- [ ] Velero configured for R2 backend
- [ ] Validate: `kustomize build kubernetes/infrastructure/cert-manager/`

---

### Task 3.3: App Template
**Files to create:**
```
kubernetes/apps/_template/
├── kustomization.yaml
├── deployment.yaml
├── service.yaml
├── ingress.yaml
└── secret.yaml.example
```

**Checklist:**
- [ ] Template provides starting point for new apps
- [ ] Includes common labels and annotations
- [ ] secret.yaml.example shows SOPS encryption format
- [ ] Validate: Template is valid Kubernetes YAML

---

## Phase 4: Backup & DR

### Task 4.1: Velero Configuration
**Files to create:**
```
config/velero/
├── backup-locations.yaml
└── schedules/
    ├── daily.yaml
    └── hourly-critical.yaml
```

**Checklist:**
- [ ] backup-locations.yaml configures R2 as S3-compatible backend
- [ ] daily.yaml: 30-day retention, all namespaces
- [ ] hourly-critical.yaml: 7-day retention, labeled apps only
- [ ] Validate: YAML syntax valid

---

### Task 4.2: Ansible Role - node-agent
**Files to create:**
```
ansible/roles/node-agent/
├── tasks/main.yml
└── defaults/main.yml
```

**Functionality:**
- Install Velero node-agent (for PVC backup)
- Configure for Kopia integration

**Checklist:**
- [ ] Node-agent DaemonSet deployed
- [ ] Can access local PVCs
- [ ] Validate: `kubectl get pods -n velero` shows node-agent running

---

### Task 4.3: DR Scripts
**Files to create:**
```
scripts/
├── backup/
│   ├── create-backup.sh
│   ├── list-backups.sh
│   └── restore-backup.sh
├── dr/
│   ├── failover.sh
│   ├── restore-workload.sh
│   └── node-recovery.sh
└── setup/
    ├── init-cluster.sh
    └── join-node.sh
```

**Checklist:**
- [ ] create-backup.sh: Creates Velero backup with labels
- [ ] list-backups.sh: Lists backups with status
- [ ] restore-backup.sh: Restores specific backup
- [ ] failover.sh: Cordons node, restores to target
- [ ] All scripts have `--help` option
- [ ] All scripts are executable (chmod +x)
- [ ] Validate: `./scripts/backup/list-backups.sh --help` works

---

## Phase 5: DNS & Infrastructure (OpenTofu)

### Task 5.1: OpenTofu Base Structure
**Files to create:**
```
tofu/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example
└── backend.tf
```

**Checklist:**
- [ ] main.tf configures Cloudflare provider
- [ ] variables.tf defines cloudflare_api_token (sensitive), zone_id
- [ ] backend.tf configures R2 or local state
- [ ] terraform.tfvars.example shows required variables
- [ ] Validate: `tofu init` succeeds

---

### Task 5.2: Cloudflare DNS Module
**Files to create:**
```
tofu/modules/cloudflare-dns/
├── main.tf
├── variables.tf
└── outputs.tf
```

**Functionality:**
- Create/manage DNS A records
- Support for proxied and non-proxied records
- TTL configuration

**Checklist:**
- [ ] Module accepts domain, subdomain, IP, proxied, TTL
- [ ] Creates cloudflare_record resources
- [ ] Outputs record ID and FQDN
- [ ] Validate: `tofu plan` shows expected resources

---

### Task 5.3: R2 Bucket Module
**Files to create:**
```
tofu/modules/r2-bucket/
├── main.tf
├── variables.tf
└── outputs.tf
```

**Functionality:**
- Create R2 bucket for Velero backups
- Configure lifecycle rules

**Checklist:**
- [ ] Creates R2 bucket with specified name
- [ ] Configures CORS if needed
- [ ] Outputs bucket name and endpoint
- [ ] Validate: Module syntax valid

---

### Task 5.4: DNS Configuration
**Files to create:**
```
tofu/dns.tf
```

**Functionality:**
- Define DNS records for cluster services
- Wildcard record for ingress

**Checklist:**
- [ ] Uses cloudflare-dns module
- [ ] Creates records for: API server, wildcard ingress
- [ ] Validate: `tofu plan` shows DNS records

---

## Phase 6: Documentation

### Task 6.1: Runbooks
**Files to create:**
```
docs/
├── architecture.md
├── networking.md
├── disaster-recovery.md
└── runbooks/
    ├── add-node.md
    ├── remove-node.md
    ├── upgrade-k3s.md
    └── restore-service.md
```

**Checklist:**
- [ ] Each runbook has: Prerequisites, Steps, Verification, Rollback
- [ ] architecture.md explains system design
- [ ] networking.md covers Tailscale setup
- [ ] disaster-recovery.md documents DR procedures
- [ ] Validate: All markdown renders correctly

---

## Verification Summary

### End-to-End Test Sequence
1. **Foundation**: `ansible-playbook playbooks/bootstrap.yml --syntax-check`
2. **K3s**: `ansible-playbook playbooks/k3s-cluster.yml --syntax-check`
3. **GitOps**: `kubectl apply --dry-run=client -f kubernetes/bootstrap/`
4. **Tofu**: `cd tofu && tofu init && tofu validate`
5. **Scripts**: Run each script with `--help`

### Per-Phase Acceptance Criteria

| Phase | Acceptance Criteria |
|-------|---------------------|
| 1 | `ansible-inventory --list` works, all roles pass syntax check |
| 2 | K3s playbooks pass syntax check, templates render correctly |
| 3 | All Kubernetes manifests pass dry-run validation |
| 4 | Velero configs valid, DR scripts executable with help |
| 5 | `tofu init && tofu validate` succeeds |
| 6 | All docs render correctly in markdown viewer |

---

## Implementation Order

```
Phase 1 (Foundation)
├── 1.1 Directory Structure ─────────────────────┐
├── 1.2 Ansible Base ────────────────────────────┤
├── 1.3 Role: common ────────────────────────────┤ Can be done in parallel
├── 1.4 Role: firewall ──────────────────────────┤
├── 1.5 Role: tailscale ─────────────────────────┤
└── 1.6 Bootstrap Playbook ──────────────────────┘ (depends on 1.2-1.5)

Phase 2 (K3s)
├── 2.1 Role: k3s-prereq ────────────────────────┐
├── 2.2 Role: k3s-server ────────────────────────┤ Sequential
├── 2.3 Role: k3s-agent ─────────────────────────┤
└── 2.4 K3s Playbooks ───────────────────────────┘

Phase 3 (GitOps) ─── Can start after Phase 1
├── 3.1 Bootstrap Structure ─────────────────────┐
├── 3.2 Infrastructure Apps ─────────────────────┤ Parallel
└── 3.3 App Template ────────────────────────────┘

Phase 4 (Backup & DR) ─── Can start after Phase 1
├── 4.1 Velero Config ───────────────────────────┐
├── 4.2 Role: node-agent ────────────────────────┤ Parallel
└── 4.3 DR Scripts ──────────────────────────────┘

Phase 5 (DNS/Tofu) ─── Can start after Phase 1
├── 5.1 Tofu Base ───────────────────────────────┐
├── 5.2 DNS Module ──────────────────────────────┤ Sequential
├── 5.3 R2 Module ───────────────────────────────┤
└── 5.4 DNS Config ──────────────────────────────┘

Phase 6 (Docs) ─── Can start anytime
└── 6.1 Runbooks ────────────────────────────────
```

---

## Task Summary

| Phase | Tasks | Files |
|-------|-------|-------|
| 1. Foundation | 6 | ~15 |
| 2. K3s Cluster | 4 | ~20 |
| 3. GitOps | 3 | ~15 |
| 4. Backup & DR | 3 | ~15 |
| 5. DNS/Tofu | 4 | ~12 |
| 6. Documentation | 1 | ~8 |
| **Total** | **21** | **~85** |

---

## Notes

- All Ansible roles support both Debian/Ubuntu and RHEL/CentOS
- Secrets are never committed - use vault.yml for Ansible, SOPS for K8s
- Tailscale IPs are discovered dynamically, not hardcoded
- R2 chosen for backups due to zero egress fees
- Code-only implementation with syntax validation (no live VPS testing)
