#!/bin/bash
# 迁移脚本 - 根据 scan.sh 的选择执行迁移

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SELECTION_FILE="/tmp/migrate_selection.txt"
TARGET_DIR="/data/migrate-root"

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
echo_info "将迁移 $selected_count 个目录到 $TARGET_DIR"
echo ""

# 创建目标目录
mkdir -p "$TARGET_DIR"
echo_info "目标目录: $TARGET_DIR"

# 迁移每个选中的目录
migrated=0
skipped=0
conflicts=0

resolve_conflict() {
  local source_dir="$1"
  local target_path="$2"
  local dir_name=$(basename "$source_dir")

  echo ""
  echo_warn "目标目录已存在: $target_path"
  echo "请选择操作："
  echo "  1. 跳过此目录"
  echo "  2. 备份后覆盖（将原目录重命名为 ${dir_name}.bak）"
  echo "  3. 合并目录（将源目录内容移动到目标目录）"
  echo -n "选择 [1-3]: "
  read choice

  case "$choice" in
    1) return 1 ;;  # 跳过
    2)
      # 备份原目标目录
      local backup_path="${target_path}.bak.$(date +%Y%m%d%H%M%S)"
      mv "$target_path" "$backup_path"
      echo_info "已备份到: $backup_path"
      return 0  # 继续迁移
      ;;
    3)
      # 合并目录：移动源内容到目标，删除源空目录
      mv "${source_dir}"/* "${target_path}/" 2>/dev/null
      rmdir "$source_dir" 2>/dev/null
      echo_info "已合并到: $target_path"
      return 2  # 已完成
      ;;
    *) return 1 ;;  # 默认跳过
  esac
}

while IFS= read -r source_dir; do
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

  # 检查目标是否已存在（冲突）
  if [ -e "$target_path" ]; then
    action=$(resolve_conflict "$source_dir" "$target_path")
    result=$?

    if [ $result -eq 1 ]; then
      echo_info "跳过: $source_dir"
      ((skipped++))
      ((conflicts++))
      continue
    elif [ $result -eq 2 ]; then
      # 合并模式，已经完成
      ((migrated++))
      continue
    fi
    # result=0 继续执行迁移
  fi

  # 执行迁移
  mv "$source_dir" "$target_path"
  if [ $? -eq 0 ]; then
    ln -s "$target_path" "$source_dir"
    echo_info "迁移成功: $source_dir -> $target_path"
    ((migrated++))
  else
    echo_error "迁移失败: $source_dir"
  fi

done < "$SELECTION_FILE"

echo ""
echo "=========================================="
echo "迁移完成: $migrated 成功, $skipped 跳过, $conflicts 冲突"
echo "=========================================="
echo ""

# 生成迁移清单
generate_report() {
  local doc_project="/root/sh"
  if [ -f ~/.claude/memory/user_doc_dir.md ]; then
    doc_project=$(grep "^路径" ~/.claude/memory/user_doc_dir.md 2>/dev/null | awk '{print $2}')
    [ -z "$doc_project" ] && doc_project="/root/sh"
  fi

  local target_dir_path="$doc_project/migrated-disk"
  mkdir -p "$target_dir_path"

  local hostname=$(hostname)
  local ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "unknown")
  local date_str=$(date '+%Y-%m-%d')
  local report_file="$target_dir_path/${hostname}-${ip_addr}-${date_str}-migrated.md"

  echo_info "生成迁移清单..."

  cat > "$report_file" << HEADER
# 磁盘迁移清单

## 概述

- **迁移时间**: $date_str
- **主机**: $hostname ($ip_addr)
- **目标目录**: $TARGET_DIR
- **成功迁移**: $migrated 个目录
- **跳过**: $skipped 个目录
- **冲突处理**: $conflicts 个目录

## 迁移清单

| 序号 | 原始路径 | 目标路径 | 大小 | 状态 |
|------|----------|----------|------|------|
HEADER

  local idx=1
  while IFS= read -r source_dir; do
    [ -z "$source_dir" ] && continue

    dir_name=$(basename "$source_dir")
    target_path="$TARGET_DIR/$dir_name"

    if [ -e "$target_path" ]; then
      size=$(du -sh "$target_path" 2>/dev/null | cut -f1 || echo "N/A")
    else
      size="-"
    fi

    if [ -L "$source_dir" ] && [ -e "$source_dir" ]; then
      status="✓ 已迁移"
    else
      status="跳过"
    fi

    printf "| %d | \`%s\` | \`%s\` | %s | %s |\n" \
      "$idx" "$source_dir" "$target_path" "$size" "$status" >> "$report_file"
    ((idx++))
  done < "$SELECTION_FILE"

  echo "" >> "$report_file"
  echo "## 回滚说明" >> "$report_file"
  echo "" >> "$report_file"
  echo "如需回滚，执行：" >> "$report_file"
  echo "\`\`\`bash" >> "$report_file"
  echo "# 移除软链接" >> "$report_file"
  echo "rm /root/\\`<dir>\\`" >> "$report_file"
  echo "" >> "$report_file"
  echo "# 移回原目录" >> "$report_file"
  echo "mv $TARGET_DIR/\\`<dir>\\` /root/" >> "$report_file"
  echo "\`\`\`" >> "$report_file"

  echo_info "清单已生成: $report_file"
}

generate_report

# 清理选择文件
rm -f "$SELECTION_FILE"

echo ""
echo "建议运行验证脚本检查迁移结果:"
echo "  bash /data/claude/claude_root/skills/my-migrate-disk/SCRIPTS/verify.sh"
