#!/usr/bin/env bash
# =============================================================================
#  Script: setup_ftp_nginx.sh
#  Autore: ChatGPT per Sem – FIX Ubuntu 20.04 (Giugno 2025)
# =============================================================================
#  Scopo :
#   ▸ Installazione/Disinstallazione di vsftpd + Nginx.
#   ▸ Password gestita con `passwd` (mai in chiaro).
#   ▸ Backup opzionale, porte custom.
#   ▸ Correzione vsftpd.conf: ora usa il token $USER **runtime**, non "root".
# =============================================================================
set -Eeuo pipefail
trap 'echo -e "\n[ERRORE @ linea $LINENO]" >&2' ERR

# --- UTIL ---------------------------------------------------------
need_root() { [[ $EUID -eq 0 ]] || { echo "Devi essere root." >&2; exit 1; }; }
ask() { local ans; read -rp "$1 " ans; echo "${ans:-$2}"; }
yn()  {
  local r; while true; do read -rp "$1 (y/n): " r; case $r in [Yy]*) return 0;; [Nn]*) return 1;; esac; done;
}

backup_dir="/root/BCKP"

# Package‑manager abstraction -------------------------------------
if command -v apt &>/dev/null; then
  install() { apt update && DEBIAN_FRONTEND=noninteractive apt install -y "$@"; }
  remove()  { apt purge -y "$@"; }
  clean()   { apt autoremove -y --purge; }
else
  echo "Questa versione è tarata su Ubuntu/Debian con apt." >&2; exit 1;
fi

# ---------------- INSTALL ----------------------------------------
install_stack() {
  echo "=== INSTALL ==="; install vsftpd nginx

  # ----- utente --------------------------------------------------
  local ftp_user
  while true; do
    ftp_user=$(ask "Nome utente FTP:")
    [[ $ftp_user =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo "Nome non valido."; continue; }
    id "$ftp_user" &>/dev/null && { echo "Utente già presente."; continue; }
    break
  done

  adduser --disabled-password --gecos "" "$ftp_user"
  echo -e "\nImposta la password per $ftp_user:"; passwd "$ftp_user"

  local ftp_root="/home/$ftp_user"; chmod 755 "$ftp_root"

  # ----- porte ---------------------------------------------------
  local ftp_port pasv_min pasv_max nginx_port
  ftp_port=$(ask "Porta FTP (21):" 21)
  pasv_min=$(ask "PASV min (21100):" 21100)
  pasv_max=$(ask "PASV max (21110):" 21110)
  nginx_port=$(ask "Porta HTTP Nginx (80):" 80)

  # ----- vsftpd.conf --------------------------------------------
  cp /etc/vsftpd.conf{,.bak.$(date +%s)}
  cat > /etc/vsftpd.conf <<'VSFTP'
listen=YES
listen_port=REPLACE_FTP_PORT
anonymous_enable=NO
local_enable=YES
write_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES
pasv_enable=YES
pasv_min_port=REPLACE_PASV_MIN
pasv_max_port=REPLACE_PASV_MAX
user_sub_token=$USER
local_root=/home/$USER
utf8_filesystem=YES
ssl_enable=NO
VSFTP
  # sostituzioni dinamiche
  sed -i "s/REPLACE_FTP_PORT/${ftp_port}/" /etc/vsftpd.conf
  sed -i "s/REPLACE_PASV_MIN/${pasv_min}/" /etc/vsftpd.conf
  sed -i "s/REPLACE_PASV_MAX/${pasv_max}/" /etc/vsftpd.conf

  systemctl enable --now vsftpd

  # ----- Nginx default site -------------------------------------
  cp /etc/nginx/sites-available/default{,.bak.$(date +%s)}
  sed -Ei "s#root [^;]*;#root $ftp_root;#" /etc/nginx/sites-available/default
  sed -Ei "s/listen [0-9]+ default_server;/listen ${nginx_port} default_server;/" /etc/nginx/sites-available/default
  sed -Ei "s/listen \[::\]:[0-9]+ default_server;/listen [::]:${nginx_port} default_server;/" /etc/nginx/sites-available/default
  systemctl enable --now nginx

  echo -e "\n[OK] Stack pronta!\n  • FTP  : ftp://<IP>:${ftp_port}/ (PASV ${pasv_min}-${pasv_max})\n  • HTTP : http://<IP>:${nginx_port}/  (root → $ftp_root)"
}

# ---------------- UNINSTALL -------------------------------------
uninstall_stack() {
  echo "=== UNINSTALL ==="
  local ftp_user=$(ask "Utente FTP da rimuovere:")
  id "$ftp_user" &>/dev/null || { echo "Utente inesistente."; exit 1; }

  if yn "Backup di /home/$ftp_user?"; then
    mkdir -p "$backup_dir"
    tar czf "$backup_dir/${ftp_user}_$(date +%F_%H-%M-%S).tgz" "/home/$ftp_user"
    echo "Backup salvato in $backup_dir"
  fi

  userdel -r "$ftp_user"
  remove vsftpd nginx
  clean
  echo "Disinstallazione completata."
}

# ---------------- MENU ------------------------------------------
need_root
PS3=$'\nScegli opzione: '
select opt in "Installa FTP + Nginx" "Disinstalla" "Esci"; do
  case $REPLY in
    1) install_stack; break;;
    2) uninstall_stack; break;;
    3) echo "Bye."; exit 0;;
    *) echo "Scelta non valida.";;
  esac
done
