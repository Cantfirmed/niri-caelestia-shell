import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

ColumnLayout {
    spacing: Tokens.spacing.small

    StyledText {
        readonly property bool capsActive: Compositor.capsLock
        text: capsActive ? Tr.tr("Caps lock enabled") : Tr.tr("Caps lock disabled")
    }

    StyledText {
        readonly property bool numActive: Compositor.numLock
        text: numActive ? Tr.tr("Num lock enabled") : Tr.tr("Num lock disabled")
    }
}

