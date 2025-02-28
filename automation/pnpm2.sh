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
USER_HOME="/home/$(whoami)"
PROFILE="$USER_HOME/.bash_profile"

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
    
    ln -fs "$src" "$dest" && log "创建软链接: $dest → $src"
}

# npm 前缀配置检查
check_npm_prefix() {
    local target_prefix="$USER_HOME/.npm-global"
    local current_prefix
    
    # 获取当前配置并过滤错误输出
    current_prefix=$(npm config get prefix 2>/dev/null)
    
    # 检查是否需要更新
    if [ "$current_prefix" != "$target_prefix" ]; then
        log "配置 npm 前缀为 $target_prefix..."
        if ! npm config set prefix "$target_prefix" 2>/dev/null; then
            warn "前缀配置失败（可能已被项目配置锁定）"
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
    check_npm_prefix  # 替换原来的直接配置命令

    log "设置 Node.js 软链接..."
    safe_link "/usr/local/bin/node20" "$USER_HOME/bin/node"
    safe_link "/usr/local/bin/npm20" "$USER_HOME/bin/npm"

    log "更新 PATH 环境变量..."
    add_to_profile '\.npm-global/bin' 'export PATH="$HOME/.npm-global/bin:$HOME/bin:$PATH"'
    
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

    log "验证安装..."
    pnpm -v || error "pnpm 未正确安装"

    log "=== 安装完成 ==="
}

# 执行主函数
install_pnpm
