#!/bin/bash
# THIS SCRIPT IS WRITTEN BY Agus Prasetyo
# Email : agus@jobindo.com

package_list="nginx mariadb-server mariadb php php-mysql php-common php-opcache php-zip php-intl php-soap php-gd php-xmlrpc php-mbstring php-curl php-mcrypt php-devel php-xml php-fpm postfix fail2ban cronie rsync cyrus-sasl-plain"
service_list="nginx php-fpm mariadb postfix fail2ban crond"

RESET="\e[0m"
RED="\e[31m"
GREEN="\e[32m"
CYAN="\e[36m"

echo -e "${RESET}"
echo "What do you want to do?"
echo "   1) Install LEMP"
echo "   2) Create NGINX CONFIG"
echo "   3) Create DATABASE"
echo "   4) Exit"
read -p "Select an option [1-4]: " option

case $option in
1)

dnf -y install epel-release
dnf -y install http://rpms.remirepo.net/enterprise/remi-release-9.5.rpm
dnf -y install dnf-utils
dnf module reset php -y
dnf module enable php:remi-8.3 -y
dnf clean all
dnf -y update

echo -e "${GREEN}"
echo "##################################################"
echo "############## AUTO LEMP INSTALLER ###############"
echo "################### Created By ###################"
echo "################# Agus Prasetyo ##################"
echo "##################################################"

echo -ne "Please type your Mysql password: "
read -s NEWPASSWD
echo ""
echo -ne "Please Re-type your new password: "
read -s CONFIRMPASSWD

if [ -z ${NEWPASSWD} ] && [ -z ${CONFIRMPASSWD} ];then
	echo -e "${RED}Sorry, null passwords.${RESET}"
	exit 1
else
	if [[ ${NEWPASSWD} == ${CONFIRMPASSWD} ]];then
		mysqlroot_pass=${CONFIRMPASSWD}

		echo -e "${RED}INSTALLING LEMP PACKAGE${RESET}"
		for package in ${package_list}
		do
			printf '=> \e[36mInstalling %-20s\e[0m' "${package}"
			if dnf install -y ${package} &> /dev/null;then
				echo -e "${GREEN} [ DONE ]${RESET}"
			else
				echo -e "${RED} [ FAILED ]${RESET}"
			fi
		done

		echo -e "${RED}ADDING SERVICES INTO CHECKCONFIG${RESET}"
		for service in ${service_list}
		do
			printf '=> \e[36mAdding %-20s\e[0m' "${service}"
			if systemctl enable ${service}.service &> /dev/null;then
				echo -e "${GREEN} [ DONE ]${RESET}"
			else
				echo -e "${RED} [ FAILED ]${RESET}"
			fi
		done

		systemctl start mariadb

		echo -e "${RED}INITIAL MYSQL-SERVER SETUP${RESET}"

		mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysqlroot_pass}';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOF

		echo "[client]
user=root
password=\"${mysqlroot_pass}\"" >> /root/.my.cnf

		chmod 600 /root/.my.cnf

	else
		echo -e "${RED}Sorry, passwords do not match.${RESET}"
	fi
fi

sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php.ini
sed -i 's/user = apache/user = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/group = apache/group = nginx/g' /etc/php-fpm.d/www.conf

systemctl start nginx.service
systemctl enable nginx.service
systemctl start mariadb
systemctl enable mariadb.service
systemctl start php-fpm
systemctl enable php-fpm.service

systemctl status nginx
systemctl status php-fpm
systemctl status mariadb

sed -i 's/enforcing/disabled/g' /etc/selinux/config /etc/selinux/config
sestatus
exit
;;

2)
wget https://raw.githubusercontent.com/pembodohan89/new/master/virtual_host.template
wget https://raw.githubusercontent.com/pembodohan89/new/master/index.html.template

NGINX_CONFIG='/etc/nginx/conf.d'
WEB_DIR='/home'
SED=`which sed`

echo -ne "Please type your domain name: "
read DOMAIN

PATTERN="^([[:alnum:]]([[:alnum:]\-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,6}$"
if [[ "$DOMAIN" =~ $PATTERN ]]; then
	DOMAIN=`echo $DOMAIN | tr '[A-Z]' '[a-z]'`
else
	echo "invalid domain name"
	exit 1
fi

SITE_DIR=`echo $DOMAIN | $SED 's/\./_/g'`
CONFIG=$NGINX_CONFIG/$DOMAIN.conf

cp /root/virtual_host.template $CONFIG
$SED -i "s/DOMAIN/$DOMAIN/g" $CONFIG
$SED -i "s!ROOT!$WEB_DIR/$SITE_DIR!g" $CONFIG

mkdir $WEB_DIR/$SITE_DIR
cp /root/index.html.template $WEB_DIR/$SITE_DIR/index.php
chown nginx:nginx -R $WEB_DIR/$SITE_DIR
chmod 600 $CONFIG
chmod -R 755 $WEB_DIR/$SITE_DIR

systemctl restart nginx
exit
;;

3)
echo "   1) Random SQL Pass"
echo "   2) Manual SQL Pass"
read option2

case $option2 in
1)
DBPASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
;;
2)
read -p "Database Password: " DBPASS
;;
esac

read -p "Database Name: " DBNAME
read -p "Database User: " DBUSER

if [ -f /root/.my.cnf ]; then
	mysql -u root <<EOF
CREATE DATABASE ${DBNAME};
GRANT ALL PRIVILEGES ON ${DBNAME}.* TO '${DBUSER}'@'localhost' IDENTIFIED BY '${DBPASS}';
FLUSH PRIVILEGES;
EOF
	echo "Database $DBNAME created for $DBUSER"
fi
exit
;;

4) exit ;;
esac
