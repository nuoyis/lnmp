#!/bin/bash
# 诺依阁<wkkjonlykang@vip.qq.com>
# 编写日期: 2025-03-31
# dockerfile构建测试专用
build_version=$1

if [ -z "$build_version" ];then
    read -p "请输入docker版本号:" build_version
fi

docker buildx build -f ../dockerfile --platform "linux/amd64,linux/arm64" -t nuoyis1024/lnmp:latest -t nuoyis1024/lnmp:$build_version -t registry.cn-hangzhou.aliyuncs.com/nuoyis/nuoyis-lnmp:latest -t registry.cn-hangzhou.aliyuncs.com/nuoyis/nuoyis-lnmp:$build_version --push ../