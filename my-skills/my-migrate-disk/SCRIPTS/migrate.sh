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

# 生成迁移清单
generate_report() {
  # 从全局记忆中读取统一文档项目路径
  local doc_project=$(grep -A1 "^描述" ~/.claude/memory/user_doc_dir.md 2>/dev/null | grep "/root/sh" || echo "/root/sh")
  [ ! -d "$doc_project" ] && doc_project="/root/sh"

  # 创建目标目录
  local target_dir="$doc_project/migrated-disk"
  mkdir -p "$target_dir"

  # 生成文件名：机器名-IP-日期-migrated.md
  local hostname=$(hostname)
  local ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "unknown")
  local date_str=$(date '+%Y-%m-%d')
  local report_file="$target_dir/${hostname}-${ip_addr}-${date_str}-migrated.md"

  echo_info "生成迁移清单..."

  cat > "$report_file" << 'HEADER'
# /root 目录软链接迁移清单

## 概述

本清单记录 `/root` 目录下所有软链接的迁移信息，将原本占用根分区空间的目录迁移至 `/data` 目录。

HEADER

  echo "**迁移时间**: $(date '+%Y-%m-%d')" >> "$report_file"
  echo "" >> "$report_file"

  # 统计软链接数量
  local link_count=$(ls -la /root/ | grep "^l" | wc -l)
  echo "- **软链接总数**: $link_count" >> "$report_file"
  echo "" >> "$report_file"

  cat >> "$report_file" << 'TABLE_HEADER'
## 软链接迁移清单

| 序号 | 原始路径 (/root) | 目标路径 (/data) | 大小 | 说明 |
|------|------------------|------------------|------|------|
TABLE_HEADER

  local idx=1
  declare -A links=(
    ["/root/.npm"]="/data/user-config/.npm:npm 包管理配置及缓存"
    ["/root/.nvm"]="/data/user-config/.nvm:Node 版本管理器"
    ["/root/.local"]="/data/user-config/.local:用户本地应用配置"
    ["/root/.opencode"]="/data/user-config/.opencode:OpenCode 编辑器配置"
    ["/root/.wdm"]="/data/user-config/.wdm:WebDriver Manager 配置"
    ["/root/.bun"]="/data/user-config/.bun:Bun runtime 配置"
    ["/root/.cache"]="/data/user-config/root-cache:用户缓存目录"
    ["/root/.paddlex"]="/data/cache/.paddlex:PaddleX 机器学习模型"
    ["/root/venv"]="/data/venvs/root-venv:Python 虚拟环境"
    ["/root/playwright-venv"]="/data/venvs/playwright-venv:Playwright 测试虚拟环境"
    ["/root/stock-quant-strategy-venv"]="/data/venvs/stock-quant-strategy-venv:量化交易策略虚拟环境"
    ["/root/ai"]="/data/ai:AI 相关配置和数据"
    ["/root/.claude"]="/data/claude/claude_root:Claude Code 配置"
  )

  for link in "${!links[@]}"; do
    if [ -L "$link" ]; then
      local target_desc="${links[$link]}"
      local target="${target_desc%%:*}"
      local desc="${target_desc##*:}"
      local size=$(du -sh "$link" 2>/dev/null | cut -f1 || echo "N/A")
      printf "| %d | \`%s\` | \`%s\` | %s | %s |\n" \
        "$idx" "$link" "$target" "$size" "$desc" >> "$report_file"
      ((idx++))
    fi
  done

  echo "" >> "$report_file"

  cat >> "$report_file" << 'FOOTER'
## 注意事项

1. **user-config/** 目录包含重要用户配置，不建议随意清理
2. **venv** 目录包含 Python 虚拟环境，清理前请确认不再使用
3. **cache/** 目录包含可重新下载的缓存（如模型、缓存包），可按需清理
4. 软链接损坏时可使用 `readlink -f /root/<path>` 检查目标是否存在
FOOTER

  echo_info "清单已生成: $report_file"
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
  generate_report

  echo ""
  echo "=========================================="
  echo "迁移完成"
  echo "=========================================="
  echo ""
  echo "建议运行验证脚本检查迁移结果:"
  echo "  bash /data/claude/claude_root/skills/my-migrate-disk/SCRIPTS/verify.sh"
}

main "$@"
