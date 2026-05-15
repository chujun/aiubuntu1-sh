# vm-image-build

> **部署说明**：Packer 运行在 Windows 11 宿主机上（Windows 原生安装），Cloud-Init 运行在目标 VM 内部（Ubuntu 24 自带）。

## 新增需求

### 需求：Packer 验证 VM 镜像配置

系统必须在构建前验证 Packer 配置文件（.pkr.hcl），以捕获语法和配置错误。

#### 场景：有效配置通过验证
- **当** 执行 `packer validate` 时使用有效的 .pkr.hcl 文件
- **则** Packer 返回退出码 0 并输出 "Template validated successfully"

#### 场景：无效配置验证失败
- **当** 执行 `packer validate` 时使用无效的 .pkr.hcl 文件
- **则** Packer 返回非零退出码并输出具体的验证错误信息

---

### 需求：Packer 构建 Ubuntu Server 基础镜像

系统必须使用 Packer 和 VMware Workstation Pro builder 构建最小化 Ubuntu 24.04 Server 基础镜像。

#### 场景：成功构建镜像
- **当** 执行 `packer build ubuntu-24-server.pkr.hcl` 时
- **则** Packer 创建一个安装了 Ubuntu 24.04 Server 的 VM
- **且** VM 配置了最小化软件包（OpenSSH Server、Cloud-Init）
- **且** VM 使用 `vmxnet3` 网络适配器
- **且** VMX 配置包含 `disk.EnableUUID = "TRUE"`
- **且** VMX 配置包含构建专用固定 MAC，用于 VMware NAT DHCP 静态保留
- **且** 生成的 .vmx 和 .vmdk 文件放置在配置的输出目录中

#### 场景：构建期 SSH 使用固定 DHCP 保留地址
- **当** Packer 完成 Ubuntu 安装并等待 SSH 连接时
- **则** Packer 使用配置的 `ssh_host` 连接 VMware NAT DHCP 为构建 MAC 保留的固定 IP
- **且** Cloud-Init 不向最终镜像写入该固定 IP
- **且** 若 VMware DHCP 未为该 MAC 保留对应 IP，构建操作应视为环境配置错误并在 SSH 等待阶段失败

#### 场景：构建后验证磁盘挂载
- **当** Packer 完成 Cloud-Init 初始化并通过 SSH 连接到 VM 时
- **则** 构建流程执行 `findmnt /data`
- **且** 构建流程执行 `df -h / /data`
- **且** 若 `/data` 未挂载或根分区/数据分区不可访问，构建失败

#### 场景：镜像交付前移除临时密码 SSH 配置
- **当** Packer 完成 SSH 连接验证后
- **则** 构建流程移除 `/etc/ssh/sshd_config.d/99-packer.conf`
- **且** 构建流程 reload 或 restart SSH 服务

#### 场景：ISO 挂载错误导致构建失败
- **当** 执行 `packer build` 但 Ubuntu ISO 不可访问时
- **则** Packer 失败并输出指示 ISO 文件未找到的错误
- **且** 输出目录中不留下部分 VM 文件

---

### 需求：Packer 构建 Ubuntu Desktop 基础镜像

系统必须使用 Packer 和 VMware Workstation Pro builder 构建最小化 Ubuntu 24.04 Desktop 基础镜像。

#### 场景：成功构建 Desktop 镜像
- **当** 执行 `packer build ubuntu-24-desktop.pkr.hcl` 时
- **则** Packer 创建一个安装了 Ubuntu 24.04 Desktop 的 VM
- **且** VM 配置了最小化软件包（OpenSSH Server、Cloud-Init、桌面工具）
- **且** 生成的 .vmx 和 .vmdk 文件放置在配置的输出目录中

---

### 需求：镜像构建使用 Cloud-Init 进行 OS 配置

系统必须在 Packer 构建期间使用 Cloud-Init 配置客户机 OS，避免交互式提示。

#### 场景：Cloud-Init 无提示配置 VM
- **当** Packer 使用 Cloud-Init 配置构建镜像时
- **则** VM 启动时无需显示语言/键盘/用户名提示
- **且** Cloud-Init 自动应用 user-data 配置

---

### 需求：镜像构建输出带版本号

系统必须生成带版本号的镜像产物，具有可预测的命名以便自动化集成。

#### 场景：镜像命名遵循约定
- **当** Packer 完成 ubuntu-24-server 的构建时
- **则** 输出文件遵循模式 `ubuntu-24-server-{timestamp}.vmx`
- **且** 元数据文件包含构建时间戳和使用的 Packer 版本
