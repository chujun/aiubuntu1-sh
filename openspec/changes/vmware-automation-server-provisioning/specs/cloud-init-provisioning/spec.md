# cloud-init-provisioning

> **部署说明**：Cloud-Init 软件运行在目标 VM 内部（Ubuntu 24 自带），Cloud-Init 配置文件通过 Packer 挂载的 ISO 注入。

## 新增需求

### 需求：Cloud-Init 创建初始用户

系统必须在首次启动时使用 Cloud-Init user-data 配置创建管理员用户账户。

#### 场景：首次启动时创建用户
- **当** 使用 Cloud-Init 配置的 VM 首次启动时
- **则** Cloud-Init 创建 user-data 中指定的用户
- **且** 该用户具有 sudo 权限（admin 组无密码 sudo）

#### 场景：使用 SSH 授权密钥创建用户
- **当** Cloud-Init user-data 包含 SSH 公钥时
- **则** 创建的用户可以使用对应的私钥通过 SSH 认证
- **且** 为安全起见，密码认证被禁用

---

### 需求：Cloud-Init 配置网络

系统必须通过 Cloud-Init 配置 VM 的网络设置，支持 DHCP 和静态 IP 配置。

#### 场景：DHCP 网络配置
- **当** Cloud-Init user-data 指定 DHCP 网络配置时
- **则** VM 通过 DHCP 在主接口上获取 IP 地址
- **且** DNS 服务器根据 DHCP 响应进行配置

#### 场景：静态 IP 网络配置
- **当** Cloud-Init user-data 指定静态 IP 配置时
- **则** VM 使用指定的 IP 地址、子网掩码、网关和 DNS 服务器
- **且** 网络配置在重启后持久化

---

### 需求：Cloud-Init 设置主机名

系统必须基于 Cloud-Init 配置在首次启动时设置 VM 的主机名。

#### 场景：主机名分配
- **当** VM 使用配置了主机名 "vm-ubuntu-server-01" 的 Cloud-Init 启动时
- **则** VM 的主机名设置为 "vm-ubuntu-server-01"
- **且** 主机名在本地网络中正确解析

---

### 需求：Cloud-Init 仅在首次启动时运行

系统必须确保 Cloud-Init 仅在首次启动时运行 user-data 脚本，后续启动不再运行。

#### 场景：首次启动执行 user-data
- **当** 新 VM 首次使用 Cloud-Init 启动时
- **则** Cloud-Init 执行所有 user-data 模块（users、groups、write_files、runcmd）

#### 场景：后续启动跳过 user-data
- **当** 同一 VM 第二次启动时
- **则** Cloud-Init 跳过 user-data 执行
- **且** 启动时间不受 Cloud-Init 处理影响

---

### 需求：Cloud-Init 日志可访问

系统必须提供可访问的 Cloud-Init 日志，以便排查配置问题。

#### 场景：Cloud-Init 日志位置
- **当** Cloud-Init 在 VM 启动期间执行时
- **则** 日志写入 `/var/log/cloud-init.log`
- **且** user-data 脚本的输出写入 `/var/log/cloud-init-output.log`

#### 场景：Cloud-Init status 命令
- **当** 在运行的 VM 上执行 `cloud-init status` 时
- **则** 返回当前 Cloud-Init 执行状态（running、done、error）
