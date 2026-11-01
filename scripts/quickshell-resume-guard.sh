#!/usr/bin/env bash
# Restart Quickshell cleanly when the system resumes from suspend.
#
# Invoked by modules/IdleMonitors.qml on `SessionManager.resumed` (which is
# logind's PrepareForSleep(false) signal, delivered through Caelestia.Services).
#
# Why: on resume the external output (HDMI) drops and re-establishes its DRM
# link, so the compositor briefly reports zero outputs (QtWayland then creates a
# placeholder screen). `Quickshell.screens` therefore goes empty and every
# per-screen window (Drawers, Background, AreaPicker, ...) is destroyed and
# recreated. During that churn quickshell 0.3.1 segfaults in
#   QQuickItem::~QQuickItem -> QQuickItemPrivate::dirty -> QQuickWindow::maybeUpdate
# because the item still references a QQuickWindow that was already destroyed
# (see coredumps 819501 / 1056130 / 1225778 on 2026-10-31, and quickshell issues
# #1340, #1228, #1270, #503).
#
# A freshly started process only ever *creates* windows while the outputs
# settle; it never destroys an old one mid-hotplug. So killing the shell as soon
# as logind reports the resume, and letting launch-quickshell.sh restart it,
# avoids the crash path entirely. The screen is still black at that moment, so
# the restart is invisible, and the session is re-locked from logind's
# LockedHint ("Session is already locked in logind; requesting lock on startup").
#
# This deliberately reacts ONLY to the logind resume signal. It never probes or
# kills Quickshell based on heuristics (see AGENTS.md, "Quickshell Watchdog &
# Defunct Process Traps").
#
# Usage:
#   quickshell-resume-guard.sh [--once]
#   QS_RESUME_GUARD_DRY_RUN=1 ...   log instead of killing

set -u

QS_PATTERN='quickshell --path .*niri-caelestia-shell/shell\.qml'
WRAPPER_PATTERN='launch-quickshell\.sh'

# Minimum uptime (seconds) of the running shell before we are willing to restart
# it. Mirrors the rule from the emergency lock rescue: never kill a shell that
# is still booting (QML compilation + shaders take ~3.5s, and plugin imports can
# take longer under load).
MIN_UPTIME=10

DRY_RUN="${QS_RESUME_GUARD_DRY_RUN:-0}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [quickshell-resume-guard] $*"
}

quickshell_pids() {
    # shellcheck disable=SC2009
    pgrep -f "$QS_PATTERN" 2>/dev/null || true
}

wrapper_running() {
    pgrep -f "$WRAPPER_PATTERN" >/dev/null 2>&1
}

restart_quickshell() {
    local pids pid uptime

    pids="$(quickshell_pids)"
    if [ -z "$pids" ]; then
        log "quickshell is not running, nothing to restart"
        return 0
    fi

    # Never kill an instance that is still booting.
    for pid in $pids; do
        uptime="$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')"
        if [ -n "$uptime" ] && [ "$uptime" -lt "$MIN_UPTIME" ]; then
            log "quickshell (PID $pid) is only ${uptime}s old, skipping restart"
            return 0
        fi
    done

    if ! wrapper_running; then
        # Shell was started by hand (e.g. for debugging); do not leave it dead.
        log "launch-quickshell.sh is not running, leaving quickshell alone"
        return 0
    fi

    if [ "$DRY_RUN" = "1" ]; then
        log "DRY RUN: would restart quickshell (PIDs: $(echo "$pids" | tr '\n' ' '))"
        return 0
    fi

    log "resume detected, restarting quickshell (PIDs: $(echo "$pids" | tr '\n' ' '))"
    # Quickshell installs no SIGTERM handler, so this terminates it immediately
    # without tearing down a single window. launch-quickshell.sh restarts it
    # within 0.5s (exit code 143 -> "crashed. Restarting in 0.5s").
    # shellcheck disable=SC2086
    kill -TERM $pids 2>/dev/null || true
}

restart_quickshell
