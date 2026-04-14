#!/usr/bin/env bash
# cc-model-test.sh — cc-model.sh 单元测试套件
# 用法: bash cc-model-test.sh
#
# 设计说明：
#   - source cc-model.sh 在全局作用域执行，保证 declare -A 数组对所有函数可见
#   - 每个 section/子测试调用 _setup/_teardown 建立/销毁沙盒目录
#   - error() 覆盖为 return 1，防止 exit 终止测试进程

set -uo pipefail   # 不加 -e，单个失败不中断套件

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/cc-model.sh"
ORIG_PATH="${PATH}"

# ── 全局 source（必须在函数外，否则 declare -A 产生局部变量）──
# shellcheck source=cc-model.sh
source "${SCRIPT}"
set +e   # 覆盖 source 注入的 set -e

# 覆盖 error()：测试中用 return 1 代替 exit 1
error() { printf '\033[31m[ERR]\033[0m   %s\n' "$*" >&2; return 1; }

# ════════════════════════════════════════
#  测试框架
# ════════════════════════════════════════
PASS=0; FAIL=0
declare -a ERRORS=()
CURRENT_SECTION=""

_pass() { PASS=$((PASS+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
_fail() {
    FAIL=$((FAIL+1))
    ERRORS+=("${CURRENT_SECTION} / $1: $2")
    printf '  \033[31m✗\033[0m %s\n    → %s\n' "$1" "$2"
}

assert_eq() {
    [[ "$2" == "$3" ]] \
        && _pass "$1" \
        || _fail "$1" "期望 '$2'，实际 '$3'"
}
assert_match() {
    [[ "$3" =~ $2 ]] \
        && _pass "$1" \
        || _fail "$1" "期望匹配模式 '$2'，实际 '$3'"
}
assert_contains() {
    [[ "$3" == *"$2"* ]] \
        && _pass "$1" \
        || _fail "$1" "期望含 '$2'"
}
assert_file_exists() {
    [[ -f "$2" ]] && _pass "$1" || _fail "$1" "文件不存在: $2"
}
assert_file_not_exists() {
    [[ ! -f "$2" ]] && _pass "$1" || _fail "$1" "文件不应存在: $2"
}
# 注意：bash 中子 shell 作为 if 条件时 set -e 会被抑制（POSIX 行为）。
# 正确做法：先在子 shell 中运行（使用 set -e，error()返回1 + set -e 触发 || error 退出），
# 再在 if 外部单独捕获退出码。
# 子 shell 继承所有变量和函数，文件变更（磁盘）在子 shell 结束后仍然有效。
_run_check() {
    local code
    ( set -e; "$@" ) &>/dev/null
    code=$?   # 必须先赋值再 return，避免 local code=$? 的 local 覆盖问题
    return "${code}"
}
assert_exit_ok() {
    local desc="$1"; shift
    local code
    _run_check "$@"; code=$?
    if [[ ${code} -eq 0 ]]; then _pass "${desc}"
    else _fail "${desc}" "应成功但失败 (exit=${code}): $*"; fi
}
assert_exit_fail() {
    local desc="$1"; shift
    local code
    _run_check "$@"; code=$?
    if [[ ${code} -ne 0 ]]; then _pass "${desc}"
    else _fail "${desc}" "应失败但成功: $*"; fi
}

section() { CURRENT_SECTION="$1"; printf '\n\033[1;34m▶ %s\033[0m\n' "$1"; }

# ════════════════════════════════════════
#  沙盒：每个 section/子测试独立目录
# ════════════════════════════════════════
TEST_HOME=""

_setup() {
    TEST_HOME="$(mktemp -d)"

    # mock claude 可执行文件
    mkdir -p "${TEST_HOME}/bin"
    printf '#!/bin/bash\necho "mock-claude $*"\n' > "${TEST_HOME}/bin/claude"
    chmod +x "${TEST_HOME}/bin/claude"
    export PATH="${TEST_HOME}/bin:${ORIG_PATH}"

    # 重定向所有路径到沙盒（函数体内赋值对全局可见）
    SETTINGS_FILE="${TEST_HOME}/.claude/settings.json"
    TOKEN_FILE="${TEST_HOME}/.config/cc-model/tokens"
    CONFIG_DIR="${TEST_HOME}/.config/cc-model"
    BACKUP_DIR="${TEST_HOME}/.config/cc-model/backups"
    BACKUP_KEEP=3
}

_teardown() {
    [[ -n "${TEST_HOME}" ]] && rm -rf "${TEST_HOME}"
    TEST_HOME=""
    export PATH="${ORIG_PATH}"
}

# 辅助
_write_token() {
    mkdir -p "$(dirname "${TOKEN_FILE}")"
    echo "${1}=${2}" >> "${TOKEN_FILE}"
    chmod 600 "${TOKEN_FILE}"
}
_write_settings() {
    mkdir -p "$(dirname "${SETTINGS_FILE}")"
    printf '%s' "$1" > "${SETTINGS_FILE}"
}

# ════════════════════════════════════════
#  1. validate_model
# ════════════════════════════════════════
section "validate_model"
_setup

for m in claude claude-opus claude-sonnet claude-haiku openrouter-sonnet openrouter-gpt-4o openrouter-gemini-pro openrouter-glm-4-32b openrouter-minimax-m2 minimax-m2; do
    assert_exit_ok "合法别名 '${m}' 通过验证" validate_model "${m}"
done
assert_exit_fail "非法别名 'gpt5' 报错"             validate_model "gpt5"
assert_exit_fail "非法别名 '' 空字符串报错"          validate_model ""
assert_exit_fail "非法别名 'CLAUDE' 大小写敏感报错"  validate_model "CLAUDE"

_teardown

# ════════════════════════════════════════
#  2. get_token
# ════════════════════════════════════════
section "get_token"
_setup

assert_exit_fail "token 文件不存在时报错" get_token "anthropic"

_write_token "anthropic"  "sk-ant-test123"
_write_token "openrouter" "sk-or-test456"
_write_token "minimax"    "mm-key=has-equals"   # token 含 = 号（Base64 常见）

assert_eq "anthropic token 读取正确" \
    "sk-ant-test123" "$(get_token anthropic)"
assert_eq "openrouter token 读取正确" \
    "sk-or-test456" "$(get_token openrouter)"
assert_eq "含 = 号的 token 完整读取（cut -f2- 不截断）" \
    "mm-key=has-equals" "$(get_token minimax)"
assert_exit_fail "不存在的 provider 报错" get_token "no_such_provider"

_teardown

# ════════════════════════════════════════
#  3. backup_file
# ════════════════════════════════════════
section "backup_file"
_setup

# 源文件不存在时静默跳过
assert_exit_ok "源文件不存在时返回 0" backup_file "${SETTINGS_FILE}"
assert_file_not_exists "无备份文件产生" "${BACKUP_DIR}/settings.json.bak.99990101_000000"

# 正常备份
mkdir -p "$(dirname "${SETTINGS_FILE}")"
echo '{"model":"v0"}' > "${SETTINGS_FILE}"
backup_file "${SETTINGS_FILE}" &>/dev/null

bak_count=$(ls "${BACKUP_DIR}/settings.json.bak."* 2>/dev/null | wc -l | tr -d ' ')
assert_eq "备份后存在 1 个备份文件" "1" "${bak_count}"

bak_file=$(ls "${BACKUP_DIR}/settings.json.bak."* 2>/dev/null | head -1)
assert_eq "备份内容与原文件一致" '{"model":"v0"}' "$(cat "${bak_file}")"
assert_match "备份文件名格式 *.bak.YYYYMMDD_HHMMSS" \
    'settings\.json\.bak\.[0-9]{8}_[0-9]{6}$' "$(basename "${bak_file}")"

# 超出 BACKUP_KEEP=3 时清理最旧备份
# 预置 3 个旧备份（用 touch -t 设置明确时间顺序）
mkdir -p "${BACKUP_DIR}"
touch -t 202601010000 "${BACKUP_DIR}/settings.json.bak.20260101_000000"
touch -t 202601010100 "${BACKUP_DIR}/settings.json.bak.20260101_010000"
touch -t 202601010200 "${BACKUP_DIR}/settings.json.bak.20260101_020000"
# 当前已有 1(正常备份)+3(预置)=4 个，再触发 2 次 → 总 6，清理到 3
backup_file "${SETTINGS_FILE}" &>/dev/null
backup_file "${SETTINGS_FILE}" &>/dev/null
remaining=$(ls "${BACKUP_DIR}/settings.json.bak."* 2>/dev/null | wc -l | tr -d ' ')
assert_eq "超出 BACKUP_KEEP=3 后只保留 3 个备份" "3" "${remaining}"

_teardown

# ════════════════════════════════════════
#  4. read_settings
# ════════════════════════════════════════
section "read_settings"
_setup

assert_eq "文件不存在时返回 {}" "{}" "$(read_settings)"

_write_settings '{"model":"test","theme":"dark"}'
assert_eq "文件存在时返回内容" \
    '{"model":"test","theme":"dark"}' "$(read_settings)"

_teardown

# ════════════════════════════════════════
#  5. write_settings
# ════════════════════════════════════════
section "write_settings"
_setup

write_settings '{"model":"claude-sonnet-4-6"}' &>/dev/null
assert_file_exists "write_settings 创建 SETTINGS_FILE" "${SETTINGS_FILE}"

content="$(cat "${SETTINGS_FILE}")"
assert_contains "写入正确 model 字段" '"model": "claude-sonnet-4-6"' "${content}"
assert_match "JSON 已格式化（含换行）" $'\n' "${content}"

# 再次写入时，旧文件应被备份
write_settings '{"model":"claude-opus-4-6"}' &>/dev/null
bak_count=$(ls "${BACKUP_DIR}/settings.json.bak."* 2>/dev/null | wc -l | tr -d ' ')
assert_eq "write_settings 写入前自动备份" "1" "${bak_count}"

bak_content="$(cat "$(ls -t "${BACKUP_DIR}/settings.json.bak."* | head -1)")"
assert_contains "备份内容是写入前的旧内容" \
    '"model": "claude-sonnet-4-6"' "${bak_content}"

_teardown

# ════════════════════════════════════════
#  6. cmd_switch
# ════════════════════════════════════════
section "cmd_switch"
_setup

_write_token "anthropic"  "sk-ant-abc"
_write_token "openrouter" "sk-or-xyz"
_write_token "minimax"    "mm-cn-key"
_write_settings '{"theme":"dark","model":"old"}'

# 切换到 Anthropic 官方模型（由 Claude Code 自身管理认证，不写入 token）
cmd_switch "claude-sonnet" &>/dev/null
content="$(cat "${SETTINGS_FILE}")"
assert_contains "switch claude-sonnet 写入正确 model"         '"model": "claude-sonnet-4-6"'  "${content}"
assert_eq "switch Anthropic 模型不写入 ANTHROPIC_API_KEY" \
    "0" "$(grep -c 'ANTHROPIC_API_KEY' "${SETTINGS_FILE}")"
assert_eq "switch Anthropic 模型不写入 ANTHROPIC_AUTH_TOKEN" \
    "0" "$(grep -c 'ANTHROPIC_AUTH_TOKEN' "${SETTINGS_FILE}")"
assert_contains "switch claude-sonnet 保留已有 theme 字段" '"theme": "dark"'               "${content}"
assert_eq "switch Anthropic 模型不写入 BASE_URL" \
    "0" "$(grep -c 'ANTHROPIC_BASE_URL' "${SETTINGS_FILE}")"

# 切换到 OpenRouter 模型，应写入 BASE_URL
cmd_switch "openrouter-gemini-pro" &>/dev/null
content="$(cat "${SETTINGS_FILE}")"
assert_contains "switch openrouter-gemini-pro 写入 ANTHROPIC_BASE_URL 键" '"ANTHROPIC_BASE_URL"' "${content}"
assert_contains "switch openrouter-gemini-pro BASE_URL 指向 openrouter"   'openrouter.ai'       "${content}"

# 切回官方 Claude，BASE_URL 应被移除
cmd_switch "claude" &>/dev/null
assert_eq "switch 回 claude 官方后移除 BASE_URL" \
    "0" "$(grep -c 'ANTHROPIC_BASE_URL' "${SETTINGS_FILE}")"

# 切换到 MiniMax 国内端点（Anthropic 兼容端点）
cmd_switch "minimax-m2" &>/dev/null
content="$(cat "${SETTINGS_FILE}")"
assert_contains "switch minimax-m2 BASE_URL 指向 minimaxi 端点"  'api.minimaxi.com'  "${content}"
assert_contains "switch minimax-m2 使用 ANTHROPIC_AUTH_TOKEN"      'ANTHROPIC_AUTH_TOKEN' "${content}"
assert_contains "switch minimax-m2 写入正确 model id"              'MiniMax-M2.7-highspeed' "${content}"

# switch 写入前自动备份（快速连续调用时间戳可能相同，只验证备份目录非空）
bak_count=$(ls "${BACKUP_DIR}/settings.json.bak."* 2>/dev/null | wc -l | tr -d ' ')
assert_exit_ok "cmd_switch 写入前产生了备份文件" test "${bak_count}" -gt 0

_teardown

# ════════════════════════════════════════
#  7. cmd_restore（每个子场景独立沙盒）
# ════════════════════════════════════════
section "cmd_restore"

# ── 7a: 无备份时报错 ──
_setup
assert_exit_fail "无备份时 restore 报错" cmd_restore
_teardown

# ── 7b: 默认恢复最新备份（n=1）──
_setup
mkdir -p "${BACKUP_DIR}"
echo '{"model":"v1"}' > "${BACKUP_DIR}/settings.json.bak.20260101_100000"
touch -t 202601011000   "${BACKUP_DIR}/settings.json.bak.20260101_100000"
echo '{"model":"v2"}' > "${BACKUP_DIR}/settings.json.bak.20260101_110000"
touch -t 202601011100   "${BACKUP_DIR}/settings.json.bak.20260101_110000"
_write_settings '{"model":"current"}'

bak_before=$(ls "${BACKUP_DIR}/settings.json.bak."* 2>/dev/null | wc -l | tr -d ' ')
cmd_restore &>/dev/null
restored=$(python3 -c "import json; print(json.load(open('${SETTINGS_FILE}'))['model'])")
assert_eq "restore 默认恢复最近备份 v2" "v2" "${restored}"

bak_after=$(ls "${BACKUP_DIR}/settings.json.bak."* 2>/dev/null | wc -l | tr -d ' ')
assert_eq "restore 恢复前自动备份当前文件（备份数 +1）" \
    "$((bak_before + 1))" "${bak_after}"
_teardown

# ── 7c: 恢复第二新备份（n=2）──
_setup
mkdir -p "${BACKUP_DIR}"
echo '{"model":"v1"}' > "${BACKUP_DIR}/settings.json.bak.20260101_100000"
touch -t 202601011000   "${BACKUP_DIR}/settings.json.bak.20260101_100000"
echo '{"model":"v2"}' > "${BACKUP_DIR}/settings.json.bak.20260101_110000"
touch -t 202601011100   "${BACKUP_DIR}/settings.json.bak.20260101_110000"
_write_settings '{"model":"current"}'

cmd_restore 2 &>/dev/null
restored=$(python3 -c "import json; print(json.load(open('${SETTINGS_FILE}'))['model'])")
assert_eq "restore 2 恢复第二新备份 v1" "v1" "${restored}"
_teardown

# ── 7d: 边界和非法参数 ──
_setup
mkdir -p "${BACKUP_DIR}"
echo '{}' > "${BACKUP_DIR}/settings.json.bak.20260101_100000"

assert_exit_fail "restore 越界序号 999 报错" cmd_restore 999
assert_exit_fail "restore 非数字参数报错"     cmd_restore "abc"
assert_exit_fail "restore 0 报错"             cmd_restore 0
assert_exit_fail "restore 负数报错"           cmd_restore -1
_teardown

# ════════════════════════════════════════
#  8. cmd_token set / del / list
# ════════════════════════════════════════
section "cmd_token set/del/list"
_setup

# set 新 provider
cmd_token set "anthropic" "sk-ant-new" &>/dev/null
assert_file_exists "token set 创建 token 文件" "${TOKEN_FILE}"
assert_eq "token set 写入 anthropic 正确" \
    "sk-ant-new" "$(get_token anthropic)"
perm="$(stat -c "%a" "${TOKEN_FILE}")"
assert_eq "token 文件权限为 600" "600" "${perm}"

# set 同 provider 覆盖（不产生重复行）
cmd_token set "anthropic" "sk-ant-updated" &>/dev/null
assert_eq "token set 覆盖已有 provider" \
    "sk-ant-updated" "$(get_token anthropic)"
line_count=$(grep -c "^anthropic=" "${TOKEN_FILE}")
assert_eq "token set 覆盖后无重复行" "1" "${line_count}"

# 第二次 set 时自动备份 token 文件
bak_count=$(ls "${BACKUP_DIR}/tokens.bak."* 2>/dev/null | wc -l | tr -d ' ')
assert_eq "token set 修改前自动备份 token 文件" "1" "${bak_count}"

# 添加第二个 provider
cmd_token set "openrouter" "sk-or-abc" &>/dev/null
assert_eq "token set openrouter 正确" \
    "sk-or-abc" "$(get_token openrouter)"

# list 列出已配置的 provider
list_out="$(cmd_token list 2>&1)"
assert_contains "token list 含 anthropic"  "anthropic"  "${list_out}"
assert_contains "token list 含 openrouter" "openrouter" "${list_out}"

# del 删除指定 provider
cmd_token del "openrouter" &>/dev/null
assert_exit_fail "token del 后 get_token openrouter 应报错" get_token "openrouter"
assert_eq "token del 后 anthropic 仍存在" \
    "sk-ant-updated" "$(get_token anthropic)"

_teardown

# ════════════════════════════════════════
#  9. provider_get 函数
# ════════════════════════════════════════
section "provider_get"

# 内置供应商字段解析
_setup

# anthropic 官方
assert_eq "anthropic base_url 为空（官方端点）" "" "$(provider_get anthropic base_url)"
assert_eq "anthropic auth_key 为空" "" "$(provider_get anthropic auth_key)"
assert_eq "anthropic token_required 为 false" "false" "$(provider_get anthropic token_required)"
assert_eq "anthropic is_official 为 true" "true" "$(provider_get anthropic is_official)"

# openrouter
assert_eq "openrouter base_url 正确" "https://openrouter.ai/api/v1" "$(provider_get openrouter base_url)"
assert_eq "openrouter auth_key 为 ANTHROPIC_API_KEY" "ANTHROPIC_API_KEY" "$(provider_get openrouter auth_key)"
assert_eq "openrouter token_required 为 true" "true" "$(provider_get openrouter token_required)"
assert_eq "openrouter is_official 为 false" "false" "$(provider_get openrouter is_official)"

# minimax
assert_eq "minimax base_url 正确" "https://api.minimaxi.com/anthropic" "$(provider_get minimax base_url)"
assert_eq "minimax auth_key 为 ANTHROPIC_AUTH_TOKEN" "ANTHROPIC_AUTH_TOKEN" "$(provider_get minimax auth_key)"
assert_eq "minimax token_required 为 true" "true" "$(provider_get minimax token_required)"

# 不存在的供应商
assert_exit_fail "不存在的 provider 报错" provider_get "no_such_provider" base_url

_teardown

# ════════════════════════════════════════
#  10. model_get 函数
# ════════════════════════════════════════
section "model_get"

_setup

# 官方模型
assert_eq "claude provider 为 anthropic" "anthropic" "$(model_get claude provider)"
assert_eq "claude model_id 正确" "claude-opus-4-6" "$(model_get claude model_id)"
assert_contains "claude desc 包含 Opus" "Opus" "$(model_get claude desc)"

# OpenRouter 模型
assert_eq "openrouter-gemini-pro provider 为 openrouter" "openrouter" "$(model_get openrouter-gemini-pro provider)"
assert_eq "openrouter-gemini-pro model_id 正确" "google/gemini-2.5-pro-preview-03-25" "$(model_get openrouter-gemini-pro model_id)"

# 通过 OpenRouter 的 Claude 模型
assert_eq "openrouter-sonnet provider 为 openrouter" "openrouter" "$(model_get openrouter-sonnet provider)"
assert_eq "openrouter-sonnet model_id 为 anthropic/claude-sonnet-4-6" "anthropic/claude-sonnet-4-6" "$(model_get openrouter-sonnet model_id)"
assert_eq "openrouter-haiku model_id 正确" "anthropic/claude-haiku-4-5-20251001" "$(model_get openrouter-haiku model_id)"

# MiniMax 国内直连
assert_eq "minimax-m2 provider 为 minimax" "minimax" "$(model_get minimax-m2 provider)"
assert_eq "minimax-m2 model_id 正确" "MiniMax-M2.7-highspeed" "$(model_get minimax-m2 model_id)"

# 不存在的模型
assert_exit_fail "不存在的模型报错" model_get "nonexistent_model" provider

_teardown

# ════════════════════════════════════════
#  11. cmd_provider 管理命令
# ════════════════════════════════════════
section "cmd_provider"

# ── 11a: provider list ──
_setup
list_out="$(cmd_provider list 2>&1)"
assert_contains "provider list 显示 anthropic" "anthropic" "${list_out}"
assert_contains "provider list 显示 openrouter" "openrouter" "${list_out}"
assert_contains "provider list 显示 minimax" "minimax" "${list_out}"
assert_contains "provider list 显示官方标识" "官方" "${list_out}"
_teardown

# ── 11b: provider add 自定义供应商 ──
_setup
cmd_provider add "azure" "https://xxx.openai.azure.com" "ANTHROPIC_API_KEY" &>/dev/null
assert_file_exists "provider add 创建 provider 文件" "${PROVIDER_FILE}"
assert_contains "provider add 内容正确" "azure" "$(cat "${PROVIDER_FILE}")"
assert_contains "provider add base_url 正确" "xxx.openai.azure.com" "$(cat "${PROVIDER_FILE}")"

# 重复添加应覆盖
cmd_provider add "azure" "https://yyy.openai.azure.com" &>/dev/null
line_count=$(grep -c "^azure=" "${PROVIDER_FILE}")
assert_eq "provider add 重复添加覆盖而非重复" "1" "${line_count}"
_teardown

# ── 11c: provider add 内置供应商应报错 ──
_setup
assert_exit_fail "provider add 内置供应商（anthropic）报错" cmd_provider add "anthropic" "http://test"
_teardown

# ── 11d: provider del 自定义供应商 ──
_setup
cmd_provider add "testprov" "http://test.com" &>/dev/null
cmd_provider del "testprov" &>/dev/null
assert_eq "provider del 删除成功" "" "$(grep "^testprov=" "${PROVIDER_FILE}" 2>/dev/null || echo "")"
_teardown

# ── 11e: provider del 内置供应商应报错 ──
_setup
assert_exit_fail "provider del 内置供应商（openrouter）报错" cmd_provider del "openrouter"
_teardown

# ════════════════════════════════════════
#  12. 新模型别名测试
# ════════════════════════════════════════
section "新模型别名验证"

_setup

# 通过 OpenRouter 的 Claude 模型应通过验证
assert_exit_ok "openrouter-sonnet 通过验证" validate_model "openrouter-sonnet"
assert_exit_ok "openrouter-haiku 通过验证" validate_model "openrouter-haiku"

# 其他新增模型
assert_exit_ok "openrouter-gpt-4o-mini 通过验证" validate_model "openrouter-gpt-4o-mini"
assert_exit_ok "openrouter-yi-large 通过验证" validate_model "openrouter-yi-large"

_teardown

# ════════════════════════════════════════
#  13. cmd_switch 官方供应商无需 token
# ════════════════════════════════════════
section "cmd_switch 官方供应商"

_setup

# anthropic 官方供应商不需要 token
_write_settings '{"model":"old"}'

# 故意不设置 anthropic token，切换应该成功
cmd_switch "claude" &>/dev/null
content="$(cat "${SETTINGS_FILE}")"
assert_contains "switch 官方 claude 成功" "claude-opus-4-6" "${content}"
assert_eq "switch 官方 claude 不写入 API_KEY" "0" "$(grep -c 'ANTHROPIC_API_KEY' "${SETTINGS_FILE}")"
assert_eq "switch 官方 claude 不写入 AUTH_TOKEN" "0" "$(grep -c 'ANTHROPIC_AUTH_TOKEN' "${SETTINGS_FILE}")"
assert_eq "switch 官方 claude 不写入 BASE_URL" "0" "$(grep -c 'ANTHROPIC_BASE_URL' "${SETTINGS_FILE}")"

# claude-haiku 也应该一样
cmd_switch "claude-haiku" &>/dev/null
assert_eq "switch claude-haiku 不写入 token" "0" "$(grep -c 'ANTHROPIC' "${SETTINGS_FILE}")"

_teardown

# ════════════════════════════════════════
#  14. cmd_switch openrouter-sonnet
# ════════════════════════════════════════
section "cmd_switch openrouter-sonnet"

_setup

_write_token "openrouter" "sk-or-claude-access"
_write_settings '{"model":"old"}'

# 通过 OpenRouter 使用 Claude Sonnet
cmd_switch "openrouter-sonnet" &>/dev/null
content="$(cat "${SETTINGS_FILE}")"
assert_contains "openrouter-sonnet model_id 为 anthropic/claude-sonnet-4-6" "anthropic/claude-sonnet-4-6" "${content}"
assert_contains "openrouter-sonnet 使用 openrouter BASE_URL" "openrouter.ai" "${content}"
assert_contains "openrouter-sonnet 写入 ANTHROPIC_API_KEY" "ANTHROPIC_API_KEY" "${content}"

# openrouter-haiku
cmd_switch "openrouter-haiku" &>/dev/null
content="$(cat "${SETTINGS_FILE}")"
assert_contains "openrouter-haiku model_id 正确" "anthropic/claude-haiku-4-5-20251001" "${content}"

_teardown

# ════════════════════════════════════════
#  15. cmd_switch 自定义供应商
# ════════════════════════════════════════
section "cmd_switch 自定义供应商"

_setup

_write_token "azure" "azure-key-123"
cmd_provider add "azure" "https://xxx.openai.azure.com" "ANTHROPIC_API_KEY" &>/dev/null

# 注意：自定义模型需要在 CONFIG_DIR/models 文件中定义
mkdir -p "${CONFIG_DIR}"
echo "my-claude=azure|anthropic/claude-sonnet-4-6|My Claude via Azure" >> "${CONFIG_DIR}/models"

# 重新 source 以加载自定义模型（这里测试 model_get 直接查文件）
assert_eq "自定义供应商模型 model_id 正确" "anthropic/claude-sonnet-4-6" "$(model_get my-claude model_id)"

_teardown

# ════════════════════════════════════════
#  汇总报告
# ════════════════════════════════════════
printf '\n%s\n' "══════════════════════════════════════"
printf '\033[1m测试结果: \033[32m%d 通过\033[0m / \033[31m%d 失败\033[0m\n' "${PASS}" "${FAIL}"

if [[ ${FAIL} -gt 0 ]]; then
    printf '\n\033[31m失败详情:\033[0m\n'
    for e in "${ERRORS[@]}"; do
        printf '  • %s\n' "${e}"
    done
    printf '\n'
    exit 1
else
    printf '\033[32m全部通过\033[0m\n\n'
    exit 0
fi
