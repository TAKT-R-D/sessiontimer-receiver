-- SessionTimer clicker receiver — Hammerspoon edition (recommended)
--
-- Official source: https://github.com/TAKT-R-D/sessiontimer-receiver
-- This file is the ONLY thing SessionTimer's clicker talks to on your computer.
-- Read it — it is short on purpose. Security model: see README.md.
--
-- What it does (and ALL it does):
--   GET /next  →  presses the Right Arrow key
--   GET /prev  →  presses the Left Arrow key
-- Any other request gets "404 not found" and presses nothing.
-- No shell commands, no eval, no file reads/writes, no downloads, no auto-update.
--
-- The keystroke goes to the FRONTMOST app, so your slideshow (Keynote, PowerPoint,
-- Google Slides in a browser, a PDF…) must be the front window in presentation mode.
--
-- Setup:
--   1. Install Hammerspoon (https://www.hammerspoon.org/) and grant it Accessibility
--      (System Settings → Privacy & Security → Accessibility).
--   2. Copy this file's contents into ~/.hammerspoon/init.lua (or `require` it from there).
--   3. Hammerspoon menu bar icon → "Reload Config". You should see an on-screen
--      confirmation with the receiver's advertised name.
-- Uninstall: remove these lines from ~/.hammerspoon/init.lua and reload (or quit
-- Hammerspoon). Nothing else was installed or written anywhere.

local PORT = 8722

-- The complete keystroke vocabulary. Fixed by design (1 click = 1 slide):
-- nothing outside this table can ever be pressed.
local KEYS = {
    ["/next"] = "right",
    ["/prev"] = "left",
}

-- 1) HTTP server: listens on every interface at PORT (your iPhone must be able to
--    reach it over your Wi-Fi). Runs only while Hammerspoon runs with this config.
local server = hs.httpserver.new()
server:setPort(PORT)
server:setCallback(function(method, path)
    local key = KEYS[path]
    if method == "GET" and key then
        hs.eventtap.keyStroke({}, key)
        return "ok", 200, {}
    end
    return "not found", 404, {}
end)
server:start()

-- 2) Bonjour advertisement via the macOS built-in /usr/bin/dns-sd (absolute path on
--    purpose), so SessionTimer lists this computer by name — no IP typing.
--    NOTE: keep `clickerBonjour` a GLOBAL (no `local`) so it is not garbage-collected.
local serviceName = "Clicker on " .. (hs.host.localizedName() or "Mac")
clickerBonjour = hs.task.new("/usr/bin/dns-sd",
    nil,
    { "-R", serviceName, "_clicker._tcp", "local.", tostring(PORT) })
clickerBonjour:start()

hs.alert.show("Clicker receiver on :" .. PORT .. "  — advertised as \"" .. serviceName .. "\"")
