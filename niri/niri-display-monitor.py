#!/usr/bin/env python3
"""Monitor Niri display connections and fall back to internal display if needed.

Runs as a daemon, watching for output hotplug events via the Niri event stream.
If all displays become inactive, it triggers a fallback to the internal laptop screen.
"""

import subprocess
import json
import time
import sys
import os
import fcntl


def run_cmd(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)


def check_and_fix_displays():
    res = run_cmd("niri msg --json outputs")
    if res.returncode != 0:
        return
    try:
        outputs = json.loads(res.stdout)
    except Exception:
        return

    has_active_display = any(data.get("logical") for data in outputs.values())

    has_external = False
    has_internal = False
    for name in outputs:
        if name.startswith(("eDP", "LVDS", "DSI")):
            has_internal = True
        else:
            has_external = True

    should_revert = False
    if not has_active_display:
        should_revert = True
        print("[DisplayMonitor] All displays are inactive (black screen).")
    elif has_internal and not has_external:
        internal_name = next((name for name in outputs if name.startswith(("eDP", "LVDS", "DSI"))), None)
        if internal_name and not outputs[internal_name].get("logical"):
            should_revert = True
            print(f"[DisplayMonitor] Only internal display {internal_name} is connected, but it is inactive.")

    if should_revert:
        print("[DisplayMonitor] Triggering fallback to internal laptop screen.")
        script_dir = os.path.dirname(os.path.abspath(__file__))
        display_script = os.path.join(script_dir, "niri-display.py")
        subprocess.run([display_script, "internal"])


def main():
    lock_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "niri-display-monitor.lock")
    try:
        lock_file = open(lock_path, "w")
        fcntl.lockf(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except IOError:
        sys.exit(0)

    print("[DisplayMonitor] Starting Niri display monitor daemon...")
    while True:
        try:
            check_and_fix_displays()

            proc = subprocess.Popen(
                ["niri", "msg", "--json", "event-stream"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                bufsize=1,
            )

            while True:
                line = proc.stdout.readline()
                if not line:
                    break
                if "Output" in line:
                    time.sleep(0.5)
                    check_and_fix_displays()

            proc.wait()
        except Exception as e:
            print(f"[DisplayMonitor] Error in monitor loop: {e}", file=sys.stderr)

        time.sleep(2)


if __name__ == "__main__":
    main()
