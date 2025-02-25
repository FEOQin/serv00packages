log "安装 pnpm 脚本启动..."
log "获取用户名..."
USER_HOME="/home/$(whoami)"
install_pnpm() {
    mkdir -p "$USER_HOME/.npm-global" "$USER_HOME/bin"
    
    log "配置 npm..."
    npm config set prefix "$USER_HOME/.npm-global"
    ln -fs /usr/local/bin/node20 "$USER_HOME/bin/node"
    ln -fs /usr/local/bin/npm20 "$USER_HOME/bin/npm"
    
    # 使用双引号允许变量扩展
    echo "export PATH=\"\$HOME/.npm-global/bin:\$HOME/bin:\$PATH\"" >> "$PROFILE"
    re_source
    
    log "安装和配置 pnpm..."
    # 清理可能存在的旧安装
    rm -rf "$USER_HOME/.local/share/pnpm"
    rm -rf "$USER_HOME/.npm-global/lib/node_modules/pnpm"
    
    # 使用 npm 安装 pnpm
    npm install -g pnpm || error "pnpm 安装失败"
    
    # 配置 pnpm
    pnpm setup
    
    # 添加 pnpm 环境变量
    if ! grep -q "PNPM_HOME" "$PROFILE"; then
        echo "export PNPM_HOME=\"\$HOME/.local/share/pnpm\"" >> "$PROFILE"
        echo "export PATH=\"\$PNPM_HOME:\$PATH\"" >> "$PROFILE"
    fi
    re_source
}
