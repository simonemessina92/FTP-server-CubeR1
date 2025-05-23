#!/bin/bash

# === Colors ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Kiloview FTP Pro Installer by Simone Messina${NC}"
echo ""

# === Main Menu ===
echo -e "${YELLOW}What would you like to do?${NC}"
echo "1) Install & configure FTP server"
echo "2) Remove FTP server and users"
echo "3) Create a new FTP user"
read -p "Enter choice [1, 2 or 3]: " CHOICE

show_summary() {
    echo -e "${GREEN}\nFTP Settings for Kiloview Cube R1:${NC}"
    echo -e "---------------------------------------------"
    echo -e "Name:             MyFTPServer"
    echo -e "FTP Host:         $SERVER_IP"
    echo -e "Port:             21"
    echo -e "Username:         $FTP_USER"
    echo -e "Password:         (the password you chose)"
    echo -e "Upload Directory: /uploads"
    echo -e "---------------------------------------------"
    echo -e "📂 Full server path created: /home/$FTP_USER/ftp/uploads"
    echo -e "📄 Summary also saved to: $OUTPUT_FILE"
}

# === INSTALL MODE ===
if [[ "$CHOICE" == "1" ]]; then
    read -p "Enter your desired FTP username: " FTP_USER
    read -p "Enter your desired FTP password: " FTP_PASSWORD
    echo -e "${RED}Kilolink Server Pro uses ports 30000–30200. Avoid using this range for passive FTP.${NC}"
    read -p "Use default passive port range 20000–20200? (yes/no): " USE_DEFAULT
    if [[ "$USE_DEFAULT" == "no" ]]; then
        read -p "Enter Passive FTP port range START: " PASV_MIN_PORT
        read -p "Enter Passive FTP port range END: " PASV_MAX_PORT
    else
        PASV_MIN_PORT=20000
        PASV_MAX_PORT=20200
    fi
    apt update && apt install -y vsftpd
    adduser --disabled-password --gecos "" $FTP_USER
    echo "${FTP_USER}:${FTP_PASSWORD}" | chpasswd
    mkdir -p /home/$FTP_USER/ftp/uploads
    chown nobody:nogroup /home/$FTP_USER/ftp
    chmod a-w /home/$FTP_USER/ftp
    chown $FTP_USER:$FTP_USER /home/$FTP_USER/ftp/uploads
    cp /etc/vsftpd.conf /etc/vsftpd.conf.bak
    cat <<EOL > /etc/vsftpd.conf
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
chroot_local_user=YES
pasv_enable=YES
pasv_min_port=$PASV_MIN_PORT
pasv_max_port=$PASV_MAX_PORT
user_sub_token=\$USER
local_root=/home/\$USER/ftp
userlist_enable=NO
EOL
    systemctl restart vsftpd
    SERVER_IP=$(hostname -I | awk '{print $1}')
    OUTPUT_FILE="/home/$FTP_USER/ftp/ftp_config_summary.txt"
    echo -e "FTP Settings for Kiloview Cube R1:\n" > $OUTPUT_FILE
    echo -e "Name:             MyFTPServer" >> $OUTPUT_FILE
    echo -e "FTP Host:         $SERVER_IP" >> $OUTPUT_FILE
    echo -e "Port:             21" >> $OUTPUT_FILE
    echo -e "Username:         $FTP_USER" >> $OUTPUT_FILE
    echo -e "Password:         (the password you chose)" >> $OUTPUT_FILE
    echo -e "Upload Directory: /uploads\n" >> $OUTPUT_FILE
    echo -e "Full server path created: /home/$FTP_USER/ftp/uploads" >> $OUTPUT_FILE
    echo -e "${GREEN}✅ FTP setup complete.${NC}"
    show_summary
    exit 0
fi
