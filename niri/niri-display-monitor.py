#!/usr/bin/env python3
"""Monitor Niri display connections and fall back to internal display if needed.

Runs as a background daemon watching for:
1. Linux kernel DRM uevents via NETLINK (instant cable plug/unplug detection).
2. Niri IPC event stream events (WorkspacesChanged, ConfigLoaded, etc.).
3. Periodic fallback check (every 1.5s) to guarantee no black screen state persists.

If the external display is disconnected while the internal screen was turned off
(e.g., "External Only" mode), it automatically triggers fallback to the laptop screen.
"""

import fcntl
import glob
import json
import os
import select
import socket
import subprocess
import sys
import time

LAST_REVERT_TIME = 0.0


def run_cmd(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)


def get_drm_status():
    """Query the kernel sysfs directly for physical DRM connector connection status."""
    internal_connected = False
    external_connected = False
    for path in glob.glob("/sys/class/drm/card*-*/status"):
        parts = os.path.basename(os.path.dirname(path)).split("-", 1)
        if len(parts) > 1:
            conn = parts[1]
            try:
                with open(path) as f:
                    status = f.read().strip()
            except Exception:
                continue
            if status == "connected":
                if conn.startswith(("eDP", "LVDS", "DSI")):
                    internal_connected = True
                else:
                    external_connected = True
    return internal_connected, external_connected


def check_and_fix_displays():
    global LAST_REVERT_TIME
    now = time.time()
    # Debounce: avoid running back-to-back within 3 seconds
    if now - LAST_REVERT_TIME < 3.0:
        return

    res = run_cmd("niri msg --json outputs")
    if res.returncode != 0:
        return
    try:
        outputs = json.loads(res.stdout)
    except Exception:
        return

    # 1. Check if any display has an active logical output in Niri
    has_active_display = any(bool(data.get("logical")) for data in outputs.values())

    # 2. Check physical connection status from the kernel
    internal_connected, external_connected = get_drm_status()

    # 3. Identify internal display name
    internal_name = None
    for name in outputs:
        if name.startswith(("eDP", "LVDS", "DSI")):
            internal_name = name
            break
    if not internal_name and internal_connected:
        internal_name = "eDP-1"

    internal_is_active = bool(outputs.get(internal_name, {}).get("logical")) if internal_name else False
    has_external_niri = any(not name.startswith(("eDP", "LVDS", "DSI")) for name in outputs)

    should_revert = False
    reason = ""

    if not has_active_display:
        should_revert = True
        reason = "All displays are inactive (black screen)."
    elif not external_connected and not internal_is_active:
        should_revert = True
        reason = "External monitor disconnected in DRM, but internal screen is inactive."
    elif not has_external_niri and not internal_is_active:
        should_revert = True
        reason = "No external monitor found in Niri outputs, but internal screen is inactive."

    if should_revert:
        LAST_REVERT_TIME = now
        print(f"[DisplayMonitor] Fallback triggered: {reason}", flush=True)
        print(f"[DisplayMonitor] Reverting to internal display ({internal_name or 'eDP-1'})...", flush=True)
        script_dir = os.path.dirname(os.path.abspath(__file__))
        display_script = os.path.join(script_dir, "niri-display.py")
        if os.path.exists(display_script):
            subprocess.run([display_script, "internal"])
        else:
            # Fallback direct commands
            if internal_name:
                run_cmd(f"niri msg output {internal_name} on")
            run_cmd("niri msg action load-config-file")


def create_netlink_socket():
    """Create a NETLINK_KOBJECT_UEVENT socket to monitor kernel DRM hotplug events."""
    try:
        sock = socket.socket(socket.AF_NETLINK, socket.SOCK_DGRAM, 15)  # 15 = NETLINK_KOBJECT_UEVENT
        sock.bind((os.getpid(), 1))  # Group 1 = kernel uevents
        sock.setblocking(False)
        return sock
    except Exception as e:
        print(f"[DisplayMonitor] Warning: Could not bind netlink uevent socket: {e}", file=sys.stderr, flush=True)
        return None


def main():
    # Ensure only one instance runs
    lock_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "niri-display-monitor.lock")
    try:
        lock_file = open(lock_path, "w")
        fcntl.lockf(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except IOError:
        sys.exit(0)

    print("[DisplayMonitor] Starting Niri display monitor daemon...", flush=True)

    # Initial check on startup
    check_and_fix_displays()

    netlink_sock = create_netlink_socket()

    while True:
        try:
            # Connect to Niri event-stream
            proc = subprocess.Popen(
                ["niri", "msg", "--json", "event-stream"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                bufsize=1,
            )

            while True:
                watch_fds = [proc.stdout]
                if netlink_sock:
                    watch_fds.append(netlink_sock)

                # Wait with 1.5s timeout as a periodic safety net
                readable, _, _ = select.select(watch_fds, [], [], 1.5)

                if not readable:
                    # Timeout fired — periodic check
                    check_and_fix_displays()
                    continue

                need_check = False

                for fd in readable:
                    if netlink_sock and fd == netlink_sock:
                        try:
                            msg = netlink_sock.recv(4096)
                            if b"drm" in msg or b"HOTPLUG" in msg:
                                need_check = True
                        except Exception:
                            pass
                    elif fd == proc.stdout:
                        line = proc.stdout.readline()
                        if not line:
                            # Process closed
                            break
                        # Any workspace, config, or window change can signal layout shift
                        if any(k in line for k in ("WorkspacesChanged", "ConfigLoaded", "OutputsChanged")):
                            need_check = True

                if proc.poll() is not None:
                    break

                if need_check:
                    time.sleep(0.3)  # Brief pause for kernel/compositor to settle
                    check_and_fix_displays()

            proc.wait()
        except Exception as e:
            print(f"[DisplayMonitor] Error in monitor loop: {e}", file=sys.stderr, flush=True)

        time.sleep(2)


if __name__ == "__main__":
    main()
