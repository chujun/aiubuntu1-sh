#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
为 Packer 构建 Ubuntu 24 Desktop 写入 VMware NAT DHCP 静态保留。

用途：
  让固定 MAC 00:50:56:24:15:02 每次都拿到 192.168.40.151，
  避免 Packer SSH 连接固定地址时，VMware DHCP 实际分配其他 IP。

安全措施：
  1. 修改前自动备份 C:\\ProgramData\\VMware\\vmnetdhcp.conf。
  2. 重复执行时会先删除旧的 Desktop reservation block，再写入新配置。
  3. 写入后重启 VMnetDHCP 服务，让 DHCP 静态保留生效。

使用方式：
  以管理员身份运行：
    python configure_vmware_dhcp_reservation.py

  仅预览将要写入的内容，不修改系统配置：
    python configure_vmware_dhcp_reservation.py --dry-run
"""

from __future__ import annotations

import argparse
import ctypes
import re
import shutil
import subprocess
from datetime import datetime
from pathlib import Path


DHCP_CONF = Path(r"C:\ProgramData\VMware\vmnetdhcp.conf")
BUILD_IP = "192.168.40.151"
BUILD_MAC = "00:50:56:24:15:02"
SERVICE_NAME = "VMnetDHCP"
BEGIN_MARKER = "# BEGIN PACKER UBUNTU 24 DESKTOP DHCP RESERVATION"
END_MARKER = "# END PACKER UBUNTU 24 DESKTOP DHCP RESERVATION"


def is_admin() -> bool:
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def reservation_block(ip: str, mac: str) -> str:
    return "\n".join(
        [
            BEGIN_MARKER,
            "host packer-ubuntu-24-desktop {",
            f"  hardware ethernet {mac};",
            f"  fixed-address {ip};",
            "}",
            END_MARKER,
            "",
        ]
    )


def update_config_text(text: str, ip: str, mac: str) -> str:
    pattern = rf"(?ms){re.escape(BEGIN_MARKER)}.*?{re.escape(END_MARKER)}\s*"
    text = re.sub(pattern, "", text).rstrip()
    return f"{text}\n\n{reservation_block(ip, mac)}"


def restart_vmware_dhcp_service() -> None:
    subprocess.run(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            f"Restart-Service -Name '{SERVICE_NAME}' -Force",
        ],
        check=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="写入 VMware NAT DHCP 静态保留，供 Packer 构建 Ubuntu Desktop 镜像使用。"
    )
    parser.add_argument("--ip", default=BUILD_IP, help=f"固定构建 IP，默认 {BUILD_IP}")
    parser.add_argument("--mac", default=BUILD_MAC, help=f"固定构建 MAC，默认 {BUILD_MAC}")
    parser.add_argument("--dry-run", action="store_true", help="仅预览，不写入文件、不重启服务")
    args = parser.parse_args()

    block = reservation_block(args.ip, args.mac)
    print(f"[vmware-dhcp] Config file: {DHCP_CONF}")
    print(f"[vmware-dhcp] Reservation: {args.mac} -> {args.ip}")

    if args.dry_run:
        print("[vmware-dhcp] Dry run. The following block would be written:")
        print(block)
        return 0

    if not is_admin():
        print("[vmware-dhcp] Please run this script as Administrator.")
        return 1

    if not DHCP_CONF.exists():
        print(f"[vmware-dhcp] Config file not found: {DHCP_CONF}")
        return 1

    backup = DHCP_CONF.with_name(
        f"{DHCP_CONF.name}.bak-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    )
    shutil.copy2(DHCP_CONF, backup)
    print(f"[vmware-dhcp] Backup created: {backup}")

    text = DHCP_CONF.read_text(encoding="ascii", errors="ignore")
    DHCP_CONF.write_text(update_config_text(text, args.ip, args.mac), encoding="ascii")
    print("[vmware-dhcp] Reservation written.")

    restart_vmware_dhcp_service()
    print("[vmware-dhcp] VMnetDHCP restarted.")
    print("[vmware-dhcp] Next: run cleanup-build.bat, then build-debug.bat.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
