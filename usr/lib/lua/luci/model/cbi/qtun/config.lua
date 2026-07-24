m = Map("qtun", "QTUN - Tunnel Configuration")

m.description = [[
<style type="text/css">
    /* 1. Responsif untuk HP */
    @media screen and (max-width: 600px) {
        .cbi-value { display: flex !important; flex-direction: column !important; margin-bottom: 10px !important; }
        .cbi-value-title { width: 100% !important; text-align: left !important; padding-bottom: 4px !important; }
        .cbi-value-field { width: 100% !important; margin: 0 !important; }
    }

    /* 2. Ruang bawah agar tombol Save & Apply tidak tertutup navbar */
    body, #maincontent, .cbi-map, form {
        padding-bottom: 100px !important;
        background-color: #0f172a !important;
        color: #f8fafc !important;
    }

    /* 3. Sembunyikan judul utama LuCI yang terlalu besar */
    h2 { display: none !important; }

    /* 4. Kotak Info Kuning agar lebih minimalis & modern */
    div[style*="background: #fff3cd"] {
        background: #1e293b !important;
        border-left: 4px solid #38bdf8 !important;
        color: #94a3b8 !important;
        border-radius: 8px !important;
        font-size: 12px !important;
    }

    /* 5. Styling Kotak Input, Dropdown, dan Textarea */
    .cbi-input-text, .cbi-input-select, select, textarea, input[type="text"], input[type="password"] {
        background-color: #090d16 !important;
        border: 1px solid #334155 !important;
        color: #f8fafc !important;
        border-radius: 6px !important;
        padding: 8px 10px !important;
        font-size: 13px !important;
        width: 100% !important;
        box-sizing: border-box !important;
    }

    /* 6. Label Teks (Server Host, Username, dll) */
    .cbi-value-title, label {
        color: #cbd5e1 !important;
        font-size: 12px !important;
        font-weight: 600 !important;
    }

    /* 7. Menghilangkan border kaku bawaan LuCI */
    .cbi-section, .cbi-section-node {
        background: transparent !important;
        border: none !important;
        box-shadow: none !important;
    }

    /* 8. Merapikan area tombol aksi di bawah */
    .cbi-page-actions {
        background: transparent !important;
        border: none !important;
        text-align: center !important;
        margin-top: 20px !important;
        margin-bottom: 40px !important;
        padding: 10px !important;
    }
</style>
<div style="padding: 10px; background: #fff3cd; color: #856404; margin-bottom: 15px;">
    <strong>Info:</strong> Untuk mengedit config silakan pilih dulu <strong>Config Mode</strong> config yang mana yang akan di edit.
</div>

<script type="text/javascript">
    // Mencegah halaman mental saat refresh dengan mempertahankan state dropdown via sessionStorage
    document.addEventListener("DOMContentLoaded", function() {
        var modeSelect = document.querySelector('select[name="cbid.qtun.main.mode_selector"]');
        if (modeSelect) {
            // Cek apakah ada memori mode sebelumnya
            var savedMode = sessionStorage.getItem('qtun_active_mode');
            if (savedMode && !window.location.search.includes('hf')) {
                if (modeSelect.value !== savedMode) {
                    modeSelect.value = savedMode;
                }
            }
            // Simpan saat mode diubah
            modeSelect.addEventListener('change', function() {
                sessionStorage.setItem('qtun_active_mode', this.value);
            });
        }
    });
</script>
]]

s = m:section(NamedSection, "main", "global", "Edit Konfigurasi")
s.addremove = false

-- Dropdown Mode
mode = s:option(ListValue, "mode_selector", "Config Mode")
mode:value("ssh", "SSH Direct")
mode:value("q-ssh","Q SSH(proxy,payload)")
mode:value("clash", "Clash / Mihomo")
mode:value("zivpn", "ZiVPN (UDP)")

local active_mode = m.uci:get("qtun", "main", "mode") or "zivpn"
mode.default = active_mode

-- Kembalikan fungsi write mode ke aslinya agar tombol Save bawaan LuCI tidak error
function mode.write() return end

-- Memuat sub-module
dofile("/usr/lib/lua/luci/model/cbi/qtun/ssh.lua")(s, mode)
dofile("/usr/lib/lua/luci/model/cbi/qtun/mihomo.lua")(s, mode)
dofile("/usr/lib/lua/luci/model/cbi/qtun/zivpn.lua")(s, mode)
dofile("/usr/lib/lua/luci/model/cbi/qtun/q-ssh.lua")(s, mode)

return m
