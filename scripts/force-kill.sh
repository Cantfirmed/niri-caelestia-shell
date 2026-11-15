#!/usr/bin/env bash
# Force-kill (SIGKILL) the currently focused Niri window's process.

set -euo pipefail

win_json="$(niri msg -j focused-window 2>/dev/null || true)"
if [ -z "$win_json" ] || [ "$win_json" = "null" ]; then
    exit 0
fi

pid="$(printf '%s' "$win_json" | jq -r '.pid // empty')"
if [ -z "$pid" ] || ! [[ "$pid" =~ ^[0-9]+$ ]] || [ "$pid" -le 1 ]; then
    notify-send -a "niri" -u normal -t 2500 "Force Kill" "Focused window has no killable PID; trying close-window." 2>/dev/null || true
    niri msg action close-window >/dev/null 2>&1 || true
    exit 0
fi

comm="$(cat "/proc/$pid/comm" 2>/dev/null || true)"
case "$comm" in
    niri|quickshell|xwayland-satellite|systemd)
        notify-send -a "niri" -u normal -t 2500 "Force Kill Blocked" "Refusing to SIGKILL '$comm' (PID $pid); sending close-window instead." 2>/dev/null || true
        niri msg action close-window >/dev/null 2>&1 || true
        exit 0
        ;;
esac

kill -KILL "$pid"
