pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    required property PersistentProperties visibilities

    property string searchQuery: ""
    property string activeCategory: "all"

    readonly property list<var> categories: [
        { id: "all", title: qsTr("All"), icon: "apps" },
        { id: "window", title: qsTr("Window Actions"), icon: "web_asset" },
        { id: "nav", title: qsTr("Navigation & Movement"), icon: "open_with" },
        { id: "layout", title: qsTr("Layout & Sizing"), icon: "view_column" },
        { id: "workspaces", title: qsTr("Workspaces & Overview"), icon: "grid_view" },
        { id: "shell", title: qsTr("Caelestia Shell"), icon: "widgets" },
        { id: "apps", title: qsTr("Apps & Launchers"), icon: "rocket_launch" },
        { id: "tools", title: qsTr("Screenshots & Tools"), icon: "crop" }
    ]

    readonly property list<var> allShortcuts: [
        // --- Window Actions ---
        { category: "window", keys: "Mod + Q", desc: qsTr("Close focused window") },
        { category: "window", keys: "Mod + F", desc: qsTr("Maximize column (toggle)") },
        { category: "window", keys: "Mod + Shift + F", desc: qsTr("Toggle windowed fullscreen") },
        { category: "window", keys: "Mod + Shift + G", desc: qsTr("Fullscreen window") },
        { category: "window", keys: "Mod + Alt + F", desc: qsTr("Maximize window to screen edges") },
        { category: "window", keys: "Mod + Alt + Space", desc: qsTr("Toggle window floating mode") },
        { category: "window", keys: "Mod + Shift + V", desc: qsTr("Switch focus between floating and tiling") },
        { category: "window", keys: "Mod + Alt + M", desc: qsTr("Mute focused window audio") },

        // --- Navigation & Movement ---
        { category: "nav", keys: "Mod + H / L", desc: qsTr("Focus column left / right (or Mod + ← / →)") },
        { category: "nav", keys: "Mod + J / K", desc: qsTr("Focus window down / up in column (or Mod + ↓ / ↑)") },
        { category: "nav", keys: "Mod + Shift + H / L", desc: qsTr("Move focused column left / right") },
        { category: "nav", keys: "Mod + Shift + J / K", desc: qsTr("Move focused window down / up in column") },
        { category: "nav", keys: "Mod + Ctrl + ← / →", desc: qsTr("Stack into / expel from column (also Mod + [ / ])") },
        { category: "nav", keys: "Mod + .", desc: qsTr("Expel window from column into new column") },
        { category: "nav", keys: "Alt + Tab", desc: qsTr("Switch to next recent window (MRU)") },
        { category: "nav", keys: "Alt + Shift + Tab", desc: qsTr("Switch to previous recent window") },

        // --- Layout & Sizing ---
        { category: "layout", keys: "Mod + R", desc: qsTr("Cycle preset column width (33%, 50%, 66%, 80%, 100%)") },
        { category: "layout", keys: "Mod + - / =", desc: qsTr("Adjust column width by -5% / +5%") },
        { category: "layout", keys: "Mod + Alt + R", desc: qsTr("Cycle preset window height") },
        { category: "layout", keys: "Mod + Shift + - / =", desc: qsTr("Adjust window height by -5% / +5%") },
        { category: "layout", keys: "Mod + Ctrl + R", desc: qsTr("Reset window height to default") },
        { category: "layout", keys: "Mod + Ctrl + F", desc: qsTr("Expand column to available screen width") },
        { category: "layout", keys: "Mod + C", desc: qsTr("Center focused column on screen") },
        { category: "layout", keys: "Mod + Ctrl + C", desc: qsTr("Center all visible columns on screen") },

        // --- Workspaces & Overview ---
        { category: "workspaces", keys: "Mod + 1 .. 9", desc: qsTr("Switch to workspace 1 through 9") },
        { category: "workspaces", keys: "Mod + Shift + 1 .. 9", desc: qsTr("Move focused column to workspace 1..9") },
        { category: "workspaces", keys: "Mod + Alt + 1 .. 9", desc: qsTr("Move column to workspace 1..9 (silent)") },
        { category: "workspaces", keys: "Mod + Ctrl + U / I", desc: qsTr("Move window down / up & switch workspace") },
        { category: "workspaces", keys: "Mod + D", desc: qsTr("Toggle workspace overview (also Mod + Tab)") },

        // --- Caelestia Shell ---
        { category: "shell", keys: "Mod + Space", desc: qsTr("Toggle application search launcher") },
        { category: "shell", keys: "Mod + D", desc: qsTr("Toggle top dashboard (weather, media, stats)") },
        { category: "shell", keys: "Mod + I", desc: qsTr("Open Nexus control panel & settings") },
        { category: "shell", keys: "Mod + N", desc: qsTr("Toggle utilities drawer (quick toggles, recorder)") },
        { category: "shell", keys: "Mod + Shift + N", desc: qsTr("Toggle notifications sidebar") },
        { category: "shell", keys: "Mod + A", desc: qsTr("Toggle sound & audio device panel") },
        { category: "shell", keys: "Mod + B", desc: qsTr("Open Biri Shader FX hotmenu") },
        { category: "shell", keys: "Mod + L", desc: qsTr("Lock the screen") },
        { category: "shell", keys: "Mod + Esc", desc: qsTr("Toggle power session menu (or Ctrl + Alt + Del)") },
        { category: "shell", keys: "Mod + Shift + E", desc: qsTr("Quit Niri compositor session") },

        // --- Apps & Launchers ---
        { category: "apps", keys: "Mod + Return", desc: qsTr("Launch Kitty terminal") },
        { category: "apps", keys: "Mod + Shift + Return", desc: qsTr("Launch floating Kitty terminal") },
        { category: "apps", keys: "Mod + T", desc: qsTr("Launch Kitty terminal with tmux session") },
        { category: "apps", keys: "Mod + O", desc: qsTr("Launch Firefox web browser") },
        { category: "apps", keys: "Mod + E", desc: qsTr("Launch Dolphin file manager") },
        { category: "apps", keys: "Mod + X", desc: qsTr("Launch VS Code IDE") },
        { category: "apps", keys: "Mod + V", desc: qsTr("Open clipboard manager") },
        { category: "apps", keys: "Mod + W", desc: qsTr("Open wallpaper selector") },
        { category: "apps", keys: "Mod + P", desc: qsTr("Open display output switcher") },
        { category: "apps", keys: "Ctrl + Shift + Esc", desc: qsTr("Launch Btop system monitor in Kitty") },

        // --- Screenshots & Tools ---
        { category: "tools", keys: "Mod + Shift + S", desc: qsTr("Interactive screenshot area picker") },
        { category: "tools", keys: "Mod + Shift + X", desc: qsTr("Region OCR (extract text from screen)") },
        { category: "tools", keys: "Mod + Shift + A", desc: qsTr("Region search (reverse image search)") },
        { category: "tools", keys: "Print", desc: qsTr("Capture interactive screenshot") },
        { category: "tools", keys: "Ctrl + Print", desc: qsTr("Capture full screen") },
        { category: "tools", keys: "Alt + Print", desc: qsTr("Capture focused window") },
        { category: "tools", keys: "Mod + M / Shift + M", desc: qsTr("Open Manga / Light Novel reader") }
    ]

    function getItemsForCategory(catId: string): var {
        const q = root.searchQuery.trim().toLowerCase();
        return root.allShortcuts.filter(item => {
            const matchesCat = (catId === "all") || (item.category === catId);
            if (!matchesCat) return false;
            if (!q) return true;
            return item.keys.toLowerCase().includes(q) || item.desc.toLowerCase().includes(q);
        });
    }

    readonly property list<var> visibleCategories: {
        const q = root.searchQuery.trim().toLowerCase();
        const cats = [];
        for (const cat of root.categories) {
            if (cat.id === "all") continue;
            if (root.activeCategory !== "all" && root.activeCategory !== cat.id) continue;
            const items = getItemsForCategory(cat.id);
            if (items.length > 0) {
                cats.push({
                    id: cat.id,
                    title: cat.title,
                    icon: cat.icon,
                    items: items
                });
            }
        }
        return cats;
    }

    width: Math.min(1040, parent ? parent.width - 64 : 1040)
    height: Math.min(760, parent ? parent.height - 64 : 760)
    implicitWidth: width
    implicitHeight: height
    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surface
    border.width: 1
    border.color: Colours.palette.m3outlineVariant

    TapHandler {
        onTapped: root.focus = true
    }

    focus: true
    Keys.onEscapePressed: root.visibilities.hotkeys = false

    Connections {
        target: root.visibilities
        function onHotkeysChanged(): void {
            if (root.visibilities.hotkeys) {
                root.searchQuery = "";
                root.activeCategory = "all";
                searchField.forceActiveFocus();
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        // Top Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledRect {
                implicitWidth: 44
                implicitHeight: 44
                radius: Tokens.rounding.medium
                color: Colours.tPalette.m3primaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "keyboard"
                    size: 26
                    color: Colours.palette.m3primary
                }
            }

            ColumnLayout {
                spacing: 2

                StyledText {
                    text: qsTr("Important Hotkeys")
                    font.family: Tokens.font.title.large.family
                    font.pixelSize: 20
                    font.weight: Font.Bold
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    text: qsTr("Niri & Caelestia Cheatsheet • Press Esc to close")
                    font.pixelSize: 12
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            Item {
                Layout.fillWidth: true
            }

            IconButton {
                icon: "close"
                type: IconButton.Tonal
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                onClicked: root.visibilities.hotkeys = false
            }
        }

        // Search Bar & Filter Row
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            SearchBar {
                id: searchField
                Layout.fillWidth: true
                placeholderText: qsTr("Search hotkeys or descriptions...")
                onTextChanged: root.searchQuery = text
                Keys.onEscapePressed: {
                    if (text.length > 0) {
                        text = "";
                    } else {
                        root.visibilities.hotkeys = false;
                    }
                }
            }
        }

        // Filter Chips Row
        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: root.categories

                Chip {
                    required property var modelData

                    text: modelData.title
                    icon: modelData.icon
                    selected: root.activeCategory === modelData.id
                    onClicked: root.activeCategory = modelData.id
                }
            }
        }

        // Divider
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
            opacity: 0.5
        }

        // Main Content Area: Scrollable Categorized List
        Flickable {
            id: scrollArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: cardsColumn.implicitHeight

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: scrollArea
            }

            ColumnLayout {
                id: cardsColumn
                width: scrollArea.width - Tokens.padding.medium
                spacing: Tokens.spacing.large

                // Empty state when search yields no matches
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 40
                    visible: root.visibleCategories.length === 0
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "search_off"
                        size: 48
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("No hotkeys matched \"%1\"").arg(root.searchQuery)
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                // Categorized Cards
                Repeater {
                    model: root.visibleCategories

                    StyledRect {
                        id: catCard
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: catContent.implicitHeight + Tokens.padding.medium * 2
                        radius: Tokens.rounding.medium
                        color: Colours.tPalette.m3surfaceContainerLow
                        border.width: 1
                        border.color: Colours.palette.m3outlineVariant

                        ColumnLayout {
                            id: catContent
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.medium
                            spacing: Tokens.spacing.small

                            // Category Header
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.small

                                MaterialIcon {
                                    text: catCard.modelData.icon
                                    size: 20
                                    color: Colours.palette.m3primary
                                }

                                StyledText {
                                    text: catCard.modelData.title
                                    font.family: Tokens.font.title.medium.family
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                    color: Colours.palette.m3primary
                                }

                                StyledText {
                                    text: qsTr("(%1)").arg(catCard.modelData.items.length)
                                    font.pixelSize: 12
                                    color: Colours.palette.m3outline
                                }
                            }

                            // Items in Category
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Repeater {
                                    model: catCard.modelData.items

                                    StyledRect {
                                        id: itemRow
                                        required property var modelData
                                        required property int index

                                        Layout.fillWidth: true
                                        implicitHeight: 34
                                        radius: Tokens.rounding.small
                                        color: index % 2 === 0 ? "transparent" : Colours.tPalette.m3surfaceContainer

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: Tokens.padding.small
                                            anchors.rightMargin: Tokens.padding.small
                                            spacing: Tokens.spacing.medium

                                            KeyBadge {
                                                keyString: itemRow.modelData.keys
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: itemRow.modelData.desc
                                                font.pixelSize: 13
                                                color: Colours.palette.m3onSurface
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
