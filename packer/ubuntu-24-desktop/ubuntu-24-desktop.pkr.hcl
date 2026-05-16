# Ubuntu 24.04 Desktop Packer 构建配置
# 使用 Cloud-Init autoinstall 进行无人值守安装

packer {
  required_plugins {
    vmware = {
      # 固定到已验证的 1.2.x 系列，避免未来插件不兼容变更破坏构建。
      version = "~> 1.2.0"
      source  = "github.com/hashicorp/vmware"
    }
  }
}

source "vmware-iso" "ubuntu-24-desktop" {
  # 基本配置
  vm_name       = var.vm_name
  guest_os_type = "ubuntu-64"
  headless      = var.headless

  # ISO 配置
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # HTTP 目录 - Cloud-Init 配置文件通过这个目录提供
  http_directory = "./http"

  # 启动等待时间 - 等待 GRUB 菜单出现
  boot_wait = "10s"

  # boot_command - 与 Server 版保持一致，将 autoinstall NoCloud 参数追加到 /casper/vmlinuz 行。
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
  ssh_host     = var.build_ssh_host
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_port     = 22
  ssh_timeout  = "45m"
  # 成功基线允许安装器/live 环境阶段出现短暂认证失败，Packer 会继续重试直到最终系统 SSH 可用。
  ssh_handshake_attempts = 120

  # 关机命令 - 优雅关机
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
  shutdown_timeout = "15m"

  # VMX 额外配置
  vmx_data = {
    "bios.bootOrder"           = "cd"
    "firmware"                 = "efi"
    "uefi.secureBoot.enabled"  = "FALSE"
    "guestinfo.local-hostname" = "ubuntu-desktop"
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
  name = "ubuntu-24-desktop"

  sources = ["source.vmware-iso.ubuntu-24-desktop"]

  # 等待 Cloud-Init 完成
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
      "cloud-init status --wait"
    ]
  }

  # 验证 SSH、桌面组件和磁盘挂载，并清理模板身份。
  # Packer 构建期使用密码 SSH；镜像交付前移除临时 sshd 配置，避免克隆机默认允许密码登录。
  # 同时删除 SSH host keys 和 machine-id，让复制出的每台 VMware VM 首次启动时生成唯一身份。
  provisioner "shell" {
    inline = [
      "echo 'SSH connection verified'",
      "hostname",
      "cat /etc/os-release | head -3",
      "dpkg-query -W ubuntu-desktop-minimal open-vm-tools-desktop",
      "systemctl is-enabled gdm3 || true",
      "findmnt /data",
      "df -h / /data",
      "echo '${var.ssh_password}' | sudo -S -p '' rm -f /etc/ssh/sshd_config.d/99-packer.conf",
      "echo '${var.ssh_password}' | sudo -S -p '' systemctl reload ssh || echo '${var.ssh_password}' | sudo -S -p '' systemctl restart ssh",
      "echo '${var.ssh_password}' | sudo -S -p '' bash -c \"printf '%s\\n' '[Unit]' 'Description=Regenerate SSH host keys for cloned VM' 'ConditionPathExists=!/etc/ssh/ssh_host_ed25519_key' 'Before=ssh.service' '' '[Service]' 'Type=oneshot' 'ExecStart=/usr/bin/ssh-keygen -A' '' '[Install]' 'WantedBy=multi-user.target' > /etc/systemd/system/regenerate-ssh-host-keys.service\"",
      "echo '${var.ssh_password}' | sudo -S -p '' systemctl enable regenerate-ssh-host-keys.service",
      "echo '${var.ssh_password}' | sudo -S -p '' rm -f /etc/ssh/ssh_host_*",
      "echo '${var.ssh_password}' | sudo -S -p '' truncate -s 0 /etc/machine-id",
      "echo '${var.ssh_password}' | sudo -S -p '' rm -f /var/lib/dbus/machine-id",
      "echo '${var.ssh_password}' | sudo -S -p '' cloud-init clean --logs --seed"
    ]
  }
}
