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

    readonly property string pythonPath: Quickshell.env("CAELESTIA_VIRTUAL_ENV") ? (Quickshell.env("CAELESTIA_VIRTUAL_ENV") + "/bin/python3") : "python3"
    readonly property string scriptDir: Quickshell.shellPath("scripts/webWallpaper/wallhaven")
    property string keyword: ""
    property string selectedRatio: "landscape"
    property string selectedResolution: "1920x1080"
    property string selectedSort: "date_added"
    property string selectedTopRange: "1M"
    property bool catGeneral: true
    property bool catAnime: true
    property bool catPeople: false
    property string downloadStatusText: qsTr("Downloading wallpaper...")
    property bool loading: false
    property bool downloading: false
    property var wallpapers: []
    property int currentApiPage: 1
    property int lastApiPage: 1

    property Process listProcess: Process {
        onExited: (exitCode, exitStatus) => {
            root.loading = false;
        }

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

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.downloading = false;
            downloadProcess.currentSlug = "";
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (text) {
                    try {
                        const result = JSON.parse(text);
                        if (result.status === "success") {
                            root.downloadStatusText = qsTr("Preparing wallpaper transition...");
                            prepareProcess.targetPath = result.path;
                            prepareProcess.command = ["python3", Quickshell.shellPath("scripts/wallfx.py"), "perfil", result.path];
                            prepareProcess.running = true;
                            return;
                        }
                    } catch (e) {
                        console.error("Failed to parse download result:", e, "Output was:", text);
                    }
                }
                root.downloading = false;
                downloadProcess.currentSlug = "";
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text) console.warn("Download process error:", text);
            }
        }
    }

    property Process prepareProcess: Process {
        property string targetPath: ""

        onExited: (exitCode, exitStatus) => {
            root.downloading = false;
            Wallpapers.setWallpaper(prepareProcess.targetPath);
            root.nState.closeSubPage();
            root.nState.closeSubPage();
        }
    }

    function fetchWallpapers(page) {
        if (page === undefined) page = 1;
        currentApiPage = page;
        loading = true;

        let cats = [];
        if (catGeneral) cats.push("general");
        if (catAnime) cats.push("anime");
        if (catPeople) cats.push("people");
        if (cats.length === 0) cats = ["general", "anime", "people"];

        let args = [
            pythonPath,
            scriptDir + "/main.py",
            "search",
            "--categories", cats.join(","),
            "--purity", "sfw",
            "--sort", selectedSort,
            "--page", String(currentApiPage),
            "--json"
        ];
        if (selectedSort === "toplist" && selectedTopRange) {
            args.push("--range", selectedTopRange);
        }
        if (selectedResolution) {
            args.push("--resolution", selectedResolution);
        }
        if (selectedRatio) {
            args.push("--ratios", selectedRatio);
        }
        if (keyword) {
            args.splice(3, 0, keyword);
        }
        if (listProcess.running) {
            listProcess.running = false;
        }
        listProcess.command = args;
        listProcess.running = true;
    }

    function downloadAndSet(slug) {
        downloading = true;
        downloadStatusText = qsTr("Downloading wallpaper...");
        downloadProcess.currentSlug = slug;
        let args = [
            pythonPath,
            scriptDir + "/main.py",
            "download",
            slug,
            "--dir", Paths.wallsdir,
            "--json"
        ];
        if (downloadProcess.running) {
            downloadProcess.running = false;
        }
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
                        root.keyword = text.trim();
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

        // Filter Bar
        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small
            z: 10

            SplitButton {
                id: ratioFilter

                z: expanded ? 20 : 0
                type: SplitButton.Tonal
                fallbackIcon: "aspect_ratio"
                fallbackText: qsTr("Ratio")
                stateLayer.onClicked: expanded = !expanded
                active: menuItems.find(i => i.value === root.selectedRatio) ?? null
                menu.onItemSelected: item => {
                    if (root.selectedRatio !== item.value) {
                        root.selectedRatio = item.value;
                        root.fetchWallpapers(1);
                    }
                }

                menuItems: [
                    MenuItem { text: qsTr("Landscape (Monitors & Laptops)"); activeText: qsTr("Landscape"); icon: "desktop_windows"; value: "landscape" },
                    MenuItem { text: qsTr("16:9 (External Monitor)"); activeText: "16:9"; icon: "monitor"; value: "16x9" },
                    MenuItem { text: qsTr("16:10 (Notebook)"); activeText: "16:10"; icon: "laptop_chromebook"; value: "16x10" },
                    MenuItem { text: qsTr("16:9 & 16:10"); activeText: "16:9 / 16:10"; icon: "devices"; value: "16x9,16x10" },
                    MenuItem { text: qsTr("21:9 (Ultrawide)"); activeText: "21:9"; icon: "width_wide"; value: "21x9" },
                    MenuItem { text: qsTr("Portrait (Phone)"); activeText: qsTr("Portrait"); icon: "smartphone"; value: "portrait" },
                    MenuItem { text: qsTr("Any Ratio"); activeText: qsTr("Any Ratio"); icon: "crop_free"; value: "" }
                ]
            }

            SplitButton {
                id: resolutionFilter

                z: expanded ? 20 : 0
                type: SplitButton.Tonal
                fallbackIcon: "high_quality"
                fallbackText: qsTr("Resolution")
                stateLayer.onClicked: expanded = !expanded
                active: menuItems.find(i => i.value === root.selectedResolution) ?? null
                menu.onItemSelected: item => {
                    if (root.selectedResolution !== item.value) {
                        root.selectedResolution = item.value;
                        root.fetchWallpapers(1);
                    }
                }

                menuItems: [
                    MenuItem { text: qsTr("1080p+ (1920x1080)"); activeText: "1080p+"; icon: "hd"; value: "1920x1080" },
                    MenuItem { text: qsTr("1440p+ (2560x1440)"); activeText: "1440p+"; icon: "2k"; value: "2560x1440" },
                    MenuItem { text: qsTr("4K+ (3840x2160)"); activeText: "4K+"; icon: "4k"; value: "3840x2160" },
                    MenuItem { text: qsTr("Any Resolution"); activeText: qsTr("Any Res"); icon: "photo_size_select_large"; value: "" }
                ]
            }

            SplitButton {
                id: sortFilter

                z: expanded ? 20 : 0
                type: SplitButton.Tonal
                fallbackIcon: "sort"
                fallbackText: qsTr("Sort")
                stateLayer.onClicked: expanded = !expanded
                active: menuItems.find(i => i.value === root.selectedSort) ?? null
                menu.onItemSelected: item => {
                    if (root.selectedSort !== item.value) {
                        root.selectedSort = item.value;
                        root.fetchWallpapers(1);
                    }
                }

                menuItems: [
                    MenuItem { text: qsTr("Latest"); activeText: qsTr("Latest"); icon: "schedule"; value: "date_added" },
                    MenuItem { text: qsTr("Toplist"); activeText: qsTr("Toplist"); icon: "trending_up"; value: "toplist" },
                    MenuItem { text: qsTr("Most Viewed"); activeText: qsTr("Views"); icon: "visibility"; value: "views" },
                    MenuItem { text: qsTr("Favorites"); activeText: qsTr("Favorites"); icon: "favorite"; value: "favorites" },
                    MenuItem { text: qsTr("Random"); activeText: qsTr("Random"); icon: "shuffle"; value: "random" },
                    MenuItem { text: qsTr("Relevance"); activeText: qsTr("Relevance"); icon: "search"; value: "relevance" }
                ]
            }

            SplitButton {
                id: topRangeFilter

                z: expanded ? 20 : 0
                visible: root.selectedSort === "toplist"
                type: SplitButton.Tonal
                fallbackIcon: "date_range"
                fallbackText: qsTr("Range")
                stateLayer.onClicked: expanded = !expanded
                active: menuItems.find(i => i.value === root.selectedTopRange) ?? null
                menu.onItemSelected: item => {
                    if (root.selectedTopRange !== item.value) {
                        root.selectedTopRange = item.value;
                        root.fetchWallpapers(1);
                    }
                }

                menuItems: [
                    MenuItem { text: qsTr("Last Day"); activeText: "1d"; value: "1d" },
                    MenuItem { text: qsTr("Last 3 Days"); activeText: "3d"; value: "3d" },
                    MenuItem { text: qsTr("Last Week"); activeText: "1w"; value: "1w" },
                    MenuItem { text: qsTr("Last Month"); activeText: "1M"; value: "1M" },
                    MenuItem { text: qsTr("Last 3 Months"); activeText: "3M"; value: "3M" },
                    MenuItem { text: qsTr("Last 6 Months"); activeText: "6M"; value: "6M" },
                    MenuItem { text: qsTr("Last Year"); activeText: "1y"; value: "1y" }
                ]
            }

            ToggleButton {
                label: qsTr("General")
                toggled: root.catGeneral
                horizontalPadding: Tokens.padding.medium
                verticalPadding: Tokens.padding.small
                onClicked: {
                    if (root.catGeneral && !root.catAnime && !root.catPeople)
                        return;
                    root.catGeneral = !root.catGeneral;
                    root.fetchWallpapers(1);
                }
            }

            ToggleButton {
                label: qsTr("Anime")
                toggled: root.catAnime
                horizontalPadding: Tokens.padding.medium
                verticalPadding: Tokens.padding.small
                onClicked: {
                    if (root.catAnime && !root.catGeneral && !root.catPeople)
                        return;
                    root.catAnime = !root.catAnime;
                    root.fetchWallpapers(1);
                }
            }

            ToggleButton {
                label: qsTr("People")
                toggled: root.catPeople
                horizontalPadding: Tokens.padding.medium
                verticalPadding: Tokens.padding.small
                onClicked: {
                    if (root.catPeople && !root.catGeneral && !root.catAnime)
                        return;
                    root.catPeople = !root.catPeople;
                    root.fetchWallpapers(1);
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
                    text: root.downloadStatusText
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
                                font: Tokens.font.label.small
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
