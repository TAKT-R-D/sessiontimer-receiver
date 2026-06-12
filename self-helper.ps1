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
# "Enter IP manually" (find this PC's IP with: ipconfig). If Apple's Bonjour
# for Windows happens to be installed (dns-sd.exe), this script advertises
# itself like the macOS receivers do and shows up by name - best effort only.
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

try {
    while ($true) {
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
