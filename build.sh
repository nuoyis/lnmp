#!/bin/bash
# 诺依阁<wkkjonlykang@vip.qq.com>
# 编写日期: 2025-03-31
# dockerfile构建测试专用
build_version=$1
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

if [ -z "$build_version" ];then
    read -p "请输入docker版本号:" build_version
fi

docker buildx build --platform "linux/amd64,linux/arm64" -t nuoyis1024/nuoyis-lnmp:latest -t nuoyis1024/nuoyis-lnmp:$build_version -t registry.cn-hangzhou.aliyuncs.com/nuoyis/nuoyis-lnmp:latest -t registry.cn-hangzhou.aliyuncs.com/nuoyis/nuoyis-lnmp:$build_version --push .
