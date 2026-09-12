#!/usr/bin/env bash
set -euo pipefail

# verify-deltas.sh — Verify that custom Niri features and fixes have not been overwritten.
# Run this after any merge, rebase, patch application, or before committing.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED=0

pass() {
    echo -e "  ${GREEN}✓${NC} $1"
}

fail() {
    echo -e "  ${RED}✗ FAIL:${NC} $1"
    echo -e "    ${YELLOW}↳ Detail:${NC} $2"
    echo -e "    ${YELLOW}↳ Reference:${NC} NIRI-DELTAS.md"
    FAILED=$((FAILED + 1))
}

echo "===================================================="
echo " Running Niri Caelestia Deltas Verification"
echo "===================================================="

# 1. Session Drawer Sleep Button
SESSION_CONTENT="modules/session/Content.qml"
if [ -f "$SESSION_CONTENT" ]; then
    if grep -q 'id: sleep' "$SESSION_CONTENT" && \
       grep -q 'Config\.session\.commands\.sleep' "$SESSION_CONTENT" && \
       grep -q '"dark_mode"' "$SESSION_CONTENT"; then
        if grep -q 'id: hibernate' "$SESSION_CONTENT"; then
            fail "Session Drawer has hibernate instead of sleep ($SESSION_CONTENT)" \
                 "Upstream replaced sleep with hibernate. Check NIRI-DELTAS.md Section 2.A."
        else
            pass "Session Drawer has Sleep action and dark_mode fallback ($SESSION_CONTENT)"
        fi
    else
        fail "Session Drawer missing Sleep action or dark_mode icon ($SESSION_CONTENT)" \
             "Upstream likely replaced 'sleep' with 'hibernate'. Check NIRI-DELTAS.md Section 2.A."
    fi
else
    fail "File missing: $SESSION_CONTENT" "File does not exist."
fi

# 2. Lockscreen Quick Actions
LOCK_CENTER="modules/lock/Center.qml"
if [ -f "$LOCK_CENTER" ]; then
    if grep -q 'Config\.session\.commands\.sleep' "$LOCK_CENTER" && \
       grep -q 'Config\.session\.commands\.reboot' "$LOCK_CENTER" && \
       grep -q 'Config\.session\.commands\.shutdown' "$LOCK_CENTER" && \
       grep -q 'Layout\.fillHeight: true' "$LOCK_CENTER"; then
        pass "Lockscreen has Sleep, Reboot, and Shutdown buttons ($LOCK_CENTER)"
    else
        fail "Lockscreen missing quick action buttons ($LOCK_CENTER)" \
             "Upstream removed sleep/reboot/shutdown buttons. Check NIRI-DELTAS.md Section 2.B."
    fi
else
    fail "File missing: $LOCK_CENTER" "File does not exist."
fi

# 3. Active Window Info Popout
ACTIVE_WINDOW="modules/bar/popouts/ActiveWindow.qml"
if [ -f "$ACTIVE_WINDOW" ]; then
    if grep -q 'Niri\.lastFocusedWindow' "$ACTIVE_WINDOW" && \
       grep -q 'detachRequested("winfo")' "$ACTIVE_WINDOW"; then
        if grep -q 'ScreencopyView' "$ACTIVE_WINDOW"; then
            fail "Active Window popout contains Hyprland ScreencopyView ($ACTIVE_WINDOW)" \
                 "ScreencopyView is Hyprland-specific and collapses popout width. Check NIRI-DELTAS.md Section 2.F."
        else
            pass "Active Window popout uses Niri IPC and triggers winfo drawer ($ACTIVE_WINDOW)"
        fi
    else
        fail "Active Window popout not wired to Niri or winfo drawer ($ACTIVE_WINDOW)" \
             "Upstream replaced Niri popout. Check NIRI-DELTAS.md Section 2.F."
    fi
else
    fail "File missing: $ACTIVE_WINDOW" "File does not exist."
fi

# 4. Battery / Power Profile Auto-Balance
BATTERY_POPOUT="modules/bar/popouts/Battery.qml"
if [ -f "$BATTERY_POPOUT" ]; then
    if grep -q 'auto_mode' "$BATTERY_POPOUT" && \
       grep -q 'PowerManagement\.setAutoBalance' "$BATTERY_POPOUT" && \
       grep -q 'PowerManagement\.setManualProfile' "$BATTERY_POPOUT"; then
        pass "Battery popout includes auto-balance power profile ($BATTERY_POPOUT)"
    else
        fail "Battery popout missing auto-balance mode ($BATTERY_POPOUT)" \
             "Upstream replaced 4th profile with 3-profile selector. Check NIRI-DELTAS.md Section 2.G."
    fi
else
    fail "File missing: $BATTERY_POPOUT" "File does not exist."
fi

# 5. C++ SessionConfig (sleep icon & command)
SESSION_CONFIG="plugin/src/Caelestia/Config/sessionconfig.hpp"
if [ -f "$SESSION_CONFIG" ]; then
    if grep -q 'CONFIG_PROPERTY(QString, sleep,' "$SESSION_CONFIG" && \
       grep -q 'CONFIG_PROPERTY(QStringList, sleep,' "$SESSION_CONFIG"; then
        pass "C++ SessionConfig retains sleep property & command ($SESSION_CONFIG)"
    else
        fail "C++ SessionConfig missing sleep property or command ($SESSION_CONFIG)" \
             "Upstream deleted sleep in favor of hibernate. Check NIRI-DELTAS.md Section 2.C."
    fi
else
    fail "File missing: $SESSION_CONFIG" "File does not exist."
fi

# 6. C++ ExtraConfig AUTOMOC fix
EXTRA_CONFIG="plugin/src/Caelestia/Config/extraconfig.hpp"
if [ -f "$EXTRA_CONFIG" ]; then
    if grep -q '#include "common.hpp"' "$EXTRA_CONFIG"; then
        pass "C++ ExtraConfig includes common.hpp for AUTOMOC ($EXTRA_CONFIG)"
    else
        fail "C++ ExtraConfig missing #include \"common.hpp\" ($EXTRA_CONFIG)" \
             "AUTOMOC will fail to expand CONFIG_NODE. Check NIRI-DELTAS.md Section 2.C."
    fi
else
    fail "File missing: $EXTRA_CONFIG" "File does not exist."
fi

# 7. C++ Config CMakeLists.txt registration
CONFIG_CMAKE="plugin/src/Caelestia/Config/CMakeLists.txt"
if [ -f "$CONFIG_CMAKE" ]; then
    if grep -q 'extraconfig\.hpp' "$CONFIG_CMAKE"; then
        pass "Config CMakeLists.txt registers extraconfig.hpp in SOURCES ($CONFIG_CMAKE)"
    else
        fail "Config CMakeLists.txt missing extraconfig.hpp ($CONFIG_CMAKE)" \
             "Meta-object code will not be generated. Check NIRI-DELTAS.md Section 2.C."
    fi
else
    fail "File missing: $CONFIG_CMAKE" "File does not exist."
fi

# 8. QML Import Path in launch-quickshell.sh
LAUNCH_SCRIPT="scripts/launch-quickshell.sh"
if [ -f "$LAUNCH_SCRIPT" ]; then
    if grep -q 'export QML2_IMPORT_PATH=' "$LAUNCH_SCRIPT" && \
       grep -q 'export QML_IMPORT_PATH=' "$LAUNCH_SCRIPT"; then
        pass "launch-quickshell.sh exports local QML import paths ($LAUNCH_SCRIPT)"
    else
        fail "launch-quickshell.sh missing QML import path exports ($LAUNCH_SCRIPT)" \
             "Quickshell might fall back to stale /usr/lib libraries. Check NIRI-DELTAS.md Section 2.D."
    fi
else
    fail "File missing: $LAUNCH_SCRIPT" "File does not exist."
fi

# 9. NetworkUsage Caelestia import
NET_USAGE="services/NetworkUsage.qml"
if [ -f "$NET_USAGE" ]; then
    if grep -q 'import Caelestia' "$NET_USAGE"; then
        pass "NetworkUsage.qml imports Caelestia for CircularBuffer ($NET_USAGE)"
    else
        fail "NetworkUsage.qml missing import Caelestia ($NET_USAGE)" \
             "CircularBuffer will fail to resolve. Check NIRI-DELTAS.md Section 1."
    fi
else
    fail "File missing: $NET_USAGE" "File does not exist."
fi

# 10. shell.json sleep icon
SHELL_JSON="shell.json"
if [ -f "$SHELL_JSON" ]; then
    if grep -q '"sleep": "dark_mode"' "$SHELL_JSON"; then
        pass "shell.json configures sleep icon as dark_mode ($SHELL_JSON)"
    else
        fail "shell.json missing dark_mode icon for sleep ($SHELL_JSON)" \
             "Check NIRI-DELTAS.md Section 2.C."
    fi
else
    fail "File missing: $SHELL_JSON" "File does not exist."
fi

# 11. Launcher wallpaper & clipboard state handling
LAUNCHER_CONTENT="modules/launcher/Content.qml"
if [ -f "$LAUNCHER_CONTENT" ]; then
    if grep -q 'wallpaperRequested' "$LAUNCHER_CONTENT" && \
       grep -q 'checkLauncherState()' "$LAUNCHER_CONTENT"; then
        pass "Launcher initializes wallpaper and clipboard requests on load ($LAUNCHER_CONTENT)"
    else
        fail "Launcher missing checkLauncherState or wallpaperRequested handling ($LAUNCHER_CONTENT)" \
             "Check NIRI-DELTAS.md Section 2.H."
    fi
else
    fail "File missing: $LAUNCHER_CONTENT" "File does not exist."
fi

echo "===================================================="
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}All 11 delta verification checks passed!${NC}"
    exit 0
else
    echo -e "${RED}Verification failed with $FAILED error(s).${NC}"
    echo "Please restore the missing features as documented in NIRI-DELTAS.md before committing or deploying."
    exit 1
fi
