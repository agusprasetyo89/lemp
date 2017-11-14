#!/bin/bash
# NginxID.com command line installer NGINX for CentOS
yum clean all && yum -y update && yum -y upgrade
yum -y install epel-release
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm
rm -f /etc/yum.repos.d/remi.repo
wget https://raw.githubusercontent.com/pembodohan89/new/master/remi.sh -O /etc/yum.repos.d/remi.repo
echo "[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=0
enabled=1" >> /etc/yum.repos.d/nginx.repo
package_list="epel-release nginx mariadb-server mariadb php php-mysql php-common php-gd php-mbstring php-mcrypt php-devel php-xml php-fpm postfix denyhosts cronie rsync cyrus-sasl-plain"
service_list="nginx php-fpm mariadb postfix denyhosts crond"
#COLOR CODE TO USE WITH THE ECHO
RESET="\e[0m"
RED="\e[31m"
GREEN="\e[32m"
CYAN="\e[36m"
echo -e "${RED}INSTALLING LAMP PACKAGE${RESET}"
echo -e '```````````````````````'
for package in ${package_list}
do
printf '=> \e[36m%-023s\e[0m\e[30m%-015s\e[0m' "Installing ${package}"
if yum install -y ${package} &> /dev/null;then
echo -e "${GREEN} [ DONE ]${RESET}"
else
echo -e "${RED} [ FAILED ]${RESET}"
fi
done
# ADDING SERVICES INTO CHKCONFIG
echo ""
echo -e "${RED}ADDING SERVICES INTO CHECKCONFIG${RESET}"
echo '````````````````````````````````'
for service in ${service_list}
do
printf '=> \e[36m%-019s\e[0m\e[30m%-019s\e[0m' "Adding ${service}"
if systemctl enable ${service}.service &> /dev/null;then
echo -e "${GREEN} [ DONE ]${RESET}"
else
echo -e "${RED} [ FAILED ]${RESET}"
fi
done
#yum -y --enablerepo=remi install nginx mariadb-server mariadb php php-common php-fpm
#yum -y --enablerepo=remi install php-mysql php-pgsql php-pecl-memcache php-gd php-mbstring php-mcrypt php-xml php-pecl-apcu php-cli php-pear php-pdo
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
