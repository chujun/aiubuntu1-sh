# Packer Variables - Ubuntu 24.04 Server
# 共享变量文件

# ISO 相关配置
variable "iso_url" {
  type        = string
  default     = "D:/repository/iso/ubuntu-24.04.4-live-server-amd64.iso"
  description = "Ubuntu 24.04 Server ISO 本地路径或下载 URL"
}

variable "iso_checksum" {
  type        = string
  default     = "sha256:e907d92eeec9df64163a7e454cbc8d7755e8ddc7ed42f99dbc80c40f1a138433"
  description = "Ubuntu 24.04 Server ISO checksum"
}

# VM 配置
variable "vm_name" {
  type        = string
  default     = "ubuntu-24-04-server"
  description = "虚拟机名称"
}

variable "disk_size" {
  type        = number
  default     = 40960
  description = "磁盘大小 (MB)，默认 40GB；Cloud-Init 将 20GB 分配给 /，剩余空间分配给 /data"
}

variable "cpus" {
  type        = number
  default     = 2
  description = "CPU 核心数"
}

variable "memory" {
  type        = number
  default     = 4096
  description = "内存大小 (MB)"
}

# SSH 配置
variable "ssh_username" {
  type        = string
  default     = "ubuntu"
  description = "SSH 用户名"
}

variable "ssh_password" {
  type        = string
  default     = "ubuntucj"
  sensitive   = true
  description = "SSH 密码"
}

# 网络配置
variable "network_bridge" {
  type        = string
  default     = "VMnet8"
  description = "网络桥接模式 (VMnet0=桥接, VMnet1=HostOnly, NAT=VMnet8)"
}

variable "build_ssh_host" {
  type        = string
  default     = "192.168.40.150"
  description = "Packer 构建期 SSH 地址；需在 VMware NAT DHCP 中为 build_mac_address 配置静态保留"
}

variable "build_mac_address" {
  type        = string
  default     = "00:50:56:24:15:01"
  description = "Packer 构建 VM 的固定 MAC；配合 VMware NAT DHCP 静态保留，避免 SSH 连接到过期 DHCP 租约"
}

# 输出目录
variable "output_directory" {
  type        = string
  default     = "output/ubuntu-24-04-server"
  description = "镜像输出目录"
}

# headless 模式
variable "headless" {
  type        = bool
  default     = true
  description = "是否显示 VM 控制台窗口"
}
