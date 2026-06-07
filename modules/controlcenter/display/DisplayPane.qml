pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.services
import qs.config
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import Caelestia.Internal

Item {
    id: root

    required property Session session

    anchors.fill: parent

    property var outputsArray: []
    property var localOutputs: []
    property bool enableSnapping: true
    property bool isDragging: false
    property real frozenScale: 0.1
    property real frozenBoxCenterX: 0
    property real frozenBoxCenterY: 0

    readonly property real currentScale: {
        if (isDragging) return frozenScale;
        
        let minX = 999999;
        let maxX = -999999;
        let minY = 999999;
        let maxY = -999999;
        let activeCount = 0;

        for (let i = 0; i < localOutputs.length; i++) {
            const out = localOutputs[i];
            if (!out.active) continue;
            activeCount++;
            if (out.x < minX) minX = out.x;
            if (out.x + out.logicalWidth > maxX) maxX = out.x + out.logicalWidth;
            if (out.y < minY) minY = out.y;
            if (out.y + out.logicalHeight > maxY) maxY = out.y + out.logicalHeight;
        }

        if (activeCount === 0) return 0.1;

        const totalWidth = Math.max(1, maxX - minX);
        const totalHeight = Math.max(1, maxY - minY);
        
        const padding = 30;
        const canvasWidth = displayCanvas.width > 0 ? displayCanvas.width - 2 * padding : 200;
        const canvasHeight = displayCanvas.height > 0 ? displayCanvas.height - 2 * padding : 150;
        
        const scaleX = canvasWidth / totalWidth;
        const scaleY = canvasHeight / totalHeight;
        
        let s = Math.min(scaleX, scaleY);
        return (s <= 0 || isNaN(s)) ? 0.1 : s;
    }

    readonly property real currentBoxCenterX: {
        if (isDragging) return frozenBoxCenterX;
        
        let minX = 999999;
        let maxX = -999999;
        let activeCount = 0;

        for (let i = 0; i < localOutputs.length; i++) {
            const out = localOutputs[i];
            if (!out.active) continue;
            activeCount++;
            if (out.x < minX) minX = out.x;
            if (out.x + out.logicalWidth > maxX) maxX = out.x + out.logicalWidth;
        }

        if (activeCount === 0) return 0;
        return minX + (maxX - minX) / 2;
    }

    readonly property real currentBoxCenterY: {
        if (isDragging) return frozenBoxCenterY;
        
        let minY = 999999;
        let maxY = -999999;
        let activeCount = 0;

        for (let i = 0; i < localOutputs.length; i++) {
            const out = localOutputs[i];
            if (!out.active) continue;
            activeCount++;
            if (out.y < minY) minY = out.y;
            if (out.y + out.logicalHeight > maxY) maxY = out.y + out.logicalHeight;
        }

        if (activeCount === 0) return 0;
        return minY + (maxY - minY) / 2;
    }

    readonly property bool hasUnappliedChanges: {
        if (localOutputs.length !== outputsArray.length) return false;
        for (let i = 0; i < localOutputs.length; i++) {
            if (localOutputs[i].x !== outputsArray[i].x || localOutputs[i].y !== outputsArray[i].y) {
                return true;
            }
        }
        return false;
    }

    function initializeLocalOutputs() {
        const temp = [];
        for (let i = 0; i < root.outputsArray.length; i++) {
            const out = root.outputsArray[i];
            temp.push({
                connector: out.connector,
                name: out.name,
                logicalWidth: out.logicalWidth,
                logicalHeight: out.logicalHeight,
                x: out.x,
                y: out.y,
                scale: out.scale,
                active: out.active
            });
        }
        root.localOutputs = temp;
    }

    function freezeMapping() {
        if (!isDragging) {
            let minX = 999999;
            let maxX = -999999;
            let minY = 999999;
            let maxY = -999999;
            let activeCount = 0;

            for (let i = 0; i < localOutputs.length; i++) {
                const out = localOutputs[i];
                if (!out.active) continue;
                activeCount++;
                if (out.x < minX) minX = out.x;
                if (out.x + out.logicalWidth > maxX) maxX = out.x + out.logicalWidth;
                if (out.y < minY) minY = out.y;
                if (out.y + out.logicalHeight > maxY) maxY = out.y + out.logicalHeight;
            }

            if (activeCount === 0) return;

            const totalWidth = Math.max(1, maxX - minX);
            const totalHeight = Math.max(1, maxY - minY);
            
            const padding = 30;
            const canvasWidth = displayCanvas.width > 0 ? displayCanvas.width - 2 * padding : 200;
            const canvasHeight = displayCanvas.height > 0 ? displayCanvas.height - 2 * padding : 150;
            
            const scaleX = canvasWidth / totalWidth;
            const scaleY = canvasHeight / totalHeight;
            
            frozenScale = Math.min(scaleX, scaleY);
            if (frozenScale <= 0 || isNaN(frozenScale)) frozenScale = 0.1;
            
            frozenBoxCenterX = minX + totalWidth / 2;
            frozenBoxCenterY = minY + totalHeight / 2;
            isDragging = true;
        }
    }

    function unfreezeMapping() {
        isDragging = false;
    }

    function updateLocalPosition(idx, newX, newY) {
        const arr = [];
        for (let i = 0; i < root.localOutputs.length; i++) {
            const item = root.localOutputs[i];
            if (i === idx) {
                arr.push({
                    connector: item.connector,
                    name: item.name,
                    logicalWidth: item.logicalWidth,
                    logicalHeight: item.logicalHeight,
                    x: Math.round(newX),
                    y: Math.round(newY),
                    scale: item.scale,
                    active: item.active
                });
            } else {
                arr.push(item);
            }
        }
        root.localOutputs = arr;
    }

    function snapPosition(dragIndex, proposedX, proposedY) {
        const snapThreshold = 100; // logical pixels
        const A = root.localOutputs[dragIndex];
        let bestX = proposedX;
        let bestY = proposedY;

        for (let i = 0; i < root.localOutputs.length; i++) {
            if (i === dragIndex) continue;
            const B = root.localOutputs[i];
            if (!B.active) continue;

            const distLeft = Math.abs((proposedX + A.logicalWidth) - B.x);
            const distRight = Math.abs(proposedX - (B.x + B.logicalWidth));

            if (distLeft < snapThreshold) {
                bestX = B.x - A.logicalWidth;
                if (Math.abs(proposedY - B.y) < snapThreshold) {
                    bestY = B.y;
                } else if (Math.abs((proposedY + A.logicalHeight) - (B.y + B.logicalHeight)) < snapThreshold) {
                    bestY = B.y + B.logicalHeight - A.logicalHeight;
                } else if (Math.abs((proposedY + A.logicalHeight/2) - (B.y + B.logicalHeight/2)) < snapThreshold) {
                    bestY = B.y + (B.logicalHeight - A.logicalHeight) / 2;
                }
            } else if (distRight < snapThreshold) {
                bestX = B.x + B.logicalWidth;
                if (Math.abs(proposedY - B.y) < snapThreshold) {
                    bestY = B.y;
                } else if (Math.abs((proposedY + A.logicalHeight) - (B.y + B.logicalHeight)) < snapThreshold) {
                    bestY = B.y + B.logicalHeight - A.logicalHeight;
                } else if (Math.abs((proposedY + A.logicalHeight/2) - (B.y + B.logicalHeight/2)) < snapThreshold) {
                    bestY = B.y + (B.logicalHeight - A.logicalHeight) / 2;
                }
            }

            const distTop = Math.abs((proposedY + A.logicalHeight) - B.y);
            const distBottom = Math.abs(proposedY - (B.y + B.logicalHeight));

            if (distTop < snapThreshold) {
                bestY = B.y - A.logicalHeight;
                if (Math.abs(proposedX - B.x) < snapThreshold) {
                    bestX = B.x;
                } else if (Math.abs((proposedX + A.logicalWidth) - (B.x + B.logicalWidth)) < snapThreshold) {
                    bestX = B.x + B.logicalWidth - A.logicalWidth;
                } else if (Math.abs((proposedX + A.logicalWidth/2) - (B.x + B.logicalWidth/2)) < snapThreshold) {
                    bestX = B.x + (B.logicalWidth - A.logicalWidth) / 2;
                }
            } else if (distBottom < snapThreshold) {
                bestY = B.y + B.logicalHeight;
                if (Math.abs(proposedX - B.x) < snapThreshold) {
                    bestX = B.x;
                } else if (Math.abs((proposedX + A.logicalWidth) - (B.x + B.logicalWidth)) < snapThreshold) {
                    bestX = B.x + B.logicalWidth - A.logicalWidth;
                } else if (Math.abs((proposedX + A.logicalWidth/2) - (B.x + B.logicalWidth/2)) < snapThreshold) {
                    bestX = B.x + (B.logicalWidth - A.logicalWidth) / 2;
                }
            }
        }

        return { x: bestX, y: bestY };
    }

    function applyPositions() {
        for (let i = 0; i < localOutputs.length; i++) {
            const out = localOutputs[i];
            if (!out.active) continue;
            root.runCmd("niri msg output " + out.connector + " position " + out.x + " " + out.y);
        }
    }

    function updateOutputs() {
        const res = [];
        const outputs = Niri.outputs;
        if (!outputs) {
            root.outputsArray = res;
            root.initializeLocalOutputs();
            return;
        }
        
        for (const connector in outputs) {
            const out = outputs[connector];
            const currentModeIdx = out.current_mode;
            const currentMode = out.modes && out.modes[currentModeIdx] ? out.modes[currentModeIdx] : null;
            
            const processedModes = [];
            if (out.modes) {
                for (let i = 0; i < out.modes.length; i++) {
                    const m = out.modes[i];
                    processedModes.push({
                        width: m.width,
                        height: m.height,
                        refresh_rate: m.refresh_rate / 1000.0,
                        is_preferred: m.is_preferred,
                        is_current: i === currentModeIdx
                    });
                }
            }

            const item = {
                connector: connector,
                name: (out.make || "") + " " + (out.model || ""),
                width: currentMode ? currentMode.width : 0,
                height: currentMode ? currentMode.height : 0,
                refresh_rate: currentMode ? currentMode.refresh_rate / 1000.0 : 0,
                x: out.logical ? out.logical.x : 0,
                y: out.logical ? out.logical.y : 0,
                scale: out.logical ? out.logical.scale : 1.0,
                logicalWidth: out.logical ? out.logical.width : (currentMode ? currentMode.width : 0),
                logicalHeight: out.logical ? out.logical.height : (currentMode ? currentMode.height : 0),
                modes: processedModes,
                active: out.logical !== null && out.logical !== undefined
            };
            res.push(item);
        }
        root.outputsArray = res;
        root.initializeLocalOutputs();
    }

    Component.onCompleted: updateOutputs()

    Connections {
        target: Niri
        function onOutputsChanged() {
            root.updateOutputs();
        }
    }

    property int selectedIndex: 0
    readonly property var selectedOutput: outputsArray.length > selectedIndex ? outputsArray[selectedIndex] : null

    function runCmd(cmd) {
        console.log("DisplayPane: Running command:", cmd);
        NiriIpc.action("spawn-sh", [cmd]);
    }

    ColumnLayout {
        anchors.fill: parent
        visible: outputsArray.length === 0
        
        MaterialIcon {
            text: "error"
            font.pointSize: 48
            color: Colours.palette.m3error
            Layout.alignment: Qt.AlignHCenter
        }
        StyledText {
            text: qsTr("No display data available")
            color: Colours.palette.m3outline
            Layout.alignment: Qt.AlignHCenter
        }
        StyledText {
            text: "Niri Available: " + Niri.niriAvailable
            Layout.alignment: Qt.AlignHCenter
        }
        TextButton {
            text: "Retry Fetch"
            Layout.alignment: Qt.AlignHCenter
            onClicked: root.updateOutputs()
        }
    }

    SplitPaneLayout {
        anchors.fill: parent
        visible: outputsArray.length > 0

        leftContent: Component {
            StyledFlickable {
                id: leftFlickable
                flickableDirection: Flickable.VerticalFlick
                contentHeight: leftContentLayout.height

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: leftFlickable
                }

                ColumnLayout {
                    id: leftContentLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Appearance.spacing.lg

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.md

                        StyledText {
                            text: qsTr("Displays")
                            font.pointSize: Appearance.font.size.titleMedium
                            font.weight: 500
                        }
                    }

                    Repeater {
                        model: root.outputsArray

                        delegate: StyledRect {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            color: root.selectedIndex === index ? Colours.layer(Colours.palette.m3surfaceContainer, 2) : "transparent"
                            radius: Appearance.rounding.normal

                            StateLayer {
                                function onClicked(): void {
                                    root.selectedIndex = index;
                                }
                            }

                            RowLayout {
                                id: rowLayout
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: Appearance.padding.md
                                spacing: Appearance.spacing.lg

                                MaterialIcon {
                                    text: "monitor"
                                    font.pointSize: Appearance.font.size.titleMedium
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.connector
                                        font.weight: root.selectedIndex === index ? 600 : 400
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        font.pointSize: Appearance.font.size.bodySmall
                                        color: Colours.palette.m3outline
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                            implicitHeight: rowLayout.implicitHeight + Appearance.padding.md * 2
                        }
                    }
                }
            }
        }

        rightContent: Component {
            StyledFlickable {
                id: rightFlickable
                flickableDirection: Flickable.VerticalFlick
                contentHeight: rightContentLayout.height

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: rightFlickable
                }

                ColumnLayout {
                    id: rightContentLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Appearance.spacing.xl

                    SettingsHeader {
                        icon: "monitor"
                        title: root.selectedOutput ? root.selectedOutput.connector : qsTr("Display Settings")
                    }

                    ColumnLayout {
                        visible: root.selectedOutput !== null
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.lg

                        SectionHeader {
                            title: qsTr("Positioning")
                            description: qsTr("Arrange your displays in virtual space by dragging them")
                        }

                        SectionContainer {
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.md

                                Item {
                                    id: displayCanvas
                                    Layout.fillWidth: true
                                    height: 240
                                    
                                    Rectangle {
                                        anchors.fill: parent
                                        color: Colours.layer(Colours.palette.m3surface, 1)
                                        radius: Appearance.rounding.normal
                                        border.color: Colours.palette.m3outlineVariant
                                        border.width: 1
                                    }
                                    
                                    Repeater {
                                        model: root.localOutputs
                                        
                                        delegate: Rectangle {
                                            id: screenItem
                                            required property var modelData
                                            required property int index
                                            
                                            visible: modelData.active
                                            
                                            x: displayCanvas.width / 2 + (modelData.x - root.currentBoxCenterX) * root.currentScale
                                            y: displayCanvas.height / 2 + (modelData.y - root.currentBoxCenterY) * root.currentScale
                                            width: modelData.logicalWidth * root.currentScale
                                            height: modelData.logicalHeight * root.currentScale
                                            
                                            radius: Appearance.rounding.small
                                            border.width: root.selectedIndex === index ? 2 : 1
                                            border.color: root.selectedIndex === index ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
                                            color: root.selectedIndex === index ? Colours.layer(Colours.palette.m3primaryContainer, 1) : Colours.layer(Colours.palette.m3surfaceContainer, 3)
                                            
                                            Behavior on x { enabled: !root.isDragging; NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                            Behavior on y { enabled: !root.isDragging; NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                            Behavior on width { enabled: !root.isDragging; NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                            Behavior on height { enabled: !root.isDragging; NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                                            clip: true

                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                width: parent.width - 8
                                                spacing: 2
                                                visible: parent.width >= 50 && parent.height >= 35
                                                
                                                StyledText {
                                                    text: modelData.connector
                                                    font.weight: 600
                                                    font.pointSize: 9.5
                                                    color: root.selectedIndex === index ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                                    Layout.alignment: Qt.AlignHCenter
                                                    elide: Text.ElideRight
                                                }
                                                
                                                StyledText {
                                                    text: modelData.logicalWidth + "x" + modelData.logicalHeight
                                                    font.pointSize: 8
                                                    color: root.selectedIndex === index ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3outline
                                                    Layout.alignment: Qt.AlignHCenter
                                                    elide: Text.ElideRight
                                                }
                                                
                                                StyledText {
                                                    text: "X: " + modelData.x + " Y: " + modelData.y
                                                    font.pointSize: 7.5
                                                    color: root.selectedIndex === index ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3outline
                                                    Layout.alignment: Qt.AlignHCenter
                                                    elide: Text.ElideRight
                                                }
                                            }
                                            
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.OpenHandCursor
                                                
                                                property real dragStartX
                                                property real dragStartY
                                                property real dragStartLogicalX
                                                property real dragStartLogicalY
                                                
                                                onPressed: (mouse) => {
                                                    cursorShape = Qt.ClosedHandCursor;
                                                    root.selectedIndex = index;
                                                    dragStartX = mouse.x;
                                                    dragStartY = mouse.y;
                                                    dragStartLogicalX = modelData.x;
                                                    dragStartLogicalY = modelData.y;
                                                    root.freezeMapping();
                                                }
                                                
                                                onPositionChanged: (mouse) => {
                                                    if (pressed) {
                                                        const dx = mouse.x - dragStartX;
                                                        const dy = mouse.y - dragStartY;
                                                        const dxLogical = dx / root.currentScale;
                                                        const dyLogical = dy / root.currentScale;
                                                        
                                                        let newX = dragStartLogicalX + dxLogical;
                                                        let newY = dragStartLogicalY + dyLogical;
                                                        
                                                        if (root.enableSnapping) {
                                                            const snapped = root.snapPosition(index, newX, newY);
                                                            newX = snapped.x;
                                                            newY = snapped.y;
                                                        }
                                                        
                                                        root.updateLocalPosition(index, newX, newY);
                                                    }
                                                }
                                                
                                                onReleased: {
                                                    cursorShape = Qt.OpenHandCursor;
                                                    root.unfreezeMapping();
                                                }
                                            }
                                        }
                                    }
                                }

                                SwitchRow {
                                    label: qsTr("Enable Snapping")
                                    checked: root.enableSnapping
                                    onToggled: (checked) => {
                                        root.enableSnapping = checked;
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.md

                                    StyledText {
                                        text: root.hasUnappliedChanges ? qsTr("Unapplied position changes") : qsTr("Positioning applied")
                                        font.pointSize: Appearance.font.size.bodySmall
                                        color: root.hasUnappliedChanges ? Colours.palette.m3error : Colours.palette.m3outline
                                        Layout.fillWidth: true
                                    }

                                    TextButton {
                                        text: qsTr("Reset Layout")
                                        stateLayer.disabled: !root.hasUnappliedChanges
                                        opacity: root.hasUnappliedChanges ? 1.0 : 0.5
                                        onClicked: {
                                            if (root.hasUnappliedChanges) {
                                                root.initializeLocalOutputs();
                                            }
                                        }
                                    }

                                    TextButton {
                                        text: qsTr("Apply Layout")
                                        stateLayer.disabled: !root.hasUnappliedChanges
                                        opacity: root.hasUnappliedChanges ? 1.0 : 0.5
                                        onClicked: {
                                            if (root.hasUnappliedChanges) {
                                                root.applyPositions();
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        SectionHeader {
                            title: qsTr("Resolution & Scale")
                            description: qsTr("Configure how your display looks")
                        }

                        SectionContainer {
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.md

                                // Scale
                                RowLayout {
                                    Layout.fillWidth: true
                                    StyledText { text: qsTr("Scale"); Layout.fillWidth: true }
                                    StyledText { 
                                        text: root.selectedOutput ? root.selectedOutput.scale.toFixed(2) : "" 
                                        font.weight: 600
                                    }
                                }
                                
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.sm
                                    Repeater {
                                        model: [0.5, 1.0, 1.5, 2.0]
                                        delegate: TextButton {
                                            text: modelData.toFixed(1)
                                            Layout.fillWidth: true
                                            checked: root.selectedOutput ? Math.abs(root.selectedOutput.scale - modelData) < 0.05 : false
                                            onClicked: {
                                                root.runCmd("niri msg output " + root.selectedOutput.connector + " scale " + modelData);
                                                scaleInput.updateText();
                                            }
                                        }
                                    }

                                    StyledInputField {
                                        id: scaleInput
                                        placeholderText: qsTr("Custom")
                                        horizontalAlignment: TextInput.AlignHCenter
                                        Layout.preferredWidth: 80
                                        Layout.fillHeight: true
                                        
                                        validator: DoubleValidator { bottom: 0.1; top: 10.0; decimals: 2 }
                                        
                                        function updateText() {
                                            if (!root.selectedOutput) {
                                                text = "";
                                                return;
                                            }
                                            const sc = root.selectedOutput.scale;
                                            const isDefault = [0.5, 1.0, 1.5, 2.0].some(val => Math.abs(sc - val) < 0.05);
                                            text = isDefault ? "" : sc.toFixed(2);
                                        }

                                        Component.onCompleted: updateText()

                                        onEditingFinished: {
                                            const val = parseFloat(text);
                                            if (!isNaN(val) && val >= 0.1 && val <= 10.0) {
                                                root.runCmd("niri msg output " + root.selectedOutput.connector + " scale " + val);
                                            }
                                        }
                                    }

                                    Connections {
                                        target: root
                                        function onOutputsArrayChanged() {
                                            if (!scaleInput.hasFocus) {
                                                scaleInput.updateText();
                                            }
                                        }
                                        function onSelectedIndexChanged() {
                                            if (!scaleInput.hasFocus) {
                                                scaleInput.updateText();
                                            }
                                        }
                                    }
                                }

                                Rectangle { height: 1; color: Colours.palette.m3outlineVariant; Layout.fillWidth: true }

                                // Resolution
                                StyledText { text: qsTr("Resolution") }
                                
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.xs
                                    
                                    Repeater {
                                        model: root.selectedOutput ? root.selectedOutput.modes.slice(0, 8) : []
                                        delegate: StyledRect {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            height: 44
                                            radius: Appearance.rounding.small
                                            color: modelData.is_current ? Colours.palette.m3primaryContainer : "transparent"
                                            
                                            StateLayer {
                                                onClicked: {
                                                    const modeStr = modelData.width + "x" + modelData.height + "@" + modelData.refresh_rate.toFixed(3);
                                                    root.runCmd("niri msg output " + root.selectedOutput.connector + " mode \"" + modeStr + "\"");
                                                }
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: Appearance.padding.md
                                                StyledText {
                                                    text: modelData.width + "x" + modelData.height + " @ " + modelData.refresh_rate.toFixed(2) + " Hz"
                                                    color: modelData.is_current ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                                    font.weight: modelData.is_current ? 600 : 400
                                                    Layout.fillWidth: true
                                                }
                                                MaterialIcon { 
                                                    visible: modelData.is_preferred
                                                    text: "star"
                                                    font.pointSize: 14
                                                    color: modelData.is_current ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3primary
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        TextButton {
                            Layout.fillWidth: true
                            text: qsTr("Save as Default")
                            // primary: true
                            onClicked: {
                                const bulkList = [];
                                for (let i = 0; i < root.localOutputs.length; i++) {
                                    const out = root.localOutputs[i];
                                    if (!out.active) continue;
                                    
                                    const actOut = root.outputsArray.find(o => o.connector === out.connector);
                                    let modeStr = "";
                                    if (actOut) {
                                        modeStr = actOut.width + "x" + actOut.height + "@" + actOut.refresh_rate.toFixed(3);
                                    }
                                    
                                    bulkList.push({
                                        connector: out.connector,
                                        x: out.x,
                                        y: out.y,
                                        scale: out.scale,
                                        mode: modeStr || null
                                    });
                                }
                                const scriptPath = "/home/patrick/.config/quickshell/niri-caelestia-shell/scripts/update_display.py";
                                const jsonStr = JSON.stringify(bulkList).replace(/"/g, '\\"');
                                const cmd = "python3 " + scriptPath + " --bulk \"" + jsonStr + "\"";
                                root.runCmd(cmd);
                            }
                        }
                    }
                }
            }
        }
    }
}
