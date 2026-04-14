# cc-model 需求文档

## 概述

`cc-model` 是 Claude Code 多模型切换工具，通过修改 `~/.claude/settings.json` 实现模型的永久或临时切换。

**核心特性**：
- 双级配置：供应商(Provider) + 模型(Model)
- 支持多供应商：Anthropic 官方、OpenRouter、MiniMax 国内直连、自定义供应商
- 官方供应商（Anthropic）无需配置 token
- 安全存储：Token 文件权限 600

---

## 概念模型

### 供应商 (Provider)

供应商是 API 端点的抽象，包含以下属性：

| 属性 | 说明 | 示例 |
|------|------|------|
| `base_url` | API 端点地址 | `https://openrouter.ai/api/v1` |
| `auth_key` | 认证密钥环境变量名 | `ANTHROPIC_API_KEY` |
| `token_required` | 是否需要 token | `true` / `false` |
| `is_official` | 是否为 Claude Code 官方供应商 | `true` / `false` |
| `desc` | 显示名称 | `OpenRouter` |

**内置供应商**：

| 供应商 | Base URL | Auth Key | 需要 Token | 说明 |
|--------|----------|----------|------------|------|
| `anthropic` | （官方端点） | - | 否 | Anthropic 官方，Claude Code 原生支持 |
| `openrouter` | `https://openrouter.ai/api/v1` | `ANTHROPIC_API_KEY` | 是 | OpenRouter 聚合平台 |
| `minimax` | `https://api.minimaxi.com/anthropic` | `ANTHROPIC_AUTH_TOKEN` | 是 | MiniMax 国内直连 |

### 模型 (Model)

模型是实际可用的 AI 模型，包含以下属性：

| 属性 | 说明 | 示例 |
|------|------|------|
| `provider` | 所属供应商 | `openrouter` |
| `model_id` | 供应商侧的实际模型 ID | `anthropic/claude-sonnet-4-6` |
| `desc` | 显示名称 | `Claude Sonnet 4.6（OpenRouter）` |

---

## 命名规范

### 命名规则：供应商-模型-版本

非官方供应商的模型统一采用 **供应商-模型-版本** 三级命名：

| 别名 | Provider | Model ID | 说明 |
|------|----------|----------|------|
| `openrouter-sonnet` | openrouter | `anthropic/claude-sonnet-4-6` | Claude Sonnet via OpenRouter |
| `openrouter-haiku` | openrouter | `anthropic/claude-haiku-4-5-20251001` | Claude Haiku via OpenRouter |
| `openrouter-gpt-4o` | openrouter | `openai/gpt-4o` | GPT-4o via OpenRouter |
| `openrouter-gemini-pro` | openrouter | `google/gemini-2.5-pro-preview-03-25` | Gemini 2.5 Pro via OpenRouter |
| `openrouter-llama-3-70b` | openrouter | `meta-llama/llama-3-3-70b-instruct` | Llama 3.3 70B via OpenRouter |
| `minimax-m2` | minimax | `MiniMax-M2.7-highspeed` | MiniMax M2 国内直连 |

### Anthropic 官方模型

官方模型保持简洁命名：

| 别名 | Model ID | 说明 |
|------|----------|------|
| `claude` / `claude-opus` | `claude-opus-4-6` | Claude Opus 4.6 |
| `claude-sonnet` | `claude-sonnet-4-6` | Claude Sonnet 4.6 |
| `claude-haiku` | `claude-haiku-4-5-20251001` | Claude Haiku 4.5 |
| `claude-3-5-sonnet` | `claude-sonnet-4-6` | Claude 3.5 Sonnet |
| `claude-3-opus` | `claude-3-opus` | Claude 3 Opus |

---

## 功能规格

### 1. 模型切换

#### 1.1 永久切换 (switch)

```bash
cc-model switch <model>
```

将模型写入 `~/.claude/settings.json`，下次 Claude Code 启动默认使用该模型。

**行为**：
- 官方供应商（anthropic）：不写入任何 token 或 base_url
- 其他供应商：写入 `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN` 和 `ANTHROPIC_BASE_URL`
- 切换前自动备份 `settings.json`

**示例**：
```bash
cc-model switch claude              # 官方，无需 token
cc-model switch openrouter-sonnet  # OpenRouter，需配置 token
cc-model switch minimax-m2         # MiniMax 国内直连
```

#### 1.2 临时运行 (run)

```bash
cc-model run <model> [claude args...]
```

通过环境变量临时启动 Claude Code，不修改 `settings.json`。

**示例**：
```bash
cc-model run openrouter-gemini-pro -p "解释这段代码"
```

### 2. 供应商管理

```bash
cc-model provider list              # 列出所有供应商
cc-model provider add <name> <base_url> [auth_key]  # 添加自定义供应商
cc-model provider del <name>       # 删除自定义供应商（内置不可删）
```

**示例 - 添加 Azure**：
```bash
cc-model provider add azure https://xxx.openai.azure.com ANTHROPIC_API_KEY
```

### 3. Token 管理

```bash
cc-model token set <provider> <token>  # 保存 token（权限 600）
cc-model token del <provider>          # 删除 token
cc-model token list                     # 列出已配置的 provider
```

**存储位置**：`~/.config/cc-model/tokens`

### 4. 备份与恢复

```bash
cc-model restore [n]   # 恢复 settings.json 到第 n 个备份（默认 1=最新）
```

- 备份目录：`~/.config/cc-model/backups`
- 保留数量：默认 5 份
- 恢复前自动备份当前文件

### 5. 其他命令

```bash
cc-model current       # 显示当前模型配置
cc-model list          # 列出所有支持的模型
cc-model help          # 显示帮助
```

### 6. Shell 补全

```bash
cc-model completion [bash|zsh]
```

支持多层级补全：
- 命令补全：`switch`, `run`, `provider`, `token`...
- 模型补全：所有可用模型别名
- 参数补全：根据上下文补全 provider、token 等

**安装**：
```bash
# Bash
echo 'eval "$(cc-model completion bash)"' >> ~/.bashrc

# Zsh
echo 'eval "$(cc-model completion zsh)"' >> ~/.zshrc
```

---

## 配置数据结构

### settings.json

```json
{
  "model": "claude-opus-4-6",
  "env": {
    "ANTHROPIC_API_KEY": "sk-xxx"
  }
}
```

### Token 文件

```
# ~/.config/cc-model/tokens
anthropic=sk-ant-xxx
openrouter=sk-or-xxx
minimax=mm-key-xxx
```

### Provider 文件（自定义）

```
# ~/.config/cc-model/providers
azure=https://xxx.openai.azure.com|ANTHROPIC_API_KEY|true|false|Azure
```

---

## 快速入门

### 1. 切换到官方 Claude

```bash
cc-model switch claude
# 无需配置 token，Claude Code 自动处理
```

### 2. 通过 OpenRouter 使用 Claude

```bash
# 1. 配置 OpenRouter token
cc-model token set openrouter sk-or-v1-xxxx

# 2. 切换模型
cc-model switch openrouter-sonnet   # Claude Sonnet
cc-model switch openrouter-haiku    # Claude Haiku
```

### 3. MiniMax 国内直连

```bash
# 1. 配置 MiniMax token
cc-model token set minimax <YOUR_MINIMAX_KEY>

# 2. 切换模型
cc-model switch minimax-m2
```

### 4. 添加自定义供应商

```bash
# 添加 Groq 或其他兼容 API
cc-model provider add groq https://api.groq.com/anthropic ANTHROPIC_API_KEY
```

---

## 目录结构

```
~/.config/cc-model/
├── tokens              # API Token 存储（权限 600）
├── providers          # 自定义供应商定义
├── models             # 自定义模型定义
└── backups/           # settings.json 备份
    ├── settings.json.bak.20260414_022412
    └── settings.json.bak.20260413_132052
```

---

## 测试覆盖

| 测试模块 | 测试数 | 说明 |
|----------|--------|------|
| validate_model | 12 | 模型别名验证 |
| get_token | 5 | Token 读取 |
| backup_file | 6 | 备份功能 |
| read_settings | 2 | 读取设置 |
| write_settings | 5 | 写入设置 |
| cmd_switch | 13 | 模型切换 |
| cmd_restore | 8 | 备份恢复 |
| cmd_token | 11 | Token 管理 |
| provider_get | 13 | 供应商字段解析 |
| model_get | 11 | 模型字段解析 |
| cmd_provider | 11 | 供应商管理 |
| 新模型别名 | 4 | 新命名验证 |
| cmd_switch 官方 | 5 | 官方供应商测试 |
| openrouter-sonnet | 4 | OpenRouter 模型测试 |
| **总计** | **110** | **全部通过** |

---

## 版本历史

### v2.0 (2026-04-14)

- **双级配置**：供应商 + 模型分离
- **供应商管理**：`provider add/del/list` 命令
- **官方免 token**：Anthropic 官方供应商无需配置 token
- **命名规范**：供应商-模型-版本 三级命名
- **Shell 补全**：多层级参数补全
- **测试覆盖**：110 个测试用例

---

## 附录：完整模型列表

### Anthropic 官方

```
claude / claude-opus        Claude Opus 4.6（旗舰）
claude-sonnet               Claude Sonnet 4.6（均衡）
claude-haiku               Claude Haiku 4.5（快速）
claude-3-5-sonnet          Claude 3.5 Sonnet
claude-3-opus              Claude 3 Opus
claude-3-sonnet            Claude 3 Sonnet
claude-3-haiku             Claude 3 Haiku
```

### OpenRouter

```
openrouter-sonnet           Claude Sonnet 4.6
openrouter-haiku           Claude Haiku 4.5
openrouter-gpt-4o          GPT-4o
openrouter-gpt-4o-mini     GPT-4o Mini
openrouter-gpt-4-turbo     GPT-4 Turbo
openrouter-gemini-pro      Gemini 2.5 Pro
openrouter-gemini-2-pro    Gemini 2.0 Pro
openrouter-gemini-flash    Gemini 2.0 Flash
openrouter-deepseek-chat   DeepSeek V2.5
openrouter-mistral-large   Mistral Large 2
openrouter-llama-3-70b     Llama 3.3 70B
openrouter-qwen-2-72b      Qwen 2 72B
openrouter-yi-large        Yi Large
openrouter-glm-4-32b       GLM-4-32B
openrouter-minimax-m2      MiniMax M2
openrouter-groq-llama-3-70b Llama 3.3 70B (Groq)
```

### MiniMax 国内直连

```
minimax-m2                 MiniMax M2（国内直连，无需科学上网）
```
