# SessionTimer clicker receiver - Windows PowerShell edition (zero install)
#
# Official source: https://github.com/TAKT-R-D/sessiontimer-receiver
# This file is the ONLY thing SessionTimer's clicker talks to on your computer.
# Read it - it is short on purpose. Security model: see README.md.
#
# What it does (and ALL it does):
#   GET /next  ->  presses the Right Arrow key
#   GET /prev  ->  presses the Left Arrow key
# Any other request gets "404 not found" and presses nothing.
# No shell commands, no eval, no file reads/writes, no downloads, no auto-update.
# Windows built-ins only (PowerShell 5.1 or later) - nothing is installed.
#
# The keystroke goes to the FOREGROUND window, so your slideshow (PowerPoint,
# Keynote via browser, Google Slides, a PDF...) must be the front window in
# presentation mode. No Accessibility-style permission is needed on Windows.
#
# Run (from the folder containing this file):
#   powershell -ExecutionPolicy Bypass -File self-helper.ps1
# Stop with Ctrl-C. Uninstall: delete this file. Nothing else was installed.
#
# First run: Windows Firewall asks to allow inbound connections - allow it
# (that is how your iPhone reaches this PC over Wi-Fi).
#
# Bonjour: Windows has none built in, so connect from SessionTimer with
# "Enter IP manually" - this script prints this PC's address for you on start.
# If Apple's Bonjour for Windows happens to be installed (dns-sd.exe), this
# script advertises itself like the macOS receivers do and shows up by name -
# best effort only.
#
# Note: on a company-managed PC, security policy (enforced Execution Policy,
# AppLocker/WDAC) may prevent scripts like this from running at all - that is
# an IT-policy limit, not a bug, and it applies to any receiver.

$Port = 8722

# The complete keystroke vocabulary. Fixed by design (1 click = 1 slide):
# nothing outside this table can ever be pressed.
$Keys = @{
    '/next' = '{RIGHT}'
    '/prev' = '{LEFT}'
}

$shell = New-Object -ComObject WScript.Shell

# This PC's LAN IPv4 address(es), so you can type one into SessionTimer's
# "Enter IP manually" without hunting through ipconfig. This READS THE LOCAL
# ADAPTER CONFIGURATION directly (System.Net.NetworkInformation) - no shell
# commands, no name resolution, no downloads; nothing leaves this machine and
# no new capability is added (the listener below already binds every interface).
# Only "up" adapters are considered; loopback and unconfigured link-local
# (169.254.x) are filtered out. A PC with VPN/virtual adapters may list several,
# so pick the one on the same Wi-Fi as your iPhone.
function Get-LanIPv4 {
    try {
        [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
            Where-Object {
                $_.OperationalStatus -eq [System.Net.NetworkInformation.OperationalStatus]::Up -and
                $_.NetworkInterfaceType -ne [System.Net.NetworkInformation.NetworkInterfaceType]::Loopback
            } |
            ForEach-Object { $_.GetIPProperties().UnicastAddresses } |
            Where-Object { $_.Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } |
            ForEach-Object { $_.Address.IPAddressToString } |
            Where-Object { $_ -notmatch '^(127\.|169\.254\.)' } |
            Select-Object -Unique
    } catch {
        @()
    }
}

# Optional Bonjour advertisement via Apple's dns-sd.exe, if present (best effort).
$bonjour = $null
$dnssd = Get-Command dns-sd.exe -ErrorAction SilentlyContinue
if ($dnssd) {
    $name = "Clicker on $env:COMPUTERNAME"
    $bonjour = Start-Process -FilePath $dnssd.Source `
        -ArgumentList @('-R', $name, '_clicker._tcp', 'local.', "$Port") `
        -WindowStyle Hidden -PassThru
    Write-Host "Advertised on Bonjour as `"$name`""
} else {
    Write-Host 'No dns-sd.exe found - Bonjour skipped (use "Enter IP manually" in SessionTimer).'
}

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
$listener.Start()
Write-Host "Clicker receiver listening on :$Port  (Ctrl-C to stop)"

$ips = @(Get-LanIPv4)
if ($ips.Count -eq 1) {
    Write-Host "Enter this in SessionTimer -> Enter IP manually:  $($ips[0])  (port $Port)"
} elseif ($ips.Count -gt 1) {
    Write-Host "Enter one of these in SessionTimer -> Enter IP manually (the one on your Wi-Fi), port ${Port}:"
    foreach ($ip in $ips) { Write-Host "    $ip" }
} else {
    Write-Host 'Could not determine this PC''s address - find it with: ipconfig'
}

try {
    while ($true) {
        # Poll instead of calling the BLOCKING AcceptTcpClient() directly: PowerShell cannot
        # process Ctrl-C while it is stuck inside a blocking .NET call, so a plain Accept loop
        # ignores Ctrl-C until the next connection arrives. Pending() + an interruptible
        # Start-Sleep gives the shell a gap to see the stop request (and to run the cleanup in
        # `finally`). 50 ms costs nothing and keeps click latency imperceptible.
        if (-not $listener.Pending()) {
            Start-Sleep -Milliseconds 50
            continue
        }
        $client = $listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $stream.ReadTimeout = 2000
            $reader = New-Object System.IO.StreamReader($stream)
            $requestLine = $reader.ReadLine()
            $path = $null
            if ($requestLine -and $requestLine.StartsWith('GET ')) {
                $path = ($requestLine -split ' ')[1]
            }
            if ($path -and $Keys.ContainsKey($path)) {
                $shell.SendKeys($Keys[$path])
                Write-Host "  $path"   # visible activity log - you see every click it receives
                $status = '200 OK'
                $body = 'ok'
            } else {
                $status = '404 Not Found'
                $body = 'not found'
            }
            $response = "HTTP/1.0 $status`r`n" +
                "Content-Type: text/plain`r`n" +
                "Content-Length: $($body.Length)`r`n" +
                "Connection: close`r`n`r`n$body"
            $bytes = [System.Text.Encoding]::ASCII.GetBytes($response)
            $stream.Write($bytes, 0, $bytes.Length)
        } catch {
            # A malformed or timed-out request is dropped; nothing is pressed.
        } finally {
            $client.Close()
        }
    }
} finally {
    $listener.Stop()
    if ($bonjour) { Stop-Process -Id $bonjour.Id -ErrorAction SilentlyContinue }
}
