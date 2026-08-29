pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services

MouseArea {
    id: root

    required property LazyLoader loader
    required property ShellScreen screen

    property int borderWidth: 2
    property int rounding: 8

    property bool onClient

    property real realBorderWidth: onClient ? (typeof Hypr !== "undefined" ? (Hypr.options["general:border_size"] ?? 1) : borderWidth) : 2
    property real realRounding: onClient ? (typeof Hypr !== "undefined" ? (Hypr.options["decoration:rounding"] ?? 0) : rounding) : 0

    property real ssx
    property real ssy

    property real sx: 0
    property real sy: 0
    property real ex: screen ? screen.width : 0
    property real ey: screen ? screen.height : 0

    property real rsx: Math.min(sx, ex)
    property real rsy: Math.min(sy, ey)
    property real sw: Math.abs(sx - ex)
    property real sh: Math.abs(sy - ey)

    property real cursorX: 0
    property real cursorY: 0

    property var clients: {
        if (typeof Niri !== "undefined" && Niri.niriAvailable) {
            const wsWindows = Niri.getActiveWorkspaceWindows();
            return wsWindows.slice().sort((a, b) => {
                const aPos = a.layout?.pos_in_scrolling_layout || [0, 0];
                const bPos = b.layout?.pos_in_scrolling_layout || [0, 0];
                if (aPos[0] !== bPos[0]) return aPos[0] - bPos[0];
                return aPos[1] - bPos[1];
            });
        }
        if (typeof Hypr !== "undefined") {
            const mon = Hypr.monitorFor(screen);
            if (!mon) return [];
            const special = mon.lastIpcObject.specialWorkspace;
            const wsId = special.name ? special.id : mon.activeWorkspace.id;
            return Hypr.toplevelsForWs(wsId);
        }
        return [];
    }

    function getWindowGeometry(window) {
        if (!window?.layout?.window_size) return null;
        const size = window.layout.window_size;
        const pos = window.layout.pos_in_scrolling_layout ?? [0, 0];
        const focusedWindow = Niri.focusedWindow;
        if (!focusedWindow?.layout?.pos_in_scrolling_layout) {
            return {
                x: (screen.width - size[0]) / 2,
                y: (screen.height - size[1]) / 2,
                w: size[0],
                h: size[1]
            };
        }
        const focusedPos = focusedWindow.layout.pos_in_scrolling_layout;
        const focusedSize = focusedWindow.layout.window_size ?? [screen.width, screen.height];
        const colOffset = pos[0] - focusedPos[0];
        const rowOffset = pos[1] - focusedPos[1];
        const focusedX = focusedSize[0] < screen.width ? (screen.width - focusedSize[0]) / 2 : 0;
        const focusedY = focusedSize[1] < screen.height ? (screen.height - focusedSize[1]) / 2 : 0;
        return {
            x: focusedX + (colOffset * size[0]),
            y: focusedY + (rowOffset * size[1]),
            w: size[0],
            h: size[1]
        };
    }

    function checkClientRects(x: real, y: real): void {
        for (const client of clients) {
            if (!client) continue;
            let cx, cy, cw, ch;
            if (typeof Niri !== "undefined" && Niri.niriAvailable) {
                const geom = getWindowGeometry(client);
                if (!geom) continue;
                cx = geom.x;
                cy = geom.y;
                cw = geom.w;
                ch = geom.h;
            } else if (client.lastIpcObject) {
                cx = client.lastIpcObject.at[0] - screen.x;
                cy = client.lastIpcObject.at[1] - screen.y;
                cw = client.lastIpcObject.size[0];
                ch = client.lastIpcObject.size[1];
            }
            if (cx <= x && cy <= y && cx + cw >= x && cy + ch >= y) {
                onClient = true;
                sx = cx;
                sy = cy;
                ex = cx + cw;
                ey = cy + ch;
                break;
            }
        }
    }

    function save(): void {
        const geom = `${screen.x + Math.ceil(rsx)},${screen.y + Math.ceil(rsy)} ${Math.floor(sw)}x${Math.floor(sh)}`;
        const scriptsDir = Quickshell.shellDir + "/scripts/areaPicker";

        if (loader.mode === "ocr") {
            Quickshell.execDetached(["sh", scriptsDir + "/region_ocr.sh", geom]);
            closeAnim.start();
        } else if (loader.mode === "lens") {
            Quickshell.execDetached(["sh", scriptsDir + "/region_search.sh", geom]);
            closeAnim.start();
        } else {
            const tmpfile = Qt.resolvedUrl(`/tmp/caelestia-picker-${Quickshell.processId}-${Date.now()}.png`);
            CUtils.saveItem(screencopy, tmpfile, Qt.rect(Math.ceil(rsx), Math.ceil(rsy), Math.floor(sw), Math.floor(sh)), path => {
                if (root.loader.clipboardOnly) {
                    Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < " + path]);
                    Quickshell.execDetached(["notify-send", "-a", "caelestia-cli", "-i", path, "Screenshot taken", "Screenshot copied to clipboard"]);
                } else {
                    Quickshell.execDetached(["swappy", "-f", path]);
                }
                closeAnim.start();
            });
        }
    }

    onClientsChanged: checkClientRects(mouseX, mouseY)

    anchors.fill: parent
    opacity: 0
    hoverEnabled: true
    cursorShape: Qt.BlankCursor

    Component.onCompleted: {
        if (typeof Hypr !== "undefined" && Hypr.extras) {
            Hypr.extras.refreshOptions();
        }

        if (loader.freeze)
            clients = clients;

        opacity = 1;

        const c = clients[0];
        if (c) {
            if (typeof Niri !== "undefined" && Niri.niriAvailable) {
                const geom = getWindowGeometry(c);
                if (geom) {
                    onClient = true;
                    sx = geom.x;
                    sy = geom.y;
                    ex = geom.x + geom.w;
                    ey = geom.y + geom.h;
                } else {
                    sx = screen.width / 2 - 100;
                    sy = screen.height / 2 - 100;
                    ex = screen.width / 2 + 100;
                    ey = screen.height / 2 + 100;
                }
            } else if (c.lastIpcObject) {
                const cx = c.lastIpcObject.at[0] - screen.x;
                const cy = c.lastIpcObject.at[1] - screen.y;
                onClient = true;
                sx = cx;
                sy = cy;
                ex = cx + c.lastIpcObject.size[0];
                ey = cy + c.lastIpcObject.size[1];
            }
        } else {
            sx = screen.width / 2 - 100;
            sy = screen.height / 2 - 100;
            ex = screen.width / 2 + 100;
            ey = screen.height / 2 + 100;
        }
    }

    onPressed: event => {
        ssx = event.x;
        ssy = event.y;
    }

    onReleased: {
        if (closeAnim.running)
            return;

        if (root.loader.mode === "ocr" || root.loader.mode === "lens") {
            save();
        } else if (root.loader.freeze) {
            save();
        } else {
            overlay.visible = border.visible = false;
            screencopy.visible = false;
            screencopy.active = true;
        }
    }

    onPositionChanged: event => {
        cursorX = event.x;
        cursorY = event.y;
        const x = event.x;
        const y = event.y;

        if (pressed) {
            onClient = false;
            sx = ssx;
            sy = ssy;
            ex = x;
            ey = y;
        } else {
            checkClientRects(x, y);
        }
    }

    focus: true
    Keys.onEscapePressed: closeAnim.start()

    SequentialAnimation {
        id: closeAnim

        PropertyAction {
            target: root.loader
            property: "closing"
            value: true
        }
        ParallelAnimation {
            Anim {
                target: root
                property: "opacity"
                to: 0
                type: Anim.StandardLarge
            }
            Anim {
                target: root
                properties: "rsx,rsy"
                to: 0
            }
            Anim {
                target: root
                property: "sw"
                to: root.screen.width
            }
            Anim {
                target: root
                property: "sh"
                to: root.screen.height
            }
        }
        PropertyAction {
            target: root.loader
            property: "activeAsync"
            value: false
        }
    }

    Loader {
        id: screencopy

        asynchronous: true
        anchors.fill: parent

        active: root.loader.freeze

        sourceComponent: ScreencopyView {
            captureSource: root.screen

            onHasContentChanged: {
                if (hasContent && !root.loader.freeze) {
                    overlay.visible = border.visible = true;
                    root.save();
                }
            }
        }
    }

    Item {
        id: cursorIndicator
        x: root.cursorX - crosshair.width / 2
        y: root.cursorY - crosshair.height / 2
        z: 100
        visible: !root.pressed

        Rectangle {
            id: crosshair
            width: 24
            height: 24
            color: "transparent"

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 2
                height: parent.height
                color: Colours.palette.m3onSurface
                opacity: 0.9
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 2
                color: Colours.palette.m3onSurface
                opacity: 0.9
            }
        }

        StyledRect {
            x: crosshair.width / 2 + 8
            y: crosshair.height / 2 + 8
            radius: Tokens.rounding.full
            color: {
                switch (root.loader.mode) {
                case "ocr": return Colours.palette.m3tertiaryContainer;
                case "lens": return Colours.palette.m3secondaryContainer;
                default: return Colours.palette.m3primaryContainer;
                }
            }

            implicitWidth: badgeRow.implicitWidth + Tokens.padding.medium * 2
            implicitHeight: badgeRow.implicitHeight + Tokens.padding.extraSmall * 2

            Row {
                id: badgeRow
                anchors.centerIn: parent
                spacing: Tokens.spacing.extraSmall

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        switch (root.loader.mode) {
                        case "ocr": return "document_scanner";
                        case "lens": return "image_search";
                        default: return "crop";
                        }
                    }
                    color: {
                        switch (root.loader.mode) {
                        case "ocr": return Colours.palette.m3onTertiaryContainer;
                        case "lens": return Colours.palette.m3onSecondaryContainer;
                        default: return Colours.palette.m3onPrimaryContainer;
                        }
                    }
                    size: Tokens.font.size.labelLarge
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        switch (root.loader.mode) {
                        case "ocr": return qsTr("OCR");
                        case "lens": return qsTr("Lens");
                        default: return qsTr("Screenshot");
                        }
                    }
                    color: {
                        switch (root.loader.mode) {
                        case "ocr": return Colours.palette.m3onTertiaryContainer;
                        case "lens": return Colours.palette.m3onSecondaryContainer;
                        default: return Colours.palette.m3onPrimaryContainer;
                        }
                    }
                    font.pointSize: Tokens.font.size.labelMedium
                    font.bold: true
                }
            }
        }
    }

    StyledRect {
        id: overlay

        anchors.fill: parent
        color: Colours.palette.m3secondaryContainer
        opacity: 0.3

        layer.enabled: true
        layer.effect: Mask {
            maskSource: selectionWrapper
            maskInverted: true
        }
    }

    Item {
        id: selectionWrapper

        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            id: selectionRect

            radius: root.realRounding
            x: root.rsx
            y: root.rsy
            implicitWidth: root.sw
            implicitHeight: root.sh
        }
    }

    Rectangle {
        id: border

        color: "transparent"
        radius: root.realRounding > 0 ? root.realRounding + root.realBorderWidth : 0
        border.width: root.realBorderWidth
        border.color: Colours.palette.m3primary

        x: selectionRect.x - root.realBorderWidth
        y: selectionRect.y - root.realBorderWidth
        implicitWidth: selectionRect.implicitWidth + root.realBorderWidth * 2
        implicitHeight: selectionRect.implicitHeight + root.realBorderWidth * 2

        Behavior on border.color {
            CAnim {}
        }
    }

    Behavior on opacity {
        Anim {
            type: Anim.StandardLarge
        }
    }

    Behavior on rsx {
        enabled: !root.pressed
        Anim {}
    }

    Behavior on rsy {
        enabled: !root.pressed
        Anim {}
    }

    Behavior on sw {
        enabled: !root.pressed
        Anim {}
    }

    Behavior on sh {
        enabled: !root.pressed
        Anim {}
    }
}
