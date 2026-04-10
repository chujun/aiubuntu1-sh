#!/usr/bin/env bash
# cc-model.sh — Claude Code 多模型切换工具
# 原理: 修改 ~/.claude/settings.json 中的 model / env.ANTHROPIC_API_KEY / env.ANTHROPIC_BASE_URL
# 非 Claude 模型通过 OpenRouter 或各自兼容端点接入
#
# 用法:
#   cc-model switch <model>   永久切换默认模型（写入 settings.json）
#   cc-model run <model> [args...]  临时用指定模型启动 claude（不改 settings）
#   cc-model restore [n]      恢复 settings.json 到第 n 个备份（默认最近一个）
#   cc-model current          显示当前模型
#   cc-model list             列出所有支持的模型
#   cc-model token set <provider> <token>   保存 token
#   cc-model token list       查看已配置的 provider

set -euo pipefail

# ────────────── 路径 ──────────────
SETTINGS_FILE="${HOME}/.claude/settings.json"
TOKEN_FILE="${HOME}/.config/cc-model/tokens"
CONFIG_DIR="${HOME}/.config/cc-model"
BACKUP_DIR="${HOME}/.config/cc-model/backups"
BACKUP_KEEP=5   # 每个文件最多保留的备份份数

# ────────────── 模型表 ──────────────
# 格式: provider|model_id|base_url
# base_url 为空 = 使用 Anthropic 官方端点
declare -A MODEL_PROVIDER=(
    [claude]="anthropic"
    [claude-opus]="anthropic"
    [claude-sonnet]="anthropic"
    [claude-haiku]="anthropic"
    [chatgpt]="openrouter"
    [gemini]="openrouter"
    [glm]="openrouter"
    [minimax-m2.7]="openrouter"
    [minimax-cn]="minimax"
)

declare -A MODEL_ID=(
    [claude]="claude-opus-4-6"
    [claude-opus]="claude-opus-4-6"
    [claude-sonnet]="claude-sonnet-4-6"
    [claude-haiku]="claude-haiku-4-5-20251001"
    [chatgpt]="openai/gpt-4o"
    [gemini]="google/gemini-2.5-pro-preview-03-25"
    [glm]="thudm/glm-4-32b"
    [minimax-m2.7]="minimax/minimax-m2"
    [minimax-cn]="MiniMax-M2.7-highspeed"
)

declare -A PROVIDER_BASE_URL=(
    [anthropic]=""                                   # 空 = 官方，不写入 settings
    [openrouter]="https://openrouter.ai/api/v1"      # OpenRouter 兼容 Anthropic SDK
    [minimax]="https://api.minimaxi.com/anthropic"   # MiniMax 国内 Anthropic 兼容端点
)

# 需要使用 ANTHROPIC_AUTH_TOKEN（而非 ANTHROPIC_API_KEY）的 provider
declare -A PROVIDER_AUTH_TOKEN_KEY=(
    [minimax]="ANTHROPIC_AUTH_TOKEN"
)

# ────────────── 工具 ──────────────
info()  { printf '\033[32m[INFO]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[33m[WARN]\033[0m  %s\n' "$*" >&2; }
error() { printf '\033[31m[ERR]\033[0m   %s\n' "$*" >&2; exit 1; }

ensure_config() {
    mkdir -p "${CONFIG_DIR}"
    chmod 700 "${CONFIG_DIR}"
}

# 备份文件，自动清理超出 BACKUP_KEEP 的旧备份
# 用法: backup_file <文件路径>
# 文件不存在时静默跳过（首次创建无需备份）
backup_file() {
    local file="$1"
    [[ -f "${file}" ]] || return 0

    mkdir -p "${BACKUP_DIR}"
    local base ts backup
    base="$(basename "${file}")"
    ts="$(date +%Y%m%d_%H%M%S)"
    backup="${BACKUP_DIR}/${base}.bak.${ts}"

    cp "${file}" "${backup}"
    info "已备份 → ${backup}"

    # 清理超出保留数量的旧备份（按时间从旧到新排序后删除末尾）
    local -a old_backups
    mapfile -t old_backups < <(ls -t "${BACKUP_DIR}/${base}.bak."* 2>/dev/null | tail -n +$((BACKUP_KEEP + 1)))
    local f
    for f in "${old_backups[@]}"; do
        rm -f "${f}"
        info "已清理旧备份: $(basename "${f}")"
    done
}

# 验证模型名合法
validate_model() {
    local m="$1"
    [[ -v MODEL_ID["${m}"] ]] || error "不支持的模型: ${m}。运行 cc-model list 查看支持列表"
}

# 从 token 文件读取指定 provider 的 token
get_token() {
    local provider="$1"
    [[ -f "${TOKEN_FILE}" ]] || error "尚未配置任何 token，请先运行: cc-model token set <provider> <token>"
    local token
    token=$(grep -E "^${provider}=" "${TOKEN_FILE}" 2>/dev/null | cut -d'=' -f2-)
    [[ -n "${token}" ]] || error "未找到 [${provider}] 的 token，请运行: cc-model token set ${provider} <token>"
    echo "${token}"
}

# 读取 settings.json（无则返回 {}）
read_settings() {
    if [[ -f "${SETTINGS_FILE}" ]]; then
        cat "${SETTINGS_FILE}"
    else
        echo '{}'
    fi
}

# 写入 settings.json（保留已有字段，只更新指定路径）
write_settings() {
    local new_json="$1"
    mkdir -p "$(dirname "${SETTINGS_FILE}")"
    backup_file "${SETTINGS_FILE}"
    echo "${new_json}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(json.dumps(data, indent=2, ensure_ascii=False))
" > "${SETTINGS_FILE}"
}

# ────────────── token 管理 ──────────────
cmd_token() {
    local action="${1:-help}"; shift || true
    case "${action}" in
        set)
            local provider="${1:-}"; shift || true
            [[ -n "${provider}" ]] || { error "用法: cc-model token set <provider> <token>"; return 1; }
            local token="${1:-}"; shift || true
            [[ -n "${token}" ]] || { error "用法: cc-model token set ${provider} <token>"; return 1; }
            ensure_config
            touch "${TOKEN_FILE}"
            chmod 600 "${TOKEN_FILE}"
            backup_file "${TOKEN_FILE}"
            if grep -qE "^${provider}=" "${TOKEN_FILE}" 2>/dev/null; then
                sed -i "s|^${provider}=.*|${provider}=${token}|" "${TOKEN_FILE}"
            else
                echo "${provider}=${token}" >> "${TOKEN_FILE}"
            fi
            info "已保存 [${provider}] token（文件权限 600）"
            ;;
        del|delete)
            local provider="${1:-}"
            [[ -n "${provider}" ]] || { error "用法: cc-model token del <provider>"; return 1; }
            [[ -f "${TOKEN_FILE}" ]] && sed -i "/^${provider}=/d" "${TOKEN_FILE}"
            info "已删除 [${provider}] token"
            ;;
        list)
            [[ -f "${TOKEN_FILE}" ]] || { info "暂无已配置的 token"; return; }
            echo "已配置 token 的 provider:"
            while IFS='=' read -r p _; do
                [[ -z "${p}" || "${p}" == \#* ]] && continue
                echo "  • ${p}"
            done < "${TOKEN_FILE}"
            ;;
        *)
            echo "用法: cc-model token <set|del|list> [provider] [token]"
            echo "Provider: anthropic  openrouter"
            ;;
    esac
}

# ────────────── 构建 settings patch ──────────────
# 根据模型生成需要注入到 settings.json env 块中的内容
build_env_patch() {
    local model="$1"
    local provider="${MODEL_PROVIDER["${model}"]}"
    local model_id="${MODEL_ID["${model}"]}"
    local base_url="${PROVIDER_BASE_URL["${provider}"]}"
    local token
    token=$(get_token "${provider}")

    # 输出 JSON patch（供 python3 合并）
    if [[ -n "${base_url}" ]]; then
        python3 -c "
import json
patch = {
    'model': '${model_id}',
    'env': {
        'ANTHROPIC_API_KEY': '${token}',
        'ANTHROPIC_BASE_URL': '${base_url}'
    }
}
print(json.dumps(patch))
"
    else
        python3 -c "
import json
patch = {
    'model': '${model_id}',
    'env': {
        'ANTHROPIC_API_KEY': '${token}'
    }
}
print(json.dumps(patch))
"
    fi
}

# ────────────── switch 命令 ──────────────
cmd_switch() {
    local model="${1:?请提供模型名称}"
    validate_model "${model}"

    local provider="${MODEL_PROVIDER["${model}"]}"
    local model_id="${MODEL_ID["${model}"]}"
    local base_url="${PROVIDER_BASE_URL["${provider}"]}"

    # anthropic 官方由 Claude Code 自身管理认证，无需手动配置 token
    local token=""
    if [[ "${provider}" != "anthropic" ]]; then
        token=$(get_token "${provider}")
    fi

    # 确定 token 环境变量名（minimax 使用 ANTHROPIC_AUTH_TOKEN）
    local token_env_key="${PROVIDER_AUTH_TOKEN_KEY["${provider}"]:-ANTHROPIC_API_KEY}"

    # 合并 settings.json
    local current_settings
    current_settings=$(read_settings)

    local new_settings
    new_settings=$(python3 -c "
import json, sys

current = json.loads('''${current_settings}''')

# 更新 model
current['model'] = '${model_id}'

# 更新 env 块（保留其他 env 项）
env = current.get('env', {})

# 清理所有可能的 token key，避免残留
for k in ['ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN']:
    env.pop(k, None)

if '${token}':
    env['${token_env_key}'] = '${token}'

if '${base_url}':
    env['ANTHROPIC_BASE_URL'] = '${base_url}'
else:
    env.pop('ANTHROPIC_BASE_URL', None)

if env:
    current['env'] = env
elif 'env' in current:
    del current['env']

print(json.dumps(current, indent=2, ensure_ascii=False))
")

    write_settings "${new_settings}"
    info "已切换默认模型 → ${model} (${model_id})"
    if [[ -n "${base_url}" ]]; then info "Base URL → ${base_url} (via ${provider})"; fi
}

# ────────────── run 命令（临时，不改 settings）──────────────
cmd_run() {
    local model="${1:?请提供模型名称}"; shift
    validate_model "${model}"

    local provider="${MODEL_PROVIDER["${model}"]}"
    local model_id="${MODEL_ID["${model}"]}"
    local base_url="${PROVIDER_BASE_URL["${provider}"]}"

    # anthropic 官方由 Claude Code 自身管理认证，无需手动配置 token
    local token=""
    if [[ "${provider}" != "anthropic" ]]; then
        token=$(get_token "${provider}")
    fi

    # 确定 token 环境变量名（minimax 使用 ANTHROPIC_AUTH_TOKEN）
    local token_env_key="${PROVIDER_AUTH_TOKEN_KEY["${provider}"]:-ANTHROPIC_API_KEY}"

    info "临时使用模型: ${model} (${model_id})"

    # 构建环境变量
    local -a env_vars=()
    if [[ -n "${token}" ]]; then
        env_vars+=("${token_env_key}=${token}")
    fi
    if [[ -n "${base_url}" ]]; then
        env_vars+=("ANTHROPIC_BASE_URL=${base_url}")
    fi

    if [[ ${#env_vars[@]} -gt 0 ]]; then
        exec env "${env_vars[@]}" claude --model "${model_id}" "$@"
    else
        exec claude --model "${model_id}" "$@"
    fi
}

# ────────────── restore 命令 ──────────────
cmd_restore() {
    local n="${1:-1}"
    [[ "${n}" =~ ^[1-9][0-9]*$ ]] || error "参数须为正整数，如: cc-model restore 2"

    # 按时间从新到旧列出所有 settings.json 备份
    local -a backups
    mapfile -t backups < <(ls -t "${BACKUP_DIR}/settings.json.bak."* 2>/dev/null)

    [[ ${#backups[@]} -gt 0 ]] || error "没有找到任何 settings.json 备份（备份目录: ${BACKUP_DIR}）"

    if [[ ${n} -gt ${#backups[@]} ]]; then
        error "只有 ${#backups[@]} 个备份，无法恢复第 ${n} 个"
    fi

    local target="${backups[$((n - 1))]}"

    # 展示备份列表，标记目标
    echo "可用备份（从新到旧）:"
    local i
    for i in "${!backups[@]}"; do
        local marker="  "
        [[ $i -eq $((n - 1)) ]] && marker="→ "
        printf '  %s[%d] %s\n' "${marker}" "$((i + 1))" "$(basename "${backups[$i]}")"
    done
    echo ""

    # 恢复前先备份当前文件
    backup_file "${SETTINGS_FILE}"
    cp "${target}" "${SETTINGS_FILE}"
    info "已恢复 settings.json ← $(basename "${target}")"
}

# ────────────── current 命令 ──────────────
cmd_current() {
    if [[ ! -f "${SETTINGS_FILE}" ]]; then
        echo "settings.json 不存在，使用默认模型"
        return
    fi
    python3 -c "
import json
with open('${SETTINGS_FILE}') as f:
    s = json.load(f)
model = s.get('model', '(未设置，使用 Claude Code 默认)')
base_url = s.get('env', {}).get('ANTHROPIC_BASE_URL', '(官方端点)')
print(f'当前模型  : {model}')
print(f'Base URL  : {base_url}')
"
}

# ────────────── list 命令 ──────────────
cmd_list() {
    echo "支持的模型别名:"
    printf '  %-18s %-40s %s\n' "别名" "Model ID" "Provider"
    printf '  %-18s %-40s %s\n' "──────────────────" "────────────────────────────────────────" "────────────"
    for alias in claude claude-opus claude-sonnet claude-haiku chatgpt gemini glm minimax-m2.7 minimax-cn; do
        [[ -v MODEL_ID["${alias}"] ]] || continue
        printf '  %-18s %-40s %s\n' "${alias}" "${MODEL_ID["${alias}"]}" "${MODEL_PROVIDER["${alias}"]}"
    done
    echo ""
    echo "Provider token 配置:"
    echo "  anthropic   → cc-model token set anthropic  <ANTHROPIC_API_KEY>"
    echo "  openrouter  → cc-model token set openrouter <OPENROUTER_API_KEY>"
    echo ""
    echo "OpenRouter 支持 claude/chatgpt/gemini/glm/minimax，一个 key 全搞定"
    echo "注册: https://openrouter.ai"
    echo ""
    echo "MiniMax 国内直连（Anthropic 兼容端点）:"
    echo "  minimax-cn  → cc-model token set minimax <MINIMAX_API_KEY>"
    echo "  使用 ANTHROPIC_AUTH_TOKEN 认证，Base URL: https://api.minimaxi.com/anthropic"
    echo "注册: https://platform.minimaxi.com"
}

# ────────────── completion 命令 ──────────────
cmd_completion() {
    local shell_type="${1:-}"
    if [[ -z "${shell_type}" ]]; then
        case "${SHELL}" in
            */zsh) shell_type="zsh" ;;
            *)     shell_type="bash" ;;
        esac
    fi
    case "${shell_type}" in
        bash) _completion_bash ;;
        zsh)  _completion_zsh  ;;
        *) error "不支持的 shell: ${shell_type}，可选: bash zsh" ;;
    esac
}

# bash 补全脚本（单引号 heredoc，内部 $ 不展开）
_completion_bash() {
    cat <<'BASH_COMP'
# cc-model bash 补全
# 安装（二选一）:
#   echo 'eval "$(cc-model completion bash)"' >> ~/.bashrc
#   cc-model completion bash > /etc/bash_completion.d/cc-model
_cc_model_completions() {
    local cur prev words cword
    if declare -f _init_completion &>/dev/null; then
        _init_completion || return
    else
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword="${COMP_CWORD}"
    fi

    local commands="switch run restore current list token completion help"
    local models="claude claude-opus claude-sonnet claude-haiku chatgpt gemini glm minimax-m2.7 minimax-cn"
    local providers="anthropic openrouter minimax"
    local token_subcmds="set del list"

    case "${cword}" in
        1)
            COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
            ;;
        2)
            case "${words[1]}" in
                switch|run)
                    COMPREPLY=($(compgen -W "${models}" -- "${cur}"))
                    ;;
                token)
                    COMPREPLY=($(compgen -W "${token_subcmds}" -- "${cur}"))
                    ;;
                completion)
                    COMPREPLY=($(compgen -W "bash zsh" -- "${cur}"))
                    ;;
                restore)
                    # 动态补全：列出可用备份序号
                    local backup_dir="${HOME}/.config/cc-model/backups"
                    local count=0
                    if [[ -d "${backup_dir}" ]]; then
                        count=$(ls "${backup_dir}/settings.json.bak."* 2>/dev/null | wc -l | tr -d ' ')
                    fi
                    if [[ ${count} -gt 0 ]]; then
                        COMPREPLY=($(compgen -W "$(seq 1 "${count}")" -- "${cur}"))
                    fi
                    ;;
            esac
            ;;
        3)
            case "${words[1]}" in
                token)
                    case "${words[2]}" in
                        set)
                            COMPREPLY=($(compgen -W "${providers}" -- "${cur}"))
                            ;;
                        del)
                            # 动态补全：仅列出已配置的 provider
                            local token_file="${HOME}/.config/cc-model/tokens"
                            local configured=""
                            if [[ -f "${token_file}" ]]; then
                                configured=$(grep -oE '^[^=#][^=]*' "${token_file}" | tr '\n' ' ')
                            fi
                            COMPREPLY=($(compgen -W "${configured}" -- "${cur}"))
                            ;;
                    esac
                    ;;
            esac
            ;;
    esac
}
complete -F _cc_model_completions cc-model
BASH_COMP
}

# zsh 补全脚本（原生 _arguments 风格，含描述）
_completion_zsh() {
    cat <<'ZSH_COMP'
# cc-model zsh 补全
# 安装（二选一）:
#   echo 'eval "$(cc-model completion zsh)"' >> ~/.zshrc
#   cc-model completion zsh > "${fpath[1]}/_cc_model"
autoload -U compinit && compinit 2>/dev/null

_cc_model() {
    local state

    _arguments -C \
        '1:command:->command' \
        '*:args:->args' && return 0

    case "${state}" in
        command)
            local -a cmds
            cmds=(
                'switch:永久切换默认模型（写入 settings.json）'
                'run:临时以指定模型启动 claude（不改 settings）'
                'restore:恢复 settings.json 到指定备份'
                'current:显示当前 settings.json 中的模型配置'
                'list:列出所有支持的模型别名'
                'token:管理 API token'
                'completion:输出 shell 补全脚本'
                'help:显示帮助信息'
            )
            _describe 'command' cmds
            ;;
        args)
            local -a models providers token_subcmds shells
            models=(
                'claude:claude-opus-4-6（默认旗舰）'
                'claude-opus:claude-opus-4-6'
                'claude-sonnet:claude-sonnet-4-6'
                'claude-haiku:claude-haiku-4-5'
                'chatgpt:openai/gpt-4o（via OpenRouter）'
                'gemini:google/gemini-2.5-pro（via OpenRouter）'
                'glm:thudm/glm-4-32b（via OpenRouter）'
                'minimax-m2.7:minimax/minimax-m2（via OpenRouter）'
                'minimax-cn:MiniMax-Text-01（国内直连）'
            )
            providers=('anthropic' 'openrouter' 'minimax')
            token_subcmds=(
                'set:保存 provider 的 API token'
                'del:删除 provider token'
                'list:查看已配置的 provider'
            )
            shells=('bash' 'zsh')

            case "${words[2]}" in
                switch|run)
                    _describe 'model' models
                    ;;
                restore)
                    local backup_dir="${HOME}/.config/cc-model/backups"
                    local count=0
                    [[ -d "${backup_dir}" ]] && \
                        count=$(ls "${backup_dir}/settings.json.bak."* 2>/dev/null | wc -l | tr -d ' ')
                    if [[ ${count} -gt 0 ]]; then
                        local -a nums
                        nums=($(seq 1 "${count}"))
                        _describe 'backup number' nums
                    fi
                    ;;
                token)
                    case "${words[3]}" in
                        set)
                            _describe 'provider' providers
                            ;;
                        del)
                            local token_file="${HOME}/.config/cc-model/tokens"
                            if [[ -f "${token_file}" ]]; then
                                local -a configured
                                configured=($(grep -oE '^[^=#][^=]*' "${token_file}"))
                                _describe 'configured provider' configured
                            fi
                            ;;
                        *)
                            _describe 'token subcommand' token_subcmds
                            ;;
                    esac
                    ;;
                completion)
                    _describe 'shell' shells
                    ;;
            esac
            ;;
    esac
}

compdef _cc_model cc-model
ZSH_COMP
}

# ────────────── help ──────────────
cmd_help() {
    cat <<EOF
用法: $(basename "$0") <命令> [参数]

命令:
  switch <model>               永久切换 Claude Code 默认模型（更新 settings.json）
  run <model> [claude args...] 临时以指定模型启动 claude（不修改 settings）
  restore [n]                  恢复 settings.json 到第 n 个备份（默认 1=最近一个）
  current                      显示当前 settings.json 中的模型配置
  list                         列出所有支持的模型别名
  token set <provider> <token> 安全保存 provider 的 API token（权限 600）
  token del <provider>         删除 provider token
  token list                   查看已配置的 provider
  completion [bash|zsh]        输出 shell 补全脚本（默认自动检测当前 shell）

支持的模型别名:
  claude / claude-opus / claude-sonnet / claude-haiku
  chatgpt / gemini / glm / minimax-m2.7
  minimax-cn（MiniMax 国内直连）

Token 配置 (二选一):
  1. 每个 provider 单独配置:
     $(basename "$0") token set anthropic  sk-ant-xxxx
     $(basename "$0") token set openrouter sk-or-xxxx   # 其他模型走 OpenRouter
     $(basename "$0") token set minimax    <MINIMAX_KEY> # MiniMax 国内直连

  2. 全部走 OpenRouter (推荐，一个 key):
     $(basename "$0") token set openrouter sk-or-xxxx
     # 同时为 claude 系列也设置 anthropic key，或在 OR 中启用 Claude

补全安装:
  bash: echo 'eval "\$(cc-model completion bash)"' >> ~/.bashrc && source ~/.bashrc
  zsh:  echo 'eval "\$(cc-model completion zsh)"'  >> ~/.zshrc  && source ~/.zshrc

示例:
  $(basename "$0") token set anthropic  sk-ant-api03-xxxx
  $(basename "$0") token set openrouter sk-or-v1-xxxx
  $(basename "$0") switch gemini          # 永久切换到 gemini
  $(basename "$0") switch claude          # 切回 claude
  $(basename "$0") run chatgpt -p "写个排序算法"   # 临时用 chatgpt 跑一次
  $(basename "$0") restore                # 恢复到上一个 settings.json
  $(basename "$0") restore 2              # 恢复到第 2 个（次新）备份
  $(basename "$0") current                # 查看当前配置
EOF
}

# ────────────── 依赖检查 ──────────────
# 以 source 方式加载时（如单元测试）跳过依赖检查和入口分发，仅导出函数定义
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && return 0

command -v python3 &>/dev/null || error "需要 python3（用于解析 JSON settings）"
command -v claude  &>/dev/null || error "未找到 claude 命令，请先安装 Claude Code"

# ────────────── 入口 ──────────────
case "${1:-help}" in
    switch)     shift; cmd_switch     "$@" ;;
    run)        shift; cmd_run        "$@" ;;
    restore)    shift; cmd_restore    "$@" ;;
    current)    cmd_current ;;
    list)       cmd_list ;;
    token)      shift; cmd_token      "$@" ;;
    completion) shift; cmd_completion "$@" ;;
    help|--help|-h) cmd_help ;;
    *)          warn "未知命令: $1"; cmd_help; exit 1 ;;
esac
