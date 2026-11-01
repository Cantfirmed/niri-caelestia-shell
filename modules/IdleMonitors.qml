pragma ComponentBehavior: Bound

import "lock"
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.Services
import qs.services

Scope {
    id: root

    required property Lock lock
    readonly property bool hasPlayer: Players.list.some(p => p.isPlaying)
    readonly property bool isCharging: !UPower.onBattery
    readonly property bool enabled: {
        if (GlobalConfig.general.idle.inhibitWhenAudio && hasPlayer)
            return false;
        if (GlobalConfig.general.idle.inhibitWhenCharging && isCharging)
            return false;
        return true;
    }

    function handleIdleAction(action: var): void {
        if (!action)
            return;

        if (action === "lock")
            lock.lock.locked = true;
        else if (action === "unlock")
            lock.lock.locked = false;
        else if (action === "dpms off") {
            Compositor.powerOffMonitors();
        } else if (action === "dpms on") {
            Compositor.powerOnMonitors();
        } else if (typeof action === "string") {
            Quickshell.execDetached(["sh", "-c", action]);
        } else if (!SessionManager.exec(action)) {
            Quickshell.execDetached(action);
        }
    }

    Connections {
        function onAboutToSleep(): void {
            if (GlobalConfig.general.idle.lockBeforeSleep)
                root.lock.lock.locked = true;
        }

        // Restart Quickshell as soon as logind reports the resume.
        //
        // On wake the external output drops and re-establishes its DRM link, so
        // the screen list goes empty for a moment and every per-screen window is
        // destroyed and recreated. quickshell 0.3.1 segfaults during that churn
        // (QQuickItem dtor -> dangling QQuickWindow in maybeUpdate). A fresh
        // process only ever creates windows while the outputs settle, so
        // restarting right here avoids the crash path. The screen is still black
        // at this point, so the restart is invisible, and the session is
        // re-locked from logind's LockedHint.
        //
        // See scripts/quickshell-resume-guard.sh for the details and safety
        // checks (wrapper present, shell not still booting).
        function onResumed(): void {
            Quickshell.execDetached(["bash", Quickshell.shellPath("scripts/quickshell-resume-guard.sh")]);
        }

        function onLockRequested(): void {
            root.lock.lock.locked = true;
        }

        function onUnlockRequested(): void {
            root.lock.lock.unlock();
        }

        target: SessionManager
    }

    Variants {
        model: GlobalConfig.general.idle.timeouts.values
        IdleMonitor {
            required property var modelData

            enabled: {
                if (!root.enabled || !(modelData.enabled ?? true))
                    return false;
                if (modelData.inhibitWhenAudio && root.hasPlayer)
                    return false;
                if (modelData.inhibitWhenCharging && root.isCharging)
                    return false;
                return true;
            }
            timeout: modelData.timeout
            respectInhibitors: modelData.respectInhibitors ?? true
            onIsIdleChanged: root.handleIdleAction(isIdle ? modelData.idleAction : modelData.returnAction)
        }
    }
}

