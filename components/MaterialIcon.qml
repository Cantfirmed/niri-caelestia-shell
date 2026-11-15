import QtQuick
import Caelestia.Config
import qs.services

StyledText {
    property real fill
    property int grade: Colours.light ? 0 : -25
    property font fontStyle: Tokens.font.icon.small
    property real size: 0
    property int weight: fontStyle.weight

    font: Tokens.font.icon.size(size > 0 ? size : fontStyle.pointSize).weight(weight).vaxes(fontStyle.variableAxes).fill(fill.toFixed(1)).grade(grade).build()
}

