#!/usr/bin/env bash
# =============================================================================
#  Script: setup_ftp_nginx.sh
#  Autore: ChatGPT per Sem – revisione "password‑safe" (Giugno 2025)
# =============================================================================
#  Scopo :
#  ▸ Installare / disinstallare vsftpd + Nginx con domande interattive 
#  ▸ Password non visibile **né** salvata: conferma doppia, hashing SHA‑512,
#    variabile sovrascritta & unset.
#  ▸ Backup opzionale dell’home, porte personalizzabili, supporto apt/dnf.
# =============================================================================
set -Eeuo pipefail
trap 'echo -e "\n[ERRORE] linea $LINENO – controlla sintassi o permessi." >&2' ERR

# --- UTIL ---------------------------------------------------------
need_root() { [[ $EUID -eq 0 ]] || { echo "Devi essere root." >&2; exit 1; }; }
ask() { local ans; read -rp "$1 " ans; echo "${ans:-$2}"; }
yn()  { local r; while true; do read -rp "$1 (y/n): " r; case $r in [Yy]*) return 0;; [Nn]*) return 1;; esac; done; }
overwrite_var() { local -n __var=$1; __var=""; unset __var; }

backup_dir="/root/BCKP"

# Package manager abstraction -------------------------------------------------
if command -v apt &>/dev/null; then
  INSTALL() { apt update && DEBIAN_FRONTEND=noninteractive apt install -y "$@"; }
  REMOVE()  { apt purge -y "$@"; }
  CLEAN()   { apt autoremove -y --purge; }
elif command -v dnf &>/dev/null; then
  INSTALL() { dnf install -y "$@"; }
  REMOVE()  { dnf remove -y "$@"; }
  CLEAN()   { dnf autoremove -y; }
else
  echo "Distro non supportata (serve apt o dnf)." >&2; exit 1;
fi

# ---------------- Install ----------------------------------------
install_stack() {
  echo "=== INSTALL ==="
  INSTALL vsftpd nginx openssl

  # ----- utente --------------------------------------------------
  local ftp_user
  while true; do
    ftp_user=$(ask "Nome utente FTP:")
    [[ $ftp_user =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo "Nome non valido."; continue; }
    id "$ftp_user" &>/dev/null && { echo "Utente già presente."; continue; }
    break
  done

  # ----- password (doppia conferma, silenziosa) ------------------
  local pw1 pw2 pw_hash
  while true; do
    read -s -r -p "Password per $ftp_user: " pw1; echo
    read -s -r -p "Conferma password : " pw2; echo
    [[ $pw1 == "$pw2" ]] && [[ -n $pw1 ]] && break
    echo "Le password non coincidono o vuote. Riprova."
  done
  pw_hash=$(openssl passwd -6 "$pw1")
  overwrite_var pw1; overwrite_var pw2

  # ----- creazione utente ---------------------------------------
  useradd -m -p "$pw_hash" "$ftp_user"
  overwrite_var pw_hash

  local ftp_root="/home/$ftp_user"; chmod 755 "$ftp_root"

  # ----- porte custom -------------------------------------------
  local ftp_port pasv_min pasv_max nginx_port
  ftp_port=$(ask "Porta FTP (21):" 21)
  pasv_min=$(ask "PASV min (21100):" 21100)
  pasv_max=$(ask "PASV max (21110):" 21110)
  nginx_port=$(ask "Porta HTTP Nginx (80):" 80)

  # ----- vsftpd.conf --------------------------------------------
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
pasv_min_port=$pasv_min
pasv_max_port=$pasv_max
user_sub_token=$USER
local_root=$ftp_root
utf8_filesystem=YES
ssl_enable=NO
EOF
  systemctl enable --now vsftpd

  # ----- Nginx default site -------------------------------------
  cp /etc/nginx/sites-available/default{,.bak.$(date +%s)}
  sed -Ei "s#root [^;]*;#root $ftp_root;#" /etc/nginx/sites-available/default
  sed -Ei "s/listen [0-9]+ default_server;/listen ${nginx_port} default_server;/" /etc/nginx/sites-available/default
  sed -Ei "s/listen \[::\]:[0-9]+ default_server;/listen [::]:${nginx_port} default_server;/" /etc/nginx/sites-available/default
  systemctl enable --now nginx

  echo -e "\n[OK] Stack pronta!\n  • FTP  : ftp://<IP>:${ftp_port}/ (PASV ${pasv_min}-${pasv_max})\n  • HTTP : http://<IP>:${nginx_port}/  (root → $ftp_root)"
}

# ---------------- Uninstall -------------------------------------
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
  REMOVE vsftpd nginx openssl
  CLEAN
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
