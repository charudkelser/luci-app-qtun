module("luci.controller.qtun", package.seeall)

function index()
    local page = entry({"admin", "services", "qtun"}, alias("admin", "services", "qtun", "dashboard"), _("QTUN"), 10)
    page.dependent = true

    entry({"admin", "services", "qtun", "dashboard"}, template("qtun/dashboard"), _("Dashboard"), 1)
    entry({"admin", "services", "qtun", "config"}, cbi("qtun/config"), _("Tunnel Config"), 2)
    entry({"admin", "services", "qtun", "logs"}, template("qtun/logs"), _("Logs & Terminal"), 5)

    -- API core
    entry({"admin", "services", "qtun", "status"}, call("action_status")).leaf = true
    entry({"admin", "services", "qtun", "start"}, call("action_start")).leaf = true
    entry({"admin", "services", "qtun", "stop"}, call("action_stop")).leaf = true
    entry({"admin", "services", "qtun", "restart"}, call("action_restart")).leaf = true
    entry({"admin", "services", "qtun", "set_config"}, call("action_set_config")).leaf = true

    -- API Account Config (Auto-Load & Save)
    entry({"admin", "services", "qtun", "get_account_config"}, call("action_get_account_config")).leaf = true
    entry({"admin", "services", "qtun", "save_account_config"}, call("action_save_account_config")).leaf = true

    -- API Clash
    entry({"admin", "services", "qtun", "clash_sub_save"}, call("action_clash_sub_save")).leaf = true
    entry({"admin", "services", "qtun", "clash_sub_update"}, call("action_clash_sub_update")).leaf = true
    entry({"admin", "services", "qtun", "clash_sub_list"}, call("action_clash_sub_list")).leaf = true
    entry({"admin", "services", "qtun", "clash_profile_get"}, call("action_clash_profile_get")).leaf = true
    entry({"admin", "services", "qtun", "clash_profile_save"}, call("action_clash_profile_save")).leaf = true
    entry({"admin", "services", "qtun", "clash_profile_delete"}, call("action_clash_profile_delete")).leaf = true
    
    -- API LOGS
    entry({"admin", "services", "qtun", "log"}, call("action_get_log"), nil).leaf = true
    entry({"admin", "services", "qtun", "get_log"}, call("action_get_log"), nil).leaf = true
    
    entry({"qtun", "ipinfo"}, call("action_ipinfo")).leaf = true
end

local function file_exists(path)
    local fs = require "nixio.fs"
    return fs.access(path)
end

local function readfile(path, fallback)
    local fs = require "nixio.fs"
    return fs.readfile(path) or fallback or ""
end

-- MAPPER NAMA MODE KE SECTION UCI
local function get_uci_section(mode)
    mode = mode or "q-ssh"
    if mode == "q-ssh" or mode == "q_ssh" then return "q_ssh" end
    if mode == "ssh_ws" then return "ssh_ws" end
    if mode == "ssh_ssl" then return "ssh_ssl" end
    return mode
end

local function get_uptime_seconds()
    local fs = require "nixio.fs"
    local time_file = "/tmp/qtun_start_time"
    if not fs.access(time_file) then return 0 end
    local start_stamp = tonumber(fs.readfile(time_file) or "0") or 0
    if start_stamp == 0 then return 0 end
    local sys = require "luci.sys"
    local now_stamp = tonumber(sys.exec("date +%s") or "0") or 0
    local diff = now_stamp - start_stamp
    return (diff > 0) and diff or 0
end

-- FIXED: KHUSUS MEMBACA TRAFIK MODEM wwan0 / TUNNEL INTERFACE
local function get_data_usage_bytes()
    local sys = require "luci.sys"
    local uci = require("luci.model.uci").cursor()
    local mode = uci:get("qtun", "main", "mode") or "q-ssh"
    local net_info = sys.exec("cat /proc/net/dev 2>/dev/null")
    local total_bytes = 0

    if net_info then
        for line in net_info:gmatch("[^\r\n]+") do
            local matched = false
            
            if line:match("tun%d*:") or line:match("clash:") or line:match("zivpn:") or line:match("qtun:") then
                matched = true
            elseif mode == "q-ssh" or mode == "ssh" or mode == "ssh_ws" or mode == "ssh_ssl" then
                if line:match("wwan%d*:") or line:match("eth%d*:") or line:match("wan:") then
                    matched = true
                end
            end

            if matched then
                local rx, tx = line:match(":%s*(%d+)%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+(%d+)")
                if rx and tx then
                    total_bytes = total_bytes + (tonumber(rx) or 0) + (tonumber(tx) or 0)
                end
            end
        end
    end
    return total_bytes
end

local function list_clash_profiles()
    local fs = require "nixio.fs"
    local dir = "/etc/qtun/config/clash/mihomo"
    local profiles = {}
    if not fs.access(dir) then return profiles end
    for file in fs.dir(dir) do
        if file and file:match("%.ya?ml$") then profiles[#profiles + 1] = file end
    end
    table.sort(profiles)
    return profiles
end

local function first_clash_profile()
    local profiles = list_clash_profiles()
    return profiles[1] or ""
end

local function ensure_clash_section(uci)
    if not uci:get("qtun", "clash") then
        uci:section("qtun", "clash", "clash", {})
    end
end

-- API: AMBIL CONFIG AKUN SESUAI MODE
function action_get_account_config()
    local http = require "luci.http"
    local uci = require("luci.model.uci").cursor()

    local mode = http.formvalue("mode") or uci:get("qtun", "main", "mode") or "q-ssh"
    local sec = get_uci_section(mode)

    local data = {
        mode = mode,
        host = uci:get("qtun", sec, "host") or uci:get("qtun", sec, "server_host") or "",
        port = uci:get("qtun", sec, "port") or uci:get("qtun", sec, "server_port") or "",
        user = uci:get("qtun", sec, "username") or uci:get("qtun", sec, "user") or "",
        pass = uci:get("qtun", sec, "password") or uci:get("qtun", sec, "pass") or "",
        workers = uci:get("qtun", sec, "workers") or uci:get("qtun", sec, "worker") or "",
        proxy_host = uci:get("qtun", sec, "proxy_host") or "",
        proxy_port = uci:get("qtun", sec, "proxy_port") or "",
        payload = uci:get("qtun", sec, "payload") or "",
        expect = uci:get("qtun", sec, "expect_status") or uci:get("qtun", sec, "expect") or ""
    }

    http.prepare_content("application/json")
    http.write_json(data)
end

-- API: SIMPAN CONFIG AKUN
function action_save_account_config()
    local http = require "luci.http"
    local uci = require("luci.model.uci").cursor()

    local mode = http.formvalue("mode") or "q-ssh"
    local sec = get_uci_section(mode)

    if not uci:get("qtun", sec) then
        uci:section("qtun", sec, sec, {})
    end

    uci:set("qtun", sec, "host", http.formvalue("host") or "")
    uci:set("qtun", sec, "port", http.formvalue("port") or "")
    uci:set("qtun", sec, "username", http.formvalue("user") or "")
    uci:set("qtun", sec, "password", http.formvalue("pass") or "")
    uci:set("qtun", sec, "workers", http.formvalue("workers") or "")
    uci:set("qtun", sec, "proxy_host", http.formvalue("proxy_host") or "")
    uci:set("qtun", sec, "proxy_port", http.formvalue("proxy_port") or "")
    uci:set("qtun", sec, "payload", http.formvalue("payload") or "")
    uci:set("qtun", sec, "expect_status", http.formvalue("expect") or "")

    uci:commit("qtun")

    http.prepare_content("application/json")
    http.write_json({ success = true, mode = mode })
end

function action_status()
    local sys = require "luci.sys"
    local fs = require "nixio.fs"
    local uci = require("luci.model.uci").cursor()

    local mode = uci:get("qtun", "main", "mode") or "zivpn"
    local enabled = uci:get("qtun", "main", "enabled") or "0"
    local pingloop = uci:get("qtun", "main", "pingloop") or "0"
    local ping_target = uci:get("qtun", "main", "ping_target") or "google.com"
    local ping_interval = uci:get("qtun", "main", "ping_interval") or "5"
    local backend = uci:get("qtun", "main", "backend") or "clash"

    local clash_profile = uci:get("qtun", "clash", "profile") or ""
    local clash_profiles = list_clash_profiles()

    if clash_profile == "" then clash_profile = first_clash_profile() end

    local running = false

    if mode == "q-ssh" then
        running = (sys.call("pgrep Q-SSH-WORKER >/dev/null") == 0) or (sys.call("pgrep q-load >/dev/null") == 0)
    elseif mode == "zivpn" then
        running = (sys.call("pgrep zivpn >/dev/null") == 0) or (sys.call("pgrep mihomo >/dev/null") == 0)
    elseif mode == "clash" then
        running = (sys.call("pgrep clash >/dev/null") == 0) or (sys.call("pgrep mihomo >/dev/null") == 0)
    elseif mode == "ssh" or mode == "ssh_ws" or mode == "ssh_ssl" then
        running = (sys.call("[ -f /etc/qtun/run/ssh_worker.pid ] && kill -0 $(cat /etc/qtun/run/ssh_worker.pid) 2>/dev/null") == 0)
    else 
        running = (sys.call("pgrep clash >/dev/null") == 0) or (sys.call("pgrep mihomo >/dev/null") == 0)
    end

    local time_file = "/tmp/qtun_start_time"
    if running then
        if not fs.access(time_file) then sys.exec("date +%s > " .. time_file) end
    else
        if fs.access(time_file) then fs.remove(time_file) end
    end

    local uptime_sec = get_uptime_seconds()
    local bytes_used = get_data_usage_bytes()

    local clash_running = (sys.call("[ -f /etc/qtun/run/clash.pid ] && kill -0 $(cat /etc/qtun/run/clash.pid) 2>/dev/null") == 0)

    -- =========================================================
    -- BACA INDIKATOR PING REALTIME DARI /tmp/qtun_ping_status
    -- =========================================================
    local ping_state = "none"
    local f = io.open("/tmp/qtun_ping_status", "r")
    if f then
        ping_state = f:read("*l") or "none"
        f:close()
    end
    ping_state = ping_state:gsub("%s+", "")

    local data = {
        running = running,
        clash_running = clash_running,
        mode = mode,
        backend = backend,
        enabled = enabled,
        pingloop = pingloop,
        ping_target = ping_target,
        ping_interval = ping_interval,
        clash_profile = clash_profile,
        clash_profiles = clash_profiles,
        uptime = uptime_sec,
        bytes_used = bytes_used,
        ping_status = ping_state -- Mengirim "1", "0", atau "none"
    }

    luci.http.prepare_content("application/json")
    luci.http.write_json(data)
end

function action_start()
    local sys = require "luci.sys"
    sys.exec("date +%s > /tmp/qtun_start_time")
    sys.call("/etc/qtun/action/qtun.sh start >/dev/null 2>&1 &")

    luci.http.prepare_content("application/json")
    luci.http.write_json({ success = true, action = "start" })
end

function action_stop()
    local sys = require "luci.sys"
    local fs = require "nixio.fs"
    fs.remove("/tmp/qtun_start_time")
    sys.call("/etc/qtun/action/qtun.sh stop >/dev/null 2>&1 &")

    luci.http.prepare_content("application/json")
    luci.http.write_json({ success = true, action = "stop" })
end

function action_restart()
    local sys = require "luci.sys"
    sys.exec("date +%s > /tmp/qtun_start_time")
    sys.call("/etc/qtun/action/qtun.sh restart >/dev/null 2>&1 &")

    luci.http.prepare_content("application/json")
    luci.http.write_json({ success = true, action = "restart" })
end

-- FIXED: MENGINJECT SIMPAN PINGLOOP & TARGET KE CONFIG UCI
function action_set_config()
    local http = require "luci.http"
    local uci = require("luci.model.uci").cursor()

    local mode = http.formvalue("mode")
    local enabled = http.formvalue("enabled")
    local pingloop = http.formvalue("pingloop")
    local ping_target = http.formvalue("ping_target")
    local ping_interval = http.formvalue("ping_interval")
    local backend = http.formvalue("backend")
    local clash_profile = http.formvalue("clash_profile")

    if mode then
        uci:set("qtun", "main", "mode", mode)
        if mode == "clash" or mode == "zivpn" or mode == "q-ssh" then
            uci:delete("qtun", "main", "backend")
        else
            if backend then uci:set("qtun", "main", "backend", backend) end
        end
    end

    if enabled then uci:set("qtun", "main", "enabled", enabled) end
    if pingloop then uci:set("qtun", "main", "pingloop", pingloop) end
    if ping_target then uci:set("qtun", "main", "ping_target", ping_target) end
    if ping_interval then uci:set("qtun", "main", "ping_interval", ping_interval) end

    if backend and mode ~= "clash" and mode ~= "zivpn" and mode ~= "q-ssh" then
        uci:set("qtun", "main", "backend", backend)
    end

    if clash_profile then
        ensure_clash_section(uci)
        uci:set("qtun", "clash", "profile", clash_profile)
    end

    uci:commit("qtun")

    luci.http.prepare_content("application/json")
    luci.http.write_json({ success = true })
end

local function sanitize_yaml_name(name)
    name = name or ""
    name = name:gsub("[/\\]", ""):gsub("%.%.", ""):gsub("%s+", "_")
    if name == "" then name = "clash.yaml" end
    if not name:match("%.ya?ml$") then name = name .. ".yaml" end
    return name
end

function action_clash_profile_get()
    local http = require "luci.http"
    local fs = require "nixio.fs"
    local dir = "/etc/qtun/config/clash/mihomo"
    local file = sanitize_yaml_name(http.formvalue("file"))
    local path = dir .. "/" .. file
    fs.mkdirr(dir)
    if not fs.access(path) then
        http.prepare_content("application/json")
        http.write_json({ success = false, message = "File tidak ditemukan: " .. file })
        return
    end
    http.prepare_content("application/json")
    http.write_json({ success = true, file = file, content = fs.readfile(path) or "" })
end

function action_clash_profile_save()
    local http = require "luci.http"
    local fs = require "nixio.fs"
    local dir = "/etc/qtun/config/clash/mihomo"
    local file = sanitize_yaml_name(http.formvalue("file"))
    local content = http.formvalue("content") or ""
    fs.mkdirr(dir)
    if file == "" or file == ".yaml" then
        http.prepare_content("application/json")
        http.write_json({ success = false, message = "Nama file tidak valid" })
        return
    end
    fs.writefile(dir .. "/" .. file, content)
    http.prepare_content("application/json")
    http.write_json({ success = true, file = file })
end

function action_clash_profile_delete()
    local http = require "luci.http"
    local fs = require "nixio.fs"
    local uci = require("luci.model.uci").cursor()
    local dir = "/etc/qtun/config/clash/mihomo"
    local file = sanitize_yaml_name(http.formvalue("file"))
    local active = uci:get("qtun", "clash", "profile") or ""

    if file == active then
        http.prepare_content("application/json")
        http.write_json({ success = false, message = "Tidak boleh delete config yang sedang aktif" })
        return
    end

    fs.remove(dir .. "/" .. file)
    http.prepare_content("application/json")
    http.write_json({ success = true, file = file })
end

-- SMART LOG ENGINE
function action_get_log()
    local fs = require "nixio.fs"
    local uci = require("luci.model.uci").cursor()
    local mode = uci:get("qtun", "main", "mode") or "zivpn"
    
    local log_file = "/etc/qtun/run/zivpn.log"

    if mode == "q-ssh" then
        log_file = "/etc/qtun/run/q-ssh.log"
    elseif mode == "zivpn" then
        log_file = "/etc/qtun/run/zivpn.log"
    elseif mode == "ssh" or mode == "ssh_ws" or mode == "ssh_ssl" then
        log_file = "/etc/qtun/run/ssh.log"
    elseif mode == "clash" then
        log_file = "/etc/qtun/run/clash.log"
    end

    local log_content = fs.readfile(log_file)
    
    if not log_content or log_content == "" then
        log_content = fs.readfile("/etc/qtun/run/qtun_live.log")
    end

    if not log_content or log_content == "" then
        log_content = "[SYSTEM] Belum ada aktivitas log tercatat untuk mode: " .. string.upper(mode)
    end

    luci.http.prepare_content("text/plain")
    luci.http.write(log_content)
end

function action_ipinfo()
    local sys = require "luci.sys"
    local result = sys.exec("curl -s --max-time 8 http://ip-api.com/json 2>/dev/null")
    if result == nil or result == "" then
        result = '{"status":"fail","message":"Unable to fetch IP info"}'
    end
    luci.http.prepare_content("application/json")
    luci.http.write(result)
end
