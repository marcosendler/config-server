#!/usr/bin/env bash
set -euo pipefail

### ===================================================
### CONFIGS (pode sobrescrever via env)
### ===================================================
ZBX_SERVER_IP="${ZBX_SERVER_IP:-172.16.2.178}"
ZBX_SERVER_ACTIVE="${ZBX_SERVER_ACTIVE:-$ZBX_SERVER_IP}"
ZBX_HOSTNAME="${ZBX_HOSTNAME:-$(hostname -f)}"
ZBX_PORT="${ZBX_PORT:-10050}"

log()  { echo -e "[\e[1;34mINFO\e[0m] $*"; }
warn() { echo -e "[\e[1;33mWARN\e[0m] $*"; }
fail() { echo -e "[\e[1;31mERRO\e[0m] $*"; exit 1; }

detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="${ID,,}"
    OS_VER="${VERSION_ID%%.*}"
    OS_CODENAME="${VERSION_CODENAME:-}"
    echo "$OS_ID:$OS_VER:$OS_CODENAME"
  elif [[ -f /etc/centos-release ]]; then
    echo "centos:7"
  else
    fail "NÃ£o foi possÃ­vel detectar o sistema operacional."
  fi
}

install_repo() {
  local ID="$1" VER="$2" CODENAME="$3"
  local SERIES=""  # 6.0 ou 7.0
  local PKG="" URL=""

  log "Detectado $ID $VER (${CODENAME:-sem-codename})"

  case "$ID" in
    debian)
      case "$CODENAME" in
        bullseye) SERIES="6.0"; PKG="zabbix-release_${SERIES}-1+debian11_all.deb"; URL="https://repo.zabbix.com/zabbix/${SERIES}/debian/pool/main/z/zabbix-release/${PKG}" ;;
        bookworm) SERIES="7.0"; PKG="zabbix-release_${SERIES}-1+debian12_all.deb"; URL="https://repo.zabbix.com/zabbix/${SERIES}/debian/pool/main/z/zabbix-release/${PKG}" ;;
        trixie) SERIES="7.4" PKG="zabbix-release_latest_${SERIES}+debian13_all.deb" URL="https://repo.zabbix.com/zabbix/${SERIES}/release/debian/pool/main/z/zabbix-release/${PKG}" ;;
        *) SERIES="7.0" PKG="zabbix-release_${SERIES}-1+debian12_all.deb" URL="https://repo.zabbix.com/zabbix/${SERIES}/debian/pool/main/z/zabbix-release/${PKG}" warn "Debian ${CODENAME:-$VER} nÃ£o reconhecido; usando repo de Debian 12 (compatÃ­vel)." ;;
      esac
      wget -q "$URL" -O "/tmp/${PKG}"
      dpkg -i "/tmp/${PKG}"
      apt-get update -y
      ;;

    ubuntu)
      case "$CODENAME" in
        focal)     SERIES="6.0"; PKG="zabbix-release_${SERIES}-1+ubuntu20.04_all.deb"; URL="https://repo.zabbix.com/zabbix/${SERIES}/ubuntu/pool/main/z/zabbix-release/${PKG}" ;;
        jammy)     SERIES="7.0"; PKG="zabbix-release_latest_${SERIES}+ubuntu22.04_all.deb"; URL="https://repo.zabbix.com/zabbix/${SERIES}/ubuntu/pool/main/z/zabbix-release/${PKG}" ;;
        noble|*)   SERIES="7.0"; PKG="zabbix-release_latest_${SERIES}+ubuntu24.04_all.deb"; URL="https://repo.zabbix.com/zabbix/${SERIES}/ubuntu/pool/main/z/zabbix-release/${PKG}" ;;
      esac
      wget -q "$URL" -O "/tmp/${PKG}"
      dpkg -i "/tmp/${PKG}"
      apt-get update -y
      ;;

    centos|rhel)
      SERIES="7.0"
      rpm -Uvh "https://repo.zabbix.com/zabbix/${SERIES}/rhel/7/x86_64/zabbix-release-${SERIES}-1.el7.noarch.rpm"
      yum clean all -y
      ;;

    *)
      fail "Sistema nÃ£o suportado: $ID"
      ;;
  esac

  # Exporta a sÃ©rie escolhida para outras funÃ§Ãµes (apenas se precisar no futuro)
  export ZBX_SERIES="${SERIES}"
}

install_agent() {
  if command -v apt-get &>/dev/null; then
    log "Instalando zabbix-agent (via apt)"
    DEBIAN_FRONTEND=noninteractive apt-get install -y zabbix-agent
  elif command -v yum &>/dev/null; then
    log "Instalando zabbix-agent (via yum)"
    yum install -y zabbix-agent
  else
    fail "Gerenciador de pacotes nÃ£o suportado."
  fi
}

configure_agent() {
  local CONF="/etc/zabbix/zabbix_agentd.conf"
  local DIR="/etc/zabbix/zabbix_agentd.conf.d"

  mkdir -p "$DIR"
  # Garante que o include exista (evita o erro 'No such file or directory')
  if ! grep -q "^Include=" "$CONF"; then
    echo "Include=${DIR}/*.conf" >> "$CONF"
  fi

  log "Configurando ${CONF}"
  sed -i "s/^Server=.*/Server=${ZBX_SERVER_IP}/" "$CONF" || true
  sed -i "s/^ServerActive=.*/ServerActive=${ZBX_SERVER_ACTIVE}/" "$CONF" || true
  sed -i "s/^Hostname=.*/Hostname=${ZBX_HOSTNAME}/" "$CONF" || true
  if grep -q "^# ListenPort=" "$CONF"; then
    sed -i "s/^# ListenPort=.*/ListenPort=${ZBX_PORT}/" "$CONF"
  else
    # se nÃ£o existir a linha comentada, garanta a diretiva
    if ! grep -q "^ListenPort=" "$CONF"; then
      echo "ListenPort=${ZBX_PORT}" >> "$CONF"
    fi
  fi
  sed -i "s|^# Include=.*|Include=${DIR}/*.conf|" "$CONF" || true

  chown -R zabbix:zabbix /etc/zabbix || true
}

start_service() {
  log "Habilitando e iniciando o serviÃ§o"
  if command -v systemctl &>/dev/null; then
    systemctl daemon-reload || true
    systemctl enable --now zabbix-agent
    systemctl status zabbix-agent --no-pager -n 10 || true
  else
    service zabbix-agent start
  fi
}

test_agent() {
  log "Teste local: zabbix_agentd -t agent.ping"
  zabbix_agentd -t agent.ping || true
  log "Se o servidor tiver 'zabbix_get', teste remoto com:"
  echo "  zabbix_get -s $(hostname -I | awk '{print $1}') -k agent.ping"
}

### ===================================================
### EXECUÃ‡ÃƒO
### ===================================================
log "Detectando sistema operacional..."
IFS=: read -r OS_ID OS_VER OS_CODENAME <<<"$(detect_os)"
install_repo "$OS_ID" "$OS_VER" "$OS_CODENAME"
install_agent
configure_agent
start_service
test_agent
log "âœ… InstalaÃ§Ã£o concluÃ­da! Hostname: ${ZBX_HOSTNAME}"
