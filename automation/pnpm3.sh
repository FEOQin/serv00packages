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
    echo "Node路径: $(command -v node 2>/dev/null || echo '未找到')"
    echo "npm路径: $(command -v npm 2>/dev/null || echo '未找到')"
    echo "当前Node版本: $(node -v 2>/dev/null || echo '无法获取')"
    echo "系统node20版本: $(/usr/local/bin/node20 -v 2>/dev/null || echo '未安装')"
    echo "npm配置前缀: $(npm config get prefix 2>/dev/null || echo '未配置')"
}
trap debug_info ERR

# 环境变量重载函数
re_source() {
    for rc in "$PROFILE" "$USER_HOME/.bashrc"; do
        if [ -f "$rc" ]; then
            source "$rc" >/dev/null 2>&1 || warn "部分加载 $rc 失败"
        fi
    done
}

# 增强型路径查重函数
add_to_profile() {
    local pattern="$1"
    local line="$2"
    
    # 使用精确匹配避免误判
    if ! grep -Fxq "$line" "$PROFILE" 2>/dev/null; then
        echo "$line" >> "$PROFILE"
        log "已添加环境变量到 $PROFILE"
    else
        log "环境变量已存在，跳过添加"
    fi
}

# 安全软链接函数（增强验证）
safe_link() {
    local src="$1"
    local dest="$2"
    
    # 验证源文件存在且可执行
    if [ ! -x "$src" ]; then
        error "源文件不可执行或不存在: $src"
    fi
    
    # 检查现有链接是否正确
    if [ -L "$dest" ]; then
        local current_link=$(readlink -f "$dest")
        if [ "$current_link" = "$src" ]; then
            log "软链接已正确设置: $dest → $src"
            return 0
        fi
    fi
    
    # 创建父目录
    mkdir -p "$(dirname "$dest")"
    
    ln -fs "$src" "$dest" && log "创建软链接: $dest → $src"
}

# 智能 npm 前缀配置检查
check_npm_prefix() {
    local target_prefix="$USER_HOME/.npm-global"
    local max_retries=3
    local attempt=1
    
    while [ $attempt -le $max_retries ]; do
        local current_prefix=$(npm config get prefix 2>/dev/null | tr -d '\n')
        
        if [ "$current_prefix" = "$target_prefix" ]; then
            log "npm 前缀已正确配置，跳过设置"
            return 0
        fi

        log "尝试配置 npm 前缀 (第 $attempt 次)..."
        
        # 清理可能存在的锁定文件
        rm -f "$USER_HOME/.npmrc" 2>/dev/null || true
        
        if npm config set prefix "$target_prefix" >/dev/null 2>&1; then
            log "成功配置 npm 前缀为 $target_prefix"
            return 0
        fi
        
        ((attempt++))
        sleep 1
    done
    
    error "无法配置 npm 前缀，请检查权限"
}

# 强制环境刷新函数
force_env() {
    export PATH="$USER_HOME/bin:$USER_HOME/.npm-global/bin:$USER_HOME/.local/share/pnpm:$PATH"
    hash -r 2>/dev/null
}

# 版本验证函数
validate_versions() {
    log "执行深度版本验证..."
    
    # Node.js 版本验证
    local node_path=$(command -v node)
    local system_node_version=$(/usr/local/bin/node20 -v 2>/dev/null | cut -d. -f1)
    local current_node_version=$(node -v 2>/dev/null | cut -d. -f1)
    
    if [ "$current_node_version" != "$system_node_version" ]; then
        error "Node版本不匹配 (当前: ${current_node_version:-无}, 系统node20: ${system_node_version:-无})\n检测到路径: $node_path"
    fi

    # npm 配置验证
    local npm_prefix=$(npm config get prefix 2>/dev/null)
    if [ "$npm_prefix" != "$USER_HOME/.npm-global" ]; then
        warn "npm前缀配置异常，尝试修复..."
        check_npm_prefix
    fi
}

# 主安装函数
install_pnpm() {
    log "=== 开始安装 pnpm ==="
    
    # 初始化环境
    log "清理旧配置..."
    rm -f "$USER_HOME/.npmrc" 2>/dev/null || true
    
    log "创建必要目录..."
    mkdir -p "$USER_HOME/.npm-global" "$USER_HOME/bin" "$USER_HOME/.local/share/pnpm"

    # 配置npm
    log "配置npm环境..."
    check_npm_prefix

    # 设置Node软链接
    log "设置 Node.js 软链接..."
    safe_link "/usr/local/bin/node20" "$USER_HOME/bin/node"
    safe_link "/usr/local/bin/npm20" "$USER_HOME/bin/npm"

    # 强制刷新环境
    log "强制刷新环境变量..."
    force_env

    # 验证基础环境
    validate_versions

    # 配置PATH
    log "更新全局PATH..."
    add_to_profile 'export PATH="$HOME/bin:$HOME/.npm-global/bin:$PATH"' \
        'export PATH="$HOME/bin:$HOME/.npm-global/bin:$PATH"'
    
    re_source

    # 清理旧版
    log "清理旧版pnpm..."
    rm -rf "$USER_HOME/.local/share/pnpm" 
    rm -rf "$USER_HOME/.npm-global/lib/node_modules/pnpm"

    # 安装pnpm
    log "通过npm安装pnpm..."
    if ! command -v pnpm &>/dev/null; then
        npm install -g pnpm >/dev/null 2>&1 || error "pnpm安装失败"
    else
        log "pnpm已安装，跳过安装步骤"
    fi

    # 配置pnpm
    log "配置pnpm存储路径..."
    pnpm setup >/dev/null 2>&1

    # 添加pnpm环境变量
    log "添加pnpm环境变量..."
    add_to_profile 'export PNPM_HOME="$HOME/.local/share/pnpm"' \
        'export PNPM_HOME="$HOME/.local/share/pnpm"'
    add_to_profile 'export PATH="$PNPM_HOME:$PATH"' \
        'export PATH="$PNPM_HOME:$PATH"'
    
    re_source
    force_env

    # 最终验证
    log "执行最终验证..."
    pnpm -v >/dev/null 2>&1 || error "pnpm未正确安装"
    log "Node版本验证通过: $(node -v)"
    log "npm版本验证通过: $(npm -v)"
    log "pnpm版本验证通过: $(pnpm -v)"

    log "=== 安装完成 ===\n"
    
    echo -e "请执行以下命令使配置立即生效："
    echo -e "\033[33msource ~/.bash_profile && hash -r\033[0m"
}

# 执行主函数
install_pnpm
