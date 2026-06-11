pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.Models
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property list<string> smartArg: GlobalConfig.services.smartScheme ? [] : ["--no-smart"]
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")

    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent
    property bool previewColourLock

    function getCategoryFor(w: FileSystemEntry): string {
        let category = w.parentDir.slice(Paths.wallsdir.length + 1);
        if (category.includes("/"))
            category = category.slice(0, category.indexOf("/"));
        return category;
    }

    function setRandom(): void {
        if (root.list.length > 0) {
            const idx = Math.floor(Math.random() * root.list.length);
            const path = root.list[idx].path;
            setWallpaper(path);
        }
    }

    function setWallpaper(path: string): void {
        actualCurrent = path;
        
        stateFile.watchChanges = false;
        stateFile.setText(path);
        stateFile.watchChanges = true;

        const mode = Colours.light ? "light" : "dark";
        const schemeType = "scheme-" + Colours.variant;
        matugenProcess.command = ["matugen", "image", path, "-m", mode, "-t", schemeType, "--source-color-index", "0"];
        matugenProcess.running = true;
    }

    function preview(path: string): void {
        previewPath = path;
        showPreview = true;

        if (Colours.scheme === "dynamic")
            getPreviewColoursProc.running = true;
    }

    function stopPreview(): void {
        showPreview = false;
        if (!previewColourLock)
            Colours.showPreview = false;
    }

    list: wallpapers.entries
    key: "relativePath"
    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    IpcHandler {
        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }

        function open(): void {
            const visibilities = Visibilities.getForActive()
            if (visibilities) {
                visibilities.wallpaperRequested = true
                visibilities.launcher = true
            }
        }

        target: "wallpaper"
    }

    FileView {
        id: stateFile
        path: root.currentNamePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let wall = text().trim();
            if (!wall) {
                wall = root.fallback;
                root.setWallpaper(root.fallback);
            }
            root.actualCurrent = wall;
            root.previewColourLock = false;
        }
        onLoadFailed: {
            root.actualCurrent = root.fallback;
            root.previewColourLock = false;
            root.setWallpaper(root.fallback);
        }
    }

    FileSystemModel {
        id: wallpapers

        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Images
    }

    Process {
        id: matugenProcess

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("Matugen exited with code:", exitCode);
            }
            // Reload tmux config so the status bar picks up new matugen colours
            tmuxReload.running = true;
        }
    }

    Process {
        id: tmuxReload

        command: ["tmux", "source-file", "/home/patrick/.config/tmux/tmux.conf"]
    }

    Process {
        id: getPreviewColoursProc

        command: {
            const scriptPath = Paths.toLocalFile(Qt.resolvedUrl("../scripts/preview.py"));
            const mode = Colours.light ? "light" : "dark";
            const schemeType = "scheme-" + Colours.variant;
            return ["python3", scriptPath, root.previewPath, mode, schemeType];
        }
        stdout: StdioCollector {
            onStreamFinished: {
                Colours.load(text, true);
                Colours.showPreview = true;
            }
        }
    }
}
