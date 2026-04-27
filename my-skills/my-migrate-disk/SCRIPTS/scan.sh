#!/bin/bash
# 扫描 /root 下超过指定阈值的目录

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 默认阈值 100M
THRESHOLD=${1:-100M}

echo "=========================================="
echo "目录扫描工具"
echo "=========================================="
echo ""

# 纯 bash 解析阈值（避免 bc 依赖）
parse_size_to_bytes() {
  local size="$1"
  local num="${size%[MGKmgk]*}"
  local unit="${size##*[0-9]}"

  # 去除小数点，转为整数计算
  num=$(echo "$num" | tr -d '.')

  case "$unit" in
    G|g) echo $((num * 1024 * 1024)) ;;
    M|m) echo $((num * 1024)) ;;
    K|k) echo $num ;;
    *)   echo $num ;;
  esac
}

# 解析目录大小（如 "2.3G" -> 2411724, "500M" -> 512000）
parse_dir_size() {
  local size="$1"
  local num="${size%[KMG]}"
  local unit="${size#[0-9.]*}"

  # 处理小数，转为整数（放大1000倍避免浮点）
  local int_num=$(echo "$num" | tr -d '.')

  case "$unit" in
    G)
      # G 单位：int_num * 1024 * 1024
      echo $((int_num * 1024))
      ;;
    M)
      # M 单位：int_num * 1024
      echo $int_num
      ;;
    K)
      # K 单位：直接返回
      echo $((int_num / 1000))
      ;;
    *)
      # 无单位，假设是 KB
      echo $((int_num / 1000))
      ;;
  esac
}

threshold_bytes=$(parse_size_to_bytes "$THRESHOLD")
echo "阈值: $THRESHOLD ($threshold_bytes KB)"

# 扫描 /root 下的目录
echo ""
echo "=== 超过阈值的目录 ==="
echo ""

idx=0
declare -a candidates
declare -a candidate_sizes
declare -a candidate_names

# 排除的目录模式
exclude_patterns="^\.$|^\.\.$|^\.config$|^\.ssh$|^\.pki$|^\.mozilla$|^\.modelscope$|^sh$|^cj_test$|^Downloads$"

while IFS= read -r line; do
  [ -z "$line" ] && continue

  size=$(echo "$line" | awk '{print $1}')
  dir=$(echo "$line" | awk '{print $2}')

  # 排除软链接
  [ -L "$dir" ] && continue
  # 排除非目录
  [ ! -d "$dir" ] && continue

  # 排除模式匹配
  basename_dir=$(basename "$dir")
  echo "$basename_dir" | grep -Eq "$exclude_patterns" && continue

  # 解析目录大小（KB）
  size_kb=$(parse_dir_size "$size")

  # 比较阈值
  if [ "$size_kb" -ge "$threshold_bytes" ]; then
    ((idx++))
    candidates+=("$dir")
    candidate_sizes+=("$size")
    candidate_names+=("$basename_dir")
    echo -e "${GREEN}$idx${NC}. ${size}\t$dir"
  fi
done < <(du -sh /root/* /root/.* 2>/dev/null | grep -v "/root/\.$" | sort -hr)

if [ $idx -eq 0 ]; then
  echo "没有超过阈值的目录"
  exit 0
fi

echo ""
echo "=========================================="
echo "找到 $idx 个目录超过阈值"
echo ""
echo -e "${BLUE}请选择要迁移的目录：${NC}"
echo "  输入编号（逗号分隔）：如 1,3,5"
echo "  输入 'a' 全部迁移"
echo "  输入 'n' 退出"
echo -n "选择: "
read choice

# 保存选择到临时文件供 migrate.sh 使用
SELECTION_FILE="/tmp/migrate_selection.txt"
> "$SELECTION_FILE"

if [ "$choice" = "n" ] || [ "$choice" = "N" ]; then
  echo "退出"
  exit 0
fi

if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
  for dir in "${candidates[@]}"; do
    echo "$dir" >> "$SELECTION_FILE"
  done
  echo "已选择全部 $idx 个目录"
else
  IFS=',' read -ra nums <<< "$choice"
  for num in "${nums[@]}"; do
    num=$(echo "$num" | tr -d ' ')
    if [ "$num" -ge 1 ] && [ "$num" -le $idx ]; then
      idx_minus=$((num - 1))
      echo "${candidates[$idx_minus]}" >> "$SELECTION_FILE"
    fi
  done
  echo "已选择 $(cat "$SELECTION_FILE" | wc -l) 个目录"
fi

echo ""
echo "选择的目录："
cat "$SELECTION_FILE"
echo ""
echo "下一步：运行 migrate.sh 执行迁移"
