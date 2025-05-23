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
    echo -e "${GREEN}✅ FTP setup complete. Summary saved to: $OUTPUT_FILE${NC}"

# === REMOVE MODE ===
elif [[ "$CHOICE" == "2" ]]; then
    echo -e "${YELLOW}Searching for FTP-configured users...${NC}"
    USERS=$(ls /home | while read u; do [ -d "/home/$u/ftp/uploads" ] && echo $u; done)
    if [ -z "$USERS" ]; then
        echo -e "${RED}No FTP-configured users found.${NC}"
        exit 0
    fi
    echo "Found users:"
    echo "$USERS"
    read -p "Do you want to remove ALL of these users and their data? (yes/no): " CONFIRM_ALL
    if [[ "$CONFIRM_ALL" != "yes" ]]; then
        echo -e "${RED}Aborted.${NC}"
        exit 1
    fi
    read -p "Do you want to backup video files before deletion? (yes/no): " BACKUP
    if [[ "$BACKUP" == "yes" ]]; then
        BACKUP_DIR="/root/backupFTP_$(date +%Y%m%d_%H%M)"
        mkdir -p "$BACKUP_DIR"
        for u in $USERS; do
            cp -r "/home/$u/ftp/uploads" "$BACKUP_DIR/$u-uploads"
        done
        echo -e "${GREEN}Backup saved to $BACKUP_DIR${NC}"
    fi
    for u in $USERS; do
        deluser --remove-home $u
    done
    apt remove -y vsftpd && apt autoremove -y
    rm -f /etc/vsftpd.conf /etc/vsftpd.conf.bak
    echo -e "${GREEN}✅ All users removed and FTP server uninstalled.${NC}"

# === CREATE NEW USER ===
elif [[ "$CHOICE" == "3" ]]; then
    read -p "Enter new FTP username: " FTP_USER
    read -p "Enter new FTP password: " FTP_PASSWORD
    adduser --disabled-password --gecos "" $FTP_USER
    echo "${FTP_USER}:${FTP_PASSWORD}" | chpasswd
    mkdir -p /home/$FTP_USER/ftp/uploads
    chown nobody:nogroup /home/$FTP_USER/ftp
    chmod a-w /home/$FTP_USER/ftp
    chown $FTP_USER:$FTP_USER /home/$FTP_USER/ftp/uploads
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
    echo -e "${GREEN}✅ New FTP user created. Summary saved to: $OUTPUT_FILE${NC}"

else
    echo -e "${RED}Invalid option. Exiting.${NC}"
    exit 1
fi
