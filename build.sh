#!/bin/bash
# 诺依阁<wkkjonlykang@vip.qq.com>
# 编写日期: 2025-03-31
# dockerfile构建测试专用

is_it=$1
build_version=$2
CURL_CA_BUNDLE=""

# 获取操作系统的 ID
os_id=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

# 根据操作系统类型安装 jq
case "$os_id" in
    debian|ubuntu)
        apt-get update
        apt-get install -y jq
        ;;
    centos|rhel|fedora)
        yum install -y jq
        ;;
    *)
        echo "Unsupported operating system: $os_id"
        exit 1
        ;;
esac

# 验证 jq 是否安装成功
if command -v jq >/dev/null 2>&1; then
    echo "jq installed successfully."
else
    echo "jq installation failed."
    exit 1
fi

NGINX_VERSION=$(curl -s "https://api.github.com/repos/nginx/nginx/releases/latest" | jq -r '.name' | grep -oP '\d+\.\d+\.\d+' | head -n 1)
PHP_LATEST_VERSION=$(curl -s "https://api.github.com/repos/php/php-src/releases" | jq -r '.[0].name' | grep -oP '\d+\.\d+\.\d+' | head -n 1)
PHP_STABLE_VERSION=$(curl -s "https://api.github.com/repos/php/php-src/releases" | jq -r '.[].name' | grep -oP '8\.1\.\d+' | head -n 1)
# 如果没有获取到版本，使用默认值
NGINX_VERSION=${NGINX_VERSION:-"1.27.3"}
PHP_LATEST_VERSION=${PHP_LATEST_VERSION:-"8.4.2"}
PHP_STABLE_VERSION=7.4.33
PHP_REDIS_VERSION=6.1.0

echo nginx: $NGINX_VERSION
echo php_latest: $PHP_LATEST_VERSION
echo php_stable: 7.4.33
echo php_redis_version: 6.1.0

if [ -z "$is_it" ];then
    read -p "1为github版本，2为国内加速版" is_it
fi

if [ -z "$build_version" ];then
    read -p "请输入docker版本号:" build_version
fi

rm -rf dockerfile/dockerfile
cp -f dockerfile/dockerfile_github dockerfile/dockerfile

if [ $is_it == "2" ];then
    sed -i 's|https://github.com|https://study-download.nuoyis.net/github/https://github.com|g' dockerfile/dockerfile
    sed -i 's|docker.io|docker.xuanyuan.me|g' dockerfile/dockerfile
fi

docker buildx build --platform "linux/amd64,linux/arm64,linux/arm/v7" --build-arg NGINX_VERSION=$NGINX_VERSION --build-arg PHP_LATEST_VERSION=$PHP_LATEST_VERSION --build-arg PHP_STABLE_VERSION=$PHP_STABLE_VERSION --build-arg PHP_REDIS_VERSION=$PHP_REDIS_VERSION --build-arg MARIADB_LATEST_VERSION=12.0.0 --no-cache -t registry.cn-hangzhou.aliyuncs.com/nuoyis/nuoyis-lnmp-np:latest -t registry.cn-hangzhou.aliyuncs.com/nuoyis/nuoyis-lnmp-np:$build_version -f dockerfile/dockerfile --push .
# docker build -t nuoyis-lnmp-np:l --build-arg NGINX_VERSION=1.27.3 --build-arg PHP_LATEST_VERSION=8.4.2 --build-arg PHP_STABLE_VERSION=8.1.31 --build-arg PHP_REDIS_VERSION=6.1.0 --build-arg=12.0.0 --no-cache -f dockerfile/dockerfile .
