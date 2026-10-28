pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.utils
import Caelestia.Config
import Caelestia.Internal
import Quickshell.Widgets
import QtQuick

Item {
    id: root

    required property var workspace
    required property int workspaceId
    required property string outputName
    required property int focusedWindowId
    required property bool isWsFocused

    // Inner cross-axis width inside the 40px vertical bar pill (with fallback per modules/bar/AGENTS.md)
    readonly property int stripWidth: Math.max(24, (Tokens.sizes.bar.innerWidth ?? 40) - (Tokens.padding.extraSmall ?? 4) * 3)
    // Pixel length along the bar's vertical axis corresponding to 1.0 full monitor width
    readonly property real viewportUnitPx: 44
    readonly property real columnGapPx: 2

    property var ribbonColumns: []
    property var floatingWindows: []
    property real monitorLogicalWidth: 1920
    property real totalRibbonLogicalWidth: 1920
    property real viewportStartLogical: 0
    property real viewportSpanLogical: 1920
    property bool hasOffscreenLeft: false
    property bool hasOffscreenRight: false

    // Drag-to-reorder state
    property int dragColumnIdx: -1
    property int dropTargetIdx: -1
    property real dragCurrentY: 0

    function rebuildRibbon(): void {
        if (root.workspaceId < 0) {
            root.ribbonColumns = [];
            root.floatingWindows = [];
            root.hasOffscreenLeft = false;
            root.hasOffscreenRight = false;
            return;
        }

        const outInfo = Niri.outputs ? Niri.outputs[root.outputName] : null;
        const monWidth = Math.max(320, Number(outInfo?.logical?.width ?? 1920));
        root.monitorLogicalWidth = monWidth;

        const rawWins = Niri.getWindowsByWorkspaceId(root.workspaceId) || [];
        const colMap = {};
        const colKeys = [];
        const floatList = [];

        for (let i = 0; i < rawWins.length; i++) {
            const w = rawWins[i];
            if (!w)
                continue;
            const pos = w.layout?.pos_in_scrolling_layout;
            if (w.is_floating || !Array.isArray(pos) || pos.length < 2) {
                floatList.push(w);
                continue;
            }
            const colIdx = Number(pos[0]);
            const rowIdx = Number(pos[1]);
            if (!colMap[colIdx]) {
                colMap[colIdx] = {
                    columnIndex: colIdx,
                    rawWindows: []
                };
                colKeys.push(colIdx);
            }
            colMap[colIdx].rawWindows.push({
                row: rowIdx,
                win: w
            });
        }

        colKeys.sort((a, b) => a - b);

        const cols = [];
        let cursorLogicalX = 0;
        let cursorPxY = 0;
        let cameraStartSample = NaN;
        let focusedColStart = NaN;
        let focusedColWidth = monWidth * 0.5;

        const globalFocusId = Number(Niri.focusedWindowId || root.focusedWindowId || -1);

        for (let c = 0; c < colKeys.length; c++) {
            const key = colKeys[c];
            const entry = colMap[key];
            entry.rawWindows.sort((a, b) => a.row - b.row);

            const wins = entry.rawWindows.map(rw => rw.win);
            let colLogicalW = 0;
            let sampleViewX = NaN;
            let colHasFocus = false;

            for (let k = 0; k < wins.length; k++) {
                const lw = wins[k].layout;
                const tileW = Array.isArray(lw?.tile_size) ? Number(lw.tile_size[0]) : 0;
                const winW = Array.isArray(lw?.window_size) ? Number(lw.window_size[0]) : 0;
                const candidateW = tileW > 0 ? tileW : winW;
                if (candidateW > colLogicalW)
                    colLogicalW = candidateW;

                if (isNaN(sampleViewX) && Array.isArray(lw?.tile_pos_in_workspace_view) && lw.tile_pos_in_workspace_view.length >= 1)
                    sampleViewX = Number(lw.tile_pos_in_workspace_view[0]);

                if (Number(wins[k].id) === globalFocusId)
                    colHasFocus = true;
            }

            if (colLogicalW <= 0)
                colLogicalW = monWidth * 0.5;

            const widthProportion = Math.max(0.18, Math.min(1.0, colLogicalW / monWidth));
            const lengthPx = Math.max(12, Math.round(widthProportion * root.viewportUnitPx));

            if (!isNaN(sampleViewX) && isNaN(cameraStartSample))
                cameraStartSample = cursorLogicalX - sampleViewX;

            if (colHasFocus) {
                focusedColStart = cursorLogicalX;
                focusedColWidth = colLogicalW;
            }

            cols.push({
                seqIndex: c,
                columnIndex: key,
                logicalX: cursorLogicalX,
                logicalWidth: colLogicalW,
                widthProportion: widthProportion,
                yPx: cursorPxY,
                heightPx: lengthPx,
                hasFocus: colHasFocus,
                isStacked: wins.length > 1,
                primaryWindowId: Number(wins[0].id),
                windows: wins
            });

            cursorLogicalX += colLogicalW;
            cursorPxY += lengthPx + (c < colKeys.length - 1 ? root.columnGapPx : 0);
        }

        const totalLogical = Math.max(monWidth, cursorLogicalX);
        let camStart = 0;
        if (!isNaN(cameraStartSample)) {
            camStart = cameraStartSample;
        } else if (!isNaN(focusedColStart)) {
            // Center active viewport on focused column when workspace is inactive / off-screen
            camStart = focusedColStart + (focusedColWidth - monWidth) / 2;
            camStart = Math.max(0, Math.min(Math.max(0, cursorLogicalX - monWidth), camStart));
        }

        const camEnd = camStart + monWidth;
        const eps = monWidth * 0.04;

        for (let c = 0; c < cols.length; c++) {
            const col = cols[c];
            const colStart = col.logicalX;
            const colEnd = col.logicalX + col.logicalWidth;
            col.inViewport = (colEnd > camStart + eps) && (colStart < camEnd - eps);
        }

        root.totalRibbonLogicalWidth = totalLogical;
        root.viewportStartLogical = camStart;
        root.viewportSpanLogical = monWidth;
        root.hasOffscreenLeft = cols.length > 0 && (camStart > eps);
        root.hasOffscreenRight = cols.length > 0 && (cursorLogicalX > camEnd + eps);
        root.ribbonColumns = cols;
        root.floatingWindows = floatList;
    }

    // Map logical ribbon coordinate [0 .. cursorLogicalX] onto pixel coordinate along stripContainer
    function logicalToStripPx(logicalPos: real): real {
        const cols = root.ribbonColumns;
        if (!cols || cols.length === 0)
            return 0;

        const first = cols[0];
        const last = cols[cols.length - 1];
        const ribbonEndLogical = last.logicalX + last.logicalWidth;
        const stripEndPx = last.yPx + last.heightPx;

        if (logicalPos <= 0)
            return 0;
        if (logicalPos >= ribbonEndLogical)
            return stripEndPx;

        for (let i = 0; i < cols.length; i++) {
            const c = cols[i];
            const cEnd = c.logicalX + c.logicalWidth;
            if (logicalPos >= c.logicalX && logicalPos <= cEnd) {
                const frac = c.logicalWidth > 0 ? (logicalPos - c.logicalX) / c.logicalWidth : 0;
                return c.yPx + frac * c.heightPx;
            }
        }
        return stripEndPx;
    }

    readonly property real stripContentHeight: {
        const cols = root.ribbonColumns;
        if (!cols || cols.length === 0)
            return 0;
        const last = cols[cols.length - 1];
        return last.yPx + last.heightPx;
    }

    readonly property real viewportBoxY: Math.max(0, logicalToStripPx(root.viewportStartLogical))
    readonly property real viewportBoxBottom: Math.min(
        stripContentHeight,
        logicalToStripPx(root.viewportStartLogical + root.viewportSpanLogical)
    )
    readonly property real viewportBoxHeight: Math.max(
        10,
        viewportBoxBottom > viewportBoxY ? (viewportBoxBottom - viewportBoxY) : Math.min(stripContentHeight, root.viewportUnitPx)
    )

    Component.onCompleted: rebuildRibbon()
    onWorkspaceIdChanged: rebuildRibbon()
    onOutputNameChanged: rebuildRibbon()
    onFocusedWindowIdChanged: rebuildRibbon()

    Connections {
        target: NiriIpc
        function onWindowsChanged(): void {
            root.rebuildRibbon();
        }
        function onLayoutChanged(): void {
            root.rebuildRibbon();
        }
        function onViewportChanged(): void {
            root.rebuildRibbon();
        }
        function onFocusedWindowChanged(): void {
            root.rebuildRibbon();
        }
        function onOutputsChanged(): void {
            root.rebuildRibbon();
        }
    }

    implicitWidth: stripWidth
    implicitHeight: mainColumn.implicitHeight

    // Wheel scrolling over the ribbon mini-map navigates columns horizontally in Niri
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        property real wheelAccum: 0

        onWheel: (event) => {
            event.accepted = true;
            const delta = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y)
                ? event.angleDelta.x
                : event.angleDelta.y;
            wheelAccum += delta;
            while (wheelAccum >= 120) {
                wheelAccum -= 120;
                if (!root.isWsFocused && root.workspaceId > 0)
                    Niri.switchToWorkspaceById(root.workspaceId);
                Niri.focusColumnLeft();
            }
            while (wheelAccum <= -120) {
                wheelAccum += 120;
                if (!root.isWsFocused && root.workspaceId > 0)
                    Niri.switchToWorkspaceById(root.workspaceId);
                Niri.focusColumnRight();
            }
        }
    }

    Column {
        id: mainColumn
        width: root.stripWidth
        spacing: 3

        // Top peek bar when off-screen columns exist to the left of the active viewport
        Rectangle {
            width: root.stripWidth - 6
            height: root.hasOffscreenLeft ? 3 : 0
            visible: height > 0
            anchors.horizontalCenter: parent.horizontalCenter
            radius: 1.5
            color: Colours.palette.m3tertiary
            opacity: 0.85

            Behavior on height {
                Anim { type: Anim.FastSpatial }
            }
        }

        // Main continuous proportional column ribbon strip
        Item {
            id: stripContainer
            width: root.stripWidth
            height: root.stripContentHeight
            visible: root.ribbonColumns.length > 0

            // Columns repeater
            Repeater {
                model: root.ribbonColumns

                delegate: Item {
                    id: colDelegate
                    required property var modelData
                    required property int index

                    x: 2
                    y: modelData.yPx
                    width: root.stripWidth - 4
                    height: modelData.heightPx
                    opacity: root.dragColumnIdx === index
                        ? 0.45
                        : (modelData.inViewport ? 1.0 : 0.46)

                    Behavior on y {
                        enabled: root.dragColumnIdx < 0
                        Anim { type: Anim.FastSpatial }
                    }
                    Behavior on height {
                        Anim { type: Anim.FastSpatial }
                    }
                    Behavior on opacity {
                        Anim { type: Anim.DefaultEffects }
                    }

                    // Stacked/tabbed tiles inside this column split across cross-axis width with crisp dividers
                    Row {
                        anchors.fill: parent
                        spacing: 1.5

                        Repeater {
                            model: colDelegate.modelData.windows

                            delegate: StyledRect {
                                id: tilePill
                                required property var modelData
                                required property int index

                                readonly property int winCount: Math.max(1, colDelegate.modelData.windows.length)
                                readonly property bool tileFocused: Number(modelData.id) === Number(Niri.focusedWindowId)
                                readonly property bool useDesktopIcon: GlobalConfig.bar?.workspaces?.windowIconImage ?? false

                                width: (colDelegate.width - (winCount - 1) * 1.5) / winCount
                                height: colDelegate.height
                                radius: winCount > 1 ? 3 : 5
                                clip: true

                                color: tileFocused
                                    ? Colours.palette.m3primaryContainer
                                    : (colDelegate.modelData.inViewport
                                        ? Colours.palette.m3surfaceContainerHighest
                                        : Colours.palette.m3surfaceContainerHigh)

                                border.width: tileFocused ? 1 : 0
                                border.color: Colours.palette.m3primary

                                // App icon (shown when tile has room)
                                Loader {
                                    anchors.centerIn: parent
                                    active: tilePill.width >= 10 && tilePill.height >= 12
                                    sourceComponent: tilePill.useDesktopIcon ? appImgComp : matIconComp

                                    Component {
                                        id: appImgComp
                                        IconImage {
                                            implicitSize: Math.min(tilePill.width - 3, tilePill.height - 3, 14)
                                            source: Icons.getAppIcon(tilePill.modelData.app_id ?? "", "application-x-executable")
                                        }
                                    }

                                    Component {
                                        id: matIconComp
                                        MaterialIcon {
                                            text: Icons.getAppCategoryIcon(tilePill.modelData.app_id ?? "", "web_asset")
                                            font.pointSize: Math.max(7, Math.min(10, Math.floor(Math.min(tilePill.width, tilePill.height) * 0.48)))
                                            color: tilePill.tileFocused
                                                ? Colours.palette.m3onPrimaryContainer
                                                : Colours.palette.m3onSurfaceVariant
                                        }
                                    }
                                }

                                StateLayer {
                                    id: tileMouse
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                                    property bool dragging: false

                                    onPressAndHold: (event) => {
                                        if (event.button !== Qt.LeftButton)
                                            return;
                                        dragging = true;
                                        root.dragColumnIdx = colDelegate.index;
                                        root.dropTargetIdx = colDelegate.index;
                                        const mapped = mapToItem(stripContainer, event.x, event.y);
                                        root.dragCurrentY = mapped.y;
                                    }

                                    onPositionChanged: (event) => {
                                        if (!dragging)
                                            return;
                                        const mapped = mapToItem(stripContainer, event.x, event.y);
                                        root.dragCurrentY = Math.max(0, Math.min(stripContainer.height, mapped.y));

                                        let bestIdx = root.ribbonColumns.length - 1;
                                        for (let c = 0; c < root.ribbonColumns.length; c++) {
                                            const col = root.ribbonColumns[c];
                                            if (root.dragCurrentY < col.yPx + col.heightPx / 2) {
                                                bestIdx = c;
                                                break;
                                            }
                                        }
                                        root.dropTargetIdx = bestIdx;
                                    }

                                    onReleased: (event) => {
                                        if (!dragging)
                                            return;
                                        event.accepted = true;
                                        const fromIdx = root.dragColumnIdx;
                                        const toIdx = root.dropTargetIdx;
                                        dragging = false;
                                        root.dragColumnIdx = -1;
                                        root.dropTargetIdx = -1;

                                        if (fromIdx >= 0 && toIdx >= 0 && fromIdx !== toIdx) {
                                            const winId = Number(tilePill.modelData.id);
                                            Niri.reorderColumn(winId, toIdx + 1);
                                        }
                                    }

                                    onCanceled: {
                                        dragging = false;
                                        root.dragColumnIdx = -1;
                                        root.dropTargetIdx = -1;
                                    }

                                    function onClicked(event): void {
                                        if (dragging)
                                            return;
                                        const targetId = Number(tilePill.modelData.id);
                                        if (event.button === Qt.MiddleButton) {
                                            Niri.closeWindow(targetId);
                                            return;
                                        }
                                        if (targetId === Number(Niri.focusedWindowId)) {
                                            // Click on already-focused column centers it on the Niri ribbon
                                            Niri.centerColumn();
                                        } else {
                                            Niri.focusWindow(targetId);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Stacked-tabs indicator badge on top edge when >1 window shares this column
                    Rectangle {
                        visible: colDelegate.modelData.isStacked
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 1
                        width: Math.min(parent.width - 6, 14)
                        height: 2
                        radius: 1
                        color: Colours.palette.m3tertiary
                        opacity: 0.9
                    }
                }
            }

            // Glowing Active Viewport Highlight Frame (tracks Niri camera scroll position)
            Rectangle {
                id: viewportFrame
                z: 10
                x: 0
                y: root.viewportBoxY
                width: root.stripWidth
                height: root.viewportBoxHeight
                radius: 6
                color: root.isWsFocused
                    ? Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.10)
                    : "transparent"
                border.width: root.isWsFocused ? 2 : 1
                border.color: root.isWsFocused ? Colours.palette.m3primary : Colours.palette.m3outline

                Behavior on y {
                    Anim { type: Anim.FastSpatial }
                }
                Behavior on height {
                    Anim { type: Anim.FastSpatial }
                }
            }

            // Drag insertion marker line
            Rectangle {
                z: 20
                visible: root.dragColumnIdx >= 0 && root.dropTargetIdx >= 0
                x: 1
                width: root.stripWidth - 2
                height: 3
                radius: 1.5
                color: Colours.palette.m3tertiary
                y: {
                    if (root.dropTargetIdx < 0 || root.dropTargetIdx >= root.ribbonColumns.length)
                        return 0;
                    const targetCol = root.ribbonColumns[root.dropTargetIdx];
                    return root.dropTargetIdx > root.dragColumnIdx
                        ? (targetCol.yPx + targetCol.heightPx - 1)
                        : Math.max(0, targetCol.yPx - 2);
                }
            }
        }

        // Bottom peek bar when off-screen columns exist to the right of the active viewport
        Rectangle {
            width: root.stripWidth - 6
            height: root.hasOffscreenRight ? 3 : 0
            visible: height > 0
            anchors.horizontalCenter: parent.horizontalCenter
            radius: 1.5
            color: Colours.palette.m3tertiary
            opacity: 0.85

            Behavior on height {
                Anim { type: Anim.FastSpatial }
            }
        }

        // Floating window chips (if workspace also has floating windows outside scrolling layout)
        Column {
            width: root.stripWidth
            spacing: 2
            visible: root.floatingWindows.length > 0

            Repeater {
                model: root.floatingWindows

                delegate: StyledRect {
                    required property var modelData
                    width: root.stripWidth - 6
                    height: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: 6
                    readonly property bool floatFocused: Number(modelData.id) === Number(Niri.focusedWindowId)
                    color: floatFocused ? Colours.palette.m3tertiaryContainer : Colours.palette.m3surfaceContainerHigh
                    border.width: 1
                    border.color: floatFocused ? Colours.palette.m3tertiary : Colours.palette.m3outlineVariant

                    StateLayer {
                        function onClicked(): void {
                            Niri.focusWindow(Number(modelData.id));
                        }
                    }
                }
            }
        }
    }
}
