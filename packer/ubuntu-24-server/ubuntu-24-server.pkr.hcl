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

  # 启动等待时间 - 确保 VM 完全启动到 GRUB 菜单
  boot_wait = "30s"

  # boot_command - Ubuntu 24.04 使用 Subiquity 安装程序
  # Ubuntu 24.04 Server ISO 启动后显示 GRUB 菜单
  # 流程: GRUB菜单 -> 按e编辑 -> 修改linux行添加autoinstall -> 按F10启动
  boot_command = [
    # 等待 GRUB 菜单，按 e 进入编辑模式
    "<esc><wait><wait><wait>e<wait><wait><wait>",
    # 在 linux 行末尾添加参数
    # 先按 End 键跳到行末
    "<end><wait><wait>",
    # 添加空格和 autoinstall 参数
    " autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    # 等待一下然后按 F10 启动 (也支持 Ctrl+X)
    "<wait><wait><f10>"
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

  # VMX 额外配置
  vmx_data = {
    "bios.bootOrder"             = "cd"
    "firmware"                   = "efi"
    "uefi.secureBoot.enabled"    = "FALSE"
    "guestinfo.local-hostname"    = "ubuntu-server"
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
