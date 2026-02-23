#!/bin/bash
# AUTO LEMP INSTALLER - Laravel 12 Ready
# Created By Agus Prasetyo (Modified)

package_list="nginx mariadb-server mariadb \
php php-cli php-common php-opcache php-zip php-intl php-soap \
php-gd php-mbstring php-curl php-bcmath php-xml php-fpm php-mysqlnd \
postfix fail2ban cronie rsync cyrus-sasl-plain unzip git composer"

service_list="nginx php-fpm mariadb postfix fail2ban crond"

RESET="\e[0m"
RED="\e[31m"
GREEN="\e[32m"
CYAN="\e[36m"

echo "What do you want to do?"
echo "   1) Install LEMP"
echo "   2) Exit"
read -p "Select an option [1-2]: " option

case $option in
1)

dnf -y install epel-release
dnf -y install https://rpms.remirepo.net/enterprise/remi-release-9.rpm
dnf module reset php -y
dnf module enable php:remi-8.3 -y
dnf -y update

echo -ne "Please type your Mysql root password: "
read -s NEWPASSWD
echo ""
echo -ne "Please Re-type your password: "
read -s CONFIRMPASSWD
echo ""

if [[ -z ${NEWPASSWD} || -z ${CONFIRMPASSWD} ]]; then
    echo -e "${RED}Password cannot be empty.${RESET}"
    exit 1
fi

if [[ ${NEWPASSWD} != ${CONFIRMPASSWD} ]]; then
    echo -e "${RED}Passwords do not match.${RESET}"
    exit 1
fi

mysqlroot_pass=${CONFIRMPASSWD}

echo -e "${CYAN}Installing Packages...${RESET}"
for package in ${package_list}
do
    printf '=> Installing %-20s' "${package}"
    if dnf install -y ${package} &> /dev/null; then
        echo -e "${GREEN} [DONE]${RESET}"
    else
        echo -e "${RED} [FAILED]${RESET}"
    fi
done

echo -e "${CYAN}Enabling Services...${RESET}"
for service in ${service_list}
do
    systemctl enable ${service} &> /dev/null
done

systemctl start mariadb

echo -e "${CYAN}Securing MariaDB...${RESET}"
mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysqlroot_pass}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host!='localhost';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOF

echo "[client]
user=root
password=\"${mysqlroot_pass}\"" > /root/.my.cnf
chmod 600 /root/.my.cnf

echo -e "${CYAN}Optimizing PHP...${RESET}"
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 512M/g' /etc/php.ini
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 50M/g' /etc/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 50M/g' /etc/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 120/g' /etc/php.ini

sed -i 's/user = apache/user = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/group = apache/group = nginx/g' /etc/php-fpm.d/www.conf

systemctl start nginx
systemctl start php-fpm
systemctl start postfix
systemctl start fail2ban
systemctl start crond

firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

echo -e "${RED}Disabling SELinux (as requested)...${RESET}"
setenforce 0
sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

echo -e "${GREEN}LEMP + PHP 8.3 Installation Completed!${RESET}"
;;

2)
exit
;;

esac
