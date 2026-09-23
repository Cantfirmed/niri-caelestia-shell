pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.Internal
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    property bool showAddManual: false
    property bool showAppSearch: false
    property string manualId: ""
    property bool manualIsRegex: false
    property real manualWidth: 0.0
    property bool manualMaximized: false
    property string appSearchQuery: ""

    readonly property var widthOptions: [
        { label: qsTr("Default"), value: 0.0 },
        { label: "33%", value: 0.33 },
        { label: "50%", value: 0.50 },
        { label: "67%", value: 0.67 },
        { label: "100%", value: 1.00 }
    ]

    title: qsTr("Tiling applications")
    isSubPage: true

    function getAppIcon(rule: var): string {
        if (!rule)
            return Quickshell.iconPath("application-x-executable", "image-missing");
        if (rule.icon && rule.icon.length > 0) {
            const p = Quickshell.iconPath(rule.icon, "");
            if (p && p.length > 0)
                return p;
        }
        const cleanId = (rule.id || "").replace(/\.desktop$/, "");
        for (const app of DesktopEntries.applications.values) {
            if (app.id === rule.id || app.id === `${cleanId}.desktop` || app.id === cleanId) {
                return Quickshell.iconPath(app.icon, "image-missing");
            }
        }
        return Quickshell.iconPath(rule.id || "", "image-missing");
    }

    function getAppName(rule: var): string {
        if (!rule)
            return "";
        if (rule.name && rule.name.length > 0 && rule.name !== rule.id)
            return rule.name;
        const cleanId = (rule.id || "").replace(/\.desktop$/, "");
        for (const app of DesktopEntries.applications.values) {
            if (app.id === rule.id || app.id === `${cleanId}.desktop` || app.id === cleanId) {
                return app.name;
            }
        }
        return rule.id || "";
    }

    function cycleWidth(index: int): void {
        const rule = NiriTiling.rules[index];
        if (!rule)
            return;
        const current = Number(rule.columnWidth || 0);
        let next = 0.0;
        if (current === 0.0) next = 0.50;
        else if (Math.abs(current - 0.50) < 0.05) next = 0.67;
        else if (Math.abs(current - 0.67) < 0.05) next = 1.00;
        else if (Math.abs(current - 1.00) < 0.05) next = 0.33;
        else next = 0.0;
        NiriTiling.setColumnWidth(index, next);
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // ---------------- Master Toggle ----------------
        SectionHeader {
            first: true
            text: qsTr("Window Tiling Behavior")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Enable tiling rules")
            subtext: qsTr("Force specified applications to start tiled instead of floating")
            checked: NiriTiling.tilingRulesEnabled
            onToggled: NiriTiling.tilingRulesEnabled = checked
        }

        // ---------------- Quick Add From Open Windows ----------------
        SectionHeader {
            text: qsTr("Quick-add Open Windows")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: quickAddCol.implicitHeight + Tokens.padding.largeIncreased * 2

            ColumnLayout {
                id: quickAddCol

                anchors.fill: parent
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "splitscreen"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Running windows detected by Niri")
                        font: Tokens.font.body.small
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    readonly property var uniqueWindows: {
                        const wins = NiriIpc.windows || [];
                        const list = [];
                        const seen = new Set();
                        for (let i = 0; i < wins.length; i++) {
                            const w = wins[i];
                            if (w && w.app_id && !seen.has(w.app_id)) {
                                seen.add(w.app_id);
                                list.push(w);
                            }
                        }
                        return list;
                    }

                    Repeater {
                        model: parent.uniqueWindows

                        StyledRect {
                            id: winChip

                            required property var modelData

                            readonly property bool alreadyAdded: NiriTiling.isAppTiled(winChip.modelData.app_id)

                            implicitWidth: chipRow.implicitWidth + Tokens.padding.medium * 2
                            implicitHeight: chipRow.implicitHeight + Tokens.padding.extraSmall * 2
                            radius: Tokens.rounding.full
                            color: alreadyAdded ? Colours.tPalette.m3surfaceContainerHigh : Colours.palette.m3secondaryContainer

                            StateLayer {
                                anchors.fill: parent
                                radius: parent.radius
                                disabled: winChip.alreadyAdded
                                onClicked: {
                                    NiriTiling.addRule(winChip.modelData.app_id, winChip.modelData.app_id, winChip.modelData.app_id, false, 0.0, false);
                                }
                            }

                            RowLayout {
                                id: chipRow

                                anchors.centerIn: parent
                                spacing: Tokens.spacing.extraSmall

                                MaterialIcon {
                                    text: winChip.alreadyAdded ? "check" : "add"
                                    fontStyle: Tokens.font.icon.small
                                    color: winChip.alreadyAdded ? Colours.palette.m3outline : Colours.palette.m3onSecondaryContainer
                                }

                                StyledText {
                                    text: winChip.modelData.app_id
                                    font: Tokens.font.label.small
                                    color: winChip.alreadyAdded ? Colours.palette.m3outline : Colours.palette.m3onSecondaryContainer
                                }
                            }
                        }
                    }

                    StyledText {
                        visible: parent.uniqueWindows.length === 0
                        text: qsTr("No active windows detected")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3outline
                    }
                }
            }
        }

        // ---------------- Add Application ----------------
        SectionHeader {
            text: qsTr("Add Application")
        }

        // Search installed apps card
        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: !root.showAddManual
            implicitHeight: appSearchCol.implicitHeight + Tokens.padding.largeIncreased * 2

            ColumnLayout {
                id: appSearchCol

                anchors.fill: parent
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "search"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Browse installed applications")
                        font: Tokens.font.body.small
                    }

                    IconButton {
                        icon: root.showAppSearch ? "expand_less" : "search"
                        type: IconButton.Tonal
                        isRound: true
                        font: Tokens.font.icon.small
                        onClicked: root.showAppSearch = !root.showAppSearch
                    }

                    IconButton {
                        icon: root.showAddManual ? "expand_less" : "tune"
                        type: IconButton.Tonal
                        isRound: true
                        font: Tokens.font.icon.small
                        onClicked: root.showAddManual = !root.showAddManual
                    }
                }

                // App search bar and results
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.showAppSearch
                    spacing: Tokens.spacing.small

                    StyledTextField {
                        id: appSearchField

                        Layout.fillWidth: true
                        placeholderText: qsTr("Search by app name (e.g. Steam, Files, Calculator)...")
                        onTextEdited: root.appSearchQuery = text.trim().toLowerCase()
                    }

                    // Filtered list of apps (showing max 5 matches)
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.appSearchQuery.length > 0
                        spacing: Tokens.spacing.extraSmall

                        readonly property var filteredApps: {
                            if (root.appSearchQuery.length === 0)
                                return [];
                            const query = root.appSearchQuery;
                            const matches = [];
                            for (const app of DesktopEntries.applications.values) {
                                if (app.name.toLowerCase().includes(query) || (app.id && app.id.toLowerCase().includes(query))) {
                                    matches.push(app);
                                    if (matches.length >= 6)
                                        break;
                                }
                            }
                            return matches;
                        }

                        Repeater {
                            model: parent.filteredApps

                            StyledRect {
                                id: searchResultItem

                                required property DesktopEntry modelData

                                readonly property bool alreadyAdded: NiriTiling.isAppTiled(searchResultItem.modelData.id)

                                Layout.fillWidth: true
                                implicitHeight: resultRow.implicitHeight + Tokens.padding.medium * 2
                                radius: Tokens.rounding.small
                                color: Colours.tPalette.m3surfaceContainer

                                StateLayer {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    disabled: searchResultItem.alreadyAdded
                                    onClicked: {
                                        const cleanId = searchResultItem.modelData.id.replace(/\.desktop$/, "");
                                        NiriTiling.addRule(cleanId, searchResultItem.modelData.name, searchResultItem.modelData.icon, false, 0.0, false);
                                        appSearchField.clear();
                                        root.appSearchQuery = "";
                                        root.showAppSearch = false;
                                    }
                                }

                                RowLayout {
                                    id: resultRow

                                    anchors.fill: parent
                                    anchors.margins: Tokens.padding.medium
                                    spacing: Tokens.spacing.medium

                                    IconImage {
                                        asynchronous: true
                                        implicitSize: Math.round(Tokens.font.icon.large.pointSize * 1.5)
                                        source: Quickshell.iconPath(searchResultItem.modelData.icon, "image-missing")
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: searchResultItem.modelData.name
                                            font: Tokens.font.body.small
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: searchResultItem.modelData.id
                                            font: Tokens.font.label.small
                                            color: Colours.palette.m3outline
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MaterialIcon {
                                        text: searchResultItem.alreadyAdded ? "check" : "add"
                                        fontStyle: Tokens.font.icon.small
                                        color: searchResultItem.alreadyAdded ? Colours.palette.m3primary : Colours.palette.m3outline
                                    }
                                }
                            }
                        }

                        StyledText {
                            visible: parent.filteredApps.length === 0
                            text: qsTr("No matching installed applications found")
                            font: Tokens.font.label.small
                            color: Colours.palette.m3outline
                        }
                    }
                }

                // Manual add form
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.showAddManual
                    spacing: Tokens.spacing.medium

                    StyledText {
                        text: qsTr("Custom rule / regular expression")
                        font: Tokens.font.label.medium
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        StyledTextField {
                            id: manualField

                            Layout.fillWidth: true
                            placeholderText: qsTr("Enter app-id or regex (e.g. steam, discord$, (?i)calc)")
                            onTextEdited: root.manualId = text
                        }

                        StyledRect {
                            implicitWidth: addBtnRow.implicitWidth + Tokens.padding.medium * 2
                            implicitHeight: manualField.implicitHeight
                            radius: Tokens.rounding.medium
                            color: Colours.palette.m3primary

                            StateLayer {
                                anchors.fill: parent
                                radius: parent.radius
                                disabled: root.manualId.trim().length === 0
                                onClicked: {
                                    if (root.manualId.trim().length > 0) {
                                        NiriTiling.addRule(
                                            root.manualId.trim(),
                                            root.manualId.trim(),
                                            root.manualId.trim(),
                                            root.manualIsRegex,
                                            root.manualWidth,
                                            root.manualMaximized
                                        );
                                        manualField.clear();
                                        root.manualId = "";
                                        root.showAddManual = false;
                                    }
                                }
                            }

                            RowLayout {
                                id: addBtnRow

                                anchors.centerIn: parent
                                spacing: Tokens.spacing.extraSmall

                                MaterialIcon {
                                    text: "add"
                                    color: Colours.palette.m3onPrimary
                                    fontStyle: Tokens.font.icon.small
                                }

                                StyledText {
                                    text: qsTr("Add")
                                    color: Colours.palette.m3onPrimary
                                    font: Tokens.font.label.medium
                                }
                            }
                        }
                    }

                    // Manual options: Regex toggle & Column width chips
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.large

                        RowLayout {
                            spacing: Tokens.spacing.extraSmall

                            StyledSwitch {
                                id: regexSwitch

                                checked: root.manualIsRegex
                                onToggled: root.manualIsRegex = checked
                            }

                            StyledText {
                                text: qsTr("Regex match")
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }

                        RowLayout {
                            spacing: Tokens.spacing.extraSmall

                            StyledSwitch {
                                id: maxSwitch

                                checked: root.manualMaximized
                                onToggled: root.manualMaximized = checked
                            }

                            StyledText {
                                text: qsTr("Open maximized")
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            spacing: Tokens.spacing.extraSmall

                            StyledText {
                                text: qsTr("Width:")
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            Repeater {
                                model: root.widthOptions

                                StyledRect {
                                    id: wOptionChip

                                    required property var modelData

                                    readonly property bool isSelected: Math.abs(root.manualWidth - wOptionChip.modelData.value) < 0.05

                                    implicitWidth: wOptionText.implicitWidth + Tokens.padding.small * 2
                                    implicitHeight: wOptionText.implicitHeight + Tokens.padding.extraSmall * 2
                                    radius: Tokens.rounding.small
                                    color: isSelected ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHigh

                                    StateLayer {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        onClicked: root.manualWidth = wOptionChip.modelData.value
                                    }

                                    StyledText {
                                        id: wOptionText

                                        anchors.centerIn: parent
                                        text: wOptionChip.modelData.label
                                        font: Tokens.font.label.small
                                        color: wOptionChip.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---------------- Configured Tiling Rules ----------------
        SectionHeader {
            text: qsTr("Configured Tiling Rules (%1)").arg(NiriTiling.rules ? NiriTiling.rules.length : 0)
        }

        // Empty state
        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            visible: !NiriTiling.rules || NiriTiling.rules.length === 0
            implicitHeight: emptyCol.implicitHeight + Tokens.padding.extraLarge * 2

            ColumnLayout {
                id: emptyCol

                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "splitscreen"
                    fontStyle: Tokens.font.icon.large
                    color: Colours.palette.m3outline
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("No tiling rules configured")
                    font: Tokens.font.body.medium
                    color: Colours.palette.m3outline
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Click an open window above or search installed applications to force tiling.")
                    font: Tokens.font.label.small
                    color: Colours.palette.m3outline
                }
            }
        }

        // List of existing tiling rules
        Repeater {
            model: NiriTiling.rules

            ConnectedRect {
                id: ruleItem

                required property var modelData
                required property int index

                Layout.fillWidth: true
                first: index === 0
                last: index === (NiriTiling.rules ? NiriTiling.rules.length - 1 : 0)
                implicitHeight: ruleRow.implicitHeight + Tokens.padding.medium * 2

                RowLayout {
                    id: ruleRow

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    IconImage {
                        asynchronous: true
                        implicitSize: Math.round(Tokens.font.icon.large.pointSize * 1.6)
                        source: root.getAppIcon(ruleItem.modelData)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: root.getAppName(ruleItem.modelData)
                            font: Tokens.font.body.small
                            color: ruleItem.modelData.enabled ? Colours.palette.m3onSurface : Colours.palette.m3outline
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                const idStr = ruleItem.modelData.id || "";
                                const typeStr = ruleItem.modelData.isRegex ? qsTr("regex") : (ruleItem.modelData.type || "app-id");
                                return `${idStr}  •  ${typeStr}`;
                            }
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    // Column width pill button (interactive, cycles on click)
                    StyledRect {
                        id: widthPill

                        readonly property real colW: Number(ruleItem.modelData.columnWidth || 0)

                        implicitWidth: widthPillText.implicitWidth + Tokens.padding.medium * 2
                        implicitHeight: widthPillText.implicitHeight + Tokens.padding.extraSmall * 2
                        radius: Tokens.rounding.full
                        color: colW > 0 ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHigh

                        StateLayer {
                            anchors.fill: parent
                            radius: parent.radius
                            onClicked: root.cycleWidth(ruleItem.index)
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.extraSmall

                            MaterialIcon {
                                text: "view_column"
                                fontStyle: Tokens.font.icon.small
                                color: widthPill.colW > 0 ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3outline
                            }

                            StyledText {
                                id: widthPillText

                                text: widthPill.colW > 0 ? `${Math.round(widthPill.colW * 100)}%` : qsTr("Default width")
                                font: Tokens.font.label.small
                                color: widthPill.colW > 0 ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3outline
                            }
                        }
                    }

                    // Maximized toggle button
                    IconButton {
                        type: ruleItem.modelData.maximized ? IconButton.Filled : IconButton.Tonal
                        isRound: true
                        icon: "fullscreen"
                        font: Tokens.font.icon.small
                        onClicked: NiriTiling.setMaximized(ruleItem.index, !ruleItem.modelData.maximized)
                    }

                    // Rule active switch
                    StyledSwitch {
                        checked: ruleItem.modelData.enabled
                        font: Tokens.font.icon.medium
                        onToggled: NiriTiling.toggleRule(ruleItem.index, checked)
                    }

                    // Delete button
                    IconButton {
                        type: IconButton.Text
                        isRound: true
                        icon: "delete"
                        inactiveOnColour: Colours.palette.m3error
                        font: Tokens.font.icon.medium
                        label.fill: 0
                        onClicked: NiriTiling.removeRule(ruleItem.index)
                    }
                }
            }
        }

        // ---------------- Clear All Action ----------------
        SectionHeader {
            visible: NiriTiling.rules && NiriTiling.rules.length > 0
            text: qsTr("Actions")
        }

        RowButton {
            visible: NiriTiling.rules && NiriTiling.rules.length > 0
            first: true
            last: true
            icon: "delete_sweep"
            text: qsTr("Clear all tiling rules")
            subtext: qsTr("Remove all configured application tiling rules")
            onClicked: NiriTiling.clearAllRules()
        }
    }
}
