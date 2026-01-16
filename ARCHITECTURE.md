# Multi-Cloud K3s Infrastructure

## Overview

Managing multiple VPS servers across cloud platforms with:
- k3s cluster management
- Tailscale networking (ZeroTier-ready)
- Ansible automation
- GitOps deployment (ArgoCD)
- OpenTofu for DNS (Cloudflare) and infrastructure
- Velero backup to Cloudflare R2 (S3-compatible, portable)
- Local PVC with disaster recovery

## Directory Structure

```
infra-k3s/
├── README.md
├── .gitignore
├── .envrc                          # direnv for local environment variables
├── .sops.yaml                      # SOPS config for secrets encryption
│
├── ansible/                        # Ansible automation
│   ├── ansible.cfg
│   ├── inventory/
│   │   ├── hosts.yml               # Main inventory with groups
│   │   ├── host_vars/              # Per-host variables (auto-generated)
│   │   └── group_vars/
│   │       ├── all.yml             # Global variables
│   │       ├── all/
│   │       │   └── vault.yml       # Encrypted secrets
│   │       ├── k3s_masters.yml     # Master node config
│   │       └── k3s_workers.yml     # Worker node config
│   ├── playbooks/
│   │   ├── site.yml                # Main entry point
│   │   ├── bootstrap.yml           # Initial VPS setup (users, ssh, firewall)
│   │   ├── k3s-cluster.yml         # Full k3s cluster setup
│   │   ├── k3s-master.yml          # Master node setup
│   │   ├── k3s-worker.yml          # Worker node join
│   │   ├── k3s-uninstall.yml       # Clean uninstall
│   │   ├── networking.yml          # Tailscale/ZeroTier
│   │   ├── upgrade.yml             # K3s upgrades
│   │   └── maintenance.yml         # Updates, cleanup
│   └── roles/
│       ├── common/                 # Base system (packages, users, ssh)
│       ├── firewall/               # UFW/iptables rules
│       ├── k3s-prereq/             # K3s prerequisites
│       ├── k3s-server/             # K3s server (master)
│       ├── k3s-agent/              # K3s agent (worker)
│       ├── tailscale/              # Tailscale VPN
│       ├── zerotier/               # ZeroTier (future)
│       └── node-agent/             # Velero node agent for PVC backup
│
├── tofu/                           # OpenTofu infrastructure
│   ├── modules/
│   │   ├── cloudflare-dns/         # Cloudflare DNS records
│   │   └── r2-bucket/              # R2 bucket for backups
│   ├── main.tf                     # Main configuration
│   ├── dns.tf                      # DNS records
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── backend.tf                  # State backend (R2 or other)
│
├── kubernetes/                     # K8s manifests (GitOps source)
│   ├── bootstrap/                  # Initial cluster setup
│   │   ├── argocd/
│   │   │   ├── install.yaml        # ArgoCD installation
│   │   │   ├── projects/           # ArgoCD projects
│   │   │   └── apps/               # App of Apps pattern
│   │   │       ├── infrastructure.yaml
│   │   │       └── apps.yaml
│   │   └── namespaces.yaml
│   ├── infrastructure/             # Cluster-wide infrastructure
│   │   ├── cert-manager/
│   │   ├── ingress-nginx/
│   │   ├── velero/
│   │   ├── external-dns/           # Auto DNS via Cloudflare
│   │   └── sealed-secrets/
│   └── apps/                       # Application deployments
│       └── _template/              # App template
│
├── scripts/                        # Utility scripts
│   ├── setup/
│   │   ├── init-cluster.sh         # Initialize new cluster
│   │   └── join-node.sh            # Join node to cluster
│   ├── backup/
│   │   ├── create-backup.sh        # Manual Velero backup
│   │   ├── list-backups.sh
│   │   └── restore-backup.sh
│   └── dr/                         # Disaster recovery
│       ├── failover.sh             # Automated failover
│       ├── restore-workload.sh     # Restore specific workload
│       └── node-recovery.sh        # Recover failed node
│
├── docs/
│   ├── architecture.md             # System architecture
│   ├── networking.md               # Tailscale setup details
│   ├── disaster-recovery.md        # DR procedures
│   └── runbooks/
│       ├── add-node.md
│       ├── remove-node.md
│       ├── upgrade-k3s.md
│       └── restore-service.md
│
└── config/                         # Shared configurations
    ├── velero/
    │   ├── backup-locations.yaml   # S3/R2 config
    │   └── schedules/
    │       ├── daily.yaml
    │       └── hourly-critical.yaml
    └── argocd/
        └── repositories.yaml       # Git repo configs
```

## Environment Variables Management

### Strategy Overview

| Type | Tool | Storage | Use Case |
|------|------|---------|----------|
| Local dev secrets | direnv + .envrc | `.envrc` (gitignored) | API keys for local tofu/ansible |
| Ansible secrets | Ansible Vault | `group_vars/all/vault.yml` | SSH passwords, Tailscale authkey |
| K8s secrets | SOPS + age | Encrypted in git | App secrets, DB passwords |
| Tofu secrets | Environment vars | `.envrc` or CI secrets | Cloudflare API token |

### 1. Local Development (direnv)

```bash
# .envrc (gitignored)
export CLOUDFLARE_API_TOKEN="xxx"
export CLOUDFLARE_ZONE_ID="xxx"
export AWS_ACCESS_KEY_ID="xxx"        # For R2
export AWS_SECRET_ACCESS_KEY="xxx"
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible-vault-pass
```

```bash
# .envrc.example (committed to git)
export CLOUDFLARE_API_TOKEN=""
export CLOUDFLARE_ZONE_ID=""
export AWS_ACCESS_KEY_ID=""
export AWS_SECRET_ACCESS_KEY=""
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible-vault-pass
```

### 2. Ansible Secrets (Ansible Vault)

```yaml
# ansible/inventory/group_vars/all/vault.yml (encrypted)
vault_tailscale_authkey: "tskey-auth-xxx"
vault_vultr_password: "xxx"
vault_k3s_token: "xxx"
```

```bash
# Encrypt/decrypt
ansible-vault encrypt ansible/inventory/group_vars/all/vault.yml
ansible-vault edit ansible/inventory/group_vars/all/vault.yml

# Reference in playbooks
tailscale_authkey: "{{ vault_tailscale_authkey }}"
```

### 3. Kubernetes Secrets (SOPS + age)

```yaml
# .sops.yaml
creation_rules:
  - path_regex: kubernetes/.*\.yaml$
    encrypted_regex: ^(data|stringData)$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

```yaml
# kubernetes/apps/myapp/secret.yaml (encrypted in git)
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secret
type: Opaque
stringData:
  DATABASE_URL: ENC[AES256_GCM,data:xxx,tag:xxx]
```

```bash
# Encrypt/decrypt
sops -e -i kubernetes/apps/myapp/secret.yaml
sops -d kubernetes/apps/myapp/secret.yaml

# ArgoCD decrypts automatically with KSOPS plugin
```

### 4. OpenTofu Variables

```hcl
# tofu/variables.tf
variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_zone_id" {
  type = string
}
```

```hcl
# tofu/terraform.tfvars (gitignored for sensitive values)
cloudflare_zone_id = "xxx"
# cloudflare_api_token comes from environment variable
```

```bash
# Tofu reads TF_VAR_* from environment
export TF_VAR_cloudflare_api_token="$CLOUDFLARE_API_TOKEN"
tofu plan
```

### Setup Commands

```bash
# 1. Install tools
brew install direnv sops age ansible

# 2. Setup direnv for your shell(s)
# For zsh (~/.zshrc)
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc

# For fish (~/.config/fish/config.fish)
echo 'direnv hook fish | source' >> ~/.config/fish/config.fish

# 3. Generate age key for SOPS
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

# 4. Setup project
cp .envrc.example .envrc
direnv allow

# 5. Create Ansible vault password file
echo "your-vault-password" > ~/.ansible-vault-pass
chmod 600 ~/.ansible-vault-pass

# 6. Initialize Ansible vault
ansible-vault create ansible/inventory/group_vars/all/vault.yml
```

## Ansible Inventory

The inventory uses public IPs for initial bootstrap. After Tailscale is installed, the playbook automatically discovers and uses Tailscale IPs.

### hosts.yml

```yaml
all:
  children:
    k3s_masters:
      hosts:
        vps-hetzner-1:
          public_ip: "1.2.3.4"
          ansible_user: root
          ansible_ssh_private_key_file: ~/.ssh/id_ed25519

    k3s_workers:
      hosts:
        vps-vultr-1:
          public_ip: "5.6.7.8"
          ansible_user: ubuntu
          ansible_ssh_pass: "{{ vault_vultr_password }}"
        vps-aws-1:
          public_ip: "9.10.11.12"
          ansible_user: ec2-user
          ansible_ssh_private_key_file: ~/.ssh/aws-key.pem
```

### Dynamic Tailscale IP Resolution

Tailscale is automatically installed during bootstrap. After installation, all connections use Tailscale IP.

```yaml
# ansible/inventory/group_vars/all.yml
# Connection logic: use Tailscale if installed, otherwise public IP
ansible_host: "{{ tailscale_ip | default(public_ip) }}"

# Tailscale auth key (from Tailscale admin console)
tailscale_authkey: "{{ vault_tailscale_authkey }}"
```

```yaml
# ansible/roles/tailscale/tasks/main.yml
---
- name: Install Tailscale (Debian/Ubuntu)
  when: ansible_os_family == "Debian"
  block:
    - name: Add Tailscale GPG key
      apt_key:
        url: https://pkgs.tailscale.com/stable/{{ ansible_distribution | lower }}/{{ ansible_distribution_release }}.noarmor.gpg
        state: present

    - name: Add Tailscale repository
      apt_repository:
        repo: "deb https://pkgs.tailscale.com/stable/{{ ansible_distribution | lower }} {{ ansible_distribution_release }} main"
        state: present

    - name: Install Tailscale
      apt:
        name: tailscale
        state: present
        update_cache: yes

- name: Install Tailscale (RHEL/CentOS)
  when: ansible_os_family == "RedHat"
  block:
    - name: Add Tailscale repository
      yum_repository:
        name: tailscale-stable
        description: Tailscale stable
        baseurl: https://pkgs.tailscale.com/stable/centos/$releasever/$basearch
        gpgcheck: yes
        gpgkey: https://pkgs.tailscale.com/stable/centos/$releasever/repo.gpg

    - name: Install Tailscale
      yum:
        name: tailscale
        state: present

- name: Enable and start Tailscale service
  systemd:
    name: tailscaled
    enabled: yes
    state: started

- name: Authenticate Tailscale
  command: tailscale up --authkey={{ tailscale_authkey }} --ssh
  args:
    creates: /var/lib/tailscale/tailscaled.state
  register: tailscale_up_result

- name: Get Tailscale IP
  command: tailscale ip -4
  register: tailscale_ip_result
  changed_when: false

- name: Set tailscale_ip fact for subsequent tasks
  set_fact:
    tailscale_ip: "{{ tailscale_ip_result.stdout }}"
```

```yaml
# ansible/roles/common/tasks/gather_facts.yml
# Included at the start of every playbook to determine connection method

- name: Check if Tailscale is installed
  command: which tailscale
  register: tailscale_installed
  ignore_errors: true
  changed_when: false

- name: Get Tailscale IP (if installed)
  command: tailscale ip -4
  register: tailscale_ip_result
  when: tailscale_installed.rc == 0
  changed_when: false

- name: Set tailscale_ip fact
  set_fact:
    tailscale_ip: "{{ tailscale_ip_result.stdout }}"
  when: tailscale_installed.rc == 0 and tailscale_ip_result.stdout | length > 0
```

### Bootstrap Flow

1. Configure `public_ip`, `ansible_user`, and SSH auth per host in `hosts.yml`
2. Set `tailscale_authkey` in vault (get from Tailscale admin console)
3. Run `ansible-playbook playbooks/bootstrap.yml` (connects via public IP)
   - Installs system packages
   - Automatically installs and configures Tailscale
   - Authenticates with your Tailscale network
4. All subsequent playbooks automatically:
   - Detect Tailscale is installed
   - Fetch current Tailscale IP at runtime
   - Connect via Tailscale network

## Disaster Recovery Design

### Challenge

Local PVCs are node-bound. When a VPS fails, data on that node is inaccessible.

### Solution: Velero + Cloudflare R2

```
┌─────────────────────────────────────────────────────────────┐
│                    Disaster Recovery Flow                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Normal Operation:                                           │
│  ┌─────────┐    Velero+Kopia   ┌──────────────────┐         │
│  │  VPS A  │ ─────────────────▶│  Cloudflare R2   │         │
│  │ (PVC)   │   scheduled       │  (S3-compatible) │         │
│  └─────────┘   backup          └──────────────────┘         │
│                                                              │
│  Node Failure & Recovery:                                    │
│  ┌─────────┐                   ┌──────────────────┐         │
│  │  VPS A  │ ✗ DOWN            │  Cloudflare R2   │         │
│  └─────────┘                   └────────┬─────────┘         │
│       │                                 │                    │
│       │ 1. Detect failure               │ 2. Restore        │
│       │ 2. Cordon node                  │    backup         │
│       │ 3. Delete stuck pods            ▼                    │
│       │                        ┌─────────────┐              │
│       └───────────────────────▶│    VPS B    │              │
│         4. Reschedule          │ (new PVC)   │              │
│                                └─────────────┘              │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

1. **Velero with Kopia** (replaces Restic)
   - File-level backup of PVC data
   - Incremental backups to R2
   - Encryption at rest

2. **Node Affinity Labels**
   ```yaml
   topology.kubernetes.io/zone: hetzner-fsn1
   node.kubernetes.io/instance-type: cx21
   workload/stateful: "true"
   ```

3. **Backup Schedules per Criticality**
   - Critical apps: hourly backups, 7-day retention
   - Standard apps: daily backups, 30-day retention
   - Stateless apps: config-only backup

4. **Recovery Automation** (`scripts/dr/failover.sh`)
   - Health check detects node failure
   - Cordons failed node
   - Identifies affected PVCs and their backups
   - Creates restore on target node
   - Updates DNS via OpenTofu if needed

### Recovery Procedure

```bash
# Manual failover (or automated via monitoring)
./scripts/dr/failover.sh --source-node vps-aws-1 --target-node vps-vultr-1

# Or restore specific workload
./scripts/dr/restore-workload.sh --app myapp --backup latest --target-node vps-vultr-1
```

### Considerations

- **RPO (Recovery Point Objective)**: Depends on backup frequency (hourly = max 1hr data loss)
- **RTO (Recovery Time Objective)**: ~5-15 min depending on data size
- **Storage Cost**: R2 has no egress fees, good for frequent restores
- **Future Enhancement**: Consider Longhorn for real-time replication if RPO=0 needed

## Implementation Phases

1. **Phase 1: Foundation**
   - Create directory structure
   - Setup Ansible roles (common, firewall, tailscale)
   - Bootstrap first VPS

2. **Phase 2: K3s Cluster**
   - K3s server/agent roles
   - Cluster initialization

3. **Phase 3: GitOps**
   - ArgoCD installation
   - App of Apps pattern
   - Infrastructure apps (cert-manager, ingress)

4. **Phase 4: Backup & DR**
   - Velero + R2 setup
   - Backup schedules
   - DR scripts and runbooks

5. **Phase 5: DNS & Infra**
   - OpenTofu Cloudflare module
   - External-DNS integration
   - Automated DNS management
