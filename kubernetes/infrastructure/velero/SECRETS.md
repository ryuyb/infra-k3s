# Velero Secrets Management

本文档说明如何使用 SOPS 加密 Velero 的敏感配置。

## 前提条件

```bash
# 安装工具
brew install sops age

# 生成 age 密钥（首次设置）
age-keygen -o .age-key.txt
# 输出示例：
# Public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# 将公钥更新到 .sops.yaml
```

## 方式一：SOPS 加密 Secret（推荐用于 GitOps）

### 1. 创建 Secret 文件

```bash
cp secret.sops.yaml.example secret.sops.yaml
```

### 2. 编辑填入实际值

```yaml
# secret.sops.yaml
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
```

### 3. 加密文件

```bash
# 使用 .sops.yaml 中配置的 age 公钥加密
sops -e -i secret.sops.yaml
```

### 4. 验证加密

```bash
# 查看加密后的内容
cat secret.sops.yaml

# 解密查看（需要 .age-key.txt）
sops -d secret.sops.yaml
```

### 5. 提交到 Git

```bash
git add secret.sops.yaml
git commit -m "Add encrypted velero credentials"
```

### 6. ArgoCD 自动解密

ArgoCD 配置了 KSOPS，会在部署时自动解密 `.sops.yaml` 文件。

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
# 编辑加密文件（自动解密→编辑→加密）
sops secret.sops.yaml

# 解密查看
sops -d secret.sops.yaml

# 重新加密（更换密钥后）
sops updatekeys secret.sops.yaml

# 手动应用 Secret
sops -d secret.sops.yaml | kubectl apply -f -
```

## 故障排除

### 解密失败

```bash
# 检查 age 密钥文件
ls -la .age-key.txt

# 检查环境变量
echo $SOPS_AGE_KEY_FILE

# 确保 direnv 已加载
direnv allow
```

### ArgoCD 解密失败

1. 检查 ArgoCD repo-server 是否有 `sops-age-key` Secret
2. 检查 KSOPS 插件是否正确安装
3. 查看 ArgoCD 日志：`kubectl logs -n argocd deploy/argocd-repo-server`
