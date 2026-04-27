#!/bin/bash
# 公共模块 - 颜色定义、日志函数、通用工具
# 所有脚本通过 source common.sh 引用

# ========== 严格模式 ==========
set -euo pipefail

# ========== 颜色定义 ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ========== 常量 ==========
TARGET_DIR="/data/migrate-root"
LOG_FILE="/var/log/migrate-disk.log"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$SKILL_DIR/config"
EXCLUDE_CONF="$CONFIG_DIR/exclude.conf"

# ========== 输出函数 ==========
check_ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
check_fail() { echo -e "${RED}[✗]${NC} $1"; }
check_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
echo_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ========== 日志函数 ==========
# 同时输出到终端和日志文件
log_info() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
  echo "$msg" >> "$LOG_FILE"
  echo_info "$1"
}

log_warn() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1"
  echo "$msg" >> "$LOG_FILE"
  echo_warn "$1"
}

log_error() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
  echo "$msg" >> "$LOG_FILE"
  echo_error "$1"
}

# 仅写日志不输出到终端
log_silent() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 初始化日志文件（确保目录和文件存在）
init_log() {
  local log_dir
  log_dir=$(dirname "$LOG_FILE")
  mkdir -p "$log_dir" 2>/dev/null || true
  touch "$LOG_FILE" 2>/dev/null || true
}

# ========== 排除列表加载 ==========
# 从配置文件加载排除目录列表，返回 grep -E 格式的正则
load_exclude_patterns() {
  local patterns="^\.$|^\.\.$"

  if [ -f "$EXCLUDE_CONF" ]; then
    while IFS= read -r line; do
      # 跳过空行和注释
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      line=$(echo "$line" | xargs)  # trim
      [ -n "$line" ] && patterns="$patterns|^${line}$"
    done < "$EXCLUDE_CONF"
  else
    # 默认排除列表（配置文件不存在时的回退）
    patterns="$patterns|^\.config$|^\.ssh$|^\.pki$|^sh$"
  fi

  echo "$patterns"
}

# ========== 磁盘空间检查 ==========
# 检查目标分区是否有足够空间
# 参数: $1 = 需要的空间(KB)
# 返回: 0=空间足够, 1=空间不足
check_disk_space() {
  local needed_kb="$1"
  local target_mount
  target_mount=$(df "$TARGET_DIR" 2>/dev/null | tail -1 | awk '{print $4}')

  if [ -z "$target_mount" ]; then
    log_error "无法获取 $TARGET_DIR 所在分区的空间信息"
    return 1
  fi

  if [ "$target_mount" -lt "$needed_kb" ]; then
    local needed_human available_human
    needed_human=$(numfmt --to=iec --suffix=B "$((needed_kb * 1024))" 2>/dev/null || echo "${needed_kb}K")
    available_human=$(numfmt --to=iec --suffix=B "$((target_mount * 1024))" 2>/dev/null || echo "${target_mount}K")
    log_error "目标分区空间不足！需要: $needed_human, 可用: $available_human"
    return 1
  fi

  return 0
}

# 调用初始化
init_log
