#!/bin/bash

# ==============================================
#   Instalador KIOSK PRO (parametrizável)
#   Uso:
#     sudo ./instalar-kiosk-pro.sh "URL" 300
# ==============================================

# -----------------------------
# 1. Captura dos parâmetros
# -----------------------------
URL="$1"
REFRESH="$2"

# Valores padrão, caso o usuário não informe
[[ -z "$URL" ]] && URL="https://projetos.wonit.com.br/?token=4bd6424d821161f0aebd6f3a43922d3a"
[[ -z "$REFRESH" ]] && REFRESH=300    # 5 minutos

SERVICE="/etc/systemd/system/kiosk.service"
LOADING_HTML="/home/pi/loading.html"


echo "--------------------------------------"
echo " KIOSK PRO - WONIT"
echo "--------------------------------------"
echo "URL configurada........: $URL"
echo "Auto refresh...........: $REFRESH segundos"
echo "--------------------------------------"
sleep 2

echo "🔧 Instalando dependências..."
sudo apt update
sudo apt install -y chromium-browser xserver-xorg x11-xserver-utils lxde raspberrypi-ui-mods --no-install-recommends


# -----------------------------
# 2. Criar tela de loading
# -----------------------------
echo "📝 Criando tela de loading..."

cat > $LOADING_HTML <<EOF
<html>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Carregando...</title>
<style>
body {
    background: #ffffff;
    color: black;
    font-family: Arial, sans-serif;
    text-align: center;
    margin-top: 20%;
}
.loader {
  border: 10px solid #a3a3a3;
  border-top: 10px solid #00aaff;
  border-radius: 50%;
  width: 70px;
  height: 70px;
  animation: spin 1.2s linear infinite;
  margin: auto;
}
@keyframes spin {
  0% { transform: rotate(0deg);}
  100% { transform: rotate(360deg);}
}
</style>

<div class="loader"></div>
<h2>Carregando dashboard...</h2>
</html>
EOF


# -----------------------------
# 3. Criar script principal
# -----------------------------
echo "📝 Criando script kiosk-start.sh..."

cat > /home/pi/kiosk-start.sh <<EOF
#!/bin/bash

URL="$URL"
REFRESH_SECONDS=$REFRESH
PING_INTERVAL=10

# Tela de loading
chromium-browser --app="file:///home/pi/loading.html" &
sleep 5

# Iniciar Chromium
chromium-browser \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-translate \
  --disable-features=TranslateUI \
  --kiosk "\$URL" &

BROWSER_PID=\$!
echo "Chromium rodando PID \$BROWSER_PID"

# Loop watchdog + auto-refresh
while true; do

    # WATCHDOG – testa URL
    if ! curl -s --head --request GET "\$URL" | grep "200 OK" > /dev/null; then
        echo "⚠ URL caiu! Reiniciando Chromium..."
        kill \$BROWSER_PID
        sleep 2
        chromium-browser --kiosk "\$URL" &
        BROWSER_PID=\$!
    fi

    # AUTO REFRESH (Ctrl+R)
    echo "🔄 Auto refresh executado"
    xdotool search --onlyvisible --class "chromium" key "ctrl+r"

    sleep \$REFRESH_SECONDS
done
EOF

chmod +x /home/pi/kiosk-start.sh


# -----------------------------
# 4. Criar serviço systemd
# -----------------------------
echo "📝 Criando serviço systemd..."

sudo bash -c "cat > $SERVICE" <<EOF
[Unit]
Description=Kiosk PRO - Wonit
After=systemd-user-sessions.service network-online.target graphical.target
Wants=network-online.target

[Service]
User=pi
Environment=XAUTHORITY=/home/pi/.Xauthority
Environment=DISPLAY=:0

ExecStart=/home/pi/kiosk-start.sh
Restart=always
RestartSec=5

[Install]
WantedBy=graphical.target
EOF


echo "📦 Recarregando systemd..."
sudo systemctl daemon-reload

echo "⚙️ Ativando serviço kiosk..."
sudo systemctl enable kiosk.service

echo "🎉 INSTALAÇÃO COMPLETA!"
echo "➡ Reinicie agora: sudo reboot"
