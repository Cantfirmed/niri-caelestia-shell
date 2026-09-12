#!/bin/bash

# A robust wrapper script to auto-restart Quickshell if it crashes,
# while respecting intentional kills during display switches.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export QML2_IMPORT_PATH="$SCRIPT_DIR/build/qml:${QML2_IMPORT_PATH:-}"
export QML_IMPORT_PATH="$SCRIPT_DIR/build/qml:${QML_IMPORT_PATH:-}"

while true; do
    export QML2_IMPORT_PATH="$SCRIPT_DIR/build/qml:${QML2_IMPORT_PATH:-}"
    export QML_IMPORT_PATH="$SCRIPT_DIR/build/qml:${QML_IMPORT_PATH:-}"
    echo "[quickshell-wrapper] Starting Quickshell..." >&2
    if [ -x "$HOME/.local/bin/quickshell" ]; then
        "$HOME/.local/bin/quickshell" --path /home/patrick/.config/quickshell/niri-caelestia-shell/shell.qml
    else
        quickshell --path /home/patrick/.config/quickshell/niri-caelestia-shell/shell.qml
    fi
    EXIT_CODE=$?
    
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
        # 137 = 128 + 9 (SIGKILL), sent by niri-display.py or manual kill during output changes.
        echo "[quickshell-wrapper] Quickshell killed by SIGKILL. Checking running state..." >&2
        sleep 1
        
        if pgrep -x "quickshell|qs" > /dev/null; then
            echo "[quickshell-wrapper] Quickshell is already running." >&2
            # Wait for it to exit before starting the next loop iteration
            while pgrep -x "quickshell|qs" > /dev/null; do
                sleep 2
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
