#!/bin/bash
# 诺依阁<wkkjonlykang@vip.qq.com>
# 编写日期: 2025-03-31
# dockerfile构建测试专用

docker build -f ../dockerfile -t nuoyis1024/lnmp:dev --no-cache -f dockerfile --load ../