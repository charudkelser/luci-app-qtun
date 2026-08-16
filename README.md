# luci-app-qtun

LuCI interface untuk Q-Tunneling dengan dukungan:

- ZiVPN (UDP)
- Clash / Mihomo
- Q-Load Core
- SSH *(Coming Soon)*
- SSH WebSocket (SSH-WS) *(Coming Soon)*
- SSH SSL (SSH-SSL) *(Coming Soon)*

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

Silakan pilih satu perintah di bawah ini yang sesuai dengan arsitektur dan versi OpenWrt perangkat kamu:

#### 📌 Universal / All Architecture (Rekomendasi OpenWrt 22.03+)
```bash
opkg update && wget --no-check-certificate -O /tmp/luci-app-qtun_1.0.6_all.ipk [https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_all.ipk](https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_all.ipk) && opkg install /tmp/luci-app-qtun_1.0.6_all.ipk && rm -f /tmp/luci-app-qtun_1.0.6_all.ipk && /etc/init.d/qtun_autoboot enable && /etc/init.d/qtun_autoboot start && /etc/init.d/rpcd restart
```
📌 Khusus OpenWrt 21.02 (Firmware STB / Custom Mod)
​Memperbaiki kendala architecture mismatch dan validasi dependensi kernel/libc bawaan OpenWrt 21:

```bash
grep -q "arch all 100" /etc/opkg.conf || echo "arch all 100" >> /etc/opkg.conf && opkg update && wget --no-check-certificate -O /tmp/luci-app-qtun_1.0.6_all.ipk [https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_all.ipk](https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_all.ipk) && opkg install --nodeps --force-depends /tmp/luci-app-qtun_1.0.6_all.ipk && rm -f /tmp/luci-app-qtun_1.0.6_all.ipk && /etc/init.d/qtun_autoboot enable && /etc/init.d/qtun_autoboot start && /etc/init.d/rpcd restart
```

📌 ARM64 - Cortex A55 (aarch64_cortex-a55)

```bash
opkg update && wget --no-check-certificate -O /tmp/luci-app-qtun_1.0.6_aarch64_cortex-a55.ipk [https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_aarch64_cortex-a55.ipk](https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_aarch64_cortex-a55.ipk) && opkg install /tmp/luci-app-qtun_1.0.6_aarch64_cortex-a55.ipk && rm -f /tmp/luci-app-qtun_1.0.6_aarch64_cortex-a55.ipk && /etc/init.d/qtun_autoboot enable && /etc/init.d/qtun_autoboot start && /etc/init.d/rpcd restart
```

📌 ARM64 Generic (aarch64_generic)

```bash
opkg update && wget --no-check-certificate -O /tmp/luci-app-qtun_1.0.6_aarch64_generic.ipk [https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_aarch64_generic.ipk](https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_aarch64_generic.ipk) && opkg install /tmp/luci-app-qtun_1.0.6_aarch64_generic.ipk && rm -f /tmp/luci-app-qtun_1.0.6_aarch64_generic.ipk && /etc/init.d/qtun_autoboot enable && /etc/init.d/qtun_autoboot start && /etc/init.d/rpcd restart
```

📌 ARMv7 Neon (arm_cortex-a7_neon-vfpv4)

```bash
opkg update && wget --no-check-certificate -O /tmp/luci-app-qtun_1.0.6_arm_cortex-a7_neon-vfpv4.ipk [https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_arm_cortex-a7_neon-vfpv4.ipk](https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_arm_cortex-a7_neon-vfpv4.ipk) && opkg install /tmp/luci-app-qtun_1.0.6_arm_cortex-a7_neon-vfpv4.ipk && rm -f /tmp/luci-app-qtun_1.0.6_arm_cortex-a7_neon-vfpv4.ipk && /etc/init.d/qtun_autoboot enable && /etc/init.d/qtun_autoboot start && /etc/init.d/rpcd restart
```

📌 ARMv7 (arm_cortex-a9)

```bash
opkg update && wget --no-check-certificate -O /tmp/luci-app-qtun_1.0.6_arm_cortex-a9.ipk [https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_arm_cortex-a9.ipk](https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_arm_cortex-a9.ipk) && opkg install /tmp/luci-app-qtun_1.0.6_arm_cortex-a9.ipk && rm -f /tmp/luci-app-qtun_1.0.6_arm_cortex-a9.ipk && /etc/init.d/qtun_autoboot enable && /etc/init.d/qtun_autoboot start && /etc/init.d/rpcd restart
```

📌 x86_64 / PC AMD64 (x86_64)

```bash
opkg update && wget --no-check-certificate -O /tmp/luci-app-qtun_1.0.6_x86_64.ipk [https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_x86_64.ipk](https://github.com/charudkelser/luci-app-qtun/releases/download/v1.0.6/luci-app-qtun_1.0.6_x86_64.ipk) && opkg install /tmp/luci-app-qtun_1.0.6_x86_64.ipk && rm -f /tmp/luci-app-qtun_1.0.6_x86_64.ipk && /etc/init.d/qtun_autoboot enable && /etc/init.d/qtun_autoboot start && /etc/init.d/rpcd restart
```

## Metode Upload SCP (Manual)
Upload File ke /tmp

```bash
scp luci-app-qtun.ipk root@192.168.1.1:/tmp/
```

```bash
scp luci-app-qtun.apk root@192.168.1.1:/tmp/
```

Eksekusi Instalasi Manual

```bash
OPKG (OpenWrt 21)

```grep -q "arch all 100" /etc/opkg.conf || echo "arch all 100" >> /etc/opkg.conf
```

```bash
opkg install --nodeps --force-depends /tmp/luci-app-qtun_1.0.6_all.ipk
/etc/init.d/qtun_autoboot enable
/etc/init.d/qtun_autoboot start
/etc/init.d/rpcd restart
```

### OPKG (OpenWrt 22 / 23 / 24)

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

### 📦 Install Dependency Manual (jika diperlukan)

```bash
opkg update
opkg install luci-compat bash curl ca-bundle ca-certificates jq
```

```bash
apk update
apk add luci-compat bash curl ca-bundle ca-certificates jq
```

**🚀 Fitur Utama**  
Autoo Download Core  
Mihomoo Core  
Q-Loadd Core  
ZiVPNN Core  
LuCII Features  
LuCII Web UI  
Multi tunnel support  
Configg management  
Autoo boot  
Script action modular  
​🛠 Arsitektur Support  
AMD64 / x86_64  
ARM64 / aarch64 (aarch64_cortex-a53 / aarch64_cortex-a55)  
ARM / armv7 (arm_cortex-a7_neon-vfpv4 / arm_cortex-a9)  
  
**🧠 Troubleshooting**
​Cek log  

```bash
logread -f
```

Cek service
```bash
/etc/qtun/action/qtun.sh status
```

Restart service

```bash
/etc/qtun/action/qtun.sh restart
```

❌ Uninstall

```bash

opkg remove luci-app-qtun
rm -rf /etc/qtun /etc/config/qtun /etc/init.d/qtun_autoboot
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache/
/etc/init.d/rpcd restart
```


🔖 Release  

​Build release tersedia di tab Releases:
​https://github.com/QcomWrt/luci-app-qtun/releases  
​📜 License  
MIT License  
Core / Binaries  
Zivpnn Zivpn by zahidbd2  
Q-loadQ-load by QcomWrt  
Clashh Mihomo by MetaCubeX  
​👤 Maintainer
​Azy / QcomWrt




