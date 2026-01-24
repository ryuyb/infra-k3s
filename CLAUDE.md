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
# Velero R2 credentials and Cloudflare API token are SOPS-managed
# Requires environment variables: VELERO_BUCKET, R2_ENDPOINT
ansible-playbook ansible/playbooks/deploy-argocd.yml

# Deploy ArgoCD with OIDC authentication
# Set ARGOCD_OIDC_ENABLED=true and configure OIDC credentials in .envrc.local
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

## ArgoCD OIDC Configuration

### Overview

ArgoCD supports OIDC authentication via ZITADEL (or other OIDC providers). When enabled, users can log in using their ZITADEL credentials instead of the default admin password.

### Configuration

**1. Enable OIDC in environment variables:**

Set `ARGOCD_OIDC_ENABLED=true` in your `.envrc.local` file:

```bash
# ArgoCD OIDC Configuration
export ARGOCD_OIDC_ENABLED="true"
export ARGOCD_OIDC_ISSUER_URL="https://zitadel.your-domain.com"
export ARGOCD_OIDC_CLIENT_ID="227060711795262483@argocd-project"
export ARGOCD_OIDC_CLIENT_SECRET="your-client-secret"
export ARGOCD_OIDC_LOGOUT_URL="https://zitadel.your-domain.com/oidc/v1/end_session"
```

**2. Deploy ArgoCD:**

```bash
direnv allow
ansible-playbook ansible/playbooks/deploy-argocd.yml
```

### RBAC Configuration

The ArgoCD RBAC configuration is defined in `ansible/roles/argocd/templates/argocd-values.yaml.j2`:

```yaml
configs:
  rbac:
    policy.csv: |
      g, argocd_administrators, role:admin
      g, argocd_users, role:readonly
    policy.default: ''
    scopes: '[groups]'
```

**RBAC Groups:**
- `argocd_administrators`: Full admin access (role:admin)
- `argocd_users`: Read-only access (role:readonly)

**Scopes:**
- `scopes: '[groups]'` - Maps OIDC groups to ArgoCD RBAC groups

### ZITADEL Client Setup

To create an OIDC client in ZITADEL:

1. **Access ZITADEL Console:**
   ```bash
   # Port-forward to access ZITADEL
   kubectl port-forward svc/zitadel -n apps 8080:8080
   # Access at http://localhost:8080
   ```

2. **Create OIDC Application:**
   - Go to Projects → Your Project → Applications
   - Click "Create Application"
   - Select "OIDC Web Application"
   - Configure:
     - **Application Name**: `argocd`
     - **Redirect URIs**: `https://argocd.your-domain.com/auth/callback`
     - **Post Logout Redirect URIs**: `https://argocd.your-domain.com`
     - **Token Response Type**: Code
     - **Grant Types**: Authorization Code, Refresh Token
     - **Code Method**: PKCE (recommended)
     - **Auth Method**: Basic (Client Secret)

3. **Get Credentials:**
   - Copy the **Client ID** and **Client Secret**
   - Note the **Issuer URL** (usually `https://zitadel.your-domain.com`)

### Verification

After deployment, verify OIDC is working:

```bash
# Check ArgoCD ConfigMap
kubectl get cm argocd-cm -n argocd -o yaml

# Check ArgoCD RBAC ConfigMap
kubectl get cm argocd-rbac-cm -n argocd -o yaml

# Test OIDC login
# Access ArgoCD UI via Tailscale: https://argocd
# Click "LOG IN VIA OIDC" button
```

### Troubleshooting

**OIDC login button not appearing:**
- Verify `ARGOCD_OIDC_ENABLED=true` is set
- Check ArgoCD ConfigMap: `kubectl get cm argocd-cm -n argocd -o yaml`
- Ensure OIDC client is properly configured in ZITADEL

**OIDC authentication fails:**
- Verify `issuer` URL is correct
- Check client ID and secret match ZITADEL configuration
- Ensure redirect URI matches exactly: `https://argocd.your-domain.com/auth/callback`
- Check ZITADEL logs: `kubectl logs -n apps -l app=zitadel`

**RBAC groups not working:**
- Verify OIDC groups are included in the token
- Check `scopes: '[groups]'` is configured
- Verify group names match `argocd_administrators` or `argocd_users`

## Architecture

### Directory Layout
- `ansible/` - Server provisioning: playbooks orchestrate roles for bootstrap, k3s setup, networking
- `tofu/` - OpenTofu modules for Cloudflare DNS and R2 backup buckets
- `helm/` - Helm charts: `infrastructure/` (App of Apps for infrastructure components), `apps/` (application deployments)
- `kubernetes/` - Legacy kustomize manifests (being migrated to Helm)
- `scripts/` - Utilities for setup, backup, and disaster recovery
- `config/` - Shared Velero schedules and ArgoCD repo configs

### Key Patterns

**Ansible inventory**: Uses `ansible_host`/`ansible_user` per node for SSH, sourced from vaulted maps (`vault_ansible_hosts`, `vault_ansible_users`). Set them to reachable IP/hostname (often public IP during bootstrap), then update to the Tailscale IP if desired.

**Tailscale VPN integration**: K3s uses official Tailscale VPN integration (requires K3s v1.27.3+) with `vpn-auth` and `node-external-ip` parameters. This enables:
- Automatic Tailscale node registration during K3s installation
- Secure cross-cloud node communication via Tailscale mesh network
- Automatic subnet route approval for pod CIDR (10.42.0.0/16)
- No manual flannel interface configuration needed

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

**Optional components**: Some infrastructure components can be enabled/disabled via `helm/infrastructure/values.yaml`:
- Rancher: Set `rancher.enabled: true` to deploy Rancher management UI
  - Requires `RANCHER_PASSWORD` environment variable
  - Access via `https://rancher.{{ domain }}`
  - Default: disabled

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

## Tailscale Kubernetes Operator

### Overview

Tailscale Kubernetes Operator 允许将 Kubernetes 服务安全地暴露到 Tailscale 网络，无需公网暴露。通过创建 Ingress 资源，Operator 自动创建 Tailscale 代理设备，并通过 MagicDNS 提供 HTTPS 访问。

### 架构说明

**认证方式**：
- **K3s 节点**：使用 Auth Key 进行 Tailscale VPN 集成（`vpn-auth` 参数）
- **Operator**：使用 OAuth Client 创建独立的 Ingress 代理设备
- 两者互不干扰，各自管理不同的设备类型

**权限配置**：
- OAuth Client 权限：`Devices: Core`, `Auth Keys: Write`, `Services: Write`
- OAuth Client Tag：`tag:k8s-operator`
- Ingress 代理设备 Tag：`tag:k8s`（由 Operator 自动分配）

**部署方式**：
- Namespace：`tailscale`
- 部署：Helm Chart + ArgoCD（App of Apps 模式）
- Sync Wave：`1`（在基础组件之后部署）

### 已暴露服务

| 服务 | Namespace | Tailscale 域名 | 公网访问 |
|------|-----------|----------------|----------|
| pgAdmin4 | database | `pgadmin.<tailnet>.ts.net` | 保留（可选删除） |

### 常用命令

```bash
# 查看 Operator 状态
cd ansible
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl get pods -n tailscale" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"

# 查看 Operator 日志
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl logs -n tailscale -l app=tailscale-operator --tail=50" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"

# 查看所有 Tailscale Ingress
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl get ingress -A -o wide | grep tailscale" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"

# 查看特定 Ingress 详情
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl describe ingress pgadmin4-tailscale -n database" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"

# 查看 Tailscale 代理 Pod
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl get pods -n tailscale -l app!=tailscale-operator" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
```

### 添加新服务到 Tailscale 网络

**步骤**：

1. **在服务的 Helm 模板中添加 Tailscale Ingress**：

```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: <service>-tailscale
  namespace: <namespace>
  annotations:
    argocd.argoproj.io/sync-wave: "4"
spec:
  ingressClassName: tailscale
  tls:
    - hosts:
        - <hostname>  # MagicDNS 会生成 <hostname>.<tailnet>.ts.net
  defaultBackend:
    service:
      name: <service>
      port:
        number: <port>
```

2. **提交并推送到 Git**：

```bash
git add helm/apps/templates/<service>.yaml
git commit -m "feat(tailscale): expose <service> to Tailscale network"
git push
```

3. **触发 ArgoCD 同步**：

```bash
cd ansible
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl annotate application apps -n argocd argocd.argoproj.io/refresh=hard --overwrite" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
```

4. **验证 Ingress 创建**：

```bash
# 等待 Ingress 分配 IP
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl get ingress <service>-tailscale -n <namespace>" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"

# 查看 Tailscale 代理 Pod
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl get pods -n tailscale -l app=<service>" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
```

5. **访问服务**：
   - 确保本地设备已连接到 Tailscale 网络
   - 在 Tailscale Admin Console 查看新创建的设备（名称类似 `<namespace>-<service>`）
   - 访问 `https://<hostname>.<tailnet>.ts.net`

**候选服务**：
- Grafana（监控面板）
- ArgoCD（GitOps 管理）
- Kubernetes Dashboard

### 故障排查

#### Ingress 未分配 IP

**症状**：`kubectl get ingress` 显示 ADDRESS 为空

**排查步骤**：

1. **检查 Operator 是否运行**：
```bash
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl get pods -n tailscale -l app=tailscale-operator" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
```

2. **查看 Operator 日志**：
```bash
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl logs -n tailscale -l app=tailscale-operator --tail=100" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
```

3. **检查 Ingress 事件**：
```bash
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl describe ingress <service>-tailscale -n <namespace>" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
```

#### OAuth 权限不足

**症状**：Operator 日志显示权限错误

**解决方案**：

1. 访问 [Tailscale Admin Console](https://login.tailscale.com/admin/settings/oauth)
2. 检查 OAuth Client 权限是否包含：
   - ✅ Devices: Core
   - ✅ Auth Keys: Write
   - ✅ Services: Write
3. 检查 OAuth Client 是否分配了 `tag:k8s-operator`
4. 检查 Tailscale ACL 中是否配置了 tagOwners：
```json
"tagOwners": {
  "tag:k8s-operator": [],
  "tag:k8s": ["tag:k8s-operator"]
}
```
5. 如果配置不正确，重新生成 OAuth Client
6. 更新 Ansible Vault：
```bash
ansible-vault edit ansible/inventory/group_vars/all/vault.yml
```
7. 重新创建 Secret：
```bash
ansible-playbook ansible/playbooks/setup-secrets-tailscale.yml
```
8. 重启 Operator：
```bash
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl rollout restart deployment/tailscale-operator -n tailscale" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
```

#### MagicDNS 未启用

**症状**：Ingress 创建后无法解析域名

**解决方案**：

1. 访问 [Tailscale Admin Console](https://login.tailscale.com/admin/dns) → DNS
2. 启用 MagicDNS
3. 确认 HTTPS 已启用
4. 等待 DNS 传播（通常几秒钟）

#### 代理 Pod 无法启动

**症状**：Tailscale 代理 Pod 处于 CrashLoopBackOff 状态

**排查步骤**：

1. **查看 Pod 日志**：
```bash
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl logs -n tailscale <pod-name>" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
```

2. **检查 Secret 是否存在**：
```bash
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl get secret operator-oauth -n tailscale" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
```

3. **验证 Secret 内容**：
```bash
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl get secret operator-oauth -n tailscale -o jsonpath='{.data.client_id}' | base64 -d" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
```

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

## Managing Application Database Credentials

### Overview

Application database credentials are automatically provisioned through Ansible playbook `setup-secrets-database.yml`. This creates:
- Dedicated PostgreSQL database per application
- Dedicated user with minimal privileges (access only to its database)
- Kubernetes Secret in application namespace

### Adding New Application Database

1. **Update `helm/apps/values.yaml`:**
   ```yaml
   appDatabases:
     - name: myapp
       database: myapp_db
       username: myapp_user
       # namespace is automatically extracted from helm/apps/templates/myapp.yaml
   ```

2. **Ensure ArgoCD Application definition exists:**
   ```yaml
   # helm/apps/templates/myapp.yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: myapp
   spec:
     destination:
       namespace: apps  # This value will be automatically extracted
   ```

3. **Generate passwords and update Ansible Vault:**
   ```bash
   ./scripts/db/generate-passwords.sh
   ```

4. **Run setup playbook:**
   ```bash
   ansible-playbook ansible/playbooks/setup-secrets-database.yml
   ```

5. **Reference Secret in Helm chart:**
   ```yaml
   env:
     - name: DATABASE_URL
       valueFrom:
         secretKeyRef:
           name: myapp-db
           key: connection-string
   ```

### Secret Structure

Each application database Secret contains:
- `host`: PostgreSQL service FQDN
- `port`: PostgreSQL port (5432)
- `database`: Database name
- `username`: Database user
- `password`: User password
- `connection-string`: Full PostgreSQL connection URL

### Password Management

Passwords are:
- Automatically generated (32-character strong random passwords)
- Encrypted in Ansible Vault (`ansible/inventory/group_vars/all/vault.yml`)
- Idempotent (re-running script preserves existing passwords)
- Shared across team via Vault encryption key

### Verification

```bash
# Verify database creation
cd ansible
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl exec -n database postgresql-postgresql-0 -- psql -U postgres -c '\l'" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"

# Verify user privileges
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl exec -n database postgresql-postgresql-0 -- psql -U postgres -c '\du'" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"

# Verify Secret creation
ansible 'k3s_masters[0]' -m shell -a \
  "kubectl get secrets -n apps | grep '\-db'" \
  -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
```

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
