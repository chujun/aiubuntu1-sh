#!/bin/bash
# 扫描 /root 下超过指定阈值的目录

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 默认阈值 100M
THRESHOLD=${1:-100M}

echo "=========================================="
echo "目录扫描工具"
echo "=========================================="
echo ""

# 解析阈值为 KB
parse_threshold_to_kb() {
  local size="$1"
  local num="${size%[MGKmgk]*}"
  local unit="${size##*[0-9.]}"

  # 处理小数：用 awk 进行浮点运算
  case "$unit" in
    G|g) awk "BEGIN {printf \"%d\", $num * 1024 * 1024}" ;;
    M|m) awk "BEGIN {printf \"%d\", $num * 1024}" ;;
    K|k) awk "BEGIN {printf \"%d\", $num}" ;;
    *)   awk "BEGIN {printf \"%d\", $num}" ;;
  esac
}

threshold_kb=$(parse_threshold_to_kb "$THRESHOLD")
echo "阈值: $THRESHOLD ($threshold_kb KB)"
log_silent "=== scan.sh 启动 === 阈值: $THRESHOLD ($threshold_kb KB)"

# 加载排除列表
exclude_patterns=$(load_exclude_patterns)
log_silent "排除规则: $exclude_patterns"

echo ""
echo "=== 超过阈值的目录 ==="
echo ""

idx=0
declare -a candidates
declare -a candidate_sizes

# 使用 du -sk 直接获取 KB 值，避免单位解析误差
while IFS=$'\t' read -r size_kb dir; do
  [ -z "$dir" ] && continue

  # 排除软链接
  [ -L "$dir" ] && continue
  # 排除非目录
  [ ! -d "$dir" ] && continue

  # 排除模式匹配
  basename_dir=$(basename "$dir")
  echo "$basename_dir" | grep -Eq "$exclude_patterns" && continue

  # 直接用 KB 值比较阈值
  if [ "$size_kb" -ge "$threshold_kb" ]; then
    idx=$((idx + 1))
    candidates+=("$dir")
    # 获取人类可读大小用于显示
    human_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
    candidate_sizes+=("$human_size")
    echo -e "${GREEN}$idx${NC}. ${human_size}\t$dir"
  fi
done < <(du -sk /root/* /root/.* 2>/dev/null | sort -k1 -nr)

if [ $idx -eq 0 ]; then
  echo "没有超过阈值的目录"
  log_silent "扫描完成：没有超过阈值的目录"
  exit 0
fi

echo ""
echo "=========================================="
echo "找到 $idx 个目录超过阈值"
echo ""
echo -e "${BLUE}请选择要迁移的目录：${NC}"
echo "  输入编号（逗号分隔或范围）：如 1,3,5 或 1-3,5"
echo "  输入 'a' 全部迁移"
echo "  输入 'n' 退出"
echo -n "选择: "
read -r choice

# 保存选择到临时文件供 migrate.sh 使用
SELECTION_FILE="/tmp/migrate_selection.txt"
> "$SELECTION_FILE"

if [ "$choice" = "n" ] || [ "$choice" = "N" ]; then
  echo "退出"
  log_silent "用户取消扫描选择"
  exit 0
fi

# 解析选择（支持范围语法 1-3,5,7-9）
parse_selection() {
  local input="$1"
  local max="$2"
  local -a result=()

  IFS=',' read -ra parts <<< "$input"
  for part in "${parts[@]}"; do
    part=$(echo "$part" | tr -d ' ')
    if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      local start="${BASH_REMATCH[1]}"
      local end="${BASH_REMATCH[2]}"
      for ((i=start; i<=end && i<=max; i++)); do
        [ "$i" -ge 1 ] && result+=("$i")
      done
    elif [[ "$part" =~ ^[0-9]+$ ]]; then
      [ "$part" -ge 1 ] && [ "$part" -le "$max" ] && result+=("$part")
    fi
  done

  echo "${result[@]}"
}

if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
  for dir in "${candidates[@]}"; do
    echo "$dir" >> "$SELECTION_FILE"
  done
  echo "已选择全部 $idx 个目录"
  log_silent "用户选择全部 $idx 个目录"
else
  selected_nums=$(parse_selection "$choice" "$idx")
  for num in $selected_nums; do
    idx_minus=$((num - 1))
    echo "${candidates[$idx_minus]}" >> "$SELECTION_FILE"
  done
  selected_count=$(wc -l < "$SELECTION_FILE")
  echo "已选择 $selected_count 个目录"
  log_silent "用户选择 $selected_count 个目录: $choice"
fi

echo ""
echo "选择的目录："
cat "$SELECTION_FILE"
echo ""
echo "下一步：运行 migrate.sh 执行迁移"
