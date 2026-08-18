#!/bin/sh

# =========================================================
# QTUN SMART INSTALLER
# Version : 2.1.0
# Project : luci-app-qtun
# OpenWrt : 21.02 / 22.03 / 23.05 / 24.10 / 25.x
# Package : IPK + APK
# =========================================================

VERSION="1.0.6"
REPO="charudkelser/luci-app-qtun"
BASE_URL="https://github.com/$REPO/releases/download/v$VERSION"
TMP_DIR="/tmp"
LOG_FILE="$TMP_DIR/qtun-install.log"
BACKUP_DIR="$TMP_DIR/qtun-backup"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; GRAY='\033[0;37m'; NC='\033[0m'; BOLD='\033[1m'

PACKAGE_MANAGER=""; PACKAGE_FILE=""; SELECTED_PACKAGE=""; SELECTED_URL=""
OPENWRT_VERSION=""; OPENWRT_BRANCH=""; OPENWRT_ARCH=""; BEST_ARCH=""; BEST_PRIORITY=""; PACKAGE_INSTALLED=0

success(){ printf "  ${GREEN}✓${NC} %s\n" "$1"; }
error_msg(){ printf "  ${RED}✗${NC} %s\n" "$1"; }
warning(){ printf "  ${YELLOW}!${NC} %s\n" "$1"; }
info(){ printf "  ${CYAN}➜${NC} %s\n" "$1"; }
line(){ printf "${GRAY}────────────────────────────────────────────────────────${NC}\n"; }

banner(){ clear; echo; printf "${CYAN}${BOLD}"; echo "╔════════════════════════════════════════════════════════╗"; echo "║                 QTUN SMART INSTALLER                   ║"; echo "║                      Version 2.1                       ║"; echo "║                  IPK + APK SUPPORT                     ║"; echo "╚════════════════════════════════════════════════════════╝"; printf "${NC}"; echo; }

detect_openwrt(){
    [ -f /etc/openwrt_release ] || { error_msg "OpenWrt tidak terdeteksi."; return 1; }
    . /etc/openwrt_release
    OPENWRT_VERSION="$DISTRIB_RELEASE"; OPENWRT_ARCH="$DISTRIB_ARCH"
    [ -z "$OPENWRT_ARCH" ] && OPENWRT_ARCH="$(uname -m)"
    case "$OPENWRT_VERSION" in
        21.02*) OPENWRT_BRANCH="21.02";; 22.03*) OPENWRT_BRANCH="22.03";; 23.05*) OPENWRT_BRANCH="23.05";; 24.10*) OPENWRT_BRANCH="24.10";; 25.*) OPENWRT_BRANCH="25.x";; *) OPENWRT_BRANCH="$OPENWRT_VERSION";;
    esac
}

detect_package_manager(){
    if command -v apk >/dev/null 2>&1; then PACKAGE_MANAGER="apk"; success "Package manager : apk"; return 0; fi
    if command -v opkg >/dev/null 2>&1; then PACKAGE_MANAGER="opkg"; success "Package manager : opkg"; return 0; fi
    error_msg "Package manager tidak ditemukan (opkg/apk)."; return 1
}

detect_architecture(){
    if [ "$PACKAGE_MANAGER" = "apk" ]; then
        BEST_ARCH="$(apk --print-arch 2>/dev/null | head -n 1)"
        [ -z "$BEST_ARCH" ] && BEST_ARCH="$OPENWRT_ARCH"
        [ -z "$BEST_ARCH" ] && BEST_ARCH="$(uname -m)"
        BEST_PRIORITY="N/A"
        return 0
    fi
    BEST_ARCH=""; BEST_PRIORITY=""
    while read -r TYPE ARCH PRIORITY; do
        [ "$TYPE" = "arch" ] || continue; [ "$ARCH" = "all" ] && continue
        case "$PRIORITY" in ''|*[!0-9]*) continue;; esac
        if [ -z "$BEST_PRIORITY" ] || [ "$PRIORITY" -gt "$BEST_PRIORITY" ]; then BEST_ARCH="$ARCH"; BEST_PRIORITY="$PRIORITY"; fi
    done <<EOF2
$(opkg print-architecture 2>/dev/null)
EOF2
    [ -n "$BEST_ARCH" ] || { error_msg "Architecture opkg tidak ditemukan."; return 1; }
}

show_system_info(){
    echo; printf "${WHITE}${BOLD}System Information${NC}\n"; line
    success "OpenWrt       : $OPENWRT_VERSION"; success "Branch        : $OPENWRT_BRANCH"; success "Machine       : $(uname -m)"; success "Package mgr   : $PACKAGE_MANAGER"; success "Architecture  : $BEST_ARCH"
    [ "$PACKAGE_MANAGER" = "opkg" ] && success "Priority      : $BEST_PRIORITY" || success "Package type  : APK"
    echo
}

check_internet(){
    info "Checking internet connection..."
    ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 || ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1 || { error_msg "Tidak ada koneksi internet."; return 1; }
    success "Internet connection available."
}

check_disk(){
    AVAILABLE="$(df /tmp 2>/dev/null | awk 'NR==2 {print $4}')"; [ -z "$AVAILABLE" ] && { warning "Tidak dapat membaca kapasitas /tmp."; return 0; }
    [ "$AVAILABLE" -ge 50000 ] || { error_msg "Ruang /tmp tidak mencukupi."; echo "  Required : 50000 KB"; echo "  Available: ${AVAILABLE} KB"; return 1; }
    success "Disk space OK."
}

check_existing(){
    PACKAGE_INSTALLED=0
    if [ "$PACKAGE_MANAGER" = "opkg" ]; then opkg status luci-app-qtun 2>/dev/null | grep -q 'Status:.*installed' && PACKAGE_INSTALLED=1; fi
    if [ "$PACKAGE_MANAGER" = "apk" ]; then apk info -e luci-app-qtun >/dev/null 2>&1 && PACKAGE_INSTALLED=1; fi
    [ -d /etc/qtun ] && PACKAGE_INSTALLED=1
}

find_package(){
    echo
    if [ "$PACKAGE_MANAGER" = "apk" ]; then
        SELECTED_PACKAGE="luci-app-qtun-${VERSION}-r1.apk"; SELECTED_URL="$BASE_URL/$SELECTED_PACKAGE"
        info "Checking QTUN APK package..."
        wget --no-check-certificate --spider -q "$SELECTED_URL" 2>/dev/null || { error_msg "QTUN APK package tidak ditemukan: $SELECTED_PACKAGE"; return 1; }
        success "APK package found:"; echo "      $SELECTED_PACKAGE"; return 0
    fi
    SPECIFIC_PACKAGE="luci-app-qtun_${VERSION}_${BEST_ARCH}.ipk"; SPECIFIC_URL="$BASE_URL/$SPECIFIC_PACKAGE"
    UNIVERSAL_PACKAGE="luci-app-qtun_${VERSION}_all.ipk"; UNIVERSAL_URL="$BASE_URL/$UNIVERSAL_PACKAGE"
    info "Checking QTUN IPK package..."
    if wget --no-check-certificate --spider -q "$SPECIFIC_URL" 2>/dev/null; then SELECTED_PACKAGE="$SPECIFIC_PACKAGE"; SELECTED_URL="$SPECIFIC_URL"; success "Compatible package found:"; echo "      $SELECTED_PACKAGE"; return 0; fi
    warning "Architecture-specific package tidak ditemukan."
    if wget --no-check-certificate --spider -q "$UNIVERSAL_URL" 2>/dev/null; then SELECTED_PACKAGE="$UNIVERSAL_PACKAGE"; SELECTED_URL="$UNIVERSAL_URL"; success "Universal package found:"; echo "      $SELECTED_PACKAGE"; return 0; fi
    error_msg "QTUN IPK package yang kompatibel tidak ditemukan."; return 1
}

update_packages(){
    echo; info "Updating package lists..."
    if [ "$PACKAGE_MANAGER" = "apk" ]; then apk update >>"$LOG_FILE" 2>&1; else opkg update >>"$LOG_FILE" 2>&1; fi
    if [ $? -eq 0 ]; then success "Package lists updated."; return 0; fi
    warning "$PACKAGE_MANAGER update gagal. Continuing..."; return 1
}

download_package(){

    PACKAGE_FILE="$TMP_DIR/$SELECTED_PACKAGE"

    echo
    info "Downloading QTUN..."
    echo "      $SELECTED_PACKAGE"
    echo

    rm -f "$PACKAGE_FILE"

    # Download berjalan di background.
    # Output wget disimpan ke log agar terminal tetap bersih.
    wget --no-check-certificate \
        -q \
        -O "$PACKAGE_FILE" \
        "$SELECTED_URL" \
        >>"$LOG_FILE" 2>&1 &

    WGET_PID=$!

    # Spinner animation
    INDEX=0

    while kill -0 "$WGET_PID" 2>/dev/null
    do
        case "$INDEX" in
            0) FRAME="/" ;;
            1) FRAME="-" ;;
            2) FRAME="\\" ;;
            3) FRAME="|" ;;
        esac

        printf "\r      Downloading package... %s" "$FRAME"

        INDEX=$((INDEX + 1))
        [ "$INDEX" -ge 4 ] && INDEX=0

        sleep 1
    done

    # Tunggu proses wget selesai dan ambil exit status-nya
    wait "$WGET_PID"
    WGET_STATUS=$?

    # Bersihkan baris spinner
    printf "\r\033[K"

    if [ "$WGET_STATUS" -ne 0 ] || [ ! -s "$PACKAGE_FILE" ]; then

        error_msg "Download QTUN gagal."
        echo "      Log: $LOG_FILE"

        rm -f "$PACKAGE_FILE"

        return 1
    fi

    success "Download completed."

    return 0
}

validate_ipk(){
    echo; info "Validating IPK package..."
    tar -tf "$PACKAGE_FILE" >/dev/null 2>&1 || { error_msg "IPK tidak dapat dibaca."; return 1; }
    LIST="$(tar -tf "$PACKAGE_FILE" 2>/dev/null)"
    echo "$LIST" | grep -q '^debian-binary$' || { error_msg "debian-binary tidak ditemukan."; return 1; }
    echo "$LIST" | grep -q '^control.tar.gz$' || { error_msg "control.tar.gz tidak ditemukan."; return 1; }
    echo "$LIST" | grep -q '^data.tar.gz$' || { error_msg "data.tar.gz tidak ditemukan."; return 1; }
    success "IPK package valid."
}

validate_apk(){
    echo; info "Validating APK package..."
    tar -tf "$PACKAGE_FILE" >/dev/null 2>&1 || { error_msg "APK tidak dapat dibaca."; return 1; }
    success "APK package archive valid."
}

validate_package(){ [ "$PACKAGE_MANAGER" = "apk" ] && validate_apk || validate_ipk; }

backup_config(){
    rm -rf "$BACKUP_DIR"; mkdir -p "$BACKUP_DIR"
    [ -d /etc/qtun ] && cp -a /etc/qtun "$BACKUP_DIR/" 2>/dev/null && info "Backed up /etc/qtun"
    [ -f /etc/config/qtun ] && cp -f /etc/config/qtun "$BACKUP_DIR/" 2>/dev/null && info "Backed up /etc/config/qtun"
    [ -f /etc/init.d/qtun_autoboot ] && cp -f /etc/init.d/qtun_autoboot "$BACKUP_DIR/" 2>/dev/null && info "Backed up qtun_autoboot"
}

install_package(){
    if [ "$PACKAGE_MANAGER" = "apk" ]; then
        info "Installing local APK package..."
        apk add --allow-untrusted "$PACKAGE_FILE" >>"$LOG_FILE" 2>&1 || { error_msg "QTUN APK installation failed."; return 1; }
        success "QTUN APK installed successfully."; return 0
    fi
    opkg install "$PACKAGE_FILE" >>"$LOG_FILE" 2>&1 || { error_msg "QTUN IPK installation failed."; return 1; }
    success "QTUN IPK installed successfully."
}

configure_service(){
    echo; info "Configuring QTUN..."
    if [ -x /etc/init.d/qtun_autoboot ]; then
        /etc/init.d/qtun_autoboot enable >/dev/null 2>&1; success "QTUN autoboot enabled."
        /etc/init.d/qtun_autoboot start >/dev/null 2>&1; success "QTUN service started."
    else warning "qtun_autoboot tidak ditemukan."; fi
    if [ -x /etc/init.d/rpcd ]; then /etc/init.d/rpcd restart >/dev/null 2>&1; success "rpcd restarted."; fi
}

install_qtun(){
    echo; printf "${BLUE}${BOLD}"; echo "╔════════════════════════════════════════════════════════╗"; echo "║                  QTUN INSTALLATION                     ║"; echo "╚════════════════════════════════════════════════════════╝"; printf "${NC}"; echo
    info "[1/6] Preparing system..."; sleep 1; success "System ready."
    echo; info "[2/6] Updating package information..."; update_packages || warning "Continuing without package update..."
    echo; info "[3/6] Downloading QTUN..."; download_package || return 1
    echo; info "[4/6] Checking package integrity..."; validate_package || return 1
    echo; info "[5/6] Installing QTUN..."; install_package || return 1
    echo; info "[6/6] Configuring QTUN..."; configure_service
    rm -f "$PACKAGE_FILE"; echo; success "QTUN installation completed!"
}

uninstall_qtun(){
    clear; printf "${RED}${BOLD}"; echo "╔════════════════════════════════════════════════════════╗"; echo "║                   UNINSTALL QTUN                       ║"; echo "╚════════════════════════════════════════════════════════╝"; printf "${NC}"
    echo; printf "${YELLOW}QTUN terdeteksi sudah terinstall.${NC}\n"; echo; echo "  ${RED}1${NC}. Lanjutkan uninstall"; echo "  ${GREEN}2${NC}. Cancel"; echo; printf "Pilih [1-2]: "; read choice
    case "$choice" in
        1)
            echo; info "Stopping QTUN..."
            if [ -x /etc/init.d/qtun_autoboot ]; then /etc/init.d/qtun_autoboot stop >/dev/null 2>&1; /etc/init.d/qtun_autoboot disable >/dev/null 2>&1; fi
            success "QTUN stopped."; echo; info "Removing QTUN package..."
            if [ "$PACKAGE_MANAGER" = "apk" ]; then apk del luci-app-qtun >/dev/null 2>&1; else opkg remove luci-app-qtun >/dev/null 2>&1; fi
            success "QTUN package removed."
            rm -rf /etc/qtun; rm -f /etc/config/qtun /etc/init.d/qtun_autoboot; rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
            [ -x /etc/init.d/rpcd ] && /etc/init.d/rpcd restart >/dev/null 2>&1
            echo; success "QTUN uninstall completed."
            ;;
        2) echo; warning "Uninstall cancelled." ;;
        *) warning "Invalid option." ;;
    esac
}

installation_menu(){
    clear; printf "${CYAN}${BOLD}"; echo "╔════════════════════════════════════════════════════════╗"; echo "║                    QTUN INSTALLER                      ║"; echo "╚════════════════════════════════════════════════════════╝"; printf "${NC}"; echo
    if [ "$PACKAGE_INSTALLED" -eq 1 ]; then
        printf "${YELLOW}${BOLD}"; echo "QTUN sudah terinstall di perangkat ini."; printf "${NC}"; echo
        echo "  ${GREEN}1${NC}. Lanjutkan / Reinstall"; echo "  ${BLUE}2${NC}. Cancel"; echo "  ${RED}3${NC}. Uninstall QTUN"; echo; printf "Pilih [1-3]: "; read choice
        case "$choice" in 1) return 0;; 2) warning "Installation cancelled."; exit 0;; 3) uninstall_qtun; exit $?;; *) warning "Invalid option."; exit 1;; esac
    else
        echo "  ${GREEN}1${NC}. Install QTUN"; echo "  ${RED}2${NC}. Cancel"; echo; printf "Pilih [1-2]: "; read choice
        case "$choice" in 1) return 0;; 2) warning "Installation cancelled."; exit 0;; *) warning "Invalid option."; exit 1;; esac
    fi
}

final_summary(){
    echo; printf "${GREEN}${BOLD}"; echo "╔════════════════════════════════════════════════════════╗"; echo "║             QTUN INSTALLATION COMPLETE                 ║"; echo "╚════════════════════════════════════════════════════════╝"; printf "${NC}"; echo
    success "OpenWrt       : $OPENWRT_VERSION"; success "Architecture  : $BEST_ARCH"; success "Package mgr   : $PACKAGE_MANAGER"; success "Package        : $SELECTED_PACKAGE"; echo; printf "${CYAN}${BOLD}"; echo "QTUN siap digunakan."; printf "${NC}"; echo
}

main(){
    banner
    detect_openwrt || exit 1
    detect_package_manager || exit 1
    detect_architecture || exit 1
    show_system_info
    check_existing
    installation_menu
    echo; printf "${CYAN}${BOLD}"; echo "Preparing QTUN installation..."; printf "${NC}"; sleep 1; echo
    check_internet || exit 1
    check_disk || exit 1
    find_package || exit 1
    backup_config
    if install_qtun; then final_summary; rm -rf "$BACKUP_DIR"; exit 0; fi
    echo; printf "${RED}${BOLD}"; echo "╔════════════════════════════════════════════════════════╗"; echo "║                  INSTALLATION FAILED                   ║"; echo "╚════════════════════════════════════════════════════════╝"; printf "${NC}"; echo; warning "QTUN gagal diinstall."; warning "Log tersedia di: $LOG_FILE"; exit 1
}

if [ "$(id -u)" != "0" ]; then echo; error_msg "Installer harus dijalankan sebagai root."; exit 1; fi
main
