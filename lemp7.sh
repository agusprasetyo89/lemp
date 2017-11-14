#!/bin/bash
# NginxID.com command line installer NGINX for CentOS
yum clean all && yum -y update && yum -y upgrade
rpm -Uvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm
echo "[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=0
enabled=1" >> /etc/yum.repos.d/nginx.repo
yum -y --enablerepo=remi,remi-php70 install nginx mariadb-server mariadb php php-common php-fpm
yum -y --enablerepo=remi,remi-php70 install php-mysql php-pgsql php-pecl-memcache php-gd php-mbstring php-mcrypt php-xml php-pecl-apcu php-cli php-pear php-pdo
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php.ini
sed -i 's/user = apache/user = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/group = apache/group = nginx/g' /etc/php-fpm.d/www.conf
systemctl start nginx.service
systemctl enable nginx.service
systemctl start mariadb
systemctl enable mariadb.service
systemctl start php-fpm
systemctl enable php-fpm.service
mysql_secure_installation
systemctl restart mariadb
systemctl status nginx
systemctl status php-fpm
systemctl status mariadb
exit
