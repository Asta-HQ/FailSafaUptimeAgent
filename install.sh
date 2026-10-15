#!/usr/bin/env bash
set -e

REPO_NAME="Asta-HQ/FailSafaUptimeAgent"
INSTALL_PATH="/usr/local/bin/failsafe-agent"

# Farben für saubere Konsolenausgaben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Root-Rechte prüfen
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Fehler: Bitte führe dieses Skript mit sudo aus! (sudo ./install.sh ...)${NC}"
  exit 1
fi

TOKEN=""
SERVER=""

# Argumente parsen
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --token) TOKEN="$2"; shift ;;
        --server) SERVER="$2"; shift ;;
        *) echo -e "${RED}Unbekannter Parameter: $1${NC}"; exit 1 ;;
    esac
    shift
done

echo "Erkenne System-Architektur..."
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

if [ "$ARCH" = "x86_64" ]; then
    ARCH="amd64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    ARCH="arm64"
else
    echo -e "${RED}Nicht unterstützte Architektur: $ARCH${NC}"
    exit 1
fi

ASSET_NAME="failsafe_agent-${OS}-${ARCH}"
DOWNLOAD_URL="https://github.com/${REPO_NAME}/releases/latest/download/${ASSET_NAME}"

echo "Lade neusten Agenten herunter von GitHub (${ASSET_NAME})..."
curl -sL -o "$INSTALL_PATH" "$DOWNLOAD_URL"
chmod +x "$INSTALL_PATH"

echo -e "${GREEN}Binary erfolgreich unter $INSTALL_PATH gespeichert!${NC}"

# Service nur installieren, wenn ein Token übergeben wurde
if [ -n "$TOKEN" ]; then
    echo "Richte systemd-Dienst ein..."
    INSTALL_CMD="$INSTALL_PATH --service install --token \"$TOKEN\""
    if [ -n "$SERVER" ]; then
        INSTALL_CMD="$INSTALL_CMD --server \"$SERVER\""
    fi

    eval "$INSTALL_CMD"
    echo -e "${GREEN}Failsafe Agent wurde als systemd-Dienst installiert und gestartet!${NC}"
else
    echo -e "${YELLOW}Hinweis: Kein --token angegeben. Der systemd-Dienst wurde NICHT installiert.${NC}"
    echo "Du kannst den Agenten jetzt direkt ausführen mit:"
    echo "  failsafe-agent --token \"dein-token\""
    echo "Oder den Dienst nachträglich installieren mit:"
    echo "  sudo failsafe-agent --service install --token \"dein-token\""
fi