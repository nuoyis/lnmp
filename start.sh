#!/bin/bash
# 诺依阁<wkkjonlykang@vip.qq.com>
# 编写日期: 2025-03-31

echo "Welcome use nuoyis's lnmp service"

# nginx/php 类启动检查
# 默认HTML
DEFAULTFILE=/nuoyis-web/nginx/webside/default/index.html

if [ ! -f "$DEFAULTFILE" ]; then
echo "default page is not found. then create new default page of html"
mkdir -p /nuoyis-web/nginx/webside/default/
touch $DEFAULTFILE
cat > $DEFAULTFILE << EOF
welcome to nuoyis's server
EOF
else
echo "default page is found. then use default page of html"
fi

mkdir -p /nuoyis-web/logs/nginx/
touch /nuoyis-web/logs/nginx/error.log

# mariadb 类启动检查
chown -R nuoyis-web:nuoyis-web /nuoyis-web
chown -R nuoyis-web:nuoyis-web /run
chmod -R 775 /run
chmod -R 775 /nuoyis-web
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)}"
LOCK_DIR=/docker-entrypoint-initdb.d/lockfiles
INIT_LOCK=$LOCK_DIR/.init.lock
IMPORT_LOCK=$LOCK_DIR/.import.lock
DEFAULTCNF=/nuoyis-web/mariadb/config/my.cnf

if [ ! -f "$DEFAULTCNF" ]; then
    cat > $DEFAULTCNF << EOF
[mysqld]
server-id=1
log_bin=mysql-bin
max_binlog_size=512M
expire_logs_days=7
binlog_format=ROW
slave_skip_errors=1062
socket=/run/mariadb/mariadb.sock
datadir=/nuoyis-web/mariadb/data
log_error = /nuoyis-web/mariadb/logs/mariadb-error.log
general_log_file = /nuoyis-web/mariadb/logs/general.log
slow_query_log_file = /nuoyis-web/mariadb/logs/slow.log
general_log = 1
slow_query_log = 1
long_query_time = 1

[client]
socket=/run/mariadb/mariadb.sock
EOF
fi
mkdir -p "$LOCK_DIR"
if [ ! -f "$INIT_LOCK" ]; then
  echo "init database..."
  /nuoyis-web/mariadb/scripts/mariadb-install-db --datadir=/nuoyis-web/mariadb/data --user=nuoyis-web
  /nuoyis-web/mariadb/bin/mariadbd --defaults-file=$DEFAULTCNF --user=nuoyis-web &
  mariadb_pid=$!
  until mariadb -u root -e "SELECT 1;" &>/dev/null; do
        echo "Waiting for MariaDB to be ready..."
        sleep 1
  done
  mariadb -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"
  echo "Mysql local root Password is： $MYSQL_ROOT_PASSWORD"
  touch "$INIT_LOCK"
else
  echo "Detected initialization lock, skipping database initialization."
fi

if [ ! -f "$IMPORT_LOCK" ]; then
    echo "import data..."
    for f in /docker-entrypoint-initdb.d/*.sql; do
        if [ -f "$f" ]; then
            echo "Importing $f"
            mariadb -u root -p$MYSQL_ROOT_PASSWORD  < "$f"
        fi
    done
  touch "$IMPORT_LOCK"
else
  echo "Detected import lock, skipping data import."
fi

if [ -n "$mariadb_pid" ]; then
    kill -9 "$mariadb_pid"
fi

echo "database checkd"

echo "nuoyis service is starting"
exec "$@"
