# Velero Secrets Management

本文档说明如何使用 Sealed Secrets 加密 Velero 的敏感配置。

## 前提条件

```bash
# 安装 kubeseal CLI
brew install kubeseal

# 确保 sealed-secrets controller 已部署
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets
```

## 方式一：Sealed Secrets（推荐用于 GitOps）

### 1. 创建原始 Secret 文件

```bash
cat > /tmp/velero-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: velero-r2-credentials
  namespace: velero
type: Opaque
stringData:
  cloud: |
    [default]
    aws_access_key_id=YOUR_R2_ACCESS_KEY_ID
    aws_secret_access_key=YOUR_R2_SECRET_ACCESS_KEY
EOF
```

### 2. 使用 kubeseal 加密

```bash
# 从集群获取公钥并加密
kubeseal --format yaml < /tmp/velero-secret.yaml > sealedsecret.yaml

# 删除原始文件
rm /tmp/velero-secret.yaml
```

### 3. 验证加密

```bash
# 查看加密后的内容
cat sealedsecret.yaml
```

### 4. 提交到 Git

```bash
git add sealedsecret.yaml
git commit -m "Add sealed velero credentials"
```

### 5. ArgoCD 自动解封

Sealed Secrets controller 会自动将 SealedSecret 解封为普通 Secret。

## 方式二：脚本创建 Secret（推荐用于手动部署）

```bash
# 设置环境变量（在 .envrc.local 中）
export R2_ACCESS_KEY_ID="your-key-id"
export R2_SECRET_ACCESS_KEY="your-secret-key"
export VELERO_BUCKET="your-bucket"
export R2_ENDPOINT="https://account-id.r2.cloudflarestorage.com"

# 运行脚本
./scripts/setup/setup-velero.sh --create-secret
```

## 常用命令

```bash
# 获取集群公钥（离线加密用）
kubeseal --fetch-cert > sealed-secrets-cert.pem

# 使用本地证书加密（无需连接集群）
kubeseal --cert sealed-secrets-cert.pem --format yaml < secret.yaml > sealedsecret.yaml

# 查看 controller 日志
kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets
```

## 故障排除

### 解封失败

```bash
# 检查 SealedSecret 状态
kubectl get sealedsecret -n velero

# 检查 controller 日志
kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets

# 确保 namespace 匹配（SealedSecret 绑定到特定 namespace）
```

### 密钥轮换

```bash
# 备份当前密钥
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets-backup.yaml

# 重新加密所有 secrets（密钥轮换后）
kubeseal --re-encrypt < sealedsecret.yaml > sealedsecret-new.yaml
```
