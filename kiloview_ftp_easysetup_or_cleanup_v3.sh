#!/usr/bin/env bash
# =============================================================================
#  🎬  Kiloview FTP + Nginx Helper – “silent & colorful”  (Ubuntu 20.04)
# =============================================================================
#  ► Prompts only – no intermediate output: runs silently, logs to /tmp/kilo-setup.log
#  ► Password never echoed (handled securely via passwd/chpasswd)
#  ► Spinner ⏳ shows install activity, then just ✅ at the end
#  ► Nginx auto-indexes user home directory for web access
# =============================================================================
set -Eeuo pipefail
trap 'echo -e "\n\033[31m[ERROR at line $LINENO]\033[0m  (see /tmp/kilo-setup.log)" >&2' ERR

# ---------- Style & Icons ----------------------------------------------------
B="\033[1m"; R="\033[0m"; G="\033[32m"; C="\033[36m"; Y="\033[33m"
INFO="${C}➜${R}"; OK="${G}✅${R}"

# ---------- Log & silent execution -------------------------------------------
log="/tmp/kilo-setup.log"; :> "$log"
quiet()   { "$@" >> "$log" 2>&1; }
spinner() { local p=$1 s='|/-\\' i=0; while kill -0 $p 2>/dev/null; do printf "\r⏳ %s " "${s:i++%4:1}"; sleep 0.1; done; printf "\r"; }

# ---------- Utils ------------------------------------------------------------
need_root() { [[ $EUID -eq 0 ]] || { echo -e "${B}You must run as root.${R}" >&2; exit 1; }; }
ask()       { local a; read -rp "${B}$1${R} " a; echo "${a:-$2}"; }
yn()        { local r; while true; do read -rp "$1 (y/n): " r; case $r in [Yy]*) return 0;; [Nn]*) return 1;; esac; done; }

backup_dir="/root/BCKP"

# ---------- Package helpers --------------------------------------------------
install_pkgs() { quiet apt-get update && DEBIAN_FRONTEND=noninteractive quiet apt-get install -y -qq "$@"; }
remove_pkgs()  { DEBIAN_FRONTEND=noninteractive quiet apt-get purge  -y -qq "$@"; }
autoclean()    { quiet apt-get autoremove -y -qq --purge; }

# ---------- INSTALL FUNCTION -------------------------------------------------
install_stack() {
  echo -e "${INFO} Installing... (logging to $log)"

  local ftp_user ftp_pass ftp_port pasv_min pasv_max web_port
  while true; do
    ftp_user=$(ask "FTP username:");
    [[ $ftp_user =~ ^[a-z_][a-z0-9_-]*$ ]] && ! id "$ftp_user" &>/dev/null && break;
    echo "Invalid or existing username.";
  done
  echo -ne "${B}FTP password:${R} "; stty -echo; read -r ftp_pass; stty echo; echo
  ftp_port=$(ask "FTP port (21):" 21)
  web_port=$(ask "Web port (8080):" 8080)
  echo "Avoiding PASV 30000–30200 (Kilolink Pro)."
  if yn "Use default PASV 20000–20200?"; then pasv_min=20000; pasv_max=20200; else
    pasv_min=$(ask "PASV min:" 21100); pasv_max=$(ask "PASV max:" 21110);
  fi

  install_pkgs vsftpd nginx & pid=$!; spinner $pid

  quiet adduser --disabled-password --gecos "" "$ftp_user"
  echo "$ftp_user:$ftp_pass" | chpasswd --quiet
  unset ftp_pass
  local ftp_root="/home/$ftp_user"; chmod 755 "$ftp_root"

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
user_sub_token=\$USER
local_root=/home/\$USER
utf8_filesystem=YES
ssl_enable=NO
VSFTP
  quiet systemctl enable --now vsftpd

  cat > /etc/nginx/sites-available/default <<NGX
server {
    listen ${web_port} default_server;
    listen [::]:${web_port} default_server;
    root ${ftp_root};
    index index.html index.htm;
    autoindex on;
}
NGX
  quiet systemctl enable --now nginx

  local ip=$(hostname -I | awk '{print $1}')
  echo -e "\n${OK} Install complete\nFTP  : ${ftp_user} @ ftp://${ip}:${ftp_port}\nWEB  : http://${ip}:${web_port}  (auto-index)"
}

# ---------- UNINSTALL FUNCTION -----------------------------------------------
uninstall_stack() {
  local ftp_user=$(ask "FTP user to remove:")
  id "$ftp_user" &>/dev/null || { echo "User does not exist."; exit 1; }
  if yn "Backup /home/$ftp_user before removal?"; then
    mkdir -p "$backup_dir"; tar czf "$backup_dir/${ftp_user}_$(date +%F_%H-%M-%S).tgz" "/home/$ftp_user" >> "$log" 2>&1;
  fi
  quiet userdel -r "$ftp_user"
  remove_pkgs vsftpd nginx; autoclean
  echo -e "${OK} Uninstallation complete."
}

# ---------- MAIN MENU --------------------------------------------------------
clear
cat <<'BANNER'
╔══════════════════════════════════════════════════════╗
║  🎬  Kiloview FTP + Nginx auto-index helper          ║
╚══════════════════════════════════════════════════════╝
BANNER

need_root
PS3=$'\nSelect option → '
select opt in "Install / Update" "Remove" "Exit"; do
  case $REPLY in
    1) install_stack; break;;
    2) uninstall_stack; break;;
    3) echo "Bye."; exit 0;;
    *) echo "Invalid choice.";;
  esac
done
