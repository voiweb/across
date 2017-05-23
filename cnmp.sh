#!env bash
installCNMP(){
    if [[ -e /etc/redhat-release ]]; then
        RELEASE_RPM=$(rpm -qf /etc/centos-release)
        RELEASE=$(rpm -q --qf '%{VERSION}' ${RELEASE_RPM})
        if [ ${RELEASE} != "7" ]; then
            echo "Not CentOS release 7."
            exit 1
        fi
    else
        echo "Not CentOS system."
        exit 1
    fi

    echo Installing delta-rpm...
    yum install -y deltarpm > /dev/null
    if [ $? != 0 ]; then exit 1; fi

    echo Installing epel repositories...
    yum -y install epel-release > /dev/null
    if [ $? != 0 ]; then exit 1; fi
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7 > /dev/null

    echo Installing ius repositories...
    curl -sS https://setup.ius.io/ | bash > /dev/null
    if [ $? != 0 ]; then exit 1; fi
    rpm --import /etc/pki/rpm-gpg/IUS-COMMUNITY-GPG-KEY > /dev/null

    echo Installing MariaDB official repositories...
    cat > /etc/yum.repos.d/MariaDB.repo <<EOF
[mariadb]
name=MariaDB
baseurl=http://mirrors.aliyun.com/mariadb/yum/10.1/centos/7/\$basearch/
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

    echo Installing Nginx official repositories...
    cat > /etc/yum.repos.d/nginx.repo <<EOF
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/mainline/centos/7/\$basearch/
gpgcheck=0
enabled=1
EOF

    echo Installing packages...
    yum install -y nginx mariadb-server php70u-fpm php70u-cli php70u-bcmatch php70u-gd php70u-json php70u-mbstring php70u-mcrypt php70u-mysqlnd php70u-opcache php70u-pdo php70u-xml
    if [ $? != 0 ]; then exit 1; fi

    echo Creating /data...
    mkdir /data
    cd /data
    mkdir -p nginx/conf.d
    cat > /data/nginx/default.conf <<EOF
user  nginx;
worker_processes  4;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  off;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    client_max_body_size 16m;
    client_body_buffer_size 1024k;

    server_names_hash_bucket_size 128;

    gzip  on;
    gzip_min_length 1k;

    fastcgi_intercept_errors on;

    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 10m;

    server_tokens off;

    server {
        listen       80 default;
        server_name  _;

        location / {
            root   /data/web/default;
            index  index.html index.htm;
            location ~ ^/.+\.php {
                fastcgi_param  SCRIPT_FILENAME    \$document_root\$fastcgi_script_name;
                fastcgi_index  index.php;
                fastcgi_split_path_info ^(.+\.php)(/?.+)\$;
                fastcgi_param PATH_INFO \$fastcgi_path_info;
                fastcgi_param PATH_TRANSLATED \$document_root\$fastcgi_path_info;
                include        fastcgi_params;
                fastcgi_pass   127.0.0.1:9000;
            }
        }
    }

    include /data/nginx/conf.d/*.conf;
}
EOF
    rm -f /etc/nginx/nginx.conf
    ln -s /data/nginx/default.conf /etc/nginx/nginx.conf
    mkdir -p /data/web/default
    curl -sS https://mirrors.loacg.com/system/linux/centos/nginx/index.htm > /data/web/default/index.htm
    if [ $? != 0 ]; then exit 1; fi
    if [ ! -d /data/mysql ]; then
        mv /var/lib/mysql /data/
        ln -s /data/mysql /var/lib/mysql
    fi

    echo Enabling services...
    systemctl enable nginx > /dev/null
    if [ $? != 0 ]; then exit 1; fi
    systemctl enable mariadb > /dev/null
    if [ $? != 0 ]; then exit 1; fi
    systemctl enable php-fpm > /dev/null
    if [ $? != 0 ]; then exit 1; fi

    echo Starting services...
    systemctl start nginx
    if [ $? != 0 ]; then exit 1; fi
    systemctl start mariadb
    if [ $? != 0 ]; then exit 1; fi
    systemctl start php-fpm
    if [ $? != 0 ]; then exit 1; fi
    echo Done~
}
#installCNMP