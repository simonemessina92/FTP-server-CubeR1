#!/bin/bash

set -e

echo "🔧 Aggiornamento pacchetti..."
sudo apt update && sudo apt upgrade -y

echo "🔧 Installazione pacchetti base..."
sudo apt install -y curl wget htop net-tools nload avahi-daemon gnupg2 ca-certificates lsb-release software-properties-common tigervnc-standalone-server tigervnc-common

echo "🔧 Installazione Google Chrome..."
wget -q -O chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install -y ./chrome.deb || sudo apt --fix-broken install -y
rm chrome.deb

echo "🔧 Installazione VLC..."
sudo apt install -y vlc

echo "🔧 Installazione Docker..."
curl -fsSL https://get.docker.com | sudo bash

echo "🔧 Installazione Flatpak e OBS Studio..."
sudo apt install -y flatpak gnome-software-plugin-flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub com.obsproject.Studio

echo "🔧 Configurazione TigerVNC..."
mkdir -p ~/.vnc
echo "password" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

cat <<EOF > ~/.vnc/xstartup
#!/bin/sh
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
vncconfig -iconic &
gnome-session &
EOF

chmod +x ~/.vnc/xstartup

cat <<EOF | sudo tee /etc/systemd/system/vncserver@.service
[Unit]
Description=Start TigerVNC server at startup for %i
After=network.target

[Service]
Type=forking
User=%i
PAMName=login
PIDFile=/home/%i/.vnc/%H:1.pid
ExecStartPre=-/usr/bin/vncserver -kill :1 > /dev/null 2>&1
ExecStart=/usr/bin/vncserver :1
ExecStop=/usr/bin/vncserver -kill :1

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable vncserver@${USER}

echo "✅ Installazione completata. Riavvia il sistema e connettiti via VNC sulla porta 5901 con TightVNC o TigerVNC Viewer."
