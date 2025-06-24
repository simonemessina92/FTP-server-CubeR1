#!/usr/bin/env bash
# =============================================================================
#  Kiloview FTP + Nginx auto-index helper
#  ► ONE-LINE INSTALL / REMOVE for Ubuntu 20.04 (apt)
#  ► Totally quiet: dopo i prompt non vedi nulla finché compare il messaggio ✅ finale.
#  ► Password gestita da `passwd`, quindi mai stampata o memorizzata.
#  ► Nginx serve l’home dell’utente con autoindex on.
# =============================================================================
set -Eeuo pipefail
trap 'echo -e "\n\033[31m[ERRORE @ linea $LINENO]\033[0m" >&2' ERR

# ---------- Colori & icone ---------------------------------------------------
B="\033[1m"; R="\033[0m"; GREEN="\033[32m"; CYAN="\033[36m"
INFO="${CYAN}➜${R}"; OK="${GREEN}✅${R}"

# ---------- Funzioni utili ----------------------------------------------------
need_root() { [[ $EUID -eq 0 ]] || { echo -e "${B}Devi essere root.${R}" >&2; exit 1; }; }
ask()       { local a; read -rp "${B}$1${R} " a; echo "${a:-$2}"; }
yn()        { local r; while true; do read -rp "$1 (y/n): " r; case $r in [Yy]*) return 0;; [Nn]*) return 1;; esac; done; }
quiet()     { "$@" > /dev/null 2>&1; }
spinner()   { local pid=$1; local s='|/-\\'; local i=0; while kill -0 $pid 2>/dev/null; do printf "\r⏳ %s " "${s:i++%4:1}"; sleep 0.1; done; printf "\r"; }
backup_dir="/root/BCKP"

# ---------- Gestione pacchetti (Ubuntu) --------------------------------------
install_pkgs() { quiet apt-get update && quiet apt-get install -y -qq "$@"; }
remove_pkgs()  { quiet apt-get purge  -y -qq "$@"; }
autoclean()    { quiet apt-get autoremove -y -qq --purge; }

# ---------- INSTALL -----------------------------------------------------------
install_stack() {
  echo -e "${INFO} Installazione in corso… (rimani calmo, niente output 🤫)"

  # --- input utente ----------------------------------------------------------
  local ftp_user ftp_pass ftp_port pasv_min pasv_max web_port
  while true; do
    ftp_user=$(ask "FTP username:");
    [[ $ftp_user =~ ^[a-z_][a-z0-9_-]*$ ]] && ! id "$ftp_user" &>/dev/null && break;
    echo "Nome non valido o già esistente.";
  done
  echo -ne "${B}FTP password:${R} "; stty -echo; read -r ftp_pass; stty echo; echo
  ftp_port=$(ask "Porta FTP (21):" 21)
  web_port=$(ask "Porta Web (8080):" 8080)
  echo "Evito PASV 30000-30200 (Kilolink Pro)."
  if yn "Use default PASV 20000-20200?"; then pasv_min=20000; pasv_max=20200; else
    pasv_min=$(ask "PASV min:" 21100); pasv_max=$(ask "PASV max:" 21110);
  fi

  # --- pacchetti (silenzioso con spinner) ------------------------------------
  install_pkgs vsftpd nginx & pid=$!; spinner $pid

  # --- utente & password -----------------------------------------------------
  quiet adduser --disabled-password --gecos "" "$ftp_user"
  printf "%s:%s" "$ftp_user" "$ftp_pass" | chpasswd -e 2>/dev/null || echo "$ftp_user:$ftp_pass" | chpasswd
  unset ftp_pass
  local ftp_root="/home/$ftp_user"; chmod 755 "$ftp_root"

  # --- vsftpd.conf -----------------------------------------------------------
  cat > /etc/vsftpd.conf <<VSFTP
listen=YES
listen_port=$ftp_port
anonymous_enable=NO
local_enable=YES
write_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES
pasv_enable=YES
pasv_min_port=$pasv_min
pasv_max_port=$pasv_max
user_sub_token=$USER
local_root=/home/$USER
utf8_filesystem=YES
ssl_enable=NO
VSFTP
  quiet systemctl enable --now vsftpd

  # --- Nginx default site ----------------------------------------------------
  cat > /etc/nginx/sites-available/default <<NGX
server {
    listen ${web_port} default_server;
    listen [::]:${web_port} default_server;
    root ${ftp_root};
    index  index.html index.htm;
    autoindex on;
}
NGX
  quiet systemctl enable --now nginx

  echo -e "${OK} Install complete\nFTP  : ${ftp_user} @ ftp://$(hostname -I | awk '{print $1}'):${ftp_port}\nWEB  : http://$(hostname -I | awk '{print $1}'):${web_port}  (auto-index)"
}

# ---------- UNINSTALL --------------------------------------------------------
uninstall_stack() {
  local ftp_user=$(ask "Utente FTP da rimuovere:")
  id "$ftp_user" &>/dev/null || { echo "Utente inesistente."; exit 1; }
  if yn "Backup di /home/$ftp_user?"; then
    mkdir -p "$backup_dir"; tar czf "$backup_dir/${ftp_user}_$(date +%F_%H-%M-%S).tgz" "/home/$ftp_user" >/dev/null 2>&1;
  fi
  quiet userdel -r "$ftp_user"
  remove_pkgs vsftpd nginx; autoclean
  echo -e "${OK} Disinstallazione completata."
}

# ---------- MENU -------------------------------------------------------------
clear
cat <<'BANNER'
╔══════════════════════════════════════════════════════╗
║  🎬  Kiloview FTP + Nginx auto-index helper          ║
╚══════════════════════════════════════════════════════╝
BANNER

need_root
PS3=$'\nScegli opzione → '
select opt in "Install / Update" "Remove" "Exit"; do
  case $REPLY in
    1) install_stack; break;;
    2) uninstall_stack; break;;
    3) echo "Bye."; exit 0;;
    *) echo "Scelta non valida.";;
  esac
done
