# My Migrate Disk

通用的根目录磁盘空间迁移技能，通过软链接方式解决根分区空间不足的问题。支持用户自定义阈值，仅迁移超过阈值的目录。

## 核心特性

1. **通用方案** - 不限定特定目录，扫描 /root 下所有子目录
2. **阈值驱动** - 用户设置阈值大小，仅处理超过阈值的目录
3. **交互选择** - 显示候选目录列表，用户可选择性迁移
4. **自动验证** - 迁移后自动验证软链接和命令可用性
5. **清单生成** - 生成迁移报告到统一文档项目

## 设计原则

| 原则 | 说明 |
|------|------|
| 通用性 | 支持任何 /root 下的子目录，不限定特定目录 |
| 最小干预 | 低于阈值的目录不处理，减少风险 |
| 用户控制 | 用户选择要迁移的目录，非全自动 |
| 可逆性 | 软链接方式，便于回滚 |

## 使用流程

### 1. 诊断阶段

运行诊断脚本查看当前磁盘空间和 /root 目录占用：

```bash
bash /data/claude/claude_root/skills/my-migrate-disk/SCRIPTS/diagnose.sh
```

输出示例：
```
=== 根分区空间 ===
/dev/mapper/ubuntu--vg-ubuntu--lv  9.8G  8.5G  1.3G  87% /

=== /root 目录大小 (TOP 10) ===
2.0G    /root/.npm
1.1G    /root/.nvm
560M    /root/venv
450M    /root/ai
...
```

### 2. 扫描阶段

扫描 /root 下超过指定阈值的目录：

```bash
bash /data/claude/claude_root/skills/my-migrate-disk/SCRIPTS/scan.sh 100M
```

参数说明：
- 阈值格式：`100M`、`1G`、`500K`
- 默认阈值：100M
- 跳过已存在的软链接

输出示例：
```
=== 超过 100M 的目录 ===
  2.0G  /root/.npm
  1.1G  /root/.nvm
  560M  /root/venv
  450M  /root/ai
  ...

请输入要迁移的目录编号（逗号分隔，如 1,3,5），或 'a' 全部迁移，'n' 退出：
```

### 3. 迁移阶段

根据用户选择执行迁移：

```bash
bash /data/claude/claude_root/skills/my-migrate-disk/SCRIPTS/migrate.sh
```

迁移脚本会自动：
1. 创建 `/data/migrate-root/` 目标目录
2. 移动选中目录到目标位置
3. 创建软链接回 /root
4. 验证软链接有效性

### 4. 验证阶段

验证迁移结果：

```bash
bash /data/claude/claude_root/skills/my-migrate-disk/SCRIPTS/verify.sh
```

验证内容：
- 软链接是否正确
- 目标目录是否存在
- 常用命令是否正常

## 目标目录结构

```
/data/
└── migrate-root/              # 迁移目标根目录
    ├── .npm                  # 原始 /root/.npm
    ├── .nvm                  # 原始 /root/.nvm
    ├── venv                  # 原始 /root/venv
    └── ...                   # 其他迁移的目录
```

## 统一文档项目

迁移清单保存到用户统一文档项目的 `migrated-disk/` 目录：

- 文件名格式：`{主机名}-{IP}-{日期}-migrated.md`
- 示例：`aiubuntus1-192.168.40.201-2026-04-27-migrated.md`
- 统一文档项目路径从 `~/.claude/memory/user_doc_dir.md` 读取

## 脚本说明

| 脚本 | 功能 |
|------|------|
| `diagnose.sh` | 诊断磁盘空间，显示根分区和 /root 目录占用 |
| `scan.sh` | 扫描超过阈值的目录，显示并收集用户选择 |
| `migrate.sh` | 执行迁移，创建软链接，生成清单 |
| `verify.sh` | 验证迁移结果，检查软链接和命令 |

## 注意事项

1. **建议阈值** - 设为 50M~200M 较为合适，太小无意义，太大可能遗漏重要目录
2. **保留目录** - 建议保留 `sh`（项目目录）、`.config`（配置）、`.ssh`（密钥）
3. **验证重要命令** - 迁移后确认 node/npm/python/git 等命令正常
4. **软链接断裂** - 使用 `readlink -f /root/<path>` 检查目标是否存在

## 故障排除

### 软链接断裂

```bash
# 检查状态
ls -la /root/<link>

# 修复
rm /root/<link>
ln -s /data/migrate-root/<dir> /root/<dir>
```

### 命令找不到

```bash
# 刷新环境
source ~/.bashrc
exec $SHELL
```

### 回滚操作

```bash
# 移除软链接
rm /root/<link>

# 移回原目录
mv /data/migrate-root/<dir> /root/<dir>
```
