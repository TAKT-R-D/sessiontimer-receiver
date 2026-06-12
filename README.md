# SessionTimer clicker receiver

The official receiver scripts for **[SessionTimer](https://takt.dev/sessiontimer)**'s
Pro slide clicker. You run ONE of these small scripts on the computer that shows your
slides; SessionTimer on your iPhone then advances them — Keynote, PowerPoint, Google Slides,
a PDF — anything that moves with the arrow keys. macOS and Windows are covered by the
ready-made scripts below; any other platform can join via the open [protocol](#protocol-for-auditors-and-tinkerers).

> **This is the only official distribution.** These scripts are published ONLY in this
> repository — `github.com/TAKT-R-D/sessiontimer-receiver` — and linked ONLY from the
> official setup guide at
> **<https://takt.dev/sessiontimer/presenter-mode-setup>** (which also lists the SHA-256
> checksums of each script). If you got these files from anywhere else, don't run them —
> download them here instead.

## How it works

SessionTimer never installs anything on your computer and we never ship a compiled
program — *you* download a short, readable script and run it yourself. The app and the
receiver speak a deliberately tiny protocol over your own Wi-Fi:

```
SessionTimer (iPhone)  ──GET /next──▶  receiver (your computer)  ──▶  Right Arrow key
                       ──GET /prev──▶                            ──▶  Left Arrow key
```

The keystroke is posted to the **frontmost app**, so your slideshow must be the front
window in presentation mode. One click = one slide; the receiver has no other vocabulary.

## Security model — what these scripts can and cannot do

Every script here is short enough to read before running, and we encourage you to.

What they **do**:

- Listen for HTTP `GET /next` / `GET /prev` on port **8722** on your Wi-Fi network.
- Press exactly one of two keys per request: **Right Arrow** or **Left Arrow**.
- Advertise themselves on your network via Bonjour (`_clicker._tcp`) so the app can list
  your computer by name — no IP typing. (On macOS via the built-in `dns-sd` tool; on
  Windows only if Apple's Bonjour for Windows is installed — otherwise the manual-IP
  connection works the same.)

What they **never** do:

- No shell commands, no `eval`, no file reads or writes, no downloads.
- **No auto-update.** A script never replaces itself; updates happen only when you
  re-download from this repository.
- No keystrokes outside the fixed two-arrow vocabulary, regardless of the request.
- Nothing listens unless you switched it on: the Hammerspoon receiver is **off by
  default** with a menu-bar toggle (○/● Clicker); the Python and PowerShell helpers
  stop with Ctrl-C. Uninstall = delete the file.

Honest caveat: while a receiver is running, **anyone on the same network** could send it
`/next` or `/prev` (worst case: your slides move). Run it during your talk, on a network
you trust, and stop it afterwards.

Both macOS paths need **Accessibility** permission (System Settings → Privacy & Security →
Accessibility) for the app that posts the keystroke — that's the OS-level grant that allows
*any* tool to press keys, and it's why we keep the scripts this small and auditable. Windows
needs no equivalent grant; its gate is the **Windows Firewall** prompt on first listen.

## Option 1 — Hammerspoon (macOS, recommended)

[Hammerspoon](https://www.hammerspoon.org/) is a well-known, signed, open-source macOS
automation app — the cleanest permission story (you grant Accessibility and Local Network
to a signed .app, not to a terminal).

1. Install Hammerspoon and grant it **Accessibility**
   (System Settings → Privacy & Security → Accessibility).
2. Copy the contents of [`hammerspoon-receiver.lua`](hammerspoon-receiver.lua) into
   `~/.hammerspoon/init.lua`.
3. Hammerspoon menu bar icon → **Reload Config**. A **○ Clicker** item appears in the
   menu bar.
4. Click **○ Clicker** to start listening before your talk (it becomes **● Clicker**
   and an alert shows the advertised name, e.g. `Clicker on YourMac`). Click it again
   to stop after — the receiver is off by default and only listens while you've
   switched it on.

**Sanity check** (no iPhone needed): switch the clicker on, start your slideshow, then
in Terminal:

```sh
curl http://localhost:8722/next
```

The slide should advance.

**Uninstall**: remove those lines from `~/.hammerspoon/init.lua` and reload (or quit
Hammerspoon).

## Option 2 — Python self-helper (macOS, no Hammerspoon)

Uses only the Python 3 standard library and two macOS built-in tools (`osascript`,
`dns-sd`) — nothing to install.

1. Grant your terminal app (Terminal, iTerm…) **Accessibility**
   (System Settings → Privacy & Security → Accessibility). macOS may also prompt for
   **Local Network** access on the first connection — allow it.
2. Run:

```sh
python3 self-helper.py
```

3. Stop with **Ctrl-C**. **Uninstall**: delete the file.

The same `curl` sanity check as above applies.

## Option 3 — PowerShell self-helper (Windows, zero install)

Uses only what ships with Windows 10/11 (PowerShell 5.1+). No Accessibility-style grant
is needed on Windows.

1. Download [`self-helper.ps1`](self-helper.ps1) and, from its folder, run:

```powershell
powershell -ExecutionPolicy Bypass -File self-helper.ps1
```

2. On first run, **allow the Windows Firewall prompt** (that's how the iPhone reaches
   this PC over Wi-Fi). If your Wi-Fi is set to the *Public* profile, inbound connections
   are blocked by default — set the network to *Private*, or use a personal hotspot.
3. Windows has no Bonjour built in, so connect from SessionTimer with **Enter IP
   manually**: this PC's IP (`ipconfig`) and port `8722`. (If Apple's Bonjour for
   Windows is installed, the script advertises itself and appears by name instead.)
4. Stop with **Ctrl-C**. **Uninstall**: delete the file.

**Sanity check** (Windows 10+ ships `curl`): start your slideshow, then in another
terminal: `curl http://localhost:8722/next` — the slide should advance.

> On a company-managed PC, security policy (enforced Execution Policy, AppLocker/WDAC)
> may prevent scripts from running at all. That's an IT-policy limit that applies to any
> receiver — check with your IT department.

## Connecting from SessionTimer

1. Make sure the iPhone and the computer are on the **same Wi-Fi access point** (the
   same network *name* is not always enough — guest/venue networks can isolate devices).
2. In SessionTimer: session list → the sync icon (top right) → under **Slide receiver
   (Mac)**, your computer appears by name. Tap it.
3. Allow the **Local Network** prompt on the iPhone if asked.
4. Bring your slideshow to the front, start presenting, and click.

If discovery shows nothing (no Bonjour on the platform, or venue Wi-Fi blocks it), use
the manual fallback in the same card: enter the computer's IP (macOS: System Settings →
Wi-Fi → Details → IP Address; Windows: `ipconfig`) and port `8722`.

Full walkthrough + troubleshooting: **<https://takt.dev/sessiontimer/presenter-mode-setup>**

## Protocol (for auditors and tinkerers)

Any receiver that speaks this protocol works with SessionTimer — these scripts are the
official reference, not a lock-in:

| Aspect | Value |
|---|---|
| Discovery | Bonjour / mDNS service type `_clicker._tcp`, advertised on the LAN |
| Transport | Plain HTTP over TCP, default port `8722` |
| Commands | `GET /next` (advance), `GET /prev` (go back) |
| Response | `200` with body `ok`; anything else `404` — the app ignores the body |
| Semantics | 1 request = 1 keystroke (Right/Left Arrow), posted to the frontmost app |

## License

[MIT](LICENSE) © 2026 TAKT R&D Co.,Ltd.
