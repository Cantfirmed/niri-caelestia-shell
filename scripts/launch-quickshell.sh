#!/bin/bash

# A robust wrapper script to auto-restart Quickshell if it crashes,
# while respecting intentional kills during display switches.

while true; do
    echo "[quickshell-wrapper] Starting Quickshell..." >&2
    if [ -x "$HOME/.local/bin/quickshell" ]; then
        "$HOME/.local/bin/quickshell" --path /home/patrick/.config/quickshell/niri-caelestia-shell/shell.qml
    else
        quickshell --path /home/patrick/.config/quickshell/niri-caelestia-shell/shell.qml
    fi
    EXIT_CODE=$?
    
    echo "[quickshell-wrapper] Quickshell exited with code $EXIT_CODE" >&2
    
    if [ $EXIT_CODE -eq 137 ]; then
        # 137 = 128 + 9 (SIGKILL), sent by niri-display.py during output changes.
        # We wait 3 seconds to let niri-display.py finish reloading Niri and restart Quickshell.
        echo "[quickshell-wrapper] Quickshell killed by SIGKILL. Waiting for display switcher..." >&2
        sleep 3
        
        if pgrep -x "quickshell" > /dev/null; then
            echo "[quickshell-wrapper] Quickshell is already running (restarted by display switcher)." >&2
            # Wait for it to exit before starting the next loop iteration
            while pgrep -x "quickshell" > /dev/null; do
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
