#!/bin/bash

sudo -p "Please enter your password" whoami 1>/dev/null && {
    yum -y update
    yum install -y redhat-lsb-core
    if [[ $(lsb_release -rs) =~ ^8.* ]]; then
        yum install -y httpd firewalld policycoreutils-python-utils
    else
        yum install -y httpd firewalld policycoreutils-python
    fi
    systemctl enable firewalld
    systemctl start firewalld
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --permanent --add-service=http
    firewall-cmd --reload
    if [[ ! -d /var/www/drconopoima.com/html ]]; then
        mkdir -v -p /var/www/drconopoima.com/html
    fi
    if [[ ! -d /var/www/drconopoima.com/log ]]; then
        mkdir -v -p /var/www/drconopoima.com/log
    fi
    echo -e "\
<html>\n\
<head>\n\
    <title>Welcome to host ${1}!</title>\n\
</head>\n\
<body>\n\
    <h1>Hello from Apache running at host ${1}!</h1>\n\
</body>\n\
</html>" >/var/www/drconopoima.com/html/index.html
    if [[ ! -d /etc/httpd/sites-available ]]; then
        mkdir -p /etc/httpd/sites-available
    fi
    if [[ ! -d /etc/httpd/sites-enabled ]]; then
        mkdir -p /etc/httpd/sites-enabled
    fi
    grep -E "^[[:space:]]*IncludeOptional[[:space:]]*sites-enabled/\*\.conf" /etc/httpd/conf/httpd.conf || echo "IncludeOptional sites-enabled/*.conf" >>/etc/httpd/conf/httpd.conf
    echo -e "\
<VirtualHost *:80>\n\
    ServerName www.drconopoima.com\n\
    ServerAlias drconopoima.com\n\
    DocumentRoot /var/www/drconopoima.com/html\n\
    ErrorLog /var/www/drconopoima.com/log/error.log\n\
    CustomLog /var/www/drconopoima.com/log/requests.log combined\n\
</VirtualHost>" >/etc/httpd/sites-available/drconopoima.com.conf
    chown -v -R apache:apache /var/www/
    chmod -v -R 755 /var/www
    ln -v -s -T /etc/httpd/sites-available/drconopoima.com.conf /etc/httpd/sites-enabled/drconopoima.com.conf
    sed -i -e '/^[^#]/ s/^/#/' /etc/httpd/conf.d/welcome.conf
    ln -v -sf -T /var/www/drconopoima.com/html/index.html /var/www/html/index.html
    setsebool -P httpd_unified 1

    if [[ $(lsb_release -rs) =~ ^8.* ]]; then
        semanage fcontext -a -t httpd_sys_content_t "/var/www/drconopoima.com/log(/.*)?"
    else
        semanage fcontext -a -t httpd_log_t "/var/www/drconopoima.com/log(/.*)?"
    fi
    restorecon -R -v /var/www/drconopoima.com/log
    systemctl daemon-reload
    systemctl start httpd
    systemctl enable httpd
}
