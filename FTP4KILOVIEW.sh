#!/bin/bash

# === Colors and Icons ===
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

print_header() {
    clear
    echo -e "${CYAN}============================================"
    echo -e "🚀  ${GREEN}Kiloview FTP + NGINX Installer${NC} by Simone Messina"
    echo -e "${CYAN}============================================${NC}\n"
}

print_header

# === MENU ===
echo -e "${YELLOW}Please select an option:${NC}"
echo -e "1) 📦 Install FTP + NGINX"
echo -e "2) 🗑️ Uninstall everything\n"
read -p "Select option [1-2]: " CHOICE

# === INSTALL ===
if [[ "$CHOICE" == "1" ]]; then
    read -p "👤 FTP Username: " FTP_USER
    read -s -p "🔐 FTP Password: " FTP_PASSWORD
    echo ""
    read -p "🌐 Web port for file access (default 8080): " WEB_PORT
    [[ -z "$WEB_PORT" ]] && WEB_PORT=8080

    echo -e "${BLUE}Installing packages...${NC}"
    apt update -y && apt install -y vsftpd nginx

    echo -e "${BLUE}Creating FTP user and directory structure...${NC}"
    adduser --disabled-password --gecos "" $FTP_USER
    echo "$FTP_USER:$FTP_PASSWORD" | chpasswd
    mkdir -p /home/$FTP_USER/ftp/uploads
    chown nobody:nogroup /home/$FTP_USER/ftp
    chmod a-w /home/$FTP_USER/ftp
    chown $FTP_USER:$FTP_USER /home/$FTP_USER/ftp/uploads

    echo -e "${BLUE}Configuring vsftpd...${NC}"
    cp /etc/vsftpd.conf /etc/vsftpd.conf.bak
    cat <<EOL > /etc/vsftpd.conf
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
chroot_local_user=YES
pasv_enable=YES
pasv_min_port=20000
pasv_max_port=20200
user_sub_token=\$USER
local_root=/home/\$USER/ftp
userlist_enable=NO
EOL
    systemctl restart vsftpd

    echo -e "${BLUE}Configuring NGINX for web access...${NC}"
    mkdir -p /var/www/ftp
    ln -s /home/$FTP_USER/ftp/uploads /var/www/ftp/uploads
    cat <<EOF > /etc/nginx/sites-available/ftp
server {
    listen $WEB_PORT default_server;
    root /var/www/ftp;
    autoindex on;
    location / {
        autoindex_exact_size off;
        autoindex_localtime on;
    }
}
EOF
    ln -sf /etc/nginx/sites-available/ftp /etc/nginx/sites-enabled/ftp
    nginx -t && systemctl restart nginx

    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo -e "${GREEN}\n✅ Installation Complete!"
    echo -e "📂 FTP Upload Path: /home/$FTP_USER/ftp/uploads  standard FTP port: 21"
    echo -e "🌍 Web Access: http://$SERVER_IP:$WEB_PORT/uploads"
    echo -e "🔑 User: $FTP_USER (password hidden)${NC}"

# === UNINSTALL ===
elif [[ "$CHOICE" == "2" ]]; then
    echo -e "${YELLOW}Scanning for FTP-configured users...${NC}"
    USERS=$(ls /home | while read u; do [ -d "/home/$u/ftp/uploads" ] && echo $u; done)
    if [ -z "$USERS" ]; then
        echo -e "${RED}❌ No FTP-configured users found.${NC}"
    else
        echo -e "${GREEN}Found users:${NC} $USERS"
        read -p "Remove ALL FTP users and configurations? (yes/no): " CONFIRM_ALL
        if [[ "$CONFIRM_ALL" != "yes" ]]; then
            echo -e "${RED}❌ Operation aborted.${NC}"
            exit 1
        fi

        read -p "Backup video files before removal? (yes/no): " BACKUP
        if [[ "$BACKUP" == "yes" ]]; then
            BACKUP_DIR="/root/backupFTP_$(date +%Y%m%d_%H%M)"
            mkdir -p "$BACKUP_DIR"
            for u in $USERS; do
                cp -r "/home/$u/ftp/uploads" "$BACKUP_DIR/$u-uploads"
            done
            echo -e "${GREEN}🔁 Backup saved to $BACKUP_DIR${NC}"
        fi

        for u in $USERS; do
            deluser --remove-home $u
            rm -f "/var/www/ftp/$u"
            echo -e "${GREEN}🗑️ Removed user $u${NC}"
        done
    fi

    echo -e "${BLUE}Removing vsftpd and nginx...${NC}"
    systemctl stop nginx
    systemctl disable nginx
    systemctl unmask nginx
    apt purge -y nginx nginx-common nginx-core vsftpd
    apt autoremove -y
    rm -rf /etc/nginx /var/www/ftp
    rm -f /etc/vsftpd.conf /etc/vsftpd.conf.bak
    rm -f /etc/nginx/sites-enabled/ftp /etc/nginx/sites-available/ftp
    systemctl restart nginx

    echo -e "${GREEN}✅ Uninstallation complete.${NC}"

else
    echo -e "${RED}Invalid option. Exiting.${NC}"
    exit 1
fi
