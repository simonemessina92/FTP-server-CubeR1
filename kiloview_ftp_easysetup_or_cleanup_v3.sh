#!/usr/bin/env bash
# ============================================================================
#  Script: setup_ftp_nginx.sh
#  Autore: ChatGPT per Sem (Tecnico Broadcasting AVoIP)
#  Scopo : Installare o disinstallare in modo interattivo un server FTP (vsftpd)
#          e un web‑server (Nginx) su una VM Linux (Debian/Ubuntu‑like).
#          • INSTALL: crea un utente FTP, imposta la password, configura vsftpd,
#            installa Nginx e chiede la porta d'ascolto.
#          • UNINSTALL: rimuove i pacchetti, cancella l'utente e (opzionale)
#            effettua il backup dei file caricati in /root/BCKP.
#  Uso   : eseguire come root → sudo ./setup_ftp_nginx.sh
# ============================================================================

set -euo pipefail

# --- Funzioni di utilità ----------------------------------------------------
need_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "[ERRORE] Devi eseguire questo script come root." >&2
        exit 1
    fi
}

prompt_yes_no() {
    # $1 = domanda
    local response
    while true; do
        read -rp "$1 (y/n): " response
        case $response in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Rispondi con 'y' o 'n'." ;;
        esac
    done
}

backup_folder="/root/BCKP"

# --- INSTALLAZIONE ----------------------------------------------------------
install_stack() {
    echo "========== INSTALLAZIONE =========="
    apt update
    apt install -y vsftpd nginx

    # --- Creazione utente FTP ---------------------------------------------
    while true; do
        read -rp "Nome nuovo utente FTP: " ftp_user
        [[ -n $ftp_user ]] && break
        echo "Il nome utente non può essere vuoto."
    done

    if id "$ftp_user" &>/dev/null; then
        echo "[ERRORE] L'utente $ftp_user esiste già. Interrompo."
        exit 1
    fi

    read -rsp "Password per $ftp_user: " ftp_pass; echo
    adduser --disabled-password --gecos "" "$ftp_user"
    echo "$ftp_user:$ftp_pass" | chpasswd

    # --- Configurazione vsftpd ---------------------------------------------
    cp /etc/vsftpd.conf /etc/vsftpd.conf.bak.$(date +%F_%H-%M-%S)
    cat >/etc/vsftpd.conf <<'VSFTP'
listen=YES
listen_port=21
anonymous_enable=NO
local_enable=YES
write_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES
utf8_filesystem=YES
pasv_enable=YES
pasv_min_port=21100
pasv_max_port=21110
user_sub_token=$USER
local_root=/home/$USER
ssl_enable=NO
VSFTP
    systemctl restart vsftpd

    # --- Installazione & configurazione Nginx ------------------------------
    read -rp "Porta HTTP per Nginx (default 80): " nginx_port
    nginx_port=${nginx_port:-80}

    sed -i.bak.$(date +%F_%H-%M-%S) \
        -e "s/^\s*listen \([0-9]*\) default_server;/listen ${nginx_port} default_server;/" \
        -e "s/^\s*listen \([0-9]*\) \[::\]:\1 default_server;/listen ${nginx_port} [::]:${nginx_port} default_server;/" \
        /etc/nginx/sites-available/default

    systemctl reload nginx

    echo "[OK] Installazione completata."
    echo "Puoi caricare i tuoi file in /home/$ftp_user e vederli su http://<IP>:$nginx_port/"
}

# --- DISINSTALLAZIONE -------------------------------------------------------
uninstall_stack() {
    echo "========== DISINSTALLAZIONE =========="
    read -rp "Quale utente FTP vuoi rimuovere? " ftp_user

    if ! id "$ftp_user" &>/dev/null; then
        echo "[ERRORE] L'utente $ftp_user non esiste." >&2
        exit 1
    fi

    if prompt_yes_no "Vuoi fare il backup di /home/$ftp_user prima di cancellare?"; then
        mkdir -p "$backup_folder"
        tar czf "$backup_folder/${ftp_user}_backup_$(date +%F_%H-%M-%S).tar.gz" "/home/$ftp_user"
        echo "Backup salvato in $backup_folder."
    fi

    userdel -r "$ftp_user"

    apt purge -y vsftpd nginx
    apt autoremove -y --purge

    echo "[OK] Disinstallazione completata."
}

# --- MAIN MENU -------------------------------------------------------------
need_root

echo "========================================="
echo "  Script di Installazione/Disinstallazione"
echo "========================================="
echo "1) Installa FTP + Nginx"
echo "2) Disinstalla FTP + Nginx"
echo "3) Esci"

read -rp "Selezione (1/2/3): " choice
case $choice in
    1) install_stack ;;
    2) uninstall_stack ;;
    3) echo "Uscita."; exit 0 ;;
    *) echo "Scelta non valida."; exit 1 ;;
fi
