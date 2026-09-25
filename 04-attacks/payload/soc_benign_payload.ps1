# soc_benign_payload.ps1 - LAB ONLY. Harmless marker payload for the Attk103
# download-and-execute demo. Prints a unique marker string that the SOC can
# correlate in the Sysmon process-create event (event ID 1) on Splunk.
$marker = "SOC_CAPSTONE_BENIGN_PAYLOAD_EXECUTED_" + (Get-Date -Format "yyyyMMddHHmmss")
Write-Output $marker
Write-Output "If you can read this in Splunk, the download-and-execute chain worked."
