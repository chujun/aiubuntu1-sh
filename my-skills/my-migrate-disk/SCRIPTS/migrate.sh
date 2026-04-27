#!/bin/bash
# 迁移脚本 - 将 /root 目录迁移到 /data

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查是否为软链接或已存在
check_and_migrate() {
  local source=$1
  local target=$2
  local desc=$3

  if [ -L "$source" ]; then
    echo_info "$desc 已是软链接，跳过: $source"
    return 0
  fi

  if [ -d "$source" ] || [ -f "$source" ]; then
    if [ -e "$target" ]; then
      echo_warn "目标已存在，跳过: $target"
      return 0
    fi
    mv "$source" "$target"
    ln -s "$target" "$source"
    echo_info "迁移成功: $source -> $target"
  else
    echo_warn "源不存在，跳过: $source"
  fi
}

# 创建目录结构
setup_directories() {
  echo_info "创建目录结构..."
  mkdir -p /data/user-config
  mkdir -p /data/venvs
  mkdir -p /data/cache
  mkdir -p /data/claude
  echo_info "目录创建完成"
}

# 迁移用户配置目录
migrate_user_config() {
  echo_info "=== 迁移用户配置目录 ==="

  local items=(
    ".npm:/data/user-config/.npm:npm 包管理"
    ".nvm:/data/user-config/.nvm:Node 版本管理器"
    ".local:/data/user-config/.local:用户本地配置"
    ".opencode:/data/user-config/.opencode:OpenCode 配置"
    ".wdm:/data/user-config/.wdm:WebDriverManager"
    ".bun:/data/user-config/.bun:Bun 配置"
  )

  for item in "${items[@]}"; do
    IFS=':' read -r src target desc <<< "$item"
    check_and_migrate "/root/$src" "$target" "$desc"
  done
}

# 迁移虚拟环境
migrate_venvs() {
  echo_info "=== 迁移虚拟环境 ==="

  local items=(
    "venv:/data/venvs/root-venv:Python 虚拟环境"
    "playwright-venv:/data/venvs/playwright-venv:Playwright 测试环境"
    "stock-quant-strategy-venv:/data/venvs/stock-quant-strategy-venv:量化交易环境"
  )

  for item in "${items[@]}"; do
    IFS=':' read -r src target desc <<< "$item"
    check_and_migrate "/root/$src" "$target" "$desc"
  done
}

# 迁移缓存目录
migrate_cache() {
  echo_info "=== 迁移缓存目录 ==="

  local items=(
    ".paddlex:/data/cache/.paddlex:PaddleX 模型"
    ".huggingface_cache:/data/cache/.huggingface_cache:HuggingFace 缓存"
  )

  for item in "${items[@]}"; do
    IFS=':' read -r src target desc <<< "$item"
    check_and_migrate "/root/$src" "$target" "$desc"
  done
}

# 迁移其他重要目录
migrate_others() {
  echo_info "=== 迁移其他目录 ==="

  check_and_migrate "/root/ai" "/data/ai" "AI 相关数据"
  check_and_migrate "/root/.claude" "/data/claude/claude_root" "Claude Code 配置"
}

# 主函数
main() {
  echo "=========================================="
  echo "磁盘迁移脚本"
  echo "=========================================="
  echo ""

  setup_directories
  migrate_user_config
  migrate_venvs
  migrate_cache
  migrate_others

  echo ""
  echo "=========================================="
  echo "迁移完成"
  echo "=========================================="
  echo ""
  echo "建议运行验证脚本检查迁移结果:"
  echo "  bash /data/claude/claude_root/skills/my-migrate-disk/SCRIPTS/verify.sh"
}

main "$@"
