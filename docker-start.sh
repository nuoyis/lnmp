#!/bin/bash

useradd -u 2233 -m -s /sbin/nologin nuoyis-web

mkdir -p /nuoyis-server/web
# 给挂载目录递归修正权限和属主属组
chown -R nuoyis-web:nuoyis-web /nuoyis-server/web
chmod -R u+rwX,g+rwX,o-rwx /nuoyis-server/web

# 确认挂载目录的父目录也有权限
chmod g+x /nuoyis-server
chmod g+x /nuoyis-server/web

docker-compose -f nuoyis-lnmp.yaml up -d
