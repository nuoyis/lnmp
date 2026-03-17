# nuoyis's build lnmp
## 前言

nuoyis-lnmp 作为从原nuoyis-lnmp-np和mariadb配合使用的容器转变为全编译构建融合的容器，并在此做出了巨大优化和独特的服务方面。此项目为开源项目，但没有上传配置文件，故在文章补足或后续添加。

## 编写思路

由于某些官方镜像过于精简和conf配置过于复杂，本项目解决了php站点普遍配置难受，迁移难，安装速度慢等问题。为了解决该问题，从nuoyis-lnmp-np老项目开始，nuoyis-toolbox脚本便可快速部署docker以及该项目。同时，本项目也是兼容k3s/k8s而生，尽量使容器在升级时采取不间断升级方法。

## 构建说明
新版构建采用docker变量控制需要构建的软件包
lnmp和lnmp-np共用一个dockerfile, lnmp比lnmp-np 多一个mariadb软件包
nginx采用全局抹掉版本号方式对外提供服务，对使用用户更安全
从0.0.5版本开始改变:
1. lnmp和lnmp-np使用同一个版本号，共用一个代码库
2. 增加CI/CD降低本地测试量，提交至dev审核通过后自动构建检测
3. CI/CD整合一个文件，共用一个流水线，先lnmp-np构建测试再构建lnmp，以节省时间和日志集中查看
4. autobuild 将与latest融合共用一个名称，介意的用户请指定版本号使用(脚本后续更新至版本号启动方案)

## 构建方法
1. 采取github-actions(arm64 + amd64)自动构建并检测镜像

## 结尾
欢迎使用该镜像来部署你的站点,使用php仅需include就行开启https/https3
仅需include head.conf即可开启同时为用户在conf页面提供了两个模板，一个是全部无缩减版本，用于防止镜像bug,一个是精简版本，仅需复制修改少量内容即可上线网站  
更多详细内容请看https://blog.nuoyis.net/posts/28fb.html 和 https://blog.nuoyis.net/posts/abed.html  
首次运行正常访问ip会弹出：welcome to use nuoyis service