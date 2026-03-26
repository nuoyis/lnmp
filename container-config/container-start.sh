#!/bin/bash
# 诺依阁<wkkjonlykang@vip.qq.com>
# 编写日期: 2026-03-17
# docker/kubernetes启动脚本

# 自定义目录
dockerdir="/server/web"
# 自定义运行方式，docker或kubernetes(后面可以简写，反正不等于docker)
container_type="docker"
# latest(稳定版)还是dev(开发版)
start_type="latest"

#### 命令执行区 ####
useradd -u 2233 -m -s /sbin/nologin web
mkdir -p /${dockerdir}/web
# 给挂载目录递归修正权限和属主属组
chown -R web:web /${dockerdir}/web
chmod -R u+rwX,g+rwX,o-rwx /${dockerdir}/web
chown -R web:web /var/log/web
chmod -R u+rwX,g+rwX,o-rwx /var/log/web
# 确认挂载目录的父目录也有权限
chmod g+x /${dockerdir}
chmod g+x /var/log/web

if [ $container_type == "docker" ];then
    docker-compose -f docker-compose-lnmp-${start_type}.yaml up -d
else
    kubectl apply -f kubernetes-lnmp-${start_type}.yaml
fi