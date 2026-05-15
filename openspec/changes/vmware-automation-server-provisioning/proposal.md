# Proposal: VMware 自动化批量服务器搭建系统

## Why

当前 VMware Workstation Pro 环境下的虚拟机服务器搭建依赖手动操作，存在以下问题：(1) 手动创建 VM 每次耗时 15-30 分钟，无法规模化；(2) 软件版本难以统一管理，无法审计跟踪；(3) 多 OS 支持缺乏统一框架，扩展成本高。本方案旨在建立一套基于 Packer + Cloud-Init + Ansible 的自动化批量服务器搭建系统，满足当前学习用途需求，同时为未来商业化扩展预留架构空间。

## What Changes

1. **新增 Packer 镜像构建流程**：使用 Packer + Cloud-Init 自动构建基础 OS 镜像（Ubuntu 24 Server/Desktop），构建期通过固定 MAC + VMware NAT DHCP 静态保留 + `ssh_host` 获得稳定 SSH 连接，替代纯手动 VM 创建
2. **新增 Ansible 配置管理体系**：基于 Role 分层组织（common/runtime/workload）的配置管理框架，支持 SSH、NTP、防火墙、Docker、Java、Node、AI 应用等软件栈
3. **新增 Cloud-Init 无人值守初始化**：通过 Cloud-Init 自动完成 OS 用户创建、SSH 公钥配置、主机名/网络设置，并显式配置 40GB 系统盘分区（根分区 20GB，`/data` 使用剩余空间）
4. **新增多 OS 适配层**：在 Ansible Role 内通过 OS 条件分支（debian.yml/redhat.yml）支持 Ubuntu/Debian/CentOS 等多发行版

## Capabilities

### New Capabilities

- `vm-image-build`: Packer 镜像构建能力，支持 VMware Workstation Pro 环境下的自动化 VM 镜像构建
- `cloud-init-provisioning`: Cloud-Init OS 初始化能力，支持无人值守的 OS 配置（用户、SSH、网络）
- `ansible-config-management`: Ansible 配置管理能力，基于 Role 分层组织，支持多软件栈的灵活组合
- `multi-os-adaptation`: 多操作系统适配能力，支持 Ubuntu/Debian/CentOS 等 Linux 发行版的配置差异化处理

### Modified Capabilities

- 无（现有系统无相关能力）

## Impact

- **新增目录**：`vm-automation/packer/`（镜像构建配置）、`vm-automation/ansible/`（配置管理）
- **新增 VM**：Ansible 控制节点（独立的轻量级 Linux VM，Ubuntu Server）
- **工具部署**：
  - **Packer**：运行在 Windows 11 宿主机上（Windows 原生安装）
  - **Ansible**：运行在控制节点 Linux VM 上
  - **Cloud-Init**：运行在目标 VM 内部（Ubuntu 24 自带，无需单独部署）
- **镜像文件位置**：存储在 Windows 宿主机 VMware 目录（`C:\Users\<用户>\Documents\Virtual Machines\`）
- **目标环境**：Windows 11 + VMware Workstation Pro 25H2，Guest OS 为 Ubuntu 24
- **未来扩展**：可迁移至 vSphere/ESXi（复用 Packer 配置），可引入 Ansible Tower/AWX（商业化扩展）

## Build Time Expectation

Packer 成功初始化 Ubuntu Server 镜像文件的耗时用于帮助用户评估整体工作等待成本。该耗时从执行 `packer build` 开始计算，到 Packer 完成 Cloud-Init 初始化、SSH provisioner 验证、关机并生成可复用 VM 镜像文件为止。

### 预期耗时

| 阶段 | 预期耗时 | 说明 |
|------|----------|------|
| Packer 配置验证 | < 1 分钟 | `packer validate` 仅检查 HCL、变量和插件配置 |
| ISO 读取与 VM 文件初始化 | 1-3 分钟 | 包括读取本地 ISO、创建 40GB VMDK、生成 VMX、启动 HTTP/VNC |
| Ubuntu 自动安装与 Cloud-Init 初始化 | 8-15 分钟 | 受宿主机 CPU、磁盘 IO、ISO 读取速度和 Ubuntu 安装流程影响最大 |
| SSH provisioner 验证与关机 | 1-3 分钟 | 包括等待 SSH、验证 `/data` 挂载、输出磁盘容量、移除临时密码 SSH 配置并关机 |
| **总计** | **10-20 分钟** | 稳定环境下的成功构建参考值；首次调试或失败重试不计入基准 |

### 记录口径

- 成功耗时以 `packer_debug.log` 中同一次 `build-debug.bat started` 到 `build-debug.bat finished ... exit code 0` 的时间差为准。
- 若构建失败，例如 Cloud-Init 配置错误、VMware DHCP 未保留固定构建 IP、SSH 超时或手动中断，则该次耗时只作为排障数据，不作为成功初始化基准。
- 当前方案通过固定构建 MAC + VMware NAT DHCP 静态保留 + `ssh_host` 降低 SSH 阶段等待失败的概率，使成功耗时更接近 10-20 分钟的稳定区间。

### 首次成功构建基准

| 项目 | 实测值 |
|------|--------|
| 构建日期 | 2026-05-15 |
| 构建命令 | `build-debug.bat` 内执行 `packer validate .` 后执行 `packer build .` |
| Packer build 开始时间 | 2026-05-15 14:18:52 |
| Packer build 完成时间 | 2026-05-15 14:30:40 |
| Packer 报告耗时 | 11 分 48 秒 |
| 构建结果 | 成功，生成 1 个 VMware 镜像产物 |
| 产物目录 | `packer/ubuntu-24-server/output/ubuntu-24-04-server` |
| 产物文件数 | 16 |
| 产物磁盘占用 | 约 5.11 GiB（约 5.48 GB） |

#### 复现环境与关键配置

| 类别 | 配置 |
|------|------|
| 宿主机 OS | Windows 11 |
| 虚拟化平台 | VMware Workstation Pro 25H2；日志识别版本 `25.0.0` |
| Packer 版本 | `1.15.3`（Windows amd64） |
| VMware Packer 插件 | `github.com/hashicorp/vmware`，约束 `~> 1.2.0`，实际使用 `v1.2.0` |
| Guest OS | Ubuntu Server 24.04.4 LTS |
| ISO | `D:/repository/iso/ubuntu-24.04.4-live-server-amd64.iso` |
| ISO checksum | `sha256:e907d92eeec9df64163a7e454cbc8d7755e8ddc7ed42f99dbc80c40f1a138433` |
| Packer VM 资源 | 2 vCPU、4096 MB 内存、40960 MB 虚拟磁盘 |
| 网络 | `VMnet8` NAT，网卡类型 `vmxnet3` |
| 构建 MAC | `00:50:56:24:15:01` |
| 构建 SSH IP | `192.168.40.150`，由 VMware NAT DHCP 静态保留分配 |
| Packer HTTP | 本次使用 `192.168.40.1:8617` 提供 Cloud-Init `user-data` |
| VNC | 本次自动分配 `127.0.0.1:5979`，仅用于调试观察 |

#### 成功验证点

- Packer 成功连接固定构建 IP：`Connected to SSH!`
- SSH provisioner 输出 `SSH connection verified`
- Cloud-Init 完成后系统为 `Ubuntu 24.04.4 LTS`
- `/data` 挂载成功：`/dev/mapper/ubuntu--vg-data--lv` 挂载到 `/data`
- 根分区容量约 20G，`/data` 容量约 19G
- 镜像交付前移除临时密码 SSH 配置并 reload/restart SSH 成功
- 构建收尾完成磁盘 defragment 与 shrink，随后清理 VMX、卸载 ISO、关闭 VNC

#### 耗时解读

本次 11 分 48 秒处在预期 10-20 分钟区间内，可作为当前宿主机和当前配置下的首个稳定基准。后续若耗时显著超过该基准，应优先对比：是否命中本地 ISO、宿主机磁盘 IO 是否繁忙、VMware DHCP 静态保留是否仍生效、是否停留在 SSH 等待阶段、磁盘 defragment/shrink 是否变慢。
