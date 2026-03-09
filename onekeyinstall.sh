
#!/bin/bash

# Ubuntu 24.04 一键部署脚本（兼容版）
# 功能：安装 httpd-tools、tree、chronyc、nvm
# 特别优化：支持普通用户运行，nvm正确安装到当前用户目录
# 兼容性：使用标准sh语法，避免[[ ]]等Bash扩展语法
# 作者：元宝
# 日期：2026-03-06

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查并获取当前用户
CURRENT_USER=$(whoami)
USER_HOME=$(eval echo ~$CURRENT_USER)
log_info "当前运行用户: $CURRENT_USER"
log_info "用户家目录: $USER_HOME"

# 检查是否具有sudo权限
check_sudo() {
    log_step "检查sudo权限..."
    if sudo -n true 2>/dev/null; then
        log_info "具有sudo权限"
        HAS_SUDO="true"
    else
        if [ "$CURRENT_USER" = "root" ]; then
            log_info "当前是root用户"
            HAS_SUDO="true"
        else
            log_warn "没有sudo权限，部分系统级安装可能失败"
            HAS_SUDO="false"
        fi
    fi
}

# 运行命令（带sudo检查）
run_cmd() {
    local cmd="$1"
    local need_sudo="$2"
    
    if [ "$need_sudo" = "true" ] && [ "$HAS_SUDO" = "true" ] && [ "$CURRENT_USER" != "root" ]; then
        log_info "执行（需sudo）: $cmd"
        sudo bash -c "$cmd"
    elif [ "$CURRENT_USER" = "root" ]; then
        log_info "执行（root）: $cmd"
        bash -c "$cmd"
    else
        log_info "执行: $cmd"
        bash -c "$cmd"
    fi
}

# 运行apt命令
run_apt() {
    local cmd="$1"
    
    if [ "$HAS_SUDO" = "true" ]; then
        if [ "$CURRENT_USER" = "root" ]; then
            apt-get $cmd
        else
            sudo apt-get $cmd
        fi
    else
        log_error "没有sudo权限，无法执行apt命令: $cmd"
        exit 1
    fi
}

# 配置APT源（需要sudo）
setup_apt_source() {
    log_step "配置APT源..."
    
    if [ "$HAS_SUDO" != "true" ]; then
        log_warn "跳过APT源配置（需要sudo权限）"
        return
    fi
    
    # 备份原有源
    if [ -f /etc/apt/sources.list ]; then
        backup_file="/etc/apt/sources.list.backup.$(date +%Y%m%d%H%M%S)"
        run_cmd "cp /etc/apt/sources.list $backup_file" "true"
        log_info "已备份原sources.list到: $backup_file"
    fi
    
    # 使用阿里云Ubuntu 24.04镜像源
    cat > /tmp/sources.list.tmp << 'EOF'
# 阿里云Ubuntu 24.04镜像源
deb https://mirrors.aliyun.com/ubuntu/ noble main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ noble-security main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ noble-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ noble-backports main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ noble main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ noble-security main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ noble-updates main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ noble-backports main restricted universe multiverse
EOF
    
    run_cmd "cp /tmp/sources.list.tmp /etc/apt/sources.list" "true"
    run_cmd "rm -f /tmp/sources.list.tmp" "true"
    log_info "APT源已更新为阿里云镜像"
}

# 更新系统包（需要sudo）
update_system() {
    log_step "更新系统包..."
    
    if [ "$HAS_SUDO" != "true" ]; then
        log_warn "跳过系统更新（需要sudo权限）"
        return
    fi
    
    log_info "更新包列表..."
    run_apt "update -y"
    
    log_info "升级已安装的包..."
    run_apt "upgrade -y --allow-downgrades"
    
    log_info "清理无用包..."
    run_apt "autoremove -y"
    run_apt "clean"
}

# 安装系统级软件包（需要sudo）
install_system_packages() {
    log_step "安装系统级软件包..."
    
    if [ "$HAS_SUDO" != "true" ]; then
        log_warn "跳过系统包安装（需要sudo权限）"
        return
    fi
    
    # 安装httpd-tools（包含在apache2-utils中）
    log_info "安装httpd-tools..."
    run_apt "install -y apache2-utils"
    
    # 安装tree
    log_info "安装tree..."
    run_apt "install -y tree"
    
    # 安装chrony（包含chronyc）
    log_info "安装chrony..."
    run_apt "install -y chrony"
    
    # 安装curl、wget、git等工具
    log_info "安装网络工具..."
    run_apt "install -y curl wget git build-essential"
    
    log_info "系统级软件包安装完成"
}

# 配置chrony时间同步（需要sudo）
setup_chrony() {
    log_step "配置chrony时间同步..."
    
    if [ "$HAS_SUDO" != "true" ]; then
        log_warn "跳过chrony配置（需要sudo权限）"
        return
    fi
    
    # 检查chrony配置文件是否存在
    if [ -f /etc/chrony/chrony.conf ]; then
        # 使用阿里云NTP服务器
        run_cmd "sed -i 's/^pool.*/pool ntp.aliyun.com iburst/' /etc/chrony/chrony.conf" "true"
        
        # 重启chrony服务
        if command -v systemctl >/dev/null 2>&1; then
            run_cmd "systemctl restart chrony" "true"
            run_cmd "systemctl enable chrony" "true"
        else
            run_cmd "service chrony restart" "true"
        fi
        
        # 等待同步完成
        sleep 2
        
        # 检查时间同步状态
        log_info "chrony状态:"
        chronyc sources -v 2>/dev/null || true
    else
        log_warn "chrony配置文件不存在，跳过配置"
    fi
}

# 为用户安装nvm（用户级安装，不需要sudo）
install_nvm_for_user() {
    log_step "为当前用户安装nvm..."
    
    # 检查是否已安装nvm
    if [ -d "$USER_HOME/.nvm" ] || [ -f "$USER_HOME/.nvm/nvm.sh" ]; then
        log_info "nvm似乎已安装，跳过安装"
        return
    fi
    
    # 设置环境变量（使用国内镜像）
    export NVM_DIR="$USER_HOME/.nvm"
    
    # 临时设置环境变量，使用国内镜像
    export NVM_NODEJS_ORG_MIRROR="https://npmmirror.com/mirrors/node"
    export NVM_IOJS_ORG_MIRROR="https://npmmirror.com/mirrors/iojs"
    
    # 使用gitee镜像下载nvm（国内更快）
    log_info "下载nvm..."
    if curl -fsSL -o /tmp/install_nvm.sh "https://gitee.com/mirrors/nvm/raw/master/install.sh"; then
        log_info "从gitee下载nvm成功"
    else
        log_warn "gitee镜像下载失败，尝试github..."
        curl -fsSL -o /tmp/install_nvm.sh "https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh"
    fi
    
    # 安装nvm
    if [ -f /tmp/install_nvm.sh ]; then
        log_info "开始安装nvm..."
        # 以当前用户身份运行安装脚本
        bash /tmp/install_nvm.sh
        
        # 加载nvm到当前shell环境
        if [ -s "$NVM_DIR/nvm.sh" ]; then
            . "$NVM_DIR/nvm.sh"
        fi
        
        # 清理临时文件
        rm -f /tmp/install_nvm.sh
    else
        log_error "nvm安装脚本下载失败"
        return
    fi
    
    # 验证nvm安装
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        log_info "nvm安装成功！"
        
        # 加载nvm
        if [ -f "$NVM_DIR/nvm.sh" ]; then
            . "$NVM_DIR/nvm.sh"
        fi
        
        # 安装最新的LTS版本Node.js
        if command -v nvm >/dev/null 2>&1; then
            log_info "安装最新Node.js LTS版本..."
            nvm install --lts
            
            # 设置为默认版本
            nvm use --lts
            nvm alias default 'lts/*'
            
            # 验证安装
            node_version=$(node --version 2>/dev/null || echo "未安装")
            npm_version=$(npm --version 2>/dev/null || echo "未安装")
            log_info "Node.js版本: $node_version"
            log_info "npm版本: $npm_version"
        else
            log_warn "nvm命令未找到，可能需要重新登录"
        fi
    else
        log_error "nvm安装失败，请手动安装"
        log_info "可尝试手动安装命令:"
        echo "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
    fi
}

# 配置用户环境变量
setup_user_env() {
    log_step "配置用户环境变量..."
    
    # 确定用户shell配置文件
    local shell_rc=""
    if [ -f "$USER_HOME/.bashrc" ]; then
        shell_rc="$USER_HOME/.bashrc"
    elif [ -f "$USER_HOME/.zshrc" ]; then
        shell_rc="$USER_HOME/.zshrc"
    elif [ -f "$USER_HOME/.profile" ]; then
        shell_rc="$USER_HOME/.profile"
    fi
    
    if [ -z "$shell_rc" ]; then
        log_warn "未找到用户shell配置文件，将使用.bashrc"
        shell_rc="$USER_HOME/.bashrc"
    fi
    
    # 检查是否已配置nvm
    if grep -q "NVM_DIR" "$shell_rc" 2>/dev/null; then
        log_info "nvm环境变量已配置"
    else
        log_info "添加nvm环境变量到 $shell_rc"
        cat >> "$shell_rc" << 'EOF'

# NVM配置
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # 加载nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # 加载nvm自动补全
EOF
        log_info "已添加nvm配置到 $shell_rc"
    fi
    
    # 立即加载配置
    if [ -s "$USER_HOME/.nvm/nvm.sh" ]; then
        . "$USER_HOME/.nvm/nvm.sh" 2>/dev/null || true
    fi
}

# 验证安装
verify_installation() {
    log_step "验证安装结果..."
    
    echo "========================================"
    echo "安装验证结果 (用户: $CURRENT_USER):"
    echo "========================================"
    
    # 检查httpd-tools
    if command -v ab >/dev/null 2>&1; then
        echo -e "✓ httpd-tools (ab): ${GREEN}已安装${NC}"
    else
        echo -e "✗ httpd-tools: ${RED}未找到${NC}"
    fi
    
    # 检查tree
    if command -v tree >/dev/null 2>&1; then
        echo -e "✓ tree: ${GREEN}已安装${NC}"
    else
        echo -e "✗ tree: ${RED}未找到${NC}"
    fi
    
    # 检查chronyc
    if command -v chronyc >/dev/null 2>&1; then
        echo -e "✓ chronyc: ${GREEN}已安装${NC}"
    else
        echo -e "✗ chronyc: ${RED}未找到${NC}"
    fi
    
    # 检查nvm
    if [ -d "$USER_HOME/.nvm" ] || command -v nvm >/dev/null 2>&1; then
        echo -e "✓ nvm: ${GREEN}已安装${NC}"
        if command -v node >/dev/null 2>&1; then
            node_version=$(node --version 2>/dev/null || echo "未知")
            echo -e "  Node.js版本: $node_version"
        fi
    else
        echo -e "✗ nvm: ${RED}未找到${NC}"
    fi
    
    # 检查当前用户对.nvm目录的权限
    if [ -d "$USER_HOME/.nvm" ]; then
        if command -v stat >/dev/null 2>&1; then
            owner=$(stat -c "%U" "$USER_HOME/.nvm" 2>/dev/null || stat -f "%Su" "$USER_HOME/.nvm" 2>/dev/null || echo "未知")
        else
            owner=$(ls -ld "$USER_HOME/.nvm" | awk '{print $3}' 2>/dev/null || echo "未知")
        fi
        if [ "$owner" = "$CURRENT_USER" ]; then
            echo -e "✓ nvm目录权限: ${GREEN}正确 ($owner)${NC}"
        else
            echo -e "⚠ nvm目录权限: ${YELLOW}不匹配 (属于: $owner, 当前用户: $CURRENT_USER)${NC}"
        fi
    fi
    
    echo "========================================"
}

# 显示使用说明
show_usage() {
    log_step "安装完成！使用说明："
    echo ""
    echo "1. httpd-tools (Apache Benchmark工具)"
    echo "   测试: ab -V"
    echo ""
    echo "2. tree (目录树显示工具)"
    echo "   测试: tree --version"
    echo "   使用: tree -L 2 /path/to/dir"
    echo ""
    echo "3. chronyc (时间同步工具)"
    echo "   测试: chronyc --version"
    echo "   查看状态: chronyc sources -v"
    echo "   手动同步: sudo chronyc makestep"
    echo ""
    echo "4. nvm (Node版本管理器)"
    echo "   注意: nvm已安装到用户 $CURRENT_USER 的家目录"
    echo "   要使nvm在当前终端生效，请执行:"
    echo "   source ~/.bashrc  # 如果使用bash"
    echo "   或重新登录/打开新终端"
    echo ""
    echo "   nvm常用命令:"
    echo "   nvm --version           # 查看nvm版本"
    echo "   nvm ls                  # 查看已安装的Node.js版本"
    echo "   nvm ls-remote           # 查看可安装的Node.js版本"
    echo "   nvm install 20         # 安装Node.js 20"
    echo "   nvm use 20             # 切换到Node.js 20"
    echo "   nvm alias default 20   # 设置默认版本为20"
    echo ""
    echo "5. 重新加载环境变量:"
    echo "   source ~/.bashrc  # 立即生效"
    echo ""
    
    if [ "$CURRENT_USER" != "root" ]; then
        log_info "当前以用户 '$CURRENT_USER' 运行，nvm已安装到: $USER_HOME/.nvm"
    fi
}

# 主函数
main() {
    echo "========================================"
    echo "Ubuntu 24.04 一键部署脚本（兼容版）"
    echo "正在为用户 [$CURRENT_USER] 安装:"
    echo "  - httpd-tools, tree, chronyc (系统级)"
    echo "  - nvm (用户级)"
    echo "========================================"
    
    # 检查sudo权限
    check_sudo
    
    # 配置APT源（可选，取消注释以下行启用）
    # setup_apt_source
    
    # 更新系统
    update_system
    
    # 安装系统级软件包
    install_system_packages
    
    # 配置chrony
    setup_chrony
    
    # 为用户安装nvm
    install_nvm_for_user
    
    # 配置用户环境变量
    setup_user_env
    
    # 验证安装
    verify_installation
    
    # 显示使用说明
    show_usage
    
    log_info "所有软件安装完成！"
    
    # 重要提示
    if [ "$CURRENT_USER" != "root" ]; then
        echo ""
        echo "========================================"
        echo "重要提示："
        echo "========================================"
        echo "nvm已安装到用户 '$CURRENT_USER' 的目录。"
        echo "要立即使用nvm，请执行以下命令之一："
        echo "1. 重新登录"
        echo "2. 执行: source ~/.bashrc"
        echo "3. 打开新的终端窗口"
        echo ""
        echo "验证安装: nvm --version"
        echo "========================================"
    fi
}

# 执行主函数
main "$@"

