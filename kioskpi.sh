#!/bin/bash

# ================================
#  Kiosk Wonit - Raspberry Pi Zero 2 W
# ================================

URL=""
SERVICE="/etc/systemd/system/kiosk.service"

echo "🔧 Atualizando o sistema..."
sudo apt update
sudo apt install -y chromium-browser xserver-xorg x11-xserver-utils lxde raspberrypi-ui-mods --no-install-recommends

echo "🧹 Limpando qualquer kiosk antigo..."
sudo systemctl stop kiosk.service 2>/dev/null
sudo systemctl disable kiosk.service 2>/dev/null
sudo rm -f "$SERVICE"

echo "📝 Criando serviço kiosk..."

sudo bash -c "cat > $SERVICE" <<EOF
[Unit]
Description=Kiosk Mode
After=systemd-user-sessions.service network-online.target graphical.target
Wants=network-online.target

[Service]
User=pi
Environment=XAUTHORITY=/home/pi/.Xauthority
Environment=DISPLAY=:0

ExecStart=/usr/bin/chromium-browser \\
  --noerrdialogs \\
  --disable-infobars \\
  --disable-session-crashed-bubble \\
  --disable-translate \\
  --disable-features=TranslateUI \\
  --kiosk \\
  $URL

Restart=always
RestartSec=5

[Install]
WantedBy=graphical.target
EOF

echo "📦 Recarregando serviços..."
sudo systemctl daemon-reload

echo "⚙️ Ativando kiosk..."
sudo systemctl enable kiosk.service

echo "🚀 Instalação concluída!"
echo "➡ Reinicie para iniciar o modo kiosk automaticamente."
echo "🔄 Comando: sudo reboot"
