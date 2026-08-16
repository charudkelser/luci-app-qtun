#!/bin/sh

# =========================================================
# QTUN SMART INSTALLER
# Version : 2.0.0
# Project : luci-app-qtun
# OpenWrt : 21.02 / 22.03 / 23.05 / 24.10
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

CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
ARROW="${CYAN}➜${NC}"

# =========================================================
# GLOBAL VARIABLES
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
# BASIC FUNCTIONS
# =========================================================

pause_screen() {
    echo
    printf "${GRAY}Press Enter to continue...${NC}"
    read dummy
}

line() {
    printf "${GRAY}────────────────────────────────────────────────────────${NC}\n"
}

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

    case "$OPENWRT_VERSION" in

        21.02*)
            OPENWRT_BRANCH="21.02"
            ;;

        22.03*)
            OPENWRT_BRANCH="22.03"
            ;;

        23.05*)
            OPENWRT_BRANCH="23.05"
            ;;

        24.10*)
            OPENWRT_BRANCH="24.10"
            ;;

        *)
            OPENWRT_BRANCH="$OPENWRT_VERSION"
            ;;

    esac

    return 0
}

# =========================================================
# PACKAGE MANAGER
# =========================================================

check_opkg() {

    if command -v opkg >/dev/null 2>&1; then
        success "Package manager : opkg"
        return 0
    fi

    error_msg "opkg tidak ditemukan."
    return 1
}

# =========================================================
# ARCHITECTURE DETECTION
# =========================================================

detect_architecture() {

    BEST_ARCH=""
    BEST_PRIORITY=""

    while read -r TYPE ARCH PRIORITY
    do

        [ "$TYPE" = "arch" ] || continue
        [ "$ARCH" = "all" ] && continue

        if [ -z "$BEST_PRIORITY" ]; then

            BEST_ARCH="$ARCH"
            BEST_PRIORITY="$PRIORITY"

        elif [ "$PRIORITY" -gt "$BEST_PRIORITY" ]; then

            BEST_ARCH="$ARCH"
            BEST_PRIORITY="$PRIORITY"

        fi

    done <<EOF
$(opkg print-architecture 2>/dev/null)
EOF

    if [ -z "$BEST_ARCH" ]; then

        error_msg "Architecture opkg tidak ditemukan."
        return 1

    fi

    return 0
}

# =========================================================
# SYSTEM INFORMATION
# =========================================================

show_system_info() {

    echo
    printf "${WHITE}${BOLD}System Information${NC}\n"
    line

    success "OpenWrt       : $OPENWRT_VERSION"
    success "Branch        : $OPENWRT_BRANCH"
    success "Machine       : $(uname -m)"
    success "Architecture   : $BEST_ARCH"
    success "Priority       : $BEST_PRIORITY"

    echo
}

# =========================================================
# INTERNET CHECK
# =========================================================

check_internet() {

    info "Checking internet connection..."

    if ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then

        success "Internet connection available."
        return 0

    fi

    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then

        success "Internet connection available."
        return 0

    fi

    error_msg "Tidak ada koneksi internet."
    return 1
}

# =========================================================
# DISK CHECK
# =========================================================

check_disk() {

    AVAILABLE="$(df /tmp 2>/dev/null | awk 'NR==2 {print $4}')"

    if [ -z "$AVAILABLE" ]; then
        warning "Tidak dapat membaca kapasitas /tmp."
        return 0
    fi

    REQUIRED=50000

    if [ "$AVAILABLE" -lt "$REQUIRED" ]; then

        error_msg "Ruang /tmp tidak mencukupi."
        echo "  Required : ${REQUIRED} KB"
        echo "  Available: ${AVAILABLE} KB"

        return 1
    fi

    success "Disk space OK."
    return 0
}

# =========================================================
# CHECK EXISTING QTUN
# =========================================================

check_existing() {

    PACKAGE_INSTALLED=0

    if opkg status luci-app-qtun 2>/dev/null | grep -q "Status:.*installed"; then
        PACKAGE_INSTALLED=1
        return 0
    fi

    if [ -d /etc/qtun ]; then
        PACKAGE_INSTALLED=1
        return 0
    fi

    return 0
}

# =========================================================
# PACKAGE SEARCH
# =========================================================

find_package() {

    SPECIFIC_PACKAGE="luci-app-qtun_${VERSION}_${BEST_ARCH}.ipk"
    SPECIFIC_URL="$BASE_URL/$SPECIFIC_PACKAGE"

    UNIVERSAL_PACKAGE="luci-app-qtun_${VERSION}_all.ipk"
    UNIVERSAL_URL="$BASE_URL/$UNIVERSAL_PACKAGE"

    echo
    info "Checking QTUN package..."

    if wget --no-check-certificate \
        --spider \
        -q \
        "$SPECIFIC_URL" 2>/dev/null
    then

        SELECTED_PACKAGE="$SPECIFIC_PACKAGE"
        SELECTED_URL="$SPECIFIC_URL"

        success "Compatible package found:"
        echo "      $SELECTED_PACKAGE"

        return 0
    fi

    warning "Architecture-specific package tidak ditemukan."

    if wget --no-check-certificate \
        --spider \
        -q \
        "$UNIVERSAL_URL" 2>/dev/null
    then

        SELECTED_PACKAGE="$UNIVERSAL_PACKAGE"
        SELECTED_URL="$UNIVERSAL_URL"

        success "Universal package found:"
        echo "      $SELECTED_PACKAGE"

        return 0
    fi

    error_msg "QTUN package yang kompatibel tidak ditemukan."

    return 1
}

# =========================================================
# UPDATE OPKG
# =========================================================

update_packages() {

    echo
    info "Updating package lists..."
    echo

    if opkg update >>"$LOG_FILE" 2>&1; then

        success "Package lists updated."
        return 0

    fi

    warning "opkg update gagal."

    return 1
}

# =========================================================
# DOWNLOAD
# =========================================================

download_package() {

    echo
    info "Downloading QTUN..."
    echo "      $SELECTED_PACKAGE"
    echo

    rm -f "$PACKAGE_FILE"

    wget --no-check-certificate \
        -O "$PACKAGE_FILE" \
        "$SELECTED_URL" 2>&1 | tee -a "$LOG_FILE"

    if [ $? -ne 0 ] || [ ! -s "$PACKAGE_FILE" ]; then

        error_msg "Download QTUN gagal."
        rm -f "$PACKAGE_FILE"

        return 1
    fi

    success "Download completed."

    return 0
}

# =========================================================
# IPK VALIDATION
# =========================================================

validate_ipk() {

    echo
    info "Validating IPK package..."

    if ! tar -tf "$PACKAGE_FILE" >/dev/null 2>&1; then

        error_msg "IPK tidak dapat dibaca."
        return 1
    fi

    LIST="$(tar -tf "$PACKAGE_FILE" 2>/dev/null)"

    if ! echo "$LIST" | grep -q "^debian-binary$"; then

        error_msg "debian-binary tidak ditemukan."
        return 1
    fi

    if ! echo "$LIST" | grep -q "^control.tar.gz$"; then

        error_msg "control.tar.gz tidak ditemukan."
        return 1
    fi

    if ! echo "$LIST" | grep -q "^data.tar.gz$"; then

        error_msg "data.tar.gz tidak ditemukan."
        return 1
    fi

    success "IPK package valid."

    return 0
}

# =========================================================
# BACKUP
# =========================================================

backup_config() {

    rm -rf "$BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    if [ -d /etc/qtun ]; then

        cp -a /etc/qtun "$BACKUP_DIR/" 2>/dev/null
        info "Backed up /etc/qtun"

    fi

    if [ -f /etc/config/qtun ]; then

        cp -f /etc/config/qtun "$BACKUP_DIR/" 2>/dev/null
        info "Backed up /etc/config/qtun"

    fi

    if [ -f /etc/init.d/qtun_autoboot ]; then

        cp -f /etc/init.d/qtun_autoboot "$BACKUP_DIR/" 2>/dev/null
        info "Backed up qtun_autoboot"

    fi
}

# =========================================================
# INSTALL
# =========================================================

install_qtun() {

    echo
    printf "${BLUE}${BOLD}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                  QTUN INSTALLATION                     ║"
    echo "╚════════════════════════════════════════════════════════╝"
    printf "${NC}"

    echo

    info "[1/6] Preparing system..."
    sleep 1
    success "System ready."

    echo
    info "[2/6] Updating package information..."
    update_packages || warning "Continuing without package update..."

    echo
    info "[3/6] Downloading QTUN..."
    download_package || return 1

    echo
    info "[4/6] Checking package integrity..."
    validate_ipk || return 1

    echo
    info "[5/6] Installing QTUN..."
    echo

    if opkg install "$PACKAGE_FILE" >>"$LOG_FILE" 2>&1; then

        success "QTUN installed successfully."

    else

        error_msg "QTUN installation failed."
        return 1
    fi

    echo
    info "[6/6] Configuring QTUN..."

    if [ -x /etc/init.d/qtun_autoboot ]; then

        /etc/init.d/qtun_autoboot enable >/dev/null 2>&1

        success "QTUN autoboot enabled."

        /etc/init.d/qtun_autoboot start >/dev/null 2>&1

        success "QTUN service started."

    else

        warning "qtun_autoboot tidak ditemukan."

    fi

    rm -f "$PACKAGE_FILE"

    echo
    success "QTUN installation completed!"

    return 0
}

# =========================================================
# UNINSTALL
# =========================================================

uninstall_qtun() {

    clear

    printf "${RED}${BOLD}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                   UNINSTALL QTUN                       ║"
    echo "╚════════════════════════════════════════════════════════╝"
    printf "${NC}"

    echo
    printf "${YELLOW}QTUN terdeteksi sudah terinstall.${NC}\n"
    echo
    echo "  ${RED}1${NC}. Lanjutkan uninstall"
    echo "  ${GREEN}2${NC}. Cancel"
    echo
    printf "Pilih [1-2]: "

    read choice

    case "$choice" in

        1)

            echo
            info "Stopping QTUN..."

            if [ -x /etc/init.d/qtun_autoboot ]; then

                /etc/init.d/qtun_autoboot stop >/dev/null 2>&1
                /etc/init.d/qtun_autoboot disable >/dev/null 2>&1

            fi

            success "QTUN stopped."

            echo
            info "Removing QTUN package..."

            opkg remove luci-app-qtun >/dev/null 2>&1

            success "QTUN package removed."

            rm -rf /etc/qtun
            rm -f /etc/config/qtun
            rm -f /etc/init.d/qtun_autoboot

            rm -rf /tmp/luci-indexcache
            rm -rf /tmp/luci-modulecache

            if [ -x /etc/init.d/rpcd ]; then
                /etc/init.d/rpcd restart >/dev/null 2>&1
            fi

            echo
            success "QTUN uninstall completed."

            ;;

        2)

            echo
            warning "Uninstall cancelled."

            ;;

        *)

            warning "Invalid option."

            ;;

    esac
}

# =========================================================
# INSTALL MENU
# =========================================================

installation_menu() {

    clear

    printf "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                    QTUN INSTALLER                      ║"
    echo "╚════════════════════════════════════════════════════════╝"
    printf "${NC}"

    echo

    if [ "$PACKAGE_INSTALLED" -eq 1 ]; then

        printf "${YELLOW}${BOLD}"
        echo "QTUN sudah terinstall di perangkat ini."
        printf "${NC}"

        echo
        echo "  ${GREEN}1${NC}. Lanjutkan / Reinstall"
        echo "  ${BLUE}2${NC}. Cancel"
        echo "  ${RED}3${NC}. Uninstall QTUN"
        echo

        printf "Pilih [1-3]: "

        read choice

        case "$choice" in

            1)
                return 0
                ;;

            2)
                echo
                warning "Installation cancelled."
                exit 0
                ;;

            3)
                uninstall_qtun
                exit $?
                ;;

            *)
                warning "Invalid option."
                exit 1
                ;;

        esac

    else

        echo "  ${GREEN}1${NC}. Install QTUN"
        echo "  ${RED}2${NC}. Cancel"
        echo

        printf "Pilih [1-2]: "

        read choice

        case "$choice" in

            1)
                return 0
                ;;

            2)
                echo
                warning "Installation cancelled."
                exit 0
                ;;

            *)
                warning "Invalid option."
                exit 1
                ;;

        esac

    fi
}

# =========================================================
# FINAL SUMMARY
# =========================================================

final_summary() {

    echo
    printf "${GREEN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║             QTUN INSTALLATION COMPLETE                 ║"
    echo "╚════════════════════════════════════════════════════════╝"
    printf "${NC}"

    echo
    success "OpenWrt       : $OPENWRT_VERSION"
    success "Architecture   : $BEST_ARCH"
    success "Package        : $SELECTED_PACKAGE"

    echo
    printf "${CYAN}${BOLD}"
    echo "QTUN siap digunakan."
    printf "${NC}"

    echo
}

# =========================================================
# MAIN
# =========================================================

main() {

    banner

    if ! detect_openwrt; then
        exit 1
    fi

    if ! check_opkg; then
        exit 1
    fi

    if ! detect_architecture; then
        exit 1
    fi

    show_system_info

    check_existing

    installation_menu

    echo
    printf "${CYAN}${BOLD}"
    echo "Preparing QTUN installation..."
    printf "${NC}"

    sleep 1

    echo

    if ! check_internet; then

        echo
        error_msg "Installation cannot continue without internet."

        exit 1
    fi

    if ! check_disk; then

        echo
        error_msg "Installation stopped because disk space is insufficient."

        exit 1
    fi

    if ! find_package; then
        exit 1
    fi

    backup_config

    if install_qtun; then

        final_summary

        rm -rf "$BACKUP_DIR"

        exit 0

    else

        echo
        printf "${RED}${BOLD}"
        echo "╔════════════════════════════════════════════════════════╗"
        echo "║                  INSTALLATION FAILED                   ║"
        echo "╚════════════════════════════════════════════════════════╝"
        printf "${NC}"

        echo
        warning "QTUN gagal diinstall."
        warning "Log tersedia di:"
        echo "      $LOG_FILE"

        exit 1
    fi
}

# =========================================================
# ROOT CHECK
# =========================================================

if [ "$(id -u)" != "0" ]; then

    echo
    error_msg "Installer harus dijalankan sebagai root."
    exit 1

fi

main
