pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.utils
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen

    readonly property bool isPersistent: (GlobalConfig.bar?.persistent ?? Config.bar?.persistent ?? true)
    readonly property bool disabled: Strings.testRegexList(GlobalConfig.bar?.excludedScreens ?? Config.bar?.excludedScreens ?? [], screen.name)

    readonly property int clampedWidth: Math.max(GlobalConfig.border?.minThickness ?? 1, implicitWidth)
    readonly property int padding: Math.max(Tokens.padding.small, GlobalConfig.border?.thickness ?? 1)
    readonly property int contentWidth: Tokens.sizes.bar.innerWidth + padding * 2
    readonly property int exclusiveZone: !disabled && (isPersistent || screenState.bar) ? contentWidth : (GlobalConfig.border?.thickness ?? 0)
    readonly property bool shouldBeVisible: !fullscreen && !disabled && (isPersistent || screenState.bar || isHovered)
    property bool isHovered

    function closeTray(): void {
        (content.item as Bar)?.closeTray();
    }

    function checkPopout(y: real): void {
        (content.item as Bar)?.checkPopout(y);
    }

    function handleWheel(y: real, angleDelta: point): void {
        (content.item as Bar)?.handleWheel(y, angleDelta);
    }

    // Reactive clock position — updates when Bar loads
    readonly property real clockY: content.item ? (content.item as Bar).getClockY() : 0
    readonly property real clockHeight: content.item ? (content.item as Bar).getClockHeight() : 0

    function getClockY(): real { return clockY; }
    function getClockHeight(): real { return clockHeight; }
    function isClockAtY(y: real): bool { return (content.item as Bar)?.isClockAtY(y) ?? false; }

    width: implicitWidth
    clip: true
    visible: width > (GlobalConfig.border?.thickness ?? 0)
    implicitWidth: fullscreen ? 0 : (shouldBeVisible ? contentWidth : (GlobalConfig.border?.thickness ?? 0))

    states: State {
        name: "visible"
        when: root.shouldBeVisible

        PropertyChanges {
            root.implicitWidth: root.contentWidth
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: "implicitWidth"
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: "implicitWidth"
                type: Anim.Emphasized
            }
        }
    ]

    Loader {
        id: content

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: root.contentWidth

        active: root.shouldBeVisible

        sourceComponent: Bar {
            anchors.fill: parent
            screen: root.screen
            screenState: root.screenState
            popouts: root.popouts // qmllint disable incompatible-type
            fullscreen: root.fullscreen
        }
    }
}

