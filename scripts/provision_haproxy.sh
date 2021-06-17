#!/bin/bash
. /etc/profile

sudo -p "Please enter your password" whoami 1>/dev/null && {
    yum -y update
    yum install epel-release -y
    yum install -y jq gcc pcre-devel tar make firewalld
    systemctl enable firewalld
    systemctl start firewalld
    HAPROXY_LATEST_VERSION=$(curl -s https://api.github.com/repos/haproxy/haproxy/tags | jq '.[].name' | grep -v -- '-de' | head -n 1 | tr -d '"' | tr -d 'v')
    HAPROXY_SHORT_VERSION=$(echo -n "${HAPROXY_LATEST_VERSION}" | awk -F "." '{ print $1"."$2 }')
    curl -s -o "/tmp/haproxy-${HAPROXY_LATEST_VERSION}.tar.gz" "https://www.haproxy.org/download/${HAPROXY_SHORT_VERSION}/src/haproxy-${HAPROXY_LATEST_VERSION}.tar.gz"
    tar xzvf "/tmp/haproxy-${HAPROXY_LATEST_VERSION}.tar.gz" -C "/tmp"
    cd "/tmp/haproxy-${HAPROXY_LATEST_VERSION}" || exit
    make TARGET=linux-glibc
    make install
    mkdir -v -p /etc/haproxy
    mkdir -v -p /var/lib/haproxy
    mkdir -v -p /usr/share/haproxy
    touch /var/lib/haproxy/stats
    ln -s /usr/local/sbin/haproxy /usr/sbin/haproxy
    cp "/tmp/haproxy-${HAPROXY_LATEST_VERSION}/examples/haproxy.init" "/etc/init.d/haproxy"
    chmod -v 755 /etc/init.d/haproxy
    useradd -r haproxy
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --permanent --zone=public --add-service=http
    firewall-cmd --reload
    cat <<-EOF >/etc/haproxy/haproxy.cfg
global
    maxconn  20000
    log      127.0.0.1 local0
    user     haproxy
    chroot   /usr/share/haproxy
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
    chmod 666 /etc/haproxy/haproxy.cfg
    systemctl daemon-reload
    chkconfig haproxy on
    systemctl start haproxy
    systemctl enable haproxy
}
