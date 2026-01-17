# 双域名 HTTPS 配置方案

本文档介绍如何配置双域名访问架构,支持公网访问和 Tailscale 内网访问。

## 架构概述

```
公网访问:   app.example.com      → 公网 IP      → HTTPS 证书
Tailscale:  app.k3s.ryuyb.com    → Tailscale IP → HTTPS 证书
```

## 方案对比

| 特性 | 方案 A (推荐) | 方案 B |
|------|--------------|--------|
| 证书管理 | 统一使用 cert-manager | 混合管理 |
| 公网证书 | Let's Encrypt (DNS-01) | Let's Encrypt (DNS-01) |
| Tailscale 证书 | Let's Encrypt (DNS-01) | Tailscale cert (手动) |
| 自动续期 | ✅ 全自动 | ⚠️ Tailscale 证书需手动更新 |
| 配置复杂度 | 简单 | 中等 |
| 适用场景 | 域名在同一 DNS 提供商 | 使用 Tailscale 原生域名 |

---

## 方案 A: 统一使用 Let's Encrypt (推荐)

### 适用场景

- ✅ 公网域名和 Tailscale 域名都在 Cloudflare(或同一 DNS 提供商)管理
- ✅ 希望统一管理证书,自动续期
- ✅ 本地测试和生产环境配置一致

### 架构设计

```
公网域名:     app.example.com      → 公网 IP      → Let's Encrypt 证书
Tailscale域名: app.k3s.ryuyb.com    → Tailscale IP → Let's Encrypt 证书

证书管理:     cert-manager + Cloudflare DNS-01 challenge
自动续期:     ✅ 全自动
```

### 前提条件

1. **域名配置**
   - 公网域名: `example.com` (在 Cloudflare 管理)
   - Tailscale 域名: `k3s.ryuyb.com` (在 Cloudflare 管理)

2. **DNS 记录**
   ```
   # Cloudflare DNS 记录
   *.example.com      A  <公网 IP>
   *.k3s.ryuyb.com    A  100.107.205.15  (Tailscale IP)
   *.k3s.ryuyb.com    A  100.114.57.55   (Tailscale IP)
   *.k3s.ryuyb.com    A  100.127.90.115  (Tailscale IP)
   ```

3. **Cloudflare API Token**
   - 权限: Zone:DNS:Edit
   - 作用域: 包含两个域名的 Zone

### 实现步骤

#### 1. 配置环境变量

在 `.envrc.local` 中添加:

```bash
# Cloudflare API Token
export CLOUDFLARE_API_TOKEN="your-cloudflare-api-token"

# 域名配置
export PUBLIC_DOMAIN="example.com"
export TAILSCALE_DOMAIN="k3s.ryuyb.com"
```

#### 2. 创建 Cloudflare Secret

```bash
direnv allow
ansible-playbook ansible/playbooks/setup-secrets.yml
```

#### 3. 配置 Gateway

修改 `helm/infrastructure-resources/templates/gateway.yaml`:

```yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: traefik
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  gatewayClassName: traefik
  listeners:
    # HTTP listener (重定向到 HTTPS)
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All

    # HTTPS listener - 公网域名
    - name: https-public
      protocol: HTTPS
      port: 443
      hostname: "*.{{ .Values.publicDomain }}"
      allowedRoutes:
        namespaces:
          from: All
      tls:
        mode: Terminate
        certificateRefs:
          - name: public-wildcard-tls
            namespace: cert-manager

    # HTTPS listener - Tailscale 域名
    - name: https-tailscale
      protocol: HTTPS
      port: 443
      hostname: "*.{{ .Values.domain }}"
      allowedRoutes:
        namespaces:
          from: All
      tls:
        mode: Terminate
        certificateRefs:
          - name: tailscale-wildcard-tls
            namespace: cert-manager
```

#### 4. 配置 Certificate 资源

修改 `helm/infrastructure-resources/templates/certificates.yaml`:

```yaml
---
# 公网域名证书
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: public-wildcard-tls
  namespace: cert-manager
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  secretName: public-wildcard-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - "{{ .Values.publicDomain }}"
    - "*.{{ .Values.publicDomain }}"

---
# Tailscale 域名证书
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tailscale-wildcard-tls
  namespace: cert-manager
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  secretName: tailscale-wildcard-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - "{{ .Values.domain }}"
    - "*.{{ .Values.domain }}"
```

#### 5. 配置 HTTPRoute

每个应用创建两个 hostname:

```yaml
# 示例: Grafana HTTPRoute
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: grafana
  namespace: monitoring
spec:
  parentRefs:
    - name: main-gateway
      namespace: traefik
      sectionName: https-public
    - name: main-gateway
      namespace: traefik
      sectionName: https-tailscale
  hostnames:
    - "grafana.example.com"      # 公网域名
    - "grafana.k3s.ryuyb.com"    # Tailscale 域名
  rules:
    - backendRefs:
        - name: grafana
          port: 80
```

#### 6. 配置 External-DNS

External-DNS 会自动为两个域名创建 DNS 记录:

```
grafana.example.com     → 公网 IP (生产环境)
grafana.k3s.ryuyb.com   → Tailscale IP (始终)
```

### 验证

```bash
# 检查证书状态
kubectl get certificate -n cert-manager

# 检查 Gateway 状态
kubectl get gateway main-gateway -n traefik

# 检查 HTTPRoute 状态
kubectl get httproute -A

# 测试访问
curl -k https://grafana.k3s.ryuyb.com  # Tailscale 访问
curl https://grafana.example.com       # 公网访问 (生产环境)
```

### 优点

- ✅ 统一使用 cert-manager 管理证书
- ✅ 自动续期,无需手动干预
- ✅ 本地测试和生产环境配置一致
- ✅ 配置简单,易于维护

### 缺点

- ⚠️ 需要两个域名都在同一 DNS 提供商管理
- ⚠️ 本地测试时,公网域名的 DNS 记录会指向 Tailscale IP(无法从公网访问)

---

## 方案 B: 混合方案 (Tailscale cert)

### 适用场景

- ✅ 使用 Tailscale 原生域名 (`*.ts.net`)
- ✅ Tailscale 域名不在 Cloudflare 管理
- ✅ 希望使用 Tailscale 提供的自动 HTTPS

### 架构设计

```
公网域名:     app.example.com           → 公网 IP      → Let's Encrypt (cert-manager)
Tailscale域名: app.tail<hash>.ts.net     → Tailscale IP → Tailscale cert (手动)

证书管理:     混合管理
自动续期:     公网证书自动,Tailscale 证书需手动更新
```

### 前提条件

1. **域名配置**
   - 公网域名: `example.com` (在 Cloudflare 管理)
   - Tailscale 域名: `<machine>.tail<hash>.ts.net` (Tailscale 提供)

2. **Tailscale 配置**
   - 启用 MagicDNS
   - 启用 HTTPS

### 实现步骤

#### 1. 获取 Tailscale 证书

在 Tailscale 节点上运行:

```bash
# 获取 Tailscale 域名
tailscale status

# 申请证书
tailscale cert app.tail<hash>.ts.net

# 会生成两个文件:
# app.tail<hash>.ts.net.crt
# app.tail<hash>.ts.net.key
```

#### 2. 创建 Kubernetes Secret

```bash
kubectl create secret tls tailscale-wildcard-tls \
  --cert=app.tail<hash>.ts.net.crt \
  --key=app.tail<hash>.ts.net.key \
  -n cert-manager
```

#### 3. 配置 Gateway

```yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: traefik
spec:
  gatewayClassName: traefik
  listeners:
    # HTTPS listener - 公网域名
    - name: https-public
      protocol: HTTPS
      port: 443
      hostname: "*.example.com"
      tls:
        certificateRefs:
          - name: public-wildcard-tls
            namespace: cert-manager

    # HTTPS listener - Tailscale 域名
    - name: https-tailscale
      protocol: HTTPS
      port: 443
      hostname: "*.tail<hash>.ts.net"
      tls:
        certificateRefs:
          - name: tailscale-wildcard-tls
            namespace: cert-manager
```

#### 4. 配置 HTTPRoute

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: grafana
  namespace: monitoring
spec:
  parentRefs:
    - name: main-gateway
      namespace: traefik
  hostnames:
    - "grafana.example.com"           # 公网域名
    - "grafana.tail<hash>.ts.net"     # Tailscale 域名
  rules:
    - backendRefs:
        - name: grafana
          port: 80
```

#### 5. 证书续期

Tailscale 证书需要手动续期(每 90 天):

```bash
# 重新申请证书
tailscale cert app.tail<hash>.ts.net

# 更新 Kubernetes Secret
kubectl create secret tls tailscale-wildcard-tls \
  --cert=app.tail<hash>.ts.net.crt \
  --key=app.tail<hash>.ts.net.key \
  -n cert-manager \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 优点

- ✅ 使用 Tailscale 原生域名
- ✅ Tailscale 证书通过 Tailscale DNS 验证,更快
- ✅ 不需要在 Cloudflare 添加 Tailscale 域名

### 缺点

- ⚠️ 需要手动管理 Tailscale 证书更新
- ⚠️ 域名不够友好 (`*.tail<hash>.ts.net`)
- ⚠️ 配置相对复杂

---

## 推荐选择

### 本地测试环境
- **推荐方案 A**: 使用自己的域名,统一管理
- 只使用 Tailscale 域名访问
- 公网域名在生产环境启用

### 生产环境
- **推荐方案 A**: 统一管理,自动续期
- 同时支持公网和 Tailscale 访问
- 配置简单,易于维护

### 特殊场景
- **使用方案 B**: 如果必须使用 Tailscale 原生域名
- 或者 Tailscale 域名不在 DNS 提供商管理

---

## 常见问题

### Q: DNS-01 challenge 可以生成泛域名证书吗?

**A: 可以!** DNS-01 是**唯一**可以生成泛域名证书的方法。HTTP-01 challenge 无法验证泛域名。

### Q: 为什么之前无法生成证书?

**A: 缺少 Cloudflare API token Secret。** cert-manager 需要 Cloudflare API token 来创建 DNS TXT 记录进行验证。

### Q: 本地测试时公网域名如何处理?

**A: 有两种方式:**
1. 公网域名的 DNS 记录指向 Tailscale IP(只能在 Tailscale 网络访问)
2. 使用不同的 External-DNS 配置,本地测试时只创建 Tailscale 域名的 DNS 记录

### Q: 如何切换方案?

**A: 修改 Gateway 和 Certificate 配置,提交到 Git,ArgoCD 会自动同步。**

---

## 参考资料

- [cert-manager 文档](https://cert-manager.io/docs/)
- [Gateway API 文档](https://gateway-api.sigs.k8s.io/)
- [Tailscale HTTPS 文档](https://tailscale.com/kb/1153/enabling-https/)
- [Let's Encrypt DNS-01 Challenge](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge)
