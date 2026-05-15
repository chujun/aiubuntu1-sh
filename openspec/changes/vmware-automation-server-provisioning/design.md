# Design: VMware 自动化批量服务器搭建系统

## Context

当前 VMware Workstation Pro 环境下的虚拟机服务器搭建依赖手动操作，每次创建 VM 需要 15-30 分钟人工等待，软件版本难以统一管理，配置变更无法审计跟踪。用户计划从少量机器起步，未来成熟后商业化。

**当前环境约束**：
- Host OS: Windows 11
- 虚拟化平台: VMware Workstation Pro 25H2（非 vSphere/ESXi，无 REST API）
- Guest OS: Ubuntu 24 Server/Desktop，未来扩展到 Debian/CentOS
- 控制节点: 独立的 Linux VM（Ubuntu Server，轻量级，作为 Ansible 控制节点）
- 软件栈: SSH、NTP、Docker、Java、Node、AI 相关应用

**决策树关键结论**（详见 `doc/decision-trees/2026-05-12-VMware自动化方案决策树.md`）：
- 选用控制系统（而非模板系统）→ 便于持续优化和审计跟踪
- 选用 Packer（而非 Terraform）→ Workstation Pro API 限制
- 选用基础 OS 镜像（而非预装软件镜像）→ 软件版本更新频繁，维护成本高
- Ansible 按角色分层组织 → 多种软件栈重叠，复用率最高

## Goals / Non-Goals

**Goals:**
- 实现 VM 镜像自动化构建，将手动创建时间从 15-30 分钟降至 5-10 分钟
- 建立统一的配置管理框架，所有配置版本化存储于 Git
- 支持多软件栈（SSH/NTP/Docker/Java/Node/AI）灵活组合
- 支持多 Linux 发行版（Ubuntu/Debian/CentOS）差异化配置

**Non-Goals:**
- 不实现 VM 的生命周期管理（创建、删除、电源操作）- 这是 Terraform 的职责
- 不实现配置 drift 检测和自动修复
- 不实现商业化的 multi-tenancy 或计费系统
- 不支持物理服务器自动化（纯虚拟化方案）

## Decisions

### Decision 1: Packer + Cloud-Init 作为镜像构建方案

**选择**：采用 Packer（运行在 Windows 上）构建基础 OS 镜像 + Cloud-Init（运行在目标 VM 内部）处理 OS 初始化

**职责分工**：
| 组件 | 运行位置 | 说明 |
|------|---------|------|
| Packer | Windows 11 宿主机 | Windows 原生安装，调用 VMware Workstation API |
| Cloud-Init | 目标 VM 内部 | Ubuntu 24 自带，无需单独部署 |
| Cloud-Init 配置 | 通过 ISO 注入 | Packer 构建时挂载配置 ISO 到虚拟光驱 |

**理由**：
- Workstation Pro 缺乏 vSphere 的 REST API，Terraform 不可用
- Packer 是 VMware 官方推荐的 Workstation 自动化工具
- Cloud-Init 是 Ubuntu 官方支持的无人值守安装标准，Ubuntu 24 自带
- Packer 在 Windows 上可直接访问 VMware 目录，镜像文件存储简单

**替代方案考虑**：
| 方案 | 优点 | 缺点 | 结论 |
|------|------|------|------|
| Terraform + vSphere Provider | 完整的 VM 生命周期管理 | Workstation 不支持 | 排除，未来迁移 vSphere 时可引入 |
| Packer 在 Linux + 同步到 Windows | 统一在 Linux 管理 | 镜像需同步，架构复杂 | 排除 |
| Packer + Cloud-Init（选中） | 职责分离、简单直接 | 需维护 Windows 上的 Packer | 采用 |

### Decision 2: 薄镜像策略（仅含 OS + SSH + Cloud-Init）

**选择**：Packer 构建的镜像仅包含最小化 OS + SSH + Cloud-Init，不预装任何应用软件

**理由**：
- 软件版本更新频繁（Docker/Java/Node），预装软件镜像一旦版本固化，更新成本高
- 薄镜像 + Ansible 组合：镜像构建一次性，配置变更由 Ansible 控制，灵活度高
- Ansible 改配置比重新构建镜像成本低得多

**镜像内容**：
```
基础镜像内容
├── Ubuntu 24 Server/Desktop（最小化安装）
├── OpenSSH Server
└── Cloud-Init（Ubuntu 自带）
```

**注意**：Cloud-Init 是 Ubuntu 24 自带的，无需单独安装。Packer 只需挂载包含 `user-data` 的配置 ISO，Cloud-Init 在 VM 启动后自动读取并执行。

### Decision 3: Ansible Role 按角色分层组织

**选择**：采用 `common/runtime/workload` 三层 Role 结构

**理由**：
- common 层（所有机器必装）：SSH、NTP、防火墙基础配置
- runtime 层（运行时环境）：Docker、Java、Node、Python 等
- workload 层（工作负载）：AI 工作站等特定场景
- 多种软件栈有大量重叠（都要 Docker/SSH），角色分层复用率最高
- 天然支持多 OS 扩展：Role 内通过 `tasks/debian.yml` / `tasks/redhat.yml` 隔离 OS 差异

**目录结构**：
```
ansible/roles/
├── common/                 # 基础角色（所有机器必装）
│   ├── ssh/
│   ├── ntp/
│   └── firewall/
├── runtime/                # 运行时环境
│   ├── docker/
│   ├── java/
│   ├── node/
│   └── python/
└── workload/              # 工作负载
    └── ai-workstation/
```

### Decision 4: 混合控制架构（Packer Windows + Ansible Linux）

**选择**：采用混合架构 - Packer 运行在 Windows 11 宿主机，Ansible 运行在独立的 Linux 控制节点 VM

**架构图**：
```
Windows 11 (Host)
├── VMware Workstation Pro 25H2
│   ├── VM-0: Ansible 控制节点 (Ubuntu Server)
│   │   └── 运行: Ansible, Python, Git, ansible-galaxy
│   └── 其他目标 VM...
│
└── Packer (Windows 原生安装)
    └── 构建镜像到 VMware 目录
```

**职责分工**：
| 组件 | 运行位置 | 职责 |
|------|---------|------|
| Packer | Windows 11 | 构建 VM 镜像，调用 VMware 创建 VM，挂载 Cloud-Init ISO |
| Ansible | Linux 控制节点 VM | 配置管理，SSH 连接到目标 VM，执行 playbooks |

**理由**：
- VMware Workstation Pro 是 Windows 原生应用，无法在 Linux 控制节点上直接运行
- Packer 在 Windows 上可直接调用 vmrun，访问 VMware 目录最简单
- Ansible 在 Linux VM 上运行，无 Windows 兼容性问题
- 镜像文件直接存储在 Windows VMware 目录，无需跨系统同步

**Ansible 控制节点安装依赖**：
```bash
# Ubuntu 24.04 上安装
apt update
apt install -y python3 python3-pip git sshpass rsync
pip3 install ansible ansible-core
ansible-galaxy collection install community.general
```

**替代方案考虑**：
| 方案 | 优点 | 缺点 | 结论 |
|------|------|------|------|
| Windows 直接安装 Ansible | 无需额外 VM | Python 依赖复杂、路径问题多 | 排除 |
| WSL2 | 原生支持 | 用户不想启用 WSL2 | 排除 |
| Packer + Ansible 分置（选中） | 职责分离、简单直接 | 控制节点占用资源 | 采用 |

### Decision 5: Inventory 采用 hosts.yml（YAML 格式）

**选择**：使用 YAML 格式定义 Inventory，而非传统的 INI 格式

**理由**：
- YAML 格式支持层次化数据结构，更易于表达主机组和变量的嵌套关系
- 与 Ansible Playbook 的 YAML 语法保持一致，降低学习成本
- 支持复杂变量定义（如 group_vars、host_vars）

### Decision 6: Ubuntu Server 镜像磁盘与 Packer 构建优化

**选择**：Ubuntu Server 基础镜像保持 40GB 虚拟磁盘，Cloud-Init 使用显式 LVM 存储配置：EFI 512MB、`/boot` 1GB、根分区 20GB、`/data` 使用 VG 剩余空间。

**理由**：
- 根分区 20GB 比 15GB 更适合后续系统包、日志、缓存和基础工具增长，降低根分区不足风险
- `/data` 使用剩余空间，方便承载应用数据、模型文件、Docker 数据等较大内容
- LVM 保留后续扩容和调整空间的弹性，适合未来从学习环境演进到更接近生产的服务器模板

**Packer/VMware 优化约束**：
- VMware 插件版本固定在已验证的 `~> 1.2.0` 系列，降低未来插件不兼容风险
- 虚拟网卡使用 `vmxnet3`，利用 Ubuntu 24 自带驱动获得更好的 VMware 虚拟化性能
- VMX 启用 `disk.EnableUUID = "TRUE"`，便于 Linux/Ansible 后续稳定识别磁盘
- Packer 构建期允许密码 SSH 以完成自动化连接，镜像交付前移除临时 sshd 密码认证配置
- Packer 构建时验证 `/data` 挂载和 `/`、`/data` 容量输出，避免分区配置静默失效
- Packer 缓存、构建输出和日志不纳入 Git，只保留可复现的 HCL 与 Cloud-Init 配置

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| Workstation Pro 性能限制 | 批量创建 VM 时宿主机的 CPU/内存/磁盘 IO 可能成为瓶颈 | 限制同时构建的 VM 数量，建议串行构建后并行克隆 |
| Cloud-Init 与特定 Ubuntu 版本兼容性 | 不同 Ubuntu 24/22/20 的 Cloud-Init 配置可能有差异 | 通过 `ansible_facts['distribution_major_version']` 变量隔离版本差异 |
| Ansible 控制节点单点故障 | 独立 VM 环境异常时无法执行配置管理 | 定期备份 inventory 和 playbooks，Ansible 状态由 Git 管理 |
| 多 OS 适配复杂度超预期 | Debian/Ubuntu/CentOS 的包管理、服务的差异可能比预期大 | Role 内设计 OS 适配层，初期聚焦 Ubuntu，后续逐步扩展 |
| Packer 构建失败排查困难 | 涉及 Packer、VMware、Cloud-Init 多个层面，调试复杂 | 保留详细的构建日志，分层排查（先验证 ISO 挂载，再验证 Cloud-Init） |
| 显式存储配置复杂度 | Cloud-Init 存储配置比默认 LVM layout 更长，维护门槛更高 | 在 `user-data` 中保留分区原因注释，并通过 PyYAML、`packer validate`、`findmnt /data`、`df -h / /data` 分层验证 |

## Migration Plan

### Phase 0: 创建 Ansible 控制节点 VM（Week 0）
1. 在 VMware Workstation Pro 中创建一台轻量级 VM（建议：Ubuntu Server 24.04，2C/4GB/40GB）
2. 配置 VM 网络（与目标 VM 同网段）
3. 在控制节点 VM 中安装 Python、Git、Ansible

### Phase 1: Packer 安装与镜像构建（Week 1）
1. 在 Windows 11 上安装 Packer（下载 Windows 版，解压到指定目录）
2. 创建 `packer/ubuntu-24-server/` 目录结构（可在 Git 仓库中管理）
3. 编写 `ubuntu-24-server.pkr.hcl` 配置文件
4. 配置 Cloud-Init `user-data` 文件
5. 运行 `packer validate` 验证配置
6. 执行 `packer build` 构建第一个基础镜像
7. 验证镜像可正常启动并通过 Cloud-Init 完成初始化
8. 将 packer 配置文件同步到 Git 仓库

### Phase 2: Ansible 框架搭建（Week 2）
1. 在控制节点 VM 中安装 Ansible
2. 创建 `ansible/` 目录结构
3. 编写 `ansible.cfg` 配置文件
4. 创建 `inventory/hosts.yml` 主机清单
5. 实现 common 层 Role（ssh、ntp、firewall）
6. 验证 Ansible 可成功连接到 VM

### Phase 3: 运行时环境 Role（Week 3）
1. 实现 runtime/docker Role
2. 实现 runtime/java Role
3. 实现 runtime/node Role
4. 编写对应的 site.yml playbook
5. 端到端测试：从镜像构建到完整配置

### Phase 4: 多 OS 扩展（Week 4）
1. 添加 Debian 12 支持
2. 在 Role 内实现 OS 条件分支（debian.yml/redhat.yml）
3. 测试跨 OS 的配置一致性

### Rollback Strategy
- 镜像构建失败：检查 .pkr.hcl 配置和 ISO 文件完整性
- Ansible 执行失败：查看 Ansible 日志，单步调试单个 Role
- 配置回滚：通过 Git revert 恢复到上一个稳定版本

## Open Questions

1. **VM 网络配置方案**：Packer 构建时使用 NAT 还是桥接网络？不同场景下的网络策略如何统一？
2. **SSH 密钥管理**：是使用统一的 Ansible Vault 加密存储，还是对接现有的密钥管理系统？
3. **镜像命名规范**：是否需要区分 server/desktop 两种镜像，还是通过同一个镜像 + Ansible 差异化配置？
4. **Packer 构建产物存储**：镜像存储在本地 VMware 目录还是集中存储在 NFS/共享存储上？
5. **商业化扩展路径**：Ansible Tower/AWX 的引入时机和迁移步骤是什么？
