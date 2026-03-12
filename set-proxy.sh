#!/bin/bash

# ============================================================================
# Proxy自动配置脚本
# ============================================================================
# 功能：动态设置http_proxy和https_proxy为宿主机VPN代理端口
# 
# 原理说明：
#   1. 在VMware NAT模式下，虚拟机通过宿主机上网
#   2. 宿主机运行VPN代理，监听10810端口（默认）
#   3. 虚拟机需要将http_proxy设置为宿主机IP:端口才能科学上网
#   4. 由于宿主机IP（WiFi地址）可能变化，需要动态检测
#
# 自动检测宿主机IP的逻辑：
#   1. 首先尝试默认网关（NAT模式的192.168.40.2）
#   2. 如果默认网关不可达，扫描常见VMware网段
#   3. 通过TCP连接测试代理端口（10810）确认宿主机
#   4. 扫描网段：10.1.32.x, 10.1.x, 192.168.40.x 等
#
# 使用示例：
#   ./set-proxy.sh -s              # 自动检测宿主机IP设置代理
#   ./set-proxy.sh -i 10.1.32.61 -s  # 手动指定宿主机IP
#   ./set-proxy.sh -e              # 持久化配置（开机自动加载）
#   ./set-proxy.sh -u              # 取消代理
#   ./set-proxy.sh -t              # 测试代理连通性
#
# 环境变量：
#   HOST_IP           - 指定宿主机IP（优先级最高）
#   VPN_PROXY_PORT    - 代理端口（默认10810）
#   PROXY_PROTOCOL    - 代理协议http/socks5（默认http）
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VPN_PROXY_PORT=${VPN_PROXY_PORT:-10810}
PROXY_PROTOCOL=${PROXY_PROTOCOL:-http}

show_usage() {
    echo -e "${BLUE}用法: $0 [选项]${NC}"
    echo ""
    echo "选项:"
    echo "  -s, --set [端口]      设置代理 (默认端口: $VPN_PROXY_PORT)"
    echo "  -i, --ip <IP>        指定宿主机IP"
    echo "  -u, --unset          取消代理"
    echo "  --show               显示当前代理设置"
    echo "  -t, --test           测试代理连通性"
    echo "  -e, --enable         持久化代理设置"
    echo "  -h, --help           显示帮助信息"
    echo ""
    echo "环境变量:"
    echo "  VPN_PROXY_PORT        VPN代理端口 (默认: 10810)"
    echo "  HOST_IP              宿主机IP (自动检测)"
    echo "  PROXY_PROTOCOL       代理协议 http/socks5 (默认: http)"
    echo ""
    echo "示例:"
    echo "  $0 -s                # 自动检测宿主机IP"
    echo "  $0 -i 10.1.32.61 -s # 指定宿主机IP"
    echo "  HOST_IP=10.1.32.61 $0 -s"
    echo "  $0 -u                # 取消代理"
}

get_host_ip() {
    local _host_ip
    
    if [ -n "$HOST_IP" ]; then
        echo "$HOST_IP"
        return
    fi
    
    _host_ip=$(ip route show default 2>/dev/null | awk '/default/ {print $3}')
    
    if timeout 1 bash -c "echo >/dev/tcp/${_host_ip}/${VPN_PROXY_PORT}" 2>/dev/null; then
        echo "$_host_ip"
        return
    fi
    
    echo -e "${YELLOW}[INFO]${NC} 默认网关 $_host_ip 不可达，尝试自动检测宿主机IP..."
    
    local vmnet_subnets=(
        "10.1.32" "10.1.0" "10.0.0"
        "192.168.40" "192.168.80" "192.168.50" 
        "192.168.126" "192.168.174" "192.168.1"
    )
    
    for subnet in "${vmnet_subnets[@]}"; do
        for i in {1..254}; do
            local test_ip="${subnet}.$i"
            if timeout 0.3 bash -c "echo >/dev/tcp/${test_ip}/${VPN_PROXY_PORT}" 2>/dev/null; then
                echo -e "${GREEN}[INFO]${NC} 自动检测到宿主机IP: $test_ip"
                echo "$test_ip"
                return
            fi
        done
    done
    
    echo -e "${RED}[ERROR]${NC} 无法自动检测宿主机IP，请手动指定: -i <IP>"
    return 1
}

set_proxy() {
    local host_ip
    host_ip=$(get_host_ip 2>&1 | tail -1)
    
    if [ -z "$host_ip" ]; then
        return 1
    fi
    
    local proxy_addr="${PROXY_PROTOCOL}://${host_ip}:${VPN_PROXY_PORT}"
    
    export http_proxy="$proxy_addr"
    export https_proxy="$proxy_addr"
    export HTTP_PROXY="$proxy_addr"
    export HTTPS_PROXY="$proxy_addr"
    
    echo -e "${GREEN}[INFO]${NC} 代理已设置: http_proxy=$http_proxy"
    echo -e "${GREEN}[INFO]${NC} 代理已设置: https_proxy=$https_proxy"
    
    echo "http_proxy=$http_proxy" > ~/.proxy_env
    echo "https_proxy=$https_proxy" >> ~/.proxy_env
    
    echo -e "${GREEN}[INFO]${NC} 代理配置已保存到 ~/.proxy_env"
}

unset_proxy() {
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
    
    echo -e "${GREEN}[INFO]${NC} 代理已取消"
    
    rm -f ~/.proxy_env 2>/dev/null
}

show_proxy() {
    echo -e "${BLUE}当前代理设置:${NC}"
    echo "------------------------"
    echo -e "http_proxy:  ${YELLOW}${http_proxy:-未设置}${NC}"
    echo -e "https_proxy: ${YELLOW}${https_proxy:-未设置}${NC}"
    echo -e "HTTP_PROXY:  ${YELLOW}${HTTP_PROXY:-未设置}${NC}"
    echo -e "HTTPS_PROXY: ${YELLOW}${HTTPS_PROXY:-未设置}${NC}"
    echo "------------------------"
    
    if [ -f ~/.proxy_env ]; then
        echo -e "(已保存配置: ~/.proxy_env)"
    fi
}

test_proxy() {
    if [ -z "$http_proxy" ]; then
        echo -e "${RED}[ERROR]${NC} 代理未设置，请先运行 $0 -s"
        return 1
    fi
    
    echo -e "${BLUE}测试代理连通性...${NC}"
    
    if curl -s --max-time 5 -x "$http_proxy" https://www.google.com > /dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC} 代理连接成功 (Google)"
    else
        echo -e "${RED}[ERROR]${NC} 代理连接失败"
    fi
    
    if curl -s --max-time 5 -x "$http_proxy" https://github.com > /dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC} 代理连接成功 (GitHub)"
    else
        echo -e "${RED}[ERROR]${NC} 代理连接失败"
    fi
}

add_to_bashrc() {
    local rc_file="$1"
    local proxy_line='[ -f ~/.proxy_env ] && source ~/.proxy_env'
    
    if ! grep -q "proxy_env" "$rc_file" 2>/dev/null; then
        echo "" >> "$rc_file"
        echo "# Proxy settings" >> "$rc_file"
        echo "$proxy_line" >> "$rc_file"
        echo -e "${GREEN}[INFO]${NC} 已添加到 $rc_file"
    else
        echo -e "${YELLOW}[WARN]${NC} $rc_file 已包含代理配置"
    fi
}

enable_persistent() {
    set_proxy
    add_to_bashrc ~/.bashrc
    
    if [ -f /etc/bash.bashrc ]; then
        add_to_bashrc /etc/bash.bashrc
    fi
    
    echo -e "${GREEN}[INFO]${NC} 代理设置已持久化"
}

main() {
    local host_ip_arg=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--ip)
                host_ip_arg="$2"
                shift 2
                ;;
            -s|--set)
                if [[ "$2" =~ ^[0-9]+$ ]]; then
                    VPN_PROXY_PORT="$2"
                    shift
                fi
                shift
                ;;
            -u|--unset)
                unset_proxy
                exit 0
                ;;
            -t|--test)
                test_proxy
                exit 0
                ;;
            -e|--enable)
                enable_persistent
                exit 0
                ;;
            --show)
                show_proxy
                exit 0
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                show_usage
                exit 1
                ;;
        esac
    done
    
    if [ -n "$host_ip_arg" ]; then
        export HOST_IP="$host_ip_arg"
    fi
    
    set_proxy
}

main "$@"
