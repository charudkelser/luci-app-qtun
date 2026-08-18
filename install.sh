#!/bin/sh

# =========================================================
# QTUN SMART INSTALLER
# Version : 2.2.0
# Project : luci-app-qtun
# OpenWrt : 21.02 / 22.03 / 23.05 / 24.10 / 25.x
# Package : IPK / OPKG
# Cache   : Persistent Local Cache
# =========================================================

VERSION="1.0.6"
REPO="charudkelser/luci-app-qtun"
BASE_URL="https://github.com/$REPO/releases/download/v$VERSION"

TMP_DIR="/tmp"
CACHE_DIR="/root/.qtun-cache"
LOG_FILE="$TMP_DIR/qtun-install.log"
BACKUP_DIR="$TMP_DIR/qtun-backup"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'
BOLD='\033[1m'

PACKAGE_MANAGER=""
PACKAGE_FILE=""
SELECTED_PACKAGE=""
SELECTED_URL=""

OPENWRT_VERSION=""
OPENWRT_BRANCH=""
OPENWRT_ARCH=""

BEST_ARCH=""
BEST_PRIORITY=""

PACKAGE_INSTALLED=0


# =========================================================
# OUTPUT
# =========================================================

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

line() {
    printf "${GRAY}────────────────────────────────────────────────────────${NC}\n"
}


# =========================================================
# BANNER
# =========================================================

banner() {
    clear
    echo
    printf "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                 QTUN SMART INSTALLER                   ║"
    echo "║                      Version 2.2                       ║"
    echo "║                  SMART LOCAL CACHE                     ║"
    echo "╚════════════════════════════════════════════════════════╝"
    printf "${NC}"
    echo
}


# =========================================================
# DETECT OPENWRT
# =========================================================

detect_openwrt() {

    [ -f /etc/openwrt_release ] || {
        error_msg "OpenWrt tidak terdeteksi."
        return 1
    }

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

        25.*)
            OPENWRT_BRANCH="25.x"
            ;;

        *)
            OPENWRT_BRANCH="$OPENWRT_VERSION"
            ;;

    esac
}


# =========================================================
# DETECT PACKAGE MANAGER
# =========================================================

detect_package_manager() {

    if command -v opkg >/dev/null 2>&1; then

        PACKAGE_MANAGER="opkg"

        success "Package manager : opkg"

        return 0
    fi

    error_msg "opkg tidak ditemukan."

    return 1
}


# =========================================================
# DETECT ARCHITECTURE
# =========================================================

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

        BEST_ARCH="$OPENWRT_ARCH"

        [ -z "$BEST_ARCH" ] && BEST_ARCH="$(uname -m)"

        warning "Architecture opkg tidak ditemukan."
        warning "Menggunakan architecture: $BEST_ARCH"

    fi
}


# =========================================================
# SYSTEM INFO
# =========================================================

show_system_info() {

    echo

    printf "${WHITE}${BOLD}System Information${NC}\n"

    line

    success "OpenWrt       : $OPENWRT_VERSION"
    success "Branch        : $OPENWRT_BRANCH"
    success "Machine       : $(uname -m)"
    success "Package mgr   : $PACKAGE_MANAGER"
    success "Architecture  : $BEST_ARCH"
    success "Cache         : $CACHE_DIR"

    if [ -n "$BEST_PRIORITY" ]; then
        success "Priority      : $BEST_PRIORITY"
    fi

    echo
}


# =========================================================
# INTERNET
# =========================================================

check_internet() {

    info "Checking internet connection..."

    if ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 ||
       ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then

        success "Internet connection available."

        return 0
    fi

    error_msg "Tidak ada koneksi internet."

    return 1
}


# =========================================================
# DISK
# =========================================================

check_disk() {

    AVAILABLE="$(df /tmp 2>/dev/null | awk 'NR==2 {print $4}')"

    if [ -z "$AVAILABLE" ]; then

        warning "Tidak dapat membaca kapasitas /tmp."

        return 0
    fi

    if [ "$AVAILABLE" -lt 50000 ]; then

        error_msg "Ruang /tmp tidak mencukupi."

        echo "      Required : 50000 KB"
        echo "      Available: ${AVAILABLE} KB"

        return 1
    fi

    success "Disk space OK."

    return 0
}


# =========================================================
# CREATE CACHE
# =========================================================

prepare_cache() {

    if [ ! -d "$CACHE_DIR" ]; then

        mkdir -p "$CACHE_DIR" 2>/dev/null

        if [ ! -d "$CACHE_DIR" ]; then

            error_msg "Gagal membuat cache directory:"
            echo "      $CACHE_DIR"

            return 1
        fi

    fi

    return 0
}


# =========================================================
# CHECK EXISTING QTUN
# =========================================================

check_existing() {

    PACKAGE_INSTALLED=0

    if opkg status luci-app-qtun 2>/dev/null |
       grep -q 'Status:.*installed'; then

        PACKAGE_INSTALLED=1

    fi

    if [ -d /etc/qtun ]; then

        PACKAGE_INSTALLED=1

    fi
}


# =========================================================
# FIND PACKAGE
# =========================================================

find_package() {

    SELECTED_PACKAGE="luci-app-qtun_${VERSION}_${BEST_ARCH}.ipk"

    SELECTED_URL="$BASE_URL/$SELECTED_PACKAGE"

    info "Checking QTUN IPK package..."

    success "Compatible package:"
    echo "      $SELECTED_PACKAGE"

    return 0
}


# =========================================================
# CACHE FILE
# =========================================================

get_cache_file() {

    echo "$CACHE_DIR/$SELECTED_PACKAGE"
}


# =========================================================
# VALIDATE IPK
# =========================================================

validate_ipk_file() {

    TEST_FILE="$1"

    [ -f "$TEST_FILE" ] || return 1

    [ -s "$TEST_FILE" ] || return 1

    opkg install \
        --noaction \
        --force-reinstall \
        "$TEST_FILE" \
        >/dev/null 2>&1

    return $?
}


# =========================================================
# CHECK LOCAL CACHE
# =========================================================

check_local_cache() {

    CACHE_FILE="$(get_cache_file)"

    # -----------------------------------------------------
    # Check /tmp
    # -----------------------------------------------------

    TMP_FILE="$TMP_DIR/$SELECTED_PACKAGE"

    if [ -s "$TMP_FILE" ]; then

        info "Checking local IPK in /tmp..."

        if validate_ipk_file "$TMP_FILE"; then

            PACKAGE_FILE="$TMP_FILE"

            success "Valid IPK found in /tmp."
            success "Download skipped."

            return 0

        else

            warning "IPK di /tmp tidak valid."
            rm -f "$TMP_FILE"

        fi

    fi


    # -----------------------------------------------------
    # Check persistent cache
    # -----------------------------------------------------

    if [ -s "$CACHE_FILE" ]; then

        info "Checking persistent QTUN cache..."

        if validate_ipk_file "$CACHE_FILE"; then

            PACKAGE_FILE="$CACHE_FILE"

            success "Valid IPK found in cache."
            success "Download skipped."

            return 0

        else

            warning "Cache IPK tidak valid."
            rm -f "$CACHE_FILE"

        fi

    fi


    return 1
}


# =========================================================
# UPDATE PACKAGES
# =========================================================

update_packages() {

    echo

    info "Updating package lists..."

    opkg update >>"$LOG_FILE" 2>&1

    if [ $? -eq 0 ]; then

        success "Package lists updated."

        return 0
    fi

    warning "opkg update gagal."
    warning "Continuing..."

    return 1
}


# =========================================================
# DOWNLOAD PACKAGE
# =========================================================

download_package() {

    PACKAGE_FILE="$TMP_DIR/$SELECTED_PACKAGE"

    echo
    info "Downloading QTUN..."
    echo "      $SELECTED_PACKAGE"
    echo

    rm -f "$PACKAGE_FILE"

    wget \
        --no-check-certificate \
        -q \
        -O "$PACKAGE_FILE" \
        "$SELECTED_URL" \
        >>"$LOG_FILE" 2>&1 &

    WGET_PID=$!

    INDEX=0

    while kill -0 "$WGET_PID" 2>/dev/null
    do

        case "$INDEX" in

            0)
                FRAME="/"
                ;;

            1)
                FRAME="-"
                ;;

            2)
                FRAME="\\"
                ;;

            3)
                FRAME="|"
                ;;

        esac

        printf "\r      Downloading package... %s" "$FRAME"

        INDEX=$((INDEX + 1))

        [ "$INDEX" -ge 4 ] && INDEX=0

        sleep 1

    done

    wait "$WGET_PID"

    WGET_STATUS=$?

    printf "\r\033[K"

    if [ "$WGET_STATUS" -ne 0 ] ||
       [ ! -s "$PACKAGE_FILE" ]; then

        error_msg "Download QTUN gagal."

        echo "      Log: $LOG_FILE"

        rm -f "$PACKAGE_FILE"

        return 1
    fi

    success "Download completed."

    return 0
}


# =========================================================
# SAVE TO PERSISTENT CACHE
# =========================================================

save_to_cache() {

    CACHE_FILE="$(get_cache_file)"

    if [ "$PACKAGE_FILE" = "$CACHE_FILE" ]; then
        return 0
    fi

    info "Saving IPK to persistent cache..."

    cp -f "$PACKAGE_FILE" "$CACHE_FILE" 2>/dev/null

    if [ -s "$CACHE_FILE" ]; then

        success "IPK saved to cache."

        return 0
    fi

    warning "Gagal menyimpan IPK ke cache."

    return 1
}


# =========================================================
# VALIDATE DOWNLOADED PACKAGE
# =========================================================

validate_ipk() {

    echo

    info "Validating IPK package..."

    if [ ! -f "$PACKAGE_FILE" ]; then

        error_msg "File IPK tidak ditemukan."

        return 1
    fi

    if [ ! -s "$PACKAGE_FILE" ]; then

        error_msg "File IPK kosong."

        return 1
    fi

    info "Checking IPK with opkg..."

    opkg install \
        --noaction \
        --force-reinstall \
        "$PACKAGE_FILE" \
        >>"$LOG_FILE" 2>&1

    OPKG_STATUS=$?

    if [ "$OPKG_STATUS" -eq 0 ]; then

        success "IPK package valid."

        return 0
    fi

    error_msg "IPK tidak dapat divalidasi oleh opkg."

    echo "      Log: $LOG_FILE"

    return 1
}


# =========================================================
# BACKUP QTUN
# =========================================================

backup_config() {

    rm -rf "$BACKUP_DIR"

    mkdir -p "$BACKUP_DIR"

    if [ -d /etc/qtun ]; then

        cp -a /etc/qtun \
            "$BACKUP_DIR/" \
            2>/dev/null

        info "Backed up /etc/qtun"

    fi

    if [ -f /etc/config/qtun ]; then

        cp -f /etc/config/qtun \
            "$BACKUP_DIR/" \
            2>/dev/null

        info "Backed up /etc/config/qtun"

    fi

    if [ -f /etc/init.d/qtun_autoboot ]; then

        cp -f /etc/init.d/qtun_autoboot \
            "$BACKUP_DIR/" \
            2>/dev/null

        info "Backed up qtun_autoboot"

    fi
}


# =========================================================
# INSTALL PACKAGE
# =========================================================

install_package() {

    info "Installing local IPK..."

    opkg install \
        "$PACKAGE_FILE" \
        >>"$LOG_FILE" 2>&1

    if [ $? -ne 0 ]; then

        error_msg "QTUN IPK installation failed."

        echo "      Log: $LOG_FILE"

        return 1
    fi

    success "QTUN IPK installed successfully."

    return 0
}


# =========================================================
# CONFIGURE SERVICE
# =========================================================

configure_service() {

    echo

    info "Configuring QTUN..."

    if [ -x /etc/init.d/qtun_autoboot ]; then

        /etc/init.d/qtun_autoboot enable \
            >/dev/null 2>&1

        success "QTUN autoboot enabled."

        /etc/init.d/qtun_autoboot start \
            >/dev/null 2>&1

        success "QTUN service started."

    else

        warning "qtun_autoboot tidak ditemukan."

    fi


    if [ -x /etc/init.d/rpcd ]; then

        /etc/init.d/rpcd restart \
            >/dev/null 2>&1

        success "rpcd restarted."

    fi
}


# =========================================================
# INSTALL QTUN
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

    prepare_cache || return 1

    success "System ready."


    echo

    info "[2/6] Updating package information..."

    update_packages || \
        warning "Continuing without package update..."


    echo

    info "[3/6] Checking local cache..."

    if check_local_cache; then

        success "Using cached IPK."

    else

        info "No valid local cache found."

        download_package || return 1

    fi


    echo

    info "[4/6] Checking package integrity..."

    validate_ipk || return 1


    # -----------------------------------------------------
    # Save downloaded package to persistent cache
    # -----------------------------------------------------

    if [ "$PACKAGE_FILE" = "$TMP_DIR/$SELECTED_PACKAGE" ]; then

        save_to_cache

    fi


    echo

    info "[5/6] Installing QTUN..."

    install_package || return 1


    echo

    info "[6/6] Configuring QTUN..."

    configure_service


    # -----------------------------------------------------
    # Keep cached copy.
    # Only remove temporary copy.
    # -----------------------------------------------------

    if [ "$PACKAGE_FILE" = "$TMP_DIR/$SELECTED_PACKAGE" ]; then

        rm -f "$PACKAGE_FILE"

    fi


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

    printf "${YELLOW}${BOLD}"
    echo "QTUN terdeteksi sudah terinstall."
    printf "${NC}"

    echo

    printf "  ${RED}1${NC}. Lanjutkan uninstall\n"
    printf "  ${GREEN}2${NC}. Cancel\n"

    echo

    printf "Pilih [1-2]: "

    read choice


    case "$choice" in

        1)

            echo

            info "Stopping QTUN..."

            if [ -x /etc/init.d/qtun_autoboot ]; then

                /etc/init.d/qtun_autoboot stop \
                    >/dev/null 2>&1

                /etc/init.d/qtun_autoboot disable \
                    >/dev/null 2>&1

            fi

            success "QTUN stopped."


            echo

            info "Removing QTUN package..."

            opkg remove luci-app-qtun \
                >/dev/null 2>&1

            success "QTUN package removed."


            rm -rf /etc/qtun

            rm -f /etc/config/qtun

            rm -f /etc/init.d/qtun_autoboot

            rm -rf /tmp/luci-indexcache
            rm -rf /tmp/luci-modulecache


            if [ -x /etc/init.d/rpcd ]; then

                /etc/init.d/rpcd restart \
                    >/dev/null 2>&1

            fi


            echo

            success "QTUN uninstall completed."

            echo

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
# INSTALLATION MENU
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

        printf "  ${GREEN}1${NC}. Lanjutkan / Reinstall\n"
        printf "  ${BLUE}2${NC}. Cancel\n"
        printf "  ${RED}3${NC}. Uninstall QTUN\n"

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

        printf "  ${GREEN}1${NC}. Install QTUN\n"
        printf "  ${RED}2${NC}. Cancel\n"

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
    success "Architecture  : $BEST_ARCH"
    success "Package mgr   : $PACKAGE_MANAGER"
    success "Package        : $SELECTED_PACKAGE"
    success "Cache          : $CACHE_DIR"

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

    detect_openwrt || exit 1

    detect_package_manager || exit 1

    detect_architecture

    show_system_info

    prepare_cache || exit 1

    check_existing

    installation_menu


    echo

    printf "${CYAN}${BOLD}"
    echo "Preparing QTUN installation..."
    printf "${NC}"

    sleep 1

    echo


    check_internet || exit 1

    check_disk || exit 1

    find_package || exit 1

    backup_config


    if install_qtun; then

        final_summary

        rm -rf "$BACKUP_DIR"

        exit 0

    fi


    echo

    printf "${RED}${BOLD}"

    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                  INSTALLATION FAILED                   ║"
    echo "╚════════════════════════════════════════════════════════╝"

    printf "${NC}"

    echo

    warning "QTUN gagal diinstall."
    warning "Log tersedia di: $LOG_FILE"

    exit 1
}


# =========================================================
# ROOT CHECK
# =========================================================

if [ "$(id -u)" != "0" ]; then

    echo

    error_msg "Installer harus dijalankan sebagai root."

    exit 1
fi


# =========================================================
# START
# =========================================================

main
