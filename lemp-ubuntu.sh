#!/bin/bash
# Auto LEMP + vHost + SSL (Ubuntu 24.04 + PHP 7.4)
# Author: Agus Prasetyo; Modified for Ubuntu by ChatGPT

set -e

# Colors
GREEN="\e[32m"; RED="\e[31m"; CYAN="\e[36m"; RESET="\e[0m"

apt update && apt upgrade -y
apt install software-properties-common curl lsb-release ca-certificates gnupg2 -y
add-apt-repository ppa:ondrej/php -y
apt update

# Package list
package_list="nginx mariadb-server php7.4 php7.4-fpm php7.4-mysql php7.4-common php7.4-opcache php7.4-zip php7.4-intl php7.4-soap php7.4-gd php7.4-mbstring php7.4-curl php7.4-xml certbot python3-certbot-nginx fail2ban cron rsync"

service_list="nginx php7.4-fpm mariadb fail2ban cron"

echo -e "${CYAN}Pilih opsi:${RESET}"
echo "1) Install LEMP Stack"
echo "2) Buat Virtual Host (tanpa SSL)"
echo "3) Pasang SSL Let’s Encrypt (dari daftar domain)"
echo "4) Buat Database"
echo "5) Uninstall Domain"
echo "6) Exit"
read -p "Pilih [1-5]: " opt

case $opt in
1)
  read -s -p "Masukkan password MySQL root: " NEWPASSWD
  echo; read -s -p "Ulangi password: " CONFIRMPASSWD; echo

  if [[ -z "$NEWPASSWD" || "$NEWPASSWD" != "$CONFIRMPASSWD" ]]; then
    echo -e "${RED}Password kosong atau tidak cocok.${RESET}"; exit 1
  fi

  for pkg in $package_list; do
    printf "Install %-25s…" "$pkg"
    apt install -y $pkg &>/dev/null && echo -e " ${GREEN}OK${RESET}" || echo -e " ${RED}GAGAL${RESET}"
  done

  for svc in $service_list; do
    printf "Enable %-20s…" "$svc"
    systemctl enable --now $svc &>/dev/null && echo -e " ${GREEN}OK${RESET}" || echo -e " ${RED}GAGAL${RESET}"
  done

  mysql <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${NEWPASSWD}';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
SQL

  echo -e "[client]\nuser=root\npassword=\"${NEWPASSWD}\"" > /root/.my.cnf
  chmod 600 /root/.my.cnf

  sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/7.4/fpm/php.ini
  systemctl restart php7.4-fpm nginx mariadb

# Setup basic fail2ban jail for sshd
if [ ! -f /etc/fail2ban/jail.local ]; then
  cat > /etc/fail2ban/jail.local <<EOL
[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 5
bantime = 3600
EOL
  systemctl restart fail2ban
fi
  echo -e "${GREEN}LEMP berhasil di-install!${RESET}"
  ;;

2)
  read -p "Domain (contoh: myapp.com): " DOMAIN
  WEB_DIR="/var/www/${DOMAIN}"
  CONFIG="/etc/nginx/sites-available/${DOMAIN}.conf"
  mkdir -p "$WEB_DIR"

  cat > "$CONFIG" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    root ${WEB_DIR};

    index index.php index.html;
    access_log /var/log/nginx/${DOMAIN}.access.log;
    error_log  /var/log/nginx/${DOMAIN}.error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

  ln -s "$CONFIG" /etc/nginx/sites-enabled/
  echo "<?php phpinfo(); ?>" > "${WEB_DIR}/index.php"
  chown -R www-data:www-data "$WEB_DIR"
  chmod -R 755 "$WEB_DIR"

  nginx -t && systemctl reload nginx
  echo -e "${GREEN}vHost berhasil dibuat untuk ${DOMAIN}${RESET}"
  ;;

3)
  echo -e "${CYAN}Daftar domain dari /etc/nginx/sites-available:${RESET}"
  files=(/etc/nginx/sites-available/*.conf)
  domains=()

  i=1
  for file in "${files[@]}"; do
    domain=$(grep -i 'server_name' "$file" | head -1 | awk '{print $2}' | sed 's/;//')
    if [[ -n "$domain" ]]; then
      echo "$i) $domain"
      domains+=("$domain")
      ((i++))
    fi
  done

  if [ ${#domains[@]} -eq 0 ]; then
    echo -e "${RED}Tidak ada domain ditemukan.${RESET}"
    exit 1
  fi

  read -p "Pilih nomor domain untuk SSL: " pilih
  DOMAIN=${domains[$((pilih-1))]}

  read -p "Masukkan email untuk Let's Encrypt: " EMAIL
  certbot --nginx -d "$DOMAIN" -m "$EMAIL" --agree-tos --redirect --non-interactive
  systemctl reload nginx
  echo -e "${GREEN}SSL berhasil dipasang untuk $DOMAIN${RESET}"
  ;;

4)
  read -p "Nama DB: " DBNAME
  read -p "Username DB: " DBUSER
  read -s -p "Password DB: " DBPASS; echo

  if [[ ! -f /root/.my.cnf ]]; then
    echo -e "${RED}MySQL root password belum diset. Jalankan opsi 1 dulu.${RESET}"; exit 1
  fi

  mysql <<SQL
CREATE DATABASE IF NOT EXISTS ${DBNAME};
CREATE USER IF NOT EXISTS '${DBUSER}'@'localhost' IDENTIFIED BY '${DBPASS}';
GRANT ALL PRIVILEGES ON ${DBNAME}.* TO '${DBUSER}'@'localhost';
FLUSH PRIVILEGES;
SQL

  echo -e "${GREEN}Database & user sukses dibuat.${RESET}"
  ;;

5)
  echo -e "${CYAN}Daftar domain dari /etc/nginx/sites-available:${RESET}"
  files=(/etc/nginx/sites-available/*.conf)
  domains=()

  i=1
  for file in "${files[@]}"; do
    domain=$(basename "$file" .conf)
    echo "$i) $domain"
    domains+=("$domain")
    ((i++))
  done

  if [ ${#domains[@]} -eq 0 ]; then
    echo -e "${RED}Tidak ada domain ditemukan.${RESET}"
    exit 1
  fi

  read -p "Pilih nomor domain untuk uninstall: " pilih
  DOMAIN=${domains[$((pilih-1))]}

  read -p "Yakin ingin hapus domain $DOMAIN? (y/n): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    rm -f /etc/nginx/sites-enabled/$DOMAIN.conf
    rm -f /etc/nginx/sites-available/$DOMAIN.conf
    rm -rf /var/www/$DOMAIN
    certbot delete --cert-name $DOMAIN -n || true
    systemctl reload nginx
    echo -e "${GREEN}Domain $DOMAIN berhasil dihapus.${RESET}"
  else
    echo -e "${CYAN}Dibatalkan.${RESET}"
  fi
  ;;

6) exit ;;
*) echo -e "${RED}Opsi tidak valid.${RESET}" ;;
esac
