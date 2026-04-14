#!/usr/bin/env bash
# cc-model.sh — Claude Code 多模型切换工具
# 双级配置: 供应商(Provider) + 模型(Model)
# 原理: 修改 ~/.claude/settings.json 中的 model / env.ANTHROPIC_API_KEY / env.ANTHROPIC_BASE_URL
#
# 用法:
#   cc-model switch <model>          永久切换默认模型（写入 settings.json）
#   cc-model run <model> [args...]  临时用指定模型启动 claude（不改 settings）
#   cc-model restore [n]             恢复 settings.json 到第 n 个备份（默认最近一个）
#   cc-model current                 显示当前模型
#   cc-model list                    列出所有支持的模型
#   cc-model provider add <name> <base_url> [auth_key]  添加供应商
#   cc-model provider del <name>     删除供应商
#   cc-model provider list           列出所有供应商
#   cc-model token set <provider> <token>   保存 token
#   cc-model token list              查看已配置的 provider

set -euo pipefail

# ────────────── 路径 ──────────────
SETTINGS_FILE="${HOME}/.claude/settings.json"
TOKEN_FILE="${HOME}/.config/cc-model/tokens"
PROVIDER_FILE="${HOME}/.config/cc-model/providers"
CONFIG_DIR="${HOME}/.config/cc-model"
BACKUP_DIR="${HOME}/.config/cc-model/backups"
BACKUP_KEEP=5   # 每个文件最多保留的备份份数

# ────────────── 供应商定义 ──────────────
# 格式: name => "base_url|auth_key_type|token_required|is_official|description"
# - base_url: 空=官方端点
# - auth_key_type: ANTHROPIC_API_KEY | ANTHROPIC_AUTH_TOKEN
# - token_required: true | false（官方=false）
# - is_official: true | false（Claude Code 官方供应商）
# - description: 显示名称
declare -A PROVIDERS=(
    [anthropic]="||false|true|Anthropic 官方"
    [openrouter]="https://openrouter.ai/api/v1|ANTHROPIC_AUTH_TOKEN|true|false|OpenRouter"
    [minimax]="https://api.minimaxi.com/anthropic|ANTHROPIC_AUTH_TOKEN|true|false|MiniMax 国内"
)

# ────────────── 内置模型表 ──────────────
# 格式: alias => "provider|model_id|description"
declare -A BUILTIN_MODELS=(
    # Anthropic 官方模型
    [claude]="anthropic|claude-opus-4-6|Claude Opus 4.6（旗舰）"
    [claude-opus]="anthropic|claude-opus-4-6|Claude Opus 4.6（旗舰）"
    [claude-sonnet]="anthropic|claude-sonnet-4-6|Claude Sonnet 4.6（均衡）"
    [claude-haiku]="anthropic|claude-haiku-4-5-20251001|Claude Haiku 4.5（快速）"
    [claude-3-5-sonnet]="anthropic|claude-sonnet-4-6|Claude 3.5 Sonnet"
    [claude-3-opus]="anthropic|claude-3-opus|Claude 3 Opus"
    [claude-3-sonnet]="anthropic|claude-3-sonnet|Claude 3 Sonnet"
    [claude-3-haiku]="anthropic|claude-3-haiku|Claude 3 Haiku"

    # OpenRouter 模型（Claude 系列）
    [openrouter-sonnet]="openrouter|anthropic/claude-sonnet-4-6|Claude Sonnet 4.6（OpenRouter）"
    [openrouter-haiku]="openrouter|anthropic/claude-haiku-4-5-20251001|Claude Haiku 4.5（OpenRouter）"

    # OpenRouter 非 Claude 模型（供应商-模型-版本）
    [openrouter-gpt-4o]="openrouter|openai/gpt-4o|GPT-4o（OpenRouter）"
    [openrouter-gpt-4o-mini]="openrouter|openai/gpt-4o-mini|GPT-4o Mini（OpenRouter）"
    [openrouter-gpt-4-turbo]="openrouter|openai/gpt-4-turbo|GPT-4 Turbo（OpenRouter）"
    [openrouter-gemini-pro]="openrouter|google/gemini-2.5-pro-preview-03-25|Gemini 2.5 Pro（OpenRouter）"
    [openrouter-gemini-2-pro]="openrouter|google/gemini-2.0-pro-exp|Gemini 2.0 Pro（OpenRouter）"
    [openrouter-gemini-flash]="openrouter|google/gemini-2.0-flash-exp|Gemini 2.0 Flash（OpenRouter）"
    [openrouter-glm-4-32b]="openrouter|thudm/glm-4-32b|GLM-4-32B（OpenRouter）"
    [openrouter-deepseek-chat]="openrouter|deepseek/deepseek-chat-v2-5|DeepSeek V2.5（OpenRouter）"
    [openrouter-mistral-large]="openrouter|mistralai/mistral-large-2|Mistral Large 2（OpenRouter）"
    [openrouter-llama-3-70b]="openrouter|meta-llama/llama-3-3-70b-instruct|Llama 3.3 70B（OpenRouter）"
    [openrouter-qwen-2-72b]="openrouter|qwen/qwen-2-72b-instruct|Qwen 2 72B（OpenRouter）"
    [openrouter-yi-large]="openrouter|01-ai/yi-large|Yi Large（OpenRouter）"
    [openrouter-minimax-m2]="openrouter|minimax/minimax-m2|MiniMax M2（OpenRouter）"
    [openrouter-groq-llama-3-70b]="openrouter|groq/llama-3.3-70b-instruct|Llama 3.3 70B（Groq）"

    # MiniMax 国内直连（供应商-模型）
    [minimax-m2]="minimax|MiniMax-M2.7-highspeed|MiniMax M2（国内直连）"
)

# ────────────── 供应商解析函数 ──────────────
# 解析 PROVIDERS 数组中某个供应商的各字段
# 用法: provider_get <provider_name> <field>
# field: base_url | auth_key | token_required | is_official | desc
provider_get() {
    local name="$1"
    local field="$2"
    local data="${PROVIDERS[${name}]:-}"
    [[ -n "${data}" ]] || return 1

    case "${field}" in
        base_url)      echo "${data}" | cut -d'|' -f1 ;;
        auth_key)      echo "${data}" | cut -d'|' -f2 ;;
        token_required) echo "${data}" | cut -d'|' -f3 ;;
        is_official)   echo "${data}" | cut -d'|' -f4 ;;
        desc)          echo "${data}" | cut -d'|' -f5 ;;
        *)             return 1 ;;
    esac
}

# ────────────── 模型解析函数 ──────────────
# 解析 BUILTIN_MODELS 数组中某个模型的各字段
# 用法: model_get <model_alias> <field>
# field: provider | model_id | desc
model_get() {
    local alias="$1"
    local field="$2"

    # 优先从内置模型表查
    if [[ -v BUILTIN_MODELS["${alias}"] ]]; then
        local data="${BUILTIN_MODELS[${alias}]}"
        case "${field}" in
            provider) echo "${data}" | cut -d'|' -f1 ;;
            model_id) echo "${data}" | cut -d'|' -f2 ;;
            desc)     echo "${data}" | cut -d'|' -f3 ;;
            *)        return 1 ;;
        esac
        return 0
    fi

    # 从用户自定义模型文件查
    local custom_file="${CONFIG_DIR}/models"
    if [[ -f "${custom_file}" ]]; then
        local line
        line=$(grep -E "^${alias}=" "${custom_file}" 2>/dev/null | head -1)
        if [[ -n "${line}" ]]; then
            local data
            data=$(echo "${line}" | cut -d'=' -f2-)
            case "${field}" in
                provider) echo "${data}" | cut -d'|' -f1 ;;
                model_id) echo "${data}" | cut -d'|' -f2 ;;
                desc)     echo "${data}" | cut -d'|' -f3 ;;
                *)        return 1 ;;
            esac
            return 0
        fi
    fi

    return 1
}

# ────────────── 工具函数 ──────────────
info()  { printf '\033[32m[INFO]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[33m[WARN]\033[0m  %s\n' "$*" >&2; }
error() { printf '\033[31m[ERR]\033[0m   %s\n' "$*" >&2; exit 1; }

ensure_config() {
    mkdir -p "${CONFIG_DIR}"
    chmod 700 "${CONFIG_DIR}"
}

# 备份文件，自动清理超出 BACKUP_KEEP 的旧备份
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
    model_get "${m}" provider &>/dev/null || \
        error "不支持的模型: ${m}。运行 cc-model list 查看支持列表"
}

# 从 token 文件读取指定 provider 的 token
get_token() {
    local provider="$1"
    [[ -f "${TOKEN_FILE}" ]] || error '尚未配置任何 token，请先运行: cc-model token set <provider> <token>'
    local token
    token=$(grep -E "^${provider}=" "${TOKEN_FILE}" 2>/dev/null | cut -d'=' -f2-)
    [[ -n "${token}" ]] || error "未找到 [${provider}] 的 token，请运行: cc-model token set ${provider} YOUR_TOKEN"
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

# 写入 settings.json
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

# ────────────── provider 管理 ──────────────
cmd_provider() {
    local action="${1:-help}"; shift || true
    case "${action}" in
        add)
            local name="${1:-}"; shift || true
            [[ -n "${name}" ]] || { error "用法: cc-model provider add <name> <base_url> [auth_key]"; return 1; }
            local base_url="${1:-}"; shift || true
            [[ -n "${base_url}" ]] || { error "用法: cc-model provider add <name> <base_url> [auth_key]"; return 1; }
            local auth_key="${1:-ANTHROPIC_API_KEY}"; shift || true

            ensure_config
            backup_file "${PROVIDER_FILE}"

            if [[ -v PROVIDERS["${name}"] ]]; then
                error "供应商 [${name}] 已存在（内置），无法重复添加。如需修改请先 del"
            fi

            if grep -qE "^${name}=" "${PROVIDER_FILE}" 2>/dev/null; then
                sed -i "s|^${name}=.*|${name}=${base_url}|${auth_key}|true|false|" "${PROVIDER_FILE}"
            else
                echo "${name}=${base_url}|${auth_key}|true|false|${name} Provider" >> "${PROVIDER_FILE}"
            fi
            info "已添加供应商 [${name}] (base_url=${base_url}, auth=${auth_key})"
            ;;
        del|delete)
            local name="${1:-}"
            [[ -n "${name}" ]] || { error "用法: cc-model provider del <name>"; return 1; }
            if [[ -v PROVIDERS["${name}"] ]]; then
                error "供应商 [${name}] 是内置供应商，无法删除"
            fi
            [[ -f "${PROVIDER_FILE}" ]] && sed -i "/^${name}=/d" "${PROVIDER_FILE}"
            info "已删除供应商 [${name}]"
            ;;
        list)
            echo "内置供应商:"
            printf '  %-12s %-40s %-8s %s\n' "名称" "Base URL" "Auth Key" "说明"
            printf '  %-12s %-40s %-8s %s\n' "────────────" "────────────────────────────────────────" "────────" "──────"
            for p in "${!PROVIDERS[@]}"; do
                local base_url auth_key token_req is_official desc
                base_url=$(provider_get "${p}" base_url)
                auth_key=$(provider_get "${p}" auth_key)
                token_req=$(provider_get "${p}" token_required)
                is_official=$(provider_get "${p}" is_official)
                desc=$(provider_get "${p}" desc)
                local token_note="需要token"
                [[ "${token_req}" == "false" ]] && token_note="无需token"
                [[ "${is_official}" == "true" ]] && token_note="${token_note} [官方]"
                printf '  %-12s %-40s %-8s %s\n' "${p}" "${base_url:-(官方端点)}" "${auth_key}" "${token_note} ${desc}"
            done

            if [[ -f "${PROVIDER_FILE}" ]]; then
                echo ""
                echo "自定义供应商:"
                while IFS='=' read -r name data; do
                    [[ -z "${name}" || "${name}" == \#* ]] && continue
                    local base_url auth_key
                    base_url=$(echo "${data}" | cut -d'|' -f1)
                    auth_key=$(echo "${data}" | cut -d'|' -f2)
                    printf '  %-12s %-40s %-8s\n' "${name}" "${base_url}" "${auth_key}"
                done < "${PROVIDER_FILE}"
            fi
            ;;
        *)
            echo "用法: cc-model provider <add|del|list>"
            echo ""
            echo "  add <name> <base_url> [auth_key]   添加自定义供应商"
            echo "                                    auth_key 默认为 ANTHROPIC_API_KEY"
            echo "  del <name>                        删除自定义供应商（内置不可删）"
            echo "  list                              列出所有供应商"
            ;;
    esac
}

# ────────────── token 管理 ──────────────
cmd_token() {
    local action="${1:-help}"; shift || true
    case "${action}" in
        set)
            local provider="${1:-}"; shift || true
            [[ -n "${provider}" ]] || { error '用法: cc-model token set <provider> <token>'; return 1; }
            local token="${1:-}"; shift || true
            [[ -n "${token}" ]] || { error "用法: cc-model token set ${provider} <token>"; return 1; }

            # 检查是否为无需 token 的官方供应商
            local token_req
            if token_req=$(provider_get "${provider}" token_required 2>/dev/null); then
                if [[ "${token_req}" == "false" ]]; then
                    warn "供应商 [${provider}] 是官方供应商，理论上不需要 token"
                fi
            fi

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
            if [[ ! -f "${TOKEN_FILE}" ]]; then
                info "暂无已配置的 token"
                return
            fi
            echo "已配置 token 的 provider:"
            while IFS='=' read -r p _; do
                [[ -z "${p}" || "${p}" == \#* ]] && continue
                local token_req
                if token_req=$(provider_get "${p}" token_required 2>/dev/null); then
                    if [[ "${token_req}" == "false" ]]; then
                        echo "  • ${p} (官方，无需token)"
                    else
                        echo "  • ${p}"
                    fi
                else
                    echo "  • ${p}"
                fi
            done < "${TOKEN_FILE}"
            ;;
        *)
            echo "用法: cc-model token <set|del|list> [provider] [token]"
            ;;
    esac
}

# ────────────── switch 命令 ──────────────
cmd_switch() {
    local model="${1:?请提供模型名称}"
    validate_model "${model}"

    local provider model_id base_url auth_key token_req is_official
    provider=$(model_get "${model}" provider)
    model_id=$(model_get "${model}" model_id)

    base_url=$(provider_get "${provider}" base_url)
    auth_key=$(provider_get "${provider}" auth_key)
    token_req=$(provider_get "${provider}" token_required)
    is_official=$(provider_get "${provider}" is_official)

    # 官方供应商（Claude Code 原生支持）不需要 token
    local token=""
    if [[ "${token_req}" == "true" ]]; then
        token=$(get_token "${provider}")
    fi

    # 合并 settings.json
    local current_settings
    current_settings=$(read_settings)

    local new_settings
    new_settings=$(python3 -c "
import json, sys

current = json.loads('''${current_settings}''')

# 更新 model
current['model'] = '${model_id}'

# 更新 env 块
env = current.get('env', {})

# 清理所有可能的 token key
for k in ['ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN']:
    env.pop(k, None)

if '${token}':
    env['${auth_key}'] = '${token}'

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
    info "供应商: ${provider}${base_url:+, Base URL: ${base_url}}"
    if [[ -n "${token}" ]]; then
        info "Token 已配置 (${auth_key})"
    else
        info "此供应商无需 token"
    fi
}

# ────────────── run 命令（临时，不改 settings）──────────────
cmd_run() {
    local model="${1:?请提供模型名称}"; shift
    validate_model "${model}"

    local provider model_id base_url auth_key token_req
    provider=$(model_get "${model}" provider)
    model_id=$(model_get "${model}" model_id)
    base_url=$(provider_get "${provider}" base_url)
    auth_key=$(provider_get "${provider}" auth_key)
    token_req=$(provider_get "${provider}" token_required)

    local token=""
    if [[ "${token_req}" == "true" ]]; then
        token=$(get_token "${provider}")
    fi

    info "临时使用模型: ${model} (${model_id}) via ${provider}"

    # 构建环境变量
    local -a env_vars=()
    if [[ -n "${token}" ]]; then
        env_vars+=("${auth_key}=${token}")
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

    local -a backups
    mapfile -t backups < <(ls -t "${BACKUP_DIR}/settings.json.bak."* 2>/dev/null)

    [[ ${#backups[@]} -gt 0 ]] || error "没有找到任何 settings.json 备份"

    if [[ ${n} -gt ${#backups[@]} ]]; then
        error "只有 ${#backups[@]} 个备份，无法恢复第 ${n} 个"
    fi

    local target="${backups[$((n - 1))]}"

    echo "可用备份（从新到旧）:"
    local i
    for i in "${!backups[@]}"; do
        local marker="  "
        [[ $i -eq $((n - 1)) ]] && marker="→ "
        printf '  %s[%d] %s\n' "${marker}" "$((i + 1))" "$(basename "${backups[$i]}")"
    done
    echo ""

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
model = s.get('model', '(未设置)')
base_url = s.get('env', {}).get('ANTHROPIC_BASE_URL', '(官方端点)')
print(f'当前模型  : {model}')
print(f'Base URL  : {base_url}')
"
}

# ────────────── list 命令 ──────────────
cmd_list() {
    echo "支持的模型别名:"
    printf '  %-20s %-40s %s\n' "别名" "Model ID" "Provider / 说明"
    printf '  %-20s %-40s %s\n' "────────────────────" "────────────────────────────────────────" "──────────────────────────"

    # 按供应商分组
    declare -A by_provider
    for alias in "${!BUILTIN_MODELS[@]}"; do
        local p
        p=$(model_get "${alias}" provider)
        by_provider["${p}"]+=" ${alias}"
    done

    for p in anthropic openrouter minimax; do
        case "${p}" in
            anthropic)   echo ""; echo "  【 Anthropic 官方 】"; echo "  无需配置 token，Claude Code 自动处理"; echo "" ;;
            openrouter)  echo ""; echo "  【 OpenRouter 】"; echo "  Base URL: https://openrouter.ai/api/v1"; echo "  一个 key 访问所有 OpenRouter 模型"; echo "" ;;
            minimax)    echo ""; echo "  【 MiniMax 国内直连 】"; echo "  Base URL: https://api.minimaxi.com/anthropic"; echo "  国内直连，无需科学上网"; echo "" ;;
        esac

        for alias in ${by_provider["${p}"]:-}; do
            [[ -z "${alias}" ]] && continue
            local model_id desc
            model_id=$(model_get "${alias}" model_id)
            desc=$(model_get "${alias}" desc)
            printf '  %-20s %-40s %s\n' "${alias}" "${model_id}" "${desc}"
        done
    done

    echo ""
    echo "供应商配置:"
    echo "  cc-model provider list    查看所有供应商"
    echo "  cc-model provider add     添加自定义供应商"
    echo ""
    echo "Token 配置:"
    echo "  cc-model token set <provider> <token>   保存 token"
    echo "  cc-model token list                     查看已配置"
    echo ""
    echo "示例 - 添加支持 Claude 的其他供应商:"
    echo "  cc-model provider add azure https://xxx.openai.azure.com"
    echo "  # 然后在 models 中添加: my-claude=azure/claude-sonnet-4-6"
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
        *) error "不支持的 shell: ${shell_type}" ;;
    esac
}

_completion_bash() {
    cat <<'BASH_COMP'
# cc-model bash 补全
# 安装: echo 'eval "$(cc-model completion bash)"' >> ~/.bashrc
_cc_model() {
    local cur prev words cword
    COMPREPLY=()
    _get_comp_words_by_ref cur prev words cword

    local commands="switch run restore current list token provider completion help"
    local models="claude claude-opus claude-sonnet claude-haiku claude-3-5-sonnet claude-3-opus claude-3-sonnet claude-3-haiku openrouter-sonnet openrouter-haiku openrouter-gpt-4o openrouter-gpt-4o-mini openrouter-gpt-4-turbo openrouter-gemini-pro openrouter-gemini-2-pro openrouter-gemini-flash openrouter-glm-4-32b openrouter-deepseek-chat openrouter-mistral-large openrouter-llama-3-70b openrouter-qwen-2-72b openrouter-yi-large openrouter-minimax-m2 openrouter-groq-llama-3-70b minimax-m2"
    local providers="anthropic openrouter minimax"
    local token_subcmds="set del list"
    local provider_subcmds="add del list"
    local auth_keys="ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN"

    # 获取已配置的 token providers（动态）
    local configured_providers=""
    local token_file="${HOME}/.config/cc-model/tokens"
    if [[ -f "${token_file}" ]]; then
        configured_providers=$(grep -oE '^[^=#][^=]*' "${token_file}" 2>/dev/null | tr '\n' ' ')
    fi

    # 获取可用备份序号（动态）
    local backup_dir="${HOME}/.config/cc-model/backups"
    local backup_count=0
    if [[ -d "${backup_dir}" ]]; then
        backup_count=$(ls "${backup_dir}/settings.json.bak."* 2>/dev/null | wc -l | tr -d ' ')
    fi

    case "${cword}" in
        1)
            # 第一层：命令
            COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
            ;;
        2)
            # 第二层：子命令/模型
            case "${words[1]}" in
                switch|run)
                    COMPREPLY=($(compgen -W "${models}" -- "${cur}"))
                    ;;
                token)
                    COMPREPLY=($(compgen -W "${token_subcmds}" -- "${cur}"))
                    ;;
                provider)
                    COMPREPLY=($(compgen -W "${provider_subcmds}" -- "${cur}"))
                    ;;
                restore)
                    if [[ ${backup_count} -gt 0 ]]; then
                        COMPREPLY=($(compgen -W "$(seq 1 "${backup_count}")" -- "${cur}"))
                    fi
                    ;;
                completion)
                    COMPREPLY=($(compgen -W "bash zsh" -- "${cur}"))
                    ;;
            esac
            ;;
        3)
            # 第三层：具体参数
            case "${words[1]}" in
                token)
                    case "${words[2]}" in
                        set)
                            # token set <provider> <token>
                            COMPREPLY=($(compgen -W "${providers}" -- "${cur}"))
                            ;;
                        del)
                            # token del <provider> - 动态补全已配置的
                            if [[ -n "${configured_providers}" ]]; then
                                COMPREPLY=($(compgen -W "${configured_providers}" -- "${cur}"))
                            fi
                            ;;
                    esac
                    ;;
                provider)
                    case "${words[2]}" in
                        add)
                            # provider add <name> [base_url] [auth_key]
                            # 只补全 provider name（用户自定义）
                            COMPREPLY=($(compgen -W "azure cloudflare groq custom" -- "${cur}"))
                            ;;
                        del)
                            # provider del <name> - 不能删除内置，只提示自定义
                            COMPREPLY=($(compgen -W "自定义供应商用 provider del 删除" -- "${cur}"))
                            ;;
                    esac
                    ;;
            esac
            ;;
        4)
            # 第四层
            case "${words[1]}" in
                token)
                    case "${words[2]}" in
                        set)
                            # token set <provider> <token> - 提示输入 token
                            COMPREPLY=($(compgen -W "YOUR_TOKEN" -- "${cur}"))
                            ;;
                    esac
                    ;;
                provider)
                    case "${words[2]}" in
                        add)
                            # provider add <name> <base_url> [auth_key]
                            COMPREPLY=($(compgen -W "https://api.example.com/anthropic" -- "${cur}"))
                            ;;
                    esac
                    ;;
            esac
            ;;
        5)
            # 第五层
            case "${words[1]}" in
                provider)
                    case "${words[2]}" in
                        add)
                            # provider add <name> <base_url> <auth_key>
                            COMPREPLY=($(compgen -W "${auth_keys}" -- "${cur}"))
                            ;;
                    esac
                    ;;
            esac
            ;;
    esac

    # 如果当前是空且没有匹配，尝试通配
    [[ ${#COMPREPLY[@]} -eq 0 ]] && _filedir
    return 0
}
complete -F _cc_model cc-model
BASH_COMP
}

_completion_zsh() {
    cat <<'ZSH_COMP'
_cc_model() {
    local -a models providers token_cmds provider_cmds
    models=(claude:claude-opus-4-6 claude-opus:claude-opus-4-6 claude-sonnet:claude-sonnet-4-6 claude-haiku:claude-haiku-4-5)
    providers=(anthropic:官方 openrouter:OpenRouter minimax:MiniMax国内)
    token_cmds=(set:保存 del:删除 list:列表)
    provider_cmds=(add:添加 del:删除 list:列表)

    _arguments -C '1:command:->command' '*:args:->args' && return
    case "${state}" in
        command)
            local -a cmds
            cmds=(switch:永久切换 run:临时启动 restore:恢复 current:当前 list:列表 token:令牌 provider:供应商)
            _describe 'command' cmds
            ;;
        args)
            case "${words[2]}" in
                switch|run) _describe 'model' models ;;
                token) _describe 'subcommand' token_cmds ;;
                provider) _describe 'subcommand' provider_cmds ;;
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

核心命令:
  switch <model>               永久切换 Claude Code 默认模型（更新 settings.json）
  run <model> [claude args...] 临时以指定模型启动 claude（不修改 settings）
  restore [n]                  恢复 settings.json 到第 n 个备份（默认 1=最近一个）
  current                      显示当前 settings.json 中的模型配置
  list                         列出所有支持的模型

供应商管理:
  provider list                列出所有供应商（含内置+自定义）
  provider add <name> <url> [auth_key]  添加自定义供应商
  provider del <name>          删除自定义供应商

Token 管理:
  token set <provider> <token> 安全保存 provider 的 API token（权限 600）
  token del <provider>         删除 provider token
  token list                   查看已配置的 provider

支持的模型别名:
  # Anthropic 官方（无需 token）
  claude / claude-opus / claude-sonnet / claude-haiku
  claude-3-5-sonnet / claude-3-opus / claude-3-sonnet / claude-3-haiku

  # OpenRouter 供应商-模型-版本
  openrouter-sonnet       Claude Sonnet 4.6
  openrouter-haiku       Claude Haiku 4.5
  openrouter-gpt-4o / openrouter-gpt-4o-mini / openrouter-gpt-4-turbo
  openrouter-gemini-pro / openrouter-gemini-flash
  openrouter-deepseek-chat / openrouter-mistral-large
  openrouter-llama-3-70b / openrouter-qwen-2-72b / openrouter-yi-large

  # MiniMax 国内直连
  minimax-m2（MiniMax M2 国内直连）

Token 配置:
  官方供应商（anthropic）不需要 token，Claude Code 自动处理
  其他供应商: cc-model token set <provider> <token>

示例:
  # 切换到官方 Claude
  $(basename "$0") switch claude

  # 通过 OpenRouter 使用 Claude
  $(basename "$0") token set openrouter sk-or-xxxx
  $(basename "$0") switch openrouter-sonnet

  # 国内直连
  $(basename "$0") switch minimax-m2

  # 添加自定义供应商
  $(basename "$0") provider add azure https://xxx.openai.azure.com
EOF
}

# ────────────── 入口 ──────────────
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && return 0

command -v python3 &>/dev/null || error "需要 python3"
command -v claude  &>/dev/null || error "未找到 claude 命令"

case "${1:-help}" in
    switch)     shift; cmd_switch     "$@" ;;
    run)        shift; cmd_run        "$@" ;;
    restore)    shift; cmd_restore    "$@" ;;
    current)    cmd_current ;;
    list)       cmd_list ;;
    token)      shift; cmd_token      "$@" ;;
    provider)   shift; cmd_provider    "$@" ;;
    completion) shift; cmd_completion  "$@" ;;
    help|--help|-h) cmd_help ;;
    *)          warn "未知命令: $1"; cmd_help; exit 1 ;;
esac
