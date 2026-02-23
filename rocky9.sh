#!/bin/bash
# AUTO LEMP INSTALLER - Laravel Ready
# Created By Agus Prasetyo (Updated)

package_list="nginx mariadb-server mariadb \
php php-cli php-common php-opcache php-zip php-intl php-soap \
php-gd php-mbstring php-curl php-bcmath php-xml php-fpm php-mysqlnd \
postfix fail2ban cronie rsync cyrus-sasl-plain unzip git composer certbot python3-certbot-nginx"

service_list="nginx php-fpm mariadb postfix fail2ban crond"

RESET="\e[0m"
RED="\e[31m"
GREEN="\e[32m"
CYAN="\e[36m"

echo "What do you want to do?"
echo "   1) Install LEMP"
echo "   2) Add Domain (Laravel)"
echo "   3) Create Database"
echo "   4) Exit"
read -p "Select an option [1-4]: " option

case $option in

##################################################
# INSTALL LEMP
##################################################
1)

dnf -y install epel-release
dnf -y install https://rpms.remirepo.net/enterprise/remi-release-9.rpm
dnf module reset php -y
dnf module enable php:remi-8.3 -y
dnf -y update

echo -ne "Mysql root password: "
read -s mysqlroot_pass
echo ""

for package in ${package_list}
do
    dnf install -y ${package} &> /dev/null
done

for service in ${service_list}
do
    systemctl enable ${service}
done

systemctl start mariadb

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

# PHP tuning
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 512M/g' /etc/php.ini
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 50M/g' /etc/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 50M/g' /etc/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 120/g' /etc/php.ini

sed -i 's/user = apache/user = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/group = apache/group = nginx/g' /etc/php-fpm.d/www.conf

systemctl restart nginx
systemctl restart php-fpm

firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

# Disable SELinux
setenforce 0
sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

echo -e "${GREEN}LEMP Installed Successfully${RESET}"
;;

##################################################
# ADD DOMAIN (Laravel Ready)
##################################################
2)

read -p "Enter Domain (example.com): " DOMAIN
DOMAIN=$(echo $DOMAIN | tr '[:upper:]' '[:lower:]')

WEB_DIR="/home/$DOMAIN"
WWW_DIR="$WEB_DIR/www"
CONFIG="/etc/nginx/conf.d/$DOMAIN.conf"

mkdir -p $WWW_DIR/public
mkdir -p $WWW_DIR/storage
mkdir -p $WWW_DIR/bootstrap/cache

cat > $CONFIG <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    root $WWW_DIR/public;
    index index.php index.html;

    access_log /var/log/nginx/$DOMAIN.access.log;
    error_log  /var/log/nginx/$DOMAIN.error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

chown -R nginx:nginx $WEB_DIR
chmod -R 755 $WEB_DIR

systemctl restart nginx

echo -e "${GREEN}Domain Added Successfully${RESET}"
echo "Laravel root: $WWW_DIR"
;;

##################################################
# CREATE DATABASE
##################################################
3)

read -p "Database Name: " DBNAME
read -p "Database User: " DBUSER
read -p "Database Password: " DBPASS

mysql -u root <<EOF
CREATE DATABASE ${DBNAME};
GRANT ALL PRIVILEGES ON ${DBNAME}.* TO '${DBUSER}'@'localhost' IDENTIFIED BY '${DBPASS}';
FLUSH PRIVILEGES;
EOF

echo -e "${GREEN}Database Created${RESET}"
;;

4) exit ;;

esac
