#!/bin/bash
# NginxID.com command line installer NGINX for CentOS
#yum clean all && yum -y update && yum -y upgrade
yum -y install epel-release
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm
rm -f /etc/yum.repos.d/remi.repo
wget https://raw.githubusercontent.com/pembodohan89/new/master/remi.sh -O /etc/yum.repos.d/remi.repo
echo "[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=0
enabled=1" >> /etc/yum.repos.d/nginx.repo
package_list="nginx mariadb-server mariadb php php-mysql php-common php-gd php-mbstring php-mcrypt php-devel php-xml php-fpm postfix denyhosts cronie rsync cyrus-sasl-plain"
service_list="nginx php-fpm mariadb postfix denyhosts crond"
#COLOR CODE TO USE WITH THE ECHO
RESET="\e[0m"
RED="\e[31m"
GREEN="\e[32m"
CYAN="\e[36m"
echo -e "${GREEN}"
echo "##################################################"
echo "############## AUTO LEMP INSTALLER ###############"
echo "################### Created By ###################"
echo "################# Agus Prasetyo ##################"
echo "##################################################"
# READING THE PASSWORD
echo -ne "Please type your Mysql password: "
read -s NEWPASSWD
echo ""
echo -ne "Please Re-type your new password: "
read -s CONFIRMPASSWD
# CHECKING FOR NULL PASSWORD
if [ -z ${NEWPASSWD} ] && [ -z ${CONFIRMPASSWD} ];then
echo ""
echo -e "${RED}Sorry, null passwords.${RESET}"
exit 1
else
# CHECKING THE PASSWORD ARE SAME
if [[ ${NEWPASSWD} == ${CONFIRMPASSWD} ]];then
# IF EVRYTHING WORK mysqlroot_pass VARIABLE CONTAIN THE PASSWORD FOR MySQL
mysqlroot_pass=${CONFIRMPASSWD}
echo ""
# INSTALLING ALL THE LEMP PACKAGE
echo -e "${RED}INSTALLING LEMP PACKAGE${RESET}"
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
# INITIAL MYSQL SETUP
echo ""
echo -e "${RED}INITIAL MYSQL-SERVER SETUP${RESET}"
echo '``````````````````````````'
#RESTING ROOT PASSWORD
printf '=> \e[36m%-038s\e[0m' "Resetting Root Password"
if mysql -u root -e "update mysql.user set Password=PASSWORD('${mysqlroot_pass}') WHERE User='root';" &> /dev/null;then
echo -e "${GREEN} [ DONE ]${RESET}"
else
echo -e "${RED} [ FAILED ]${RESET}"
fi
#RESTARTING THE MYSQL TO AVOID ANY ANY ISSUE
systemctl restart mariadb &> /dev/null
#DELETING ANONYMOUS USERS
printf '=> \e[36m%-038s\e[0m' "Deleting Anonymous Users"
if mysql -u root -p${mysqlroot_pass} -e "DELETE FROM mysql.user WHERE User=''" &> /dev/null;then
echo -e "${GREEN} [ DONE ]${RESET}"
else
echo -e "${RED} [ FAILED ]${RESET}"
fi
#DELETING TEST DATABASE
printf '=> \e[36m%-038s\e[0m' "Deleting test DataBase"
if mysql -u root -p${mysqlroot_pass} -e "DROP DATABASE test" &> /dev/null;then
echo -e "${GREEN} [ DONE ]${RESET}"
else
echo -e "${RED} [ FAILED ]${RESET}"
fi
#RELOADING DATABASE
printf '=> \e[36m%-038s\e[0m' "Reloading Privileges"
if mysql -u root -p${mysqlroot_pass} -e "FLUSH PRIVILEGES" &> /dev/null;then
echo -e "${GREEN} [ DONE ]${RESET}"
else
echo -e "${RED} [ FAILED ]${RESET}"
fi
echo "[client]
user=root
password="\"${mysqlroot_pass}"\"" >> .my.cnf
else
echo ""
echo -e "${RED}Sorry, passwords do not match.${RESET}"
fi
fi
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
