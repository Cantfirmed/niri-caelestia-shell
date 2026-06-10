pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property ShellScreen screen
    required property var client

    readonly property ShellScreen clientScreen: {
        const wsId = root.client?.workspace_id;
        if (wsId === undefined || wsId === null) return root.screen;
        const ws = Niri.allWorkspaces.find(w => w.id === wsId);
        if (!ws) return root.screen;
        const s = Screens.screens.find(scr => scr.name === ws.output);
        return s || root.screen;
    }

    readonly property real screenAspectRatio: clientScreen ? clientScreen.width / clientScreen.height : 1.6

    // Retrieve coordinates directly from the compositor's active layout where possible.
    // Falls back to centering if the window details aren't currently rendered on screen.
    readonly property var geom: {
        const c = root.client;
        if (!c || !c.layout || !c.layout.window_size) return null;
        
        const size = c.layout.window_size;
        
        // Ask the Niri service for currently visible windows and their coordinates
        const visibleWindows = Niri.getWindowsInScreen(0, 0, clientScreen.width, clientScreen.height, 0, 0);
        const item = visibleWindows.find(w => w.window.id === c.id);
        if (item) {
            return {
                x: item.screenX,
                y: item.screenY,
                w: item.screenW,
                h: item.screenH
            };
        }
        
        // Fallback: center the window on the screen
        return {
            x: (clientScreen.width - size[0]) / 2,
            y: (clientScreen.height - size[1]) / 2,
            w: size[0],
            h: size[1]
        };
    }

    onClientScreenChanged: {
        console.log("[Preview] clientScreen changed to:", clientScreen ? clientScreen.name : "null", 
                    "width:", clientScreen ? clientScreen.width : 0, 
                    "height:", clientScreen ? clientScreen.height : 0);
    }

    onGeomChanged: {
        if (geom) {
            console.log("[Preview] geom changed to: x =", geom.x, "y =", geom.y, "w =", geom.w, "h =", geom.h);
        } else {
            console.log("[Preview] geom changed to null");
        }
    }

    Layout.preferredWidth: preview.implicitWidth + Tokens.padding.extraLargeIncreased
    Layout.fillHeight: true

    StyledClippingRect {
        id: preview

        anchors.centerIn: parent
        implicitWidth: 600
        implicitHeight: implicitWidth / screenAspectRatio
        clip: true

        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.medium

        // Semi-transparent decorative background elements for a premium feel
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(Colours.palette.m3primaryContainer, 0.15) }
                GradientStop { position: 1.0; color: Qt.alpha(Colours.palette.m3surfaceVariant, 0.05) }
            }
        }

        // Loader for the live/snapshot screencopy.
        // We apply the crop coordinates and scale factors directly to the Loader.
        // The loaded ScreencopyView automatically resizes to match, preventing the Loader
        // from overriding its size constraints.
        Loader {
            id: captureLoader
            
            width: root.clientScreen ? root.clientScreen.width * scaleFactor : 0
            height: root.clientScreen ? root.clientScreen.height * scaleFactor : 0

            x: root.geom ? offsetX - (root.geom.x * scaleFactor) : 0
            y: root.geom ? offsetY - (root.geom.y * scaleFactor) : 0

            readonly property real scaleFactor: {
                if (!root.geom || root.geom.w <= 0 || root.geom.h <= 0) return 1.0;
                const scaleX = preview.width / root.geom.w;
                const scaleY = preview.height / root.geom.h;
                return Math.min(scaleX, scaleY);
            }

            readonly property real scaledWindowWidth: root.geom ? root.geom.w * scaleFactor : 0
            readonly property real scaledWindowHeight: root.geom ? root.geom.h * scaleFactor : 0

            readonly property real offsetX: (preview.width - scaledWindowWidth) / 2
            readonly property real offsetY: (preview.height - scaledWindowHeight) / 2

            clip: true
            active: root.geom !== null && preview.width > 0 && preview.height > 0

            sourceComponent: ScreencopyView {
                captureSource: root.clientScreen
                live: false
            }
        }

        // Overlay with App name and icon when screencopy is available
        StyledRect {
            visible: root.geom !== null
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.padding.medium
            
            radius: Tokens.rounding.medium
            color: Qt.alpha(Colours.tPalette.m3surfaceContainerHigh, 0.85)
            
            implicitHeight: overlayLayout.implicitHeight + Tokens.padding.medium * 2
            
            RowLayout {
                id: overlayLayout
                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                // Small App Icon
                StyledRect {
                    radius: Tokens.rounding.small
                    color: Colours.tPalette.m3surfaceContainerHighest
                    implicitWidth: 32
                    implicitHeight: 32

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 24
                        asynchronous: true
                        source: Icons.getAppIcon(root.client?.app_id ?? "", "image-missing")
                    }
                }

                ColumnLayout {
                    spacing: 0
                    
                    StyledText {
                        Layout.fillWidth: true
                        text: root.client?.app_id ? root.client.app_id.toUpperCase() : qsTr("UNKNOWN")
                        font: Tokens.font.body.builders.medium.weight(Font.Bold).letterSpacing(1.0).build()
                        color: Colours.palette.m3primary
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("ACTIVE WINDOW")
                        font: Tokens.font.body.builders.extraSmall.weight(Font.Medium).letterSpacing(0.5).build()
                        color: Colours.palette.m3outline
                    }
                }
            }
        }

        // Fallback when geometry is not available
        ColumnLayout {
            anchors.centerIn: parent
            spacing: Tokens.spacing.largeIncreased
            width: parent.width - Tokens.padding.extraLargeIncreased * 2
            visible: root.geom === null

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 160
                implicitHeight: 160

                // Glowing background aura
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.alpha(Colours.palette.m3primary, 0.15)
                    scale: 1.2
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 32
                    }
                }

                // Smooth round background for the icon
                StyledRect {
                    anchors.fill: parent
                    radius: Tokens.rounding.extraLarge
                    color: Colours.tPalette.m3surfaceContainerHigh

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 96
                        asynchronous: true
                        source: Icons.getAppIcon(root.client?.app_id ?? "", "image-missing")
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.client?.app_id ? root.client.app_id.toUpperCase() : qsTr("UNKNOWN")
                    font: Tokens.font.body.builders.large.weight(Font.Bold).letterSpacing(2.0).build()
                    color: Colours.palette.m3primary
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("ACTIVE WINDOW")
                    font: Tokens.font.body.builders.small.weight(Font.Medium).letterSpacing(1.0).build()
                    color: Colours.palette.m3outline
                }
            }
        }
    }

    StyledText {
        id: label

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: preview.bottom
        anchors.topMargin: Tokens.padding.large

        animate: true
        text: {
            const client = root.client;
            if (!client)
                return qsTr("No active client");

            const wsId = client.workspace_id;
            const ws = Niri.allWorkspaces.find(w => w.id === wsId);
            const outputName = ws ? ws.output : "unknown";
            return qsTr("%1 on monitor %2").arg(client.title).arg(outputName);
        }
    }
}
