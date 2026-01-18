#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VAULT_FILE="$PROJECT_ROOT/ansible/inventory/group_vars/all/vault.yml"
VALUES_FILE="$PROJECT_ROOT/helm/apps/values.yaml"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== PostgreSQL 应用数据库密码生成工具 ===${NC}\n"

# 检查依赖
command -v ansible-vault >/dev/null 2>&1 || { echo "错误: 需要安装 ansible-vault"; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "错误: 需要安装 yq (https://github.com/mikefarah/yq)"; exit 1; }

# 生成强随机密码（32字符，包含字母数字和特殊字符）
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# 读取 values.yaml 中的应用列表
echo "读取应用配置..."
app_names=$(yq eval '.appDatabases[].name' "$VALUES_FILE")

if [ -z "$app_names" ]; then
    echo "错误: 在 $VALUES_FILE 中未找到 appDatabases 配置"
    exit 1
fi

# 解密 Vault 文件到临时文件
TEMP_VAULT=$(mktemp)
trap "rm -f $TEMP_VAULT" EXIT

echo "解密 Ansible Vault..."
ansible-vault decrypt "$VAULT_FILE" --output="$TEMP_VAULT"

# 确保 app_db_passwords 节点存在
if ! yq eval '.app_db_passwords' "$TEMP_VAULT" >/dev/null 2>&1; then
    echo "初始化 app_db_passwords 配置..."
    yq eval '.app_db_passwords = {}' -i "$TEMP_VAULT"
fi

# 为每个应用生成或保留密码
echo -e "\n处理应用密码:"
while IFS= read -r app_name; do
    [ -z "$app_name" ] && continue

    # 转换为 Vault 中的 key 格式（user-service -> user_service）
    vault_key=$(echo "$app_name" | tr '-' '_')

    # 检查密码是否已存在
    existing_password=$(yq eval ".app_db_passwords.$vault_key" "$TEMP_VAULT")

    if [ "$existing_password" != "null" ] && [ -n "$existing_password" ]; then
        echo -e "  ${YELLOW}✓${NC} $app_name: 密码已存在，保持不变"
    else
        new_password=$(generate_password)
        yq eval ".app_db_passwords.$vault_key = \"$new_password\"" -i "$TEMP_VAULT"
        echo -e "  ${GREEN}✓${NC} $app_name: 生成新密码"
    fi
done <<< "$app_names"

# 重新加密 Vault 文件
echo -e "\n加密 Ansible Vault..."
ansible-vault encrypt "$TEMP_VAULT" --output="$VAULT_FILE"

echo -e "\n${GREEN}✓ 完成！密码已保存到 $VAULT_FILE${NC}"
echo -e "\n下一步: 运行 ${YELLOW}ansible-playbook ansible/playbooks/setup-secrets-database.yml${NC}"
