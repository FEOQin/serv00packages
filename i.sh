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

# 定义关键路径变量
USER_HOME="/home/$(whoami)"
PROFILE="$USER_HOME/.bash_profile"

# 环境变量重载函数
re_source() {
    source "$PROFILE" || warn "未能加载 $PROFILE"
    source ~/.bashrc    || warn "未能加载 .bashrc"
}

# pnpm 安装函数
install_pnpm() {
    log "创建必要目录..."
    mkdir -p "$USER_HOME/.npm-global" "$USER_HOME/bin"

    log "配置 npm 前缀..."
    npm config set prefix "$USER_HOME/.npm-global"

    log "设置 Node.js 软链接..."
    ln -fs /usr/local/bin/node20 "$USER_HOME/bin/node"
    ln -fs /usr/local/bin/npm20 "$USER_HOME/bin/npm"

    log "更新 PATH 环境变量..."
    echo "export PATH=\"\$HOME/.npm-global/bin:\$HOME/bin:\$PATH\"" >> "$PROFILE"
    re_source

    log "清理旧版 pnpm..."
    rm -rf "$USER_HOME/.local/share/pnpm" 
    rm -rf "$USER_HOME/.npm-global/lib/node_modules/pnpm"

    log "通过 npm 安装 pnpm..."
    npm install -g pnpm || error "pnpm 安装失败"

    log "配置 pnpm 存储路径..."
    pnpm setup

    log "添加 pnpm 环境变量..."
    if ! grep -q "PNPM_HOME" "$PROFILE"; then
        echo "export PNPM_HOME=\"\$HOME/.local/share/pnpm\"" >> "$PROFILE"
        echo "export PATH=\"\$PNPM_HOME:\$PATH\"" >> "$PROFILE"
    fi
    re_source

    log "验证安装..."
    pnpm -v || error "pnpm 未正确安装"
}

# 执行安装
log "=== 开始安装 pnpm ==="
install_pnpm
log "=== 安装完成 ==="
