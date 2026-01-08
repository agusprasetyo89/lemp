#!/bin/bash
# PHP 5.6 Docker + Nginx Interactive Installer
# Author : Agus Prasetyo
# Target : AlmaLinux 9 + LEMP existing

set -e

echo "========================================="
echo " PHP 5.6 (Docker) + Nginx Installer"
echo "========================================="
echo ""

read -p "Masukkan DOMAIN (contoh: legacy.domain.com): " DOMAIN
read -p "Masukkan WEB ROOT (contoh: /home/domain/www): " WEB_ROOT

if [[ -z "$DOMAIN" || -z "$WEB_ROOT" ]]; then
    echo "[ERROR] Domain dan Web Root tidak boleh kosong"
    exit 1
fi

PHP56_DIR="/opt/php56-${DOMAIN}"
SOCKET_DIR="/run/php"
SOCKET_FILE="${SOCKET_DIR}/php56-${DOMAIN}.sock"
NGINX_CONF="/etc/nginx/conf.d/${DOMAIN}.conf"

echo ""
echo "[INFO] Domain   : ${DOMAIN}"
echo "[INFO] Web Root : ${WEB_ROOT}"
echo ""

# ================= DOCKER =================
if ! command -v docker &>/dev/null; then
    echo "[+] Installing Docker..."
    dnf install -y docker
    systemctl enable --now docker
else
    echo "[✓] Docker already installed"
fi

# docker-compose fallback
if ! command -v docker-compose &>/dev/null; then
    echo "[+] Installing docker-compose (legacy)..."
    dnf install -y docker-compose
else
    echo "[✓] docker-compose available"
fi

# ================= DIR =================
echo "[+] Preparing directories..."
mkdir -p "${PHP56_DIR}" "${WEB_ROOT}" "${SOCKET_DIR}"

# ================= PHP.INI =================
echo "[+] Creating php.ini..."
cat > "${PHP56_DIR}/php.ini" <<'EOF'
cgi.fix_pathinfo=0

extension=mysqli
extension=pdo_mysql
extension=mbstring
extension=soap
extension=zip
extension=intl
extension=xmlrpc
extension=gd
extension=curl
extension=opcache

memory_limit=256M
upload_max_filesize=64M
post_max_size=64M
max_execution_time=60
date.timezone=Asia/Jakarta

disable_functions=exec,passthru,shell_exec,system,proc_open,popen
EOF

# ================= DOCKER COMPOSE =================
echo "[+] Creating docker-compose.yml..."
cat > "${PHP56_DIR}/docker-compose.yml" <<EOF
version: "3"

services:
  php56:
    image: php:5.6-fpm
    container_name: php56-${DOMAIN}
    restart: always
    volumes:
      - ${WEB_ROOT}:/var/www/html
      - ${PHP56_DIR}/php.ini:/usr/local/etc/php/php.ini
      - ${SOCKET_DIR}:${SOCKET_DIR}
    command: php-fpm -R
EOF

# ================= START CONTAINER =================
echo "[+] Starting PHP 5.6 container..."
cd "${PHP56_DIR}"
docker-compose up -d

# ================= PERMISSION =================
chown -R nginx:nginx "${WEB_ROOT}"
chmod -R 755 "${WEB_ROOT}"

# ================= INDEX.PHP =================
if [ ! -f "${WEB_ROOT}/index.php" ]; then
    echo "[+] Creating index.php..."
    cat > "${WEB_ROOT}/index.php" <<'EOF'
<?php
$ip = $_SERVER['REMOTE_ADDR'] ?? 'UNKNOWN';
echo "Selamat datang, IP anda adalah " . $ip;
?>
EOF
fi

# ================= NGINX CONFIG =================
echo "[+] Creating Nginx config..."
cat > "${NGINX_CONF}" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    root ${WEB_ROOT};
    index index.php index.html;

    access_log /var/log/nginx/${DOMAIN}.access.log;
    error_log  /var/log/nginx/${DOMAIN}.error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:${SOCKET_FILE};
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# ================= RELOAD NGINX =================
nginx -t
systemctl reload nginx

echo ""
echo "========================================="
echo " PHP 5.6 + Nginx SELESAI"
echo " Domain   : ${DOMAIN}"
echo " Web Root : ${WEB_ROOT}"
echo " FastCGI  : unix:${SOCKET_FILE}"
echo "========================================="
