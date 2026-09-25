# 02-windows-endpoint / 01-install-sysmon.ps1
# Installs Sysmon with the SwiftOnSecurity config (high-signal community config).
# Run as Administrator on the Windows 11 VM (<windows-ip>).
#
# WHY SwiftOnSecurity over default Windows logging:
#  - Default Windows Event logs miss process command lines, image loads, network
#    connections, file creations, and DNS — the exact artifacts a SOC needs to
#    reconstruct an attack timeline.
#  - The SwiftOnSecurity config ships ~300 curated rules that capture the high-
#    signal events (process creation w/ command line, hash logging, network
#    connections, persistence locations, credential access) while filtering the
#    noise that would otherwise flood a lab indexer.
#  - It is the de-facto standard cited in nearly every serious SOC / Threat
#    Hunting reference, so detections built against it transfer directly.
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$sysmonZip = "$env:TEMP\sysmon.zip"
$sysmonExe = "$env:TEMP\sysmon64.exe"
$configUrl = "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml"
$configPath = "$env:TEMP\sysmonconfig-export.xml"

Write-Host "[*] Downloading Sysmon (Sysinternals)..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile $sysmonZip -UseBasicParsing
Expand-Archive -Path $sysmonZip -DestinationPath $env:TEMP -Force
if (-not (Test-Path $sysmonExe)) { $sysmonExe = "$env:TEMP\sysmon.exe" }

Write-Host "[*] Downloading SwiftOnSecurity config..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $configUrl -OutFile $configPath -UseBasicParsing

Write-Host "[*] Installing Sysmon (accept EULA, SwiftOnSecurity config)..." -ForegroundColor Cyan
& $sysmonExe -accepteula -i $configPath

Write-Host "[*] Verifying Sysmon service + provider..." -ForegroundColor Cyan
$svc = Get-Service -Name Sysmon64 -ErrorAction SilentlyContinue
if ($svc) {
    Write-Host "    Sysmon service: $($svc.Status)" -ForegroundColor Green
} else {
    Write-Host "    Sysmon service NOT found" -ForegroundColor Red
}

$prov = Get-WinEvent -ListLog "Microsoft-Windows-Sysmon/Operational" -ErrorAction SilentlyContinue
if ($prov) {
    Write-Host "    Sysmon Operational log: Enabled=$($prov.IsEnabled)  Size=$([math]::Round($prov.MaximumSizeInMB,1))MB" -ForegroundColor Green
}

Write-Host "[*] Done. Sysmon events now stream into Microsoft-Windows-Sysmon/Operational." -ForegroundColor Green
