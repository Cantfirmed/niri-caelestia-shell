import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import "navpane"

ColumnLayout {
    id: root

    required property NexusState nState

    spacing: Tokens.spacing.large

    SearchBar {
        id: searchField

        Layout.fillWidth: true

        placeholderText: qsTr("Search settings")
        font: Tokens.font.body.large

        bg.color: Colours.tPalette.m3surfaceContainerLowest
        bg.border.color: searchField.activeFocus ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
        searchIcon.fontStyle: Tokens.font.icon.medium
        searchIcon.anchors.leftMargin: Tokens.padding.largeIncreased
        clearIcon.font: Tokens.font.icon.medium
        clearIcon.padding: Tokens.padding.extraSmall

        Behavior on bg.border.color {
            CAnim {}
        }

        onTextChanged: {
            if (root.nState && root.nState.searchQuery !== text)
                root.nState.searchQuery = text;
        }

        Connections {
            function onSearchQueryChanged(): void {
                if (searchField.text !== (root.nState.searchQuery ?? ""))
                    searchField.text = root.nState.searchQuery ?? "";
            }

            target: root.nState
        }

        onAccepted: {
            if (navLocations.firstIndex >= 0)
                root.nState.currentPageIdx = navLocations.firstIndex;
        }
    }

    NavLocations {
        id: navLocations

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: -topMargin
        Layout.bottomMargin: -bottomMargin
        nState: root.nState
    }
}
