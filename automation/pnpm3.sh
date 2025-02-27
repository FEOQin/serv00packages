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

# 使用可靠的路径获取方式
USER_HOME="/usr/home/$(whoami)"
PROFILE="$USER_HOME/.bash_profile"

# 环境诊断函数
debug_info() {
    echo -e "\n=== 环境诊断 ==="
    echo "User: $(id -un)"
    echo "HOME: $USER_HOME"
    echo "PATH: $PATH"
    echo "Node路径: $(command -v node || echo '未找到')"
    echo "npm路径: $(command -v npm || echo '未找到')"
    echo "Node版本: $(node -v 2>/dev/null || echo '无法获取')"
    echo "系统node20版本: $(/usr/local/bin/node20 -v 2>/dev/null || echo '无法获取')"
}
trap debug_info ERR

# 环境变量重载函数
re_source() {
    for rc in "$PROFILE" "$USER_HOME/.bashrc"; do
        if [ -f "$rc" ]; then
            source "$rc" || warn "未能加载 $rc"
        fi
    done
}

# 路径查重函数
add_to_profile() {
    local pattern="$1"
    local line="$2"
    
    if ! grep -qE "$pattern" "$PROFILE" 2>/dev/null; then
        echo "$line" >> "$PROFILE"
        log "已添加环境变量到 $PROFILE"
    else
        log "环境变量已存在，跳过添加"
    fi
}

# 安全软链接函数
safe_link() {
    local src="$1"
    local dest="$2"
    
    if [ ! -f "$src" ]; then
        error "源文件不存在: $src"
    fi
    
    # 检查现有链接是否正确
    if [ -L "$dest" ]; then
        local current_link=$(readlink "$dest")
        if [ "$current_link" = "$src" ]; then
            log "软链接已存在且正确: $dest → $src"
            return 0
        fi
    fi
    
    ln -fs "$src" "$dest" && log "创建软链接: $dest → $src"
}

# 智能 npm 前缀配置检查
check_npm_prefix() {
    local target_prefix="$USER_HOME/.npm-global"
    local current_prefix
    
    current_prefix=$(npm config get prefix 2>/dev/null | tr -d '\n')
    
    if [ "$current_prefix" != "$target_prefix" ]; then
        log "配置 npm 前缀为 $target_prefix..."
        if ! npm config set prefix "$target_prefix" 2>/dev/null; then
            warn "前缀配置失败，尝试重置配置..."
            rm -f "$USER_HOME/.npmrc"
            npm config set prefix "$target_prefix"
        fi
    else
        log "npm 前缀已正确配置，跳过设置"
    fi
}

# 主安装函数
install_pnpm() {
    log "=== 开始安装 pnpm ==="
    
    log "创建必要目录..."
    mkdir -p "$USER_HOME/.npm-global" "$USER_HOME/bin"

    log "配置 npm 前缀..."
    check_npm_prefix

    log "设置 Node.js 软链接..."
    safe_link "/usr/local/bin/node20" "$USER_HOME/bin/node"
    safe_link "/usr/local/bin/npm20" "$USER_HOME/bin/npm"

    log "强制刷新环境变量..."
    export PATH="$USER_HOME/bin:$USER_HOME/.npm-global/bin:$PATH"

    log "验证 Node 链接..."
    local local_version=$(node -v 2>/dev/null | cut -d. -f1)
    local system_version=$(/usr/local/bin/node20 -v 2>/dev/null | cut -d. -f1)
    
    if [ "$local_version" != "$system_version" ]; then
        error "Node主版本不匹配 (本地: ${local_version:-未获取}, 系统: ${system_version:-未获取})"
    fi

    log "更新 PATH 环境变量..."
    add_to_profile '^export PATH=.*\.npm-global/bin' 'export PATH="$HOME/.npm-global/bin:$HOME/bin:$PATH"'
    
    re_source

    log "清理旧版 pnpm..."
    rm -rf "$USER_HOME/.local/share/pnpm" 
    rm -rf "$USER_HOME/.npm-global/lib/node_modules/pnpm"

    log "通过 npm 安装 pnpm..."
    if ! command -v pnpm &>/dev/null; then
        npm install -g pnpm || error "pnpm 安装失败"
    else
        log "pnpm 已安装，跳过安装步骤"
    fi

    log "配置 pnpm 存储路径..."
    pnpm setup

    log "添加 pnpm 环境变量..."
    add_to_profile 'PNPM_HOME' 'export PNPM_HOME="$HOME/.local/share/pnpm"'
    add_to_profile '\$PNPM_HOME' 'export PATH="$PNPM_HOME:$PATH"'
    
    re_source

    log "最终验证..."
    pnpm -v || error "pnpm 未正确安装"
    log "Node版本验证通过: $(node -v)"

    log "=== 安装完成 ==="
}

install_pnpm
