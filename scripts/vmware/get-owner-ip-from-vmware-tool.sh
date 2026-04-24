

#!/bin/bash
# 修正：通过VMware工具获取宿主机IP的可行方法

# 检查并安装VMware工具
if [ ! -f /usr/bin/vmware-toolbox-cmd ]; then
    echo "正在安装VMware Tools..."
    # Ubuntu/Debian
    sudo apt update && sudo apt install -y open-vm-tools
    # RHEL/CentOS
    # sudo yum install -y open-vm-tools
fi

# 获取宿主机IP的多种方法
if command -v vmware-toolbox-cmd &> /dev/null; then
    echo "VMware Tools 已安装，版本: $(vmware-toolbox-cmd --version 2>/dev/null || echo '未知')"
    echo ""
    
    # 方法1：通过获取虚拟网络信息
    echo "=== 方法1：通过虚拟网络信息 ==="
    
    # 更新虚拟网络信息到宿主机
    vmware-toolbox-cmd info update network 2>/dev/null
    
    # 获取默认网关（NAT模式下通常是宿主机IP）
    HOST_IP=$(ip route show default 2>/dev/null | awk '/default/ {print $3}')
    
    if [ -n "$HOST_IP" ]; then
        echo "宿主机IP（通过网关推测）: $HOST_IP"
        
        # 验证是否为VMware虚拟网络
        echo "验证IP $HOST_IP 是否为VMware虚拟网络..."
        
        # 检查IP段是否属于VMware常见网段
        if [[ "$HOST_IP" =~ ^192\.168\.(10|122|233)\. ]] || \
           [[ "$HOST_IP" =~ ^172\.(16|17|18)\. ]] || \
           [[ "$HOST_IP" =~ ^10\. ]]; then
            echo "✓ IP $HOST_IP 属于常见VMware NAT网段"
        fi
        
        # 尝试获取宿主机MAC地址
        HOST_MAC=$(arp -n "$HOST_IP" 2>/dev/null | grep "$HOST_IP" | awk '{print $3}')
        if [ -n "$HOST_MAC" ]; then
            echo "宿主机MAC地址: $HOST_MAC"
            
            # VMware虚拟网卡MAC地址通常以特定前缀开头
            if [[ "$HOST_MAC" =~ ^(00:50:56|00:0C:29|00:05:69) ]]; then
                echo "✓ 确认是VMware虚拟网卡（MAC前缀匹配）"
            fi
        fi
    else
        echo "无法获取网关地址"
    fi
    
    echo ""
    
    # 方法2：通过VMware虚拟网络接口
    echo "=== 方法2：通过虚拟网络接口 ==="
    
    # 查找VMware虚拟网络接口
    VMWARE_INTERFACES=$(ip addr show 2>/dev/null | grep -E "vmnet|vboxnet|virbr" | head -1)
    
    if [ -n "$VMWARE_INTERFACES" ]; then
        echo "发现虚拟网络接口:"
        echo "$VMWARE_INTERFACES"
        
        # 获取该接口的IP地址
        VMWARE_IP=$(ip addr show 2>/dev/null | grep -A2 -E "vmnet|vboxnet|virbr" | grep "inet " | awk '{print $2}' | cut -d'/' -f1 | head -1)
        
        if [ -n "$VMWARE_IP" ]; then
            echo "虚拟网络接口IP: $VMWARE_IP"
        fi
    else
        echo "未发现明显的虚拟网络接口"
    fi
    
    echo ""
    
    # 方法3：通过路由表分析
    echo "=== 方法3：通过路由表分析 ==="
    
    echo "当前路由表:"
    ip route show 2>/dev/null | head -10
    
    # 查找NAT网络的路由
    NAT_ROUTE=$(ip route show 2>/dev/null | grep -E "192\.168\..*|172\..*|10\..*" | head -1)
    
    if [ -n "$NAT_ROUTE" ]; then
        echo "发现NAT网络路由: $NAT_ROUTE"
        
        # 提取网络段
        NETWORK=$(echo "$NAT_ROUTE" | grep -oE "192\.168\.[0-9]+\.[0-9]+|172\.[0-9]+\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+" | head -1)
        
        if [ -n "$NETWORK" ]; then
            echo "NAT网络段: $NETWORK"
            
            # 推测宿主机IP（通常是网络段的第一个或第二个IP）
            NETWORK_PREFIX=$(echo "$NETWORK" | cut -d'.' -f1-3)
            
            echo "推测宿主机可能IP:"
            for i in 1 2 254; do
                TEST_IP="$NETWORK_PREFIX.$i"
                if [ "$TEST_IP" != "$HOST_IP" ]; then
                    echo "  $TEST_IP"
                fi
            done
        fi
    fi
    
    echo ""
    
    # 方法4：通过VMware配置文件（如果可访问）
    echo "=== 方法4：检查VMware配置文件 ==="
    
    # 检查常见的VMware配置文件
    VMWARE_CONFIG_FILES=(
        "/etc/vmware-tools/tools.conf"
        "/etc/vmware/vmnet8/nat/nat.conf"
        "/var/lib/vmware/SharedVmfs"
    )
    
    for config_file in "${VMWARE_CONFIG_FILES[@]}"; do
        if [ -f "$config_file" ]; then
            echo "发现VMware配置文件: $config_file"
            
            # 显示文件开头几行
            head -20 "$config_file" 2>/dev/null | grep -i "ip\|host\|nat\|gateway" || true
        fi
    done
    
    echo ""
    
    # 最终推荐
    echo "=== 最终推荐 ==="
    echo "在VMware NAT模式下，最可靠的宿主机IP获取方法是："
    echo "1. 默认网关: $HOST_IP"
    echo "2. 在宿主机中，此IP通常配置在VMware虚拟网络适配器上"
    echo ""
    echo "从虚拟机访问宿主机，请使用: http://$HOST_IP 或 ping $HOST_IP"
    
else
    echo "VMware Tools 未安装或不可用"
    echo "请先安装VMware Tools: sudo apt install open-vm-tools"
fi

