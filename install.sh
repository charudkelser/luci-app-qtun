#!/bin/sh

# =========================================================
# QTUN SMART INSTALLER
# Version : 2.0.0
# Project : luci-app-qtun
# Support : OpenWrt 21.02 / 22.03 / 23.05 / 24.10
# =========================================================

VERSION="1.0.6"
REPO="charudkelser/luci-app-qtun"
BASE_URL="https://github.com/$REPO/releases/download/v$VERSION"

TMP_DIR="/tmp"
PACKAGE_FILE="$TMP_DIR/luci-app-qtun_${VERSION}.ipk"
LOG_FILE="$TMP_DIR/qtun-install.log"
BACKUP_DIR="$TMP_DIR/qtun-backup"

# =========================================================
# COLORS
# =========================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'
BOLD='\033[1m'

# =========================================================
# SYMBOLS
# =========================================================

CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
ARROW="${CYAN}➜${NC}"

# =========================================================
# VARIABLES
# =========================================================

BEST_ARCH=""
BEST_PRIORITY=""
SELECTED_PACKAGE=""
SELECTED_URL=""
OPENWRT_VERSION=""
OPENWRT_BRANCH=""
OPENWRT_ARCH=""
PACKAGE_INSTALLED=0

# =========================================================
# UI FUNCTIONS
# =========================================================

banner() {
    clear

    echo
    printf "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                                                        ║"
    echo "║                 QTUN SMART INSTALLER                   ║"
    echo "║                      Version 2.0                       ║"
    echo "║                                                        ║"
    echo "╚════════════════════════════════════════════════════════╝"
    printf "${NC}"
    echo
}

line() {
    printf "${GRAY}────────────────────────────────────────────────────────${NC}\n"
}

success() {
    printf "  ${GREEN}✓${NC} %s\n" "$1"
}

error_msg() {
    printf "  ${RED}✗${NC} %s\n" "$1"
}

warning() {
    printf "  ${YELLOW}!${NC} %s\n" "$1"
}

info() {
    printf "  ${CYAN}➜${NC} %s\n" "$1"
}

# =========================================================
# OPENWRT DETECTION
# =========================================================

detect_openwrt() {

    if [ ! -f /etc/openwrt_release ]; then
        error_msg "OpenWrt tidak terdeteksi."
        return 1
    fi

    . /etc/openwrt_release

    OPENWRT_VERSION="$DISTRIB_RELEASE"
    OPENWRT_ARCH="$DISTRIB_ARCH"

    [ -z "$OPENWRT_ARCH" ] && OPENWRT_ARCH="$(uname -m)"
