#!/bin/bash

# === Colors ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Kiloview FTP EasySetup & Cleanup by Simone Messina${NC}"
echo ""

# === Ask user what they want to do ===
echo -e "${YELLOW}What would you like to do?${NC}"
echo "1) Install & configure FTP server"
echo "2) Remove FTP server and cleanup"
read -p "Enter choice [1 or 2]: " CHOICE

if [[ "$CHOICE" == "2" ]]; then
    # === Cleanup Mode ===
    echo ""
    read -p "$(echo -e ${GREEN}'Enter the FTP username you previously created (default: record):'${NC}) " FTP_USER
    FTP_USER=${FTP_USER:-record}

    read -p "$(echo -e ${RED}'Are you sure you want to remove user '$FTP_USER' and all related data? (yes/no):'${NC}) " CONFIRM

    if [[ "$CONFIRM" != "yes" ]]; then
        echo -e "${RED}Aborted. No changes made.${NC}"
        exit 1
    fi

    deluser --remove-home $FTP_USER
    apt remove -y vsftpd
    apt autoremove -y
    rm -f /etc/vsftpd.conf
    rm -f /etc/vsftpd.conf.bak

    echo -e "${GREEN}✅ Cleanup complete. vsftpd uninstalled, user '$FTP_USER' removed, and configuration deleted.${NC}"
    exit 0

elif [[ "$CHOICE" == "1" ]]; then
    # === Setup Mode ===
    read -p "$(echo -e ${GREEN}'Enter your desired FTP username:'${NC}) " FTP_USER
    read -s -p "$(echo -e ${GREEN}'Enter your desired FTP password:'${NC}) " FTP_PASSWORD
    echo ""

    echo -e "${RED}Kilolink Server Pro uses port range 30000–30200. Avoid using this range for FTP passive mode.${NC}"
    echo ""
    DEFAULT_PASV_MIN=20000
    DEFAULT_PASV_MAX=20200
    read -p "$(echo -e ${GREEN}'Do you want to use the default passive port range 20000–20200? (yes/no):'${NC}) " USE_DEFAULT

    if [[ "$USE_DEFAULT" == "no" ]]; then
        read -p "$(echo -e ${GREEN}'Enter Passive FTP port range START:'${NC}) " PASV_MIN_PORT
        read -p "$(echo -e ${GREEN}'Enter Passive FTP port range END:'${NC}) " PASV_MAX_PORT
    else
        PASV_MIN_PORT=$DEFAULT_PASV_MIN
        PASV_MAX_PORT=$DEFAULT_PASV_MAX
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

    echo ""
    echo -e "${GREEN}✅ FTP setup complete for user '$FTP_USER'. Passive ports: $PASV_MIN_PORT-$PASV_MAX_PORT${NC}"
    echo -e "${GREEN}Ensure you open ports 21 and $PASV_MIN_PORT-$PASV_MAX_PORT in your cloud provider firewall settings.${NC}"
    echo ""
    echo -e "${GREEN}These are the settings to insert into your Kiloview Cube R1 FTP configuration:${NC}"
    echo -e "---------------------------------------------"
    echo -e "${GREEN}Name:${NC}           Your custom label (e.g., MyFTPServer)"
    echo -e "${GREEN}FTP Host:${NC}       $SERVER_IP"
    echo -e "${GREEN}Port:${NC}           21"
    echo -e "${GREEN}Username:${NC}       $FTP_USER"
    echo -e "${GREEN}Password:${NC}       (the password you chose)"
    echo -e "${GREEN}Upload Directory:${NC}  /uploads"
    echo -e "---------------------------------------------"
    echo -e "${GREEN}📂 Full server path created: /home/$FTP_USER/ftp/uploads${NC}"
    echo -e "${GREEN}📄 Configuration summary exported to: $OUTPUT_FILE${NC}"
    echo -e "${GREEN}You can copy and paste these parameters directly into your Kiloview R1 interface.${NC}"
    exit 0

else
    echo -e "${RED}Invalid option. Exiting.${NC}"
    exit 1
fi
