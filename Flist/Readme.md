```python
1、cd domains/创建在serv00的域名/public_html
2、git clone https://github.com/FEOQin/FList.git && cd FList
3、pnpm add -D @rollup/wasm-node@latest
4、rm -rf node_modules pnpm-lock.yaml
5、pnpm install --force
6、pnpm run build
7、cp -r .vuepress/dist/* ~/domains/创建在serv00的域名/public_html/
8、cd ~/domains/创建在serv00的域名/ 
9、chmod -R 755 ~/public_html
