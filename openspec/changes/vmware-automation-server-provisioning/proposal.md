# Proposal: VMware 自动化批量服务器搭建系统

## Why

当前 VMware Workstation Pro 环境下的虚拟机服务器搭建依赖手动操作，存在以下问题：(1) 手动创建 VM 每次耗时 15-30 分钟，无法规模化；(2) 软件版本难以统一管理，无法审计跟踪；(3) 多 OS 支持缺乏统一框架，扩展成本高。本方案旨在建立一套基于 Packer + Cloud-Init + Ansible 的自动化批量服务器搭建系统，满足当前学习用途需求，同时为未来商业化扩展预留架构空间。

## What Changes

1. **新增 Packer 镜像构建流程**：使用 Packer + Cloud-Init 自动构建基础 OS 镜像（Ubuntu 24 Server/Desktop），替代纯手动 VM 创建
2. **新增 Ansible 配置管理体系**：基于 Role 分层组织（common/runtime/workload）的配置管理框架，支持 SSH、NTP、防火墙、Docker、Java、Node、AI 应用等软件栈
3. **新增 Cloud-Init 无人值守初始化**：通过 Cloud-Init 自动完成 OS 用户创建、SSH 公钥配置、主机名/网络设置
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
