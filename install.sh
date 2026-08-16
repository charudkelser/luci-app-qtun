#!/bin/sh

# =========================================================
# QTUN AUTO INSTALLER
# =========================================================

VERSION="1.0.6"
REPO="charudkelser/luci-app-qtun"
BASE_URL="https://github.com/$REPO/releases/download/v$VERSION"

TMP_DIR="/tmp"
PACKAGE_FILE="$TMP_DIR/luci-app-qtun_${VERSION}.ipk"

echo "========================================"
echo "        QTUN AUTO INSTALLER"
echo "========================================"
echo

# =========================================================
# CHECK OPENWRT
# =========================================================

if [ ! -f /etc/openwrt_release ]; then
    echo "[ERROR] OpenWrt tidak terdeteksi."
    exit 1
fi

. /etc/openwrt_release

echo "[OK] OpenWrt  : $DISTRIB_RELEASE"
echo "[OK] Revision  : $DISTRIB_REVISION"
echo "[OK] Machine   : $(uname -m)"

# =========================================================
# DETECT OPKG ARCHITECTURE
# =========================================================

BEST_ARCH=""
BEST_PRIORITY=""

while read -r TYPE ARCH PRIORITY
do
    [ "$TYPE" = "arch" ] || continue

    # Jangan pilih architecture "all"
    [ "$ARCH" = "all" ] && continue

    if [ -z "$BEST_PRIORITY" ] || [ "$PRIORITY" -gt "$BEST_PRIORITY" ]; then
        BEST_ARCH="$ARCH"
        BEST_PRIORITY="$PRIORITY"
    fi

done <<EOF
$(opkg print-architecture 2>/dev/null)
EOF

if [ -z "$BEST_ARCH" ]; then
    echo "[ERROR] Architecture opkg tidak ditemukan."
    exit 1
fi

echo "[OK] Selected Arch : $BEST_ARCH"
echo "[OK] Priority      : $BEST_PRIORITY"

# =========================================================
# PACKAGE SELECTION
# =========================================================

SPECIFIC_PACKAGE="luci-app-qtun_${VERSION}_${BEST_ARCH}.ipk"
SPECIFIC_URL="$BASE_URL/$SPECIFIC_PACKAGE"

UNIVERSAL_PACKAGE="luci-app-qtun_${VERSION}_all.ipk"
UNIVERSAL_URL="$BASE_URL/$UNIVERSAL_PACKAGE"

echo
echo "[+] Checking package..."

# ---------------------------------------------------------
# TRY ARCHITECTURE-SPECIFIC PACKAGE
# ---------------------------------------------------------

if wget --no-check-certificate --spider -q "$SPECIFIC_URL" 2>/dev/null; then

    SELECTED_PACKAGE="$SPECIFIC_PACKAGE"
    SELECTED_URL="$SPECIFIC_URL"

    echo "[OK] Specific package found:"
    echo "     $SELECTED_PACKAGE"

else

    echo "[INFO] Specific package not found."
    echo "[+] Using universal package..."

    # -----------------------------------------------------
    # FALLBACK TO ALL PACKAGE
    # -----------------------------------------------------

    if wget --no-check-certificate --spider -q "$UNIVERSAL_URL" 2>/dev/null; then

        SELECTED_PACKAGE="$UNIVERSAL_PACKAGE"
        SELECTED_URL="$UNIVERSAL_URL"

        echo "[OK] Universal package found:"
        echo "     $SELECTED_PACKAGE"

    else

        echo
        echo "[ERROR] Compatible QTUN package tidak ditemukan."
        exit 1
    fi
fi

# =========================================================
# OPKG UPDATE
# =========================================================

echo
echo "[+] Updating package lists..."

opkg update

if [ $? -ne 0 ]; then
    echo
    echo "[ERROR] opkg update gagal."
    exit 1
fi

echo "[OK] Package lists updated."

# =========================================================
# DOWNLOAD
# =========================================================

echo
echo "[+] Downloading QTUN..."
echo "    $SELECTED_PACKAGE"
echo

rm -f "$PACKAGE_FILE"

wget --no-check-certificate \
    -O "$PACKAGE_FILE" \
    "$SELECTED_URL"

if [ $? -ne 0 ]; then
    echo
    echo "[ERROR] Download QTUN gagal."
    rm -f "$PACKAGE_FILE"
    exit 1
fi

if [ ! -s "$PACKAGE_FILE" ]; then
    echo
    echo "[ERROR] File package kosong."
    rm -f "$PACKAGE_FILE"
    exit 1
fi

echo
echo "[OK] Download completed."

# =========================================================
# BASIC IPK VALIDATION
# =========================================================

echo
echo "[+] Checking IPK..."

TAR_LIST="$(tar -tf "$PACKAGE_FILE" 2>/dev/null)"

if [ -z "$TAR_LIST" ]; then
    echo "[ERROR] Package tidak dapat dibaca."
    rm -f "$PACKAGE_FILE"
    exit 1
fi

if ! echo "$TAR_LIST" | grep -q "^debian-binary$"; then
    echo "[ERROR] debian-binary tidak ditemukan."
    rm -f "$PACKAGE_FILE"
    exit 1
fi

if ! echo "$TAR_LIST" | grep -q "^control.tar.gz$"; then
    echo "[ERROR] control.tar.gz tidak ditemukan."
    rm -f "$PACKAGE_FILE"
    exit 1
fi

if ! echo "$TAR_LIST" | grep -q "^data.tar.gz$"; then
    echo "[ERROR] data.tar.gz tidak ditemukan."
    rm -f "$PACKAGE_FILE"
    exit 1
fi

echo "[OK] IPK package valid."

# =========================================================
# INSTALL
# =========================================================

echo
echo "[+] Installing QTUN..."
echo

opkg install "$PACKAGE_FILE"

if [ $? -ne 0 ]; then
    echo
    echo "[ERROR] QTUN installation gagal."
    echo
    echo "Package disimpan di:"
    echo "$PACKAGE_FILE"
    exit 1
fi

echo
echo "[OK] QTUN installed successfully."

# =========================================================
# CLEANUP PACKAGE
# =========================================================

rm -f "$PACKAGE_FILE"

# =========================================================
# QTUN AUTOBOOT
# =========================================================

echo
echo "[+] Enabling QTUN autoboot..."

if [ -x /etc/init.d/qtun_autoboot ]; then

    /etc/init.d/qtun_autoboot enable

    if [ $? -eq 0 ]; then
        echo "[OK] qtun_autoboot enabled."
    else
        echo "[WARN] Failed to enable qtun_autoboot."
    fi

    echo
    echo "[+] Starting QTUN..."

    /etc/init.d/qtun_autoboot start

    if [ $? -eq 0 ]; then
        echo "[OK] qtun_autoboot started."
    else
        echo "[WARN] Failed to start qtun_autoboot."
    fi

else

    echo "[WARN] /etc/init.d/qtun_autoboot tidak ditemukan."

fi

# =========================================================
# RESTART RPCD
# =========================================================

echo
echo "[+] Restarting rpcd..."

if [ -x /etc/init.d/rpcd ]; then

    /etc/init.d/rpcd restart

    if [ $? -eq 0 ]; then
        echo "[OK] rpcd restarted."
    else
        echo "[WARN] Failed to restart rpcd."
    fi

else

    echo "[WARN] /etc/init.d/rpcd tidak ditemukan."

fi

# =========================================================
# FINISH
# =========================================================

echo
echo "========================================"
echo "       QTUN INSTALLATION COMPLETE"
echo "========================================"
echo
echo "OpenWrt      : $DISTRIB_RELEASE"
echo "Machine      : $(uname -m)"
echo "Architecture : $BEST_ARCH"
echo "Package      : $SELECTED_PACKAGE"
echo
echo "[OK] QTUN installation selesai."
echo
echo "========================================"
