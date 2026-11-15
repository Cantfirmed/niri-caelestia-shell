pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

MouseArea {
    id: root

    required property LazyLoader loader
    required property ShellScreen screen

    property int borderWidth: 2
    property int rounding: 8

    property string captureType: root.loader.captureType || "area"
    property var hoveredClient: null
    property bool onClient: false
    property bool openSwappy: root.loader.openSwappy

    property real realBorderWidth: onClient ? borderWidth : 2
    property real realRounding: onClient ? rounding : 0

    property real ssx: 0
    property real ssy: 0

    property real sx: 0
    property real sy: 0
    property real ex: 0
    property real ey: 0

    property real rsx: Math.min(sx, ex)
    property real rsy: Math.min(sy, ey)
    property real sw: Math.abs(sx - ex)
    property real sh: Math.abs(sy - ey)

    property real cursorX: 0
    property real cursorY: 0

    property var clients: {
        const wsWindows = Compositor.getActiveWorkspaceWindows();
        return wsWindows.slice().sort((a, b) => {
            const aPos = a.layout?.pos_in_scrolling_layout || [0, 0];
            const bPos = b.layout?.pos_in_scrolling_layout || [0, 0];
            if (aPos[0] !== bPos[0]) return aPos[0] - bPos[0];
            return aPos[1] - bPos[1];
        });
    }

    function inToolbar(x: real, y: real): bool {
        if (!toolbar || !toolbar.visible) return false;
        return x >= toolbar.x && x <= toolbar.x + toolbar.width &&
               y >= toolbar.y && y <= toolbar.y + toolbar.height;
    }

    function getWindowGeometry(window) {
        if (!window?.layout) return null;

        // Direct Niri viewport coordinates
        if (window.layout.tile_pos_in_workspace_view && window.layout.window_size) {
            const tilePos = window.layout.tile_pos_in_workspace_view;
            const offset = window.layout.window_offset_in_tile ?? [0, 0];
            const size = window.layout.window_size;
            const x = tilePos[0] + offset[0];
            const y = tilePos[1] + offset[1];
            const w = size[0];
            const h = size[1];
            if (x + w > 0 && x < screen.width && y + h > 0 && y < screen.height) {
                return { x, y, w, h };
            }
        }

        // Fallback calculation for scrolling layout
        if (!window.layout.window_size) return null;
        const size = window.layout.window_size;
        const pos = window.layout.pos_in_scrolling_layout ?? [0, 0];
        const focusedWindow = Compositor.focusedWindow;
        if (!focusedWindow?.layout?.pos_in_scrolling_layout) {
            return {
                x: Math.max(0, (screen.width - size[0]) / 2),
                y: Math.max(0, (screen.height - size[1]) / 2),
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
            const geom = getWindowGeometry(client);
            if (!geom) continue;
            if (geom.x <= x && geom.y <= y && geom.x + geom.w >= x && geom.y + geom.h >= y) {
                hoveredClient = client;
                onClient = true;
                sx = geom.x;
                sy = geom.y;
                ex = geom.x + geom.w;
                ey = geom.y + geom.h;
                return;
            }
        }
        hoveredClient = null;
        onClient = false;
    }

    function setCaptureType(type: string): void {
        root.captureType = type;
        root.loader.captureType = type;
        if (type === "screen") {
            onClient = false;
            hoveredClient = null;
            sx = 0;
            sy = 0;
            ex = screen ? screen.width : 0;
            ey = screen ? screen.height : 0;
        } else if (type === "window") {
            checkClientRects(cursorX, cursorY);
            if (!onClient) {
                const focused = Compositor.focusedWindow;
                const geom = focused ? getWindowGeometry(focused) : null;
                if (geom) {
                    sx = geom.x;
                    sy = geom.y;
                    ex = geom.x + geom.w;
                    ey = geom.y + geom.h;
                    onClient = true;
                    hoveredClient = focused;
                } else if (clients.length > 0) {
                    const geom0 = getWindowGeometry(clients[0]);
                    if (geom0) {
                        sx = geom0.x;
                        sy = geom0.y;
                        ex = geom0.x + geom0.w;
                        ey = geom0.y + geom0.h;
                        onClient = true;
                        hoveredClient = clients[0];
                    }
                }
            }
        } else {
            // Area mode
            onClient = false;
            hoveredClient = null;
            sx = 0;
            sy = 0;
            ex = 0;
            ey = 0;
        }
    }

    function triggerCapture(): void {
        if (root.loader.freeze) {
            save();
        } else {
            overlay.visible = false;
            border.visible = false;
            if (cursorIndicator) cursorIndicator.visible = false;
            if (windowInfoBadge) windowInfoBadge.visible = false;
            if (screenHintBadge) screenHintBadge.visible = false;
            if (toolbar) toolbar.visible = false;
            screencopy.visible = false;
            screencopy.active = true;
        }
    }

    function captureCurrent(): void {
        if (root.captureType === "screen") {
            sx = 0;
            sy = 0;
            ex = screen.width;
            ey = screen.height;
            triggerCapture();
        } else if (root.captureType === "window") {
            if (!onClient) {
                const focused = Compositor.focusedWindow;
                const geom = focused ? getWindowGeometry(focused) : null;
                if (geom) {
                    sx = geom.x;
                    sy = geom.y;
                    ex = geom.x + geom.w;
                    ey = geom.y + geom.h;
                    onClient = true;
                    hoveredClient = focused;
                }
            }
            if (sw > 10 && sh > 10) {
                triggerCapture();
            }
        } else {
            // Area mode
            if (sw >= 10 && sh >= 10) {
                triggerCapture();
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
            let destFile;
            if (root.loader.clipboardOnly) {
                destFile = Qt.resolvedUrl(`/tmp/caelestia-picker-${Quickshell.processId}-${Date.now()}.png`);
            } else {
                const home = Quickshell.env("HOME") || "/home/patrick";
                const now = new Date();
                const pad = n => n.toString().padStart(2, "0");
                const yyyy = now.getFullYear();
                const mm = pad(now.getMonth() + 1);
                const dd = pad(now.getDate());
                const hh = pad(now.getHours());
                const min = pad(now.getMinutes());
                const ss = pad(now.getSeconds());
                const filename = `Screenshot from ${yyyy}-${mm}-${dd} ${hh}-${min}-${ss}.png`;
                destFile = Qt.resolvedUrl(`file://${home}/Pictures/Screenshots/${filename}`);
            }

            const cropRect = Qt.rect(Math.ceil(rsx), Math.ceil(rsy), Math.floor(sw), Math.floor(sh));
            CUtils.saveItem(screencopy, destFile, cropRect, path => {
                Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < " + path]);
                const notifMsg = root.loader.clipboardOnly
                    ? Tr.tr("Screenshot copied to clipboard")
                    : Tr.tr("Saved to Screenshots & copied to clipboard");
                Quickshell.execDetached(["notify-send", "-a", "caelestia-cli", "-e", "-t", "3000", "-h", "boolean:transient:true", "-i", path, Tr.tr("Screenshot taken"), notifMsg]);
                if (root.openSwappy) {
                    Quickshell.execDetached(["swappy", "-f", path]);
                }
                closeAnim.start();
            });
        }
    }

    onClientsChanged: {
        if (captureType === "window") {
            checkClientRects(cursorX, cursorY);
        }
    }

    anchors.fill: parent
    opacity: 0
    hoverEnabled: true
    cursorShape: {
        if (inToolbar(cursorX, cursorY)) return Qt.ArrowCursor;
        if (captureType === "window") return onClient ? Qt.PointingHandCursor : Qt.ArrowCursor;
        if (captureType === "screen") return Qt.PointingHandCursor;
        return Qt.BlankCursor;
    }

    Component.onCompleted: {
        if (loader.freeze)
            clients = clients;

        opacity = 1;
        setCaptureType(root.loader.captureType || "area");
    }

    onPressed: event => {
        if (inToolbar(event.x, event.y)) return;
        ssx = event.x;
        ssy = event.y;
    }

    onPositionChanged: event => {
        cursorX = event.x;
        cursorY = event.y;
        if (inToolbar(event.x, event.y)) return;

        if (pressed) {
            if (root.captureType === "area") {
                onClient = false;
                sx = ssx;
                sy = ssy;
                ex = event.x;
                ey = event.y;
            }
        } else {
            if (root.captureType === "window") {
                checkClientRects(event.x, event.y);
            }
        }
    }

    onReleased: event => {
        if (closeAnim.running) return;
        if (inToolbar(event.x, event.y)) return;

        if (root.loader.mode === "ocr" || root.loader.mode === "lens") {
            if (sw > 5 && sh > 5) {
                save();
            }
            return;
        }

        if (root.captureType === "screen") {
            sx = 0;
            sy = 0;
            ex = screen.width;
            ey = screen.height;
            triggerCapture();
        } else if (root.captureType === "window") {
            if (onClient && sw > 10 && sh > 10) {
                triggerCapture();
            }
        } else {
            // Area mode: trigger if dragged at least a small box
            if (sw >= 10 && sh >= 10) {
                triggerCapture();
            }
        }
    }

    focus: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            closeAnim.start();
            event.accepted = true;
        } else if (event.key === Qt.Key_1 || event.key === Qt.Key_A || event.key === Qt.Key_R) {
            setCaptureType("area");
            event.accepted = true;
        } else if (event.key === Qt.Key_2 || event.key === Qt.Key_W) {
            setCaptureType("window");
            event.accepted = true;
        } else if (event.key === Qt.Key_3 || event.key === Qt.Key_F || event.key === Qt.Key_S) {
            setCaptureType("screen");
            event.accepted = true;
        } else if (event.key === Qt.Key_C) {
            root.loader.clipboardOnly = !root.loader.clipboardOnly;
            event.accepted = true;
        } else if (event.key === Qt.Key_E) {
            root.openSwappy = !root.openSwappy;
            root.loader.openSwappy = root.openSwappy;
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            captureCurrent();
            event.accepted = true;
        }
    }

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

    // Cursor indicator for Area mode
    Item {
        id: cursorIndicator

        x: root.cursorX - crosshair.width / 2
        y: root.cursorY - crosshair.height / 2
        z: 100
        visible: root.captureType === "area" && !root.inToolbar(root.cursorX, root.cursorY)

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
                        default: return root.pressed ? "straighten" : "crop";
                        }
                    }
                    color: {
                        switch (root.loader.mode) {
                        case "ocr": return Colours.palette.m3onTertiaryContainer;
                        case "lens": return Colours.palette.m3onSecondaryContainer;
                        default: return Colours.palette.m3onPrimaryContainer;
                        }
                    }
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (root.pressed && root.sw > 0 && root.sh > 0) {
                            return `${Math.round(root.sw)} × ${Math.round(root.sh)}`;
                        }
                        switch (root.loader.mode) {
                        case "ocr": return qsTr("OCR");
                        case "lens": return qsTr("Lens");
                        default: return qsTr("Area");
                        }
                    }
                    color: {
                        switch (root.loader.mode) {
                        case "ocr": return Colours.palette.m3onTertiaryContainer;
                        case "lens": return Colours.palette.m3onSecondaryContainer;
                        default: return Colours.palette.m3onPrimaryContainer;
                        }
                    }
                    font: Tokens.font.label.builders.medium.weight(Font.Bold).build()
                }
            }
        }
    }

    // Window Info Badge for Window Mode
    Item {
        id: windowInfoBadge

        visible: root.captureType === "window" && root.onClient && !root.pressed && root.sw > 0
        x: Math.max(16, Math.min(root.screen.width - width - 16, root.rsx + 16))
        y: root.rsy > 48 ? root.rsy - height - 8 : root.rsy + 16
        z: 110

        StyledRect {
            radius: Tokens.rounding.full
            color: Colours.palette.m3surfaceContainerHigh
            border.width: 1
            border.color: Colours.palette.m3outlineVariant
            implicitWidth: winBadgeRow.implicitWidth + Tokens.padding.medium * 2
            implicitHeight: winBadgeRow.implicitHeight + Tokens.padding.small * 2

            Row {
                id: winBadgeRow
                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "web_asset"
                    fontStyle: Tokens.font.icon.small
                    color: Colours.palette.m3primary
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        const app = root.hoveredClient?.app_id || "";
                        const title = root.hoveredClient?.title || "";
                        if (app && title && !title.toLowerCase().includes(app.toLowerCase())) {
                            return `${app} — ${title}`;
                        }
                        return title || app || qsTr("Window");
                    }
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font: Tokens.font.label.medium
                    color: Colours.palette.m3onSurface
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 12
                    color: Colours.palette.m3outlineVariant
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${Math.round(root.sw)} × ${Math.round(root.sh)}`
                    font: Tokens.font.label.small
                    color: Colours.palette.m3outline
                }
            }
        }
    }

    // Screen Hint Badge for Fullscreen Mode
    StyledRect {
        id: screenHintBadge

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: toolbar.top
        anchors.bottomMargin: Tokens.spacing.medium
        visible: root.captureType === "screen" && !root.pressed
        z: 150

        radius: Tokens.rounding.full
        color: Colours.palette.m3surfaceContainerHigh
        border.width: 1
        border.color: Colours.palette.m3outlineVariant
        implicitWidth: screenHintRow.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: screenHintRow.implicitHeight + Tokens.padding.small * 2

        Row {
            id: screenHintRow
            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: "info"
                fontStyle: Tokens.font.icon.small
                color: Colours.palette.m3primary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Click anywhere or press Enter to capture entire screen")
                font: Tokens.font.label.medium
                color: Colours.palette.m3onSurface
            }
        }
    }

    // Floating Screenshot Toolbar
    StyledRect {
        id: toolbar

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.spacing.extraLarge * 2
        z: 200

        radius: Tokens.rounding.full
        color: Colours.palette.m3surfaceContainerHigh
        border.width: 1
        border.color: Colours.palette.m3outlineVariant

        implicitWidth: toolbarLayout.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: 52

        RowLayout {
            id: toolbarLayout
            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            // Mode 1: Area
            IconTextButton {
                icon: "crop"
                text: qsTr("Area")
                isToggle: true
                checked: root.captureType === "area"
                type: checked ? TextButton.Filled : TextButton.Tonal
                onClicked: root.setCaptureType("area")
            }

            // Mode 2: Window
            IconTextButton {
                icon: "web_asset"
                text: qsTr("Window")
                isToggle: true
                checked: root.captureType === "window"
                type: checked ? TextButton.Filled : TextButton.Tonal
                onClicked: root.setCaptureType("window")
            }

            // Mode 3: Fullscreen
            IconTextButton {
                icon: "fullscreen"
                text: qsTr("Fullscreen")
                isToggle: true
                checked: root.captureType === "screen"
                type: checked ? TextButton.Filled : TextButton.Tonal
                onClicked: root.setCaptureType("screen")
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 24
                color: Colours.palette.m3outlineVariant
            }

            // Clipboard Only Toggle
            IconButton {
                icon: root.loader.clipboardOnly ? "content_paste" : "save"
                isToggle: true
                checked: root.loader.clipboardOnly
                type: checked ? IconButton.Filled : IconButton.Tonal
                onClicked: root.loader.clipboardOnly = !root.loader.clipboardOnly
            }

            // Swappy Edit Toggle
            IconButton {
                icon: "edit"
                isToggle: true
                checked: root.openSwappy
                type: checked ? IconButton.Filled : IconButton.Tonal
                onClicked: {
                    root.openSwappy = !root.openSwappy;
                    root.loader.openSwappy = root.openSwappy;
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 24
                color: Colours.palette.m3outlineVariant
            }

            // Capture Button
            IconButton {
                icon: "photo_camera"
                type: IconButton.Filled
                onClicked: root.captureCurrent()
            }

            // Cancel Button
            IconButton {
                icon: "close"
                type: IconButton.Tonal
                onClicked: closeAnim.start()
            }
        }
    }

    StyledRect {
        id: overlay

        anchors.fill: parent
        color: Colours.palette.m3secondaryContainer
        opacity: (root.captureType === "area" && root.sw === 0 && !root.pressed) ? 0.15 : 0.3

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
        visible: root.sw > 0 && root.sh > 0
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
