# Packer Variables - Ubuntu 24.04 Server
# 共享变量文件

# ISO 相关配置
variable "iso_url" {
  type    = string
  default = "https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso"
  description = "Ubuntu 24.04 Server ISO 下载地址"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:8c60f1b8ca06c04ac564f0409952684ee9aca8c7a56d6c6c8c3b02b6974f8a3b"
  description = "Ubuntu 24.04 Server ISO checksum"
}

# VM 配置
variable "vm_name" {
  type    = string
  default = "ubuntu-24-04-server"
  description = "虚拟机名称"
}

variable "disk_size" {
  type    = number
  default = 40960
  description = "磁盘大小 (MB)，默认 40GB"
}

variable "cpus" {
  type    = number
  default = 2
  description = "CPU 核心数"
}

variable "memory" {
  type    = number
  default = 4096
  description = "内存大小 (MB)"
}

# SSH 配置
variable "ssh_username" {
  type    = string
  default = "ubuntu"
  description = "SSH 用户名"
}

variable "ssh_password" {
  type      = string
  default   = "ubuntu"
  sensitive = true
  description = "SSH 密码"
}

# 网络配置
variable "network_bridge" {
  type    = string
  default = "VMnet8"
  description = "网络桥接模式 (VMnet0=桥接, VMnet1=HostOnly, NAT=VMnet8)"
}

# 输出目录
variable "output_directory" {
  type    = string
  default = "output/${var.vm_name}"
  description = "镜像输出目录"
}

# headless 模式
variable "headless" {
  type    = bool
  default = false
  description = "是否显示 VM 控制台窗口"
}
