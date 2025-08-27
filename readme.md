# nuoyis's build lnmp
## 前言

nuoyis-lnmp 作为从原nuoyis-lnmp-np和mariadb配合使用的容器转变为全编译构建融合的容器，并在此做出了巨大优化和独特的服务方面。此项目为开源项目，但没有上传配置文件，故在文章补足或后续添加。

## 编写思路

由于某些官方镜像过于精简和配置过于复杂，本项目解决了php站点普遍配置难受，迁移难，安装速度慢等问题。为了解决该问题，从nuoyis-lnmp-np开始，nuoyis-toolbox脚本便可快速部署docker以及该项目。同时，本项目也是兼容k3s/k8s而生，尽量使容器在升级时采取不间断升级方法。

## 构建方法

1. 采取github-actions+arm64树莓派搭建的runner自动构建此镜像
2. 采取本地build-dev.sh和build.sh(树莓派sd卡down的情况下)构建此镜像

## 结尾

欢迎使用该镜像来部署你的站点,使用php仅需include就行开启https/https3  
仅需include head.conf即可开启同时为用户在conf页面提供了两个模板，一个是全部无缩减版本，用于防止镜像bug,一个是精简版本，仅需复制修改少量内容即可上线网站  
更多详细内容请看https://blog.nuoyis.net/posts/28fb.html 和 https://blog.nuoyis.net/posts/abed.html  
首次运行正常访问ip会弹出：welcome to use nuoyis service