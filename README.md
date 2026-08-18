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

## 📦 Instalasi

### 🧩 Compatibility / Support

QTUN dirancang untuk OpenWrt dengan dukungan:

- OpenWrt 21.02
- OpenWrt 22.03
- OpenWrt 23.05
- OpenWrt 24.10

Arsitektur yang tersedia:

- x86_64 / AMD64
- ARM64 / aarch64
  - aarch64_cortex-a53
  - aarch64_cortex-a55
  - aarch64_generic
- ARMv7 / ARM
  - arm_cortex-a7_neon-vfpv4
  - arm_cortex-a9

### ⚡ Auto Installer — Rekomendasi

Cara paling mudah adalah menggunakan Smart Installer. Installer akan otomatis mendeteksi environment OpenWrt dan arsitektur perangkat, memilih package yang sesuai, mengunduh dan memvalidasi package, menginstal QTUN, mengaktifkan autoboot, menjalankan service, dan me-restart rpcd.

```bash
wget --no-check-certificate -O /tmp/install.sh "https://raw.githubusercontent.com/charudkelser/luci-app-qtun/master/install.sh" && chmod +x /tmp/install.sh && /tmp/install.sh
```

## 📦 Install Dependency Tambahan (Jika Diperlukan)

```bash
opkg update

opkg install luci-compat
opkg install bash
opkg install curl
opkg install ca-bundle
opkg install ca-certificates
opkg install jq
opkg install coreutils-nohup
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
