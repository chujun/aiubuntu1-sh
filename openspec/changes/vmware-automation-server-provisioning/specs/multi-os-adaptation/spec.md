# multi-os-adaptation

> **部署说明**：多 OS 适配由 Ansible Role 实现，运行在控制节点 Linux VM 上，通过 SSH 连接到目标 VM 执行差异化配置。

## 新增需求

### 需求：Ansible Role 检测 OS 发行版

系统必须使用 Ansible facts 检测目标 VM 的 Linux 发行版和版本。

#### 场景：Ubuntu 检测
- **当** Ansible 从 Ubuntu 24.04 目标收集 facts 时
- **则** `ansible_facts['distribution']` 等于 "Ubuntu"
- **且** `ansible_facts['distribution_major_version']` 等于 "24"
- **且** `ansible_facts['os_family']` 等于 "Debian"

#### 场景：Debian 检测
- **当** Ansible 从 Debian 12 目标收集 facts 时
- **则** `ansible_facts['distribution']` 等于 "Debian"
- **且** `ansible_facts['distribution_major_version']` 等于 "12"
- **且** `ansible_facts['os_family']` 等于 "Debian"

#### 场景：CentOS 检测
- **当** Ansible 从 CentOS 9 目标收集 facts 时
- **则** `ansible_facts['distribution']` 等于 "CentOS"
- **且** `ansible_facts['distribution_major_version']` 等于 "9"
- **且** `ansible_facts['os_family']` 等于 "RedHat"

---

### 需求：Ansible Role 加载 OS 特定任务

系统必须基于检测到的发行版加载 OS 特定的任务文件，避免在整个 role 逻辑中使用条件任务。

#### 场景：Debian 系列 OS 使用 debian.yml 任务
- **当** Ansible 在 Ubuntu 目标上执行 Role 时
- **则** Role 包含来自 `tasks/debian.yml` 的任务
- **且** `tasks/main.yml` 中的任务使用 `when: ansible_facts['os_family'] == 'Debian'` 条件

#### 场景：RedHat 系列 OS 使用 redhat.yml 任务
- **当** Ansible 在 CentOS 目标上执行 Role 时
- **则** Role 包含来自 `tasks/redhat.yml` 的任务
- **且** `tasks/main.yml` 中的任务使用 `when: ansible_facts['os_family'] == 'RedHat'` 条件

---

### 需求：Ansible Role 使用 OS 特定变量

系统必须从单独的变量文件（vars/debian.yml、vars/redhat.yml）加载 OS 特定变量。

#### 场景：包名因 OS 而异
- **当** Role 需要安装 openssh-server 时
- **则** 在 Debian/Ubuntu 上安装 "openssh-server"
- **且** 在 RedHat/CentOS 上安装 "openssh-server"（此情况下包名相同）
- **且** 变量文件允许按 OS 覆盖包名

#### 场景：服务名因 OS 而异
- **当** Role 需要管理 SSH 服务时
- **则** 在 Debian/Ubuntu 上使用服务名 "ssh"
- **且** 在 RedHat/CentOS 上使用服务名 "sshd"
- **且** 正确的服务名从 OS 特定的变量文件加载

---

### 需求：Ansible Role 处理防火墙差异

系统必须处理 Debian（ufw）和 RedHat（firewalld）系统之间的防火墙配置差异。

#### 场景：Debian 防火墙配置
- **当** 防火墙 Role 在 Ubuntu 上执行时
- **则** 它使用 ufw（Uncomplicated Firewall）命令
- **且** 通过 `ufw allow` 命令配置规则

#### 场景：RedHat 防火墙配置
- **当** 防火墙 Role 在 CentOS 上执行时
- **则** 它使用 firewalld 命令
- **且** 通过 `firewall-cmd --permanent --add-port` 命令配置规则

---

### 需求：Ansible Role 处理包管理器差异

系统必须根据检测到的 OS 使用正确的包管理器（apt/dnf/yum）。

#### 场景：Debian/Ubuntu 使用 apt
- **当** Ansible 在 Ubuntu 上安装包时
- **则** 它使用 `ansible.builtin.apt` 模块
- **且** 安装前更新包缓存

#### 场景：RedHat/CentOS 使用 dnf
- **当** Ansible 在 CentOS 上安装包时
- **则** 它使用 `ansible.builtin.dnf` 模块
- **且** 安装前更新包缓存

---

### 需求：多 OS 支持已文档化

系统必须记录支持哪些 OS 版本以及如何添加对新发行版的支持。

#### 场景：支持的 OS 文档
- **当** 新团队成员查看 Ansible Role 文档时
- **则** 他们可以找到当前支持的 OS 发行版列表
- **且** 他们可以找到添加新 OS 发行版支持的说明
- **且** 示例显示在哪里添加新的 OS 特定任务和变量文件
