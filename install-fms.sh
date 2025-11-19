#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="./.env"

if [[ -f "$ENV_FILE" ]]; then
  # Temporarily relax undefined-variable checks
  set +u
  set -o allexport
  source "$ENV_FILE"
  set +o allexport
  set -u
  log "Loaded environment variables from $ENV_FILE"
else
  log "No .env file found at $ENV_FILE"
fi

###############################################################################
# Check installer
###############################################################################
echo -e "🔍 Checking installer..."

INSTALLER_FILE=$(find "$FMS_INSTALLER_PATH" -name "*$FMS_INSTALLER*.deb" | head -n1)
if [[ -z "$INSTALLER_FILE" ]]; then
  echo -e "✋ Installer .deb file not found in $FMS_INSTALLER_PATH."
  exit 1
fi

###############################################################################
# Use existing Assisted Install.txt from project
###############################################################################
echo -e "📝 Copying Assisted Install.txt..."

PROJECT_ASSISTED_INSTALL="./Assisted Install.txt"
DEST_ASSISTED_INSTALL="$FMS_INSTALLER_PATH/Assisted Install.txt"

if [[ ! -f "$PROJECT_ASSISTED_INSTALL" ]]; then
  echo -e "✋ Assisted Install.txt not found in project folder: $PROJECT_ASSISTED_INSTALL"
  exit 1
fi

cp -f "$PROJECT_ASSISTED_INSTALL" "$DEST_ASSISTED_INSTALL"

echo -e "📄 Assisted Install.txt copied to $DEST_ASSISTED_INSTALL"

###############################################################################
# Install FileMaker Server
###############################################################################
echo -e "🧰 Installing FileMaker Server..."
echo "Logs: /share/logs/fms_install.log"

apt update -y
FM_ASSISTED_INSTALL=/install apt install -y "/install/$INSTALLER_FILE" \
  | tee /share/logs/fms_install.log

# FMS post-install service behavior
/bin/systemctl start fmshelper.service

###############################################################################
# Health check for fmshelper.service
###############################################################################
echo -e "🔎 Checking fmshelper.service health..."
if ! systemctl is-active --quiet fmshelper.service; then
  echo -e "✋ fmshelper.service is NOT healthy. Gathering logs..."
  HEALTH_LOG="/share/logs/fmshelper_health.log"
  {
    echo '==== fmshelper.service status ===='
    systemctl status fmshelper.service --no-pager --full || true
    echo
    echo '==== Recent journal ===='
    journalctl -u fmshelper.service -n 200 --no-pager || true
  } | tee "$HEALTH_LOG"
  echo -e "📄 Health details logged to $HEALTH_LOG"
  exit 92
fi
echo -e "✅ fmshelper.service is healthy."

###############################################################################
# Install OttoFMS
###############################################################################
echo -e "🌐 Installing OttoFMS..."
echo "Logs: /share/logs/ottofms_install.log"

curl -sSL "https://downloads.ottomatic.cloud/ottofms/install-scripts/install-linux.sh" \
  | bash > /share/logs/ottofms_install.log 2>&1 \
  || echo -e "✋ OttoFMS installer reported failure — check logs."

###############################################################################
# Health check for OttoFMS
###############################################################################
echo -e "🔎 Verifying ottofms-proofgeist-com.service health..."
if ! systemctl is-active --quiet ottofms-proofgeist-com.service; then
  echo -e "✋ ottofms-proofgeist-com.service is NOT healthy. Gathering diagnostics..."
  OTTO_HEALTH_LOG="/share/logs/ottofms_service_health.log"
  {
    echo '==== ottofms-proofgeist-com.service status ===='
    systemctl status ottofms-proofgeist-com.service --no-pager --full || true
    echo
    echo '==== Recent journal ===='
    journalctl -u ottofms-proofgeist-com.service -n 200 --no-pager || true
  } | tee "$OTTO_HEALTH_LOG"
  echo -e "📄 Health details logged to $OTTO_HEALTH_LOG"
  exit 92
fi

echo -e "✅ ottofms-proofgeist-com.service is healthy."