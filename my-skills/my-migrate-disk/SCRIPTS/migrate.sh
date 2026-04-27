#!/bin/bash
# 迁移脚本 - 根据 scan.sh 的选择执行迁移

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SELECTION_FILE="/tmp/migrate_selection.txt"

# 检查选择文件
if [ ! -f "$SELECTION_FILE" ]; then
  echo_error "未找到选择文件，请先运行 scan.sh"
  echo "示例：bash /data/claude/claude_root/skills/my-migrate-disk/SCRIPTS/scan.sh 100M"
  exit 1
fi

selected_count=$(cat "$SELECTION_FILE" | wc -l)
if [ "$selected_count" -eq 0 ]; then
  echo_error "没有选择任何目录"
  exit 1
fi

echo "=========================================="
echo "磁盘迁移脚本"
echo "=========================================="
echo ""
echo_info "将迁移 $selected_count 个目录"
echo ""

# 创建目标目录
TARGET_DIR="/data/migrate-root"
mkdir -p "$TARGET_DIR"
echo_info "目标目录: $TARGET_DIR"

# 迁移每个选中的目录
migrated=0
skipped=0

while IFS= read -r source_dir; do
  # 跳过空行
  [ -z "$source_dir" ] && continue

  dir_name=$(basename "$source_dir")
  target_path="$TARGET_DIR/$dir_name"

  # 检查是否已是软链接
  if [ -L "$source_dir" ]; then
    echo_warn "跳过（已是软链接）: $source_dir"
    ((skipped++))
    continue
  fi

  # 检查源是否存在
  if [ ! -e "$source_dir" ]; then
    echo_warn "跳过（不存在）: $source_dir"
    ((skipped++))
    continue
  fi

  # 检查目标是否已存在
  if [ -e "$target_path" ]; then
    echo_warn "跳过（目标已存在）: $target_path"
    ((skipped++))
    continue
  fi

  # 执行迁移
  mv "$source_dir" "$target_path"
  ln -s "$target_path" "$source_dir"

  if [ $? -eq 0 ]; then
    echo_info "迁移成功: $source_dir -> $target_path"
    ((migrated++))
  else
    echo_error "迁移失败: $source_dir"
  fi

done < "$SELECTION_FILE"

echo ""
echo "=========================================="
echo "迁移完成: $migrated 成功, $skipped 跳过"
echo "=========================================="
echo ""

# 生成迁移清单
generate_report() {
  # 读取统一文档项目路径
  local doc_project="/root/sh"
  if [ -f ~/.claude/memory/user_doc_dir.md ]; then
    doc_project=$(grep "^路径" ~/.claude/memory/user_doc_dir.md 2>/dev/null | awk '{print $2}')
    [ -z "$doc_project" ] && doc_project="/root/sh"
  fi

  local target_dir="$doc_project/migrated-disk"
  mkdir -p "$target_dir"

  local hostname=$(hostname)
  local ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "unknown")
  local date_str=$(date '+%Y-%m-%d')
  local report_file="$target_dir/${hostname}-${ip_addr}-${date_str}-migrated.md"

  echo_info "生成迁移清单..."

  cat > "$report_file" << HEADER
# 磁盘迁移清单

## 概述

- **迁移时间**: $date_str
- **主机**: $hostname ($ip_addr)
- **成功迁移**: $migrated 个目录
- **跳过**: $skipped 个目录

## 迁移清单

| 序号 | 原始路径 | 目标路径 | 大小 | 状态 |
|------|----------|----------|------|------|
HEADER

  local idx=1
  while IFS= read -r source_dir; do
    [ -z "$source_dir" ] && continue

    dir_name=$(basename "$source_dir")
    target_path="$TARGET_DIR/$dir_name"
    size=$(du -sh "$target_path" 2>/dev/null | cut -f1 || echo "N/A")

    if [ -L "$source_dir" ]; then
      printf "| %d | \`%s\` | \`%s\` | %s | ✓ 已迁移 |\n" \
        "$idx" "$source_dir" "$target_path" "$size" >> "$report_file"
    else
      printf "| %d | \`%s\` | - | - | 跳过 |\n" \
        "$idx" "$source_dir" >> "$report_file"
    fi
    ((idx++))
  done < "$SELECTION_FILE"

  echo "" >> "$report_file"
  echo "## 目标目录" >> "$report_file"
  echo "" >> "$report_file"
  echo "所有迁移的目录都在 \`$TARGET_DIR/\` 下。" >> "$report_file"

  echo_info "清单已生成: $report_file"
}

generate_report

# 清理选择文件
rm -f "$SELECTION_FILE"

echo ""
echo "建议运行验证脚本检查迁移结果:"
echo "  bash /data/claude/claude_root/skills/my-migrate-disk/SCRIPTS/verify.sh"
