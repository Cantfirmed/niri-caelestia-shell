pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.services
import qs.utils

Item {
    id: root

    // Tuning & Config
    readonly property int msContagio: GlobalConfig.background?.transition?.duration ?? 1800
    readonly property int msPerfil: 2000
    readonly property real glow: GlobalConfig.background?.transition?.glow ?? 0.9

    // State
    property bool active: false
    property string phase: "idle" // "idle", "preparing", "loading", "running"
    property string oldPath: ""
    property string newPath: ""
    property string kind: "contagio"
    property string fieldPath: ""
    property string linePath: ""
    property real t: 0
    property real seed: 0
    property color ember: Colours.palette.m3primary
    property color ink: Colours.palette.m3onSurface

    property int readyCount: 0
    readonly property int screenCount: Math.max(1, Screens.screens.filter(s => s && s.name && (GlobalConfig.forScreen(s.name)?.background?.enabled ?? false)).length)

    // Benchmark stats
    property int statFrames: 0
    property real statWorst: 0
    property string lastStats: ""

    signal finished(string path)

    function lifted(c) {
        return Qt.hsla(c.hslHue, Math.max(c.hslSaturation, 0.55),
                       Math.min(Math.max(c.hslLightness, 0.62), 0.82), 1);
    }

    function updateColors() {
        const pal = [
            Colours.palette.m3primary,
            Colours.palette.m3secondary,
            Colours.palette.m3tertiary,
            Colours.palette.m3onSurface,
            Colours.palette.m3primaryContainer,
            Colours.palette.m3secondaryContainer,
            Colours.palette.m3tertiaryContainer
        ];
        const chroma = c => (c.hslSaturation ?? 0) * (1 - Math.abs(2 * (c.hslLightness ?? 0.5) - 1));
        const light = c => 0.299 * (c.r ?? 0) + 0.587 * (c.g ?? 0) + 0.114 * (c.b ?? 0);

        const mostVivid = pal.reduce((a, b) => chroma(b) > chroma(a) ? b : a, pal[0]);
        root.ember = root.lifted(mostVivid);

        const lightest = pal.reduce((a, b) => light(b) > light(a) ? b : a, pal[0]);
        root.ink = lightest;
    }

    function play(oldImg: string, newImg: string, k: string, field: string, line: string): string {
        if (!newImg)
            return "no new image";

        root.cancel();

        root.oldPath = oldImg;
        root.newPath = newImg;
        root.kind = k === "perfil" ? "perfil" : "contagio";
        root.fieldPath = field;
        root.linePath = line || field;
        root.readyCount = 0;
        root.t = 0;
        root.seed = Math.random() * 100;
        root.updateColors();

        root.phase = "loading";
        root.active = true;
        watchdog.interval = 8000;
        watchdog.restart();
        return "ok";
    }

    function trigger(oldImg: string, newImg: string): void {
        if (!newImg || oldImg === newImg)
            return;

        if (root.phase !== "idle" && root.newPath === newImg)
            return;

        if (!(GlobalConfig.background?.transition?.enabled ?? true)) {
            root.finished(newImg);
            return;
        }

        root.cancel();
        root.oldPath = oldImg;
        root.newPath = newImg;
        root.phase = "preparing";
        watchdog.interval = 20000;
        watchdog.restart();

        const transitionType = GlobalConfig.background?.transition?.type ?? "auto";
        eligeProcess.targetNew = newImg;
        eligeProcess.targetOld = oldImg;
        eligeProcess.command = ["python3", Quickshell.shellPath("scripts/wallfx.py"), "elige", transitionType, newImg];
        eligeProcess.running = true;
    }

    function screenReady(): void {
        if (root.phase !== "loading")
            return;

        root.readyCount++;
        if (root.readyCount >= root.screenCount)
            root.startAnimation();
    }

    function startAnimation(): void {
        root.phase = "running";
        runAnim.duration = root.kind === "perfil" ? root.msPerfil : root.msContagio;
        watchdog.interval = Math.max(3000, runAnim.duration + 1000);
        watchdog.restart();
        runAnim.restart();
    }

    function finish(): void {
        runAnim.stop();
        watchdog.stop();
        const dest = root.newPath;
        root.phase = "idle";
        root.active = false;
        root.t = 0;
        if (dest)
            root.finished(dest);
    }

    function cancel(): void {
        runAnim.stop();
        watchdog.stop();
        eligeProcess.running = false;
        root.phase = "idle";
        root.active = false;
        root.t = 0;
    }

    Component.onCompleted: {
        warmProcess.running = true;
    }

    NumberAnimation {
        id: runAnim

        target: root
        property: "t"
        from: 0
        to: 1
        easing.type: Easing.Linear

        onFinished: root.finish()
    }

    FrameAnimation {
        id: frameAnim

        running: root.phase === "running"

        onRunningChanged: {
            if (running) {
                root.statFrames = 0;
                root.statWorst = 0;
            } else if (root.statFrames > 0) {
                root.lastStats = root.kind + ": " + root.statFrames + " frames in "
                    + runAnim.duration + " ms (" + Math.round(root.statFrames * 1000 / runAnim.duration)
                    + " fps), worst " + Math.round(root.statWorst * 1000) + " ms";
            }
        }

        onTriggered: {
            root.statFrames++;
            if (root.statFrames > 2)
                root.statWorst = Math.max(root.statWorst, frameTime);
        }
    }

    Timer {
        id: watchdog

        interval: 20000
        onTriggered: {
            console.warn("WallFx transition watchdog triggered, finishing cleanly");
            root.finish();
        }
    }

    Process {
        id: eligeProcess

        property string targetOld: ""
        property string targetNew: ""

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim().length === 0)
                    return;
                const parts = text.trim().split(/\s+/);
                if (parts.length >= 3) {
                    const kind = parts[0];
                    const field = parts[1];
                    const line = parts[2];
                    root.play(eligeProcess.targetOld, eligeProcess.targetNew, kind, field, line);
                } else if (parts.length === 2) {
                    root.play(eligeProcess.targetOld, eligeProcess.targetNew, "contagio", parts[0], parts[1]);
                } else {
                    root.finish();
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && root.phase === "preparing") {
                console.warn("wallfx.py exited with error, falling back");
                root.finish();
            }
        }
    }

    Process {
        id: warmProcess

        command: ["python3", Quickshell.shellPath("scripts/wallfx.py"), "warm", Paths.wallsdir]
    }

    IpcHandler {
        id: ipc

        function play(oldImg: string, newImg: string, kind: string, field: string, line: string): string {
            return root.play(oldImg, newImg, kind, field, line);
        }

        function trigger(oldImg: string, newImg: string): string {
            root.trigger(oldImg, newImg);
            return "ok";
        }

        function stats(): string {
            return root.lastStats || "no transitions recorded";
        }

        function stop(): string {
            root.cancel();
            return "ok";
        }

        function state(): string {
            return root.phase;
        }

        target: "wallfx"
    }
}
