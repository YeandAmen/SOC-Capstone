# SOC Playground

A reproducible SOC lab with a Mac running Splunk Enterprise, a Windows 11
endpoint, and a Kali Linux endpoint on one UTM virtual network. Both VMs send
events to the Mac. Attack scripts produce lab telemetry; saved searches, a
Splunk dashboard, and the live trace console show what Splunk actually ingests.

## Topology

| Node | Example IP | Software | Role |
| --- | --- | --- | --- |
| Mac host | `192.168.64.1` | Splunk Enterprise | Indexer, search head, receiver, live console |
| Windows VM | `192.168.64.2` | Sysmon, Splunk Universal Forwarder, OpenSSH Server | Monitored endpoint |
| Kali VM | `192.168.64.4` | Splunk Universal Forwarder, OpenSSH Server | Monitored endpoint and lab attack machine |

The IPs in this repo (`192.168.64.x`) are examples from the original UTM lab.
Clone users must substitute their own VM addresses. Set the `SPLUNK_HOST_IP`
environment variable for forwarding (default 192.168.64.1). All Splunk data stays
local to the host — the console binds to loopback and holds admin credentials
only in server memory. To host the live console publicly would require removing
credential handling; this repo is designed for local lab use only.
The repo contains scripts and configuration, not VM disk images, Splunk
installers, licenses, OS images, or production credentials.

## Rebuild the lab

1. Install Splunk Enterprise on the Mac at `/Applications/Splunk`. Create two
   VMs on a UTM network where both can reach the Mac. Check each IP with
   `ipconfig` on Windows and `ip addr` on Kali. Allow VM-to-Mac TCP 9997
   (forwarding) and 8000 (Splunk Web). Keep 8089 local to the Mac.
2. On a fresh Splunk install, set an admin password in your shell and run
   `bash 01-splunk-manager/setup-splunk-macos.sh`. On an existing install,
   supply its current admin password; the script preserves existing accounts.
   It creates the `soc_capstone` index and opens receiver port 9997.
3. On Windows, in an Administrator PowerShell prompt, run
   `02-windows-endpoint/01-install-sysmon.ps1`, then
   `02-windows-endpoint/02-install-uf.ps1` from the checked-out folder. The
   second script prompts for a local forwarder admin password, copies
   `inputs.conf`, uses LocalSystem for Sysmon access, and restarts the service.
   Run `03-verify-forwarder.ps1` to check local forwarding.
4. On Kali, run `sudo bash 03-linux-endpoint/setup-uf-kali.sh`. It installs the
   Universal Forwarder and monitors `/var/log/auth.log` and `/var/log/syslog`.
5. On the Mac, run `bash 05-detection/deploy-macos.sh` to install the saved
   searches, Splunk dashboard, and benign PowerShell payload. This restarts
   Splunk. Verify `index=soc_capstone | stats count by host,sourcetype` in
   Splunk Search. Both endpoints should appear.
6. Run `bash 07-live-console/start-macos.sh` on the Mac, open
   `http://127.0.0.1:8765`, and enter the Splunk admin password in the local
   connection form. The console searches Splunk
   every 15 seconds. The regular Splunk UI remains at
   `http://127.0.0.1:8000`.

## Mac to VM SSH

The Mac is the control host. In an elevated Windows PowerShell prompt, enable
OpenSSH Server and start it:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd
```

On Kali, run `sudo apt install openssh-server` followed by
`sudo systemctl enable --now ssh`. Confirm the Mac can reach both VM addresses
on port 22 with `nc -vz 192.168.64.2 22` and `nc -vz 192.168.64.4 22`, then
install the Mac helper:

```bash
python3 -m pip install -r requirements.txt
python3 scripts/lab-ssh.py kali --user YOUR_KALI_USER --command 'hostname'
python3 scripts/lab-ssh.py windows --user YOUR_WINDOWS_USER --command 'hostname'
python3 scripts/lab-ssh.py windows --user YOUR_WINDOWS_USER --put 04-attacks/Attk103_psuedoattacks.ps1 'C:/SOC-Capstone/Attk103_psuedoattacks.ps1'
```

The helper uses Paramiko because password login through the Mac's OpenSSH
client did not work in the original UTM lab. Passwords are prompted locally,
not passed on the command line. Check VM host keys when connecting for the
first time. SSH does not confer Windows Administrator rights by itself; run
the endpoint setup and local account test in an elevated PowerShell prompt.

## Run the lab attacks

Only use these scripts against your own lab VMs. The original run exercised
Attk101, Attk102, and Attk103; Attk104 is provided but was not run because
it clears the Windows Security log.

```bash
# Mac: copy and edit this ignored file for your own lab password candidates.
cp 04-attacks/wordlist.example.txt 04-attacks/wordlist.txt
python3 04-attacks/Attk101_psuedoattacks.py --target <kali-ip> --user <user> --wordlist 04-attacks/wordlist.txt --delay 1.5
```

On Windows, run `Attk102_psuedoattacks.ps1` in an elevated PowerShell window. It
prompts for a password and creates `capstone_admin` (or a name supplied through
`-AccountName`). Run `Attk103_psuedoattacks.ps1` to fetch and execute
the benign marker hosted in the Splunk app. The latter requires Windows to
reach Mac port 8000. `04-attacks/README.md` has the attack detail and cleanup.
No real password, timeline log, VM image, or Splunk data is committed.

## Read the results

- Splunk dashboard: **SOC Capstone - Attack Detection Dashboard** in the
  `soc_capstone_detections` app.
- Live trace: `http://127.0.0.1:8765`; chart points are observed event counts,
  with rule matches and a timestamped event table. Counts are matching
  telemetry, not confirmed incidents: the SSH series includes accepted and
  failed logins, and PowerShell download behavior can include legitimate
  administration or setup activity. Review the underlying events before
  attributing an attack.
- [Detection notes](05-detection/README.md), [attack map](06-deliverables/attack-mapping.md),
  [architecture](06-deliverables/architecture.md), and
  [incident report template](06-deliverables/incident-report-template.md).
