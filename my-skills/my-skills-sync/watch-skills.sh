#!/bin/bash
# 监听 my-* skills 变化并自动同步
# 用法: ./watch-skills.sh

SOURCE_DIR="$HOME/.claude/skills"
TARGET_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$(dirname "$0")/watch.log"
PID_FILE="$(dirname "$0")/watch.pid"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

start_watch() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        log "监控进程已在运行 (PID: $(cat "$PID_FILE"))"
        return 1
    fi

    log "启动文件监控..."

    # 首次同步
    bash "$(dirname "$0")/sync-skills.sh"

    # 监听变化
    inotifywait -m -r \
        --exclude '(\.git|swp|swo)' \
        -e modify,create,delete,move \
        "$SOURCE_DIR" 2>/dev/null | while read path action file; do

        # 检查是否是 my-* 相关的变化
        if echo "$path" | grep -q "my-"; then
            log "检测到变化: $path $action $file"
            bash "$(dirname "$0")/sync-skills.sh"
        fi
    done &

    echo $! > "$PID_FILE"
    log "监控进程已启动 (PID: $(cat "$PID_FILE"))"
}

stop_watch() {
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log "监控进程已停止 (PID: $pid)"
        fi
        rm -f "$PID_FILE"
    fi
}

status_watch() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "监控进程运行中 (PID: $(cat "$PID_FILE"))"
    else
        echo "监控进程未运行"
    fi
}

case "${1:-start}" in
    start)
        start_watch
        ;;
    stop)
        stop_watch
        ;;
    restart)
        stop_watch
        sleep 1
        start_watch
        ;;
    status)
        status_watch
        ;;
    sync)
        bash "$(dirname "$0")/sync-skills.sh"
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|sync}"
        exit 1
        ;;
esac
