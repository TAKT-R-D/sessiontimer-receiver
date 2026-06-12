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
-- The receiver is OFF by default. A "○ Clicker" item appears in the macOS menu
-- bar: click it to start listening before your talk (it turns into "● Clicker"),
-- click again to stop after. It only listens while you have switched it on.
--
-- The keystroke goes to the FRONTMOST app, so your slideshow (Keynote, PowerPoint,
-- Google Slides in a browser, a PDF…) must be the front window in presentation mode.
--
-- Setup:
--   1. Install Hammerspoon (https://www.hammerspoon.org/) and grant it Accessibility
--      (System Settings → Privacy & Security → Accessibility).
--   2. Copy this file's contents into ~/.hammerspoon/init.lua (or `require` it from there).
--   3. Hammerspoon menu bar icon → "Reload Config" → the "○ Clicker" toggle appears.
-- Uninstall: remove these lines from ~/.hammerspoon/init.lua and reload (or quit
-- Hammerspoon). Nothing else was installed or written anywhere.

local PORT = 8722

-- The complete keystroke vocabulary. Fixed by design (1 click = 1 slide):
-- nothing outside this table can ever be pressed.
local KEYS = {
    ["/next"] = "right",
    ["/prev"] = "left",
}

-- NOTE: the server, the Bonjour task, and the menu item are deliberately GLOBALS
-- (no `local`). Lua's garbage collector silently reaps top-level locals after a
-- while — a `local` server here means a receiver that dies mid-session.
clickerServer = nil
clickerBonjour = nil
clickerMenu = hs.menubar.new()

local function refreshMenu()
    if clickerMenu then
        clickerMenu:setTitle(clickerServer and "● Clicker" or "○ Clicker")
    end
end

-- Start listening (menu toggle / call clickerStart() from the console).
function clickerStart()
    if clickerServer then return end

    -- 1) HTTP server: turns /next and /prev into arrow keystrokes. Listens on every
    --    interface at PORT (your iPhone must reach it over your Wi-Fi).
    clickerServer = hs.httpserver.new()
    clickerServer:setPort(PORT)
    clickerServer:setCallback(function(method, path)
        local key = KEYS[path]
        if method == "GET" and key then
            hs.eventtap.keyStroke({}, key)
            return "ok", 200, {}
        end
        return "not found", 404, {}
    end)
    clickerServer:start()

    -- 2) Bonjour advertisement via the macOS built-in /usr/bin/dns-sd (absolute path
    --    on purpose), so SessionTimer lists this computer by name — no IP typing.
    local serviceName = "Clicker on " .. (hs.host.localizedName() or "Mac")
    clickerBonjour = hs.task.new("/usr/bin/dns-sd",
        nil,
        { "-R", serviceName, "_clicker._tcp", "local.", tostring(PORT) })
    clickerBonjour:start()

    hs.alert.show("Clicker receiver ON (:" .. PORT .. ")  — \"" .. serviceName .. "\"")
    refreshMenu()
end

-- Stop listening and stop advertising (menu toggle / clickerStop() from the console).
function clickerStop()
    if clickerServer then
        clickerServer:stop()
        clickerServer = nil
    end
    if clickerBonjour then
        clickerBonjour:terminate()
        clickerBonjour = nil
    end
    hs.alert.show("Clicker receiver OFF")
    refreshMenu()
end

if clickerMenu then
    clickerMenu:setClickCallback(function()
        if clickerServer then clickerStop() else clickerStart() end
    end)
end
refreshMenu()  -- starts OFF — click "○ Clicker" in the menu bar when you present
