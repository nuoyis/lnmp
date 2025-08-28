#!/bin/bash

useradd -u 2233 -m -s /sbin/nologin web
mkdir -p /nuoyis-server/web
# 给挂载目录递归修正权限和属主属组
chown -R web:web /nuoyis-server/web
chmod -R u+rwX,g+rwX,o-rwx /nuoyis-server/web

chown -R web:web /var/log/web
chmod -R u+rwX,g+rwX,o-rwx /var/log/web

# 确认挂载目录的父目录也有权限
chmod g+x /nuoyis-server
chmod g+x /var/log/web