import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

ColumnLayout {
    spacing: Tokens.spacing.small

    StyledText {
        readonly property bool capsActive: ((typeof Niri !== "undefined" && Niri.niriAvailable) ? Niri.capsLock : (typeof Hypr !== "undefined" ? Hypr.capsLock : false))
        text: capsActive ? Tr.tr("Caps lock enabled") : Tr.tr("Caps lock disabled")
    }

    StyledText {
        readonly property bool numActive: ((typeof Niri !== "undefined" && Niri.niriAvailable) ? Niri.numLock : (typeof Hypr !== "undefined" ? Hypr.numLock : false))
        text: numActive ? Tr.tr("Num lock enabled") : Tr.tr("Num lock disabled")
    }
}

