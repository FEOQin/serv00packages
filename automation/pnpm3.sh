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
NPM_CONFIG_PATH="$USER_HOME/.npmrc"

# 环境诊断函数
debug_info() {
    echo -e "\n=== 环境诊断 ==="
    echo "User: $(id -un)"
    echo "HOME: $USER_HOME"
    echo "PATH: $PATH"
    echo "Node路径: $(command -v node 2>/dev/null || echo '未找到')"
    echo "npm路径: $(command -v npm 2>/dev/null || echo '未找到')"
    echo "当前Node版本: $(node -v 2>/dev/null || echo '无法获取')"
    echo "npm配置前缀: $(npm config get prefix 2>/dev/null || echo '未配置')"
    echo "npm配置文件: $(npm config get userconfig 2>/dev/null || echo '无')"
    echo "pnpm路径: $(command -v pnpm 2>/dev/null || echo '未安装')"
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

# 路径查重函数（精确匹配）
add_to_profile() {
    local line="$1"
    if ! grep -Fxq "$line" "$PROFILE" 2>/dev/null; then
        echo "$line" >> "$PROFILE"
        log "已添加环境变量到 $PROFILE"
    else
        log "环境变量已存在，跳过添加"
    fi
}

# 安全软链接函数（增强版）
safe_link() {
    local src="$1"
    local dest="$2"
    
    # 验证源文件存在且可执行
    [ ! -x "$src" ] && error "源文件不可执行或不存在: $src"
    
    # 创建父目录（如果不存在）
    mkdir -p "$(dirname "$dest")"
    
    # 检查现有链接是否正确
    if [ -L "$dest" ]; then
        local current_link=$(readlink -f "$dest")
        [ "$current_link" = "$src" ] && return 0
    fi
    
    # 创建新链接
    ln -fs "$src" "$dest" && log "创建软链接: $dest → $src"
}

# 强制清理npm配置
purge_npm_config() {
    log "清理所有npm配置..."
    rm -f "$NPM_CONFIG_PATH" 2>/dev/null || true
    rm -f "$USER_HOME/.npm/_logs/*" 2>/dev/null || true
    find "$USER_HOME" -maxdepth 3 -name ".npmrc" -delete 2>/dev/null || true
    npm cache clean --force >/dev/null 2>&1 || true
}

# 原子级npm配置
atomic_npm_config() {
    log "配置原子级npm设置..."
    
    # 创建新的临时配置
    local temp_conf=$(mktemp)
    echo "prefix = $USER_HOME/.npm-global" > "$temp_conf"
    echo "global = true" >> "$temp_conf"
    echo "update-notifier = false" >> "$temp_conf"
    
    # 原子替换旧配置
    mv -f "$temp_conf" "$NPM_CONFIG_PATH"
    
    # 双重验证
    if ! grep -q "prefix = $USER_HOME/.npm-global" "$NPM_CONFIG_PATH"; then
        error "npm配置写入失败"
    fi
}

# 强制环境刷新
force_env() {
    export PATH="$USER_HOME/bin:$USER_HOME/.npm-global/bin:$USER_HOME/.local/share/pnpm:$PATH"
    hash -r 2>/dev/null
}

# 深度版本验证
validate_versions() {
    log "执行深度验证..."
    
    # 使用绝对路径验证
    local abs_node="$USER_HOME/bin/node"
    local abs_npm="$USER_HOME/bin/npm"
    
    # Node验证
    local node_version=$("$abs_node" -v 2>/dev/null | cut -d. -f1)
    [ "$node_version" = "v20" ] || error "Node版本异常: $("$abs_node" -v)"
    
    # npm验证（跳过配置检查）
    local npm_version=$("$abs_npm" -v --no-global-config 2>/dev/null)
    [ "$npm_version" = "10.8.1" ] || error "npm版本异常: $npm_version"
    
    # 配置验证
    local npm_prefix=$("$abs_npm" config get prefix --no-global-config 2>/dev/null)
    [ "$npm_prefix" = "$USER_HOME/.npm-global" ] || error "npm配置未生效"
}

# 主安装函数
install_pnpm() {
    log "=== 开始安装 pnpm ==="
    
    # 环境初始化
    purge_npm_config
    mkdir -p "$USER_HOME/.npm-global" "$USER_HOME/bin" "$USER_HOME/.local/share/pnpm"
    
    # 配置Node环境
    safe_link "/usr/local/bin/node20" "$USER_HOME/bin/node"
    safe_link "/usr/local/bin/npm20" "$USER_HOME/bin/npm"
    force_env
    
    # 配置npm
    atomic_npm_config
    "$USER_HOME/bin/npm" config set fund false --global >/dev/null 2>&1
    
    # 配置PATH
    add_to_profile 'export PATH="$HOME/bin:$HOME/.npm-global/bin:$HOME/.local/share/pnpm:$PATH"'
    re_source
    force_env
    
    # 安装pnpm
    log "安装pnpm..."
    "$USER_HOME/bin/npm" install -g pnpm >/dev/null 2>&1 || error "pnpm安装失败"
    
    # 配置pnpm
    PNPM_HOME="$USER_HOME/.local/share/pnpm"
    add_to_profile "export PNPM_HOME=\"$PNPM_HOME\""
    add_to_profile 'export PATH="$PNPM_HOME:$PATH"'
    "$USER_HOME/.npm-global/bin/pnpm" setup >/dev/null 2>&1
    
    # 最终验证
    validate_versions
    log "Node版本: $("$USER_HOME/bin/node" -v)"
    log "npm版本: $("$USER_HOME/bin/npm" -v)"
    log "pnpm版本: $(pnpm -v)"
    
    log "=== 安装成功 ==="
    echo -e "\n请执行以下命令完成初始化："
    echo -e "\033[33msource ~/.bash_profile && hash -r\033[0m"
}

# 执行安装
install_pnpm
