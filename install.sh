#!/bin/sh

# =========================================================
# QTUN AUTO INSTALLER v2
# =========================================================

VERSION="1.0.6"
REPO="charudkelser/luci-app-qtun"
BASE_URL="https://github.com/$REPO/releases/download/v$VERSION"

TMP_DIR="/tmp"
PACKAGE_FILE="$TMP_DIR/luci-app-qtun_${VERSION}.ipk"
LOG_FILE="$TMP_DIR/qtun-installer.log"

# =========================================================
# COLORS
# =========================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

CHECK="✓"
CROSS="✗"
ARROW="➜"
WARN="!"
SPINNER_CHARS="|/-\\"

# =========================================================
# GLOBAL
# =========================================================

DISTRIB_RELEASE=""
DISTRIB_REVISION=""
DISTRIB_TARGET=""
MACHINE=""
BEST_ARCH=""
BEST_PRIORITY=""
SELECTED_PACKAGE=""
SELECTED_URL=""
QTUN_INSTALLED=""
QTUN_VERSION=""
COMPAT_MODE="normal"

# =========================================================
# BASIC FUNCTIONS
# =========================================================

pause() {
    echo
    printf "Tekan ENTER untuk melanjutkan..."
    read -r _
}

header() {
    clear
    echo
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║${NC}                                                    ${CYAN}${BOLD}║${NC}"
    echo -e "${CYAN}${BOLD}║${NC}              ${WHITE}Q T U N  I N S T A L L E R${NC}         ${CYAN}${BOLD}║${NC}"
    echo -e "${CYAN}${BOLD}║${NC}                    ${YELLOW}v${VERSION}${NC}                     ${CYAN}${BOLD}║${NC}"
    echo -e "${CYAN}${BOLD}║${NC}                                                    ${CYAN}${BOLD}║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
    echo
}

line() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

ok() {
    echo -e "  ${GREEN}${CHECK}${NC} $1"
}

warn() {
    echo -e "  ${YELLOW}${WARN}${NC} $1"
}

error() {
    echo -e "  ${RED}${CROSS}${NC} $1"
}

info() {
    echo -e "  ${BLUE}${ARROW}${NC} $1"
}

spinner() {
    text="$1"
    pid="$2"
    i=0

    while kill -0 "$pid" 2>/dev/null; do
        i=$((i + 1))
        char=$(printf "%s" "$SPINNER_CHARS" | cut -c $(( (i % 4) + 1 )))
        printf "\r  ${CYAN}%s${NC} %s..." "$char" "$text"
        sleep 0.15
    done

    printf "\r\033[K"
}

run_with_spinner() {
    text="$1"
    shift

    "$@" >>"$LOG_FILE" 2>&1 &
    pid=$!

    spinner "$text" "$pid"

    wait "$pid"
    return $?
}

step_start() {
    STEP="$1"
    TOTAL="$2"
    TITLE="$3"

    echo
    echo -e "${MAGENTA}${BOLD}[$STEP/$TOTAL]${NC} ${WHITE}${BOLD}$TITLE${NC}"
}

step_done() {
    echo -e "      ${GREEN}${CHECK} Selesai${NC}"
}

step_failed() {
    echo -e "      ${RED}${CROSS} Gagal${NC}"
}

# =========================================================
# SYSTEM DETECTION
# =========================================================

detect_system() {

    [ -f /etc/openwrt_release ] || return 1

    . /etc/openwrt_release

    MACHINE="$(uname -m 2>/dev/null)"
    DISTRIB_RELEASE="${DISTRIB_RELEASE:-unknown}"
    DISTRIB_REVISION="${DISTRIB_REVISION:-unknown}"
    DISTRIB_TARGET="${DISTRIB_TARGET:-unknown}"

    case "$DISTRIB_RELEASE" in
        21.02*)
            COMPAT_MODE="legacy"
            ;;
        22.03*)
            COMPAT_MODE="legacy"
            ;;
        23.05*)
            COMPAT_MODE="normal"
            ;;
        24.10*)
            COMPAT_MODE="normal"
            ;;
        SNAPSHOT*)
            COMPAT_MODE="normal"
            ;;
        *)
            COMPAT_MODE="unknown"
            ;;
    esac

    return 0
}

# =========================================================
# OPKG ARCHITECTURE
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
        elif [ "$PRIORITY" -gt "$BEST_PRIORITY" ] 2>/dev/null; then
            BEST_ARCH="$ARCH"
            BEST_PRIORITY="$PRIORITY"
        fi

    done <<EOF
$(opkg print-architecture 2>/dev/null)
EOF

    [ -n "$BEST_ARCH" ]
}

# =========================================================
# QTUN STATUS
# =========================================================

detect_qtun() {

    QTUN_INSTALLED="no"
    QTUN_VERSION=""

    if opkg status luci-app-qtun 2>/dev/null | grep -q "^Status:.*installed"; then
        QTUN_INSTALLED="yes"

        QTUN_VERSION=$(opkg status luci-app-qtun 2>/dev/null \
            | sed -n 's/^Version: //p' \
            | head -n 1)

        [ -z "$QTUN_VERSION" ] && QTUN_VERSION="unknown"
    fi
}

# =========================================================
# INTERNET
# =========================================================

check_internet() {

    if command -v wget >/dev/null 2>&1; then
        wget --no-check-certificate \
            --spider \
            -q \
            --timeout=8 \
            "$BASE_URL" >/dev/null 2>&1

        return $?
    fi

    return 1
}

# =========================================================
# PACKAGE SELECTION
# =========================================================

select_package() {

    SPECIFIC_PACKAGE="luci-app-qtun_${VERSION}_${BEST_ARCH}.ipk"
    SPECIFIC_URL="$BASE_URL/$SPECIFIC_PACKAGE"

    UNIVERSAL_PACKAGE="luci-app-qtun_${VERSION}_all.ipk"
    UNIVERSAL_URL="$BASE_URL/$UNIVERSAL_PACKAGE"

    SELECTED_PACKAGE=""
    SELECTED_URL=""

    echo
    info "Mencari package QTUN yang sesuai..."

    if wget --no-check-certificate \
        --spider \
        -q \
        "$SPECIFIC_URL" 2>/dev/null; then

        SELECTED_PACKAGE="$SPECIFIC_PACKAGE"
        SELECTED_URL="$SPECIFIC_URL"

        ok "Package ditemukan:"
        echo "      $SELECTED_PACKAGE"
        return 0
    fi

    warn "Package architecture-specific tidak ditemukan."
    info "Mencoba universal package..."

    if wget --no-check-certificate \
        --spider \
        -q \
        "$UNIVERSAL_URL" 2>/dev/null; then

        SELECTED_PACKAGE="$UNIVERSAL_PACKAGE"
        SELECTED_URL="$UNIVERSAL_URL"

        ok "Universal package ditemukan:"
        echo "      $SELECTED_PACKAGE"
        return 0
    fi

    return 1
}

# =========================================================
# SYSTEM INFORMATION
# =========================================================

show_system() {

    header

    echo -e "${WHITE}${BOLD}System Information${NC}"
    line

    echo "  OpenWrt       : $DISTRIB_RELEASE"
    echo "  Revision      : $DISTRIB_REVISION"
    echo "  Target        : $DISTRIB_TARGET"
    echo "  Machine       : $MACHINE"
    echo "  Architecture  : $BEST_ARCH"

    if [ "$COMPAT_MODE" = "legacy" ]; then
        echo
        echo -e "  ${YELLOW}${BOLD}Compatibility  : LEGACY / FW21-22${NC}"
    else
        echo
        echo -e "  ${GREEN}${BOLD}Compatibility  : NORMAL${NC}"
    fi

    echo
}

# =========================================================
# INITIAL MENU
# =========================================================

initial_menu() {

    header

    if [ "$QTUN_INSTALLED" = "yes" ]; then

        echo -e "${GREEN}${BOLD}QTUN TERDETEKSI${NC}"
        echo
        echo "  Installed version : $QTUN_VERSION"
        echo "  Latest version    : $VERSION"
        echo

        line

        echo
        echo -e "  ${GREEN}1${NC}. Update QTUN"
        echo -e "  ${BLUE}2${NC}. Repair QTUN"
        echo -e "  ${YELLOW}3${NC}. Reinstall QTUN"
        echo -e "  ${RED}4${NC}. Uninstall QTUN"
        echo -e "  ${WHITE}0${NC}. Cancel"
        echo

        printf "Pilih [0-4]: "
        read -r choice

        case "$choice" in
            1)
                install_mode="update"
                ;;
            2)
                install_mode="repair"
                ;;
            3)
                install_mode="reinstall"
                ;;
            4)
                uninstall_qtun
                exit 0
                ;;
            0)
                echo
                info "Dibatalkan."
                exit 0
                ;;
            *)
                error "Pilihan tidak valid."
                sleep 1
                initial_menu
                ;;
        esac

    else

        echo -e "${YELLOW}${BOLD}QTUN BELUM TERINSTALL${NC}"
        echo
        echo "Installer akan memasang QTUN v$VERSION"
        echo "beserta konfigurasi service yang diperlukan."
        echo

        line

        echo
        echo -e "  ${GREEN}1${NC}. Lanjutkan Instalasi"
        echo -e "  ${RED}2${NC}. Cancel"
        echo -e "  ${YELLOW}3${NC}. Uninstall / Cleanup"
        echo

        printf "Pilih [1-3]: "
        read -r choice

        case "$choice" in
            1)
                install_mode="install"
                ;;
            2)
                echo
                info "Instalasi dibatalkan."
                exit 0
                ;;
            3)
                uninstall_qtun
                exit 0
                ;;
            *)
                error "Pilihan tidak valid."
                sleep 1
                initial_menu
                ;;
        esac
    fi
}

# =========================================================
# UNINSTALL
# =========================================================

uninstall_qtun() {

    header

    echo -e "${RED}${BOLD}UNINSTALL QTUN${NC}"
    echo
    echo "Tindakan ini akan menghapus package QTUN."
    echo
    echo -e "${YELLOW}Konfigurasi /etc/qtun juga akan dihapus.${NC}"
    echo

    line

    echo
    echo -e "  ${GREEN}1${NC}. Lanjutkan Uninstall"
    echo -e "  ${RED}2${NC}. Cancel"
    echo

    printf "Pilih [1-2]: "
    read -r choice

    [ "$choice" = "1" ] || {
        info "Uninstall dibatalkan."
        return 0
    }

    echo
    step_start 1 4 "Menghentikan QTUN"

    if [ -x /etc/init.d/qtun_autoboot ]; then
        /etc/init.d/qtun_autoboot stop >>"$LOG_FILE" 2>&1
        /etc/init.d/qtun_autoboot disable >>"$LOG_FILE" 2>&1
    fi

    step_done

    step_start 2 4 "Menghapus package"

    if opkg status luci-app-qtun 2>/dev/null | grep -q "^Status:.*installed"; then
        opkg remove luci-app-qtun >>"$LOG_FILE" 2>&1
    fi

    step_done

    step_start 3 4 "Membersihkan konfigurasi"

    rm -rf /etc/qtun
    rm -f /etc/config/qtun
    rm -f /etc/init.d/qtun_autoboot

    step_done

    step_start 4 4 "Membersihkan cache LuCI"

    rm -rf /tmp/luci-indexcache
    rm -rf /tmp/luci-modulecache

    if [ -x /etc/init.d/rpcd ]; then
        /etc/init.d/rpcd restart >>"$LOG_FILE" 2>&1
    fi

    step_done

    echo
    line
    echo
    echo -e "${GREEN}${BOLD}QTUN berhasil di-uninstall.${NC}"
    echo

    pause
}

# =========================================================
# INSTALLATION
# =========================================================

install_qtun() {

    TOTAL=8

    header

    echo -e "${WHITE}${BOLD}Preparing QTUN Installation${NC}"
    echo
    echo "  Version      : $VERSION"
    echo "  OpenWrt      : $DISTRIB_RELEASE"
    echo "  Architecture : $BEST_ARCH"

    if [ "$COMPAT_MODE" = "legacy" ]; then
        echo "  Compatibility : Legacy mode"
    else
        echo "  Compatibility : Normal mode"
    fi

    echo
    line

    # -----------------------------------------------------
    # STEP 1
    # -----------------------------------------------------

    step_start 1 "$TOTAL" "Memeriksa sistem"

    if [ ! -f /etc/openwrt_release ]; then
        step_failed
        installation_failed
        return 1
    fi

    if ! command -v opkg >/dev/null 2>&1; then
        step_failed
        installation_failed
        return 1
    fi

    if ! command -v wget >/dev/null 2>&1; then
        step_failed
        error "wget tidak ditemukan."
        installation_failed
        return 1
    fi

    step_done

    # -----------------------------------------------------
    # STEP 2
    # -----------------------------------------------------

    step_start 2 "$TOTAL" "Memeriksa kompatibilitas"

    if [ "$COMPAT_MODE" = "legacy" ]; then
        echo -e "      ${YELLOW}!${NC} OpenWrt $DISTRIB_RELEASE detected"
        echo -e "      ${YELLOW}!${NC} Legacy compatibility mode"
    else
        echo -e "      ${GREEN}${CHECK}${NC} OpenWrt $DISTRIB_RELEASE"
    fi

    step_done

    # -----------------------------------------------------
    # STEP 3
    # -----------------------------------------------------

    step_start 3 "$TOTAL" "Memeriksa koneksi internet"

    if check_internet; then
        step_done
    else
        step_failed
        error "Tidak dapat mengakses GitHub."
        installation_failed
        return 1
    fi

    # -----------------------------------------------------
    # STEP 4
    # -----------------------------------------------------

    step_start 4 "$TOTAL" "Mencari package QTUN"

    if select_package; then
        step_done
    else
        step_failed
        error "Compatible QTUN package tidak ditemukan."
        installation_failed
        return 1
    fi

    # -----------------------------------------------------
    # STEP 5
    # -----------------------------------------------------

    step_start 5 "$TOTAL" "Memperbarui package lists"

    opkg update >>"$LOG_FILE" 2>&1

    if [ $? -eq 0 ]; then
        step_done
    else
        step_failed
        error "opkg update gagal."
        installation_failed
        return 1
    fi

    # -----------------------------------------------------
    # STEP 6
    # -----------------------------------------------------

    step_start 6 "$TOTAL" "Mengunduh QTUN"

    rm -f "$PACKAGE_FILE"

    wget --no-check-certificate \
        -O "$PACKAGE_FILE" \
        "$SELECTED_URL" >>"$LOG_FILE" 2>&1 &
    
    DOWNLOAD_PID=$!

    spinner "Downloading $SELECTED_PACKAGE" "$DOWNLOAD_PID"

    wait "$DOWNLOAD_PID"

    if [ $? -eq 0 ] && [ -s "$PACKAGE_FILE" ]; then
        step_done
    else
        step_failed
        rm -f "$PACKAGE_FILE"
        installation_failed
        return 1
    fi

    # -----------------------------------------------------
    # STEP 7
    # -----------------------------------------------------

    step_start 7 "$TOTAL" "Memvalidasi dan menginstall QTUN"

    TAR_LIST="$(tar -tf "$PACKAGE_FILE" 2>/dev/null)"

    if [ -z "$TAR_LIST" ]; then
        step_failed
        error "IPK tidak dapat dibaca."
        rm -f "$PACKAGE_FILE"
        installation_failed
        return 1
    fi

    if ! echo "$TAR_LIST" | grep -q "^debian-binary$"; then
        step_failed
        error "debian-binary tidak ditemukan."
        rm -f "$PACKAGE_FILE"
        installation_failed
        return 1
    fi

    if ! echo "$TAR_LIST" | grep -q "^control.tar.gz$"; then
        step_failed
        error "control.tar.gz tidak ditemukan."
        rm -f "$PACKAGE_FILE"
        installation_failed
        return 1
    fi

    if ! echo "$TAR_LIST" | grep -q "^data.tar.gz$"; then
        step_failed
        error "data.tar.gz tidak ditemukan."
        rm -f "$PACKAGE_FILE"
        installation_failed
        return 1
    fi

    echo -e "      ${GREEN}${CHECK}${NC} IPK package valid"

    opkg install "$PACKAGE_FILE" >>"$LOG_FILE" 2>&1

    if [ $? -eq 0 ]; then
        step_done
    else
        step_failed
        rm -f "$PACKAGE_FILE"
        installation_failed
        return 1
    fi

    rm -f "$PACKAGE_FILE"

    # -----------------------------------------------------
    # STEP 8
    # -----------------------------------------------------

    step_start 8 "$TOTAL" "Mengaktifkan QTUN"

    SERVICE_OK=1

    if [ -x /etc/init.d/qtun_autoboot ]; then

        /etc/init.d/qtun_autoboot enable >>"$LOG_FILE" 2>&1

        if [ $? -ne 0 ]; then
            SERVICE_OK=0
        fi

        /etc/init.d/qtun_autoboot start >>"$LOG_FILE" 2>&1

        if [ $? -ne 0 ]; then
            SERVICE_OK=0
        fi

        echo -e "      ${GREEN}${CHECK}${NC} qtun_autoboot"
    else
        echo -e "      ${YELLOW}!${NC} qtun_autoboot tidak ditemukan"
    fi

    if [ -x /etc/init.d/rpcd ]; then
        /etc/init.d/rpcd restart >>"$LOG_FILE" 2>&1
        echo -e "      ${GREEN}${CHECK}${NC} rpcd restarted"
    fi

    if [ "$SERVICE_OK" -eq 1 ]; then
        step_done
    else
        warn "Service QTUN perlu diperiksa."
    fi

    installation_success
}

# =========================================================
# INSTALL SUCCESS
# =========================================================

installation_success() {

    detect_qtun

    clear
    echo
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║${NC}                                                    ${GREEN}${BOLD}║${NC}"
    echo -e "${GREEN}${BOLD}║${NC}          ${WHITE}QTUN INSTALLATION COMPLETE${NC}            ${GREEN}${BOLD}║${NC}"
    echo -e "${GREEN}${BOLD}║${NC}                                                    ${GREEN}${BOLD}║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
    echo

    echo -e "${WHITE}${BOLD}Installation Summary${NC}"
    line

    echo
    echo "  QTUN Version  : ${QTUN_VERSION:-$VERSION}"
    echo "  OpenWrt       : $DISTRIB_RELEASE"
    echo "  Architecture  : $BEST_ARCH"
    echo "  Package       : $SELECTED_PACKAGE"

    if [ "$COMPAT_MODE" = "legacy" ]; then
        echo "  Compatibility  : Legacy"
    else
        echo "  Compatibility  : Normal"
    fi

    echo
    ok "QTUN berhasil diinstall."
    ok "Autoboot dikonfigurasi."
    ok "RPCD direstart."

    echo
    line
    echo
    echo -e "${CYAN}${BOLD}QTUN siap digunakan.${NC}"
    echo

    pause
}

# =========================================================
# INSTALL FAILURE
# =========================================================

installation_failed() {

    echo
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║${NC}             INSTALLATION FAILED                    ${RED}${BOLD}║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
    echo

    echo -e "${YELLOW}QTUN tidak berhasil menyelesaikan instalasi.${NC}"
    echo

    echo -e "  ${GREEN}1${NC}. Coba Lagi"
    echo -e "  ${BLUE}2${NC}. Cancel"
    echo -e "  ${RED}3${NC}. Hapus Instalasi / Cleanup"
    echo

    printf "Pilih [1-3]: "
    read -r choice

    case "$choice" in
        1)
            install_qtun
            ;;
        2)
            info "Instalasi dibatalkan."
            ;;
        3)
            uninstall_qtun
            ;;
        *)
            info "Tidak ada tindakan."
            ;;
    esac
}

# =========================================================
# REPAIR
# =========================================================

repair_qtun() {

    header

    echo -e "${BLUE}${BOLD}QTUN REPAIR${NC}"
    echo
    echo "Repair akan mencoba memperbaiki service dan cache LuCI."
    echo

    line

    echo
    printf "Lanjutkan repair? [Y/n]: "
    read -r answer

    case "$answer" in
        n|N)
            info "Repair dibatalkan."
            return 0
            ;;
    esac

    echo

    step_start 1 4 "Membersihkan cache LuCI"

    rm -rf /tmp/luci-indexcache
    rm -rf /tmp/luci-modulecache

    step_done

    step_start 2 4 "Memeriksa service QTUN"

    if [ -x /etc/init.d/qtun_autoboot ]; then
        /etc/init.d/qtun_autoboot enable >>"$LOG_FILE" 2>&1
        step_done
    else
        step_failed
        warn "qtun_autoboot tidak ditemukan."
    fi

    step_start 3 4 "Restarting QTUN"

    if [ -x /etc/init.d/qtun_autoboot ]; then
        /etc/init.d/qtun_autoboot restart >>"$LOG_FILE" 2>&1

        if [ $? -eq 0 ]; then
            step_done
        else
            step_failed
        fi
    else
        step_failed
    fi

    step_start 4 4 "Restarting RPCD"

    if [ -x /etc/init.d/rpcd ]; then
        /etc/init.d/rpcd restart >>"$LOG_FILE" 2>&1
        step_done
    else
        step_failed
    fi

    echo
    echo -e "${GREEN}${BOLD}Repair selesai.${NC}"
    pause
}

# =========================================================
# MAIN
# =========================================================

[ "$(id -u)" -eq 0 ] || {
    echo -e "${RED}ERROR: Jalankan installer sebagai root.${NC}"
    exit 1
}

mkdir -p "$TMP_DIR"
: > "$LOG_FILE"

detect_system || {
    echo -e "${RED}[ERROR] OpenWrt tidak terdeteksi.${NC}"
    exit 1
}

detect_architecture || {
    echo -e "${RED}[ERROR] Architecture opkg tidak ditemukan.${NC}"
    exit 1
}

detect_qtun

initial_menu

case "$install_mode" in

    install)
        install_qtun
        ;;

    update)
        echo
        echo -e "${GREEN}${BOLD}Update QTUN${NC}"
        echo
        install_qtun
        ;;

    reinstall)
        uninstall_qtun
        sleep 1

        detect_system
        detect_architecture
        detect_qtun

        install_qtun
        ;;

    repair)
        repair_qtun
        ;;

esac

exit 0
