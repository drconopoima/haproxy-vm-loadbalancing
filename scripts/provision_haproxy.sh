#!/bin/bash
. /etc/profile

sudo -p "Please enter your password" whoami 1>/dev/null && {
    yum -y update
    yum install -y redhat-lsb-core
    if [[ $(lsb_release -rs) =~ ^8.* ]]; then
        yum config-manager --set-enabled powertools # for lua
    fi
    yum install -y epel-release # for jq
    if [[ $(lsb_release -rs) =~ ^8.* ]]; then
        yum install -y jq openssl openssl-devel readline readline-devel systemd-devel lua lua-devel gcc pcre-devel tar make firewalld policycoreutils-python-utils
    else
        yum install -y jq openssl openssl-devel readline readline-devel systemd-devel gcc pcre-devel tar make firewalld policycoreutils-python
    fi
    systemctl enable firewalld
    systemctl start firewalld
}
sudo -p "Please enter your password" whoami 1>/dev/null && {
    HAPROXY_LATEST_VERSION=$(curl -s https://api.github.com/repos/haproxy/haproxy/tags | jq '.[].name' | grep -v -- '-de' | head -n 1 | tr -d '"' | tr -d 'v')
    HAPROXY_SHORT_VERSION=$(echo -n "${HAPROXY_LATEST_VERSION}" | awk -F "." '{ print $1"."$2 }')
    curl -s -o "/tmp/haproxy-${HAPROXY_LATEST_VERSION}.tar.gz" "https://www.haproxy.org/download/${HAPROXY_SHORT_VERSION}/src/haproxy-${HAPROXY_LATEST_VERSION}.tar.gz"
    sync
    tar xzvf "/tmp/haproxy-${HAPROXY_LATEST_VERSION}.tar.gz" -C "/tmp"
    sync
    cd "/tmp/haproxy-${HAPROXY_LATEST_VERSION}" || exit
    if [[ $(lsb_release -rs) =~ ^8.* ]]; then
        make USE_NS=1 \
            USE_TFO=1 \
            USE_OPENSSL=1 \
            USE_ZLIB=1 \
            USE_LUA=1 \
            USE_PCRE=1 \
            USE_SYSTEMD=1 \
            USE_LIBCRYPT=1 \
            USE_THREAD=1 \
            TARGET=linux-glibc
    else # required LUA > 5.3 not available in earlier versions
        make USE_NS=1 \
            USE_TFO=1 \
            USE_OPENSSL=1 \
            USE_ZLIB=1 \
            USE_PCRE=1 \
            USE_SYSTEMD=1 \
            USE_LIBCRYPT=1 \
            USE_THREAD=1 \
            TARGET=linux-glibc
    fi
    make install
    useradd -r haproxy
    mkdir -v -p /etc/haproxy
    mkdir -v -p /var/lib/haproxy/log
    sync
    touch /var/lib/haproxy/stats
    ln -v -s /usr/local/sbin/haproxy /usr/sbin/haproxy
    chown -v -R haproxy:haproxy /var/lib/haproxy
    cp "/tmp/haproxy-${HAPROXY_LATEST_VERSION}/examples/haproxy.init" "/etc/init.d/haproxy"
    sync
    chmod -v 755 /etc/init.d/haproxy
    cat <<-EOF >/etc/haproxy/haproxy.cfg
global
    maxconn  20000
    log      /log/haproxy.log local2
    user     haproxy
    chroot   /var/lib/haproxy
    pidfile  /run/haproxy.pid
    daemon

    stats socket /run/haproxy.sock mode 666
    stats timeout 60s

frontend main
    bind :80
    mode               http
    log                global
    option             httplog
    option             dontlognull
    option             http_proxy
    option forwardfor  except 127.0.0.0/8
    timeout            client  30s
    default_backend    app

frontend stats
    bind     *:8404
    mode     http
    stats    enable
    stats    uri /stats
    stats    refresh 10s
    timeout  client  30s

backend app
    mode        http
    balance     roundrobin
    timeout     connect 5s
    timeout     server  30s
    timeout     queue   30s
    server  web1 172.29.1.101:80 check
    server  web2 172.29.1.102:80 check
    server  web3 172.29.1.103:80 check
EOF
    cat <<-EOF >/etc/rsyslog.d/99-haproxy.conf
$AddUnixListenSocket /var/lib/haproxy/log/haproxy.log

:programname, startswith, "haproxy" {
  /var/log/haproxy/haproxy.log
  stop
}
EOF
    cat <<-EOF >/etc/logrotate.d/haproxy
/var/log/haproxy/haproxy.log {
    missingok
    copytruncate
    notifempty
    rotate 50
    size 25M
    compress
    delaycompress
    postrotate
	    /bin/kill -HUP $(cat /var/run/rsyslogd.pid 2>/dev/null) 2> /dev/null || true
    endscript
}
EOF
    sync
    chmod 644 /etc/rsyslog.d/99-haproxy.conf
    semanage fcontext -a -t syslog_conf_t "/etc/rsyslog.d/99-haproxy.conf"
    semanage fcontext -a -t etc_t "/etc/logrotate.d/haproxy"
    chmod 666 /etc/haproxy/haproxy.cfg
    systemctl daemon-reload
    systemctl restart rsyslog
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --permanent --zone=public --add-service=http
    firewall-cmd --permanent --zone=public --add-port=8404/tcp
    firewall-cmd --reload
    chkconfig haproxy on
    systemctl start haproxy
    systemctl enable haproxy
}
