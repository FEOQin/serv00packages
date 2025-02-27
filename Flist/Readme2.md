```
1、cd domains/创建在serv00的域名/public_html
2、git clone https://github.com/FEOQin/FList.git && cd FList
3、pnpm add @rollup/wasm-node
4、pnpm approve-builds
5、修改```package.json```
```
{
  "name": "flist",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "type": "module",
  "scripts": {
    "dev": "vuepress dev",
    "build": "NODE_OPTIONS=--max-old-space-size=4096 vuepress build"
  },
  "keywords": [],
  "author": "",
  "license": "ISC",
  "devDependencies": {
    "@types/markdown-it": "^14.1.2",
    "@vuepress/bundler-vite": "2.0.0-rc.14",
    "@vuepress/plugin-nprogress": "2.0.0-rc.38",
    "aplayer": "^1.10.1",
    "artplayer": "^5.1.7",
    "markdown-it": "^14.1.0",
    "pdf-vue3": "^1.0.12",
    "typescript": "^5.5.4",
    "v-viewer": "^3.0.13",
    "viewerjs": "^1.11.6",
    "vite": "^5.4.1",
    "vue": "^3.4.38",
    "vuepress": "2.0.0-rc.14"
  },
  "dependencies": {
    "@rollup/wasm-node": "^4.34.8"
  },
  "pnpm": {
    "onlyBuiltDependencies": [
      "esbuild"
    ]
  },
  "resolutions": {
    "rollup": "npm:@rollup/wasm-node@4.34.8"
  }
}
```
pnpm install --force
6、pnpm run build
7、cp -r .vuepress/dist/* ~/domains/创建在serv00的域名/public_html/
8、cd ~/domains/创建在serv00的域名/ 
9、chmod -R 755 ~/public_html
```
