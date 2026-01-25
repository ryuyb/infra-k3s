# ZITADEL 重构总结

## 重构概述

按照方案1（模块化重构）对 `tofu/stacks/zitadel/main.tf` 进行了全面重构，将单文件配置转换为模块化结构。

## 重构内容

### 1. 创建了三个新模块

#### `tofu/modules/zitadel-project/`
- 管理 ZITADEL 项目
- 管理项目角色（roles）
- 管理用户授权（grants）
- 支持通过 `for_each` 动态创建多个角色和授权

#### `tofu/modules/zitadel-oidc-app/`
- 管理 ZITADEL OIDC 应用程序
- 支持配置各种 OIDC 参数（响应类型、授权类型、认证方法等）
- 支持配置重定向 URI 和注销重定向 URI

#### `tofu/modules/zitadel-action/`
- 管理 ZITADEL 自定义动作
- 支持配置动作脚本
- 支持配置触发器（pre userinfo creation, pre access token creation）

### 2. 更新了主配置文件

#### `tofu/stacks/zitadel/main.tf`
- 添加了 `required_version = ">= 1.6.0"`
- 使用模块化结构组织资源
- 移除了内联的 JavaScript 脚本
- 使用 `file()` 函数加载外部脚本

### 3. 添加了输出定义

#### `tofu/stacks/zitadel/outputs.tf`
- ArgoCD 相关输出：项目 ID、应用 ID、客户端 ID/Secret
- OAuth2 Proxy 相关输出：项目 ID、应用 ID、客户端 ID/Secret
- 敏感信息标记为 `sensitive = true`

### 4. 改进了变量定义

#### `tofu/stacks/zitadel/variables.tf`
- 添加了详细的描述
- 添加了 `sensitive = true` 标记
- 添加了验证规则（确保域名以 https:// 开头）

### 5. 提取了 JavaScript 脚本

#### `tofu/stacks/zitadel/scripts/argocd-groups-claim.js`
- 将内联脚本提取到外部文件
- 改进了注释和文档

### 6. 更新了示例配置

#### `tofu/stacks/zitadel/terraform.tfvars.example`
- 添加了 `oauth2_proxy_domain` 字段

### 7. 添加了文档

#### `tofu/stacks/zitadel/README.md`
- 详细说明了模块结构
- 提供了使用示例
- 说明了如何添加新应用

#### 模块 README 文件
- `tofu/modules/zitadel-project/README.md`
- `tofu/modules/zitadel-oidc-app/README.md`
- `tofu/modules/zitadel-action/README.md`

## 文件结构对比

### 重构前
```
tofu/stacks/zitadel/
├── main.tf                    # 单文件，所有资源定义
├── variables.tf
├── terraform.tfvars
├── terraform.tfvars.example
└── .terraform.lock.hcl
```

### 重构后
```
tofu/stacks/zitadel/
├── main.tf                    # 主配置文件（使用模块）
├── variables.tf               # 改进的变量定义
├── outputs.tf                 # 新增输出定义
├── terraform.tfvars
├── terraform.tfvars.example
├── .terraform.lock.hcl
├── README.md                  # 新增文档
├── REFACTORING_SUMMARY.md     # 本文件
└── scripts/
    └── argocd-groups-claim.js # 提取的脚本

tofu/modules/
├── zitadel-project/           # 新增模块
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── README.md
├── zitadel-oidc-app/          # 新增模块
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── README.md
└── zitadel-action/            # 新增模块
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── README.md
```

## 重构优势

### 1. 模块化
- 每个模块职责单一，易于理解和维护
- 模块可以独立测试
- 模块可以跨项目重用

### 2. 可维护性
- 代码组织更清晰
- 添加新应用更简单
- 修改现有配置更容易

### 3. 可扩展性
- 支持动态创建多个角色和授权
- 易于添加新的 ZITADEL 资源
- 模块化设计支持未来扩展

### 4. 安全性
- 敏感信息（client_secret）标记为 sensitive
- 变量验证防止配置错误
- 脚本提取到外部文件，避免硬编码

### 5. 文档化
- 每个模块都有详细的 README
- 主配置文件有完整的使用说明
- 提供了添加新应用的指南

## 使用方式

### 1. 配置变量
```bash
cp terraform.tfvars.example terraform.tfvars
# 编辑 terraform.tfvars 填入实际值
```

### 2. 初始化和应用
```bash
cd tofu/stacks/zitadel
tofu init
tofu plan
tofu apply
```

### 3. 使用输出
```bash
# 获取 ArgoCD 客户端 ID 和 Secret
tofu output argocd_client_id
tofu output argocd_client_secret
```

## 添加新应用示例

```hcl
# 在 main.tf 中添加
module "new_app_project" {
  source = "../../modules/zitadel-project"
  name   = "new-app"
  org_id = data.zitadel_org.default.id
  # ... 其他配置
}

module "new_app_oidc" {
  source = "../../modules/zitadel-oidc-app"
  name   = "new-app"
  org_id = data.zitadel_org.default.id
  project_id = module.new_app_project.project_id
  redirect_uris = ["https://new-app.example.com/callback"]
}
```

## 注意事项

1. **状态迁移**：由于使用了模块，Terraform 可能会检测到资源移动。建议：
   - 先备份当前状态
   - 使用 `tofu plan` 检查变更
   - 确认无误后再应用

2. **变量验证**：新添加的验证规则会检查域名是否以 `https://` 开头

3. **敏感信息**：客户端密钥等敏感信息在输出中会被标记为 sensitive

## 后续改进

1. **添加测试**：为每个模块添加单元测试
2. **添加 CI/CD**：集成到 GitHub Actions 或其他 CI/CD 工具
3. **添加更多模块**：根据需要添加更多 ZITADEL 资源模块
4. **添加状态后端**：配置远程状态存储（如 S3、Azure Blob Storage）

## 总结

本次重构成功地将单文件配置转换为模块化结构，提高了代码的可维护性、可扩展性和安全性。新的结构更符合 Terraform 最佳实践，便于团队协作和长期维护。
