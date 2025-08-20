#!/bin/bash
# 诺依阁<wkkjonlykang@vip.qq.com>
# 编写日期: 2025-03-31
# dockerfile构建测试专用

is_it=2
build_version=$2
CURL_CA_BUNDLE=""

docker build -t nuoyis-lnmp:test --build-arg NGINX_VERSION=1.27.3 --build-arg PHP_LATEST_VERSION=8.4.11 --build-arg PHP_STABLE_VERSION=7.4.33 --build-arg PHP_REDIS_VERSION=6.1.0 --build-arg MARIADB_LATEST_VERSION=12.0.0 --no-cache -f dockerfile .
