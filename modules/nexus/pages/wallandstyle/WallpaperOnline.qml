pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
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
    property bool loading: false
    property bool downloading: false
    property string downloadStatusText: Tr.tr("Downloading and setting wallpaper...")
    property var wallpapers: []
    property int currentApiPage: 1
    property int lastApiPage: 1
    property string errorMessage: ""

    // Active Wallhaven filters (exposed visibly in the UI)
    property bool catGeneral: true
    property bool catAnime: true
    property bool catPeople: false
    property bool puritySfw: true
    property bool puritySketchy: false
    property bool purityNsfw: false
    property string sortBy: "date_added"
    property string topRange: "1M"
    property string minResolution: "1920x1080"
    property string aspectRatio: ""

    readonly property bool hasCustomFilters: !catGeneral || !catAnime || catPeople
        || !puritySfw || puritySketchy || purityNsfw
        || sortBy !== "date_added" || minResolution !== "1920x1080" || aspectRatio !== ""

    property Process listProcess: Process {
        property string lastStderr: ""

        onStarted: {
            lastStderr = "";
        }

        onExited: (exitCode, exitStatus) => {
            root.loading = false;
            if (exitCode !== 0) {
                root.wallpapers = [];
                root.errorMessage = lastStderr.trim() || Tr.tr("Search failed (exit code %1)").arg(exitCode);
            }
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
                        root.errorMessage = "";
                        root.wallpapers = newData;
                    } catch (e) {
                        console.error("Failed to parse wallpaper list:", e, "Output was:", text);
                    }
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text) {
                    listProcess.lastStderr = text;
                    console.warn("List process error:", text);
                }
            }
        }
    }

    property Process downloadProcess: Process {
        property string currentSlug: ""
        property bool preparingTransition: false

        onStarted: {
            preparingTransition = false;
        }

        onExited: (exitCode, exitStatus) => {
            if (!preparingTransition)
                root.downloading = false;
            downloadProcess.currentSlug = "";
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (text) {
                    try {
                        const result = JSON.parse(text);
                        if (result.status === "success") {
                            downloadProcess.preparingTransition = true;
                            root.downloadStatusText = Tr.tr("Preparing wallpaper transition...");
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

    function resetFilters(): void {
        catGeneral = true;
        catAnime = true;
        catPeople = false;
        puritySfw = true;
        puritySketchy = false;
        purityNsfw = false;
        sortBy = "date_added";
        topRange = "1M";
        minResolution = "1920x1080";
        aspectRatio = "";
        sortBtn.active = sortDateAdded;
        rangeBtn.active = range1M;
        resBtn.active = res1080;
        ratioBtn.active = ratioAny;
        fetchWallpapers(1);
    }

    function fetchWallpapers(page) {
        if (page === undefined) page = 1;
        currentApiPage = page;
        loading = true;
        errorMessage = "";

        const cats = [];
        if (catGeneral) cats.push("general");
        if (catAnime) cats.push("anime");
        if (catPeople) cats.push("people");

        const purities = [];
        if (puritySfw) purities.push("sfw");
        if (puritySketchy) purities.push("sketchy");
        if (purityNsfw) purities.push("nsfw");

        let args = [
            pythonPath,
            scriptDir + "/main.py",
            "search",
            "--categories", cats.length > 0 ? cats.join(",") : "general,anime,people",
            "--purity", purities.length > 0 ? purities.join(",") : "sfw",
            "--sort", sortBy
        ];
        if (sortBy === "toplist" && topRange) {
            args.push("--range", topRange);
        }
        if (minResolution) {
            args.push("--resolution", minResolution);
        }
        if (aspectRatio) {
            args.push("--ratios", aspectRatio);
        }
        args.push("--page", String(currentApiPage), "--json");

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
        downloadStatusText = Tr.tr("Downloading wallpaper...");
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

    title: Tr.tr("Search Online")
    isSubPage: true

    Component.onCompleted: {
        fetchWallpapers(1);
    }

    Item {
        width: parent ? parent.width : 0
        implicitHeight: mainLayout.implicitHeight

        ColumnLayout {
            id: mainLayout

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: root.cappedWidth
            spacing: Tokens.spacing.medium

            // Search Bar
            SearchBar {
                id: searchField

                Layout.fillWidth: true
                font: Tokens.font.body.medium
                placeholderText: Tr.tr("Search online wallpapers...")

                onAccepted: {
                    root.keyword = text.trim();
                    root.fetchWallpapers(1);
                }

                onTextChanged: {
                    if (text.length === 0 && root.keyword.length > 0) {
                        root.keyword = "";
                        root.fetchWallpapers(1);
                    }
                }
            }

            // Visible Filter Controls
            ConnectedRect {
                Layout.fillWidth: true
                first: true
                last: true
                implicitHeight: filterLayout.implicitHeight + Tokens.padding.medium * 2

                ColumnLayout {
                    id: filterLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "tune"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Tr.tr("Filters")
                            font: Tokens.font.title.small
                        }

                        IconTextButton {
                            visible: root.hasCustomFilters
                            icon: "restart_alt"
                            text: Tr.tr("Reset")
                            type: IconTextButton.Text
                            verticalPadding: Tokens.padding.extraSmall
                            onClicked: root.resetFilters()
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        // Categories
                        FilterChip {
                            labelText: Tr.tr("General")
                            checked: root.catGeneral
                            onClicked: {
                                if (!internalChecked && !root.catAnime && !root.catPeople) {
                                    internalChecked = true;
                                    return;
                                }
                                root.catGeneral = internalChecked;
                                root.fetchWallpapers(1);
                            }
                        }

                        FilterChip {
                            labelText: Tr.tr("Anime")
                            checked: root.catAnime
                            onClicked: {
                                if (!internalChecked && !root.catGeneral && !root.catPeople) {
                                    internalChecked = true;
                                    return;
                                }
                                root.catAnime = internalChecked;
                                root.fetchWallpapers(1);
                            }
                        }

                        FilterChip {
                            labelText: Tr.tr("People")
                            checked: root.catPeople
                            onClicked: {
                                if (!internalChecked && !root.catGeneral && !root.catAnime) {
                                    internalChecked = true;
                                    return;
                                }
                                root.catPeople = internalChecked;
                                root.fetchWallpapers(1);
                            }
                        }

                        StyledRect {
                            width: 1
                            height: Tokens.padding.large * 1.4
                            color: Colours.palette.m3outlineVariant
                        }

                        // Purity
                        FilterChip {
                            labelText: Tr.tr("SFW")
                            checked: root.puritySfw
                            onClicked: {
                                if (!internalChecked && !root.puritySketchy && !root.purityNsfw) {
                                    internalChecked = true;
                                    return;
                                }
                                root.puritySfw = internalChecked;
                                root.fetchWallpapers(1);
                            }
                        }

                        FilterChip {
                            labelText: Tr.tr("Sketchy")
                            checked: root.puritySketchy
                            onClicked: {
                                if (!internalChecked && !root.puritySfw && !root.purityNsfw) {
                                    internalChecked = true;
                                    return;
                                }
                                root.puritySketchy = internalChecked;
                                root.fetchWallpapers(1);
                            }
                        }

                        FilterChip {
                            labelText: Tr.tr("NSFW")
                            checked: root.purityNsfw
                            onClicked: {
                                if (!internalChecked && !root.puritySfw && !root.puritySketchy) {
                                    internalChecked = true;
                                    return;
                                }
                                root.purityNsfw = internalChecked;
                                root.fetchWallpapers(1);
                            }
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        SplitButton {
                            id: sortBtn

                            type: SplitButton.Tonal
                            fallbackIcon: "sort"
                            fallbackText: Tr.tr("Sort: Date Added")
                            active: sortDateAdded
                            menuItems: [
                                MenuItem {
                                    id: sortDateAdded

                                    icon: "schedule"
                                    text: Tr.tr("Sort: Date Added")
                                    value: "date_added"
                                    onClicked: {
                                        root.sortBy = String(value);
                                        root.fetchWallpapers(1);
                                    }
                                },
                                MenuItem {
                                    icon: "auto_awesome"
                                    text: Tr.tr("Sort: Relevance")
                                    value: "relevance"
                                    onClicked: {
                                        root.sortBy = String(value);
                                        root.fetchWallpapers(1);
                                    }
                                },
                                MenuItem {
                                    icon: "trending_up"
                                    text: Tr.tr("Sort: Toplist")
                                    value: "toplist"
                                    onClicked: {
                                        root.sortBy = String(value);
                                        root.fetchWallpapers(1);
                                    }
                                },
                                MenuItem {
                                    icon: "visibility"
                                    text: Tr.tr("Sort: Views")
                                    value: "views"
                                    onClicked: {
                                        root.sortBy = String(value);
                                        root.fetchWallpapers(1);
                                    }
                                },
                                MenuItem {
                                    icon: "favorite"
                                    text: Tr.tr("Sort: Favorites")
                                    value: "favorites"
                                    onClicked: {
                                        root.sortBy = String(value);
                                        root.fetchWallpapers(1);
                                    }
                                },
                                MenuItem {
                                    icon: "shuffle"
                                    text: Tr.tr("Sort: Random")
                                    value: "random"
                                    onClicked: {
                                        root.sortBy = String(value);
                                        root.fetchWallpapers(1);
                                    }
                                }
                            ]
                        }

                        SplitButton {
                            id: rangeBtn

                            visible: root.sortBy === "toplist"
                            type: SplitButton.Tonal
                            fallbackIcon: "date_range"
                            fallbackText: Tr.tr("Range: 1M")
                            active: range1M
                            menuItems: [
                                MenuItem {
                                    icon: "today"
                                    text: Tr.tr("Range: 1 Day")
                                    value: "1d"
                                    onClicked: { root.topRange = String(value); root.fetchWallpapers(1); }
                                },
                                MenuItem {
                                    icon: "date_range"
                                    text: Tr.tr("Range: 3 Days")
                                    value: "3d"
                                    onClicked: { root.topRange = String(value); root.fetchWallpapers(1); }
                                },
                                MenuItem {
                                    icon: "date_range"
                                    text: Tr.tr("Range: 1 Week")
                                    value: "1w"
                                    onClicked: { root.topRange = String(value); root.fetchWallpapers(1); }
                                },
                                MenuItem {
                                    id: range1M

                                    icon: "calendar_month"
                                    text: Tr.tr("Range: 1 Month")
                                    value: "1M"
                                    onClicked: { root.topRange = String(value); root.fetchWallpapers(1); }
                                },
                                MenuItem {
                                    icon: "calendar_month"
                                    text: Tr.tr("Range: 3 Months")
                                    value: "3M"
                                    onClicked: { root.topRange = String(value); root.fetchWallpapers(1); }
                                },
                                MenuItem {
                                    icon: "calendar_month"
                                    text: Tr.tr("Range: 6 Months")
                                    value: "6M"
                                    onClicked: { root.topRange = String(value); root.fetchWallpapers(1); }
                                },
                                MenuItem {
                                    icon: "calendar_today"
                                    text: Tr.tr("Range: 1 Year")
                                    value: "1y"
                                    onClicked: { root.topRange = String(value); root.fetchWallpapers(1); }
                                }
                            ]
                        }

                        SplitButton {
                            id: resBtn

                            type: SplitButton.Tonal
                            fallbackIcon: "aspect_ratio"
                            fallbackText: Tr.tr("Min: 1920x1080")
                            active: res1080
                            menuItems: [
                                MenuItem {
                                    icon: "photo_size_select_large"
                                    text: Tr.tr("Min: Any")
                                    value: ""
                                    onClicked: { root.minResolution = String(value); root.fetchWallpapers(1); }
                                },
                                MenuItem {
                                    id: res1080

                                    icon: "hd"
                                    text: Tr.tr("Min: 1920x1080")
                                    value: "1920x1080"
                                    onClicked: { root.minResolution = String(value); root.fetchWallpapers(1); }
                                },
                                MenuItem {
                                    icon: "high_quality"
                                    text: Tr.tr("Min: 2560x1440")
                                    value: "2560x1440"
                                    onClicked: { root.minResolution = String(value); root.fetchWallpapers(1); }
                                },
                                MenuItem {
                                    icon: "4k"
                                    text: Tr.tr("Min: 3840x2160")
                                    value: "3840x2160"
                                    onClicked: { root.minResolution = String(value); root.fetchWallpapers(1); }
                                }
                            ]
                        }

                        SplitButton {
                            id: ratioBtn

                            type: SplitButton.Tonal
                            fallbackIcon: "crop_16_9"
                            fallbackText: Tr.tr("Ratio: Any")
                            active: ratioAny
                            menuItems: [
                                MenuItem {
                                    id: ratioAny

                                    icon: "crop_free"
                                    text: Tr.tr("Ratio: Any")
                                    value: ""
                                    onClicked: { root.aspectRatio = String(value); root.fetchWallpapers(1); }
                                },
                                MenuItem {
                                    icon: "desktop_windows"
                                    text: Tr.tr("Ratio: Landscape")
                                    value: "landscape"
                                    onClicked: { root.aspectRatio = String(value); root.fetchWallpapers(1); }
                                },
                                MenuItem {
                                    icon: "crop_16_9"
                                    text: Tr.tr("Ratio: 16:9")
                                    value: "16x9"
                                    onClicked: { root.aspectRatio = String(value); root.fetchWallpapers(1); }
                                },
                                MenuItem {
                                    icon: "crop_landscape"
                                    text: Tr.tr("Ratio: 16:10")
                                    value: "16x10"
                                    onClicked: { root.aspectRatio = String(value); root.fetchWallpapers(1); }
                                },
                                MenuItem {
                                    icon: "devices"
                                    text: Tr.tr("Ratio: 16:9 / 16:10")
                                    value: "16x9,16x10"
                                    onClicked: { root.aspectRatio = String(value); root.fetchWallpapers(1); }
                                },
                                MenuItem {
                                    icon: "panorama_wide_angle"
                                    text: Tr.tr("Ratio: 21:9")
                                    value: "21x9"
                                    onClicked: { root.aspectRatio = String(value); root.fetchWallpapers(1); }
                                },
                                MenuItem {
                                    icon: "panorama_horizontal"
                                    text: Tr.tr("Ratio: 32:9")
                                    value: "32x9"
                                    onClicked: { root.aspectRatio = String(value); root.fetchWallpapers(1); }
                                },
                                MenuItem {
                                    icon: "crop_3_2"
                                    text: Tr.tr("Ratio: 4:3")
                                    value: "4x3"
                                    onClicked: { root.aspectRatio = String(value); root.fetchWallpapers(1); }
                                },
                                MenuItem {
                                    icon: "smartphone"
                                    text: Tr.tr("Ratio: Portrait")
                                    value: "portrait"
                                    onClicked: { root.aspectRatio = String(value); root.fetchWallpapers(1); }
                                }
                            ]
                        }
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

            // Empty / error state
            Loader {
                Layout.fillWidth: true
                Layout.minimumHeight: 200
                active: root.wallpapers.length === 0 && !root.loading && !root.downloading
                visible: active

                sourceComponent: ColumnLayout {
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.errorMessage ? "error_outline" : "sentiment_dissatisfied"
                        color: root.errorMessage ? Colours.palette.m3error : Colours.palette.m3outlineVariant
                        fontStyle: Tokens.font.icon.extraLarge
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: root.errorMessage ? root.errorMessage : Tr.tr("No wallpapers found")
                        font: Tokens.font.title.medium
                        color: root.errorMessage ? Colours.palette.m3error : Colours.palette.m3outlineVariant
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
                    disabled: root.currentApiPage <= 1
                    type: IconButton.Tonal

                    onClicked: {
                        if (root.currentApiPage > 1) {
                            root.fetchWallpapers(root.currentApiPage - 1);
                        }
                    }
                }

                StyledText {
                    text: Tr.tr("Page %1 of %2").arg(root.currentApiPage).arg(root.lastApiPage)
                    font: Tokens.font.body.medium
                    color: Colours.palette.m3onSurface
                }

                IconButton {
                    icon: "chevron_right"
                    disabled: root.currentApiPage >= root.lastApiPage
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

    component FilterChip: IconTextButton {
        id: chip

        required property string labelText

        isToggle: true
        type: IconTextButton.Tonal
        text: labelText
        icon: internalChecked ? "check" : ""
        spacing: internalChecked ? Tokens.spacing.extraSmall : 0
        horizontalPadding: Tokens.padding.medium
        verticalPadding: Tokens.padding.extraSmall
        defaultRadius: internalChecked ? implicitHeight / 2 : Tokens.rounding.small
        pressedRadius: Tokens.rounding.extraSmall
        activeColour: Colours.palette.m3secondaryContainer
        activeOnColour: Colours.palette.m3onSecondaryContainer
        inactiveColour: Colours.tPalette.m3surfaceContainerHigh
        inactiveOnColour: Colours.palette.m3onSurfaceVariant
    }
}
