#!/bin/bash

# A robust wrapper script to auto-restart Quickshell if it crashes,
# while respecting intentional kills during display switches.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export QML2_IMPORT_PATH="$SCRIPT_DIR/build/qml:${QML2_IMPORT_PATH:-}"
export QML_IMPORT_PATH="$SCRIPT_DIR/build/qml:${QML_IMPORT_PATH:-}"

# Prevent Quickshell from opening an interactive crash dialog or popups,
# which causes futex deadlocks when crashing without an active GUI surface.
export QS_DISABLE_CRASH_HANDLER=1
export QS_NO_RELOAD_POPUP=1

while true; do
    export QML2_IMPORT_PATH="$SCRIPT_DIR/build/qml:${QML2_IMPORT_PATH:-}"
    export QML_IMPORT_PATH="$SCRIPT_DIR/build/qml:${QML_IMPORT_PATH:-}"
    export QS_DISABLE_CRASH_HANDLER=1
    export QS_NO_RELOAD_POPUP=1

    echo "[quickshell-wrapper] Starting Quickshell..." >&2
    if [ -x "$HOME/.local/bin/quickshell" ]; then
        QS_BIN="$HOME/.local/bin/quickshell"
    else
        QS_BIN="quickshell"
    fi

    "$QS_BIN" --path /home/patrick/.config/quickshell/niri-caelestia-shell/shell.qml &
    QS_PID=$!

    # Active Watchdog: detects zombie children or unresponsive IPC and recovers
    (
        CONSECUTIVE_FAILS=0
        # Startup grace period
        sleep 8
        while kill -0 "$QS_PID" 2>/dev/null; do
            # Skip checks during display reconfiguration
            if [ -f "/tmp/quickshell-display-switching" ]; then
                sleep 2
                continue
            fi

            # Check if Quickshell has spawned any defunct/zombie child processes
            if ps -eo ppid,stat 2>/dev/null | grep -E "^[[:space:]]*${QS_PID}[[:space:]]+.*Z" >/dev/null; then
                echo "[quickshell-watchdog] Detected defunct child under Quickshell PID $QS_PID. Terminating..." >&2
                kill -9 "$QS_PID" 2>/dev/null
                break
            fi

            # Ping Quickshell IPC
            if ! timeout 2s qs -c niri-caelestia-shell ipc call lock isLocked >/dev/null 2>&1; then
                CONSECUTIVE_FAILS=$((CONSECUTIVE_FAILS + 1))
                if [ $CONSECUTIVE_FAILS -ge 3 ]; then
                    echo "[quickshell-watchdog] Quickshell unresponsive to IPC for 3 consecutive checks. Terminating..." >&2
                    kill -9 "$QS_PID" 2>/dev/null
                    break
                fi
            else
                CONSECUTIVE_FAILS=0
            fi

            sleep 5
        done
    ) &
    WATCHDOG_PID=$!

    wait "$QS_PID" 2>/dev/null
    EXIT_CODE=$?

    # Cleanup watchdog
    kill "$WATCHDOG_PID" 2>/dev/null
    wait "$WATCHDOG_PID" 2>/dev/null

    echo "[quickshell-wrapper] Quickshell exited with code $EXIT_CODE" >&2

    LOCK_FILE="/tmp/quickshell-display-switching"
    if [ -f "$LOCK_FILE" ]; then
        # Display switch in progress (managed by niri-display.py)
        echo "[quickshell-wrapper] Display switch in progress. Waiting for display switcher..." >&2
        WAITED=0
        while [ -f "$LOCK_FILE" ] && [ $WAITED -lt 100 ]; do
            sleep 0.1
            WAITED=$((WAITED + 1))
        done
        rm -f "$LOCK_FILE" 2>/dev/null
        # Wait a short moment for Wayland/Niri output events to settle
        sleep 0.3
        echo "[quickshell-wrapper] Display switch complete. Restarting Quickshell..." >&2
    elif [ $EXIT_CODE -eq 137 ]; then
        # 137 = 128 + 9 (SIGKILL), sent by watchdog or niri-display.py.
        echo "[quickshell-wrapper] Quickshell killed by SIGKILL. Checking running state..." >&2
        sleep 0.5

        if pgrep -f "quickshell.*shell\.qml" > /dev/null; then
            echo "[quickshell-wrapper] Quickshell is already running." >&2
            while pgrep -f "quickshell.*shell\.qml" > /dev/null; do
                sleep 1
            done
        else
            echo "[quickshell-wrapper] Quickshell not running. Restarting now..." >&2
        fi
    elif [ $EXIT_CODE -eq 0 ]; then
        # Normal exit (e.g. manual qs kill). Restart after a short delay.
        echo "[quickshell-wrapper] Clean exit. Restarting in 1s..." >&2
        sleep 1
    else
        # Crashed (e.g., 139 = 128 + 11 SIGSEGV). Restart quickly.
        echo "[quickshell-wrapper] Quickshell crashed. Restarting in 0.5s..." >&2
        sleep 0.5
    fi
done
