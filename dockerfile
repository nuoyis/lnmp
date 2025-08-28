FROM docker.io/debian:13 AS versions

SHELL ["/bin/bash", "-c"]

RUN sed -i 's/http:\/\/deb.debian.org/https:\/\/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources;\
    apt -o Acquire::https::Verify-Peer=false -o Acquire::https::Verify-Host=false update -y;\
    apt -o Acquire::https::Verify-Peer=false -o Acquire::https::Verify-Host=false upgrade -y;\
    apt -o Acquire::https::Verify-Peer=false -o Acquire::https::Verify-Host=false install -y curl jq ca-certificates;\
    rm -rf /var/lib/apt/lists/*

# Fetch versions from upstream (with sane fallbacks) and write JSON
RUN NGINX_VERSION=$(curl -s "http://lnmp-versions.nuoyis.net/versions.json" | jq -r '.versions.nginx');\
    PHP_LATEST_VERSION=$(curl -s "http://lnmp-versions.nuoyis.net/versions.json" | jq -r '.versions.php');\
    MARIADB_LATEST_VERSION=$(curl -s "http://lnmp-versions.nuoyis.net/versions.json" | jq -r '.versions.mariadb');\
    NGINX_VERSION=${NGINX_VERSION:-"1.29.1"};\
    PHP_LATEST_VERSION=${PHP_LATEST_VERSION:-"8.4.11"};\
    echo "ENV NGINX_VERSION=$NGINX_VERSION" >> /tmp/version.env;\
    echo "ENV PHP_LATEST_VERSION=$PHP_LATEST_VERSION" >> /tmp/version.env;\
    echo "ENV MARIADB_LATEST_VERSION=$MARIADB_LATEST_VERSION" >> /tmp/version.env;\
    echo nginx: $NGINX_VERSION;\
    echo php_latest: $PHP_LATEST_VERSION;\
    echo php_stable: 7.4.33;\
    echo php_redis_version: 6.1.0;\
    echo mariadb_latest: $MARIADB_LATEST_VERSION;\
    echo "nuoyis's lnmp will be build";\
    sleep 5
    
FROM docker.io/debian:13 AS builder

# 设置默认 shell
SHELL ["/bin/bash", "-c"]

# lnmp 最新版本信息
COPY --from=versions /tmp/version.env /tmp/version.env

# 架构变量定义
ARG TARGETARCH
ARG TARGETVARIANT

# 更换软件源，并安装基础依赖
RUN sed -i 's/http:\/\/deb.debian.org/https:\/\/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources;\
    apt -o Acquire::https::Verify-Peer=false -o Acquire::https::Verify-Host=false update -y;\
    apt -o Acquire::https::Verify-Peer=false -o Acquire::https::Verify-Host=false upgrade -y;\
    apt -o Acquire::https::Verify-Peer=false -o Acquire::https::Verify-Host=false install -y ca-certificates;\
    apt install -y \
        dos2unix \
        vim \
        jq \
        wget \
        autoconf \
        bison \
        re2c \
        make \
        procps \
        gcc \
        cmake \
        g++ \
        bison \
        libicu-dev \
        inetutils-ping \
        pkg-config \
        build-essential \
        libpcre2-dev \
        libncurses5-dev \
        gnutls-dev \
        zlib1g-dev \
        libxslt1-dev \
        libpng-dev \
        libjpeg-dev \
        libfreetype6-dev \
        libxml2-dev \
        libsqlite3-dev \
        libbz2-dev \
        libcurl4-openssl-dev \
        libxpm-dev \
        libzip-dev \
        libonig-dev \
        libgd-dev \
        libaio-dev \
        libgeoip-dev

# 目录初始化
RUN export $(cat /tmp/version.env); \
    mkdir -p /build/php-$PHP_LATEST_VERSION/ext/php-redis \
    /build/php-7.4.33/ext/php-redis \
    /web/{logs/{mariadb,nginx,php/{latest,stable}},nginx/{conf,webside/default,server/$NGINX_VERSION/conf/ssl}} \
    /var/run/php/{stable,latest} \
    /web/{supervisord,mariadb/{data,config,logs}}

# 下载源码
COPY software/php-7.4.33.tar.gz /build/php-7.4.33.tar.gz
COPY software/phpredis-6.1.0.tar.gz /build/phpredis-6.1.0.tar.gz
COPY software/openssl-1.1.1w.tar.gz /build/openssl-1.1.1w.tar.gz
COPY software/curl-7.87.0.tar.gz /build/curl-7.87.0.tar.gz
WORKDIR /build
RUN export $(cat /tmp/version.env); \
    wget https://github.com/nginx/nginx/releases/download/release-$NGINX_VERSION/nginx-$NGINX_VERSION.tar.gz && \
    wget https://www.php.net/distributions/php-$PHP_LATEST_VERSION.tar.gz && \
    wget https://mirrors.aliyun.com/mariadb/mariadb-$MARIADB_LATEST_VERSION/source/mariadb-$MARIADB_LATEST_VERSION.tar.gz && \
    wget https://github.com/openssl/openssl/releases/download/openssl-3.5.2/openssl-3.5.2.tar.gz && \
    tar -xzf nginx-$NGINX_VERSION.tar.gz && \
    tar -xzf php-$PHP_LATEST_VERSION.tar.gz && \
    tar -xzf php-7.4.33.tar.gz && \
    tar -xzf phpredis-6.1.0.tar.gz && \
    tar -xzf mariadb-$MARIADB_LATEST_VERSION.tar.gz && \
    tar -xzf openssl-1.1.1w.tar.gz && \
    tar -xzf curl-7.87.0.tar.gz && \
    tar -xzf openssl-3.5.2.tar.gz

# Nginx编译
WORKDIR /build
RUN export $(cat /tmp/version.env); \
    cd nginx-$NGINX_VERSION; \
    sed -i 's/#define NGINX_VERSION\s\+".*"/#define NGINX_VERSION      "'$NGINX_VERSION'"/g' ./src/core/nginx.h; \
    sed -i 's/"nginx\/" NGINX_VERSION/"nuoyis server"/g' ./src/core/nginx.h; \
    sed -i 's/Server: nginx/Server: nuoyis server/g' ./src/http/ngx_http_header_filter_module.c; \
    ./configure \
         --prefix=/web/nginx/server \
         --with-openssl=/build/openssl-3.5.2 \
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
         --with-ld-opt="-static"; \
    make -j$(nproc); \
    make install

# 复制 php Redis 源码
WORKDIR /build
RUN export $(cat /tmp/version.env); \
    cp -r phpredis-6.1.0/* php-$PHP_LATEST_VERSION/ext/php-redis && \
    cp -r phpredis-6.1.0/* php-7.4.33/ext/php-redis

# php stable 版本 openssl 编译
WORKDIR /build/openssl-1.1.1w
RUN export $(cat /tmp/version.env); \
    CONFIGURE_OPTS="--prefix=/web/openssl-1.1.1 --openssldir=/web/openssl-1.1.1 no-shared no-dso no-tests";\
    if [ "$TARGETARCH" = "arm64" ]; then \
        ./Configure linux-aarch64 $CONFIGURE_OPTS;\
    else \
        ./config $CONFIGURE_OPTS;\
    fi;\
    make -j$(nproc);\
    make install

# php stable 版本 curl 编译
WORKDIR /build/curl-7.87.0
RUN export $(cat /tmp/version.env); \
    ./configure --prefix=/web/curl-openssl --with-ssl=/web/openssl-1.1.1 --disable-shared --enable-static && make -j$(nproc) && make install

# php latest 版本 openssl 编译
WORKDIR /build/openssl-3.5.2
RUN export $(cat /tmp/version.env); \
    CONFIGURE_OPTS="--prefix=/web/openssl-3.5.2 --openssldir=/web/openssl-3.5.2 no-shared no-dso no-tests";\
    if [ "$TARGETARCH" = "arm64" ]; then \
        ./Configure linux-aarch64 $CONFIGURE_OPTS;\
    else \
        ./config $CONFIGURE_OPTS;\
    fi;\
    make -j$(nproc);\
    make install

# php 编译
RUN export $(cat /tmp/version.env); \
    for phpversion in 7.4.33 $PHP_LATEST_VERSION; do \
        if [ "$phpversion" == "7.4.33" ]; then \
            export CXXFLAGS="-std=c++17";\
            export buildtype=stable;\
            export CURL_PREFIX="/web/curl-openssl";\
            export OPENSSL_PREFIX_PATH="/web/openssl-1.1.1";\
            PHPCONFIG="--with-curl=${CURL_PREFIX} --with-openssl=${OPENSSL_PREFIX_PATH}";\
            export CPPFLAGS="-I${OPENSSL_PREFIX_PATH}/include -I${CURL_PREFIX}/include";\
            export PKG_CONFIG_PATH="${CURL_PREFIX}/lib/pkgconfig:${OPENSSL_PREFIX_PATH}/lib/pkgconfig:${PKG_CONFIG_PATH:-}";\
        else \
            unset CXXFLAGS CURL_PREFIX OPENSSL_PREFIX_PATH CPPFLAGS LDFLAGS PKG_CONFIG_PATH LD_LIBRARY_PATH;\
            export buildtype=latest;\
            export OPENSSL_PREFIX_PATH="/web/openssl-3.5.2";\
            PHPCONFIG="--with-curl --with-openssl=${OPENSSL_PREFIX_PATH}";\
        fi;\
        export LDFLAGS="-L${OPENSSL_PREFIX_PATH}/lib -L${CURL_PREFIX}/lib";\
        export LD_LIBRARY_PATH="${OPENSSL_PREFIX_PATH}/lib:${CURL_PREFIX}/lib:${LD_LIBRARY_PATH:-}";\
        cd /build/php-$phpversion;\
        ./configure --prefix=/web/php/$buildtype/ \
            --with-config-file-path=/web/php/$buildtype/etc/ \
            --with-freetype \
            --enable-gd \
            --with-jpeg \
            --with-gettext \
            --with-libdir=lib64 \
            --with-libxml \
            --with-mysqli \
            $PHPCONFIG \
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
            --enable-opcache \
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
            --enable-redis;\
        make -j$(nproc);\
        make install;\
    done;\
    mv /web/php/latest/etc/php-fpm.conf.default /web/php/latest/etc/php-fpm.conf &&\
    mv /web/php/stable/etc/php-fpm.conf.default /web/php/stable/etc/php-fpm.conf

# mariadb 编译
WORKDIR /build
RUN export $(cat /tmp/version.env); \
    cd mariadb-$MARIADB_LATEST_VERSION; \
    cmake . \
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
        -DDEFAULT_CHARSET=utf8mb4 \
        -DDEFAULT_COLLATION=utf8mb4_general_ci \
        -DMYSQL_USER=web \
        -DMYSQL_UNIX_ADDR=/run/mariadb/mariadb.sock && \
    make -j$(nproc) && make install && \
    strip /web/mariadb/bin/* /web/mariadb/lib/*.so* || true

# 配置文件添加
ADD config/nginx.conf.txt /web/nginx/server/conf/nginx.conf
ADD config/ssl/default.pem /web/nginx/server/conf/ssl/default.pem
ADD config/ssl/default.key /web/nginx/server/conf/ssl/default.key
ADD config/start-php-latest.conf.txt /web/nginx/server/conf/start-php-latest.conf
ADD config/path.conf.txt /web/nginx/server/conf/path.conf
ADD config/start-php-stable.conf.txt /web/nginx/server/conf/start-php-stable.conf
ADD config/head.conf.txt /web/nginx/server/conf/head.conf
ADD config/latest-php.ini.txt /web/php/latest/etc/php.ini
ADD config/fpm-latest.conf.txt /web/php/latest/etc/php-fpm.d/fpm.conf
ADD config/stable-php.ini.txt /web/php/stable/etc/php.ini
ADD config/fpm-stable.conf.txt /web/php/stable/etc/php-fpm.d/fpm.conf
ADD config/supervisord.conf.txt /web/supervisord/supervisord.conf
ADD config/index.html /web/nginx/server/template/index.html
ADD config/default.conf.txt /web/nginx/server/template/default.conf
ADD config/nginx.conf.full.template.txt /web/nginx/server/template/nginx.conf.full.template
ADD config/nginx.conf.succinct.template.txt /web/nginx/server/template/nginx.conf.succinct.template
ADD config/start.sh.txt /web/start.sh
ADD config/healthcheck.sh.txt /web/healthcheck.sh

# 防止windows字符造成无法读取
RUN find "/web" -type f -exec dos2unix {} \;

# so环境获取
RUN mkdir -p /runner-libs /otherlibs && \
    for bin in /web/php/latest/sbin/php-fpm /web/php/stable/sbin/php-fpm /web/mariadb/bin/mysqld; do \
        ldd $bin | grep "=> /" | awk '{print $3}' | sort -u | xargs -r -I{} cp --parents {} /runner-libs; \
    done && \
    cp /lib64/ld-linux-*.so.* /otherlibs || true

# 删除不需要的环境
RUN rm -rf /web/curl-openssl /web/openssl-1.1.1 /web/openssl-3.5.2

# 创建最终镜像
FROM docker.io/debian:13-slim AS runner

# 设置默认 shell
SHELL ["/bin/bash", "-c"]

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 复制 so依赖
COPY --from=builder /runner-libs /runner-libs
COPY --from=builder /otherlibs /lib64

# 复制 web文件夹
COPY --from=builder /web /web

# 环境变量
ENV PATH=/web/mariadb/bin:/web/nginx/server/sbin:$PATH

# # 必要的初始化
RUN if [ -d /runner-libs ]; then \
      find /runner-libs -type d | sort -u \
        > /etc/ld.so.conf.d/nuoyis-runner-libs.conf; \
      ldconfig; \
    fi;\
    useradd -u 2233 -m -s /sbin/nologin web;\
    mkdir -p /run/{mariadb,php/{stable,latest}};\
    chown -R web:web /web;\
    chown -R web:web /run;\
    chmod -R 775 /run;\
    chmod -R 775 /web;\
    chmod g+s /web;\
    chmod +x /web/start.sh;\
    chmod +x /web/healthcheck.sh;\
    mkdir /docker-entrypoint-initdb.d;\
    sed -i 's/http:\/\/deb.debian.org/https:\/\/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources;\
    apt -o Acquire::https::Verify-Peer=false -o Acquire::https::Verify-Host=false update -y;\
    apt -o Acquire::https::Verify-Peer=false -o Acquire::https::Verify-Host=false upgrade -y;\
    apt -o Acquire::https::Verify-Peer=false -o Acquire::https::Verify-Host=false install -y ca-certificates;\
    apt install -y supervisor curl libncurses6;\
    apt clean && rm -rf /var/cache/apt /var/lib/apt/lists/* /usr/share/doc /usr/share/man /usr/share/locale /usr/share/info && \
    ln -s /web/php/latest/sbin/php-fpm /usr/bin/php-latest && \
    ln -s /web/php/stable/sbin/php-fpm /usr/bin/php-stable

# 暴露端口
EXPOSE 80 443

# 设置容器的入口点
ENTRYPOINT ["/web/start.sh"]
CMD ["/usr/bin/supervisord", "-c", "/web/supervisord/supervisord.conf"]
