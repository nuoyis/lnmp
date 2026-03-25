FROM docker.io/debian:13 AS versions

SHELL ["/bin/bash", "-c"]

RUN sed -i 's/http:\/\/deb.debian.org/https:\/\/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources;\
    apt -o Acquire::https::Verify-Peer=false -o Acquire::https::Verify-Host=false update -y;\
    apt -o Acquire::https::Verify-Peer=false -o Acquire::https::Verify-Host=false install -y curl jq ca-certificates;\
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Fetch versions from upstream (with sane fallbacks) and write JSON
RUN <<EOF
mkdir -p /tmp/build
NGINX_VERSION=$(curl -sLk "https://lnmp.nuoyis.net/versions.json" | jq -r '.versions.nginx')
PHP_LATEST_VERSION=$(curl -sLk "https://lnmp.nuoyis.net/versions.json" | jq -r '.versions.php')
MARIADB_LATEST_VERSION=$(curl -sLk "https://lnmp.nuoyis.net/versions.json" | jq -r '.versions.mariadb')
NGINX_VERSION=${NGINX_VERSION:-"1.29.1"}
PHP_LATEST_VERSION=${PHP_LATEST_VERSION:-"8.5.3"}
echo "ENV NGINX_VERSION=$NGINX_VERSION" >> /tmp/build/version.env
echo "ENV PHP_LATEST_VERSION=$PHP_LATEST_VERSION" >> /tmp/build/version.env
echo "ENV MARIADB_LATEST_VERSION=$MARIADB_LATEST_VERSION" >> /tmp/build/version.env
echo nginx: $NGINX_VERSION
echo php_latest: $PHP_LATEST_VERSION
echo php_stable: 7.4.33
echo php_redis_version: 6.1.0
echo mariadb_latest: $MARIADB_LATEST_VERSION
echo "nuoyis's lnmp will be build"
sleep 5
EOF

FROM docker.io/debian:13 AS builder

# 设置默认 shell
SHELL ["/bin/bash", "-c"]

# lnmp 最新版本信息
COPY --from=versions /tmp/build/version.env /tmp/build/version.env

# 架构变量定义
ARG TARGETARCH
ARG TARGETVARIANT
# lnmp和lnmp-np定义
ARG BUILD_TYPE=lnmp

ENV DEBIAN_FRONTEND=noninteractive

# 更换软件源，并安装基础依赖
RUN sed -i 's/http:\/\/deb.debian.org/https:\/\/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources;\
    apt -o Acquire::https::Verify-Peer=false -o Acquire::https::Verify-Host=false update -y;\
    apt -o Acquire::https::Verify-Peer=false -o Acquire::https::Verify-Host=false install -y ca-certificates;\
    apt install -y dos2unix vim jq wget autoconf bison re2c make procps gcc cmake g++ bison libicu-dev inetutils-ping pkg-config build-essential libpcre2-dev libncurses5-dev gnutls-dev zlib1g-dev libxslt1-dev libpng-dev libjpeg-dev libfreetype6-dev libxml2-dev libsqlite3-dev libbz2-dev libcurl4-openssl-dev libxpm-dev libzip-dev libonig-dev libgd-dev libaio-dev libgeoip-dev;\
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# 目录初始化
RUN export $(cat /tmp/build/version.env); \
mkdir -p /tmp/build/php-$PHP_LATEST_VERSION/ext/php-redis /tmp/build/php-7.4.33/ext/php-redis /web/{logs/{mariadb,nginx,php/{latest,stable}},nginx/{conf,webside/default,server/$NGINX_VERSION/conf/ssl}} /var/run/php/{stable,latest} /web/{supervisord,mariadb/{bin,data,config,logs}}

COPY software/openssl-3.5.5.tar.gz /tmp/build/openssl-3.5.5.tar.gz
COPY software/openssl-1.1.1w.tar.gz /tmp/build/openssl-1.1.1w.tar.gz
COPY software/phpredis-6.1.0.tar.gz /tmp/build/phpredis-6.1.0.tar.gz
COPY software/curl-7.87.0.tar.gz /tmp/build/curl-7.87.0.tar.gz
COPY software/php-7.4.33.tar.gz /tmp/build/php-7.4.33.tar.gz
WORKDIR /tmp/build
RUN <<EOF
export $(cat /tmp/build/version.env);
wget https://github.com/nginx/nginx/releases/download/release-$NGINX_VERSION/nginx-$NGINX_VERSION.tar.gz
wget https://www.php.net/distributions/php-$PHP_LATEST_VERSION.tar.gz
tar -xzf openssl-3.5.5.tar.gz
tar -xzf nginx-$NGINX_VERSION.tar.gz
tar -xzf php-$PHP_LATEST_VERSION.tar.gz
tar -xzf php-7.4.33.tar.gz
tar -xzf phpredis-6.1.0.tar.gz
tar -xzf openssl-1.1.1w.tar.gz
tar -xzf curl-7.87.0.tar.gz
cp -r phpredis-6.1.0/* php-$PHP_LATEST_VERSION/ext/php-redis
cp -r phpredis-6.1.0/* php-7.4.33/ext/php-redis
EOF

# Nginx编译
WORKDIR /tmp/build
RUN <<EOF
export $(cat /tmp/build/version.env);
cd nginx-$NGINX_VERSION
sed -i 's/#define NGINX_VERSION\s\+".*"/#define NGINX_VERSION      "'$NGINX_VERSION'"/g' ./src/core/nginx.h
sed -i 's/"nginx\/" NGINX_VERSION/"nuoyis server"/g' ./src/core/nginx.h
sed -i 's/Server: nginx/Server: nuoyis server/g' ./src/http/ngx_http_header_filter_module.c
./configure \
    --prefix=/web/nginx/server \
    --with-openssl=/tmp/build/openssl-3.5.5 \
    --user=web --group=web \
    --with-compat \
    --with-file-aio \
    --with-threads \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-stream \
    --with-stream_realip_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-cc-opt="-static" \
    --with-ld-opt="-static"
make -j$(nproc)
make install
EOF

# PHP综合构建
WORKDIR /tmp/build
RUN <<EOF
export $(cat /tmp/build/version.env);
cd /tmp/build/openssl-1.1.1w
CONFIGURE_OPTS="--prefix=/tmp/build/software/openssl-1.1.1 --openssldir=/tmp/build/software/openssl-1.1.1 no-shared no-dso no-tests"
if [ "$TARGETARCH" == "arm64" ]; then
    ./Configure linux-aarch64 $CONFIGURE_OPTS
else
    ./config $CONFIGURE_OPTS
fi
make -j$(nproc)
make install
cd /tmp/build/curl-7.87.0
./configure --prefix=/tmp/build/curl-openssl --with-ssl=/tmp/build/software/openssl-1.1.1 --disable-shared --enable-static
make -j$(nproc)
make install
cd /tmp/build/openssl-3.5.5
CONFIGURE_OPTS="--prefix=/tmp/build/software/openssl-3.5.5 --openssldir=/tmp/build/software/openssl-3.5.5 no-shared no-dso no-tests"
if [ "$TARGETARCH" == "arm64" ]; then
    ./Configure linux-aarch64 $CONFIGURE_OPTS
else
    ./config $CONFIGURE_OPTS
fi
make -j$(nproc)
make install
for phpversion in 7.4.33 $PHP_LATEST_VERSION; do
    if [ "$phpversion" == "7.4.33" ]; then
        export CXXFLAGS="-std=c++17"
        export tmptype=stable
        export CURL_PREFIX="/tmp/build/curl-openssl"
        export OPENSSL_PREFIX_PATH="/tmp/build/software/openssl-1.1.1"
        PHPCONFIG="--with-curl=${CURL_PREFIX} --with-openssl=${OPENSSL_PREFIX_PATH} --enable-opcache"
        export CPPFLAGS="-I${OPENSSL_PREFIX_PATH}/include -I${CURL_PREFIX}/include"
        export PKG_CONFIG_PATH="${CURL_PREFIX}/lib/pkgconfig:${OPENSSL_PREFIX_PATH}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    else
        unset CXXFLAGS CURL_PREFIX OPENSSL_PREFIX_PATH CPPFLAGS LDFLAGS PKG_CONFIG_PATH LD_LIBRARY_PATH
        export tmptype=latest
        export OPENSSL_PREFIX_PATH="/tmp/build/software/openssl-3.5.5"
        PHPCONFIG="--with-curl --with-openssl=${OPENSSL_PREFIX_PATH}"
    fi
    export LDFLAGS="-L${OPENSSL_PREFIX_PATH}/lib -L${CURL_PREFIX}/lib"
    export LD_LIBRARY_PATH="${OPENSSL_PREFIX_PATH}/lib:${CURL_PREFIX}/lib:${LD_LIBRARY_PATH:-}"
    cd /tmp/build/php-$phpversion
    ./configure --prefix=/web/php/$tmptype/  \
        --with-config-file-path=/web/php/$tmptype/etc/ \
        --with-freetype \
        --enable-gd \
        --with-jpeg \
        --with-gettext \
        --with-libdir=lib64 \
        --with-libxml \
        --with-mysqli \
        --with-pdo-mysql \
        --with-pdo-sqlite \
        --with-pear \
        --enable-sockets \
        --with-mhash \
        --with-ldap-sasl \
        --with-xsl \
        --with-zlib \
        --with-zip \
        --with-bz2 \
        --with-iconv \
        --enable-fpm \
        --enable-pdo \
        --enable-bcmath \
        --enable-mbregex \
        --enable-mbstring \
        --enable-pcntl \
        --enable-shmop \
        --enable-soap \
        --enable-ftp \
        --with-xpm \
        --enable-xml \
        --enable-sysvsem \
        --enable-cli \
        --enable-intl \
        --enable-calendar \
        --enable-static \
        --enable-ctype \
        --enable-mysqlnd \
        --enable-session \
        --enable-php-redis \
        $PHPCONFIG
    make -j$(nproc)
    make install
done
mv /web/php/latest/etc/php-fpm.conf.default /web/php/latest/etc/php-fpm.conf
mv /web/php/stable/etc/php-fpm.conf.default /web/php/stable/etc/php-fpm.conf
rm -rf /web/php/*/include /web/php/*/lib/php/tmp /web/php/*/php/man /tmp/build/curl-openssl /tmp/build/php
EOF

# mariadb 编译
WORKDIR /tmp/build
RUN <<EOF
if [ "$BUILD_TYPE" == "lnmp" ]; then
    export $(cat /tmp/build/version.env)
    wget https://mirrors.aliyun.com/mariadb/mariadb-$MARIADB_LATEST_VERSION/source/mariadb-$MARIADB_LATEST_VERSION.tar.gz
    tar -xzf mariadb-$MARIADB_LATEST_VERSION.tar.gz
    cd mariadb-$MARIADB_LATEST_VERSION
    cmake . \
        -DWITH_STATIC=ON \
        -DCMAKE_INSTALL_PREFIX=/web/mariadb \
        -DMYSQL_DATADIR=/web/mariadb/data \
        -DSYSCONFDIR=/web/mariadb/config \
        -DWITH_INNOBASE_STORAGE_ENGINE=1 \
        -DWITH_ARCHIVE_STORAGE_ENGINE=1 \
        -DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
        -DWITHOUT_TOKUDB=1 \
        -DWITHOUT_MROONGA_STORAGE_ENGINE=1 \
        -DPLUGIN_SPHINX=NO \
        -DPLUGIN_FEEDBACK=NO \
        -DWITH_READLINE=1 \
        -DWITH_SSL=system \
        -DWITH_ZLIB=system \
        -DWITH_LIBWRAP=0 \
        -DCMAKE_BUILD_TYPE=Release \
        -DWITH_DEBUG=0 \
        -DWITH_UNIT_TESTS=OFF \
        -DWITH_BENCHMARK=OFF \
        -DWITH_WSREP=OFF \
        -DENABLE_DTRACE=OFF \
        -DBUILD_TESTING=OFF \
        -DDEFAULT_CHARSET=utf8mb4 \
        -DDEFAULT_COLLATION=utf8mb4_general_ci \
        -DMYSQL_USER=web \
        -DMYSQL_UNIX_ADDR=/run/mariadb/mariadb.sock
    make -j$(nproc)
    make install
    strip /web/mariadb/bin/* /web/mariadb/lib/*.so* || true
    rm -rf /web/mariadb/mysql-test /web/mariadb/sql-bench /web/mariadb/man /web/mariadb/include /web/mariadb/docs /tmp/build/*
fi
EOF

# 配置文件添加
# docker-start-shell
ADD config/supervisord.conf.txt /web/supervisord/supervisord.conf
ADD config/start.sh.txt /web/start.sh
ADD config/healthcheck.sh.txt /web/healthcheck.sh
# nginx
ADD config/nginx.conf.txt /web/nginx/server/conf/nginx.conf
ADD config/ssl/default.pem /web/nginx/server/conf/ssl/default.pem
ADD config/ssl/default.key /web/nginx/server/conf/ssl/default.key
ADD config/start-php-latest.conf.txt /web/nginx/server/conf/start-php-latest.conf
ADD config/path.conf.txt /web/nginx/server/conf/path.conf
ADD config/start-php-stable.conf.txt /web/nginx/server/conf/start-php-stable.conf
ADD config/head.conf.txt /web/nginx/server/conf/head.conf
ADD config/index.html /web/nginx/server/template/index.html
ADD config/default.conf.txt /web/nginx/server/template/default.conf.init
ADD config/nginx.conf.full.template.txt /web/nginx/server/template/nginx.conf.full.template
ADD config/nginx.conf.succinct.template.txt /web/nginx/server/template/nginx.conf.succinct.template
# php
ADD config/latest-php.ini.txt /web/php/latest/etc/php.ini
ADD config/fpm-latest.conf.txt /web/php/latest/etc/php-fpm.d/fpm.conf
ADD config/stable-php.ini.txt /web/php/stable/etc/php.ini
ADD config/fpm-stable.conf.txt /web/php/stable/etc/php-fpm.d/fpm.conf

# 综合最后处理
RUN <<EOF
mkdir -p /web/libs;
if [ "$BUILD_TYPE" == "lnmp" ]; then
    binso="/web/php/latest/sbin/php-fpm /web/php/stable/sbin/php-fpm /web/mariadb/bin/mysqld"
else
    binso="/web/php/latest/sbin/php-fpm /web/php/stable/sbin/php-fpm"
fi
for bin in $binso; do \
    ldd $bin | grep -oE '/[^ ]+' | sort -u | xargs -r -I{} cp --parents {} /web/libs; \
done
find "/web" -type f -exec dos2unix {} \;
useradd -u 2233 -m -s /sbin/nologin web;
chown -R web:web /web;
chmod -R 775 /web;
chmod g+s /web;
chmod +x /web/start.sh;
chmod +x /web/healthcheck.sh;
EOF

# 创建最终镜像
FROM docker.io/debian:13-slim AS runner

# 设置默认 shell
SHELL ["/bin/bash", "-c"]

# lnmp和lnmp-np定义
ARG BUILD_TYPE=lnmp

# 设置时区
ENV TZ=Asia/Shanghai
ENV DEBIAN_FRONTEND=noninteractive

# 环境变量
ENV PATH=/web/mariadb/bin:/web/nginx/server/sbin:$PATH

# 复制 web文件夹
COPY --from=builder /web /web
# 必要的初始化
RUN <<EOF
if [ -d /web/libs ]; then
      find /web/libs -type d | sort -u > /etc/ld.so.conf.d/nuoyis-web-libs.conf;
      ldconfig;
fi
useradd -u 2233 -m -s /sbin/nologin web
ln -s /web/php/latest/sbin/php-fpm /usr/bin/php-latest
ln -s /web/php/stable/sbin/php-fpm /usr/bin/php-stable
sed -i 's/http:\/\/deb.debian.org/https:\/\/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources
apt -o Acquire::https::Verify-Peer=false -o Acquire::https::Verify-Host=false update -y
apt --no-install-recommends -o Acquire::https::Verify-Peer=false -o Acquire::https::Verify-Host=false install -y ca-certificates supervisor curl procps
if [ "$BUILD_TYPE" == "lnmp" ]; then
    mkdir /docker-entrypoint-initdb.d
fi
apt clean
rm -rf /var/cache/apt/* /var/lib/apt/lists/* /usr/share/doc /usr/share/man /usr/share/locale /usr/share/info
EOF

# 暴露端口
EXPOSE 80 443

# 设置容器的入口点
ENTRYPOINT ["/web/start.sh"]
CMD ["/usr/bin/supervisord", "-c", "/web/supervisord/supervisord.conf"]