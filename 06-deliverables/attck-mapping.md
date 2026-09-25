# MITRE ATT&CK Mapping — Simulated Attacks

| # | Technique ID | Technique Name | Tactic | Script / Tool | Target | Key log artifact(s) for detection |
|---|--------------|----------------|--------|---------------|--------|-----------------------------------|
| a | **T1110** | Brute Force | Credential Access | `ssh-bruteforce.py` (paramiko) | Kali/SSH | Linux `auth.log` `Failed password`; Windows 4625 if RDP |
| b | **T1136.001** | Create Account: Local Account | Persistence | `t1136-localadmin.ps1` | Windows | Security EID 4720 (created), 4732 (added to Administrators) |
| c | **T1059.001** | PowerShell | Execution | `t1059-powershell-download-exec.ps1` (optional Atomic) | Windows | Sysmon EID 1 (PowerShell w/ DownloadString), EID 3 (to Mac:8000) |
| d | **T1070.001** | Indicator Removal: Clear Windows Event Log | Defense Evasion | `t1070-clearlogs.ps1` (`wevtutil cl`) | Windows | Security EID 1102, Sysmon EID 4 |

## Mapping to the detection layer
| Technique | Splunk saved search | Sourcetype / Event IDs |
|-----------|---------------------|------------------------|
| T1110 | `SOC - T1110 SSH Brute Force (Linux)` / `...Windows Brute Force (4625)` | `linux_secure`; `WinEventLog:Security` 4625 |
| T1136.001 | `SOC - T1136.001 Local Account Created` / `...Added to Administrators` | `WinEventLog:Security` 4720, 4728, 4732 |
| T1059.001 | `SOC - T1059.001 PowerShell Download Cradle` / `...Network Connect From PowerShell` | Sysmon Operational EID 1, 3 |
| T1070.001 | `SOC - T1070.001 Security Log Cleared` | Security 1102, Sysmon 4 |

## ATT&CK tactics covered
- **Credential Access** (TA0006) — T1110
- **Persistence** (TA0003) — T1136.001
- **Execution** (TA0002) — T1059.001
- **Defense Evasion** (TA0005) — T1070.001

## References
- https://attack.mitre.org/techniques/T1110/
- https://attack.mitre.org/techniques/T1136/001/
- https://attack.mitre.org/techniques/T1059/001/
- https://attack.mitre.org/techniques/T1070/001/
- Atomic Red Team: https://github.com/redcanaryco/atomic-red-team
