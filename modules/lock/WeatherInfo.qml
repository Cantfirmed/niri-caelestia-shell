import "weather"
import QtQuick
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    required property int rootHeight
    property real effectiveHeight: rootHeight
    readonly property int cardPadding: Math.min(Tokens.padding.extraLarge, Math.max(Tokens.padding.small, Math.round(rootHeight * 0.04)))
    readonly property bool showForecast: effectiveHeight >= Tokens.sizes.lock.showForecastHeight

    implicitHeight: {
        const base = brief.implicitHeight + brief.anchors.topMargin;
        if (showForecast)
            return base + Tokens.spacing.largeIncreased + forecast.implicitHeight + forecast.anchors.margins;
        return base + brief.anchors.topMargin;
    }
    clip: true
    radius: Tokens.rounding.extraExtraLarge
    color: Colours.tPalette.m3surfaceContainer

    Timer {
        running: true
        triggeredOnStart: true
        repeat: true
        interval: 900000 // 15 minutes
        onTriggered: Weather.reload()
    }

    BriefInfo {
        id: brief

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        anchors.top: parent.top
        anchors.topMargin: root.cardPadding

        rootHeight: root.rootHeight
        effectiveHeight: root.effectiveHeight
    }

    Loader {
        id: forecast

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.large

        active: root.showForecast
        asynchronous: true

        sourceComponent: Forecast {}
    }
}
