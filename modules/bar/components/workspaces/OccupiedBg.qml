pragma ComponentBehavior: Bound

import qs.components
import qs.services
import Caelestia.Config
import Quickshell
import QtQuick

Item {
    id: root

    required property Repeater workspaces
    required property var occupiedSlots

    property list<var> pills: []

    onOccupiedSlotsChanged: buildPills()

    function buildPills() {
        let count = 0;
        const len = Config.bar.workspaces.shown;
        for (let i = 0; i < len; i++) {
            if (occupiedSlots[i]) {
                if (i === 0 || !occupiedSlots[i - 1]) {
                    if (pills[count])
                        pills[count].start = i;
                    else
                        pills.push(pillComp.createObject(root, {
                            start: i
                        }));
                    count++;
                }
                if (i === len - 1 || !occupiedSlots[i + 1])
                    pills[count - 1].end = i;
            }
        }
        if (pills.length > count)
            pills.splice(count, pills.length - count).forEach(p => p.destroy());
    }

    Repeater {
        model: ScriptModel {
            values: root.pills.filter(p => p)
        }

        StyledRect {
            id: rect

            required property var modelData

            readonly property Workspace start: root.workspaces.itemAt(modelData.start) ?? null
            readonly property Workspace end: root.workspaces.itemAt(modelData.end) ?? null
            property bool isContextActiveInWs: Niri.wsContextType === "workspaces" && Niri.wsContextAnchor

            anchors {
                // horizontalCenter: root.horizontalCenter
                left: root.left
                right: root.right
                rightMargin: isContextActiveInWs ? -Config.bar.workspaces.windowContextWidth + Appearance.padding.xs : 0
            }

            topRightRadius: isContextActiveInWs ? Appearance.rounding.normal : radius
            bottomRightRadius: isContextActiveInWs ? Appearance.rounding.normal : radius

            y: (start?.y ?? 0)
            // implicitWidth: Tokens.sizes.bar.innerWidth - Appearance.padding.xs * 2 + 2
            implicitHeight: start && end ? end.y + end.size - start.y : 0
            // implicitHeight: end?.y + end?.height - start?.y

            color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
            radius: Appearance.rounding.full

            scale: 0
            Component.onCompleted: scale = 1.0

            Behavior on topRightRadius {
                Anim {
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }
            Behavior on bottomRightRadius {
                Anim {
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }

            Behavior on scale {
                Anim {
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
            }

            Behavior on anchors.rightMargin {
                Anim {
                    duration: Appearance.anim.durations.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }

            Behavior on y {
                Anim {}
            }

            Behavior on implicitHeight {
                Anim {}
            }
        }
    }

    component Pill: QtObject {
        property int start
        property int end
    }

    Component {
        id: pillComp

        Pill {}
    }
}
