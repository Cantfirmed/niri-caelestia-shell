pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Components
import Caelestia.Config
import Caelestia.Models
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    property string wallpaperToDeletePath: ""
    property var colorsDb: ({})

    property Process localColorsProcess: Process {
        id: localColorsProcess

        command: ["python3", Quickshell.shellPath("scripts/webWallpaper/local_colors.py"), Paths.wallsdir]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.colorsDb = JSON.parse(text);
                } catch (e) {
                    console.error("Failed to parse local colors JSON:", e);
                }
            }
        }
    }

    property Process deleteProcess: Process {
        id: deleteProcess

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                localColorsProcess.running = true;
            } else {
                console.error("Delete process failed with exit code:", exitCode);
            }
        }
    }

    function deleteWallpaper(path) {
        root.wallpaperToDeletePath = path;
        deleteProcess.command = ["rm", path];
        deleteProcess.running = true;
    }

    title: qsTr("Wallpapers")
    isSubPage: true

    onVisibleChanged: {
        if (visible) {
            localColorsProcess.running = true;
        }
    }

    Component.onCompleted: {
        localColorsProcess.running = true;
    }

    Item {
        width: parent ? parent.width : 0
        implicitHeight: mainLayout.implicitHeight

        ColumnLayout {
            id: mainLayout

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: root.cappedWidth
            spacing: Tokens.spacing.small

        ButtonRow {
            Layout.bottomMargin: Tokens.spacing.medium
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.small

            IconTextButton {
                icon: "photo_library"
                text: qsTr("Browse")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                onClicked: browseDialog.open()

                FileDialog {
                    id: browseDialog

                    title: qsTr("Select an image")
                    filterLabel: qsTr("Image files")
                    filters: Images.validImageExtensions
                    onAccepted: path => {
                        Wallpapers.setWallpaper(path);
                        root.nState.closeSubPage();
                    }
                }
            }

            IconTextButton {
                icon: "travel_explore"
                text: qsTr("Search Online")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                type: IconTextButton.Tonal
                onClicked: {
                    root.nState.openSubPage(4);
                }
            }

            IconTextButton {
                icon: "shuffle"
                text: qsTr("Random")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                type: IconTextButton.Tonal
                onClicked: {
                    Wallpapers.setRandom();
                    root.nState.closeSubPage();
                }
            }
        }

        WallItem {
            imgHeight: Math.round(width * 0.3)
            radius: Tokens.rounding.extraLarge
            source: Quickshell.shellPath("assets/wallpaper.webp")
            text: qsTr("Featured wallpaper")
            fillLabel: false
            onClicked: {
                Wallpapers.setWallpaper(Quickshell.shellPath("assets/wallpaper.webp"));
                root.nState.closeSubPage();
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.large
            text: qsTr("Local wallpapers")
            font: Tokens.font.title.small
        }

        GridLayout {
            Layout.fillWidth: true
            visible: localWalls.count > 0

            columns: Config.nexus.wallpapersPerRow
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.large

            Repeater {
                id: localWalls

                model: {
                    const walls = Wallpapers.list;
                    const baseDir = Paths.wallsdir;
                    const categories = {};
                    const list = [];
                    for (const w of walls) {
                        if (w.parentDir !== baseDir) {
                            const category = Wallpapers.getCategoryFor(w);
                            if (category && (!(category in categories) || categories[category].name.localeCompare(w.name) > 0))
                                categories[category] = w;
                        } else {
                            list.push(w);
                        }
                    }
                    list.push(...Object.values(categories));
                    list.sort((a, b) => ((a.parentDir === baseDir) - (b.parentDir === baseDir)) || a.name.localeCompare(b.name));
                    while (list.length < Config.nexus.wallpapersPerRow)
                        list.push(null);
                    return list;
                }

                delegate: ColumnLayout {
                    id: delegateRoot

                    required property FileSystemEntry modelData
                    readonly property bool isLocal: delegateRoot.modelData ? delegateRoot.modelData.parentDir === Paths.wallsdir : false

                    // Empty placeholders for sizing
                    opacity: modelData ? 1 : 0
                    enabled: modelData

                    spacing: Tokens.spacing.small

                    // 1. Widescreen Thumbnail Container
                    StyledClippingRect {
                        id: imageContainer

                        Layout.fillWidth: true
                        implicitHeight: Math.round(width * 0.56)
                        radius: Tokens.rounding.large
                        color: Colours.tPalette.m3surfaceContainer

                        Loader {
                            anchors.centerIn: parent
                            opacity: thumbImage.status === Image.Ready ? 0 : 1
                            active: opacity > 0

                            sourceComponent: StyledRect {
                                implicitWidth: loadingIndicator.implicitSize + Tokens.padding.large * 2
                                implicitHeight: loadingIndicator.implicitSize + Tokens.padding.large * 2
                                color: Colours.palette.m3primaryContainer
                                radius: Tokens.rounding.full

                                LoadingIndicator {
                                    id: loadingIndicator

                                    anchors.centerIn: parent
                                    containsIcon: true
                                    implicitSize: Math.min(imageContainer.width, imageContainer.height) * 0.3
                                }
                            }

                            Behavior on opacity {
                                Anim {
                                    type: Anim.DefaultEffects
                                }
                            }
                        }

                        Image {
                            id: thumbImage

                            anchors.fill: parent
                            source: delegateRoot.modelData ? String(delegateRoot.modelData.path) : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: status === Image.Ready ? 1 : 0
                            retainWhileLoading: true

                            Behavior on opacity {
                                Anim {
                                    type: Anim.SlowEffects
                                }
                            }
                        }

                        StateLayer {
                            id: itemStateLayer

                            anchors.fill: parent
                            onClicked: {
                                if (!delegateRoot.modelData) return;
                                if (delegateRoot.modelData.parentDir !== Paths.wallsdir) {
                                    root.nState.selectedWallpaperCategory = Wallpapers.getCategoryFor(delegateRoot.modelData);
                                    root.nState.openSubPage(2);
                                } else {
                                    Wallpapers.setWallpaper(delegateRoot.modelData.path);
                                    root.nState.closeSubPage();
                                }
                            }
                        }

                        IconButton {
                            id: deleteBtn

                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: Tokens.padding.small
                            icon: "delete"
                            z: 10
                            visible: delegateRoot.isLocal
                            type: IconButton.Tonal
                            activeColour: Colours.palette.m3errorContainer
                            inactiveColour: Colours.palette.m3errorContainer
                            activeOnColour: Colours.palette.m3onErrorContainer
                            inactiveOnColour: Colours.palette.m3onErrorContainer
                            opacity: itemStateLayer.containsMouse || deleteBtn.hovered ? 1 : 0

                            onClicked: {
                                if (delegateRoot.modelData) {
                                    root.wallpaperToDeletePath = delegateRoot.modelData.path;
                                    deleteDialog.visible = true;
                                }
                            }

                            Behavior on opacity {
                                Anim {
                                    type: Anim.DefaultEffects
                                }
                            }
                        }
                    }

                    // 2. Info Row
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: Tokens.padding.small
                        spacing: Tokens.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                if (!delegateRoot.modelData)
                                    return "";
                                if (delegateRoot.modelData.parentDir !== Paths.wallsdir) {
                                    const category = Wallpapers.getCategoryFor(delegateRoot.modelData);
                                    return category.slice(0, 1).toUpperCase() + category.slice(1);
                                }
                                return delegateRoot.modelData.name;
                            }
                            font: Tokens.font.label.builders.small.weight(Font.Medium).build()
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }

                        Row {
                            spacing: 4
                            Layout.alignment: Qt.AlignVCenter
                            visible: delegateRoot.isLocal && root.colorsDb && root.colorsDb[delegateRoot.modelData.name] !== undefined

                            Repeater {
                                model: {
                                    if (!delegateRoot.modelData) return [];
                                    const cols = root.colorsDb ? root.colorsDb[delegateRoot.modelData.name] : null;
                                    return cols ? cols : [];
                                }

                                delegate: StyledRect {
                                    required property string modelData

                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: modelData
                                    border.width: 1
                                    border.color: Qt.alpha(Colours.palette.m3outline, 0.3)
                                }
                            }
                        }
                    }
                }
            }
        }

        Loader {
            Layout.fillWidth: true

            asynchronous: true
            active: localWalls.count === 0
            visible: active

            sourceComponent: StyledRect {
                color: Colours.tPalette.m3surfaceContainer
                radius: Tokens.rounding.extraLarge
                implicitHeight: noWallsLayout.implicitHeight + Tokens.padding.extraExtraLarge * 2

                ColumnLayout {
                    id: noWallsLayout

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "hide_image"
                        color: Colours.palette.m3outline
                        fontStyle: Tokens.font.icon.extraLarge
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("No local wallpapers found")
                        color: Colours.palette.m3outline
                        font: Tokens.font.title.small
                    }
                }
            }
        }
        }

        StyledRect {
            id: deleteDialog

            anchors.fill: parent
            z: 999
            color: Qt.rgba(Colours.palette.m3surface.r, Colours.palette.m3surface.g, Colours.palette.m3surface.b, 0.8)
            visible: false

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            StyledRect {
                anchors.centerIn: parent
                width: Math.min(parent.width - Tokens.padding.extraLarge * 2, 400)
                implicitHeight: dialogLayout.implicitHeight + Tokens.padding.large * 2
                radius: Tokens.rounding.extraLarge
                color: Colours.tPalette.m3surfaceContainer
                border.width: 1
                border.color: Colours.palette.m3outlineVariant

                ColumnLayout {
                    id: dialogLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "warning"
                        color: Colours.palette.m3error
                        fontStyle: Tokens.font.icon.large
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("Delete Wallpaper?")
                        font: Tokens.font.title.medium
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("Are you sure you want to delete this wallpaper from your local storage? This action cannot be undone.")
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        Layout.topMargin: Tokens.spacing.small
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        IconTextButton {
                            Layout.fillWidth: true
                            icon: "close"
                            text: qsTr("Cancel")
                            type: IconTextButton.Tonal
                            onClicked: {
                                deleteDialog.visible = false;
                            }
                        }

                        IconTextButton {
                            Layout.fillWidth: true
                            icon: "delete"
                            text: qsTr("Delete")
                            activeColour: Colours.palette.m3error
                            inactiveColour: Colours.palette.m3error
                            activeOnColour: Colours.palette.m3onError
                            inactiveOnColour: Colours.palette.m3onError
                            onClicked: {
                                deleteDialog.visible = false;
                                root.deleteWallpaper(root.wallpaperToDeletePath);
                            }
                        }
                    }
                }
            }
        }
    }
}
