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

# 解析阈值（支持 M, G, K 后缀）
parse_size() {
  local size="$1"
  local num="${size%[MGKmgk]*}"
  local unit="${size##*[0-9]}"

  case "$unit" in
    G|g) echo $((num * 1024 * 1024)) ;;
    M|m) echo $((num * 1024)) ;;
    K|k) echo $num ;;
    *) echo $num ;;
  esac
}

threshold_bytes=$(parse_size "$THRESHOLD")
echo "阈值: $THRESHOLD ($threshold_bytes KB)"

# 扫描 /root 下的目录（排除软链接和特殊目录）
echo ""
echo "=== 超过阈值的目录 ==="
echo ""

idx=0
declare -a candidates
declare -a candidate_sizes
declare -a candidate_names

while IFS= read -r line; do
  size=$(echo "$line" | awk '{print $1}')
  dir=$(echo "$line" | awk '{print $2}')

  # 排除已经是软链接的目录
  if [ -L "$dir" ]; then
    continue
  fi

  # 排除不是目录的
  if [ ! -d "$dir" ]; then
    continue
  fi

  # 排除系统目录
  basename_dir=$(basename "$dir")
  case "$basename_dir" in
    .|..|.config|.ssh|.pki|.mozilla|.modelscope|sh|cj_test|Downloads)
      continue
      ;;
  esac

  # 解析大小
  size_num="${size%[KMG]}"
  size_unit="${size#[0-9.]}"

  case "$size_unit" in
    G) size_bytes=$(echo "$size_num * 1024 * 1024" | bc 2>/dev/null | cut -d. -f1) ;;
    M) size_bytes=$(echo "$size_num * 1024" | bc 2>/dev/null | cut -d. -f1) ;;
    K) size_bytes=$(echo "$size_num" | cut -d. -f1) ;;
    *) size_bytes=0 ;;
  esac

  # 比较阈值
  if [ "$size_bytes" -ge "$threshold_bytes" ]; then
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
  # 全部选择
  for dir in "${candidates[@]}"; do
    echo "$dir" >> "$SELECTION_FILE"
  done
  echo "已选择全部 $idx 个目录"
else
  # 解析编号
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
