#!/bin/bash
# NGINX Proxy Manager with Submenus
# Author: Agus Prasetyo (with ChatGPT)

set -e

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

function list_manage_proxies() {
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
    echo "1) Hapus salah satu domain"
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
        echo -e "${GREEN}Domain $DOMAIN berhasil dihapus.${RESET}"
    fi
}

function proxy_domain_menu() {
    while true; do
        echo -e "\n${CYAN}Kelola Reverse Proxy Domain:${RESET}"
        echo "1) Buat proxy domain baru"
        echo "2) Lihat & hapus domain yang di-proxy"
        echo "3) Kembali ke menu utama"
        read -p "Pilih [1-3]: " opt
        case $opt in
            1) create_proxy ;;
            2) list_manage_proxies ;;
            3) break ;;
            *) echo -e "${RED}Pilihan tidak valid.${RESET}" ;;
        esac
    done
}

function create_port_forward() {
  echo -e "${CYAN}Setup Port Forwarding (iptables NAT):${RESET}"
  read -p "IP internal tujuan (misal: 192.168.2.100): " INTIP
  read -p "Port tujuan di internal (misal: 22): " INTPORT
  read -p "Protocol [tcp/udp]: " PROTO

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

  if ! dpkg -l | grep -q iptables-persistent; then
    echo -e "${CYAN}Menginstall iptables-persistent...${RESET}"
    DEBIAN_FRONTEND=noninteractive apt install iptables-persistent -y
  fi

  iptables-save > /etc/iptables/rules.v4
  ip6tables-save > /etc/iptables/rules.v6
  echo -e "${GREEN}Rule disimpan permanent.${RESET}"
}

function list_manage_forwarding() {
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
}

function port_forwarding_menu() {
    while true; do
        echo -e "\n${CYAN}Kelola Port Forwarding:${RESET}"
        echo "1) Buat port forwarding baru"
        echo "2) Lihat & hapus port forwarding"
        echo "3) Kembali ke menu utama"
        read -p "Pilih [1-3]: " pf
        case $pf in
            1) create_port_forward ;;
            2) list_manage_forwarding ;;
            3) break ;;
            *) echo -e "${RED}Pilihan tidak valid.${RESET}" ;;
        esac
    done
}

# Main menu
while true; do
    echo -e "\n${CYAN}NGINX Proxy Manager Menu:${RESET}"
    echo "1) Install NGINX + open ports 80/443"
    echo "2) Kelola Reverse Proxy Domain"
    echo "3) Kelola Port Forwarding"
    echo "4) Exit"
    read -p "Pilih opsi [1-4]: " CHOICE

    case $CHOICE in
        1) install_nginx ;;
        2) proxy_domain_menu ;;
        3) port_forwarding_menu ;;
        4) exit 0 ;;
        *) echo -e "${RED}Pilihan tidak valid.${RESET}" ;;
    esac
done
