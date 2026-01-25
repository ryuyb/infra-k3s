# ZITADEL 重构变更记录

## 2025-01-25 - 模块化重构完成

### 变更概述
按照方案1对 `tofu/stacks/zitadel/main.tf` 进行了模块化重构，将单文件配置转换为模块化结构。

### 新增文件

#### 模块文件
- `tofu/modules/zitadel-project/main.tf` - ZITADEL 项目模块
- `tofu/modules/zitadel-project/variables.tf` - 项目模块变量
- `tofu/modules/zitadel-project/outputs.tf` - 项目模块输出
- `tofu/modules/zitadel-project/README.md` - 项目模块文档
- `tofu/modules/zitadel-oidc-app/main.tf` - ZITADEL OIDC 应用模块
- `tofu/modules/zitadel-oidc-app/variables.tf` - OIDC 应用模块变量
- `tofu/modules/zitadel-oidc-app/outputs.tf` - OIDC 应用模块输出
- `tofu/modules/zitadel-oidc-app/README.md` - OIDC 应用模块文档
- `tofu/modules/zitadel-action/main.tf` - ZITADEL 动作模块
- `tofu/modules/zitadel-action/variables.tf` - 动作模块变量
- `tofu/modules/zitadel-action/outputs.tf` - 动作模块输出
- `tofu/modules/zitadel-action/README.md` - 动作模块文档

#### 配置文件
- `tofu/stacks/zitadel/outputs.tf` - 主配置输出定义
- `tofu/stacks/zitadel/README.md` - 主配置文档
- `tofu/stacks/zitadel/REFACTORING_SUMMARY.md` - 重构总结
- `tofu/stacks/zitadel/CHANGES.md` - 本变更记录
- `tofu/stacks/zitadel/scripts/argocd-groups-claim.js` - 提取的 JavaScript 脚本

### 修改文件

#### `tofu/stacks/zitadel/main.tf`
- 添加 `required_version = ">= 1.6.0"`
- 使用模块化结构组织资源
- 移除内联 JavaScript 脚本
- 使用 `file()` 函数加载外部脚本

#### `tofu/stacks/zitadel/variables.tf`
- 添加详细描述
- 添加 `sensitive = true` 标记
- 添加域名验证规则

#### `tofu/stacks/zitadel/terraform.tfvars.example`
- 添加 `oauth2_proxy_domain` 字段

### 功能变化

#### ArgoCD 配置
- **项目**: `argocd` (通过 `zitadel-project` 模块管理)
- **角色**: `argocd_administrators`, `argocd_users` (动态创建)
- **用户授权**: 管理员用户授权 (动态创建)
- **OIDC 应用**: `argocd` (通过 `zitadel-oidc-app` 模块管理)
- **自定义动作**: `argocdGroupsClaim` (通过 `zitadel-action` 模块管理)

#### OAuth2 Proxy 配置
- **项目**: `oauth2-proxy` (通过 `zitadel-project` 模块管理)
- **OIDC 应用**: `oauth2-proxy` (通过 `zitadel-oidc-app` 模块管理)

### 输出变化

#### 新增输出
- `argocd_project_id` - ArgoCD 项目 ID
- `argocd_application_id` - ArgoCD OIDC 应用 ID
- `argocd_client_id` - ArgoCD OIDC 客户端 ID (sensitive)
- `argocd_client_secret` - ArgoCD OIDC 客户端 Secret (sensitive)
- `argocd_group_claim_action_id` - ArgoCD groups claim 动作 ID
- `oauth2_proxy_project_id` - OAuth2 Proxy 项目 ID
- `oauth2_proxy_application_id` - OAuth2 Proxy OIDC 应用 ID
- `oauth2_proxy_client_id` - OAuth2 Proxy OIDC 客户端 ID (sensitive)
- `oauth2_proxy_client_secret` - OAuth2 Proxy OIDC 客户端 Secret (sensitive)

### 验证结果
```bash
$ tofu validate
Success! The configuration is valid.
```

### 迁移说明

由于使用了模块化结构，Terraform 可能会检测到资源移动。建议：

1. **备份当前状态**:
   ```bash
   cp terraform.tfstate terraform.tfstate.backup
   ```

2. **检查计划变更**:
   ```bash
   tofu plan
   ```

3. **确认无误后应用**:
   ```bash
   tofu apply
   ```

### 使用示例

#### 1. 配置变量
```bash
cp terraform.tfvars.example terraform.tfvars
# 编辑 terraform.tfvars 填入实际值
```

#### 2. 初始化和应用
```bash
cd tofu/stacks/zitadel
tofu init
tofu plan
tofu apply
```

#### 3. 使用输出
```bash
# 获取 ArgoCD 客户端 ID 和 Secret
tofu output argocd_client_id
tofu output argocd_client_secret
```

### 添加新应用

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

### 优势

1. **模块化**: 每个模块职责单一，易于理解和维护
2. **可维护性**: 代码组织更清晰，添加新应用更简单
3. **可扩展性**: 支持动态创建多个角色和授权
4. **安全性**: 敏感信息标记为 sensitive，变量验证防止配置错误
5. **文档化**: 每个模块都有详细的 README

### 注意事项

1. **状态迁移**: 由于使用了模块，Terraform 可能会检测到资源移动
2. **变量验证**: 新添加的验证规则会检查域名是否以 `https://` 开头
3. **敏感信息**: 客户端密钥等敏感信息在输出中会被标记为 sensitive

### 后续计划

1. 添加模块单元测试
2. 集成到 CI/CD 流程
3. 根据需要添加更多 ZITADEL 资源模块
4. 配置远程状态存储（如 S3、Azure Blob Storage）
