# =============================================================================
# 04-attacks / install-atomicredteam.ps1
# Installs the Atomic Red Team framework (Red Canary) + Invoke-AtomicTest on
# the Windows VM so every attack maps to a MITRE ATT&CK technique ID and runs
# as a single invocation. Run once, as Administrator.
# =============================================================================
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

Write-Host "[*] Installing Atomic Red Team + Invoke-AtomicTest..." -ForegroundColor Cyan
$url = "https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1"
$inst = "$env:TEMP\install-atomicredteam.ps1"
Invoke-WebRequest -Uri $url -OutFile $inst -UseBasicParsing
& $inst -RepoUrl https://github.com/redcanaryco/atomic-red-team -Branch master

Write-Host "[*] Installing AtomicTest module + prerequisites..." -ForegroundColor Cyan
Install-Module -Name Invoke-AtomicTest -Force -Scope AllUsers -AcceptLicense

Write-Host "[*] Verifying..." -ForegroundColor Cyan
Import-Module Invoke-AtomicTest
Invoke-AtomicTest --help 2>&1 | Select-Object -First 3
Write-Host "[*] Atomic Red Team ready. Use: Invoke-AtomicTest T1136.001" -ForegroundColor Green
