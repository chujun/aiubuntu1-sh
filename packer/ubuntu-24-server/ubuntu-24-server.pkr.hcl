# Ubuntu 24.04 Server Packer 构建配置
# 使用 Cloud-Init 进行无人值守安装

packer {
  required_plugins {
    vmware = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/vmware"
    }
  }
}

source "vmware-iso" "ubuntu-24-server" {
  # 基本配置
  vm_name       = var.vm_name
  guest_os_type = "ubuntu-64"
  headless      = var.headless

  # ISO 配置
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # HTTP 目录 - Cloud-Init 配置文件通过这个目录提供
  http_directory = "./http"

  # 启动等待时间 - 20秒，让 GRUB 有足够时间显示
  boot_wait = "20s"

  # boot_command - 使用更简单的按键序列
  boot_command = [
    # 按 e 进入 GRUB 编辑模式
    "e<wait><wait><wait><wait>",
    # 按 End 跳到行末
    "<end><wait><wait><wait>",
    # 添加 autoinstall 参数
    " autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    # 按 Ctrl+X 启动
    "<ctrl-x>"
  ]

  # 磁盘配置
  disk_size = var.disk_size

  # 虚拟机内存和 CPU
  cpus   = var.cpus
  memory = var.memory

  # 网络配置
  network_adapter_type      = "e1000e"
  network                  = var.network_bridge

  # SSH 配置
  ssh_username         = var.ssh_username
  ssh_password         = var.ssh_password
  ssh_port             = 22
  ssh_timeout          = "30m"
  ssh_handshake_attempts = 100

  # 关机命令 - 优雅关机
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
  shutdown_timeout = "15m"

  # VMX 额外配置 - 添加启动延迟让 BIOS 有更多初始化时间
  vmx_data = {
    "bios.bootOrder"              = "cd"
    "firmware"                    = "efi"
    "uefi.secureBoot.enabled"     = "FALSE"
    "guestinfo.local-hostname"    = "ubuntu-server"
    "bios.bootDelay"              = "5000"
  }

  # 输出目录
  output_directory = var.output_directory

  # VMware Tools 上传
  tools_upload_flavor = "linux"
  tools_mode = "upload"
}

build {
  name = "ubuntu-24-server"

  sources = ["source.vmware-iso.ubuntu-24-server"]

  # 等待 Cloud-Init 完成
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
      "cloud-init status --wait"
    ]
  }

  # 验证 SSH 连接
  provisioner "shell" {
    inline = [
      "echo 'SSH connection verified'",
      "hostname",
      "cat /etc/os-release | head -3"
    ]
  }
}
