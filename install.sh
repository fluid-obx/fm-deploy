#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="settings/.env"

if [[ -f "$ENV_FILE" ]]; then
  # Temporarily relax undefined-variable checks
  set +u
  set -o allexport
  source "$ENV_FILE"
  set +o allexport
  set -u
  echo "Loaded environment variables from $ENV_FILE"
else
  echo "No .env file found at $ENV_FILE"
fi

###############################################################################
# Detect installed FileMaker Server and compare versions (normalized)
###############################################################################
echo -e "🔍 Checking existing FileMaker Server installation and version..."

FMS_PACKAGE_NAME="filemaker-server"
INSTALLED_VERSION=""

if dpkg -s "$FMS_PACKAGE_NAME" 2>/dev/null | grep -q "Status: install ok installed"; then
    FMS_ALREADY_INSTALLED=true
    INSTALLED_VERSION=$(dpkg -s "$FMS_PACKAGE_NAME" | grep '^Version:' | awk '{print $2}')
    echo -e "✔ FileMaker Server is installed. Full version: ${INSTALLED_VERSION}"
else
    FMS_ALREADY_INSTALLED=false
    echo -e "✖ FileMaker Server is NOT installed."
fi

###############################################################################
# Version normalization
# Purpose: FMS debs often include build numbers (22.0.2.223)
# .env typically uses major.minor.patch (22.0.2)
# We must strip build numbers before comparison.
###############################################################################

normalize_version() {
    # Returns first 3 components (major.minor.patch)
    echo "$1" | cut -d'.' -f1-3
}

if [[ "$FMS_ALREADY_INSTALLED" = true ]]; then
    NORMALIZED_INSTALLED_VERSION=$(normalize_version "$INSTALLED_VERSION")
else
    NORMALIZED_INSTALLED_VERSION="0.0.0"
fi

NORMALIZED_INSTALLER_VERSION=$(normalize_version "$FMS_VERSION")

echo -e "🧮 Comparing normalized versions:"
echo -e "    Installer version: ${NORMALIZED_INSTALLER_VERSION} (from .env)"
echo -e "    Installed version: ${NORMALIZED_INSTALLED_VERSION} (normalized from ${INSTALLED_VERSION})"

###############################################################################
# Version comparison decision tree (normalized compare)
###############################################################################
if [[ "$FMS_ALREADY_INSTALLED" = true ]]; then

    # Case 1: Same version = skip
    if dpkg --compare-versions "$NORMALIZED_INSTALLER_VERSION" eq "$NORMALIZED_INSTALLED_VERSION"; then
        echo -e "⏭  Versions match (major.minor.patch). Skipping installation."
        exit 0
    fi

    # Case 2: Installer older = skip
    if dpkg --compare-versions "$NORMALIZED_INSTALLER_VERSION" lt "$NORMALIZED_INSTALLED_VERSION"; then
        echo -e "⏭  Installer (${NORMALIZED_INSTALLER_VERSION}) is older than installed (${NORMALIZED_INSTALLED_VERSION})."
        echo -e "    Downgrade prevented — skipping installation."
        exit 0
    fi

    # Case 3: Installer newer = upgrade
    if dpkg --compare-versions "$NORMALIZED_INSTALLER_VERSION" gt "$NORMALIZED_INSTALLED_VERSION"; then
        echo -e "♻  Newer version detected. Proceeding with reinstall/upgrade..."
    fi

else
    echo -e "🆕 No existing FileMaker Server found — performing fresh install..."
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

PROJECT_ASSISTED_INSTALL="./settings/Assisted Install.txt"
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
FM_ASSISTED_INSTALL=/install apt install -y "$INSTALLER_FILE" \
  | tee /share/logs/fms_install.log

# FMS post-install service behavior
/bin/systemctl start fmshelper.service
rm -f "$DEST_ASSISTED_INSTALL"

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