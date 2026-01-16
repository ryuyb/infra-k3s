# OpenTofu Infrastructure

模块化的 OpenTofu 配置，管理 Cloudflare DNS、R2 存储和其他基础设施。

## 目录结构

```
tofu/
├── modules/                    # 可复用模块
│   ├── cloudflare-dns/         # DNS 记录管理
│   ├── cloudflare-r2/          # R2 存储桶
│   └── authentik/              # Authentik 配置
└── stacks/                     # 环境配置
    └── prod/                   # 生产环境
```

## 使用方法

### 1. 配置环境变量

```bash
# 在 .envrc.local 中设置
export CLOUDFLARE_API_TOKEN="your-api-token"
export CLOUDFLARE_ZONE_ID="your-zone-id"
```

### 2. 初始化

```bash
cd tofu/stacks/prod
tofu init
```

### 3. 配置变量

```bash
cp terraform.tfvars.example terraform.tfvars
# 编辑 terraform.tfvars
```

### 4. 部署

```bash
tofu plan
tofu apply
```

## 模块说明

### cloudflare-dns

管理 DNS 记录（A、CNAME、TXT 等）。

```hcl
module "dns" {
  source  = "../../modules/cloudflare-dns"
  zone_id = var.cloudflare_zone_id
  records = {
    "app" = { type = "A", value = "1.2.3.4", proxied = true }
  }
}
```

### cloudflare-r2

创建和管理 R2 存储桶。

```hcl
module "backup_bucket" {
  source      = "../../modules/cloudflare-r2"
  account_id  = var.cloudflare_account_id
  bucket_name = "k3s-backups"
}
```

### authentik

配置 Authentik 身份认证（应用、提供者、流程等）。

```hcl
module "authentik" {
  source = "../../modules/authentik"
  url    = "https://auth.example.com"
  token  = var.authentik_token
  # ...
}
```
