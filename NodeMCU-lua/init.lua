-- Connects to wifi, calls application
-- Enter your ip, netmask, gateway, wifissid, wifiPassword:
local cfg = {
    ip = "192.168.XXX.XXX",
    netmask = "255.255.255.0",
    gateway = "192.168.XXX.XXX"
}
local wifiSsid = "XXXXXXXX"
local wifiPassword = "XXXXXXXX"

function startup()
    if file.open("init.lua") == nil then
        print("init.lua deleted or renamed")
    else
        print("Running")
        file.close("init.lua")
        dofile("NightScout.lua")
    end
end

print("Connecting to WiFi access point...")
    wifi.setmode(wifi.STATION)
    -- Use 802.11n (Can also be set to PHYMODE_B or PHYMODE_G)
    wifi.setphymode(wifi.PHYMODE_N)
    wifi.sleeptype(wifi.NONE_SLEEP)
    wifi.sta.setip(cfg)
    wifi.sta.config(wifiSsid, wifiPassword)

tmr.create():alarm(1000, tmr.ALARM_AUTO, function(cb_timer)
    if wifi.sta.getip() == nil then
        print("Waiting for IP address...")
    else
        cb_timer:unregister()
        print("WiFi connection established, IP address: " .. wifi.sta.getip())
        print("You have 5 seconds to abort")
        print("Waiting...")
        tmr.create():alarm(5000, tmr.ALARM_SINGLE, startup)
    end
end)