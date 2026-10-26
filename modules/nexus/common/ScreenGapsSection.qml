pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

ColumnLayout {
    id: root

    property bool showInnerGap: true
    property bool showHeader: true
    property bool firstHeader: false

    Layout.fillWidth: true
    spacing: Tokens.spacing.extraSmall / 2

    SectionHeader {
        visible: root.showHeader
        first: root.firstHeader
        text: Tr.tr("Window & Screen Gaps")
    }

    StepperRow {
        visible: root.showInnerGap
        first: true
        label: Tr.tr("Inner window gap")
        subtext: Tr.tr("Spacing between adjacent tiled windows in pixels")
        value: Niri.gaps
        from: 0
        to: 64
        stepSize: 1
        onMoved: v => Niri.setGaps(Math.round(v))
    }

    ToggleRow {
        first: !root.showInnerGap
        text: Tr.tr("Link screen gaps")
        subtext: Tr.tr("Synchronize all sides (uncheck to set each edge separately)")
        checked: Biri.screenGapsLinked
        onToggled: Biri.setScreenGapsLinked(checked)
    }

    StepperRow {
        visible: Biri.screenGapsLinked
        last: true
        label: Tr.tr("Screen gap (all sides)")
        subtext: Tr.tr("Distance between screen edges and windows in pixels")
        value: Biri.screenGapLinkedValue
        from: 0
        to: 128
        stepSize: 1
        onMoved: v => Biri.setLinkedScreenGap(Math.round(v))
    }

    StepperRow {
        visible: !Biri.screenGapsLinked
        label: Tr.tr("Top screen gap")
        subtext: Tr.tr("Distance from the top screen edge in pixels")
        value: Biri.screenGapTop
        from: 0
        to: 128
        stepSize: 1
        onMoved: v => Biri.screenGapTop = Math.round(v)
    }

    StepperRow {
        visible: !Biri.screenGapsLinked
        label: Tr.tr("Bottom screen gap")
        subtext: Tr.tr("Distance from the bottom screen edge in pixels")
        value: Biri.screenGapBottom
        from: 0
        to: 128
        stepSize: 1
        onMoved: v => Biri.screenGapBottom = Math.round(v)
    }

    StepperRow {
        visible: !Biri.screenGapsLinked
        label: Tr.tr("Left screen gap (starting from sidebar)")
        subtext: Tr.tr("Distance from the left screen edge / sidebar in pixels")
        value: Biri.screenGapLeft
        from: 0
        to: 128
        stepSize: 1
        onMoved: v => Biri.screenGapLeft = Math.round(v)
    }

    StepperRow {
        visible: !Biri.screenGapsLinked
        last: true
        label: Tr.tr("Right screen gap")
        subtext: Tr.tr("Distance from the right screen edge in pixels")
        value: Biri.screenGapRight
        from: 0
        to: 128
        stepSize: 1
        onMoved: v => Biri.screenGapRight = Math.round(v)
    }
}
