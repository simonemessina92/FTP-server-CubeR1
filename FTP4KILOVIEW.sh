#!/bin/bash

# ───────────────────────────────────────────────
#   Kiloview FTP + Nginx auto-index helper
#   Autore: Simone Messina / GitHub: simonemessina92
# ───────────────────────────────────────────────

clear
echo -e "\033[1;35m┌────────────────────────────────────────────┐"
echo -e "│ 📦  Kiloview FTP + Nginx auto-index helper │"
echo -e "└────────────────────────────────────────────┘\033[0m"
echo
echo "1) Install / Update"
echo "2) Remove"
echo "3) Exit"

# Fix per far leggere da tastiera anche via curl | bash
exec < /dev/tty
read -rp "Select option → " opt

install_stack() {
  echo "[INFO] Installing... (logging to /tmp/kilo-setup.log)"

  apt update -y >> /tmp/kilo-setup.log 2>&1
  apt install -y vsftpd nginx >> /tmp/kilo-setup.log 2>&1

  read -rp "FTP username: " ftpuser
  read -rsp "FTP password: " ftppass
  echo
  read -rp "FTP port (21): " ftpport
  ftpport=${ftpport:-21}
  read -rp "Web port (8080): " webport
  webport=${webport:-8080}

  useradd -m -d /home/"$ftpuser" -s /bin/bash "$ftpuser"
  echo "$ftpuser:$ftppass" | chpasswd

  cat > /etc/vsftpd.conf <<EOF
listen=YES
listen_port=$ftpport
anonymous_enable=NO
local_enable=YES
write_enable=YES
chroot_local_user=YES
pasv_enable=YES
pasv_min_port=20000
pasv_max_port=20200
EOF

  systemctl restart vsftpd

  cat > /etc/nginx/sites-available/default <<EOF
server {
    listen $webport default_server;
    listen [::]:$webport default_server;
    root /home/$ftpuser;
    index index.html index.htm;
    autoindex on;
}
EOF

  systemctl restart nginx

  echo
  echo -e "\033[1;32m✅ Install complete\033[0m"
  echo "FTP  : $ftpuser @ ftp://<your-ip>:$ftpport"
  echo "HTTP : http://<your-ip>:$webport"
}

uninstall_stack() {
  echo "[INFO] Removing FTP and NGINX..."
  systemctl stop vsftpd nginx
  apt purge -y vsftpd nginx
  apt autoremove -y
  echo -e "\033[1;31mUninstall complete.\033[0m"
}

case "$opt" in
  1) install_stack ;;
  2) uninstall_stack ;;
  3) echo "Bye!" && exit 0 ;;
  *) echo -e "\033[1;31mInvalid choice.\033[0m" && exit 1 ;;
esac
