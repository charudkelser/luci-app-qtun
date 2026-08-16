#!/bin/sh

# =========================================================
# QTUN SMART INSTALLER
# Version : 2.0.0
# Project : luci-app-qtun
# =========================================================

VERSION="1.0.6"
INSTALLER_VERSION="2.0.0"

REPO="charudkelser/luci-app-qtun"
BASE_URL="https://github.com/$REPO/releases/download/v$VERSION"

TMP_DIR="/tmp/qtun-installer"
PACKAGE_FILE="$TMP_DIR/luci-app-qtun_${VERSION}.ipk"
LOG_FILE="/tmp/qtun-installer.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

CHECK="✓"
CROSS="✗"
ARROW="➜"

DISTRIB_RELEASE=""
DISTRIB_DESCRIPTION=""
DISTRIB_REVISION=""

BEST_ARCH=""
BEST_PRIORITY=""

SELECTED_PACKAGE=""
SELECTED_URL=""

OPENWRT_MAJOR=""
COMPAT_MODE="normal"

INSTALL_FAILED=0


# =========================================================
# BASIC FUNCTIONS
# =========================================================

mkdir -p "$TMP_DIR"
: > "$LOG_FILE"


pause_screen() {
    echo
    printf "Press Enter to continue..."
    read dummy
}


print_ok() {
    printf "  ${GREEN}${CHECK}${NC} %s\n" "$1"
}


print_error() {
    printf "  ${RED}${CROSS}${NC} %s\n" "$1"
}


print_warn() {
    printf "  ${YELLOW}!${NC} %s\n" "$1"
}


print_info() {
    printf "  ${CYAN}${ARROW}${NC} %s\n" "$1"
}


log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)] $*" >> "$LOG_FILE"
}


header() {
    clear
    echo
    echo "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo "${CYAN}${BOLD}║                 QTUN SMART INSTALLER                    ║${NC}"
    echo "${CYAN}${BOLD}║                      v${INSTALLER_VERSION}                         ║${NC}"
    echo "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
}


progress_bar() {
    CURRENT="$1"
    TOTAL="$2"
    TEXT="$3"

    WIDTH=30

    if [ "$TOTAL" -le 0 ]; then
        TOTAL=1
    fi

    FILLED=$((CURRENT * WIDTH / TOTAL))
    EMPTY=$((WIDTH - FILLED))

    BAR=""

    i=0
    while [ "$i" -lt "$FILLED" ]; do
        BAR="${BAR}█"
        i=$((i + 1))
    done

    i=0
    while [ "$i" -lt "$EMPTY" ]; do
        BAR="${BAR}░"
        i=$((i + 1))
    done

    PERCENT=$((CURRENT * 100 / TOTAL))

    printf "\r  ${CYAN}[${BAR}]${NC} %3s%% %s" "$PERCENT" "$TEXT"

    [ "$CURRENT" -ge "$TOTAL" ] && echo
}


# =========================================================
# SYSTEM DETECTION
# =========================================================

detect_system() {

    if [ ! -f /etc/openwrt_release ]; then
        print_error "OpenWrt tidak terdeteksi."
        return 1
    fi

    . /etc/openwrt_release

    log "OpenWrt: $DISTRIB_RELEASE"
    log "Revision: $DISTRIB_REVISION"
    log "Machine: $(uname -m 2>/dev/null)"

    case "$DISTRIB_RELEASE" in
        21.*)
            OPENWRT_MAJOR="21"
            COMPAT_MODE="legacy"
            ;;
        22.*)
            OPENWRT_MAJOR="22"
            COMPAT_MODE="legacy"
            ;;
        23.*)
            OPENWRT_MAJOR="23"
            COMPAT_MODE="normal"
            ;;
        24.*)
            OPENWRT_MAJOR="24"
            COMPAT_MODE="normal"
            ;;
        *)
            OPENWRT_MAJOR="unknown"
            COMPAT_MODE="legacy"
            ;;
    esac

    print_ok "OpenWrt      : $DISTRIB_RELEASE"

    if [ -n "$DISTRIB_REVISION" ]; then
        print_ok "Revision     : $DISTRIB_REVISION"
    else
        print_ok "Revision     : unknown"
    fi

    print_ok "Machine      : $(uname -m 2>/dev/null)"
    print_ok "Mode         : $COMPAT_MODE"

    return 0
}


detect_architecture() {

    BEST_ARCH=""
    BEST_PRIORITY=""

    while read -r TYPE ARCH PRIORITY
    do
        [ "$TYPE" = "arch" ] || continue
        [ "$ARCH" = "all" ] && continue

        case "$PRIORITY" in
            ''|*[!0-9]*)
                continue
                ;;
        esac

        if [ -z "$BEST_PRIORITY" ] ||
           [ "$PRIORITY" -gt "$BEST_PRIORITY" ]; then

            BEST_ARCH="$ARCH"
            BEST_PRIORITY="$PRIORITY"
        fi

    done <<EOF
$(opkg print-architecture 2>/dev/null)
EOF

    if [ -z "$BEST_ARCH" ]; then
        print_error "Architecture opkg tidak ditemukan."
        return 1
    fi

    print_ok "Architecture : $BEST_ARCH"
    print_ok "Priority     : $BEST_PRIORITY"

    log "Architecture: $BEST_ARCH"
    log "Priority: $BEST_PRIORITY"

    return 0
}


detect_package_manager() {

    if command -v opkg >/dev/null 2>&1; then
        print_ok "Package mgr  : opkg"
        return 0
    fi

    print_error "opkg tidak ditemukan."
    return 1
}


# =========================================================
# INTERNET CHECK
# =========================================================

check_internet() {

    printf "  ${CYAN}${ARROW}${NC} Checking internet..."

    if wget --no-check-certificate \
        --spider -q \
        --timeout=8 \
        "https://github.com" 2>/dev/null; then

        echo " ${GREEN}OK${NC}"
        log "Internet check: OK"
        return 0
    fi

    echo " ${RED}FAILED${NC}"

    log "Internet check: FAILED"

    return 1
}


# =========================================================
# DISK CHECK
# =========================================================

check_disk_space() {

    AVAILABLE="$(df /tmp 2>/dev/null | awk 'NR==2 {print $4}')"

    case "$AVAILABLE" in
        ''|*[!0-9]*)
            print_warn "Tidak dapat membaca free space."
            return 0
            ;;
    esac

    REQUIRED=50000

    if [ "$AVAILABLE" -lt "$REQUIRED" ]; then
        print_error "Storage tidak cukup."
        print_info "Required : ${REQUIRED} KB"
        print_info "Available: ${AVAILABLE} KB"
        return 1
    fi

    print_ok "Storage cukup"

    return 0
}


# =========================================================
# PACKAGE DETECTION
# =========================================================

find_package() {

    SPECIFIC_PACKAGE="luci-app-qtun_${VERSION}_${BEST_ARCH}.ipk"
    SPECIFIC_URL="$BASE_URL/$SPECIFIC_PACKAGE"

    UNIVERSAL_PACKAGE="luci-app-qtun_${VERSION}_all.ipk"
    UNIVERSAL_URL="$BASE_URL/$UNIVERSAL_PACKAGE"

    SELECTED_PACKAGE=""
    SELECTED_URL=""

    echo
    print_info "Mencari package QTUN..."

    if wget --no-check-certificate \
        --spider -q \
        --timeout=15 \
        "$SPECIFIC_URL" 2>/dev/null; then

        SELECTED_PACKAGE="$SPECIFIC_PACKAGE"
        SELECTED_URL="$SPECIFIC_URL"

        print_ok "Specific package ditemukan"
        print_info "$SELECTED_PACKAGE"

        return 0
    fi

    print_warn "Specific package tidak ditemukan."

    if wget --no-check-certificate \
        --spider -q \
        --timeout=15 \
        "$UNIVERSAL_URL" 2>/dev/null; then

        SELECTED_PACKAGE="$UNIVERSAL_PACKAGE"
        SELECTED_URL="$UNIVERSAL_URL"

        print_ok "Universal package ditemukan"
        print_info "$SELECTED_PACKAGE"

        return 0
    fi

    print_error "Package QTUN yang kompatibel tidak ditemukan."

    return 1
}


# =========================================================
# PACKAGE LIST
# =========================================================

update_opkg() {

    echo
    print_info "Updating package lists..."

    if opkg update >> "$LOG_FILE" 2>&1; then
        print_ok "Package lists updated"
        return 0
    fi

    print_warn "opkg update gagal."

    if [ "$COMPAT_MODE" = "legacy" ]; then
        print_warn "OpenWrt lama terdeteksi."
        print_info "Installer akan mencoba melanjutkan."
        return 0
    fi

    print_warn "QTUN package berasal dari GitHub."
    print_info "Installer akan mencoba melanjutkan."

    return 0
}


# =========================================================
# DOWNLOAD
# =========================================================

download_package() {

    rm -f "$PACKAGE_FILE"

    echo
    print_info "Downloading QTUN..."
    echo
    print_info "$SELECTED_PACKAGE"
    echo

    wget --no-check-certificate \
        --progress=dot:giga \
        -O "$PACKAGE_FILE" \
        "$SELECTED_URL" 2>&1 | tee -a "$LOG_FILE"

    if [ "${PIPESTATUS:-}" ]; then
        :
    fi

    if [ ! -s "$PACKAGE_FILE" ]; then
        echo
        print_error "Download gagal."
        return 1
    fi

    echo
    print_ok "Download completed."

    return 0
}


# =========================================================
# IPK VALIDATION
# =========================================================

validate_ipk() {

    echo
    print_info "Checking IPK package..."

    if ! tar -tf "$PACKAGE_FILE" >/dev/null 2>&1; then
        print_error "Package tidak dapat dibaca."
        return 1
    fi

    TAR_LIST="$(tar -tf "$PACKAGE_FILE" 2>/dev/null)"

    if ! echo "$TAR_LIST" | grep -q "^debian-binary$"; then
        print_error "debian-binary tidak ditemukan."
        return 1
    fi

    if ! echo "$TAR_LIST" | grep -q "^control.tar.gz$"; then
        print_error "control.tar.gz tidak ditemukan."
        return 1
    fi

    if ! echo "$TAR_LIST" | grep -q "^data.tar.gz$"; then
        print_error "data.tar.gz tidak ditemukan."
        return 1
    fi

    print_ok "IPK package valid."

    return 0
}


# =========================================================
# EXISTING QTUN CHECK
# =========================================================

is_installed() {

    if opkg status luci-app-qtun 2>/dev/null |
       grep -q "^Status:.*installed"; then
        return 0
    fi

    return 1
}


show_installed_status() {

    if is_installed; then

        VERSION_INSTALLED="$(
            opkg status luci-app-qtun 2>/dev/null |
            awk -F': ' '/^Version:/ {print $2; exit}'
        )"

        echo
        print_ok "QTUN        : INSTALLED"

        if [ -n "$VERSION_INSTALLED" ]; then
            print_ok "Version     : $VERSION_INSTALLED"
        fi

    else

        echo
        print_info "QTUN        : NOT INSTALLED"

    fi
}


# =========================================================
# BACKUP CONFIG
# =========================================================

backup_config() {

    BACKUP_DIR="$TMP_DIR/backup"

    rm -rf "$BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    if [ -f /etc/config/qtun ]; then
        cp -f /etc/config/qtun "$BACKUP_DIR/qtun"
        print_ok "QTUN configuration backed up"
    fi

    if [ -d /etc/qtun ]; then
        cp -rf /etc/qtun "$BACKUP_DIR/etc-qtun"
        print_ok "QTUN data backed up"
    fi
}


restore_config() {

    BACKUP_DIR="$TMP_DIR/backup"

    if [ -f "$BACKUP_DIR/qtun" ]; then
        cp -f "$BACKUP_DIR/qtun" /etc/config/qtun
        print_ok "QTUN configuration restored"
    fi

    if [ -d "$BACKUP_DIR/etc-qtun" ]; then
        rm -rf /etc/qtun
        cp -rf "$BACKUP_DIR/etc-qtun" /etc/qtun
        print_ok "QTUN data restored"
    fi
}


# =========================================================
# INSTALL
# =========================================================

install_qtun() {

    header

    echo "${WHITE}${BOLD}QTUN INSTALLATION${NC}"
    echo

    # -----------------------------------------------------
    # SYSTEM CHECK
    # -----------------------------------------------------

    echo "${BLUE}${BOLD}[1/7] System Check${NC}"

    if ! detect_system; then
        pause_screen
        return 1
    fi

    if ! detect_package_manager; then
        pause_screen
        return 1
    fi

    if ! detect_architecture; then
        pause_screen
        return 1
    fi

    if ! check_disk_space; then
        pause_screen
        return 1
    fi

    if ! check_internet; then

        echo
        print_error "Tidak ada koneksi internet."
        pause_screen

        return 1
    fi

    echo


    # -----------------------------------------------------
    # COMPATIBILITY
    # -----------------------------------------------------

    echo "${BLUE}${BOLD}[2/7] Compatibility Check${NC}"

    case "$OPENWRT_MAJOR" in

        21)
            print_warn "OpenWrt 21.x terdeteksi."
            print_info "Legacy compatibility mode aktif."
            ;;

        22)
            print_warn "OpenWrt 22.x terdeteksi."
            print_info "Legacy compatibility mode aktif."
            ;;

        23|24)
            print_ok "OpenWrt $OPENWRT_MAJOR.x supported."
            ;;

        *)
            print_warn "Versi OpenWrt tidak dikenal."
            print_warn "Installer akan melanjutkan dengan compatibility mode."
            ;;

    esac

    echo


    # -----------------------------------------------------
    # PACKAGE
    # -----------------------------------------------------

    echo "${BLUE}${BOLD}[3/7] Package Detection${NC}"

    if ! find_package; then
        pause_screen
        return 1
    fi

    echo


    # -----------------------------------------------------
    # OPKG UPDATE
    # -----------------------------------------------------

    echo "${BLUE}${BOLD}[4/7] Package Lists${NC}"

    update_opkg

    echo


    # -----------------------------------------------------
    # DOWNLOAD
    # -----------------------------------------------------

    echo "${BLUE}${BOLD}[5/7] Download & Validation${NC}"

    if ! download_package; then
        pause_screen
        return 1
    fi

    if ! validate_ipk; then
        rm -f "$PACKAGE_FILE"
        pause_screen
        return 1
    fi

    echo


    # -----------------------------------------------------
    # INSTALL
    # -----------------------------------------------------

    echo "${BLUE}${BOLD}[6/7] Installing QTUN${NC}"

    backup_config

    echo

    if opkg install "$PACKAGE_FILE" >> "$LOG_FILE" 2>&1; then

        print_ok "QTUN package installed."

    else

        print_error "QTUN installation gagal."

        echo
        print_info "Detail error tersedia di:"
        print_info "$LOG_FILE"

        rm -f "$PACKAGE_FILE"

        return 1
    fi

    rm -f "$PACKAGE_FILE"

    restore_config

    echo


    # -----------------------------------------------------
    # FINALIZATION
    # -----------------------------------------------------

    echo "${BLUE}${BOLD}[7/7] Finalizing${NC}"

    if [ -x /etc/init.d/qtun_autoboot ]; then

        if /etc/init.d/qtun_autoboot enable >> "$LOG_FILE" 2>&1; then
            print_ok "QTUN autoboot enabled."
        else
            print_warn "Failed to enable QTUN autoboot."
        fi

        if /etc/init.d/qtun_autoboot start >> "$LOG_FILE" 2>&1; then
            print_ok "QTUN started."
        else
            print_warn "QTUN start returned an error."
        fi

    else

        print_warn "qtun_autoboot tidak ditemukan."

    fi


    if [ -x /etc/init.d/rpcd ]; then

        if /etc/init.d/rpcd restart >> "$LOG_FILE" 2>&1; then
            print_ok "rpcd restarted."
        else
            print_warn "rpcd restart gagal."
        fi

    fi


    # -----------------------------------------------------
    # VERIFY
    # -----------------------------------------------------

    echo

    if is_installed; then

        echo
        echo "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
        echo "${GREEN}${BOLD}║              ✓ QTUN INSTALLATION COMPLETE                ║${NC}"
        echo "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"

        echo
        print_ok "QTUN berhasil diinstall."
        print_ok "OpenWrt      : $DISTRIB_RELEASE"
        print_ok "Architecture : $BEST_ARCH"
        print_ok "Package      : $SELECTED_PACKAGE"

        echo

        return 0

    fi

    print_error "Installation selesai tetapi validasi package gagal."

    return 1
}


# =========================================================
# REPAIR
# =========================================================

repair_qtun() {

    header

    echo "${YELLOW}${BOLD}QTUN REPAIR / REINSTALL${NC}"
    echo

    if is_installed; then
        print_ok "QTUN terdeteksi."
    else
        print_warn "QTUN belum terinstall."
        print_info "Repair akan melakukan fresh installation."
    fi

    echo
    echo "Pilih tindakan:"
    echo
    echo "  ${GREEN}1${NC}. Lanjutkan"
    echo "  ${RED}2${NC}. Cancel"
    echo

    printf "Pilihan [1-2]: "
    read choice

    case "$choice" in
        1)
            install_qtun
            ;;
        *)
            echo
            print_warn "Repair dibatalkan."
            ;;
    esac

    pause_screen
}


# =========================================================
# UNINSTALL
# =========================================================

uninstall_qtun() {

    header

    echo "${RED}${BOLD}QTUN UNINSTALL${NC}"
    echo

    if ! is_installed; then
        print_warn "QTUN tidak terinstall."

        pause_screen
        return 0
    fi

    print_warn "Tindakan ini akan menghapus package QTUN."
    echo

    echo "  ${GREEN}1${NC}. Lanjutkan uninstall"
    echo "  ${RED}2${NC}. Cancel"
    echo

    printf "Pilihan [1-2]: "
    read choice

    case "$choice" in

        1)

            echo
            print_info "Stopping QTUN..."

            if [ -x /etc/init.d/qtun_autoboot ]; then
                /etc/init.d/qtun_autoboot stop >/dev/null 2>&1
                /etc/init.d/qtun_autoboot disable >/dev/null 2>&1
            fi

            print_info "Removing QTUN package..."

            if opkg remove luci-app-qtun >> "$LOG_FILE" 2>&1; then

                print_ok "QTUN package removed."

            else

                print_error "Failed to remove QTUN package."

            fi

            echo
            print_info "Membersihkan cache LuCI..."

            rm -rf \
                /tmp/luci-indexcache \
                /tmp/luci-modulecache \
                2>/dev/null

            if [ -x /etc/init.d/rpcd ]; then
                /etc/init.d/rpcd restart >/dev/null 2>&1
            fi

            echo
            print_ok "QTUN uninstall selesai."

            ;;

        *)

            echo
            print_warn "Uninstall dibatalkan."

            ;;

    esac

    pause_screen
}


# =========================================================
# COMPATIBILITY CHECK
# =========================================================

compatibility_check() {

    header

    echo "${WHITE}${BOLD}SYSTEM COMPATIBILITY CHECK${NC}"
    echo

    detect_system
    echo

    detect_package_manager
    detect_architecture
    echo

    check_disk_space
    check_internet

    echo
    echo "${CYAN}${BOLD}Package Check${NC}"
    echo

    if find_package; then
        print_ok "QTUN package tersedia."
    else
        print_error "QTUN package tidak tersedia."
    fi

    echo
    echo "${CYAN}${BOLD}Result${NC}"
    echo

    case "$OPENWRT_MAJOR" in

        21)
            print_warn "OpenWrt 21.x menggunakan legacy compatibility mode."
            print_info "Direkomendasikan melakukan test install terlebih dahulu."
            ;;

        22)
            print_warn "OpenWrt 22.x menggunakan legacy compatibility mode."
            ;;

        23|24)
            print_ok "OpenWrt $OPENWRT_MAJOR.x menggunakan normal mode."
            ;;

        *)
            print_warn "Versi OpenWrt tidak dikenali."
            ;;

    esac

    echo
    pause_screen
}


# =========================================================
# LOG VIEWER
# =========================================================

show_log() {

    header

    echo "${WHITE}${BOLD}QTUN INSTALLATION LOG${NC}"
    echo

    if [ -s "$LOG_FILE" ]; then

        cat "$LOG_FILE"

    else

        print_warn "Belum ada installation log."

    fi

    echo
    pause_screen
}


# =========================================================
# MAIN MENU
# =========================================================

main_menu() {

    while true
    do

        header

        if [ -f /etc/openwrt_release ]; then
            . /etc/openwrt_release
        fi

        echo "${CYAN}System${NC}"
        echo
        echo "  OpenWrt      : ${DISTRIB_RELEASE:-Unknown}"
        echo "  Machine      : $(uname -m 2>/dev/null)"
        echo

        show_installed_status

        echo
        echo "${CYAN}${BOLD}Pilih tindakan:${NC}"
        echo

        echo "  ${GREEN}1${NC}. Install QTUN"
        echo "  ${YELLOW}2${NC}. Repair / Reinstall QTUN"
        echo "  ${RED}3${NC}. Uninstall QTUN"
        echo "  ${BLUE}4${NC}. Check Compatibility"
        echo "  ${CYAN}5${NC}. View Installation Log"
        echo "  ${WHITE}0${NC}. Exit"

        echo
        printf "Pilihan [0-5]: "
        read MENU_CHOICE

        case "$MENU_CHOICE" in

            1)

                if is_installed; then

                    header

                    print_warn "QTUN sudah terinstall."
                    echo

                    echo "  ${GREEN}1${NC}. Reinstall"
                    echo "  ${RED}2${NC}. Cancel"
                    echo

                    printf "Pilihan [1-2]: "
                    read r

                    case "$r" in
                        1)
                            install_qtun
                            pause_screen
                            ;;
                        *)
                            ;;
                    esac

                else

                    install_qtun
                    pause_screen

                fi

                ;;

            2)
                repair_qtun
                ;;

            3)
                uninstall_qtun
                ;;

            4)
                compatibility_check
                ;;

            5)
                show_log
                ;;

            0)

                clear
                echo
                echo "${GREEN}${BOLD}QTUN Smart Installer selesai.${NC}"
                echo
                exit 0
                ;;

            *)

                print_error "Pilihan tidak valid."
                sleep 1
                ;;

        esac

    done
}


# =========================================================
# ROOT CHECK
# =========================================================

if [ "$(id -u 2>/dev/null)" != "0" ]; then

    echo
    echo "${RED}${BOLD}ERROR:${NC} Installer harus dijalankan sebagai root."
    echo

    exit 1

fi


# =========================================================
# START
# =========================================================

main_menu
