#!/usr/bin/env bash
# =============================================================================
#  Script: setup_ftp_nginx.sh
#  Autore: ChatGPT per Sem – versione rivista (Giugno 2025)
#  Scopo : Installare *o* disinstallare in modo interattivo:
#           · Server FTP (vsftpd) con porte e range passive configurabili.
#           · Web‑server (Nginx) che espone la stessa directory via HTTP.
#  PLUS  : Backup facoltativo, input password realmente nascosto, variabile
#           subito *unset* così da non restare in chiaro in memoria / history.
#  Uso   : sudo ./setup_ftp_nginx.sh
# =============================================================================
set -euo pipefail

# --- UTIL ---------------------------------------------------------
need_root() {
  [[ $EUID -eq 0 ]] || { echo "Devi essere root." >&2; exit 1; }
}

ask() { # $1=prompt $2=default(optional)
  local ans
  read -rp "${1} " ans
  echo "${ans:-$2}"
}

yn() { # yes/no → 0/1
  local r; while true; do read -rp "$1 (y/n): " r; case $r in [Yy]*) return 0;; [Nn]*) return 1;; esac; done; }

backup_dir="/root/BCKP"

# Detect minimal pkg manager (Debian/Ubuntu vs RHEL‑like)
if command -v apt &>/dev/null; then PM="apt"; INSTALL="apt update && apt install -y"; REMOVE="apt purge -y"; CLEAN="apt autoremove -y --purge";
elif command -v dnf &>/dev/null; then PM="dnf"; INSTALL="dnf install -y"; REMOVE="dnf remove -y"; CLEAN="dnf autoremove -y";
else echo "Distro non supportata (serve apt o dnf)."; exit 1; fi

# --------------------- INSTALL ----------------------------------
install_stack() {
  echo "=== INSTALL ==="
  eval "$INSTALL vsftpd nginx"

  local ftp_user
  while true; do ftp_user=$(ask "Nome utente FTP:"); [[ -n $ftp_user ]] && ! id "$ftp_user" &>/dev/null && break; echo "Utente non valido o esistente."; done

  # Password (nascosta) e subito unset
  local ftp_pass
  read -rsp "Password per $ftp_user: " ftp_pass; echo
  adduser --disabled-password --gecos "" "$ftp_user"
  echo "$ftp_user:$ftp_pass" | chpasswd --encrypted 2>/dev/null || echo "$ftp_user:$ftp_pass" | chpasswd
  unset ftp_pass

  # Cartella FTP & permessi
  local ftp_root="/home/$ftp_user"
  chmod 755 "$ftp_root"

  # Porte personalizzabili
  local ftp_port ftp_pasv_min ftp_pasv_max nginx_port
  ftp_port=$(ask "Porta FTP (default 21):" 21)
  ftp_pasv_min=$(ask "PASV min (21100):" 21100)
  ftp_pasv_max=$(ask "PASV max (21110):" 21110)
  nginx_port=$(ask "Porta HTTP Nginx (80):" 80)

  # vsftpd.conf minimal
  cp /etc/vsftpd.conf{,.bak.$(date +%s)}
  cat > /etc/vsftpd.conf <<EOF
listen=YES
listen_port=$ftp_port
anonymous_enable=NO
local_enable=YES
write_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES
pasv_enable=YES
pasv_min_port=$ftp_pasv_min
pasv_max_port=$ftp_pasv_max
user_sub_token=$USER
local_root=$ftp_root
utf8_filesystem=YES
ssl_enable=NO
EOF
  systemctl restart vsftpd

  # Nginx default site → stessa cartella
  cp /etc/nginx/sites-available/default{,.bak.$(date +%s)}
  sed -i -E "s#root .*;#root $ftp_root;#" /etc/nginx/sites-available/default
  sed -i -E "s/listen [0-9]+ default_server;/listen ${nginx_port} default_server;/" /etc/nginx/sites-available/default
  sed -i -E "s/listen \[::\]:[0-9]+ default_server;/listen [::]:${nginx_port} default_server;/" /etc/nginx/sites-available/default
  systemctl reload nginx

  echo -e "\n[OK] Stack pronta! Cartella: $ftp_root\n  • FTP → ftp://<IP>:${ftp_port}/ (PASV ${ftp_pasv_min}-${ftp_pasv_max})\n  • HTTP → http://<IP>:${nginx_port}/"
}

# --------------------- UNINSTALL --------------------------------
uninstall_stack() {
  echo "=== UNINSTALL ==="
  local ftp_user=$(ask "Utente FTP da rimuovere:")
  id "$ftp_user" &>/dev/null || { echo "Utente inesistente."; exit 1; }

  if yn "Vuoi un backup di /home/$ftp_user?"; then
    mkdir -p "$backup_dir"
    tar czf "$backup_dir/${ftp_user}_$(date +%F_%H-%M-%S).tgz" "/home/$ftp_user"
    echo "Backup salvato in $backup_dir";
  fi

  userdel -r "$ftp_user"
  eval "$REMOVE vsftpd nginx"
  eval "$CLEAN"
  echo "Disinstallazione completata."
}

# --------------------- MENU -------------------------------------
need_root
PS3=$'\nScegli un'opzione: '
select opt in "Installa FTP + Nginx" "Disinstalla" "Esci"; do
  case $REPLY in
    1) install_stack; break;;
    2) uninstall_stack; break;;
    3) echo "Bye."; exit 0;;
    *) echo "Scelta non valida.";;
  esac
done
