pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Internal
import qs.utils

Singleton {
    id: root

    readonly property string tilingConfigPath: `${Paths.home}/.config/niri/niri/tiling.kdl`
    readonly property string secondaryConfigPath: `${Paths.home}/.config/niri_caelestia/niri/tiling.kdl`
    readonly property string statePath: `${Paths.home}/.local/state/caelestia/niri_tiling.json`

    property bool loaded: false
    property bool tilingRulesEnabled: true
    property var rules: []

    onTilingRulesEnabledChanged: requestSave()
    onRulesChanged: requestSave()

    function requestSave(): void {
        if (!root.loaded)
            return;
        saveDebounceTimer.restart();
    }

    function init(): void {
        console.log("[NiriTiling] Initializing service...");
        if (!root.loaded)
            initTimer.start();
    }

    function saveImmediately(): void {
        if (!root.loaded)
            return;

        const stateObj = {
            tilingRulesEnabled: root.tilingRulesEnabled,
            rules: root.rules
        };

        const jsonStr = JSON.stringify(stateObj, null, 2);
        stateWriter.setText(jsonStr);

        const kdl = generateKdl();
        console.log("[NiriTiling] Writing tiling.kdl (length:", kdl.length, ")");
        tilingKdlWriter.setText(kdl);
        secondaryKdlWriter.setText(kdl);

        reloadNiriConfig();
    }

    function reloadNiriConfig(): void {
        const proc = Qt.createQmlObject('import Quickshell.Io; Process { command: ["niri", "msg", "action", "load-config-file"] }', root);
        proc.exited.connect(() => proc.destroy());
        proc.running = true;
    }

    function generateKdl(): string {
        let kdl = "// ============================================================================\n";
        kdl += "// NIRI TILING CONFIGURATION\n";
        kdl += "// Generated automatically by Caelestia Nexus Settings. Edits may be overwritten.\n";
        kdl += "// ============================================================================\n\n";

        if (!root.tilingRulesEnabled || !root.rules || root.rules.length === 0) {
            kdl += "// Tiling rules disabled or empty\n";
            return kdl;
        }

        for (let i = 0; i < root.rules.length; i++) {
            const r = root.rules[i];
            if (!r || !r.enabled || !r.id || r.id.trim().length === 0)
                continue;

            const type = r.type || "app-id";
            const trimmed = r.id.trim();

            kdl += `// Rule: ${r.name || trimmed}\n`;
            kdl += "window-rule {\n";

            if (r.isRegex) {
                kdl += `    match ${type}=r#"${trimmed}"#\n`;
            } else {
                kdl += `    match ${type}="${trimmed}"\n`;
                if (!trimmed.endsWith(".desktop")) {
                    kdl += `    match ${type}="${trimmed}.desktop"\n`;
                }
            }

            kdl += "    open-floating false\n";

            if (r.columnWidth && Number(r.columnWidth) > 0) {
                const prop = Number(r.columnWidth).toFixed(2);
                kdl += `    default-column-width { proportion ${prop}; }\n`;
            }

            if (r.maximized) {
                kdl += "    open-maximized true\n";
            }

            kdl += "}\n\n";
        }

        return kdl;
    }

    function isAppTiled(appId: string): bool {
        if (!appId || !root.rules)
            return false;
        const cleanId = appId.replace(/\.desktop$/, "");
        for (let i = 0; i < root.rules.length; i++) {
            const r = root.rules[i];
            if (!r || !r.enabled)
                continue;
            const rClean = (r.id || "").replace(/\.desktop$/, "");
            if (r.id === appId || rClean === cleanId || r.id === cleanId)
                return true;
            if (r.isRegex) {
                try {
                    const reg = new RegExp(r.id);
                    if (reg.test(appId) || reg.test(cleanId))
                        return true;
                } catch (e) {}
            }
        }
        return false;
    }

    function setAppTiled(appId: string, name: string, icon: string, tiled: bool): void {
        if (!appId)
            return;
        const cleanId = appId.replace(/\.desktop$/, "");
        const existingIdx = (root.rules || []).findIndex(r => {
            const rClean = (r.id || "").replace(/\.desktop$/, "");
            return r.id === appId || rClean === cleanId || r.id === cleanId;
        });

        if (tiled) {
            if (existingIdx >= 0) {
                toggleRule(existingIdx, true);
            } else {
                addRule(cleanId, name || cleanId, icon || cleanId, false, 0, false);
            }
        } else {
            if (existingIdx >= 0) {
                removeRule(existingIdx);
            }
        }
    }

    function addRule(id: string, name: string, icon: string, isRegex: bool, columnWidth: real, maximized: bool): void {
        if (!id || id.trim().length === 0)
            return;
        const trimmed = id.trim();
        const existingIdx = (root.rules || []).findIndex(r => r.id === trimmed);
        const newRule = {
            id: trimmed,
            name: name || trimmed,
            icon: icon || trimmed,
            type: "app-id",
            isRegex: !!isRegex,
            columnWidth: columnWidth || 0,
            maximized: !!maximized,
            enabled: true
        };

        if (existingIdx >= 0) {
            const updated = [...root.rules];
            updated[existingIdx] = newRule;
            root.rules = updated;
        } else {
            root.rules = [...root.rules, newRule];
        }
        root.requestSave();
    }

    function removeRule(index: int): void {
        if (index < 0 || index >= root.rules.length)
            return;
        const updated = [...root.rules];
        updated.splice(index, 1);
        root.rules = updated;
        root.requestSave();
    }

    function toggleRule(index: int, enabled: bool): void {
        if (index < 0 || index >= root.rules.length)
            return;
        const updated = [...root.rules];
        updated[index] = Object.assign({}, updated[index], { enabled: enabled });
        root.rules = updated;
        root.requestSave();
    }

    function setColumnWidth(index: int, width: real): void {
        if (index < 0 || index >= root.rules.length)
            return;
        const updated = [...root.rules];
        updated[index] = Object.assign({}, updated[index], { columnWidth: width });
        root.rules = updated;
        root.requestSave();
    }

    function setMaximized(index: int, max: bool): void {
        if (index < 0 || index >= root.rules.length)
            return;
        const updated = [...root.rules];
        updated[index] = Object.assign({}, updated[index], { maximized: max });
        root.rules = updated;
        root.requestSave();
    }

    function clearAllRules(): void {
        root.rules = [];
        root.requestSave();
    }

    Timer {
        id: saveDebounceTimer

        interval: 150
        onTriggered: root.saveImmediately()
    }

    Timer {
        id: initTimer

        interval: 1500
        onTriggered: {
            if (!root.loaded) {
                root.loaded = true;
                root.saveImmediately();
            }
        }
    }

    FileView {
        id: stateFile

        path: root.statePath
        printErrors: false
        onLoaded: {
            initTimer.stop();
            const raw = text();
            if (raw && raw.trim().length > 0) {
                try {
                    const data = JSON.parse(raw);
                    if (data) {
                        if (data.tilingRulesEnabled !== undefined)
                            root.tilingRulesEnabled = data.tilingRulesEnabled;
                        if (Array.isArray(data.rules))
                            root.rules = data.rules;
                    }
                } catch (e) {
                    console.warn("[NiriTiling] Failed to parse state file:", e);
                }
                root.loaded = true;
                root.saveImmediately();
            } else {
                root.loaded = true;
                root.saveImmediately();
            }
        }
        onLoadFailed: {
            initTimer.stop();
            root.loaded = true;
            root.saveImmediately();
        }
    }

    FileView {
        id: tilingKdlWriter

        path: root.tilingConfigPath
        printErrors: true
    }

    FileView {
        id: secondaryKdlWriter

        path: root.secondaryConfigPath
        printErrors: false
    }

    FileView {
        id: stateWriter

        path: root.statePath
        printErrors: true
    }
}
