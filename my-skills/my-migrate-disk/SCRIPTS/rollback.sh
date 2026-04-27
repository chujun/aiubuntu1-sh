#!/bin/bash
# 回滚脚本 - 将迁移的目录移回 /root

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

echo "=========================================="
echo "磁盘迁移回滚脚本"
echo "=========================================="
echo ""

log_silent "=== rollback.sh 启动 ==="

# 检查目标目录
if [ ! -d "$TARGET_DIR" ]; then
  log_error "目标目录不存在: $TARGET_DIR"
  exit 1
fi

# 列出可回滚的目录
echo "=== 可回滚的目录 ==="
echo ""

idx=0
declare -a migratable
declare -a broken_links

# 检查软链接
for link in /root/*/; do
  link="${link%/}"  # 去尾部斜杠
  [ ! -L "$link" ] && continue

  link_name=$(basename "$link")
  target=$(readlink "$link")

  if [[ "$target" == "$TARGET_DIR"* ]]; then
    if [ -e "$link" ]; then
      idx=$((idx + 1))
      migratable+=("$link_name")
      size=$(du -sh "$TARGET_DIR/$link_name" 2>/dev/null | cut -f1 || echo "N/A")
      echo -e "${GREEN}$idx${NC}. $link_name (软链接正常, ${size})"
    else
      broken_links+=("$link_name")
    fi
  fi
done

# 也检查隐藏目录的软链接
for link in /root/.*; do
  [ ! -L "$link" ] && continue
  link_name=$(basename "$link")
  [[ "$link_name" == "." || "$link_name" == ".." ]] && continue

  target=$(readlink "$link")
  if [[ "$target" == "$TARGET_DIR"* ]]; then
    if [ -e "$link" ]; then
      idx=$((idx + 1))
      migratable+=("$link_name")
      size=$(du -sh "$TARGET_DIR/$link_name" 2>/dev/null | cut -f1 || echo "N/A")
      echo -e "${GREEN}$idx${NC}. $link_name (软链接正常, ${size})"
    else
      broken_links+=("$link_name")
    fi
  fi
done

if [ $idx -eq 0 ] && ( [ -z "${broken_links+x}" ] || [ "${#broken_links[@]}" -eq 0 ] ); then
  echo "没有可回滚的目录"
  exit 0
fi

# 显示已断裂的软链接
if [ -n "${broken_links+x}" ] && [ "${#broken_links[@]}" -gt 0 ]; then
  echo ""
  echo_warn "以下软链接已断裂（目标不存在）："
  for i in "${!broken_links[@]}"; do
    local_name="${broken_links[$i]}"
    target=$(readlink "/root/$local_name" 2>/dev/null || echo "unknown")
    echo -e "  ${RED}$((i+1))${NC}. $local_name -> $target"
  done
fi

echo ""
echo "请选择操作："
echo "  输入编号回滚单个目录（如 1,3）"
echo "  输入 'a' 回滚全部正常目录"
if [ -n "${broken_links+x}" ] && [ "${#broken_links[@]}" -gt 0 ]; then
  echo "  输入 'b' 处理断裂的软链接"
fi
echo "  输入 'n' 退出"
echo -n "选择: "
read -r choice

rollback_single() {
  local dir_name="$1"
  local source_link="/root/$dir_name"
  local target_path="$TARGET_DIR/$dir_name"

  # 检查软链接
  if [ ! -L "$source_link" ]; then
    log_warn "不是软链接: $source_link"
    return 1
  fi

  # 检查目标
  if [ ! -e "$target_path" ]; then
    log_error "目标目录不存在: $target_path"
    return 1
  fi

  # 检查 /root 分区是否有足够空间
  local dir_size_kb
  dir_size_kb=$(du -sk "$target_path" 2>/dev/null | cut -f1)
  local root_avail_kb
  root_avail_kb=$(df /root 2>/dev/null | tail -1 | awk '{print $4}')

  if [ "$root_avail_kb" -lt "$dir_size_kb" ]; then
    log_error "根分区空间不足，无法回滚 $dir_name (需要 ${dir_size_kb}K, 可用 ${root_avail_kb}K)"
    return 1
  fi

  # 移除软链接
  rm "$source_link"

  # 移回原目录
  if mv "$target_path" /root/; then
    log_info "回滚成功: $dir_name"
    return 0
  else
    log_error "回滚失败: $dir_name"
    # 重建软链接恢复原状
    ln -s "$target_path" "$source_link"
    return 1
  fi
}

handle_broken_links() {
  echo ""
  echo "=== 处理断裂的软链接 ==="
  echo ""

  for i in "${!broken_links[@]}"; do
    local name="${broken_links[$i]}"
    local link_path="/root/$name"
    local expected_target="$TARGET_DIR/$name"
    local actual_target
    actual_target=$(readlink "$link_path" 2>/dev/null)

    echo -e "${YELLOW}断链${NC}: $link_path -> $actual_target"
    echo "  请选择操作："
    echo "    1. 删除此断链"
    echo "    2. 创建空目录替代"
    if [ -d "$expected_target" ]; then
      echo "    3. 重建软链接（目标存在: $expected_target）"
    fi
    echo "    s. 跳过"
    echo -n "  选择: "
    read -r sub_choice

    case "$sub_choice" in
      1)
        rm -f "$link_path"
        log_info "已删除断链: $link_path"
        ;;
      2)
        rm -f "$link_path"
        mkdir -p "$link_path"
        log_info "已创建空目录替代: $link_path"
        ;;
      3)
        if [ -d "$expected_target" ]; then
          rm -f "$link_path"
          ln -s "$expected_target" "$link_path"
          if [ -e "$link_path" ]; then
            log_info "重建软链接成功: $link_path -> $expected_target"
          else
            log_error "重建软链接失败: $link_path"
          fi
        else
          log_error "目标目录不存在，无法重建: $expected_target"
        fi
        ;;
      s|S)
        echo_info "跳过: $name"
        ;;
      *)
        echo_info "跳过: $name"
        ;;
    esac
    echo ""
  done
}

if [ "$choice" = "n" ] || [ "$choice" = "N" ]; then
  echo "退出"
  exit 0
fi

if [ "$choice" = "b" ] || [ "$choice" = "B" ]; then
  if [ -z "${broken_links+x}" ] || [ "${#broken_links[@]}" -eq 0 ]; then
    echo_info "没有断裂的软链接"
  else
    handle_broken_links
  fi
  exit 0
fi

if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
  echo ""
  log_info "回滚全部 ${#migratable[@]} 个目录..."
  log_silent "用户选择回滚全部 ${#migratable[@]} 个目录"
  for name in "${migratable[@]}"; do
    rollback_single "$name"
  done
else
  IFS=',' read -ra nums <<< "$choice"
  for num in "${nums[@]}"; do
    num=$(echo "$num" | tr -d ' ')
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le $idx ]; then
      idx_minus=$((num - 1))
      rollback_single "${migratable[$idx_minus]}"
    fi
  done
fi

echo ""
echo "=========================================="
echo "回滚完成"
echo "=========================================="
log_silent "=== rollback.sh 完成 ==="
