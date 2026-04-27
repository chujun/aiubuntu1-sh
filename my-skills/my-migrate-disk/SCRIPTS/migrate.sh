#!/bin/bash
# 迁移脚本 - 根据 scan.sh 的选择执行迁移

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

SELECTION_FILE="/tmp/migrate_selection.txt"

# 检查选择文件
if [ ! -f "$SELECTION_FILE" ]; then
  log_error "未找到选择文件，请先运行 scan.sh"
  echo "示例：bash $SCRIPT_DIR/scan.sh 100M"
  exit 1
fi

selected_count=$(wc -l < "$SELECTION_FILE")
if [ "$selected_count" -eq 0 ]; then
  log_error "没有选择任何目录"
  exit 1
fi

echo "=========================================="
echo "磁盘迁移脚本"
echo "=========================================="
echo ""
log_info "将迁移 $selected_count 个目录到 $TARGET_DIR"
echo ""

# ========== 磁盘空间预检 ==========
echo "=== 磁盘空间预检 ==="

# 创建目标目录（预检需要分区存在）
mkdir -p "$TARGET_DIR"

# 计算所有待迁移目录的总大小（KB）
total_needed_kb=0
while IFS= read -r source_dir; do
  [ -z "$source_dir" ] && continue
  [ -L "$source_dir" ] && continue
  [ ! -e "$source_dir" ] && continue
  dir_size_kb=$(du -sk "$source_dir" 2>/dev/null | cut -f1)
  total_needed_kb=$((total_needed_kb + dir_size_kb))
done < "$SELECTION_FILE"

total_needed_human=$(numfmt --to=iec --suffix=B "$((total_needed_kb * 1024))" 2>/dev/null || echo "${total_needed_kb}K")
log_info "待迁移总大小: $total_needed_human"

# 获取目标分区可用空间
available_kb=$(df "$TARGET_DIR" 2>/dev/null | tail -1 | awk '{print $4}')
available_human=$(numfmt --to=iec --suffix=B "$((available_kb * 1024))" 2>/dev/null || echo "${available_kb}K")
log_info "目标分区可用: $available_human"

# 预留 10% 安全余量
safe_needed_kb=$((total_needed_kb * 110 / 100))

if [ "$available_kb" -lt "$safe_needed_kb" ]; then
  log_error "目标分区空间不足！需要: $total_needed_human (含10%余量), 可用: $available_human"
  log_error "请清理 $TARGET_DIR 所在分区后重试"
  rm -f "$SELECTION_FILE"
  exit 1
fi

log_info "空间预检通过 ✓"
echo ""

log_silent "=== migrate.sh 启动 === 迁移 $selected_count 个目录到 $TARGET_DIR"

# ========== 迁移执行 ==========
migrated=0
skipped=0
conflicts=0

resolve_conflict() {
  local source_dir="$1"
  local target_path="$2"
  local dir_name
  dir_name=$(basename "$source_dir")

  echo ""
  echo_warn "目标目录已存在: $target_path"
  echo "请选择操作："
  echo "  1. 跳过此目录"
  echo "  2. 备份后覆盖（将原目录重命名为 ${dir_name}.bak）"
  echo "  3. 合并目录（将源目录内容移动到目标目录）"
  echo -n "选择 [1-3]: "
  read -r choice

  case "$choice" in
    1) return 1 ;;  # 跳过
    2)
      local backup_path="${target_path}.bak.$(date +%Y%m%d%H%M%S)"
      mv "$target_path" "$backup_path"
      log_info "已备份到: $backup_path"
      return 0  # 继续迁移
      ;;
    3)
      # 合并目录：使用 rsync 保证完整性（回退到 cp+rm）
      if command -v rsync &>/dev/null; then
        rsync -a "${source_dir}/" "${target_path}/"
        if [ $? -eq 0 ]; then
          rm -rf "$source_dir"
          log_info "已合并到（rsync）: $target_path"
        else
          log_error "rsync 合并失败，保留源目录: $source_dir"
          return 1
        fi
      else
        cp -a "${source_dir}"/* "${target_path}/" 2>/dev/null
        cp -a "${source_dir}"/.[!.]* "${target_path}/" 2>/dev/null
        rm -rf "$source_dir"
        log_info "已合并到（cp）: $target_path"
      fi
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
    log_warn "跳过（已是软链接）: $source_dir"
    ((skipped++))
    continue
  fi

  # 检查源是否存在
  if [ ! -e "$source_dir" ]; then
    log_warn "跳过（不存在）: $source_dir"
    ((skipped++))
    continue
  fi

  # 检查目标是否已存在（冲突）
  if [ -e "$target_path" ]; then
    resolve_conflict "$source_dir" "$target_path"
    result=$?

    if [ $result -eq 1 ]; then
      log_info "跳过: $source_dir"
      ((skipped++))
      ((conflicts++))
      continue
    elif [ $result -eq 2 ]; then
      # 合并模式完成，创建软链接
      ln -s "$target_path" "$source_dir"
      ((migrated++))
      ((conflicts++))
      continue
    fi
    ((conflicts++))
  fi

  # 执行迁移
  mv "$source_dir" "$target_path"
  if [ $? -eq 0 ]; then
    ln -s "$target_path" "$source_dir"
    log_info "迁移成功: $source_dir -> $target_path"
    ((migrated++))
  else
    log_error "迁移失败: $source_dir"
  fi

done < "$SELECTION_FILE"

echo ""
echo "=========================================="
echo "迁移完成: $migrated 成功, $skipped 跳过, $conflicts 冲突"
echo "=========================================="
echo ""

log_silent "迁移结果: $migrated 成功, $skipped 跳过, $conflicts 冲突"

# ========== 生成迁移清单 ==========
generate_report() {
  local doc_project="/root/sh"
  if [ -f ~/.claude/memory/user_doc_dir.md ]; then
    local mem_path
    mem_path=$(grep "^路径" ~/.claude/memory/user_doc_dir.md 2>/dev/null | awk '{print $2}')
    [ -n "$mem_path" ] && doc_project="$mem_path"
  fi

  local target_dir_path="$doc_project/migrated-disk"
  mkdir -p "$target_dir_path"

  local hostname_str
  hostname_str=$(hostname)
  local ip_addr
  ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "unknown")
  local date_str
  date_str=$(date '+%Y-%m-%d')
  local report_file="$target_dir_path/${hostname_str}-${ip_addr}-${date_str}-migrated.md"

  log_info "生成迁移清单..."

  cat > "$report_file" << HEADER
# 磁盘迁移清单

## 概述

- **迁移时间**: $date_str
- **主机**: $hostname_str ($ip_addr)
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
    idx=$((idx + 1))
  done < "$SELECTION_FILE"

  echo "" >> "$report_file"
  echo "## 回滚说明" >> "$report_file"
  echo "" >> "$report_file"
  echo "如需回滚，执行：" >> "$report_file"
  echo "\`\`\`bash" >> "$report_file"
  echo "bash $SCRIPT_DIR/rollback.sh" >> "$report_file"
  echo "\`\`\`" >> "$report_file"

  log_info "清单已生成: $report_file"
}

generate_report

# 清理选择文件
rm -f "$SELECTION_FILE"

echo ""
echo "建议运行验证脚本检查迁移结果:"
echo "  bash $SCRIPT_DIR/verify.sh"
