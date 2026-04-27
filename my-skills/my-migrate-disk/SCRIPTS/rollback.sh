#!/bin/bash
# 回滚脚本 - 将迁移的目录移回 /root

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

TARGET_DIR="/data/migrate-root"

echo "=========================================="
echo "磁盘迁移回滚脚本"
echo "=========================================="
echo ""

# 检查目标目录
if [ ! -d "$TARGET_DIR" ]; then
  echo_error "目标目录不存在: $TARGET_DIR"
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
  link_name=$(basename "$link")
  if [ -L "$link" ]; then
    target=$(readlink "$link")
    if [[ "$target" == "$TARGET_DIR"* ]]; then
      if [ -e "$link" ]; then
        ((idx++))
        migratable+=("$link_name")
        size=$(du -sh "$TARGET_DIR/$link_name" 2>/dev/null | cut -f1 || echo "N/A")
        echo -e "${GREEN}$idx${NC}. $link_name (软链接正常, ${size})"
      else
        broken_links+=("$link_name")
        echo -e "${RED}$idx${NC}. $link_name (软链接已断裂)"
      fi
    fi
  fi
done

if [ $idx -eq 0 ] && [ ${#broken_links[@]} -eq 0 ]; then
  echo "没有可回滚的目录"
  exit 0
fi

# 显示已断裂的软链接
if [ ${#broken_links[@]} -gt 0 ]; then
  echo ""
  echo_warn "以下软链接已断裂（目录可能丢失）："
  for name in "${broken_links[@]}"; do
    echo "  - $name"
  done
fi

echo ""
echo "请选择操作："
echo "  1. 输入编号回滚单个目录（如 1,3）"
echo "  2. 输入 'a' 回滚全部"
echo "  3. 输入 'b' 修复断裂的软链接"
echo "  4. 输入 'n' 退出"
echo -n "选择: "
read choice

rollback_single() {
  local dir_name="$1"
  local source_link="/root/$dir_name"
  local target_path="$TARGET_DIR/$dir_name"

  # 检查软链接
  if [ ! -L "$source_link" ]; then
    echo_warn "不是软链接: $source_link"
    return 1
  fi

  # 检查目标
  if [ ! -e "$target_path" ]; then
    echo_error "目标目录不存在: $target_path"
    return 1
  fi

  # 移除软链接
  rm "$source_link"

  # 移回原目录
  mv "$target_path" /root/

  if [ $? -eq 0 ]; then
    echo_info "回滚成功: $dir_name"
    return 0
  else
    echo_error "回滚失败: $dir_name"
    # 重建软链接恢复原状
    ln -s "$target_path" "$source_link"
    return 1
  fi
}

fix_broken_link() {
  local dir_name="$1"
  local source_link="/root/$dir_name"
  local target_path="$TARGET_DIR/$dir_name"

  if [ ! -e "$target_path" ]; then
    echo_error "目标目录不存在，无法修复: $target_path"
    return 1
  fi

  # 移除断裂的软链接
  rm -f "$source_link"

  # 重建软链接
  ln -s "$target_path" "$source_link"

  if [ -L "$source_link" ] && [ -e "$source_link" ]; then
    echo_info "修复成功: $source_link -> $target_path"
    return 0
  else
    echo_error "修复失败: $source_link"
    return 1
  fi
}

if [ "$choice" = "n" ] || [ "$choice" = "N" ]; then
  echo "退出"
  exit 0
fi

if [ "$choice" = "b" ] || [ "$choice" = "B" ]; then
  echo ""
  echo_info "修复断裂的软链接..."
  for name in "${broken_links[@]}"; do
    fix_broken_link "$name"
  done
  exit 0
fi

if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
  echo ""
  echo_info "回滚全部 ${#migratable[@]} 个目录..."
  for name in "${migratable[@]}"; do
    rollback_single "$name"
  done
else
  IFS=',' read -ra nums <<< "$choice"
  for num in "${nums[@]}"; do
    num=$(echo "$num" | tr -d ' ')
    if [ "$num" -ge 1 ] && [ "$num" -le $idx ]; then
      idx_minus=$((num - 1))
      rollback_single "${migratable[$idx_minus]}"
    fi
  done
fi

echo ""
echo "=========================================="
echo "回滚完成"
echo "=========================================="
