#!/bin/sh

# =========================================================
# QTUN SMART INSTALLER
# Version : 2.3.0
# Project : luci-app-qtun
# OpenWrt : 21.02 / 22.03 / 23.05 / 24.10 / 25.x
# Package : IPK ONLY
# Feature : SMART LOCAL CACHE
# =========================================================

VERSION="1.0.6"
REPO="charudkelser/luci-app-qtun"
BASE_URL="https://github.com/$REPO/releases/download/v$VERSION"

TMP_DIR="/tmp"
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
# UI
# =========================================================

success(){
    printf "  ${GREEN}✓${NC} %s\n" "$1"
}

error_msg(){
    printf "  ${RED}✗${NC} %s\n" "$1"
}

warning(){
    printf "  ${YELLOW}!${NC} %s\n" "$1"
}

info(){
    printf "  ${CYAN}➜${NC} %s\n" "$1"
}

line(){
    printf "${GRAY}────────────────────────────────────────────────────────${NC}\n"
}


banner(){
    clear
    echo
    printf "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                 QTUN SMART INSTALLER                   ║"
    echo "║                      Version 2.3                       ║"
    echo "║                  SMART LOCAL CACHE                     ║"
    echo "╚════════════════════════════════════════════════════════╝"
    printf "${NC}"
    echo
}


# =========================================================
# DETECT OPENWRT
# =========================================================

detect_openwrt(){

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
# DETECT OPKG
# =========================================================

detect_package_manager(){

    if command -v opkg >/dev/null 2>&1
    then

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

detect_architecture(){

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
           [ "$PRIORITY" -gt "$BEST_PRIORITY" ]
        then

            BEST_ARCH="$ARCH"
            BEST_PRIORITY="$PRIORITY"

        fi

    done <<EOF
$(opkg print-architecture 2>/dev/null)
EOF

    if [ -z "$BEST_ARCH" ]
    then

        BEST_ARCH="$OPENWRT_ARCH"

        [ -z "$BEST_ARCH" ] &&
            BEST_ARCH="$(uname -m)"

    fi

    [ -n "$BEST_ARCH" ] || {

        error_msg "Architecture tidak dapat ditentukan."

        return 1
    }

    return 0
}


# =========================================================
# SYSTEM INFORMATION
# =========================================================

show_system_info(){

    echo

    printf "${WHITE}${BOLD}System Information${NC}\n"

    line

    success "OpenWrt       : $OPENWRT_VERSION"
    success "Branch        : $OPENWRT_BRANCH"
    success "Machine       : $(uname -m)"
    success "Package mgr   : $PACKAGE_MANAGER"
    success "Architecture  : $BEST_ARCH"
    success "Priority      : $BEST_PRIORITY"

    echo
}


# =========================================================
# INTERNET
# =========================================================

check_internet(){

    info "Checking internet connection..."

    ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 ||
    ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1 ||
    {

        error_msg "Tidak ada koneksi internet."

        return 1

    }

    success "Internet connection available."
}


# =========================================================
# DISK
# =========================================================

check_disk(){

    AVAILABLE="$(df /tmp 2>/dev/null | awk 'NR==2 {print $4}')"

    if [ -z "$AVAILABLE" ]
    then

        warning "Tidak dapat membaca kapasitas /tmp."

        return 0

    fi

    if [ "$AVAILABLE" -lt 50000 ]
    then

        error_msg "Ruang /tmp tidak mencukupi."

        echo "  Required : 50000 KB"
        echo "  Available: ${AVAILABLE} KB"

        return 1

    fi

    success "Disk space OK."
}


# =========================================================
# CHECK EXISTING INSTALLATION
# =========================================================

check_existing(){

    PACKAGE_INSTALLED=0

    if opkg status luci-app-qtun 2>/dev/null |
        grep -q 'Status:.*installed'
    then

        PACKAGE_INSTALLED=1

    fi

    [ -d /etc/qtun ] &&
        PACKAGE_INSTALLED=1
}


# =========================================================
# VALIDATE IPK
# =========================================================

validate_ipk(){

    [ -f "$PACKAGE_FILE" ] || {

        error_msg "File IPK tidak ditemukan."

        return 1
    }

    [ -s "$PACKAGE_FILE" ] || {

        error_msg "File IPK kosong."

        return 1
    }

    info "Checking IPK with opkg..."

    opkg install \
        --noaction \
        --force-reinstall \
        "$PACKAGE_FILE" \
        >>"$LOG_FILE" 2>&1

    OPKG_STATUS=$?

    if [ "$OPKG_STATUS" -eq 0 ]
    then

        success "IPK package valid."

        return 0

    fi

    error_msg "IPK tidak dapat divalidasi oleh opkg."

    echo "      Log: $LOG_FILE"

    return 1
}


# =========================================================
# SMART LOCAL CACHE
# =========================================================

check_local_cache(){

    LOCAL_PACKAGE="$TMP_DIR/$SELECTED_PACKAGE"

    if [ ! -f "$LOCAL_PACKAGE" ]
    then

        return 1

    fi

    if [ ! -s "$LOCAL_PACKAGE" ]
    then

        warning "Local package kosong. Menghapus cache."

        rm -f "$LOCAL_PACKAGE"

        return 1

    fi

    echo

    success "Local package found:"

    echo "      $LOCAL_PACKAGE"

    info "Validating cached package..."

    PACKAGE_FILE="$LOCAL_PACKAGE"

    if validate_ipk
    then

        success "Using cached IPK."
        return 0

    fi

    warning "Cached IPK tidak valid."

    rm -f "$LOCAL_PACKAGE"

    PACKAGE_FILE=""

    return 1
}


# =========================================================
# FIND PACKAGE
# =========================================================

find_package(){

    echo

    SPECIFIC_PACKAGE="luci-app-qtun_${VERSION}_${BEST_ARCH}.ipk"
    SPECIFIC_URL="$BASE_URL/$SPECIFIC_PACKAGE"

    UNIVERSAL_PACKAGE="luci-app-qtun_${VERSION}_all.ipk"
    UNIVERSAL_URL="$BASE_URL/$UNIVERSAL_PACKAGE"


    # -----------------------------------------------------
    # SMART CACHE - ARCH SPECIFIC
    # -----------------------------------------------------

    SELECTED_PACKAGE="$SPECIFIC_PACKAGE"
    SELECTED_URL="$SPECIFIC_URL"

    info "Checking local QTUN cache..."

    if check_local_cache
    then

        return 0

    fi


    # -----------------------------------------------------
    # DOWNLOAD ARCH SPECIFIC
    # -----------------------------------------------------

    info "Checking QTUN IPK package..."

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


    # -----------------------------------------------------
    # UNIVERSAL PACKAGE
    # -----------------------------------------------------

    warning "Architecture-specific package tidak ditemukan."

    SELECTED_PACKAGE="$UNIVERSAL_PACKAGE"
    SELECTED_URL="$UNIVERSAL_URL"


    info "Checking local universal cache..."

    if check_local_cache
    then

        return 0

    fi


    if wget --no-check-certificate \
        --spider \
        -q \
        "$UNIVERSAL_URL" 2>/dev/null
    then

        success "Universal package found:"

        echo "      $SELECTED_PACKAGE"

        return 0

    fi


    error_msg "QTUN IPK package yang kompatibel tidak ditemukan."

    return 1
}


# =========================================================
# UPDATE OPKG
# =========================================================

update_packages(){

    echo

    info "Updating package lists..."

    opkg update >>"$LOG_FILE" 2>&1

    if [ $? -eq 0 ]
    then

        success "Package lists updated."

        return 0

    fi

    warning "opkg update gagal. Continuing..."

    return 1
}


# =========================================================
# DOWNLOAD PACKAGE
# =========================================================

download_package(){

    PACKAGE_FILE="$TMP_DIR/$SELECTED_PACKAGE"

    echo

    info "Downloading QTUN..."

    echo "      $SELECTED_PACKAGE"

    echo

    rm -f "$PACKAGE_FILE"

    RETRY=1
    MAX_RETRY=3

    while [ "$RETRY" -le "$MAX_RETRY" ]
    do

        info "Download attempt $RETRY/$MAX_RETRY..."

        wget --no-check-certificate \
            -q \
            -O "$PACKAGE_FILE" \
            "$SELECTED_URL" \
            >>"$LOG_FILE" 2>&1

        WGET_STATUS=$?

        if [ "$WGET_STATUS" -eq 0 ] &&
           [ -s "$PACKAGE_FILE" ]
        then

            success "Download completed."

            return 0

        fi

        warning "Download failed."

        rm -f "$PACKAGE_FILE"

        RETRY=$((RETRY + 1))

        [ "$RETRY" -le "$MAX_RETRY" ] &&
            sleep 2

    done

    error_msg "Download QTUN gagal setelah $MAX_RETRY percobaan."

    echo "      Log: $LOG_FILE"

    return 1
}


# =========================================================
# BACKUP CONFIG
# =========================================================

backup_config(){

    rm -rf "$BACKUP_DIR"

    mkdir -p "$BACKUP_DIR"


    if [ -d /etc/qtun ]
    then

        cp -a /etc/qtun \
            "$BACKUP_DIR/" 2>/dev/null

        info "Backed up /etc/qtun"

    fi


    if [ -f /etc/config/qtun ]
    then

        cp -f /etc/config/qtun \
            "$BACKUP_DIR/" 2>/dev/null

        info "Backed up /etc/config/qtun"

    fi


    if [ -f /etc/init.d/qtun_autoboot ]
    then

        cp -f /etc/init.d/qtun_autoboot \
            "$BACKUP_DIR/" 2>/dev/null

        info "Backed up qtun_autoboot"

    fi
}


# =========================================================
# INSTALL PACKAGE
# =========================================================

install_package(){

    info "Installing local IPK package..."

    opkg install "$PACKAGE_FILE" \
        >>"$LOG_FILE" 2>&1

    if [ $? -ne 0 ]
    then

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

configure_service(){

    echo

    info "Configuring QTUN..."


    if [ -x /etc/init.d/qtun_autoboot ]
    then

        /etc/init.d/qtun_autoboot enable \
            >/dev/null 2>&1

        success "QTUN autoboot enabled."


        /etc/init.d/qtun_autoboot start \
            >/dev/null 2>&1

        success "QTUN service started."

    else

        warning "qtun_autoboot tidak ditemukan."

    fi


    if [ -x /etc/init.d/rpcd ]
    then

        /etc/init.d/rpcd restart \
            >/dev/null 2>&1

        success "rpcd restarted."

    fi
}


# =========================================================
# INSTALL QTUN
# =========================================================

install_qtun(){

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

    update_packages ||
        warning "Continuing without package update..."


    echo

    info "[3/6] Preparing QTUN package..."

    if [ ! -f "$PACKAGE_FILE" ]
    then

        download_package ||
            return 1

    else

        success "Using existing local package."

    fi


    echo

    info "[4/6] Checking package integrity..."

    validate_ipk ||
        return 1


    echo

    info "[5/6] Installing QTUN..."

    install_package ||
        return 1


    echo

    info "[6/6] Configuring QTUN..."

    configure_service


    echo

    success "QTUN installation completed!"

    return 0
}


# =========================================================
# UNINSTALL QTUN
# =========================================================

uninstall_qtun(){

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


            if [ -x /etc/init.d/qtun_autoboot ]
            then

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


            if [ -x /etc/init.d/rpcd ]
            then

                /etc/init.d/rpcd restart \
                    >/dev/null 2>&1

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
# INSTALLATION MENU
# =========================================================

installation_menu(){

    clear

    printf "${CYAN}${BOLD}"

    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                    QTUN INSTALLER                      ║"
    echo "╚════════════════════════════════════════════════════════╝"

    printf "${NC}"

    echo


    if [ "$PACKAGE_INSTALLED" -eq 1 ]
    then

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

final_summary(){

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

    echo

    printf "${CYAN}${BOLD}"

    echo "QTUN siap digunakan."

    printf "${NC}"

    echo
}


# =========================================================
# MAIN
# =========================================================

main(){

    banner


    detect_openwrt ||
        exit 1


    detect_package_manager ||
        exit 1


    detect_architecture ||
        exit 1


    show_system_info


    check_existing


    installation_menu


    echo

    printf "${CYAN}${BOLD}"

    echo "Preparing QTUN installation..."

    printf "${NC}"

    sleep 1

    echo


    check_internet ||
        exit 1


    check_disk ||
        exit 1


    find_package ||
        exit 1


    backup_config


    if install_qtun
    then

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

if [ "$(id -u)" != "0" ]
then

    echo

    error_msg "Installer harus dijalankan sebagai root."

    exit 1

fi


main
