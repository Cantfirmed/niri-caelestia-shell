#!/bin/bash
# Rescue lock script: ensures displays are powered, Quickshell is running, and the lock surface is active.
# Safe against loops: prevents concurrent runs, never terminates an instance that is actively starting up,
# and avoids spawning duplicate wrapper daemons.

set -u

# Prevent concurrent rescue runs from racing or death-looping
exec 200>/tmp/rescue-lock.lock
flock -n 200 || exit 0

# Ensure Wayland and Niri environment
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    for sock in /run/user/$UID/wayland-*; do
        if [ -S "$sock" ]; then
            export WAYLAND_DISPLAY="$(basename "$sock")"
            break
        fi
    done
fi

if [ -z "${NIRI_SOCKET:-}" ]; then
    for sock in $(ls -t /run/user/$UID/niri*.sock 2>/dev/null); do
        if [ -S "$sock" ]; then
            export NIRI_SOCKET="$sock"
            break
        fi
    done
fi

# 1. Power on all displays in Niri
niri msg output HDMI-A-1 on 2>/dev/null || true
niri msg output eDP-1 on 2>/dev/null || true
niri msg action power-on-monitors 2>/dev/null || true

# 2. Check if Quickshell is currently responsive to IPC
if timeout 2s qs -c niri-caelestia-shell ipc call lock isLocked >/dev/null 2>&1; then
    # Quickshell is alive, re-assert lock
    qs -c niri-caelestia-shell ipc call lock lock >/dev/null 2>&1 || true
    exit 0
fi

# 3. Quickshell is not responding. Check if it's already booting or needs restart.
QS_PID=$(pgrep -f "quickshell.*shell\.qml" | head -n1 || true)
if [ -n "$QS_PID" ]; then
    # Check process age. If it started less than 15 seconds ago, let it finish starting!
    ELAPSED=$(ps -p "$QS_PID" -o etimes= 2>/dev/null | tr -d ' ' || echo 99)
    if [ "$ELAPSED" -lt 15 ]; then
        # Process is young and still initializing, poll for IPC
        for i in $(seq 1 25); do
            sleep 0.4
            if timeout 2s qs -c niri-caelestia-shell ipc call lock lock >/dev/null 2>&1; then
                exit 0
            fi
        done
    else
        # Process is older than 15s and hung without answering IPC, kill it so wrapper restarts it
        kill -9 "$QS_PID" 2>/dev/null || true
        sleep 0.5
    fi
fi

# 4. Wait for wrapper to restart Quickshell
for i in $(seq 1 25); do
    sleep 0.4
    if timeout 2s qs -c niri-caelestia-shell ipc call lock isLocked >/dev/null 2>&1; then
        qs -c niri-caelestia-shell ipc call lock lock >/dev/null 2>&1 || true
        exit 0
    fi
done

# 5. If STILL not running and the wrapper is NOT running, only then launch the wrapper
if ! pgrep -f "quickshell.*shell\.qml" >/dev/null && ! pgrep -f "launch-quickshell.sh" >/dev/null; then
    WRAPPER="$HOME/.config/niri_caelestia/scripts/launch-quickshell.sh"
    if [ -x "$WRAPPER" ]; then
        nohup "$WRAPPER" >/dev/null 2>&1 &
    fi
    for i in $(seq 1 25); do
        sleep 0.4
        if timeout 2s qs -c niri-caelestia-shell ipc call lock lock >/dev/null 2>&1; then
            exit 0
        fi
    done
fi
