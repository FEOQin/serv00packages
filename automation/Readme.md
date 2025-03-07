# 在serv00上一键安装脚本


## 一键安装pnpm
```bash
git clone https://github.com/FEOQin/serv00packages.git && cd serv00packages/automation && bash pnpm.sh

bash <(curl -fsSL https://raw.githubusercontent.com/FEOQin/serv00packages/main/automation/pnpm.sh)
```
### 生效环境变量
```
source ~/.bash_profile
source ~/.bashrc
```

### 安装后验证
安装完成后可以手动验证版本
```bash
pnpm --version
```
