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
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property string pythonPath: (Quickshell.env("CAELESTIA_VIRTUAL_ENV") || (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell/.venv") + "/bin/python3"
    readonly property string scriptDir: Paths.toLocalFile(Qt.resolvedUrl("../../../../scripts/webWallpaper/wallhaven"))
    property string keyword: ""
    property bool loading: false
    property bool downloading: false
    property var wallpapers: []
    property int currentApiPage: 1
    property int lastApiPage: 1

    property Process listProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                if (text) {
                    try {
                        let response = JSON.parse(text);
                        root.lastApiPage = response.meta.last_page;
                        let rawData = response.data;
                        let newData = [];
                        for (let i = 0; i < rawData.length; i++) {
                            newData.push({
                                slug: rawData[i].id,
                                url_thumb: rawData[i].thumbs.large,
                                resolution: rawData[i].resolution,
                                ratio: rawData[i].ratio,
                                colors: rawData[i].colors
                            });
                        }
                        root.wallpapers = newData;
                    } catch (e) {
                        console.error("Failed to parse wallpaper list:", e, "Output was:", text);
                    }
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text) console.warn("List process error:", text);
            }
        }
    }

    property Process downloadProcess: Process {
        property string currentSlug: ""

        stdout: StdioCollector {
            onStreamFinished: {
                root.downloading = false;
                if (text) {
                    try {
                        const result = JSON.parse(text);
                        if (result.status === "success") {
                            Wallpapers.setWallpaper(result.path);
                            root.nState.closeSubPage();
                            root.nState.closeSubPage();
                        }
                    } catch (e) {
                        console.error("Failed to parse download result:", e, "Output was:", text);
                    }
                }
                downloadProcess.currentSlug = "";
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text) console.warn("Download process error:", text);
            }
        }
    }

    function fetchWallpapers(page) {
        if (page === undefined) page = 1;
        currentApiPage = page;
        loading = true;

        let args = [
            pythonPath,
            scriptDir + "/main.py",
            "search",
            "--categories", "general,anime",
            "--purity", "sfw",
            "--sort", "date_added",
            "--resolution", "1920x1080",
            "--page", String(currentApiPage),
            "--json"
        ];
        if (keyword) {
            args.splice(3, 0, keyword);
        }
        listProcess.command = args;
        listProcess.running = true;
    }

    function downloadAndSet(slug) {
        downloading = true;
        downloadProcess.currentSlug = slug;
        let args = [
            pythonPath,
            scriptDir + "/main.py",
            "download",
            slug,
            "--dir", Paths.wallsdir,
            "--json"
        ];
        downloadProcess.command = args;
        downloadProcess.running = true;
    }

    title: qsTr("Search Online")
    isSubPage: true

    Component.onCompleted: {
        fetchWallpapers(1);
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.medium

        // Search Bar Row
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 50
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerLowest
            border.color: Colours.palette.m3outlineVariant

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: Tokens.padding.medium
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "search"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }

                StyledTextField {
                    id: searchField

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    placeholderText: qsTr("Search online wallpapers...")
                    placeholderTextColor: Colours.palette.m3onSurfaceVariant
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.body.large

                    onAccepted: {
                        root.keyword = text;
                        root.fetchWallpapers(1);
                    }
                }

                IconButton {
                    icon: "close"
                    font: Tokens.font.icon.medium
                    type: IconButton.Text
                    padding: Tokens.padding.extraSmall
                    isRound: true
                    opacity: searchField.text.length > 0 ? 1 : 0

                    onClicked: {
                        searchField.clear();
                        root.keyword = "";
                        root.fetchWallpapers(1);
                    }

                    Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                }
            }
        }

        // Loading indicator for search
        Loader {
            Layout.fillWidth: true
            Layout.minimumHeight: 200
            active: root.loading
            visible: active

            sourceComponent: ColumnLayout {
                spacing: Tokens.spacing.medium

                StyledBusyIndicator {
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // Loading/progress overlay for download
        Loader {
            Layout.fillWidth: true
            Layout.minimumHeight: 200
            active: root.downloading
            visible: active

            sourceComponent: ColumnLayout {
                spacing: Tokens.spacing.medium

                StyledBusyIndicator {
                    Layout.alignment: Qt.AlignHCenter
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Downloading and setting wallpaper...")
                    font: Tokens.font.body.large
                    color: Colours.palette.m3onSurface
                }
            }
        }

        // Empty state
        Loader {
            Layout.fillWidth: true
            Layout.minimumHeight: 200
            active: root.wallpapers.length === 0 && !root.loading && !root.downloading
            visible: active

            sourceComponent: ColumnLayout {
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "sentiment_dissatisfied"
                    color: Colours.palette.m3outlineVariant
                    fontStyle: Tokens.font.icon.extraLarge
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("No wallpapers found")
                    font: Tokens.font.title.medium
                    color: Colours.palette.m3outlineVariant
                }
            }
        }

        // Wallpapers Grid
        GridLayout {
            Layout.fillWidth: true
            visible: root.wallpapers.length > 0 && !root.loading && !root.downloading
            columns: Config.nexus.wallpapersPerRow
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.large

            Repeater {
                model: root.wallpapers

                delegate: ColumnLayout {
                    id: delegateRoot

                    required property var modelData

                    spacing: Tokens.spacing.small

                    // 1. Widescreen Thumbnail Container (16:9 aspect ratio)
                    StyledClippingRect {
                        id: imageContainer

                        Layout.fillWidth: true
                        implicitHeight: Math.round(width * 0.56)
                        radius: Tokens.rounding.large
                        color: Colours.tPalette.m3surfaceContainer

                        Image {
                            id: thumbImage

                            anchors.fill: parent
                            source: delegateRoot.modelData ? delegateRoot.modelData.url_thumb : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: status === Image.Ready ? 1 : 0

                            Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                        }

                        // Downloading Overlay
                        StyledRect {
                            anchors.fill: parent
                            color: Qt.rgba(Colours.palette.m3surface.r, Colours.palette.m3surface.g, Colours.palette.m3surface.b, 0.6)
                            visible: root.downloading && downloadProcess.currentSlug === delegateRoot.modelData.slug

                            StyledBusyIndicator {
                                anchors.centerIn: parent
                            }
                        }

                        // Hover & Click Interaction
                        StateLayer {
                            anchors.fill: parent

                            onClicked: {
                                root.downloadAndSet(delegateRoot.modelData.slug);
                            }
                        }
                    }

                    // 2. Info Row (Resolution, Aspect Ratio, & Color Scheme Palette)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: delegateRoot.modelData ? delegateRoot.modelData.resolution : ""
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurface
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    if (!delegateRoot.modelData) return "";
                                    let r = parseFloat(delegateRoot.modelData.ratio);
                                    if (Math.abs(r - 1.78) < 0.05) return "16:9";
                                    if (Math.abs(r - 1.6) < 0.05) return "16:10";
                                    if (Math.abs(r - 1.33) < 0.05) return "4:3";
                                    if (Math.abs(r - 2.33) < 0.05) return "21:9";
                                    if (Math.abs(r - 3.56) < 0.05) return "32:9";
                                    return delegateRoot.modelData.ratio + " Ratio";
                                }
                                font: Tokens.font.label.extraSmall
                                color: Colours.palette.m3outline
                                elide: Text.ElideRight
                            }
                        }

                        // Color Dots (representing Matugen profile)
                        Row {
                            spacing: 4
                            Layout.alignment: Qt.AlignVCenter

                            Repeater {
                                model: delegateRoot.modelData ? delegateRoot.modelData.colors : []

                                delegate: StyledRect {
                                    required property var modelData

                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: String(modelData)
                                    border.width: 1
                                    border.color: Qt.alpha(Colours.palette.m3outline, 0.3)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Pagination
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.medium
            visible: root.wallpapers.length > 0 && !root.loading && !root.downloading
            spacing: Tokens.spacing.large

            IconButton {
                icon: "chevron_left"
                enabled: root.currentApiPage > 1
                type: IconButton.Tonal

                onClicked: {
                    if (root.currentApiPage > 1) {
                        root.fetchWallpapers(root.currentApiPage - 1);
                    }
                }
            }

            StyledText {
                text: qsTr("Page %1 of %2").arg(root.currentApiPage).arg(root.lastApiPage)
                font: Tokens.font.body.medium
                color: Colours.palette.m3onSurface
            }

            IconButton {
                icon: "chevron_right"
                enabled: root.currentApiPage < root.lastApiPage
                type: IconButton.Tonal

                onClicked: {
                    if (root.currentApiPage < root.lastApiPage) {
                        root.fetchWallpapers(root.currentApiPage + 1);
                    }
                }
            }
        }
    }
}
