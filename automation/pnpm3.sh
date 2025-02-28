#!/bin/bash
set -e

# 定义颜色输出函数
log() {
    echo -e "\033[32m[INFO] $1\033[0m"
}
error() {
    echo -e "\033[31m[ERROR] $1\033[0m"
    exit 1
}
warn() {
    echo -e "\033[33m[WARN] $1\033[0m"
}

# 配置参数 (按需修改)
NODE_VERSION="18.20.4"
NODE_BIN_NAME="node18"
NPM_BIN_NAME="npm18"

# 系统路径配置
USER_HOME="/home/$(whoami)"
BIN_DIR="$USER_HOME/bin"
NPM_PREFIX="$USER_HOME/.npm-global"
PROFILE="$USER_HOME/.bash_profile"

# 环境诊断函数
debug_info() {
    echo -e "\n=== 环境诊断 ==="
    echo "用户: $(whoami)"
    echo "家目录: $USER_HOME"
    echo "Node路径: $(command -v node || echo '未找到')"
    echo "npm路径: $(command -v npm || echo '未找到')"
    echo "当前Node版本: $(node -v 2>/dev/null || echo '未知')"
    echo "目标版本: $NODE_VERSION"
}
trap debug_info ERR

# 环境变量重载
re_source() {
    for rc in "$PROFILE" "$USER_HOME/.bashrc"; do
        [ -f "$rc" ] && source "$rc" >/dev/null 2>&1 || true
    done
}

# 安全软链接
safe_link() {
    local src="$1"
    local dest="$2"
    
    [ ! -f "$src" ] && error "源文件不存在: $src"
    
    mkdir -p "$(dirname "$dest")"
    if [ "$(readlink "$dest")" != "$src" ]; then
        ln -fs "$src" "$dest" && log "创建链接: $dest → $src"
    else
        log "链接已存在: $dest → $src"
    fi
}

# 配置Node环境
setup_node() {
    log "配置 Node $NODE_VERSION 环境..."
    
    # 设置系统版本软链接
    safe_link "/usr/local/bin/$NODE_BIN_NAME" "$BIN_DIR/node"
    safe_link "/usr/local/bin/$NPM_BIN_NAME" "$BIN_DIR/npm"
    
    # 验证版本
    local current_version=$(node -v 2>/dev/null)
    if [[ "$current_version" != *"$NODE_VERSION"* ]]; then
        error "版本不匹配! 当前: ${current_version:-无}, 期望: $NODE_VERSION"
    fi
}

# 配置npm环境
setup_npm() {
    log "配置npm环境..."
    
    # 清理旧配置
    rm -f "$USER_HOME/.npmrc" 2>/dev/null
    
    # 写入新配置
    cat > "$USER_HOME/.npmrc" << EOF
prefix=$NPM_PREFIX
global=true
update-notifier=false
EOF

    # 验证配置
    [ "$(npm config get prefix)" = "$NPM_PREFIX" ] || error "npm配置失败"
}

# 主安装流程
main() {
    log "=== 开始环境配置 ==="
    
    # 初始化目录
    mkdir -p "$BIN_DIR" "$NPM_PREFIX"
    
    # 配置Node
    setup_node
    
    # 配置npm
    setup_npm
    
    # 设置PATH
    echo 'export PATH="$HOME/bin:$HOME/.npm-global/bin:$PATH"' >> "$PROFILE"
    re_source
    
    log "=== 配置完成 ==="
    echo -e "请执行以下命令使配置生效:"
    echo -e "\033[33msource ~/.bash_profile && hash -r\033[0m"
}

# 执行主程序
main
