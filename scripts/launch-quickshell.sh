#!/bin/bash

# A robust wrapper script to auto-restart Quickshell if it crashes,
# while respecting intentional kills during display switches.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export QML2_IMPORT_PATH="$SCRIPT_DIR/build/qml:${QML2_IMPORT_PATH:-}"
export QML_IMPORT_PATH="$SCRIPT_DIR/build/qml:${QML_IMPORT_PATH:-}"
export LD_LIBRARY_PATH="$SCRIPT_DIR/build/lib:${LD_LIBRARY_PATH:-}"

# Prevent Quickshell from opening an interactive crash dialog or popups,
# which causes futex deadlocks when crashing without an active GUI surface.
export QS_DISABLE_CRASH_HANDLER=1
export QS_NO_RELOAD_POPUP=1

# Silence harmless DBus property errors (e.g. Discord SNI omitting IconName, transient MPRIS errors)
export QT_LOGGING_RULES="quickshell.dbus.properties.warning=false;${QT_LOGGING_RULES:-}"

# Ensure Wayland and Niri environment variables are populated
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

export DISPLAY="${DISPLAY:-:0}"

LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/quickshell-wrapper.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec >> "$LOG_FILE" 2>&1

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

while true; do
    export DISPLAY="${DISPLAY:-:0}"
    export QML2_IMPORT_PATH="$SCRIPT_DIR/build/qml:${QML2_IMPORT_PATH:-}"
    export QML_IMPORT_PATH="$SCRIPT_DIR/build/qml:${QML_IMPORT_PATH:-}"
    export LD_LIBRARY_PATH="$SCRIPT_DIR/build/lib:${LD_LIBRARY_PATH:-}"
    export QS_DISABLE_CRASH_HANDLER=1
    export QS_NO_RELOAD_POPUP=1
    export QT_LOGGING_RULES="quickshell.dbus.properties.warning=false;${QT_LOGGING_RULES:-}"

    log_msg "[quickshell-wrapper] Starting Quickshell..."
    if [ -x "$HOME/.local/bin/quickshell" ]; then
        QS_BIN="$HOME/.local/bin/quickshell"
    else
        QS_BIN="quickshell"
    fi

    "$QS_BIN" --path /home/patrick/.config/quickshell/niri-caelestia-shell/shell.qml &
    QS_PID=$!

    # Active Watchdog: detects unresponsive IPC and recovers
    (
        CONSECUTIVE_FAILS=0
        # Startup grace period: allow Quickshell to load QML, shaders, wallpapers, and register IPC
        sleep 15
        while kill -0 "$QS_PID" 2>/dev/null; do
            # Skip checks during display reconfiguration
            if [ -f "/tmp/quickshell-display-switching" ]; then
                sleep 2
                continue
            fi

            # Ping Quickshell IPC with relaxed threshold to prevent false-positive kills during heavy UI/DBus load
            if ! timeout 6s qs -c niri-caelestia-shell ipc call lock isLocked >/dev/null 2>&1; then
                CONSECUTIVE_FAILS=$((CONSECUTIVE_FAILS + 1))
                if [ $CONSECUTIVE_FAILS -ge 5 ]; then
                    log_msg "[quickshell-watchdog] Quickshell (PID $QS_PID) unresponsive to IPC for 5 consecutive checks (~30-40s). Terminating..."
                    kill -9 "$QS_PID" 2>/dev/null
                    break
                fi
            else
                CONSECUTIVE_FAILS=0
            fi

            sleep 6
        done
    ) &
    WATCHDOG_PID=$!

    wait "$QS_PID" 2>/dev/null
    EXIT_CODE=$?

    # Cleanup watchdog
    kill "$WATCHDOG_PID" 2>/dev/null
    wait "$WATCHDOG_PID" 2>/dev/null

    log_msg "[quickshell-wrapper] Quickshell (PID $QS_PID) exited with code $EXIT_CODE"

    LOCK_FILE="/tmp/quickshell-display-switching"
    if [ -f "$LOCK_FILE" ]; then
        # Display switch in progress (managed by niri-display.py)
        log_msg "[quickshell-wrapper] Display switch in progress. Waiting for display switcher..."
        WAITED=0
        while [ -f "$LOCK_FILE" ] && [ $WAITED -lt 100 ]; do
            sleep 0.1
            WAITED=$((WAITED + 1))
        done
        rm -f "$LOCK_FILE" 2>/dev/null
        # Wait a short moment for Wayland/Niri output events to settle
        sleep 0.3
        log_msg "[quickshell-wrapper] Display switch complete. Restarting Quickshell..."
    elif [ $EXIT_CODE -eq 137 ]; then
        # 137 = 128 + 9 (SIGKILL), sent by watchdog or niri-display.py.
        log_msg "[quickshell-wrapper] Quickshell killed by SIGKILL. Checking running state..."
        sleep 0.5

        if pgrep -f "quickshell.*shell\.qml" > /dev/null; then
            log_msg "[quickshell-wrapper] Quickshell is already running."
            while pgrep -f "quickshell.*shell\.qml" > /dev/null; do
                sleep 1
            done
        else
            log_msg "[quickshell-wrapper] Quickshell not running. Restarting now..."
        fi
    elif [ $EXIT_CODE -eq 0 ]; then
        # Normal exit (e.g. manual qs kill). Restart after a short delay.
        log_msg "[quickshell-wrapper] Clean exit. Restarting in 1s..."
        sleep 1
    else
        # Crashed (e.g., 139 = 128 + 11 SIGSEGV). Restart quickly.
        log_msg "[quickshell-wrapper] Quickshell crashed. Restarting in 0.5s..."
        sleep 0.5
    fi
done
