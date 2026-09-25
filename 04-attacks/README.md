# Lab attack simulations

These tests are for the isolated lab VMs in this project. They produce real endpoint
and authentication logs for the Splunk detections. Timeline logs stay local and
are ignored by Git.

## Attk101: SSH password attempts

Run from the Mac against the Kali VM's own SSH service:

```bash
python3 -m pip install -r requirements.txt
cp 04-attacks/wordlist.example.txt 04-attacks/wordlist.txt
# Add a lab-only password to the ignored wordlist if you want a success event.
python3 04-attacks/Attk101_psuedoattacks.py --target <kali-ip> --user <username> --wordlist 04-attacks/wordlist.txt --delay 1.5
```

The script logs attempt numbers and outcomes (never candidate passwords). Kali
`/var/log/auth.log` supplies the evidence in Splunk.

## Attk102: local admin creation

Run `Attk102_psuedoattacks.ps1` in an elevated PowerShell prompt on Windows. It
prompts for a password, creates `capstone_admin`, and adds it to Administrators.
Use `-AccountName some_other_lab_name` if that account already exists. Check
Windows Security event 4720 and 4732. To clean up after collecting evidence:

```powershell
Remove-LocalUser -Name capstone_admin
```

## Attk103: PowerShell download and execution

Deploy the Splunk app first with `bash 05-detection/deploy-macos.sh`. On Windows,
run `Attk103_psuedoattacks.ps1`. It downloads the repository's benign marker
script through Splunk Web on the Mac and executes it. `CAPSTONE_PAYLOAD_URL`
can override the URL. Check Sysmon process creation  with `DownloadString` in
the command line.

## Attk104: clear Security log

`Attk104_psuedoattacks.ps1` clears the Windows Security log. Export evidence
before running it. The expected audit event is 1102.