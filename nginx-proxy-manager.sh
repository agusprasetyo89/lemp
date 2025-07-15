#!/bin/bash
# NGINX Proxy Manager for Proxmox Host
# Author: Agus Prasetyo (with ChatGPT assistant)

set -e

# Colors
GREEN="\e[32m"; RED="\e[31m"; CYAN="\e[36m"; RESET="\e[0m"

NGINX_CONF_PATH="/etc/nginx/sites-available"
NGINX_ENABLED_PATH="/etc/nginx/sites-enabled"

function install_nginx() {
    echo -e "${CYAN}Installing NGINX and Certbot...${RESET}"
    apt update
    apt install nginx certbot python3-certbot-nginx ufw -y

    echo -e "${GREEN}Opening firewall ports 80 and 443...${RESET}"
    ufw allow 80
    ufw allow 443
    ufw reload || true

    systemctl enable nginx
    systemctl start nginx
}

function create_proxy() {
    read -p "Domain name (e.g., app.domain.com): " DOMAIN
    read -p "Internal IP target (e.g., 192.168.19.101): " TARGET_IP
    read -p "Enable SSL via Let’s Encrypt? [y/n]: " SSL_ENABLE

    WEBROOT="/var/www/${DOMAIN}"
    CONFIG="${NGINX_CONF_PATH}/${DOMAIN}.conf"
    mkdir -p "$WEBROOT"
    echo "<h1>Reverse Proxy for $DOMAIN</h1>" > "$WEBROOT/index.html"

    cat > "$CONFIG" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://${TARGET_IP};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    ln -sf "$CONFIG" "${NGINX_ENABLED_PATH}/${DOMAIN}.conf"
    nginx -t && systemctl reload nginx

    if [[ "$SSL_ENABLE" =~ ^[Yy]$ ]]; then
        read -p "Enter email for Let's Encrypt: " EMAIL
        certbot --nginx -d "$DOMAIN" -m "$EMAIL" --agree-tos --redirect --non-interactive
        systemctl reload nginx
        echo -e "${GREEN}SSL enabled for $DOMAIN${RESET}"
    else
        echo -e "${CYAN}Proxy created without SSL for $DOMAIN${RESET}"
    fi
}

function list_proxies() {
    echo -e "\n${CYAN}List of proxied domains:${RESET}"
    files=(${NGINX_CONF_PATH}/*.conf)
    domains=()
    i=1
    for file in "${files[@]}"; do
        domain=$(grep -i 'server_name' "$file" | head -1 | awk '{print $2}' | sed 's/;//')
        target=$(grep -i 'proxy_pass' "$file" | head -1 | awk '{print $2}' | sed 's/;//')
        printf "%2d. %-25s → %s\n" "$i" "$domain" "$target"
        domains+=("$domain")
        ((i++))
    done

    echo -e "\nPilih opsi:"
    echo "1) Hapus domain"
    echo "2) Kembali ke menu utama"
    read -p "Pilihan [1-2]: " action
    if [ "$action" = "1" ]; then
        read -p "Masukkan nomor domain yang akan dihapus: " num
        DOMAIN=${domains[$((num-1))]}
        rm -f "${NGINX_CONF_PATH}/${DOMAIN}.conf"
        rm -f "${NGINX_ENABLED_PATH}/${DOMAIN}.conf"
        rm -rf "/var/www/${DOMAIN}"
        certbot delete --cert-name "$DOMAIN" -n || true
        systemctl reload nginx
        echo -e "${GREEN}Domain $DOMAIN dihapus.${RESET}"
    fi
}

function remove_proxy() {
    list_proxies
    echo ""
    read -p "Enter domain to remove: " DOMAIN

    rm -f "${NGINX_CONF_PATH}/${DOMAIN}.conf"
    rm -f "${NGINX_ENABLED_PATH}/${DOMAIN}.conf"
    rm -rf "/var/www/${DOMAIN}"
    certbot delete --cert-name "$DOMAIN" -n || true
    systemctl reload nginx

    echo -e "${GREEN}Domain $DOMAIN removed.${RESET}"
}

while true; do
    echo -e "\n${CYAN}NGINX Proxy Manager Menu:${RESET}"
    echo "1) Install NGINX + open ports 80/443"
    echo "2) Create new reverse proxy for domain"
    echo "3) List current proxied domains"
    echo "4) Remove proxy by domain"
    echo "6) Buat Port Forwarding (iptables NAT)"
echo "7) Lihat Semua Port Forwarding Aktif"
echo "8) Exit"
    read -p "Choose an option [1-5]: " CHOICE

    case $CHOICE in
        1) install_nginx ;;
7)
  echo -e "\n${CYAN}Daftar Port Forwarding NAT Aktif:${RESET}"
  iptables -t nat -L PREROUTING -n -v --line-numbers | grep -E "DNAT"
  echo -e "\nPilih opsi:"
  echo "1) Hapus rule berdasarkan nomor baris"
  echo "2) Kembali ke menu utama"
  read -p "Pilihan [1-2]: " ans
  if [ "$ans" = "1" ]; then
    read -p "Masukkan nomor baris yang akan dihapus: " lineno
    iptables -t nat -D PREROUTING $lineno
    echo -e "${GREEN}Rule baris $lineno dihapus.${RESET}"
    iptables-save > /etc/iptables/rules.v4
  fi
  ;;

        2) create_proxy ;;
        3) list_proxies ;;
        4) remove_proxy ;;
        5) exit 0 ;;

6)
  echo -e "${CYAN}Setup Port Forwarding (iptables NAT):${RESET}"
  read -p "IP internal tujuan (misal: 192.168.2.100): " INTIP
  read -p "Port tujuan di internal (misal: 22): " INTPORT
  read -p "Protocol [tcp/udp]: " PROTO

  # Saran port publik otomatis
  LAST_OCTET=$(echo $INTIP | awk -F'.' '{print $4}')
  if [ "$INTPORT" = "22" ]; then
    PUBPORT="10${LAST_OCTET}22"
  else
    PUBPORT="1${LAST_OCTET}${INTPORT}"
  fi

  echo -e "${CYAN}Port publik yang disarankan: ${GREEN}$PUBPORT${RESET}"
  read -p "Gunakan port publik ini? [Y/n]: " confirm
  if [[ "$confirm" =~ ^[Nn]$ ]]; then
    read -p "Masukkan port publik manual: " PUBPORT
  fi

  iptables -t nat -A PREROUTING -p $PROTO --dport $PUBPORT -j DNAT --to-destination $INTIP:$INTPORT
  iptables -t nat -A POSTROUTING -p $PROTO -d $INTIP --dport $INTPORT -j MASQUERADE

  echo -e "${GREEN}Port forwarding aktif: ${RESET}$PROTO port $PUBPORT → $INTIP:$INTPORT"

  # Install iptables-persistent if needed
  if ! dpkg -l | grep -q iptables-persistent; then
    echo -e "${CYAN}Menginstall iptables-persistent untuk menyimpan rule...${RESET}"
    DEBIAN_FRONTEND=noninteractive apt install iptables-persistent -y
  fi

  echo -e "${CYAN}Menyimpan konfigurasi iptables agar persistent...${RESET}"
  iptables-save > /etc/iptables/rules.v4
  ip6tables-save > /etc/iptables/rules.v6
  echo -e "${GREEN}Rule disimpan dan akan aktif setelah reboot.${RESET}"
  ;;
        *) echo -e "${RED}Invalid option${RESET}" ;;
    esac
done

8) exit 0 ;;
