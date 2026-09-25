# SOC Capstone

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

The IPs are examples from the original UTM setup. Use the `SPLUNK_HOST_IP`
environment variable and the helper's `--ip` option when your addresses differ.
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
6. Run `bash 07-live-console/start-macos.sh` on the Mac, enter the Splunk admin
   password, and open `http://127.0.0.1:8765`. The console searches Splunk
   every 15 seconds. The regular Splunk UI remains at
   `http://127.0.0.1:8000`.

## Mac to VM SSH

The Mac is the control host. Enable OpenSSH Server on Windows and `sshd` on
Kali, confirm the Mac can reach VM port 22, then install the Mac helper:

```bash
python3 -m pip install -r requirements.txt
python3 scripts/lab-ssh.py kali --user YOUR_KALI_USER --command 'hostname'
python3 scripts/lab-ssh.py windows --user YOUR_WINDOWS_USER --command 'hostname'
python3 scripts/lab-ssh.py windows --user YOUR_WINDOWS_USER --put 04-attacks/t1059-powershell-download-exec.ps1 'C:/SOC-Capstone/t1059-powershell-download-exec.ps1'
```

The helper uses Paramiko because password login through the Mac's OpenSSH
client did not work in the original UTM lab. Passwords are prompted locally,
not passed on the command line. Check VM host keys when connecting for the
first time. SSH does not confer Windows Administrator rights by itself; run
the endpoint setup and local account test in an elevated PowerShell prompt.

## Run the lab attacks

Only use these scripts against your own lab VMs. The original run exercised
T1110, T1136.001, and T1059.001; T1070.001 is provided but was not run because
it clears the Windows Security log.

```bash
# Mac: copy and edit this ignored file for your own lab password candidates.
cp 04-attacks/wordlist.example.txt 04-attacks/wordlist.txt
python3 04-attacks/ssh-bruteforce.py --target 192.168.64.4 --user YOUR_KALI_USER --wordlist 04-attacks/wordlist.txt --delay 1.5
```

On Windows, run `t1136-localadmin.ps1` in an elevated PowerShell window. It
prompts for a password and creates `capstone_admin` (or a name supplied through
`-AccountName`). Run `t1059-powershell-download-exec.ps1` to fetch and execute
the benign marker hosted in the Splunk app. The latter requires Windows to
reach Mac port 8000. `04-attacks/README.md` has the attack detail and cleanup.
No real password, timeline log, VM image, or Splunk data is committed.

## Read the results

- Splunk dashboard: **SOC Capstone - Attack Detection Dashboard** in the
  `soc_capstone_detections` app.
- Live trace: `http://127.0.0.1:8765`; chart points are observed event counts,
  with rule matches and a timestamped event table.
- [Detection notes](05-detection/README.md), [ATT&CK map](06-deliverables/attck-mapping.md),
  [architecture](06-deliverables/architecture.md), and
  [incident report template](06-deliverables/incident-report-template.md).
