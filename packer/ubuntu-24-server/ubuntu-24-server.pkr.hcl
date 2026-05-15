# Ubuntu 24.04 Server Packer 构建配置
# 使用 Cloud-Init 进行无人值守安装

packer {
  required_plugins {
    vmware = {
      # 固定到已验证的 1.2.x 系列，避免未来插件不兼容变更破坏构建。
      version = "~> 1.2.0"
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

  # 启动等待时间 - 10秒，等待 GRUB 菜单出现
  boot_wait = "10s"

  # boot_command - 基于 Canonical 官方 packer-maas 配置
  # 参考: https://github.com/canonical/packer-maas/blob/main/ubuntu/ubuntu-flat.pkr.hcl
  boot_command = [
    "<wait>e<wait5>",
    "<down><wait><down><wait><down><wait2><end><wait5>",
    "<bs><bs><bs><bs><wait> autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait><f10>"
  ]

  # 磁盘配置
  disk_size = var.disk_size

  # 虚拟机内存和 CPU
  cpus   = var.cpus
  memory = var.memory

  # 网络配置
  # Ubuntu 24 自带 vmxnet3 驱动，性能和虚拟化集成优于 e1000e。
  network_adapter_type = "vmxnet3"
  network              = var.network_bridge

  # SSH 配置
  # 构建期使用 VMware NAT DHCP 的 MAC 静态保留地址，避免 Packer 从旧 DHCP lease 中探测到错误 IP。
  # 注意：该固定 IP 仅用于 Packer SSH，不写入最终 Ubuntu 镜像，避免克隆后发生 IP 冲突。
  ssh_host               = var.build_ssh_host
  ssh_username           = var.ssh_username
  ssh_password           = var.ssh_password
  ssh_port               = 22
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 100

  # 关机命令 - 优雅关机
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
  shutdown_timeout = "15m"

  # VMX 额外配置
  vmx_data = {
    "bios.bootOrder"           = "cd"
    "firmware"                 = "efi"
    "uefi.secureBoot.enabled"  = "FALSE"
    "guestinfo.local-hostname" = "ubuntu-server"
    # 暴露稳定磁盘 UUID，便于后续 Linux/Ansible 自动化识别磁盘。
    "disk.EnableUUID" = "TRUE"
    # 固定构建 VM 的 MAC，用于 VMware NAT DHCP 静态保留，保证 Packer SSH 命中正确客户机。
    "ethernet0.addressType" = "static"
    "ethernet0.address"     = var.build_mac_address
  }

  # 输出目录
  output_directory = var.output_directory

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
  # Packer 构建期使用密码 SSH；镜像交付前移除临时 sshd 配置，避免克隆机默认允许密码登录。
  provisioner "shell" {
    inline = [
      "echo 'SSH connection verified'",
      "hostname",
      "cat /etc/os-release | head -3",
      "findmnt /data",
      "df -h / /data",
      "echo '${var.ssh_password}' | sudo -S -p '' rm -f /etc/ssh/sshd_config.d/99-packer.conf",
      "echo '${var.ssh_password}' | sudo -S -p '' systemctl reload ssh || echo '${var.ssh_password}' | sudo -S -p '' systemctl restart ssh"
    ]
  }
}
