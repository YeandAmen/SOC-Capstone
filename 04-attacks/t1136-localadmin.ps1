#Requires -RunAsAdministrator
param([string]$AccountName = 'capstone_admin')
$ErrorActionPreference = 'Stop'
$LogFile = Join-Path $PSScriptRoot 't1136_timeline.log'
function Log($message) {
    $line = "$(Get-Date -Format o) | $message"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

if ($AccountName.Length -gt 20) { throw 'Local account names must be 20 characters or fewer.' }
if (Get-LocalUser -Name $AccountName -ErrorAction SilentlyContinue) {
    throw "Account $AccountName already exists. Choose another lab account name."
}

$password = Read-Host "Password for new lab account $AccountName" -AsSecureString
Log "[T1136.001] Starting local account creation on $env:COMPUTERNAME"
New-LocalUser -Name $AccountName -Password $password -Description 'SOC capstone test account' | Out-Null
Add-LocalGroupMember -Group Administrators -Member $AccountName
Log "[T1136.001] Created $AccountName and added it to Administrators"
Log "[T1136.001] END"
