import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    spacing: Tokens.spacing.small

    StyledText {
        text: qsTr("Capslock: %1").arg(((typeof Niri !== "undefined" && Niri.niriAvailable) ? Niri.capsLock : (typeof Hypr !== "undefined" ? Hypr.capsLock : false)) ? "Enabled" : "Disabled")
    }

    StyledText {
        text: qsTr("Numlock: %1").arg(((typeof Niri !== "undefined" && Niri.niriAvailable) ? Niri.numLock : (typeof Hypr !== "undefined" ? Hypr.numLock : false)) ? "Enabled" : "Disabled")
    }
}

