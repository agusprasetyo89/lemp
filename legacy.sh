#!/bin/bash
# PHP 5.6 Docker + Nginx Installer (STABLE VERSION)
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

# =================================================
# INSTALL DOCKER ENGINE (RESMI)
# =================================================
if ! systemctl list-unit-files | grep -q docker.service; then
    echo "[+] Installing Docker Engine..."

    dnf remove -y docker docker-client docker-common docker-latest docker-engine >/dev/null 2>&1 || true

    dnf install -y dnf-plugins-core
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    systemctl enable --now docker
else
    echo "[✓] Docker Engine already installed"
fi

# =================================================
# PREPARE DIRECTORIES
# =================================================
echo "[+] Preparing directories..."
mkdir -p "${PHP56_DIR}" "${WEB_ROOT}" "${SOCKET_DIR}"

# =================================================
# DOCKER COMPOSE (PHP 5.6 LEGACY IMAGE)
# =================================================
echo "[+] Creating docker-compose.yml..."
cat > "${PHP56_DIR}/docker-compose.yml" <<EOF
services:
  php56:
    image: webdevops/php:5.6
    container_name: php56-${DOMAIN}
    restart: always
    volumes:
      - ${WEB_ROOT}:/app
      - ${SOCKET_DIR}:${SOCKET_DIR}
    environment:
      PHP_FPM_LISTEN: ${SOCKET_FILE}
      PHP_MEMORY_LIMIT: 256M
      PHP_UPLOAD_MAX_FILESIZE: 64M
      PHP_POST_MAX_SIZE: 64M
      PHP_DATE_TIMEZONE: Asia/Jakarta
EOF

# =================================================
# START CONTAINER
# =================================================
echo "[+] Starting PHP 5.6 container..."
cd "${PHP56_DIR}"
docker compose up -d

# =================================================
# PERMISSION
# =================================================
chown -R nginx:nginx "${WEB_ROOT}"
chmod -R 755 "${WEB_ROOT}"

# =================================================
# INDEX.PHP DEFAULT
# =================================================
if [ ! -f "${WEB_ROOT}/index.php" ]; then
    echo "[+] Creating index.php..."
    cat > "${WEB_ROOT}/index.php" <<'EOF'
<?php
$ip = $_SERVER['REMOTE_ADDR'] ?? 'UNKNOWN';
echo "Selamat datang, IP anda adalah " . htmlspecialchars($ip);
?>
EOF
fi

# =================================================
# NGINX CONFIG
# =================================================
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

# =================================================
# TEST & RELOAD NGINX
# =================================================
nginx -t
systemctl reload nginx

echo ""
echo "========================================="
echo " PHP 5.6 LEGACY SETUP SELESAI & AMAN"
echo " Domain   : ${DOMAIN}"
echo " Web Root : ${WEB_ROOT}"
echo " FastCGI  : unix:${SOCKET_FILE}"
echo " AutoRun  : ENABLED (after reboot)"
echo "========================================="
