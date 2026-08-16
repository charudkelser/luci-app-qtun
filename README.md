# luci-app-qtun

LuCI interface untuk Q-Tunneling dengan dukungan:

- ZiVPN (UDP)
- Clash / Mihomo
- Q-Load Core
- SSH (Coming Soon)
- SSH WebSocket (SSH-WS) (Coming Soon)
- SSH SSL (SSH-SSL) (Coming Soon)

Dirancang untuk OpenWrt dengan auto-download core saat build dan integrasi penuh ke LuCI.

---

<h1 align="center">
  <img src="https://raw.githubusercontent.com/QcomWrt/luci-app-qtun/master/img/main.png" alt="QTUN Dashboard" width="100%">
  <br>QTUN Dashboard
</h1>

<h1 align="center">
  <img src="https://raw.githubusercontent.com/QcomWrt/luci-app-qtun/master/img/yacd.png" alt="YACD" width="100%">
  <br>YACD
</h1>

<h1 align="center">
  <img src="https://raw.githubusercontent.com/QcomWrt/luci-app-qtun/master/img/logs.png" alt="QTUN Dashboard Logs" width="100%">
  <br>QTUN Dashboard Logs
</h1>

---

## 📦 Instalasi Package (.ipk / .apk)

### ⚡ 1-Liner Auto Install via Wget (Rekomendasi)

Installer otomatis akan mendeteksi OpenWrt, arsitektur perangkat, memilih package yang sesuai, mengunduh package, melakukan validasi, menginstal QTUN, mengaktifkan autoboot, menjalankan service, dan me-restart rpcd.

**Auto Installer:**

```bash
wget --no-check-certificate -O /tmp/install.sh https://raw.githubusercontent.com/charudkelser/qtun-installer-test/main/install.sh && sh /tmp/install.sh
```

> Installer sedang dikembangkan dan diuji pada beberapa versi OpenWrt. Gunakan package manual di bawah jika ingin instalasi secara langsung.

### 📌 Universal / All Architecture

```bash
opkg update && wget --no-check-certificate -O /tmp/luci-app-qtun_1.0.6_all.ipk https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_all.ipk && opkg install /tmp/luci-app-qtun_1.0.6_all.ipk && rm -f /tmp/luci-app-qtun_1.0.6_all.ipk && /etc/init.d/qtun_autoboot enable && /etc/init.d/qtun_autoboot start && /etc/init.d/rpcd restart
```

### 📌 Khusus OpenWrt 21.02 (Firmware STB / Custom Mod)

Untuk firmware OpenWrt 21.02 yang membutuhkan registrasi architecture `all` dan instalasi package tanpa validasi dependency bawaan:

```bash
grep -q "arch all 100" /etc/opkg.conf || echo "arch all 100" >> /etc/opkg.conf && opkg update && wget --no-check-certificate -O /tmp/luci-app-qtun_1.0.6_all.ipk https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_all.ipk && opkg install --nodeps --force-depends /tmp/luci-app-qtun_1.0.6_all.ipk && rm -f /tmp/luci-app-qtun_1.0.6_all.ipk && /etc/init.d/qtun_autoboot enable && /etc/init.d/qtun_autoboot start && /etc/init.d/rpcd restart
```

### 📌 ARM64 - Cortex A55 (aarch64_cortex-a55)

```bash
opkg update && wget --no-check-certificate -O /tmp/luci-app-qtun_1.0.6_aarch64_cortex-a55.ipk https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_aarch64_cortex-a55.ipk && opkg install /tmp/luci-app-qtun_1.0.6_aarch64_cortex-a55.ipk && rm -f /tmp/luci-app-qtun_1.0.6_aarch64_cortex-a55.ipk && /etc/init.d/qtun_autoboot enable && /etc/init.d/qtun_autoboot start && /etc/init.d/rpcd restart
```

### 📌 ARM64 Generic (aarch64_generic)

```bash
opkg update && wget --no-check-certificate -O /tmp/luci-app-qtun_1.0.6_aarch64_generic.ipk https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_aarch64_generic.ipk && opkg install /tmp/luci-app-qtun_1.0.6_aarch64_generic.ipk && rm -f /tmp/luci-app-qtun_1.0.6_aarch64_generic.ipk && /etc/init.d/qtun_autoboot enable && /etc/init.d/qtun_autoboot start && /etc/init.d/rpcd restart
```

### 📌 ARMv7 Neon (arm_cortex-a7_neon-vfpv4)

```bash
opkg update && wget --no-check-certificate -O /tmp/luci-app-qtun_1.0.6_arm_cortex-a7_neon-vfpv4.ipk https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_arm_cortex-a7_neon-vfpv4.ipk && opkg install /tmp/luci-app-qtun_1.0.6_arm_cortex-a7_neon-vfpv4.ipk && rm -f /tmp/luci-app-qtun_1.0.6_arm_cortex-a7_neon-vfpv4.ipk && /etc/init.d/qtun_autoboot enable && /etc/init.d/qtun_autoboot start && /etc/init.d/rpcd restart
```

### 📌 ARMv7 (arm_cortex-a9)

```bash
opkg update && wget --no-check-certificate -O /tmp/luci-app-qtun_1.0.6_arm_cortex-a9.ipk https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_arm_cortex-a9.ipk && opkg install /tmp/luci-app-qtun_1.0.6_arm_cortex-a9.ipk && rm -f /tmp/luci-app-qtun_1.0.6_arm_cortex-a9.ipk && /etc/init.d/qtun_autoboot enable && /etc/init.d/qtun_autoboot start && /etc/init.d/rpcd restart
```

### 📌 x86_64 / PC AMD64 (x86_64)

```bash
opkg update && wget --no-check-certificate -O /tmp/luci-app-qtun_1.0.6_x86_64.ipk https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_x86_64.ipk && opkg install /tmp/luci-app-qtun_1.0.6_x86_64.ipk && rm -f /tmp/luci-app-qtun_1.0.6_x86_64.ipk && /etc/init.d/qtun_autoboot enable && /etc/init.d/qtun_autoboot start && /etc/init.d/rpcd restart
```

---

## 📤 Metode Upload SCP (Manual)

Upload file ke `/tmp`:

```bash
scp luci-app-qtun.ipk root@192.168.1.1:/tmp/
```

Untuk APK:

```bash
scp luci-app-qtun.apk root@192.168.1.1:/tmp/
```

### OPKG - OpenWrt 21

```bash
grep -q "arch all 100" /etc/opkg.conf || echo "arch all 100" >> /etc/opkg.conf
```

```bash
opkg install --nodeps --force-depends /tmp/luci-app-qtun_1.0.6_all.ipk
/etc/init.d/qtun_autoboot enable
/etc/init.d/qtun_autoboot start
/etc/init.d/rpcd restart
```

### OPKG - OpenWrt 22 / 23 / 24

```bash
opkg install --nodeps --force-depends /tmp/luci-app-qtun_1.0.6_all.ipk
/etc/init.d/qtun_autoboot enable
/etc/init.d/qtun_autoboot start
/etc/init.d/rpcd restart
```

### Restart Web UI Service (Jika Dibutuhkan)

```bash
/etc/init.d/uhttpd restart 2>/dev/null || /etc/init.d/rpcd restart
```

---

## 📦 Install Dependency Manual (Jika Diperlukan)

### OPKG

```bash
opkg update
opkg install luci-compat bash curl ca-bundle ca-certificates jq
```

### APK

```bash
apk update
apk add luci-compat bash curl ca-bundle ca-certificates jq
```

---

## 🚀 Fitur Utama

- Auto Download Core
- Mihomo Core
- Q-Load Core
- ZiVPN Core
- LuCI Web UI
- Multi tunnel support
- Config management
- Auto boot
- Script action modular

---

## 🛠 Arsitektur Support

- AMD64 / x86_64
- ARM64 / aarch64
  - aarch64_cortex-a53
  - aarch64_cortex-a55
  - aarch64_generic
- ARM / armv7
  - arm_cortex-a7_neon-vfpv4
  - arm_cortex-a9

---

## 🧠 Troubleshooting

### Cek log

```bash
logread -f
```

### Cek service

```bash
/etc/qtun/action/qtun.sh status
```

### Restart service

```bash
/etc/qtun/action/qtun.sh restart
```

### Cek status autoboot

```bash
/etc/init.d/qtun_autoboot status
```

### Restart LuCI / RPCD

```bash
/etc/init.d/rpcd restart
```

---

## ❌ Uninstall

```bash
opkg remove luci-app-qtun
rm -rf /etc/qtun /etc/config/qtun /etc/init.d/qtun_autoboot
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache/
/etc/init.d/rpcd restart
```

---

## 🔖 Release

Build release tersedia di tab Releases:

https://github.com/QcomWrt/luci-app-qtun/releases

---

## 📜 License

MIT License

### Core / Binaries

- ZiVPN by zahidbd2
- Q-load by QcomWrt
- Clash / Mihomo by MetaCubeX

---

## 👤 Maintainer

**Azy / QcomWrt**
