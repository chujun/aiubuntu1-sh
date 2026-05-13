# 自定义变量文件 - 用户可复制此文件并修改

# ISO 相关配置
iso_url      = "https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso"
iso_checksum = "sha256:8c60f1b8ca06c04ac564f0409952684ee9aca8c7a56d6c6c8c3b02b6974f8a3b"

# VM 配置
vm_name  = "ubuntu-24-04-server"
disk_size = 40960
cpus     = 2
memory   = 4096

# SSH 配置 - 请修改为你的密码
ssh_username = "ubuntu"
ssh_password = "ubuntu"  # 修改为你的密码

# 网络配置 - VMnet0=桥接, VMnet8=NAT
network_bridge = "VMnet8"

# headless 模式 - true=不显示控制台
headless = false
