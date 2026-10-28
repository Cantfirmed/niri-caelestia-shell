#!/usr/bin/env python3
"""Monitor Niri display connections and fall back to internal display if needed.

Runs as a background daemon watching for:
1. Linux kernel DRM uevents via NETLINK (instant cable plug/unplug detection).
2. Niri IPC event stream events (WorkspacesChanged, ConfigLoaded, OutputsChanged, etc.).
3. Physical laptop lid switch state (/proc/acpi/button/lid/*/state).
4. Periodic safety check (every 1.5s) to guarantee no black screen or misplaced window state persists.

Clamshell Mode Rules:
- If the laptop lid is physically closed and an external display is connected, enforce External Only
  mode (internal laptop screen turned off) so windows are not misplaced onto the closed screen.
- Never revert to the internal display while the laptop lid is closed.
- If waking from sleep or unlocking, grant a grace period for HDMI/DP handshake to complete before
  evaluating fallback.
- Require consecutive confirmation checks before declaring an external monitor truly unplugged.
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
WAS_LOCKED = False
LAST_UNLOCK_TIME = 0.0
DISCONNECT_COUNT = 0
LAST_LID_CLOSED = None


def ensure_niri_socket():
    """Ensure NIRI_SOCKET is set in os.environ by discovering active niri socket if needed."""
    if "NIRI_SOCKET" in os.environ and os.path.exists(os.environ["NIRI_SOCKET"]):
        return True
    uid = os.getuid()
    socks = glob.glob(f"/run/user/{uid}/niri*.sock")
    if socks:
        socks.sort(key=lambda s: os.path.getmtime(s), reverse=True)
        os.environ["NIRI_SOCKET"] = socks[0]
        return True
    return False


def run_cmd(cmd):
    ensure_niri_socket()
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)


def is_lid_closed():
    """Query sysfs/proc for physical lid switch status."""
    for path in glob.glob("/proc/acpi/button/lid/*/state"):
        try:
            with open(path) as f:
                if "closed" in f.read().lower():
                    return True
        except Exception:
            pass
    return False


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


def is_session_locked():
    """Check if session is currently locked via Quickshell IPC or logind."""
    uid = os.getuid()
    try:
        ensure_niri_socket()
        env = dict(os.environ)
        if "WAYLAND_DISPLAY" not in env:
            for sock in glob.glob(f"/run/user/{uid}/wayland-*"):
                env["WAYLAND_DISPLAY"] = os.path.basename(sock)
                break
        res = subprocess.run(
            ["qs", "-c", "niri-caelestia-shell", "ipc", "call", "lock", "isLocked"],
            capture_output=True,
            text=True,
            timeout=2.0,
            env=env,
        )
        if res.returncode == 0:
            return res.stdout.strip() == "true"
    except Exception:
        pass

    # Fallback when Quickshell is temporarily restarting: check logind
    try:
        session_id = os.environ.get("XDG_SESSION_ID", "2")
        res = subprocess.run(
            ["loginctl", "show-session", session_id, "-p", "LockedHint"],
            capture_output=True,
            text=True,
            timeout=1.0,
        )
        if res.returncode == 0 and "LockedHint=yes" in res.stdout:
            return True
    except Exception:
        pass

    return False


def check_and_fix_displays():
    global LAST_REVERT_TIME, WAS_LOCKED, LAST_UNLOCK_TIME, DISCONNECT_COUNT, LAST_LID_CLOSED
    now = time.time()

    # Track lock state transitions
    locked = is_session_locked()
    if locked:
        WAS_LOCKED = True
        DISCONNECT_COUNT = 0
        return

    if WAS_LOCKED:
        WAS_LOCKED = False
        LAST_UNLOCK_TIME = now
        print("[DisplayMonitor] Session unlocked. Granting 5s grace period for external display wake...", flush=True)

    # Check physical lid state
    current_lid_closed = is_lid_closed()
    lid_state_changed = (LAST_LID_CLOSED is not None and current_lid_closed != LAST_LID_CLOSED)
    if lid_state_changed:
        print(
            f"[DisplayMonitor] Lid state transition: {'OPEN -> CLOSED' if current_lid_closed else 'CLOSED -> OPEN'}",
            flush=True,
        )
    LAST_LID_CLOSED = current_lid_closed

    # Query Niri outputs
    res = run_cmd("niri msg --json outputs")
    if res.returncode != 0:
        return
    try:
        outputs = json.loads(res.stdout)
    except Exception:
        return

    # Physical DRM connection status from kernel
    internal_connected, external_connected = get_drm_status()

    # Identify internal display name
    internal_name = None
    for name in outputs:
        if name.startswith(("eDP", "LVDS", "DSI")):
            internal_name = name
            break
    if not internal_name and internal_connected:
        internal_name = "eDP-1"

    internal_is_active = bool(outputs.get(internal_name, {}).get("logical")) if internal_name else False
    has_external_niri = any(not name.startswith(("eDP", "LVDS", "DSI")) for name in outputs)
    external_is_present = external_connected or has_external_niri

    script_dir = os.path.dirname(os.path.abspath(__file__))
    display_script = os.path.join(script_dir, "niri-display.py")

    # =========================================================================
    # CASE 1: LAPTOP LID IS CLOSED (Clamshell Mode)
    # =========================================================================
    if current_lid_closed:
        # Reset disconnect counter; under NO circumstances should we revert to
        # the internal display inside a closed laptop.
        DISCONNECT_COUNT = 0

        if external_is_present:
            # If external monitor is present and the internal display is active,
            # enforce external-only clamshell mode so windows don't end up on
            # the closed laptop screen.
            if internal_is_active or lid_state_changed:
                if now - LAST_REVERT_TIME >= 2.0:
                    LAST_REVERT_TIME = now
                    print(
                        "[DisplayMonitor] Clamshell mode: Lid is closed with external monitor present. Enforcing external-only layout...",
                        flush=True,
                    )
                    if os.path.exists(display_script):
                        subprocess.run([display_script, "external"])
                    if internal_name:
                        run_cmd(f"niri msg output {internal_name} off")
        # When lid is closed, do nothing further (never fall back to internal screen).
        return

    # =========================================================================
    # CASE 2: LAPTOP LID JUST OPENED
    # =========================================================================
    if lid_state_changed and not current_lid_closed:
        if now - LAST_REVERT_TIME >= 2.0:
            LAST_REVERT_TIME = now
            if external_is_present:
                print("[DisplayMonitor] Lid opened with external monitor present. Restoring extended desktop...", flush=True)
                if os.path.exists(display_script):
                    subprocess.run([display_script, "restore-extended"])
                elif internal_name:
                    run_cmd(f"niri msg output {internal_name} on")
            else:
                print("[DisplayMonitor] Lid opened with no external monitor. Enabling laptop screen...", flush=True)
                if os.path.exists(display_script):
                    subprocess.run([display_script, "internal"])
                elif internal_name:
                    run_cmd(f"niri msg output {internal_name} on")
        return

    # =========================================================================
    # CASE 3: LAPTOP LID IS OPEN (Normal Operation & Disconnect Fallback)
    # =========================================================================
    # Debounce: avoid running back-to-back within 3 seconds
    if now - LAST_REVERT_TIME < 3.0:
        return

    # Honor 5s grace period immediately following session unlock to allow
    # HDMI/DP handshake to complete without false fallbacks.
    if (now - LAST_UNLOCK_TIME) < 5.0:
        DISCONNECT_COUNT = 0
        return

    has_active_display = any(bool(data.get("logical")) for data in outputs.values())

    # Count consecutive checks where external monitor is confirmed absent in DRM
    if not external_connected:
        DISCONNECT_COUNT += 1
    else:
        DISCONNECT_COUNT = 0

    should_revert = False
    reason = ""

    # Immediate black screen recovery:
    # If all displays are inactive (black screen), lid is open, session is unlocked, and no external monitor is physically connected,
    # recover immediately without waiting 4.5s.
    if not has_active_display and not external_connected:
        should_revert = True
        reason = "All displays inactive, lid is open, and no external monitor is physically connected."
    elif not internal_is_active and not external_is_present and DISCONNECT_COUNT >= 3:
        should_revert = True
        reason = f"External monitor confirmed disconnected ({DISCONNECT_COUNT} checks), and internal screen is inactive."

    if should_revert:
        LAST_REVERT_TIME = now
        DISCONNECT_COUNT = 0
        print(f"[DisplayMonitor] Fallback triggered: {reason}", flush=True)
        print(f"[DisplayMonitor] Reverting to internal display ({internal_name or 'eDP-1'})...", flush=True)
        if os.path.exists(display_script):
            subprocess.run([display_script, "internal"])
        else:
            if internal_name:
                run_cmd(f"niri msg output {internal_name} on")
            run_cmd("niri msg action load-config-file")


def handle_cli_lid_event(event_type):
    """Handle instant lid event triggered directly by Niri switch-events."""
    internal_conn, external_conn = get_drm_status()
    res = run_cmd("niri msg --json outputs")
    outputs = {}
    if res.returncode == 0:
        try:
            outputs = json.loads(res.stdout)
        except Exception:
            pass
    has_ext_niri = any(not name.startswith(("eDP", "LVDS", "DSI")) for name in outputs)
    ext_present = external_conn or has_ext_niri
    script_dir = os.path.dirname(os.path.abspath(__file__))
    display_script = os.path.join(script_dir, "niri-display.py")

    if event_type == "close":
        if ext_present:
            print("[LidHandler] Lid closed with external display present. Enforcing external mode.", flush=True)
            if os.path.exists(display_script):
                subprocess.run([display_script, "external"])
    elif event_type == "open":
        if ext_present:
            print("[LidHandler] Lid opened with external display present. Restoring extended desktop.", flush=True)
            if os.path.exists(display_script):
                subprocess.run([display_script, "restore-extended"])
        else:
            print("[LidHandler] Lid opened with no external display. Enabling laptop screen.", flush=True)
            if os.path.exists(display_script):
                subprocess.run([display_script, "internal"])


def create_netlink_socket():
    """Create a NETLINK_KOBJECT_UEVENT socket to monitor kernel DRM hotplug and switch events."""
    try:
        sock = socket.socket(socket.AF_NETLINK, socket.SOCK_DGRAM, 15)  # 15 = NETLINK_KOBJECT_UEVENT
        sock.bind((os.getpid(), 1))  # Group 1 = kernel uevents
        sock.setblocking(False)
        return sock
    except Exception as e:
        print(f"[DisplayMonitor] Warning: Could not bind netlink uevent socket: {e}", file=sys.stderr, flush=True)
        return None


def main():
    if len(sys.argv) > 1:
        arg = sys.argv[1]
        if arg in ("--lid-close", "close"):
            handle_cli_lid_event("close")
            sys.exit(0)
        elif arg in ("--lid-open", "open"):
            handle_cli_lid_event("open")
            sys.exit(0)

    # Ensure only one instance runs
    lock_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "niri-display-monitor.lock")
    try:
        lock_file = open(lock_path, "w")
        fcntl.lockf(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except IOError:
        sys.exit(0)

    # Check if this machine is a desktop (no internal eDP/LVDS/DSI display hardware)
    has_internal_hw = any(
        os.path.basename(p).split("-", 1)[-1].startswith(("eDP", "LVDS", "DSI"))
        for p in glob.glob("/sys/class/drm/card*-*")
    )
    if not has_internal_hw:
        print("[DisplayMonitor] Desktop system detected (no internal panel). Monitor daemon idle.", flush=True)
        while True:
            time.sleep(3600)

    print("[DisplayMonitor] Starting Niri display monitor daemon...", flush=True)

    # Initial sanity check on startup
    script_dir = os.path.dirname(os.path.abspath(__file__))
    display_script = os.path.join(script_dir, "niri-display.py")
    try:
        if os.path.exists(display_script):
            subprocess.run([display_script, "--sanity-check"])
    except Exception as e:
        print(f"[DisplayMonitor] Sanity check error: {e}", file=sys.stderr, flush=True)

    # Initial check on startup
    check_and_fix_displays()

    netlink_sock = create_netlink_socket()

    while True:
        try:
            ensure_niri_socket()
            proc = None
            if "NIRI_SOCKET" in os.environ and os.path.exists(os.environ["NIRI_SOCKET"]):
                proc = subprocess.Popen(
                    ["niri", "msg", "--json", "event-stream"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                    text=True,
                    bufsize=1,
                )

            while True:
                watch_fds = []
                if proc and proc.stdout and proc.poll() is None:
                    watch_fds.append(proc.stdout)
                if netlink_sock:
                    watch_fds.append(netlink_sock)

                # Wait with 1.5s timeout as a periodic safety net
                last_loop_time = time.time()
                readable, _, _ = select.select(watch_fds, [], [], 1.5)
                loop_elapsed = time.time() - last_loop_time
                if loop_elapsed > 3.5:
                    print(
                        f"[DisplayMonitor] System resumed from sleep (elapsed {loop_elapsed:.1f}s). Granting 8s grace period...",
                        flush=True,
                    )
                    LAST_UNLOCK_TIME = time.time() + 3.0
                    DISCONNECT_COUNT = 0

                if not readable:
                    # Timeout fired — periodic check
                    check_and_fix_displays()
                    if proc and proc.poll() is not None:
                        break
                    continue

                need_check = False

                for fd in readable:
                    if netlink_sock and fd == netlink_sock:
                        try:
                            msg = netlink_sock.recv(4096)
                            if any(k in msg for k in (b"drm", b"HOTPLUG", b"button", b"switch", b"lid")):
                                need_check = True
                        except Exception:
                            pass
                    elif proc and proc.stdout and fd == proc.stdout:
                        line = proc.stdout.readline()
                        if not line:
                            # Process closed or EOF
                            break
                        # Any workspace, config, or window change can signal layout shift
                        if any(k in line for k in ("WorkspacesChanged", "ConfigLoaded", "OutputsChanged")):
                            need_check = True

                if proc and proc.poll() is not None:
                    break

                if need_check:
                    time.sleep(0.3)  # Brief pause for kernel/compositor to settle
                    check_and_fix_displays()

            if proc:
                try:
                    proc.wait(timeout=1.0)
                except Exception:
                    proc.kill()

            # Always perform check when loop exits or reconnects
            check_and_fix_displays()
        except Exception as e:
            print(f"[DisplayMonitor] Error in monitor loop: {e}", file=sys.stderr, flush=True)

        time.sleep(2)


if __name__ == "__main__":
    main()
