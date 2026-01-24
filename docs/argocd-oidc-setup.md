# ArgoCD OIDC 配置指南

## 概述

本文档说明如何为 ArgoCD 配置 OIDC 认证，使用 ZITADEL 作为 OIDC 提供商。

## 配置结构

### 1. 变量定义 (`ansible/roles/argocd/defaults/main.yml`)

```yaml
# OIDC Configuration
argocd_oidc_enabled: "{{ lookup('env', 'ARGOCD_OIDC_ENABLED') | default('false', true) }}"
argocd_oidc_issuer_url: "{{ lookup('env', 'ARGOCD_OIDC_ISSUER_URL') | default('', true) }}"
argocd_oidc_client_id: "{{ lookup('env', 'ARGOCD_OIDC_CLIENT_ID') | default('', true) }}"
argocd_oidc_client_secret: "{{ lookup('env', 'ARGOCD_OIDC_CLIENT_SECRET') | default('', true) }}"
argocd_oidc_logout_url: "{{ lookup('env', 'ARGOCD_OIDC_LOGOUT_URL') | default('', true) }}"
```

### 2. Helm Values 模板 (`ansible/roles/argocd/templates/argocd-values.yaml.j2`)

```yaml
configs:
  cm:
    url: https://argocd
    {% if argocd_oidc_enabled == 'true' %}
    oidc.config: |
      name: Zitadel
      issuer: {{ argocd_oidc_issuer_url }}
      clientID: {{ argocd_oidc_client_id }}
      clientSecret: {{ argocd_oidc_client_secret }}
      requestedScopes:
        - openid
        - profile
        - email
        - groups
      logoutURL: {{ argocd_oidc_logout_url }}
    {% endif %}
  rbac:
    policy.csv: |
      g, argocd_administrators, role:admin
      g, argocd_users, role:readonly
    policy.default: ''
    scopes: '[groups]'
```

### 3. 环境变量示例 (`.envrc.example`)

```bash
# ArgoCD OIDC Configuration
export ARGOCD_OIDC_ENABLED="false"
export ARGOCD_OIDC_ISSUER_URL="https://auth.example.com"
export ARGOCD_OIDC_CLIENT_ID="227060711795262483@argocd-project"
export ARGOCD_OIDC_CLIENT_SECRET="your-client-secret"
export ARGOCD_OIDC_LOGOUT_URL="https://auth.example.com/oidc/v1/end_session"
```

## 使用步骤

### 步骤 1: 在 ZITADEL 中创建 OIDC 客户端

1. 访问 ZITADEL 控制台
2. 创建 OIDC 应用程序：
   - 应用类型：Web
   - 回调 URL：`https://argocd.your-domain.com/auth/callback`
   - 启用授权码模式
   - 启用 PKCE
   - 作用域：`openid profile email groups`

### 步骤 2: 配置环境变量

1. 复制 `.envrc.example` 到 `.envrc.local`
2. 设置 OIDC 配置：
   ```bash
   export ARGOCD_OIDC_ENABLED="true"
   export ARGOCD_OIDC_ISSUER_URL="https://zitadel.your-domain.com"
   export ARGOCD_OIDC_CLIENT_ID="your-client-id"
   export ARGOCD_OIDC_CLIENT_SECRET="your-client-secret"
   export ARGOCD_OIDC_LOGOUT_URL="https://zitadel.your-domain.com/oidc/v1/end_session"
   ```
3. 启用环境变量：`direnv allow`

### 步骤 3: 部署 ArgoCD

```bash
ansible-playbook ansible/playbooks/deploy-argocd.yml
```

### 步骤 4: 验证配置

```bash
# 检查 ArgoCD ConfigMap
kubectl get cm argocd-cm -n argocd -o yaml

# 检查 ArgoCD RBAC ConfigMap
kubectl get cm argocd-rbac-cm -n argocd -o yaml

# 测试 OIDC 登录
# 访问 ArgoCD UI: https://argocd
# 点击 "LOG IN VIA OIDC" 按钮
```

## RBAC 配置

### 用户组定义

- **argocd_administrators**: 完全管理员权限 (role:admin)
- **argocd_users**: 只读权限 (role:readonly)

### 作用域配置

`scopes: '[groups]'` - 将 OIDC 组映射到 ArgoCD RBAC 组

## 故障排查

### OIDC 登录按钮不显示

**可能原因：**
- `ARGOCD_OIDC_ENABLED` 未设置为 `true`
- OIDC 配置未正确应用

**解决方法：**
```bash
# 检查环境变量
echo $ARGOCD_OIDC_ENABLED

# 检查 ArgoCD ConfigMap
kubectl get cm argocd-cm -n argocd -o yaml

# 重新部署 ArgoCD
ansible-playbook ansible/playbooks/deploy-argocd.yml
```

### OIDC 认证失败

**可能原因：**
- Issuer URL 不正确
- Client ID 或 Secret 不匹配
- 回调 URL 不匹配

**解决方法：**
```bash
# 检查 OIDC 配置
kubectl get cm argocd-cm -n argocd -o yaml | grep -A 20 "oidc.config"

# 检查 ZITADEL 日志
kubectl logs -n apps -l app=zitadel --tail=50
```

### RBAC 组不工作

**可能原因：**
- OIDC 令牌中未包含组信息
- 组名不匹配

**解决方法：**
```bash
# 检查 OIDC 令牌中的组信息
# 在浏览器开发者工具中检查登录后的令牌

# 验证 RBAC 配置
kubectl get cm argocd-rbac-cm -n argocd -o yaml
```

## 配置文件位置

| 文件 | 用途 |
|------|------|
| `ansible/roles/argocd/defaults/main.yml` | OIDC 变量定义 |
| `ansible/roles/argocd/templates/argocd-values.yaml.j2` | Helm values 模板 |
| `ansible/roles/argocd/tasks/main.yml` | 部署任务 |
| `.envrc.example` | 环境变量示例 |
| `.envrc.local` | 实际环境变量（gitignored） |

## 安全建议

1. **不要提交敏感信息到 Git**：使用 `.envrc.local` 存储实际值
2. **使用强密码**：确保 OIDC Client Secret 足够复杂
3. **定期轮换密钥**：定期更新 OIDC Client Secret
4. **限制访问权限**：根据需要配置 RBAC 策略

## 参考文档

- [ArgoCD OIDC 配置](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/)
- [ZITADEL OIDC 文档](https://zitadel.com/docs/guides/integrate/oidc/web-app)
- [ArgoCD RBAC 配置](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/)
