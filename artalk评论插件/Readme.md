## 1、拉取项目
#进入创建域名的`public_html` 文件下
```
cd domains/这里创建.域名绑定端口.com/public_html

#拉取artalk官方最新项目
git clone https://github.com/ArtalkJS/Artalk.git
```
## 2、编译项目
不想自行构建的可以直接下载 ~[Release下载地址](https://github.com/FEOQin/serv00packages/releases/download/artalk%E8%AF%84%E8%AE%BA%E6%8F%92%E4%BB%B6/artalk)
```
#进入项目文件夹
cd Artalk
#编译项目
##这里构建项目时间较长，不要使用webssh会断线，使用正常SSH软件
go build
```

构建完成后在serv00的File Manager中可以看到一个名叫 artalk 的文件
![artalk](https://b2.qbobo.eu.org/2025/02/22/631782.png)
