#!/bin/bash
# 同步 my-* skills 到本地目录
# 用法: ./sync-skills.sh

SOURCE_DIR="$HOME/.claude/skills"
TARGET_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="$(dirname "$0")/sync.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "开始同步 my-* skills..."

# 获取所有 my- 开头的 skill
my_skills=$(find "$SOURCE_DIR" -maxdepth 1 -type d -name "my-*" 2>/dev/null | xargs -r basename -a)

if [ -z "$my_skills" ]; then
    log "未找到 my-* skills"
    exit 0
fi

for skill in $my_skills; do
    source_path="$SOURCE_DIR/$skill"
    target_path="$TARGET_DIR/$skill"

    if [ -d "$source_path" ]; then
        # 使用 rsync 同步，保持目录结构
        rsync -avz --delete "$source_path/" "$target_path/"
        log "已同步: $skill"
    fi
done

log "同步完成"
