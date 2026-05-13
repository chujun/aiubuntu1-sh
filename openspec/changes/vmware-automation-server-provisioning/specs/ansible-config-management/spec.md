# ansible-config-management

> **部署说明**：Ansible 运行在独立的 Linux 控制节点 VM（Ubuntu Server）上，通过 SSH 连接到目标 VM 进行配置管理。

## 新增需求

### 需求：Ansible 通过 SSH 连接到目标 VM

系统必须从 Ansible 控制节点建立到目标 VM 的 SSH 连接以进行配置管理。

#### 场景：Ansible ping 测试成功
- **当** 执行 `ansible -i inventory/hosts.yml all -m ping` 时
- **则** Ansible 通过 SSH 连接到所有目标 VM
- **且** 对每个可达的 VM 返回 SUCCESS

#### 场景：Ansible 连接失败处理
- **当** Ansible 尝试连接到不可达的 VM 时
- **则** Ansible 报告该主机为 UNREACHABLE 状态
- **且** 继续对其他主机执行而不整体失败

---

### 需求：Ansible 配置 SSH 服务

系统必须配置 SSH 守护进程设置，包括禁用密码认证和配置授权密钥。

#### 场景：SSH 加固已应用
- **当** 执行 `ansible-playbook -i inventory/hosts.yml playbooks/base.yml --tags ssh` 时
- **则** SSH 密码认证被禁用
- **且** root 登录被禁用
- **且** 为 ansible 用户配置了 SSH authorized_keys

---

### 需求：Ansible 配置 NTP 服务

系统必须在目标 VM 上配置 NTP 时间同步。

#### 场景：NTP 服务已启用并运行
- **当** 执行 `ansible-playbook -i inventory/hosts.yml playbooks/base.yml --tags ntp` 时
- **则** NTP 服务已安装
- **且** NTP 服务已启用并运行
- **且** 与指定的 NTP 服务器的时间同步处于活动状态

---

### 需求：Ansible 配置防火墙

系统必须在目标 VM 上配置防火墙规则，仅开放必需的端口。

#### 场景：防火墙允许 SSH 和定义的服务
- **当** 执行 `ansible-playbook -i inventory/hosts.yml playbooks/base.yml --tags firewall` 时
- **则** SSH（端口 22）被允许
- **且** 仅开放额外指定端口
- **且** 对入站连接应用默认拒绝策略

---

### 需求：Ansible 安装 Docker 运行时

系统必须在目标 VM 上安装和配置 Docker 运行时环境。

#### 场景：Docker 安装
- **当** 执行 `ansible-playbook -i inventory/hosts.yml playbooks/runtime.yml --tags docker` 时
- **则** Docker 引擎已安装
- **且** Docker 服务已启用并运行
- **且** 当前用户被添加到 docker 组

#### 场景：Docker 守护进程配置
- **当** 通过 Ansible 安装 Docker 时
- **则** Docker 守护进程使用指定的镜像仓库镜像（如果有）进行配置
- **且** Docker socket 权限允许 docker 组用户访问

---

### 需求：Ansible 安装 Java 运行时

系统必须在指定为 Java 开发机的目标 VM 上安装 Java 开发工具包。

#### 场景：Java 安装
- **当** 执行 `ansible-playbook -i inventory/hosts.yml playbooks/runtime.yml --tags java` 时
- **则** 安装 OpenJDK 或 Oracle JDK（版本在 inventory 中指定）
- **且** JAVA_HOME 环境变量已设置
- **且** `java -version` 执行成功

---

### 需求：Ansible 安装 Node.js 运行时

系统必须在指定用于 JavaScript/Node 开发的目标 VM 上安装 Node.js 运行时。

#### 场景：Node.js 安装
- **当** 执行 `ansible-playbook -i inventory/hosts.yml playbooks/runtime.yml --tags node` 时
- **则** Node.js 已安装（版本在 inventory 中指定）
- **且** npm 已安装且可用
- **且** `node -v` 和 `npm -v` 执行成功

---

### 需求：Ansible inventory 定义目标 VM

系统必须使用结构化 inventory 文件（YAML 格式）定义所有目标 VM 及其分组。

#### 场景：Inventory 结构
- **当** 执行 `ansible-inventory -i inventory/hosts.yml --list` 时
- **则** 所有定义的主机及其变量都被列出
- **且** 主机组正确组织（dev-machines、ai-machines 等）
- **且** 主机组变量可被该组中的主机访问

#### 场景：Inventory 验证
- **当** 执行 `ansible-inventory -i inventory/hosts.yml --graph` 时
- **则** 主机和组的层次结构被正确显示
