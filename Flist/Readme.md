1、cd domains/flist.nft6gq111.serv00.net/public_html
2、git clone https://github.com/FEOQin/FList.git && cd FList
3、pnpm add -D @rollup/wasm-node@latest
4、rm -rf node_modules pnpm-lock.yaml
5、pnpm install --force 6、pnpm run build
6、cp -r .vuepress/dist/* ~/domains/flist.nft6gq111.serv00.net/public_html/
7、cd ~/domains/flist.nft6gq111.serv00.net/ 
8、chmod -R 755 ~/public_html
