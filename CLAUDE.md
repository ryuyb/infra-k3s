# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multi-cloud K3s infrastructure managing VPS servers across providers (Hetzner, Vultr, AWS) with Tailscale networking, GitOps (ArgoCD + Helm), and disaster recovery via Velero to Cloudflare R2.

## Commands

### Ansible
```bash
# Bootstrap VPS (initial setup via public IP)
ansible-playbook ansible/playbooks/bootstrap.yml

# Deploy K3s cluster (master + workers)
# IMPORTANT: Always use k3s-cluster.yml to deploy/update workers
# Do NOT use k3s-worker.yml directly as it requires variables from k3s-server role
ansible-playbook ansible/playbooks/k3s-cluster.yml

# Deploy ArgoCD via Helm and GitOps (after K3s is running)
# Automatically creates cluster secrets (Velero R2, Cloudflare API token)
# Requires environment variables: R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, VELERO_BUCKET, R2_ENDPOINT, CLOUDFLARE_API_TOKEN
ansible-playbook ansible/playbooks/deploy-argocd.yml

# Setup cluster secrets from environment variables (standalone, if needed)
ansible-playbook ansible/playbooks/setup-secrets.yml

# Upgrade K3s (rolling, one node at a time)
ansible-playbook ansible/playbooks/upgrade.yml

# System maintenance
ansible-playbook ansible/playbooks/maintenance.yml

# Edit encrypted secrets
ansible-vault edit ansible/inventory/group_vars/all/vault.yml

# One-command cluster initialization (bootstrap + K3s + ArgoCD)
./scripts/setup/init-cluster.sh --with-argocd
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

# Execute kubectl commands on master node via Ansible (from ansible/ directory)
cd ansible

# Check cluster nodes
ansible 'k3s_masters[0]' -m shell -a "kubectl get nodes" \
  -e "ansible_shell_executable=/bin/bash" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"

# Check ArgoCD Applications
ansible 'k3s_masters[0]' -m shell -a "kubectl get applications -n argocd" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"

# View all pods
ansible 'k3s_masters[0]' -m shell -a "kubectl get pods -A" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"

# Sync ArgoCD Application
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl annotate application infrastructure -n argocd argocd.argoproj.io/refresh=hard --overwrite" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"

# Describe ArgoCD Application
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl describe application infrastructure -n argocd" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
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

## Storage and Node Affinity

### Local Storage Constraints

This cluster uses **local-path** storage (no distributed storage like Longhorn or Ceph). Services with persistent volumes must be pinned to specific nodes.

### Adding Stateful Services

When deploying services that require data persistence:

1. **Ask the user** which node (or node label) to pin the service to
2. Add scheduling configuration to the service:
   - **Hostname-based**: `nodeSelector: {kubernetes.io/hostname: <node-name>}`
   - **Label-based**: `nodeSelector: {<label-key>: <label-value>}`
   - **Advanced**: Use `affinity.nodeAffinity` for complex rules
3. **Update docs/stateful-services.md** with:
   - Service name and namespace
   - Storage type and size
   - Scheduling method and configuration
   - Pinned node(s) or label(s)
   - Reason for persistence

### Current Pinned Services

See [docs/stateful-services.md](docs/stateful-services.md) for the complete list of services and scheduling configurations.

## Adding New Kubernetes Secrets

When adding new services that require secrets (passwords, API tokens, etc.), follow this workflow to ensure secrets are properly managed through environment variables and Ansible automation.

### Step 1: Add Environment Variables

Add the required environment variables to three files:

**1. `.envrc`** - Default values and variable definitions
```bash
# Service Name
export SERVICE_SECRET="${SERVICE_SECRET:-default_value}"
```

**2. `.envrc.example`** - Example configuration for documentation
```bash
# Service Name
export SERVICE_SECRET="example_value"
```

**3. `.envrc.local`** - Actual values (gitignored, user-specific)
```bash
# Service Name
export SERVICE_SECRET="actual_secret_value"
```

### Step 2: Update setup-secrets.yml

Add secret creation tasks to `ansible/playbooks/setup-secrets.yml`:

**2.1 Add namespace variable** (if new namespace needed):
```yaml
vars:
  service_namespace: service-name
```

**2.2 Add environment variable validation**:
```yaml
- name: Check required environment variables
  ansible.builtin.assert:
    that:
      - lookup('env', 'SERVICE_SECRET') != ''
    fail_msg: "Missing SERVICE_SECRET in .envrc.local"
```

**2.3 Create namespace** (if needed):
```yaml
- name: Create service namespace
  kubernetes.core.k8s:
    name: "{{ service_namespace }}"
    api_version: v1
    kind: Namespace
    state: present
  environment:
    KUBECONFIG: /etc/rancher/k3s/k3s.yaml
```

**2.4 Create secret**:
```yaml
- name: Create service secret
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: v1
      kind: Secret
      metadata:
        name: service-secret
        namespace: "{{ service_namespace }}"
      type: Opaque
      stringData:
        secret-key: "{{ lookup('env', 'SERVICE_SECRET') }}"
  environment:
    KUBECONFIG: /etc/rancher/k3s/k3s.yaml
  no_log: true  # Prevent secrets from appearing in logs
```

**2.5 Verify secret creation**:
```yaml
- name: Verify service secret creation
  kubernetes.core.k8s_info:
    api_version: v1
    kind: Secret
    name: service-secret
    namespace: "{{ service_namespace }}"
  environment:
    KUBECONFIG: /etc/rancher/k3s/k3s.yaml
  register: service_secret_info

- name: Display service secret status
  ansible.builtin.debug:
    msg: "Service secret created successfully"
  when: service_secret_info.resources | length > 0
```

**2.6 Update summary**:
```yaml
- name: Display summary
  ansible.builtin.debug:
    msg:
      - "Service: service-secret in {{ service_namespace }}"
```

### Step 3: Update Helm Templates

Configure the service to use the secret:

**For Helm charts** (`helm/apps/templates/service.yaml` or `helm/infrastructure/templates/service.yaml`):
```yaml
auth:
  existingSecret: service-secret
  secretKeys:
    passwordKey: secret-key
```

**For direct Kubernetes resources**:
```yaml
env:
  - name: SERVICE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: service-secret
        key: secret-key
```

### Step 4: Test and Verify

```bash
# 1. Load environment variables
direnv allow

# 2. Run setup-secrets playbook
ansible-playbook ansible/playbooks/setup-secrets.yml

# 3. Verify secret creation
cd ansible
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl get secret service-secret -n service-namespace -o yaml" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"

# 4. Verify service is using the secret
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl get pods -n service-namespace" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
```

### Example: PostgreSQL Secret

See the PostgreSQL configuration as a reference implementation:

- **Environment variables**: `.envrc`, `.envrc.example`, `.envrc.local`
  ```bash
  export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
  ```

- **Secret creation**: `ansible/playbooks/setup-secrets.yml`
  ```yaml
  - name: Create PostgreSQL credentials secret
    kubernetes.core.k8s:
      state: present
      definition:
        apiVersion: v1
        kind: Secret
        metadata:
          name: postgresql
          namespace: database
        type: Opaque
        stringData:
          postgres-password: "{{ lookup('env', 'POSTGRES_PASSWORD') }}"
      environment:
        KUBECONFIG: /etc/rancher/k3s/k3s.yaml
      no_log: true
  ```

- **Helm configuration**: `helm/apps/templates/postgresql.yaml`
  ```yaml
  auth:
    enablePostgresUser: true
    existingSecret: postgresql
    secretKeys:
      adminPasswordKey: postgres-password
  ```

### Best Practices

1. **Never commit secrets to Git**: Use `.envrc.local` (gitignored) for actual values
2. **Use `no_log: true`**: Prevent secrets from appearing in Ansible logs
3. **Validate environment variables**: Add assertions in `setup-secrets.yml`
4. **Use descriptive secret keys**: Name keys clearly (e.g., `postgres-password`, not just `password`)
5. **Document in CLAUDE.md**: Update this file when adding new secrets
6. **Update .envrc.example**: Provide clear examples for other developers

## Troubleshooting

### Worker Nodes Not Joining Cluster

**Symptom**: All pods running on master node, worker nodes not visible in `kubectl get nodes`

**Common Causes**:
1. **k3s-agent service failing**: Check service status with `ansible k3s_workers -m shell -a "systemctl status k3s-agent"`
2. **Missing variables**: Running `k3s-worker.yml` directly fails because `k3s_server_url` and `k3s_token` are set by k3s-server role

**Solution**: Always use `k3s-cluster.yml` to deploy or update worker nodes:
```bash
ansible-playbook ansible/playbooks/k3s-cluster.yml
```

**Verification**:
```bash
# Check all nodes are Ready
kubectl get nodes

# Check pod distribution across nodes
kubectl get pods -A -o wide
```
